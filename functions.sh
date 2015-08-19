#
# Functions for pov-check-health
#

#
# Helpers
#

purple=
red=
reset=
line_up=
if [ -t 1 ] && [ "$(tput colors)" -ge 8 ]; then
    purple='\033[35m'
    red='\033[31m'
    reset='\033[0m'
fi
if [ -t 1 ] && [ -t 2 ]; then
    line_up='\033[A'
fi
if [ -z "$verbose" ]; then
    verbose=0
fi

warn() {
    printf "%s\n" "$*" 1>&2
}

info() {
    if [ $verbose -gt 0 ]; then
        printf "%s\n" "$*"
    fi
}

info_check() {
    if [ $verbose -gt 0 ]; then
        printf "${purple}+ %s${reset}\n" "$*"
    fi
}

warn_check() {
    if [ $verbose -eq 0 ]; then
        printf "${red}+ %s${reset}\n" "$*" 1>&2
    else
        printf "${line_up}${red}+ %s${reset}\n" "$*" 1>&2
    fi
}


# convert value to seconds
# usage: x=$(_to_seconds number [default])
_to_seconds() {
    case $1 in
        "") echo "$2";;
        *sec) echo "${1%sec}";;
        *s) echo "${1%s}";;
        *S) echo "${1%S}";;
        *min) echo $((${1%min} * 60));;
        *m) echo $((${1%m} * 60));;
        *M) echo $((${1%M} * 60));;
        *hour) echo $((${1%hour} * 60 * 60));;
        *h) echo $((${1%h} * 60 * 60));;
        *H) echo $((${1%H} * 60 * 60));;
        *)  echo "$1";;
    esac
}

# convert number to (metric) kilobytes
# usage: x=$(_to_kb number [default])
_to_kb() {
    case $1 in
        "") echo "$2";;
        *k) echo "${1%k}";;
        *K) echo "${1%K}";;
        *m) echo "${1%m}000";;
        *M) echo "${1%M}000";;
        *g) echo "${1%g}000000";;
        *G) echo "${1%G}000000";;
        *t) echo "${1%t}000000000";;
        *T) echo "${1%T}000000000";;
        *)  echo "$1";;
    esac
}

# convert number to (metric) megabytes
# usage: x=$(_to_mb number [default])
_to_mb() {
    case $1 in
        "") echo "$2";;
        *m) echo "${1%m}";;
        *M) echo "${1%M}";;
        *g) echo "${1%g}000";;
        *G) echo "${1%G}000";;
        *t) echo "${1%t}000000";;
        *T) echo "${1%T}000000";;
        *)  echo "$1";;
    esac
}

#
# Checks
#

# checkuptime [<uptime>[s/m/h/sec/min/hour]]
#   Skip the rest of the checks if system uptime is less than N
#   seconds/minutes/hours.
#
#   <uptime> defaults to 10 minutes.
#
#   Example: checkuptime 10m
checkuptime() {
    info_check checkuptime "$@"
    want=$(_to_seconds "$1" 600)
    uptime=$(cut /proc/uptime -d . -f 1)
    if [ "$uptime" -lt "$want" ]; then
        info "uptime less than $want seconds, skipping the rest of the checks"
        exit 0
    fi
}

# checkfs <mountpoint> [<amount>[K/M/G/T]]
#   Check that the filesystem mounted on <mountpoint> has at least <amount>
#   of metric kilo/mega/giga/terabytes free.
#
#   <amount> defaults to 1M.
#
#   Example: checkfs / 100M
checkfs() {
    info_check checkfs "$@"
    need=$(_to_kb "$2" 1000)
    free=$(df -P -k "$1" | awk 'NR==2 { print $4; }')
    [ -z "$free" ] && { warn "couldn't figure out free space in $1"; return; }
    [ "$free" -lt "$need" ] && warn "$1 is low on disk space ($free)"
}

# checkinodes <mountpoint> [<inodes>]
#   Check that the filesystem mounted on <mountpoint> has at least <inodes>
#   of free inodes left.
#
#   <inodes> defaults to 5000.
#
#   Example: checkinodes /
checkinodes() {
    info_check checkinodes "$@"
    need=${2:-5000}
    free=$(df -P -i "$1" | awk 'NR==2 { print $4; }')
    [ "$free" -lt "$need" ] && warn "$1 is low on inodes ($free)"
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
    info_check checknfs "$@"
    if [ -z "$(grep "$1 .* nfs4\? " /proc/mounts)" ]; then
        warn "$1 is not NFS-mounted, trying to remount"
        mount -a -t nfs
        if [ -z "$(grep "$1 .* nfs4\? " /proc/mounts)" ]; then
            warn "... mount -a -t nfs didn't help"
        else
            warn "... mount -a -t nfs helped"
        fi
    fi
}

# checkpidfile <filename>
#   Check that the process listed in a given pidfile is running.
#
#   Example: checkpidfile /var/run/crond.pid
checkpidfile() {
    info_check checkpidfile "$@"
    [ -f "$1" ] || { warn "$1: pidfile missing"; return; }
    for pid in $(cat "$1"); do
        test -d "/proc/$pid" || warn "$1: stale pidfile ($pid)"
    done
}

