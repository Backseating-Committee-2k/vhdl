#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ([2.69])
AC_INIT([basys2k-display], [0.0.20220425], [Simon.Richter@hogyros.de])
AM_INIT_AUTOMAKE([1.10 foreign])

AC_CONFIG_SRCDIR([config.h.in])
AC_CONFIG_HEADERS([config.h])

# Checks for programs.
AC_PROG_CC

AC_CHECK_TOOL(
	[OBJDUMP],
	[objdump])

AC_MSG_CHECKING([BFD type of compiler output])
AC_TRY_COMPILE(
	[],
	[],
	[BFDTYPE=`${OBJDUMP} -f conftest.$ac_objext | sed -ne 's/.*format //p'`])
AC_MSG_RESULT([${BFDTYPE}])

AC_SUBST([BFDTYPE])

AC_CHECK_TOOL(
	[OBJCOPY],
	[objcopy])

# Checks for libraries.
AC_CHECK_LIB(
	[X11],
	[XOpenDisplay],
	,
	[AC_MSG_ERROR([Cannot find X11 library])])

dnl Workaround for libXext bug (fails to deregister a callback when the
dnl last user is gone and the library is unloaded)
dnl
dnl This just forces the library to remain loaded.
dnl
dnl TODO: check if as-needed is active before with compilers that don't
dnl support push-state/pop-state, and restore properly.

AX_CHECK_LINK_FLAG(
	[-Wl,--as-needed],
	[
		AX_CHECK_LINK_FLAG(
			[-Wl,--push-state,--pop-state],
			[LIBS="-Wl,--push-state,--no-as-needed,-lXext,--pop-state $LIBS"],
			[LIBS="-Wl,--no-as-needed,-lXext,--as-needed $LIBS"]
		)
	],
	[LIBS="-lXext $LIBS"])

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

AC_CONFIG_FILES([Makefile
                 src/Makefile])
AC_OUTPUT
