================
check-web-health
================

--------------------
check website health
--------------------

:Author: Marius Gedminas <marius@gedmin.as>
:Date: 2015-11-11
:Version: 0.10.0
:Manual section: 8


SYNOPSIS
========

**check-web-health** [**-c**] [**-v**] [**-f** *configfile*]

**check-web-health** **-g** > *configfile*

**check-web-health** **-h**


DESCRIPTION
===========

**check-web-health** is a "poor man's Nagios": a script that performs some
basic system health checks.  The checks are specified in the configuration
file ``/etc/pov/check-web-health``; if that file doesn't exist,
**check-web-health** will exit silently without checking anything.

You can run ``check-web-health -g`` to generate a config file.  You'll probably
need to modify it to suit your needs.

Usually **check-web-health** is run automatically from cron.  It doesn't
emit any output and returns exit code 0 if all checks pass.  Any output
indicates an error, and cron emails it to ``root``.


OPTIONS
=======

-h           Print brief usage message and exit.
-v           Verbose output: show what checks are being performed.
-c           Colorize error messages in red.
-g           Generate a sample config file and print it to stdout.
-f FILENAME  Use the specified config file instead of ``/etc/pov/check-web-health``.


Note: ``-v`` also uses some colors, for informational messages, when
standard output is a terminal that supports colors.  ``-c``, on the other
hand, is unconditional and always uses colors, which is useful when
you run **check-web-health** over ssh without an allocated terminal and
want to see the errors stand out.


CONFIGURATION FILE
==================

``/etc/pov/check-web-health`` is a shell script that can invoke the
``checkweb`` function, which is a very thin wrapper around ``check_http``
from Nagios plugins.  See
https://www.monitoring-plugins.org/doc/man/check_http.html for the
available options.

Technically you may also use any of the other checks from **check-health**\ (8),
but why would you want to do that?  Except maybe `checkuptime`, to suppress the other
checks while the server is still booting.


EXAMPLES
========

Example ``/etc/pov/check-web-health``::

    checkweb -H www.example.com
    checkweb --ssl -H www.example.com -u /prefix/ -f follow -s 'Expect this string' --timeout=30
    checkweb --ssl -H www.example.com -u /protected/ -e 'HTTP/1.1 401 Unauthorized' -s 'Login required'
    checkweb --ssl -H www.example.com --invert-regex -r "Database connection error"


BUGS
====

**check-web-health** returns exit code 0 even if some checks failed.  You need
to watch stderr to notice problems.


DESIGN LIMITATIONS
==================

If cron doesn't work, or email sending doesn't work, **check-web-health**
won't be able to report problems.

**check-web-health** is stateless and as such will keep reporting the same
error every fifteen minutes (assuming default cron configuration) until
you fix it.


SEE ALSO
========

**check-health**\ (8), **check-ssl-certs**\ (8)
