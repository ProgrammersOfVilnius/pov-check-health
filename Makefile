source := $(shell dpkg-parsechangelog | awk '$$1 == "Source:" { print $$2 }')
version := $(shell dpkg-parsechangelog | awk '$$1 == "Version:" { print $$2 }')
date := $(shell dpkg-parsechangelog | grep ^Date: | cut -d: -f 2- | date --date="$$(cat)" +%Y-%m-%d)

VCS_STATUS = git status --porcelain

.PHONY: all
all: check-health.8 check-health

check-health.8: check-health.rst
	rst2man check-health.rst > check-health.8

check-health: check-health.sh
	sed -e 's,^libdir=\.$$,libdir=/usr/share/pov-check-health,' $< > $@

.PHONY: test check
test check: check-version check-docs
	./tests.sh

.PHONY: checkversion
check-version:
	@grep -q ":Version: $(version)" check-health.rst || { \
	    echo "Version number in check-health.rst doesn't match debian/changelog" 2>&1; \
	    exit 1; \
	}
	@grep -q ":Date: $(date)" check-health.rst || { \
	    echo "Date in check-health.rst doesn't match debian/changelog" 2>&1; \
	    exit 1; \
	}

.PHONY: check-docs
check-docs:
	@./extract-documentation.py -c README.rst -c check-health.rst || echo "Run make update-docs please"

.PHONY: update-docs
update-docs:
	./extract-documentation.py -u README.rst -u check-health.rst

.PHONY: install
install: check-health
	install -D -m 644 functions.sh $(DESTDIR)/usr/share/pov-check-health/functions.sh
	install -D -m 644 generate.sh $(DESTDIR)/usr/share/pov-check-health/generate.sh
	install -D -m 644 example.conf $(DESTDIR)/usr/share/doc/pov-check-health/check-health.example
	install -D check-health $(DESTDIR)/usr/sbin/check-health

.PHONY: source-package
source-package: all
	debuild -S -i -k$(GPGKEY)

.PHONY: upload-to-ppa
upload-to-ppa: check source-package
	@test -z "`$(VCS_STATUS) 2>&1`" || { echo; echo "Your working tree is not clean; please commit and try again" 1>&2; $(VCS_STATUS); exit 1; }
	dput ppa:pov/ppa ../$(source)_$(version)_source.changes
	git tag $(version)

.PHONY: binary-package
binary-package: all
	debuild -i -k$(GPGKEY)
