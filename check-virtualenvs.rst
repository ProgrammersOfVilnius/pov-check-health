=================
check-virtualenvs
=================

---------------------------
check for stale virtualenvs
---------------------------

:Author: Marius Gedminas <marius@gedmin.as>
:Date: 2017-12-06
:Version: 0.12.1
:Manual section: 8


SYNOPSIS
========

**check-virtualenvs** [**-v**] [**-f**]
**check-virtualenvs** **-h**]


DESCRIPTION
===========

**check-virtualenvs** finds all Python virtual environments on your system
(by using **locate**\ (1)) and compares their copies of the Python
interpreter with the system copy.

OPTIONS
=======

-v           Verbose output
-f           Fix the problems by overwriting outdated Python binaries


BACKGROUND
==========

**virtualenv** is a solution for Python application sandboxing,
so that different applications can use different sets of Python libraries
without encountering conflicts due to incompatible versions.  It works
by creating directory trees that contain copies of the Python executable
in addition to symlinks to the Python standard library.  When you upgrade
the system Python executable, you end up with stale copies of the old
versions in all your virtualenvs.  Sometimes this simply means you don't
get the latest bugfixes.  Sometimes this breaks your virtualenvs
completely.


BUGS
====

This script relies on **locate**\ (1) to locate all virtualenvs.  The
locate database may be outdated and the script will not notice.

The logic for detecting a virtualenv is ad hoc and can produce false
positives.

This script cannot deal with a single virtualenv containing multiple
Python versions.

This script will break if you put spaces in your directory names.


TROUBLESHOOTING
===============

If you get errors like ::

  locate: can not stat () `/var/lib/mlocate/mlocate.db': No such file or directory

be sure to run **updatedb**\ (8).
