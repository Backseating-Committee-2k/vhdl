#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ([2.69])
AC_INIT([basys2k-display], [0.0.20220425], [Simon.Richter@hogyros.de])
AM_INIT_AUTOMAKE([1.10 foreign])

AC_CONFIG_SRCDIR([config.h.in])
AC_CONFIG_HEADERS([config.h])
AC_CONFIG_FILES([Makefile src/Makefile])

# Checks for programs.
AC_PROG_CC

# Checks for libraries.
AC_CHECK_LIB(
	[X11],
	[XOpenDisplay],
	,
	[AC_MSG_ERROR([Cannot find X11 library])])
AC_CHECK_LIB(
	[vulkan],
	[vkCreateInstance],
	,
	[AC_MSG_ERROR([Cannot find Vulkan library])])

# Checks for header files.
AC_CHECK_HEADER(
	[X11/X.h],
	,
	[AC_MSG_ERROR([Cannot find X11 headers])])
AC_CHECK_HEADER(
	[vulkan/vulkan.h],
	,
	[AC_MSG_ERROR([Cannot find Vulkan headers])])
AC_CHECK_HEADERS([stddef.h string.h unistd.h])

# Checks for typedefs, structures, and compiler characteristics.
AC_CHECK_HEADER_STDBOOL
AC_TYPE_UINT32_T

# Checks for library functions.

AC_OUTPUT
