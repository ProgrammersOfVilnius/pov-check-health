#!/bin/sh

. "$(dirname "$0")/functions.sh"
. "$(dirname "$0")/generate.sh"

n_tests=0

assertEqual() {
    fn=$1
    shift
    if [ x"$1" = x"=" ]; then
        args="$fn"
        actual=$($fn)
        expected=$2
    elif [ x"$2" = x"=" ]; then
        args="$fn $1"
        actual=$($fn "$1")
        expected=$3
    elif [ x"$3" = x"=" ]; then
        args="$fn $1 $2"
        actual=$($fn "$1" "$2")
        expected=$4
    else
        warn "expected one of these forms:"
        warn "  assertEqual fn = value"
        warn "  assertEqual fn arg = value"
        warn "  assertEqual fn arg1 arg2 = value"
        warn "got"
        warn "  assertEqual $fn $*"
        exit 1
    fi
    if ! [ x"$actual" = x"$expected" ]; then
        warn "assertion failure: $args == $actual (expected $expected)"
        exit 1
    fi
    n_tests=$((n_tests + 1))
}

assertEqual _to_seconds 14 = 14
assertEqual _to_seconds 14s = 14
assertEqual _to_seconds 14S = 14
assertEqual _to_seconds 14sec = 14
assertEqual _to_seconds 27m = 1620
assertEqual _to_seconds 27M = 1620
assertEqual _to_seconds 27min = 1620
assertEqual _to_seconds 1h = 3600
assertEqual _to_seconds 3H = 10800
assertEqual _to_seconds 2hour = 7200
assertEqual _to_seconds "" 100 = 100

assertEqual _to_kb 14 = 14
assertEqual _to_kb 15k = 15
assertEqual _to_kb 15K = 15
assertEqual _to_kb 14m = 14000
assertEqual _to_kb 14M = 14000
assertEqual _to_kb 27g = 27000000
assertEqual _to_kb 27G = 27000000
assertEqual _to_kb 1t = 1000000000
assertEqual _to_kb 3T = 3000000000
assertEqual _to_kb "" 1000 = 1000

assertEqual _to_mb 14 = 14
assertEqual _to_mb 14m = 14
assertEqual _to_mb 14M = 14
assertEqual _to_mb 27g = 27000
assertEqual _to_mb 27G = 27000
assertEqual _to_mb 1t = 1000000
assertEqual _to_mb 3T = 3000000
assertEqual _to_mb "" 1000 = 1000

_test() { emit "a"; }
assertEqual _test = "a"

_test() { prefix "b"; emit "c"; }
assertEqual _test = "b
c"

_test() { prefix "d"; prefix "e"; emit "f"; }
assertEqual _test = "d

e
f"

_test() { prefix "g"; emit "h"; prefix "i"; emit "j"; }
assertEqual _test = "g
h

i
j"

assertEqual emit "foo" = "foo"

echo "$(basename "$0"): all $n_tests tests passed"
