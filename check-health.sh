#!/bin/sh

PATH=/usr/sbin:/usr/bin:/sbin:/bin
export PATH

configfile=/etc/pov/check-health

. /usr/share/pov-check-health/functions.sh

if [ x"$1" = x"-v" ]; then
    verbose=1
    shift
fi

if ! [ -f $configfile ]; then
    info "not performing any checks: $configfile doesn't exit"
    exit 0
fi

. $configfile

exit 0
