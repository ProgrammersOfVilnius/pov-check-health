source := $(shell dpkg-parsechangelog | awk '$$1 == "Source:" { print $$2 }')
version := $(shell dpkg-parsechangelog | awk '$$1 == "Version:" { print $$2 }')

.PHONY: all
all: check-health.8

.PHONY: test check
test check: checkversion
	./tests.sh

.PHONY: checkversion
checkversion:
	@grep -q ":Version: $(version)" check-health.rst || { \
	    echo "Version number in check-health.rst doesn't match debian/changelog" 2>&1; \
	    exit 1; \
	}

check-health.8: check-health.rst
	rst2man check-health.rst > check-health.8

.PHONY: install
install:
	install -D -m 644 functions.sh $(DESTDIR)/usr/share/pov-check-health/functions.sh
	install -D -m 644 example.conf $(DESTDIR)/usr/share/doc/pov-check-health/check-health.example
	install -D check-health.sh $(DESTDIR)/usr/sbin/check-health

.PHONY: source-package
source-package:
	debuild -S -i -k$(GPGKEY)

.PHONY: upload-to-ppa
upload-to-ppa: source-package
	dput ppa:pov/ppa ../$(source)_$(version)_source.changes
	git tag $(version)

.PHONY: binary-package
binary-package:
	debuild -i -k$(GPGKEY)
