#
# Generate config file for pov-check-health
#

# shellcheck shell=sh

pending=
prefix_called=0

prefix() {
    if [ $prefix_called -ne 0 ]; then
        pending="$pending
$*
"
    else
        pending="$*
"
        prefix_called=1
    fi
}

emit() {
    if [ -n "$pending" ]; then
        printf "%s" "$pending"
        pending=
    fi
    printf "%s\\n" "$*"
}

separator() {
    prefix "
"
}

generate_checkfs() {
    prefix "# Check free disk space"
    df -PT | { read -r header; while read -r device fstype size used free capacity mountpoint; do
        case $fstype in
            tmpfs|devtmpfs|ecryptfs|nfs|nfs4|cifs|vboxsf|squashfs)
                ;;
            *)
                if [ "$free" -gt 1048576 ]; then
                    emit "checkfs $mountpoint		1G"
                else
                    emit "checkfs $mountpoint		100M"
                fi
                ;;
        esac
    done; }
    pending=
}

generate_checkinodes() {
    prefix "# Check free inodes"
    # shellcheck disable=SC2034
    df -PT | { read -r header; while read -r device fstype size used free capacity mountpoint; do
        case $fstype in
            tmpfs|devtmpfs|ecryptfs|nfs|nfs4|cifs|vboxsf|squashfs)
                ;;
            *)
                emit checkinodes "$mountpoint"
                ;;
        esac
    done; }
    pending=
}

generate_checkpidfiles() {
    prefix "# Check for stale pidfiles"
    emit "checkpidfiles /var/run/*.pid /var/run/*/*.pid"
}

generate_checkproc() {
    prefix "# Check that processes are running"
    ps --ppid 1 -o comm= | LC_ALL=C sort -u | while read -r cmd; do
        case $cmd in
            kthreadd/*)
                ;;
            dhclient|dhclient3)
                # these come and go, I assume
                ;;
            console-kit-dae)
                # truncated process name won't work with checkproc
                ;;
            upstart-*)
                # truncated upstart helper process names won't work with
                # checkproc; besides I'm not sure I want to explicitly
                # check for implementation details of /sbin/init...
                ;;
            master)
                emit "checkproc master # postfix"
                ;;
            collectdmon)
                emit checkproc "$cmd"
                emit checkproc collectd
                # two collectds will fill up syslog with rrd errors
                emit checktoomanyproc collectd 2
                ;;
            screen|tmux)
                # probably transient
                ;;
            /usr/sbin/postg)
                # this is horrible, but neither checkproc nor checkproc_pgrep
                # postgrey work
                emit checkproc_pgrep_full '^/usr/sbin/postgrey'
                ;;
            systemd)
                # skip: this is systemd --user, which exists only when there
                # are live login (e.g. ssh) sessions
                ;;
            systemd-journal|systemd-timesyn)
                # for some reason pidof systemd-journal fails
                emit checkproc_pgrep "$cmd"
                ;;
            *)
                emit checkproc "$cmd"
                ;;
        esac
    done
    pending=
}

generate_checkram() {
    prefix "# Check free memory"
    emit checkram
}

generate_checkswap() {
    prefix "# Check excessive swap usage"
    emit checkswap
}

generate_checkmailq() {
    prefix "# Check size of mail queue"
    emit checkmailq
}

generate_checkaliases() {
    prefix "# Check if /etc/aliases is up to date"
    emit checkaliases
}

generate_checkweb() {
    for site in /etc/apache2/sites-enabled/*; do
        awk '/<VirtualHost .*:80/ { ssl = "" } /<VirtualHost .*:443/ { ssl = " --ssl" } $1 == "ServerName" { print "checkweb", "-H", $2 ssl }' "$site"
    done
}

generate_checkcert() {
    for site in /etc/apache2/sites-enabled/*; do
        awk '/<VirtualHost .*:80/ { ssl = 0 } /<VirtualHost .*:443/ { ssl = 1 } $1 == "ServerName" && ssl == 1 { print "checkcert", $2 }' "$site"
    done
}


generate_config_for_check_health() {
    prefix "#
# System health checks for $(hostname -f)
#
# Generated by pov-check-health on $(date +"%Y-%m-%d %H:%M:%S")
#"
    generate_checkproc
    generate_checkpidfiles
    generate_checkfs
    generate_checkinodes
    generate_checkram
    generate_checkswap
    generate_checkmailq
    generate_checkaliases
    # generate_checkweb is not called here because we want it separate
    # generate_checkcert is not called here because we want it separate
}


generate_config_for_check_web_health() {
    emit "#
# Web health checks for $(hostname -f)
#
# Generated by pov-check-health on $(date +"%Y-%m-%d %H:%M:%S")
#"
    generate_checkweb
}


generate_config_for_check_ssl_certs() {
    emit "#
# SSL certificate checks for $(hostname -f)
#
# Generated by pov-check-health on $(date +"%Y-%m-%d %H:%M:%S")
#"
    generate_checkcert
}
