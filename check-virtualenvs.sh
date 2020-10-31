#!/bin/bash

usage="\
Usage: check-virtualenvs [-v] [-f|-n]
       check-virtualenvs -h"
options="
Options:
  -v  be more verbose
  -f  fix the problems by overwriting outdated Python binaries
  -n  print the cp commands but do not execute them
"

verbose=0
fix=0
dry_run=0

while getopts hvfn OPT; do
    case "$OPT" in
        v)
            verbose=1
            ;;
        f)
            fix=1
            ;;
        n)
            dry_run=1
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

purple=
green=
red=
blue=
reset=
if [ -t 1 ] && [ "$(tput colors)" -ge 8 ]; then
    purple='\033[35m'
    green='\033[32m'
    red='\033[31m'
    cyan='\033[36m'
    reset='\033[0m'
fi

info() {
    test $verbose -gt 0 && printf "%s\\n" "$*"
}

info_looking() {
    test $verbose -gt 0 && printf "${purple}%s${reset}\\n" "$*"
}

info_good() {
    test $verbose -gt 0 && printf "${green}%s${reset}\\n" "$*"
}

info_action() {
    printf "${cyan}%s${reset}\\n" "$*"
}

warn() {
    printf "${red}%s${reset}\\n" "$*" 1>&2
}

rc=0

check() {
    binary=$1
    system=$2
    test -x "$binary" || return
    test -L "$binary" && return
    if cmp -s "$binary" "$system"; then
        info_good "$binary is up to date"
    else
        if [ $dry_run -ne 0 ]; then
            echo "cp $system $binary"
        elif [ $fix -ne 0 ]; then
            info_action "cp $system $binary"
            cp "$system" "$binary" || rc=1
        else
            warn "$binary differs from $system"
            rc=1
        fi
    fi
}

checkifone() {
    binary=$1
    system=$2
    versions=$3
    test -x "$binary" || return
    test -L "$binary" && return
    if [ "$versions" -ne 1 ]; then
        warn "${binary%/bin/python*}/lib has multiple python versions, cannot check $binary"
    else
        check "$binary" "$system"
    fi
}

ignore="\
^/usr/(local/)?lib/python|\
^/usr/lib/debug/|\
^/var/lib/docker/|\
^/var/lib/flatpak/|\
\\.local/share/flatpak/|\
\\.steam/|\
^/var/lib/lxd/|\
^/snap/\
"

info_looking "looking for virtualenvs"
locate -r "/lib/python[2-3][.][0-9][0-9]*$" | grep -vE "$ignore" | \
while read -r libdir; do
    python=${libdir##*/}        # /path/to/venv/lib/python3.8 -> python3.8
    major=${python%.*}          # python3.4 -> python3
    libdir=${libdir%/$python}   # /path/to/venv/lib
    envdir=${libdir%/lib}       # /path/to/venv
    if [ -e "$libdir/pkgconfig" ]; then
        info "skipping $envdir, it looks like a full Python installation"
        continue
    fi
    # shellcheck disable=SC2010
    versions=$(ls "$libdir"|grep -c ^python)
    # shellcheck disable=SC2010
    minor_versions=$(ls "$libdir"|grep -c "^$major")
    checkifone "$envdir/bin/python" "/usr/bin/$python" "$versions"
    checkifone "$envdir/bin/$major" "/usr/bin/$python" "$minor_versions"
    check "$envdir/bin/$python" "/usr/bin/$python"
done

exit $rc
