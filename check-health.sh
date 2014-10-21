#!/bin/sh

PATH=/usr/sbin:/usr/bin:/sbin:/bin
export PATH

usage="Usage: check-health [-v] [-f configfile]
       check-health -g > configfile
       check-health -h"

verbose=0
generate=0
configfile=/etc/pov/check-health

libdir=.

while getopts hvgf: OPT; do
    case "$OPT" in
        v)
            verbose=1
            ;;
        h)
            echo "$usage"
            exit 0
            ;;
        g)
            generate=1
            ;;
        f)
            configfile=$OPTARG
            ;;
        *)
            echo "$usage" 1>&2
            exit 1
            ;;
    esac
done

shift $(($OPTIND - 1))

if [ $# -ne 0 ]; then
    echo $usage 1>&2
    exit 1
fi

if [ $generate -ne 0 ]; then
    . $libdir/generate.sh
    generate
    exit 0
fi

. $libdir/functions.sh || exit 1

if ! [ -f $configfile ]; then
    info "not performing any checks: $configfile doesn't exit"
    exit 0
fi

. $configfile

exit 0
