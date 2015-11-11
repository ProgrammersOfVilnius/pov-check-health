#!/bin/sh

prog=check-web-health
libdir=.

. $libdir/cmdline.sh || exit 1
argparse "$@"

if [ $generate -ne 0 ]; then
    . $libdir/generate.sh
    generate_config_for_check_web_health
    exit 0
fi

run_checks
exit 0
