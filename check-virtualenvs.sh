#!/bin/sh

verbose=0

if [ x"$1" = x"-v" ]; then
    verbose=1
fi

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
        warn "$binary differs from $system"
        rc=1
    fi
}

for python in /usr/bin/python[23].[0-9]; do
    python=${python#/usr/bin/}
    info "looking for $python virtualenvs"
    for libdir in $(locate -r /lib/$python$ | grep -vE "^/usr/(local/)?lib/$python"); do
        latest_python_in_this_venv=$(ls ${libdir%/$python}|tail -n 1)
        if test $python != "$latest_python_in_this_venv"; then
            info "${libdir%/lib/$python}/lib has multiple python versions"
        else
            check ${libdir%/lib/$python}/bin/python /usr/bin/$python
            check ${libdir%/lib/$python}/bin/$python /usr/bin/$python
        fi
    done
done

exit $rc
