#
# Functions for pov-check-health
#

#
# Helpers
#

warn() {
    echo "$@" 1>&2
}

# convert value to seconds
# usage: x=$(_to_seconds number [default])
_to_seconds() {
    case $1 in
        "") echo $2;;
        *s) echo ${1%s};;
        *S) echo ${1%S};;
        *m) echo $((${1%m} * 60));;
        *M) echo $((${1%M} * 60));;
        *h) echo $((${1%h} * 60 * 60));;
        *H) echo $((${1%H} * 60 * 60));;
        *)  echo $1;;
    esac
}

# convert number to (metric) kilobytes
# usage: x=$(_to_kb number [default])
_to_kb() {
    case $1 in
        "") echo $2;;
        *k) echo ${1%k};;
        *K) echo ${1%K};;
        *m) echo ${1%m}000;;
        *M) echo ${1%M}000;;
        *g) echo ${1%g}000000;;
        *G) echo ${1%G}000000;;
        *t) echo ${1%t}000000000;;
        *T) echo ${1%T}000000000;;
        *)  echo $1;;
    esac
}

# convert number to (metric) megabytes
# usage: x=$(_to_mb number [default])
_to_mb() {
    case $1 in
        "") echo $2;;
        *m) echo ${1%m};;
        *M) echo ${1%M};;
        *g) echo ${1%g}000;;
        *G) echo ${1%G}000;;
        *t) echo ${1%t}000000;;
        *T) echo ${1%T}000000;;
        *)  echo $1;;
    esac
}

#
# Checks
#

# if uptime is too low, the system probably hasn't fully booted up yet,
# so it doesn't make to check that all the services have started
checkuptime() {
    want=$(_to_seconds $1 600)
    uptime=$(cut /proc/uptime -d . -f 1)
    if [ $uptime -lt $want ]; then
        exit 0
    fi
}

checkfs() {
    need=$(_to_kb $2 1000)
    free=$(df -P -k $1 | awk 'NR==2 { print $4; }')
    [ -z "$free" ] && { warn "couldn't figure out free space in $1"; return; }
    [ $free -lt $need ] && warn "$1 is low on disk space ($free)"
}

checkinodes() {
    need=${2:-5000}
    free=$(df -i $1 | awk 'NR==2 { print $4; }')
    [ $free -lt $need ] && warn "$1 is low on inodes ($free)"
}

checknfs() {
    [ -z "$(grep "$1 .* nfs " /proc/mounts)" ] && {
        warn "$1 is not NFS-mounted, trying to remount"
        mount -a -t nfs
        [ -z "$(grep "$1 .* nfs " /proc/mounts)" ] && warn "... mount -a -t nfs didn't help"
    }
}

checkpidfile() {
    [ -f $1 ] || { warn "$1: pidfile missing"; return; }
    pid="$(cat $1)"
    test -d "/proc/$pid" || warn "$1: stale pidfile ($pid)"
}

checkpidfiles() {
    for pidfile in "$@"; do
        case $pidfile in
            "/var/run/*/*.pid")
                # suppress spurious warning when this glob doesn't match anything
                ;;
            /var/run/sm-notify.pid)
                # ignore: this one is always stale, yet nothing bad happens
                ;;
            *)
                checkpidfile $pidfile
                ;;
        esac

    done
}

checkproc() {
    [ -z "$(pidof -s $1)" ] && warn "$1 is not running"
}

checkproc_pgrep() {
    [ -z "$(pgrep $1)" ] && warn "$1 is not running"
}

checkproc_pgrep_full() {
    [ -z "$(pgrep -f "$@")" ] && warn "$1 is not running"
}

checktoomanyproc() {
    [ "$(pidof $1|wc -w)" -ge "$2" ] && warn "More than $2 copies of $1 running"
}

checkram() {
    need=$(_to_mb $1 100)
    free=$(free -mt | awk '$1 ~ /^Total/ { print $4; }')
    [ $free -lt $need ] && warn "low on virtual memory ($free)"
}

checkswap() {
    trip=$(_to_mb $1 100)
    used=$(free -m| awk '/^Swap/ {print $3}')
    [ $used -gt $trip ] && warn "too much swap used ($used)"
}

checkmailq() {
    # this probably only works with postfix
    limit=${1:-20}
    status=$(mailq 2>&1| tail -n 1)
    case "$status" in
        "Mail queue is empty") return;;
        *": mailq: not found") return;;
        *) ;;
    esac
    count=$(echo "$status" | awk '{print $5;}')
    [ $count -gt $limit ] && warn "mail queue is large ($count requests)"
}

checkzopemailq() {
    for f in `find /apps/zopes/*/var/mailqueue/new -type f -mmin +1`; do
        warn "stale zope mail message: $f"
    done
}

checkcups() {
    queuename=$1
    lpq $queuename | grep -s -q "^$queuename is not ready$" && {
        warn "printer $1 is not ready, trying to enable"
        cupsenable $1
    }
}

cmpfiles() {
    file1="$1"
    file2="$2"
    cmp -s "$file1" "$file2" || {
        warn "$file1 and $file2 differ"
    }
}

checkaliases() {
    [ /etc/aliases.db -ot /etc/aliases ] && {
        warn "/etc/aliases.db out of date; run newaliases"
    }
}

checklilo() {
    [ /boot/map -ot /vmlinuz ] && warn "lilo not updated after kernel upgrade"
}