# checkpidfiles <filename> ...
#   Check that the processes listed in given pidfiles are running.
#
#   Suppresses warnings for /var/run/sm-notify.pid because it feels like a
#   false positive.
#
#   Suppresses warnings for failed glob expansion under /run or /var/run.
#
#   Example: checkpidfiles /var/run/*.pid /var/run/*/*.pid
checkpidfiles() {
    for pidfile in "$@"; do
        case $pidfile in
            "/run/*.pid"|"/var/run/*.pid"|"/run/*/*.pid"|"/var/run/*/*.pid")
                # suppress spurious warning when this glob doesn't match anything
                info "ignoring $pidfile since glob failed to match"
                ;;
            /var/run/sm-notify.pid)
                # ignore: this one is always stale, yet nothing bad happens
                info "ignoring $pidfile since it's always stale"
                ;;
            *)
                checkpidfile "$pidfile"
                ;;
        esac
    done
}

# checkproc <name>
#   Check that a process with a given name is running.
#
#   See also: checkproc_pgrep, checkproc_pgrep_full.
#
#   Example: checkproc crond
checkproc() {
    info_check checkproc "$@"
    [ -z "$(pidof -s -x "$1")" ] && warn "$1 is not running"
}

# checkproc_pgrep <name>
#   Check that a process with a given name is running.
#
#   Uses pgrep instead of pidof.
#
#   Example: checkproc_pgrep tracd
checkproc_pgrep() {
    info_check checkproc_pgrep "$@"
    [ -z "$(pgrep "$1")" ] && warn "$1 is not running"
}

# checkproc_pgrep_full <cmdline>
#   Check that a process matching a given command line is running.
#
#   Uses pgrep -f instead of pidof, which makes it handle all sorts of things.
#
#   Example: checkproc_pgrep_full scriptname.py
#   Example: checkproc_pgrep_full '/usr/bin/java -jar /usr/share/jenkins/jenkins.war'
checkproc_pgrep_full() {
    info_check checkproc_pgrep_full "$@"
    [ -z "$(pgrep -f "$@")" ] && warn "$1 is not running"
}

# checktoomanyproc <name> <limit>
#   Check that fewer than <limit> instances of a given process is running.
#
#   See also: checktoomanyproc_pgrep, checktoomanyproc_pgrep_full.
#
#   Example: checktoomanyproc aspell 2
checktoomanyproc() {
    info_check checktoomanyproc "$@"
    n=$(pidof -x "$1"|wc -w)
    [ "$n" -ge "$2" ] && warn "More than $(($2-1)) copies ($n) of $1 running"
}

# checktoomanyproc_pgrep <name> <limit>
#   Check that fewer than <limit> instances of a given process is running.
#
#   Uses pgrep instead of pidof.
#
#   Example: checktoomanyproc_pgrep tracd 2
checktoomanyproc_pgrep() {
    info_check checktoomanyproc_pgrep "$@"
    out=$(pgrep "$1")
    case "$out" in
        Usage:*)
            warn "pgrep $1 failed: $out"
            return
            ;;
    esac
    n=$(echo "$out"|wc -w)
    [ "$n" -ge "$2" ] && warn "More than $(($2-1)) copies ($n) of $1 running"
}

# checktoomanyproc_pgrep_full <limit> <cmdline>
#   Check that fewer than <limit> instances of a given process is running.
#
#   Uses pgrep -f instead of pidof, which makes it handle all sorts of things.
#
#   Example: checktoomanyproc_pgrep_full 2 scriptname.py
#   Example: checktoomanyproc_pgrep_full 2 '/usr/bin/java -jar /usr/share/jenkins/jenkins.war'
checktoomanyproc_pgrep_full() {
    info_check checktoomanyproc_pgrep_full "$@"
    limit=$1
    shift
    out=$(pgrep -f "$@")
    case "$out" in
        Usage:*)
            warn "pgrep -f $* failed: $out"
            return
            ;;
    esac
    n=$(echo "$out"|wc -w)
    [ "$n" -ge "$limit" ] && warn "More than $((limit-1)) copies ($n) of $* running"
}

# checkram [<free>[M/G/T]]
#   Check that at least <free> metric mega/giga/terabytes of virtual memory are
#   free.
#
#   <free> defaults to 100 megabytes.
#
#   Example: checkram 100M
checkram() {
    info_check checkram "$@"
    need=$(_to_mb "$1" 100)
    free=$(free -mt | awk '$1 ~ /^Total/ { print $4; }')
    [ "$free" -lt "$need" ] && warn "low on virtual memory ($free)"
}

# checkswap [<limit>[M/G/T]]
#   Check if more than <limit> metric mega/giga/terabytes of swap are used.
#
#   <limit> defaults to 100 megabytes.
#
#   Example: checkswap 2G
checkswap() {
    info_check checkswap "$@"
    trip=$(_to_mb "$1" 100)
    used=$(free -m| awk '/^Swap/ {print $3}')
    [ "$used" -gt "$trip" ] && warn "too much swap used (${used}M)"
}

