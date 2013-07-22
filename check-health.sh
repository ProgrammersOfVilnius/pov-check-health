#!/bin/sh

PATH=/usr/sbin:/usr/bin:/sbin:/bin
export PATH

test -f /etc/pov/check-health || exit 0

. /usr/share/pov-check-health/functions.sh

. /etc/pov/check-health

exit 0
