#
# Functions for pov-check-health
#

#
# Helpers
#

purple=
reset=
if [ -t 1 ] && [ $(tput colors) -ge 8 ]; then
    purple='\033[35m'
    reset='\033[0m'
fi

warn() {
    echo "$@" 1>&2
}

info() {
    if [ $verbose -gt 0 ]; then
        echo "$@"
    fi
}

info_check() {
    if [ $verbose -gt 0 ]; then
        echo "${purple}+ $@${reset}"
    fi
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

# checkuptime [<uptime>[s/m/h]]
#   Skip the rest of the checks if system uptime is less than N
#   seconds/minutes/hours
#
#   <uptime> defaults to 10 minutes
#
#   Example: checkuptime 10m
checkuptime() {
    info_check checkuptime $@
    want=$(_to_seconds $1 600)
    uptime=$(cut /proc/uptime -d . -f 1)
    if [ $uptime -lt $want ]; then
        info "uptime less than $want seconds, skipping the rest of the checks"
        exit 0
    fi
}

# checkfs <mountpoint> [<amount>[K/M/G/T]]
#   Check that the filesystem mounted on <mountpoint> has at least <amount>
#   of metric kilo/mega/giga/terabytes free.
#
#   <amount> defaults to 1M
#
#   Example: checkfs / 100M
checkfs() {
    info_check checkfs $@
    need=$(_to_kb $2 1000)
    free=$(df -P -k $1 | awk 'NR==2 { print $4; }')
    [ -z "$free" ] && { warn "couldn't figure out free space in $1"; return; }
    [ $free -lt $need ] && warn "$1 is low on disk space ($free)"
}

# checkinodes <mountpoint> [<inodes>]
#   Check that the filesystem mounted on <mountpoint> has at least <inodes>
#   of free inodes left.
#
#   <inodes> defaults to 5000
#
#   Example: checkinodes /
checkinodes() {
    info_check checkinodes $@
    need=${2:-5000}
    free=$(df -P -i $1 | awk 'NR==2 { print $4; }')
    [ $free -lt $need ] && warn "$1 is low on inodes ($free)"
}

# checknfs <mountpoint>
#   Check that an NFS file system is mounted on <mountpoint>.
#
#   If not, try to mount all NFS filesystems.
#
#   Used as a workaround for an Ubuntu issue where NFS filesystems would fail
#   to mount during boot, but would mount fine afterwards.
#
#   This hasn't been a problem lately.
#
#   Example: checknfs /home
checknfs() {
    info_check checknfs $@
    [ -z "$(grep "$1 .* nfs " /proc/mounts)" ] && {
        warn "$1 is not NFS-mounted, trying to remount"
        mount -a -t nfs
        [ -z "$(grep "$1 .* nfs " /proc/mounts)" ] && warn "... mount -a -t nfs didn't help"
    }
}

# checkpidfile <filename>
#   Check that the process listed in a given pidfile is running.
#
#   Example: checkpidfile /var/run/crond.pid
checkpidfile() {
    info_check checkpidfile $@
    [ -f $1 ] || { warn "$1: pidfile missing"; return; }
    pid="$(cat $1)"
    test -d "/proc/$pid" || warn "$1: stale pidfile ($pid)"
}

# checkpidfiles <filename> ...
#   Check that the process listed in given pidfiles are running.
#
#   Example: checkpidfiles /var/run/*.pid /var/run/*/*.pid
checkpidfiles() {
    for pidfile in "$@"; do
        case $pidfile in
            "/var/run/*/*.pid")
                # suppress spurious warning when this glob doesn't match anything
                info "ignoring $pidfile since glob failed to match"
                ;;
            /var/run/sm-notify.pid)
                # ignore: this one is always stale, yet nothing bad happens
                info "ignoring $pidfile since it's always stale"
                ;;
            *)
                checkpidfile $pidfile
                ;;
        esac

    done
}

# checkproc <name>
#   Check that a process with a given name is running.
#
#   See also: checkproc_pgrep, checkproc_pgrep_full
#
#   Example: checkproc crond
checkproc() {
    info_check checkproc $@
    [ -z "$(pidof -s $1)" ] && warn "$1 is not running"
}

# checkproc_pgrep <name>
#   Check that a process with a given name is running.
#
#   Uses pgrep instead of pidof, which makes it handle scripts too.

#   (XXX why didn't I use pidof -x?  ignorance?)
#
#   Example: checkproc_pgrep tracd
checkproc_pgrep() {
    info_check checkproc_pgrep $@
    [ -z "$(pgrep $1)" ] && warn "$1 is not running"
}

