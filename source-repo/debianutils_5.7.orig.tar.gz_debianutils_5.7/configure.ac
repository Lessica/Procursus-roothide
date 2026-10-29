AC_INIT([debianutils],[DEBIANUTILS_VERSION])
AM_INIT_AUTOMAKE

AC_PROG_CC
AC_PATH_PROG([po4a_translate],[po4a-translate])
AM_CONDITIONAL([TRANSLATE_DOCS], [test -n "$po4a_translate"])

AC_CHECK_HEADERS(paths.h getopt.h)

AC_SYS_LARGEFILE

AC_CONFIG_FILES([Makefile po4a/Makefile po4a/de/Makefile po4a/es/Makefile po4a/fr/Makefile po4a/it/Makefile po4a/ja/Makefile po4a/pl/Makefile po4a/pt/Makefile po4a/sl/Makefile])
AC_OUTPUT
