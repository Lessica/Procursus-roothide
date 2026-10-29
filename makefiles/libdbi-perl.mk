ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS += libdbi-perl
LIBDBI_PERL_VERSION := 1.643
DEB_LIBDBI_PERL_V ?= $(LIBDBI_PERL_VERSION)
PERL_HOST ?= $(shell command -v perl)
DBI_HOST_CORE = $(shell $(PERL_HOST) -MConfig -e 'print -f "$(MACOSX_SYSROOT)$$Config{archlib}/CORE/perl.h" ? "$(MACOSX_SYSROOT)$$Config{archlib}/CORE" : "$$Config{archlib}/CORE"')
DBI_HOST_LIBPATH = $(BUILD_WORK)/libdbi-perl-native/blib/lib:$(BUILD_WORK)/libdbi-perl-native/blib/arch
DBI_TARGET_CORE = $(BUILD_STAGE)/perl/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/perl5/$(PERL_MAJOR)/CORE
ifeq ($(UNAME),Darwin)
DBI_NATIVE_CC = $(firstword $(CC_FOR_BUILD))
DBI_NATIVE_CFLAGS = -arch $(UNAME_M) -isysroot $(MACOSX_SYSROOT) -mmacosx-version-min=13.0
DBI_NATIVE_LDFLAGS = $(DBI_NATIVE_CFLAGS) -bundle -undefined dynamic_lookup
else
DBI_NATIVE_CC = $(CC_FOR_BUILD)
DBI_NATIVE_CFLAGS = $(CFLAGS_FOR_BUILD)
DBI_NATIVE_LDFLAGS = $(LDFLAGS_FOR_BUILD) -shared
endif

libdbi-perl-setup: setup
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/DBI-$(LIBDBI_PERL_VERSION).tar.gz,https://cpan.metacpan.org/authors/id/T/TI/TIMB/DBI-$(LIBDBI_PERL_VERSION).tar.gz)
	echo '8a2b993db560a2c373c174ee976a51027dd780ec766ae17620c20393d2e836fa  $(BUILD_SOURCE)/DBI-$(LIBDBI_PERL_VERSION).tar.gz' | sha256sum -c -
	$(call EXTRACT_TAR,DBI-$(LIBDBI_PERL_VERSION).tar.gz,DBI-$(LIBDBI_PERL_VERSION),libdbi-perl)
	$(call EXTRACT_TAR,DBI-$(LIBDBI_PERL_VERSION).tar.gz,DBI-$(LIBDBI_PERL_VERSION),libdbi-perl-native)

# DBD's configure script loads DBI. Reuse a matching real host module when
# available, or build one separately; never load target objects on the host.
libdbi-perl-native: libdbi-perl-setup
	+if ! PERL5LIB="$(DBI_HOST_LIBPATH)" $(PERL_HOST) -MDBI -e 'exit($$DBI::VERSION eq "$(LIBDBI_PERL_VERSION)" ? 0 : 1)' 2>/dev/null; then \
		cd $(BUILD_WORK)/libdbi-perl-native && \
		env -u CFLAGS -u CPPFLAGS -u CXXFLAGS -u LDFLAGS SDKROOT="$(MACOSX_SYSROOT)" \
			$(PERL_HOST) Makefile.PL PERL="$(PERL_HOST)" \
			CC="$(DBI_NATIVE_CC)" LD="$(DBI_NATIVE_CC)" \
			CCFLAGS="$(DBI_NATIVE_CFLAGS)" PERL_INC="$(DBI_HOST_CORE)" \
			LDDLFLAGS="$(DBI_NATIVE_LDFLAGS)" && \
		$(MAKE) CC="$(DBI_NATIVE_CC)" LD="$(DBI_NATIVE_CC)" \
			CCFLAGS="$(DBI_NATIVE_CFLAGS)" PERL_INC="$(DBI_HOST_CORE)" \
			LDDLFLAGS="$(DBI_NATIVE_LDFLAGS)"; \
	fi
	PERL5LIB="$(DBI_HOST_LIBPATH)" $(PERL_HOST) -MDBI -e 'die "wrong host DBI" unless $$DBI::VERSION eq "$(LIBDBI_PERL_VERSION)"; print "host DBI $$DBI::VERSION: $$INC{q(DBI.pm)}\n"'

ifneq ($(wildcard $(BUILD_WORK)/libdbi-perl/.build_complete),)
libdbi-perl:
	@echo "Using previously built libdbi-perl."
else
libdbi-perl: libdbi-perl-setup perl libxcrypt
	cd $(BUILD_WORK)/libdbi-perl && $(PERL_HOST) Makefile.PL \
		$(DEFAULT_PERL_MAKE_FLAGS) CC="$(CC)" LD="$(CC)" DLEXT=so \
		CCFLAGS="$(CFLAGS) -I$(DBI_TARGET_CORE)" \
		PERLRUN="$(PERL_HOST)" FULLPERLRUN="$(PERL_HOST)" ABSPERLRUN="$(PERL_HOST)" \
		LDDLFLAGS="$(LDFLAGS) -L$(DBI_TARGET_CORE) -lperl -shared"
	+$(MAKE) -C $(BUILD_WORK)/libdbi-perl PERL_INCDEP="$(DBI_HOST_CORE)" DLEXT=so
	+$(MAKE) -C $(BUILD_WORK)/libdbi-perl install PERL_INCDEP="$(DBI_HOST_CORE)" DLEXT=so DESTDIR="$(BUILD_STAGE)/libdbi-perl"
	find $(BUILD_STAGE)/libdbi-perl -type f \( -name .packlist -o -name perllocal.pod \) -delete
	$(call AFTER_BUILD,copy)
endif

libdbi-perl-package: libdbi-perl-stage
	rm -rf $(BUILD_DIST)/libdbi-perl
	cp -a $(BUILD_STAGE)/libdbi-perl $(BUILD_DIST)
	$(call SIGN,libdbi-perl,general.xml)
	$(call PACK,libdbi-perl,DEB_LIBDBI_PERL_V)
	rm -rf $(BUILD_DIST)/libdbi-perl

.PHONY: libdbi-perl libdbi-perl-native libdbi-perl-package
