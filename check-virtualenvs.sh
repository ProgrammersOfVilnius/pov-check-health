#!/bin/sh

usage="\
Usage: check-virtualenvs [-v] [-f]
       check-virtualenvs -h"
options="
Options:
  -v  be more verbose
  -f  fix the problems by overwriting outdated Python binaries
"

verbose=0
fix=0

while getopts hvf OPT; do
    case "$OPT" in
        v)
            verbose=1
            ;;
        f)
            fix=1
            ;;
        h)
            echo "$usage"
            echo "$options"
            exit 0
            ;;
        *)
            echo "$usage" 1>&2
            exit 1
            ;;
    esac
done

warn() {
    echo "$@" 1>&2
}

info() {
    test $verbose -ne 0 && echo "$@"
}

rc=0

check() {
    binary=$1
    system=$2
    test -x $binary || return
    if cmp -s $binary $system; then
        info "$binary is up to date"
    else
        if [ $fix -ne 0 ]; then
            warn "cp $system $binary"
            cp $system $binary || rc=1
        else
            warn "$binary differs from $system"
            rc=1
        fi
    fi
}

for python in /usr/bin/python[23].[0-9]; do
    python=${python#/usr/bin/}
    info "looking for $python virtualenvs"
    for libdir in $(locate -r /lib/$python$ | grep -vE "^/usr/(local/)?lib/$python|^/usr/lib/debug/"); do
        latest_python_in_this_venv=$(ls ${libdir%/$python}|tail -n 1)
        if [ "$latest_python_in_this_venv" = pkgconfig ]; then
            : # this is a full Python installation, not a virtualenv
        elif [ $python != "$latest_python_in_this_venv" ]; then
            binary=${libdir%/lib/$python}/bin/python
            if [ -x $binary ]; then
                warn "${libdir%/lib/$python}/lib has multiple python versions, cannot check $binary"
            fi
            check ${libdir%/lib/$python}/bin/$python /usr/bin/$python
        else
            check ${libdir%/lib/$python}/bin/python /usr/bin/$python
            check ${libdir%/lib/$python}/bin/$python /usr/bin/$python
        fi
    done
done

exit $rc
