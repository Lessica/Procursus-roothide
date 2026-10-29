ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS += libdbd-mariadb-perl
LIBDBD_MARIADB_PERL_VERSION := 1.21
DEB_LIBDBD_MARIADB_PERL_V ?= $(LIBDBD_MARIADB_PERL_VERSION)

libdbd-mariadb-perl-setup: setup
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/DBD-MariaDB-$(LIBDBD_MARIADB_PERL_VERSION).tar.gz,https://cpan.metacpan.org/authors/id/P/PA/PALI/DBD-MariaDB-$(LIBDBD_MARIADB_PERL_VERSION).tar.gz)
	echo 'f5972b337a0d1d4726b2471eb79f23ee0cdd034bf43f4e13f2b5162597271419  $(BUILD_SOURCE)/DBD-MariaDB-$(LIBDBD_MARIADB_PERL_VERSION).tar.gz' | sha256sum -c -
	$(call EXTRACT_TAR,DBD-MariaDB-$(LIBDBD_MARIADB_PERL_VERSION).tar.gz,DBD-MariaDB-$(LIBDBD_MARIADB_PERL_VERSION),libdbd-mariadb-perl)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/Devel-CheckLib-1.14.tar.gz,https://cpan.metacpan.org/authors/id/M/MA/MATTN/Devel-CheckLib-1.14.tar.gz)
	echo 'f21c5e299ad3ce0fdc0cb0f41378dca85a70e8d6c9a7599f0e56a957200ec294  $(BUILD_SOURCE)/Devel-CheckLib-1.14.tar.gz' | sha256sum -c -
	$(call EXTRACT_TAR,Devel-CheckLib-1.14.tar.gz,Devel-CheckLib-1.14,libdbd-mariadb-perl/checklib)
	$(call DO_PATCH,libdbd-mariadb-perl,libdbd-mariadb-perl,-p1)

ifneq ($(wildcard $(BUILD_WORK)/libdbd-mariadb-perl/.build_complete),)
libdbd-mariadb-perl:
	@echo "Using previously built libdbd-mariadb-perl."
else
libdbd-mariadb-perl: libdbd-mariadb-perl-setup libdbi-perl libdbi-perl-native mariadb perl libxcrypt
	# The selected Connector/C is not embedded (mysql_embedded returns 0).
	# Its OpenSSL >= 1.1 path never calls the legacy global cleanup functions.
	# Keep API probes as real target compile/link checks, never host execution.
	cd $(BUILD_WORK)/libdbd-mariadb-perl && \
		PERL5LIB="$(BUILD_WORK)/libdbd-mariadb-perl/checklib/lib:$(DBI_HOST_LIBPATH)" \
		DEVEL_CHECKLIB_CROSS_CC="$(CC)" $(PERL_HOST) Makefile.PL \
		--cross-compile --cross-embedded=0 --cross-openssl-deinit=0 \
		--dbi-instarch-dir="$(BUILD_STAGE)/libdbi-perl/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/perl5/$(PERL_MAJOR)/auto/DBI" \
		--mysql_config=skip --cflags="$(CFLAGS) -I$(BUILD_BASE)$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include/mysql" \
		--libs="$(LDFLAGS) -lmariadb -lssl -lcrypto" \
		$(DEFAULT_PERL_MAKE_FLAGS) CC="$(CC)" LD="$(CC)" DLEXT=so \
		CCFLAGS="$(CFLAGS) -I$(DBI_TARGET_CORE)" \
		PERLRUN="$(PERL_HOST)" FULLPERLRUN="$(PERL_HOST)" ABSPERLRUN="$(PERL_HOST)" \
		LDDLFLAGS="$(LDFLAGS) -L$(DBI_TARGET_CORE) -lperl -shared"
	+PERL5LIB="$(DBI_HOST_LIBPATH)" $(MAKE) -C $(BUILD_WORK)/libdbd-mariadb-perl \
		PERL_INCDEP="$(DBI_HOST_CORE)" DLEXT=so LDLOADLIBS="$(LDFLAGS) -lmariadb -lssl -lcrypto" \
		DBI_INSTARCH_DIR="$(BUILD_STAGE)/libdbi-perl/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/perl5/$(PERL_MAJOR)/auto/DBI"
	+PERL5LIB="$(DBI_HOST_LIBPATH)" $(MAKE) -C $(BUILD_WORK)/libdbd-mariadb-perl install \
		PERL_INCDEP="$(DBI_HOST_CORE)" DLEXT=so LDLOADLIBS="$(LDFLAGS) -lmariadb -lssl -lcrypto" \
		DBI_INSTARCH_DIR="$(BUILD_STAGE)/libdbi-perl/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/perl5/$(PERL_MAJOR)/auto/DBI" \
		DESTDIR="$(BUILD_STAGE)/libdbd-mariadb-perl"
	find $(BUILD_STAGE)/libdbd-mariadb-perl -type f \( -name .packlist -o -name perllocal.pod \) -delete
	$(call AFTER_BUILD)
endif

libdbd-mariadb-perl-package: libdbd-mariadb-perl-stage
	rm -rf $(BUILD_DIST)/libdbd-mariadb-perl
	cp -a $(BUILD_STAGE)/libdbd-mariadb-perl $(BUILD_DIST)
	$(call SIGN,libdbd-mariadb-perl,general.xml)
	$(call PACK,libdbd-mariadb-perl,DEB_LIBDBD_MARIADB_PERL_V)
	rm -rf $(BUILD_DIST)/libdbd-mariadb-perl

.PHONY: libdbd-mariadb-perl libdbd-mariadb-perl-package
