#!/bin/sh

PATH=/usr/sbin:/usr/bin:/sbin:/bin
export PATH

verbose=0
color=0
generate=0
configfile=/etc/pov/check-health

usage="Usage: check-health [-c] [-v] [-f configfile]
       check-health -g > configfile
       check-health -h"
help="
Options:
  -c           colorize the output
  -v           be more verbose (show checks being executed)
  -f FILENAME  use a different config file (default: $configfile)
  -g           generate a config file and print to standard output
  -h           show this help message
"

libdir=.

while getopts hvcgf: OPT; do
    case "$OPT" in
        c)
            color=1
            ;;
        v)
            verbose=1
            ;;
        h)
            echo "$usage"
            echo "$help"
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

shift $((OPTIND - 1))

if [ $# -ne 0 ]; then
    echo "$usage" 1>&2
    exit 1
fi

if [ $generate -ne 0 ]; then
    . $libdir/generate.sh
    generate
    exit 0
fi

. $libdir/functions.sh || exit 1

if ! [ -f "$configfile" ]; then
    info "not performing any checks: $configfile doesn't exist"
    exit 0
fi

. "$configfile"

exit 0
