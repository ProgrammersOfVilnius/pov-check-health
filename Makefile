version := $(shell dpkg-parsechangelog | awk '$$1 == "Version:" { print $$2 }')

.PHONY: all
all:

.PHONY: install
install:
	install -D -m 644 functions.sh $(DESTDIR)/usr/share/pov-check-health/functions.sh
	install -D -m 644 example.conf $(DESTDIR)/etc/pov/check-health
	install -D check-health.sh $(DESTDIR)/usr/sbin/check-health

.PHONY: source-package
source-package:
	debuild -S -i -k$(GPGKEY)

.PHONY: upload-to-ppa
upload-to-ppa: source-package
	dput ppa:mgedmin/ppa ../pov-check-health_$(version)_source.changes
	git tag $(version)

.PHONY: binary-package
binary-package:
	debuild -i -k$(GPGKEY)