# checkproc_pgrep_full <cmdline>
#   Check that a process matching a given command line is running.
#
#   Uses pgrep -f instead of pidof, which makes it handle all sorts of things.
#
#   Example: checkproc_pgrep_full scriptname.py
#   Example: checkproc_pgrep_full '/usr/bin/java -jar /usr/share/jenkins/jenkins.war'
checkproc_pgrep_full() {
    info_check checkproc_pgrep_full $@
    [ -z "$(pgrep -f "$@")" ] && warn "$1 is not running"
}

# checktoomanyproc <name> <limit>
#   Check that fewer than <limit> instances of a given process is running.
#
#   Example: checktoomanyproc aspell 2
checktoomanyproc() {
    info_check checktoomanyproc $@
    [ "$(pidof $1|wc -w)" -ge "$2" ] && warn "More than $2 copies of $1 running"
}

# checkram [<free>[M/G/T]]
#   Check that at least <free> metric mega/giga/terabytes of virtual memory are
#   free.
#
#   <free> defaults to 100 megabytes
#
#   Example: checkram 100M
checkram() {
    info_check checkram $@
    need=$(_to_mb $1 100)
    free=$(free -mt | awk '$1 ~ /^Total/ { print $4; }')
    [ $free -lt $need ] && warn "low on virtual memory ($free)"
}

# checkswap [<limit>[M/G/T]]
#   Check if more than <limit> metric mega/giga/terabytes of swap are used.
#
#   <limit> defaults to 100 megabytes
#
#   Example: checkswap 2G
checkswap() {
    info_check checkswap $@
    trip=$(_to_mb $1 100)
    used=$(free -m| awk '/^Swap/ {print $3}')
    [ $used -gt $trip ] && warn "too much swap used ($used)"
}

# checkmailq [<limit>]
#   Check if more than <limit> emails are waiting in the outgoing mail queue.
#
#   <limit> defaults to 20
#
#   The check is silently skipped if you don't have any MTA (that provides a
#   mailq command) installed.  Otherwise it probably works only with Postfix.
#
#   Example: checkmailq 100
checkmailq() {
    info_check checkmailq $@
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

# checkzopemailq <path> ...
#   Check if any messages older than one minute are present in the outgoing
#   maildir used by zope.sendmail.
#
#   <path> needs to refer to the 'new' subdirectory of the mail queue.
#
#   Example: checkzopemailq /apps/zopes/*/var/mailqueue/new
checkzopemailq() {
    info_check checkzopemailq $@
    for f in $(find "$@" -type f -mmin +1); do
        warn "stale zope mail message: $f"
    done
}

# checkcups <queuename>
#   Check if the printer is ready.
#
#   Try to enable it if it became disabled.
#
#   Background: I had this issue with CUPS randomly disabling a particular mail
#   queue after it couldn't talk to the printer for a while due to network
#   issues or something.  Manually reenabling the printer got old fast.
#   This hasn't been a problem lately.
#
#   Example: checkcups cheese
checkcups() {
    info_check checkcups $@
    queuename=$1
    lpq $queuename | grep -s -q "^$queuename is not ready$" && {
        warn "printer $1 is not ready, trying to enable"
        cupsenable $1
    }
}

# cmpfiles <pathname1> <pathname2>
#   Check if the two files are identical.
#
#   Background: there were some init.d scripts that were writable by a non-root
#   user.  I wanted to do manual inspection before replacing copies of them
#   into /etc/init.d/.
#
#   Example: cmpfiles /etc/init.d/someservice /home/someservice/initscript
cmpfiles() {
    info_check cmpfiles $@
    file1="$1"
    file2="$2"
    cmp -s "$file1" "$file2" || {
        warn "$file1 and $file2 differ"
    }
}

# checkaliases
#   Check if /etc/aliases.db is up to date
#
#   Probably works only with Postfix, and only if you use the default database
#   format.
#
#   Background: when you edit /etc/aliases it's so easy to forget to run
#   newaliases.
#
#   Example: checkaliases
checkaliases() {
    info_check checkaliases $@
    [ /etc/aliases.db -ot /etc/aliases ] && {
        warn "/etc/aliases.db out of date; run newaliases"
    }
}

# checklilo
#   Check if LILO was run after a kernel update
#
#   Background: if you don't re-run LILO after you update your kernel, your
#   machine will not boot.  We had to use LILO on one server because GRUB
#   completely refused to boot from the Software RAID-1 root partition.
#
#   Example: checklilo
checklilo() {
    info_check checklilo $@
    [ /boot/map -ot /vmlinuz ] && warn "lilo not updated after kernel upgrade"
}
