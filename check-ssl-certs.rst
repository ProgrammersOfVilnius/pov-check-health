===============
check-ssl-certs
===============

----------------------
check SSL certificates
----------------------

:Author: Marius Gedminas <marius@gedmin.as>
:Date: 2015-08-19
:Version: 0.9.0
:Manual section: 8


SYNOPSIS
========

**check-ssl-certs** [**-v**] [**-f** *configfile*]

**check-ssl-certs** **-h**


DESCRIPTION
===========

**check-ssl-certs** is a "poor man's Nagios": a script that performs some
basic system health checks.  The checks are specified in the configuration
file ``/etc/pov/check-ssl-certs``; if that file doesn't exist,
**check-ssl-certs** will exit silently without checking anything.

Usually **check-ssl-certs** is run automatically from cron, once a day.
It doesn't emit any output and returns exit code 0 if all checks pass.
Any output indicates an error, and cron emails it to ``root``.


OPTIONS
=======

-h           Print brief usage message and exit.
-v           Verbose output: show what checks are being performed.
-f FILENAME  Use the specified config file instead of ``/etc/pov/check-ssl-certs``.


CONFIGURATION FILE
==================

``/etc/pov/check-ssl-certs`` is a shell script that can invoke the
``checkcert``, ``checkcert_ssmtp`` and ``checkcert_imaps`` functions.

Technically you may also use any of the other checks from **check-health**\ (8),
but why would you want to do that?


EXAMPLES
========

Example ``/etc/pov/check-ssl-certs``::

    checkcert www.example.com
    checkcert subdomain.example.com
    checkcert_ssmtp mail.example.com
    checkcert_imaps mail.example.com


BUGS
====

**check-ssl-certs** returns exit code 0 even if some checks failed.  You need
to watch stderr to notice problems.


DESIGN LIMITATIONS
==================

If cron doesn't work, or email sending doesn't work, **check-ssl-certs**
won't be able to report problems.

**check-ssl-certs** is stateless and as such will keep reporting the same
error every day (assuming default cron configuration) until you fix it.


SEE ALSO
========

**check-health**\ (8), **check-web-health**\ (8)