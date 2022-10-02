# Process this file with autoconf to produce a configure script.

AC_PREREQ([2.69])
AC_INIT([bss2ktest], [0.0.20220902], [Simon.Richter@hogyros.de])
AM_INIT_AUTOMAKE([1.10 foreign])

AC_CONFIG_HEADER([config.h])

# Checks for programs.
AC_PROG_CC

AC_CHECK_PROGS([UPHOLSTERER2K], [Upholsterer2k])

if test -z "${UPHOLSTERER2K}"; then
	AC_MSG_ERROR([Upholsterer2k is required])
fi

# Checks for libraries.
AC_CHECK_LIB([tinfo], [tiparm])

# Checks for header files.
AC_CHECK_HEADERS([term.h curses.h])

# Checks for typedefs, structures, and compiler characteristics.

# Checks for library functions.

AC_CONFIG_FILES([Makefile src/Makefile tests/Makefile])

AC_CONFIG_COMMANDS([test-subdirs], [${MKDIR_P} tests/base tests/insn])

AC_OUTPUT
