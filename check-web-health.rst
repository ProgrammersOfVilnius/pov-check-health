================
check-web-health
================

--------------------
check website health
--------------------

:Author: Marius Gedminas <marius@gedmin.as>
:Date: 2016-08-19
:Version: 0.10.5
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
available options.  Here are a few of the most useful ones:

HTTP request parameters

-H ADDRESS, --hostname=ADDRESS
   Host name argument for servers using host headers (virtual host)
   Append a port to include it in the header (eg: example.com:5000)

-I ADDRESS, --IP-address=ADDRESS
   IP address or name (use numeric address if possible to bypass DNS lookup).

-p PORT, --port=PORT
   Port number (default: 80)

-4, --use-ipv4
   Use IPv4 connection

-6, --use-ipv6
   Use IPv6 connection

-S, --ssl
   Connect via SSL. Port defaults to 443.

--sni
   Enable SSL/TLS hostname extension support (SNI)

-u PATH, --url=PATH
   URL to GET or POST (default: /)

-j METHOD, --method=METHOD
   Set HTTP method (for example: HEAD, OPTIONS, TRACE, PUT, DELETE, CONNECT)

-P DATa, --post=DATA
   URL encoded http POST data

-T TYPE, --content-type=TYPE
   specify Content-Type header media type when POSTing

-A AGENT, --useragent=AGENT
   String to be sent in http header as "User Agent"

-k HEADER, --header=HEADER
   Any other tags to be sent in http header. Use multiple times for additional headers

HTTP response checks

-e STRING, --expect=STRING
   Comma-delimited list of strings, at least one of them is expected in
   the first (status) line of the server response (default: HTTP/1.)
   If specified skips all other status line logic (ex: 3xx, 4xx, 5xx processing)

-d STRING, --header-string=STRING
   String to expect in the response headers

-s STRING, --string=STRING
   String to expect in the content

-l, --linespan
   Allow regex to span newlines (must precede -r or -R)

-r STRING, --regex=STRING, --ereg=STRING
   Search page for regex STRING

-R STRING, --eregi=STRING
   Search page for case-insensitive regex STRING

--invert-regex
   Return CRITICAL if found, OK if not

-M SECONDS, --max-age=SECONDS
   Warn if document is more than SECONDS old. the number can also be of
   the form "10m" for minutes, "10h" for hours, or "10d" for days.

-m SIZE_RANGE, --pagesize=SIZE_RANGE
   Minimum page size required (bytes) : Maximum page size required (bytes)

Time options

-w SECONDS, --warning=SECONDS
   Response time to result in warning status (seconds)

-c SECONDS, --critical=SECONDS
   Response time to result in critical status (seconds)

-t SECONDS, --timeout=SECONDS
   Seconds before connection times out (default: 10.0)

Options you should not use

-a AUTH_PAIR, --authorization=AUTH_PAIR
   Use ``checkweb_auth <username>:<password> <options>`` instead

-C DAYS, --certificate=DAYS
   Use ``checkcert <hostname> [<days>]`` instead


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
