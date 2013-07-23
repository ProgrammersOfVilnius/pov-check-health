#!/bin/sh

PATH=/usr/sbin:/usr/bin:/sbin:/bin
export PATH

usage="Usage: check-health [-h] [-v] [-f configfile]"

verbose=0
configfile=/etc/pov/check-health

while getopts hvf: OPT; do
    case "$OPT" in
        v)
            verbose=1
            ;;
        h)
            echo $usage
            exit 0
            ;;
        f)
            configfile=$OPTARG
            ;;
        *)
            echo $usage 1>&2
            exit 1
            ;;
    esac
done

shift $(($OPTIND - 1))

if [ $# -ne 0 ]; then
    echo $usage 1>&2
    exit 1
fi

. /usr/share/pov-check-health/functions.sh

if ! [ -f $configfile ]; then
    info "not performing any checks: $configfile doesn't exit"
    exit 0
fi

. $configfile

exit 0
