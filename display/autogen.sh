#! /bin/sh -x

set -e

aclocal
autoheader
automake -a
autoconf
