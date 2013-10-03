=================
check-virtualenvs
=================

---------------------------
check for stale virtualenvs
---------------------------

:Author: Marius Gedminas <marius@gedmin.as>
:Date: 2013-10-03
:Version: 0.5.0
:Manual section: 8


SYNOPSIS
========

**check-virtualenvs** [**-v**]


DESCRIPTION
===========

**check-virtualenvs** finds all Python virtual environments on your system
(by using **locate**\ (1)) and compares their copies of the Python
interpreter with the system copy.

OPTIONS
=======

-v           Verbose output


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


TROUBLESHOOTING
===============

If you get errors like ::

  locate: can not stat () `/var/lib/mlocate/mlocate.db': No such file or directory

be sure to run **updatedb**\ (8).
