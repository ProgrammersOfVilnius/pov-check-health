#
# Command-line handling logic for pov-check-health
#

#
# The script including this must define the following variables:
# - prog -- name of the program
# - libdir -- location of library scripts
#

# shellcheck shell=sh

PATH=/usr/sbin:/usr/bin:/sbin:/bin
export PATH

verbose=0
color=0
generate=0
configfile=/etc/pov/${prog:?}

usage="Usage: $prog [-c] [-v] [-f configfile]
       $prog -g > configfile
       $prog -h"
help="
Options:
  -c           colorize the output
  -v           be more verbose (show checks being executed)
  -f FILENAME  use a different config file (default: $configfile)
  -g           generate a config file and print to standard output
  -h           show this help message
"

# parse the command line arguments
argparse() {
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
                # shellcheck disable=SC2034
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
}

run_checks() {
    # shellcheck source=functions.sh
    . "${libdir:?}"/functions.sh || exit 1

    if ! [ -f "$configfile" ]; then
        info "not performing any checks: $configfile doesn't exist"
        exit 0
    fi

    # shellcheck source=example.conf
    . "$configfile"
}
