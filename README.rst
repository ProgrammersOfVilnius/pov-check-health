pov-check-health
================

This is a "poor man's Nagios": a cron script that runs once an hour to
perform some basic system health checks.

The checks are configured in ``/etc/pov/check-health``, which is actually
a shell file that is sourced from the cron script.  Example ::

    # Check that processes are running
    checkproc apache2
    checkproc cron
    checkproc sshd
    checkproc_pgrep tracd
    checkproc_pgrep_full '/usr/bin/java -jar /usr/share/jenkins/jenkins.war'

    # Check for stale aspell processes (more than 2)
    checktoomanyproc aspell 2

    # Check for stale pidfiles
    checkpidfiles /var/run/*.pid /var/run/*/*.pid

    # Check free disk space
    checkfs /    200M
    checkfs /var 200M

    # Check free inodes
    checkinodes /
    checkinodes /var

    # Check free memory
    checkram 100M

    # Check excessive swap usage
    checkswap 2G

    # Check mail queue
    checkmailq 100

    # Check if /etc/aliases is up to date
    checkaliases

The checks run with root privileges.  Any failures are reported via cron,
so make sure email delivery works and root is aliased to a working
email address via ``/etc/aliases``.

You can also run the checks manually by running ``check-health`` and
see the report on the console.
