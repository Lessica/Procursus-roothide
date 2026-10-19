ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS                  += libterm-readkey-perl
LIBTERM-READKEY-PERL_VERSION := 2.38
DEB_LIBTERM-READKEY-PERL_V   ?= $(LIBTERM-READKEY-PERL_VERSION)-2
PERL_HOST                    ?= $(shell command -v perl)
PERL_HOST_CORE               ?= $(shell $(PERL_HOST) -MConfig -e 'print "$$Config{archlib}/CORE"')
PERL_TARGET_CORE             = $(BUILD_STAGE)/perl/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/perl5/$(PERL_MAJOR)/CORE

libterm-readkey-perl-setup: setup
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/libterm-readkey-perl-$(LIBTERM-READKEY-PERL_VERSION).tar.gz, \
		https://cpan.metacpan.org/authors/id/J/JS/JSTOWE/TermReadKey-$(LIBTERM-READKEY-PERL_VERSION).tar.gz)
	$(call EXTRACT_TAR,libterm-readkey-perl-$(LIBTERM-READKEY-PERL_VERSION).tar.gz,TermReadKey-$(LIBTERM-READKEY-PERL_VERSION),libterm-readkey-perl)
	$(call DO_PATCH,libterm-readkey-perl,libterm-readkey-perl,-p1)

ifneq ($(wildcard $(BUILD_WORK)/libterm-readkey-perl/.build_complete),)
libterm-readkey-perl:
	@echo "Using previously built libterm-readkey-perl."
else
libterm-readkey-perl: libterm-readkey-perl-setup perl
	cd $(BUILD_WORK)/libterm-readkey-perl && $(PERL_HOST) Makefile.PL \
		$(DEFAULT_PERL_MAKE_FLAGS) \
		DLEXT=so \
		LDDLFLAGS="$(LDFLAGS) -L$(PERL_TARGET_CORE) -lperl -shared"
	+$(MAKE) -C $(BUILD_WORK)/libterm-readkey-perl ReadKey.c \
		PERL_INCDEP="$(PERL_HOST_CORE)" \
		DLEXT=so
	+@set -e; \
		macro_file=$$(mktemp); \
		trap 'rm -f "$$macro_file"' EXIT; \
		$(CC) $(CFLAGS) -I$(PERL_TARGET_CORE) -dM -E $(BUILD_WORK)/libterm-readkey-perl/ReadKey.c > "$$macro_file"; \
		test -s "$$macro_file" || { echo "target ReadKey feature macro preprocessing produced no output" >&2; exit 1; }; \
		blockoptions=$$(awk '$$2 == "Have_nodelay" { value += 1 } $$2 == "Have_poll" { value += 2 } $$2 == "Have_select" { value += 4 } $$2 == "USE_WIN32" { value += 8 } END { print value + 0 }' "$$macro_file"); \
		case "$$blockoptions" in ''|*[!0-9]*) echo "invalid target ReadKey blockoptions mask: $$blockoptions" >&2; exit 1;; esac; \
		$(MAKE) -C $(BUILD_WORK)/libterm-readkey-perl install \
			FULLPERLRUNINST="env TERM_READKEY_BLOCKOPTIONS=$$blockoptions $(PERL_HOST)" \
			PERL_INCDEP="$(PERL_HOST_CORE)" \
			DLEXT=so \
			LDDLFLAGS="$(LDFLAGS) -L$(PERL_TARGET_CORE) -lperl -shared" \
			DESTDIR="$(BUILD_STAGE)/libterm-readkey-perl"
	rm -f $(BUILD_STAGE)/libterm-readkey-perl/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/perl5/$(PERL_MAJOR)/auto/Term/ReadKey/ReadKey.bundle
	rm -f $(BUILD_STAGE)/libterm-readkey-perl/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/perl5/$(PERL_MAJOR)/perllocal.pod
	$(call AFTER_BUILD)
endif

libterm-readkey-perl-package: libterm-readkey-perl-stage
	# libterm-readkey-perl.mk Package Structure
	rm -rf $(BUILD_DIST)/libterm-readkey-perl

	# libterm-readkey-perl.mk Prep libterm-readkey-perl
	cp -a $(BUILD_STAGE)/libterm-readkey-perl $(BUILD_DIST)
	find $(BUILD_DIST)/libterm-readkey-perl -type f -name .packlist -delete
	rm -f $(BUILD_DIST)/libterm-readkey-perl/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/perl5/$(PERL_MAJOR)/auto/Term/ReadKey/ReadKey.bundle
	$(call SIGN,libterm-readkey-perl,general.xml)

	# libterm-readkey-perl.mk Make .debs
	$(call PACK,libterm-readkey-perl,DEB_LIBTERM-READKEY-PERL_V)

	# libterm-readkey-perl.mk Build cleanup
	rm -rf $(BUILD_DIST)/libterm-readkey-perl

.PHONY: libterm-readkey-perl libterm-readkey-perl-package
