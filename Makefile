source   := $(shell dpkg-parsechangelog | awk '$$1 == "Source:" { print $$2 }')
version  := $(shell dpkg-parsechangelog | awk '$$1 == "Version:" { print $$2 }')
date     := $(shell dpkg-parsechangelog | grep ^Date: | cut -d: -f 2- | date --date="$$(cat)" +%Y-%m-%d)
target_distribution := $(shell dpkg-parsechangelog | awk '$$1 == "Distribution:" { print $$2 }')

script_sources  := check-health.sh check-web-health.sh check-virtualenvs.sh check-ssl-certs.sh
manpage_sources := $(script_sources:%.sh=%.rst)

builddir        := build
scripts         := $(script_sources:%.sh=$(builddir)/%)
manpages        := $(manpage_sources:%.rst=$(builddir)/%.8)

# the main manpage that documents all the functions
main_manpage := check-health.rst


# change this to the lowest supported Ubuntu LTS
TARGET_DISTRO := jammy

# for testing in vagrant:
#   mkdir -p ~/tmp/vagrantbox && cd ~/tmp/vagrantbox
#   vagrant init ubuntu/xenial64
#   vagrant ssh-config --host vagrantbox >> ~/.ssh/config
# now you can 'make vagrant-test-install', then 'ssh vagrantbox' and play
# with the package
VAGRANT_DIR := ~/tmp/vagrantbox
VAGRANT_SSH_ALIAS := vagrantbox


##: Development


.PHONY: all
all: $(scripts) $(manpages)             ##: generate scripts and manual pages

include help.mk
HELP_INDENT = "  "
HELP_WIDTH = 28

$(builddir):
	mkdir $@

$(builddir)/%.8: %.rst | $(builddir)
	rst2man $< $@

$(builddir)/check-%: check-%.sh | $(builddir)
	sed -e 's,^libdir=\.$$,libdir=/usr/share/pov-check-health,' $< > $@

.PHONY: test
test: check-version check-docs          ##: run tests
	@./tests.sh

.PHONY: shellcheck
shellcheck:                             ##: run shellcheck
	shellcheck *.sh example.conf

clean:                                  ##: delete generated files
	rm -f $(scripts) $(manpages)

##: Run these when `make release` tells you to, otherwise ignore them

.PHONY: check
check: test                             ## pre-release testing

.PHONY: check-version
check-version:                          ## check version numbers in man pages
	@for fn in $(manpage_sources); do \
	    grep -q ":Version: $(version)" $$fn || { \
	        echo "Version number in $$fn doesn't match debian/changelog ($(version))." 2>&1; \
	        echo "Run make update-version" 2>&1; \
	        exit 1; \
	    }; \
	    grep -q ":Date: $(date)" $$fn || { \
	        echo "Date in $$fn doesn't match debian/changelog ($(date))" 2>&1; \
	        echo "Run make update-version" 2>&1; \
	        exit 1; \
	    }; \
	    echo "$$fn: date and version number match debian/changelog"; \
	done

.PHONY: update-version
update-version:                         ##: update version numbers in man pages
	sed -i -e 's/^:Version: .*/:Version: $(version)/' $(manpage_sources)
	sed -i -e 's/^:Date: .*/:Date: $(date)/' $(manpage_sources)

.PHONY: check-docs
check-docs:                             ## check if docs are outdated
	@./extract-documentation.py -c $(main_manpage) || echo "Run make update-docs please"
	@echo "$(main_manpage): docs match comments in functions.sh"

.PHONY: check-target
check-target:                           ## check debian/changelog target distro
	@test "$(target_distribution)" = "$(TARGET_DISTRO)" || { \
	    echo "Distribution in debian/changelog should be '$(TARGET_DISTRO)'" 2>&1; \
	    echo "Run make update-target" 2>&1; \
	    exit 1; \
	}

.PHONY: update-target
update-target:                          ##: update debian/changelog prior to release
	dch -r -D $(TARGET_DISTRO) ""

.PHONY: update-docs
update-docs:                            ##: update man pages with function descriptions
	./extract-documentation.py -u $(main_manpage)

.PHONY: install
install: check-health
	install -D -m 644 functions.sh $(DESTDIR)/usr/share/pov-check-health/functions.sh
	install -D -m 644 generate.sh  $(DESTDIR)/usr/share/pov-check-health/generate.sh
	install -D -m 644 cmdline.sh   $(DESTDIR)/usr/share/pov-check-health/cmdline.sh
	install -D -m 644 example.conf $(DESTDIR)/usr/share/doc/pov-check-health/check-health.example
	install -D $(builddir)/check-health      $(DESTDIR)/usr/sbin/check-health
	install -D $(builddir)/check-web-health  $(DESTDIR)/usr/sbin/check-web-health
	install -D $(builddir)/check-ssl-certs   $(DESTDIR)/usr/sbin/check-ssl-certs
	install -D $(builddir)/check-virtualenvs $(DESTDIR)/usr/sbin/check-virtualenvs
	# manpages are installed by debhelpers; see debian/manpages


VCS_STATUS := git status --porcelain

.PHONY: clean-build-tree
clean-build-tree:
	@./extract-documentation.py -c $(main_manpage) || { echo "Run make update-docs please" 1>&2; exit 1; }
	@test -z "`$(VCS_STATUS) 2>&1`" || { \
	    echo; \
	    echo "Your working tree is not clean; please commit and try again" 1>&2; \
	    $(VCS_STATUS); \
	    echo 'E.g. run git commit -am "Release $(version)"' 1>&2; \
	    exit 1; }
	rm -rf pkgbuild/$(source)
	git archive --format=tar --prefix=pkgbuild/$(source)/ HEAD | tar -xf -

##: Test before you release

.PHONY: source-package
source-package: clean-build-tree                ##: build a Debian source package for testing/uploading
	cd pkgbuild/$(source) && debuild -S -i -k$(GPGKEY)

.PHONY: binary-package
binary-package: clean-build-tree                ##: build a Debian binary package for local testing
	cd pkgbuild/$(source) && debuild -i -k$(GPGKEY)
	@echo
	@echo "Built pkgbuild/$(source)_$(version)_all.deb"

.PHONY: vagrant-test-install
vagrant-test-install: binary-package
	cp pkgbuild/$(source)_$(version)_all.deb $(VAGRANT_DIR)/
	cd $(VAGRANT_DIR) && vagrant up
	ssh $(VAGRANT_SSH_ALIAS) 'sudo DEBIAN_FRONTEND=noninteractive dpkg -i /vagrant/$(source)_$(version)_all.deb; sudo apt-get install -f'

.PHONY: pbuilder-test-build
pbuilder-test-build: source-package             ##: test building the source package in a chroot
	# NB: 1st time run pbuilder-dist $(TARGET_DISTRO) create
	# NB: you need to periodically run pbuilder-dist $(TARGET_DISTRO) update
	pbuilder-dist $(TARGET_DISTRO) build pkgbuild/$(source)_$(version).dsc
	@echo
	@echo "Look for the package in ~/pbuilder/$(TARGET_DISTRO)_result/"

##: Release

.PHONY: upload-to-ppa release
release upload-to-ppa: check-target check source-package        ##: prepare, build and upload a source .deb to the PPA
	dput ssh-ppa:pov/ppa pkgbuild/$(source)_$(version)_source.changes
	git tag $(version)
	git push
	git push --tags
