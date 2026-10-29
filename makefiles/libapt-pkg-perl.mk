ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS             += libapt-pkg-perl
LIBAPT-PKG-PERL_VERSION := 0.1.40
DEB_LIBAPT-PKG-PERL_V   ?= $(LIBAPT-PKG-PERL_VERSION)-2
PERL_HOST              ?= $(shell command -v perl)
PERL_HOST_CORE         ?= $(shell $(PERL_HOST) -MConfig -e 'print "$$Config{archlib}/CORE"')
PERL_TARGET_CORE       = $(BUILD_STAGE)/perl/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/perl5/$(PERL_MAJOR)/CORE

libapt-pkg-perl-setup: setup
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/libapt-pkg-perl-$(LIBAPT-PKG-PERL_VERSION).tar.xz, \
		https://deb.debian.org/debian/pool/main/liba/libapt-pkg-perl/libapt-pkg-perl_$(LIBAPT-PKG-PERL_VERSION).tar.xz)
	$(call EXTRACT_TAR,libapt-pkg-perl-$(LIBAPT-PKG-PERL_VERSION).tar.xz,libapt-pkg-perl-$(LIBAPT-PKG-PERL_VERSION),libapt-pkg-perl)

ifneq ($(wildcard $(BUILD_WORK)/libapt-pkg-perl/.build_complete),)
libapt-pkg-perl:
	@echo "Using previously built libapt-pkg-perl."
else
libapt-pkg-perl: libapt-pkg-perl-setup perl apt
	cd $(BUILD_WORK)/libapt-pkg-perl && PERLRUN=$(PERL_HOST) $(PERL_HOST) Makefile.PL \
		$(DEFAULT_PERL_MAKE_FLAGS) \
		DLEXT=so \
		LDDLFLAGS="-std=c++11 $(LDFLAGS) -L$(PERL_TARGET_CORE) -lperl -shared"
	+$(MAKE) -C $(BUILD_WORK)/libapt-pkg-perl \
		$(DEFAULT_PERL_MAKE_FLAGS) \
		DLEXT=so \
		CC="$(CXX)" \
		CCFLAGS="-std=c++11 $(CXXFLAGS) -Denviron" \
		LD="$(CXX)" \
		LDDLFLAGS="-std=c++11 $(LDFLAGS) -L$(PERL_TARGET_CORE) -lperl -shared" \
		PERL_INCDEP="$(PERL_HOST_CORE)" \
		INST_DYNAMIC_FIX="-lapt-pkg"
	+$(MAKE) -C $(BUILD_WORK)/libapt-pkg-perl install \
		$(DEFAULT_PERL_MAKE_FLAGS) \
		DLEXT=so \
		PERL_INCDEP="$(PERL_HOST_CORE)" \
		LDDLFLAGS="-std=c++11 $(LDFLAGS) -L$(PERL_TARGET_CORE) -lperl -shared" \
		DESTDIR="$(BUILD_STAGE)/libapt-pkg-perl"
	rm -f $(BUILD_STAGE)/libapt-pkg-perl/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/perl5/$(PERL_MAJOR)/auto/AptPkg/AptPkg.bundle
	rm -f $(BUILD_STAGE)/libapt-pkg-perl/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/perl5/$(PERL_MAJOR)/perllocal.pod
	chmod 755 $(BUILD_STAGE)/libapt-pkg-perl/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/perl5/$(PERL_MAJOR)/auto/AptPkg/AptPkg.so
	$(call AFTER_BUILD)
endif

libapt-pkg-perl-package: libapt-pkg-perl-stage
	# libapt-pkg-perl.mk Package Structure
	rm -rf $(BUILD_DIST)/libapt-pkg-perl

	# libapt-pkg-perl.mk Prep libapt-pkg-perl
	cp -a $(BUILD_STAGE)/libapt-pkg-perl $(BUILD_DIST)
	find $(BUILD_DIST)/libapt-pkg-perl -type f -name .packlist -delete
	rm -f $(BUILD_DIST)/libapt-pkg-perl/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/perl5/$(PERL_MAJOR)/auto/AptPkg/AptPkg.bundle

	# libapt-pkg-perl.mk Sign
	$(call SIGN,libapt-pkg-perl,general.xml)

	# libapt-pkg-perl.mk Make .debs
	$(call PACK,libapt-pkg-perl,DEB_LIBAPT-PKG-PERL_V)

	# libapt-pkg-perl.mk Build cleanup
	rm -rf $(BUILD_DIST)/libapt-pkg-perl

.PHONY: libapt-pkg-perl libapt-pkg-perl-package
