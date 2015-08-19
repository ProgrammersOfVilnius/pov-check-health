pov-check-health
================

This is a "poor man's Nagios": a cron script that runs once an hour to
perform some basic system health checks.

Quick start::

    sudo add-apt-repository ppa:pov/ppa
    sudo apt-get update
    sudo apt-get install pov-check-health

The checks are configured in ``/etc/pov/check-health``, which is actually
a shell file that is sourced from the cron script.  If this file is missing,
``check-health`` does nothing.

You can generate a skeleton config file automatically with ::

    check-health > /etc/pov/check-health

Example configuration file::

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

You can also run the checks manually by running ``check-health`` and see the
report on the console.  Run ``check-health -v`` for more verbosity.  Run
``check-health -f filename`` to use a different config file (useful to test it
before the cron script takes over).  Run ``check-health -h`` for a brief usage
notice::

    Usage: check-health [-h] [-v] [-f configfile] [-g]


Available checks
----------------

These are documented in the manual page (see check-health.rst in the
source tree or ``man check-health`` if you've have the package installed).


Additional tools
----------------

check-web-health
~~~~~~~~~~~~~~~~

This is the same script as ``check-health``, only it uses a different
config file (``/etc/pov/check-web-health``), and the ``-g`` generation
produces ``checkweb`` checks for websites configured in
``/etc/apache2/sites-enabled``.

Also, the default cron configuration runs the website checks four times an
hour instead of once an hour.


check-ssl-certs
~~~~~~~~~~~~~~~

This is the same script as ``check-ssl-certs``, only it uses a different
config file (``/etc/pov/check-ssl-certs``).

The default cron configuration runs the SSL certificate expiration checks
once a day.


check-virtualenvs
~~~~~~~~~~~~~~~~~

Background: virtualenv is a solution for Python application sandboxing,
so that different applications can use different sets of Python libraries
without encountering conflicts due to incompatible versions.  It works
by creating directory trees that contain copies of the Python executable
in addition to symlinks to the Python standard library.  When you upgrade
the system Python executable, you end up with stale copies of the old
versions in all your virtualenvs.  Sometimes this simply means you don't
get the latest bugfixes.  Sometimes this breaks your virtualenvs
completely.

The ``check-virtualenvs`` script finds all virtualenvs on your system
and compares their copies of the Python executable with the system
version.  It relies on mlocate_ (or an equivalent such as slocate_)
for finding the virtualenvs.

.. _mlocate: http://packages.ubuntu.com/search?keywords=mlocate
.. _slocate: http://packages.ubuntu.com/search?keywords=slocate

It is not yet integrated with cron.
