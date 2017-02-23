===============
check-ssl-certs
===============

----------------------
check SSL certificates
----------------------

:Author: Marius Gedminas <marius@gedmin.as>
:Date: 2017-01-27
:Version: 0.12.0
:Manual section: 8


SYNOPSIS
========

**check-ssl-certs** [**-c**] [**-v**] [**-f** *configfile*]

**check-ssl-certs** **-g** > *configfile*

**check-ssl-certs** **-h**


DESCRIPTION
===========

**check-ssl-certs** is a "poor man's Nagios": a script that performs some
basic system health checks.  The checks are specified in the configuration
file ``/etc/pov/check-ssl-certs``; if that file doesn't exist,
**check-ssl-certs** will exit silently without checking anything.

You can run ``check-ssl-certs -g`` to generate a config file.  You'll probably
need to modify it to suit your needs.

Usually **check-ssl-certs** is run automatically from cron, once a day.
It doesn't emit any output and returns exit code 0 if all checks pass.
Any output indicates an error, and cron emails it to ``root``.


OPTIONS
=======

-h           Print brief usage message and exit.
-v           Verbose output: show what checks are being performed.
-c           Colorize error messages in red.
-g           Generate a sample config file and print it to stdout.
-f FILENAME  Use the specified config file instead of ``/etc/pov/check-ssl-certs``.


Note: ``-v`` also uses some colors, for informational messages, when
standard output is a terminal that supports colors.  ``-c``, on the other
hand, is unconditional and always uses colors, which is useful when
you run **check-ssl-certs** over ssh without an allocated terminal and
want to see the errors stand out.


CONFIGURATION FILE
==================

``/etc/pov/check-ssl-certs`` is a shell script that can invoke the
``checkcert``, ``checkcert_ssmtp`` and ``checkcert_imaps`` functions.

checkcert <hostname>[:<port>] [<days>]
  Check if the SSL certificate of a website is close to expiration.

checkcert_ssmtp <hostname> [<days>]
  Check if the SSL certificate of an SSMTP server is close to expiration.

checkcert_imaps <hostname> [<days>]
  Check if the SSL certificate of an IMAPS server is close to expiration.

<days> defaults to $CHECKCERT_WARN_BEFORE, and if that's not specified, 21.

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