# checkmailq [<limit>]
#   Check if more than <limit> emails are waiting in the outgoing mail queue.
#
#   <limit> defaults to 20.
#
#   The check is silently skipped if you don't have any MTA (that provides a
#   mailq command) installed.  Otherwise it probably works only with Postfix.
#
#   Example: checkmailq 100
checkmailq() {
    info_check checkmailq "$@"
    limit=${1:-20}
    status=$(mailq 2>&1| tail -n 1)
    case "$status" in
        "Mail queue is empty")
            return
            ;;
        *": mailq: not found")
            info "mailq not found, skipping check"
            return
            ;;
        *"Total requests:"*)
            # sendmail
            count=$(echo "$status" | awk '{print $3;}')
            ;;
        "-- "*" Kbytes in "*" Request."|"-- "*" Kbytes in "*" Requests.")
            # postfix
            count=$(echo "$status" | awk '{print $5;}')
            ;;
        *)
            info "mailq output format not recognized, skipping check"
            return
            ;;
    esac
    [ "$count" -gt "$limit" ] && warn "mail queue is large ($count requests)"
}

# checkzopemailq <path> ...
#   Check if any messages older than one minute are present in the outgoing
#   maildir used by zope.sendmail.
#
#   <path> needs to refer to the 'new' subdirectory of the mail queue.
#
#   Example: checkzopemailq /apps/zopes/*/var/mailqueue/new
checkzopemailq() {
    info_check checkzopemailq "$@"
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
    info_check checkcups "$@"
    queuename=$1
    lpq "$queuename" | grep -s -q "^$queuename is not ready$" && {
        warn "printer $1 is not ready, trying to enable"
        cupsenable "$1"
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
    info_check cmpfiles "$@"
    file1="$1"
    file2="$2"
    cmp -s "$file1" "$file2" || {
        warn "$file1 and $file2 differ"
    }
}

# checkaliases
#   Check if /etc/aliases.db is up to date.
#
#   Probably works only with Postfix, and only if you use the default database
#   format.
#
#   Background: when you edit /etc/aliases it's so easy to forget to run
#   newaliases.
#
#   Example: checkaliases
checkaliases() {
    info_check checkaliases "$@"
    [ /etc/aliases.db -ot /etc/aliases ] && {
        warn "/etc/aliases.db out of date; run newaliases"
    }
}

# checklilo
#   Check if LILO was run after a kernel update.
#
#   Background: if you don't re-run LILO after you update your kernel, your
#   machine will not boot.  We had to use LILO on one server because GRUB
#   completely refused to boot from the Software RAID-1 root partition.
#
#   Example: checklilo
checklilo() {
    info_check checklilo "$@"
    [ /boot/map -ot /vmlinuz ] && warn "lilo not updated after kernel upgrade"
}


# checkweb
#   Check if a website is available over HTTP/HTTPS.
#
#   A thin wrapper around check_http from nagios-plugins-basic.  See
#   https://www.monitoring-plugins.org/doc/man/check_http.html for the
#   available options.
#
#   Normally you wouldn't use this from /etc/pov/check-web-health, and
#   not from /etc/pov/check-health.
#
#   Example: checkweb -H www.example.com
#   Example: checkweb --ssl -H www.example.com -u /prefix/ -f follow -s 'Expect this string' --timeout=30
#   Example: checkweb --ssl -H www.example.com -u /protected/ -e 'HTTP/1.1 401 Unauthorized' -s 'Login required'
#   Example: checkweb --ssl -H www.example.com --invert-regex -r "Database connection error"
checkweb() {
    info_check checkweb "$@"
    output=$(/usr/lib/nagios/plugins/check_http "$@" 2>&1)
    case "$output" in
        HTTP\ OK:*)
            info "$output"
            ;;
        CRITICAL\ -\ Socket\ timeout\ after\ *)
            warn_check checkweb "$@"
            warn "$output"
            load=$(LC_ALL=C uptime|sed -e 's/^.*load/load/')
            warn "$load"
            ;;
        *)
            warn_check checkweb "$@"
            warn "$output"
            ;;
    esac
}

# checkweb_auth
#   Check if a website is available over HTTP/HTTPS.
#
#   ``checkweb_auth user:pwd args`` is equivalent to
#   ``checkweb -a user:pwd args`` but the username/password pair is not
#   printed if the check fails or in verbose mode.
#
#   (It's still visible to any local system user who can run 'ps' while
#   check-web-health is running.)
#
#   Example: checkweb_auth username:password -H www.example.com
checkweb_auth() {
    creds="$1"
    shift
    info_check checkweb_auth "*secret*" "$@"
    output=$(/usr/lib/nagios/plugins/check_http -a "$creds" "$@" 2>&1)
    case "$output" in
        HTTP\ OK:*)
            info "$output"
            ;;
        CRITICAL\ -\ Socket\ timeout\ after\ *)
            warn_check checkweb_auth "*secret*" "$@"
            warn "$output"
            load=$(LC_ALL=C uptime|sed -e 's/^.*load/load/')
            warn "$load"
            ;;
        *)
            warn_check checkweb_auth "*secret*" "$@"
            warn "$output"
            ;;
    esac
}
