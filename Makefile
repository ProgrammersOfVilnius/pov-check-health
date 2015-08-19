source := $(shell dpkg-parsechangelog | awk '$$1 == "Source:" { print $$2 }')
version := $(shell dpkg-parsechangelog | awk '$$1 == "Version:" { print $$2 }')
date := $(shell dpkg-parsechangelog | grep ^Date: | cut -d: -f 2- | date --date="$$(cat)" +%Y-%m-%d)

manpage = check-health.rst
manpages = check-health.rst check-web-health.rst check-virtualenvs.rst

# for testing in vagrant:
#   vagrant box add precise64 http://files.vagrantup.com/precise64.box
#   mkdir -p ~/tmp/vagrantbox && cd ~/tmp/vagrantbox
#   vagrant init precise64
#   vagrant ssh-config --host vagrantbox >> ~/.ssh/config
# now you can 'make vagrant-test-install', then 'ssh vagrantbox' and play
# with the package
VAGRANT_DIR = ~/tmp/vagrantbox
VAGRANT_SSH_ALIAS = vagrantbox


.PHONY: all
all: check-health.8 check-health check-web-health.8 check-web-health check-virtualenvs.8

%.8: %.rst
	rst2man $< > $@

check-%: check-%.sh
	sed -e 's,^libdir=\.$$,libdir=/usr/share/pov-check-health,' $< > $@

.PHONY: test check
test check: check-version check-docs
	@./tests.sh

.PHONY: checkversion
check-version:
	@for fn in $(manpages); do \
	    grep -q ":Version: $(version)" $$fn || { \
	        echo "Version number in $$fn doesn't match debian/changelog ($(version))" 2>&1; \
	        exit 1; \
	    }; \
	    grep -q ":Date: $(date)" $$fn || { \
	        echo "Date in $$fn doesn't match debian/changelog ($(date))" 2>&1; \
	        exit 1; \
	    }; \
	done
	@echo "$(manpages): dates and version numbers match debian/changelog"

.PHONY: check-docs
check-docs:
	@./extract-documentation.py -c $(manpage) || echo "Run make update-docs please"
	@echo "$(manpage): docs match comments in functions.sh"

.PHONY: update-docs
update-docs:
	./extract-documentation.py -u $(manpage)

.PHONY: install
install: check-health
	install -D -m 644 functions.sh $(DESTDIR)/usr/share/pov-check-health/functions.sh
	install -D -m 644 generate.sh $(DESTDIR)/usr/share/pov-check-health/generate.sh
	install -D -m 644 example.conf $(DESTDIR)/usr/share/doc/pov-check-health/check-health.example
	install -D check-health $(DESTDIR)/usr/sbin/check-health
	install -D check-web-health $(DESTDIR)/usr/sbin/check-web-health
	install -D check-virtualenvs.sh $(DESTDIR)/usr/sbin/check-virtualenvs


VCS_STATUS = git status --porcelain

.PHONY: clean-build-tree
clean-build-tree:
	@./extract-documentation.py -c $(manpage) || { echo "Run make update-docs please" 1>&2; exit 1; }
	@test -z "`$(VCS_STATUS) 2>&1`" || { echo; echo "Your working tree is not clean; please commit and try again" 1>&2; $(VCS_STATUS); exit 1; }
	rm -rf pkgbuild/$(source)
	git archive --format=tar --prefix=pkgbuild/$(source)/ HEAD | tar -xf -

.PHONY: source-package
source-package: clean-build-tree
	cd pkgbuild/$(source) && debuild -S -i -k$(GPGKEY)

.PHONY: upload-to-ppa release
release upload-to-ppa: check source-package
	dput ppa:pov/ppa pkgbuild/$(source)_$(version)_source.changes
	git tag $(version)
	git push
	git push --tags

.PHONY: binary-package
binary-package: clean-build-tree
	cd pkgbuild/$(source) && debuild -i -k$(GPGKEY)
	@echo
	@echo "Built pkgbuild/$(source)_$(version)_all.deb"

.PHONY: vagrant-test-install
vagrant-test-install: binary-package
	cp pkgbuild/$(source)_$(version)_all.deb $(VAGRANT_DIR)/
	cd $(VAGRANT_DIR) && vagrant up
	ssh $(VAGRANT_SSH_ALIAS) 'sudo DEBIAN_FRONTEND=noninteractive dpkg -i /vagrant/$(source)_$(version)_all.deb; sudo apt-get install -f'

.PHONY: pbuilder-test-build
pbuilder-test-build: source-package
	pbuilder-dist precise build pkgbuild/$(source)_$(version).dsc
