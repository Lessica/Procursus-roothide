ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS     += texinfo
TEXINFO_VERSION := 6.7
DEB_TEXINFO_V   ?= $(TEXINFO_VERSION)-3
PERL_HOST       ?= /usr/bin/perl
PERL_TARGET_CORE = $(BUILD_STAGE)/perl/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/perl5/$(PERL_MAJOR)/CORE

## This is super broken, someone should fix it

texinfo-setup: setup
	$(call DOWNLOAD_FILES,$(BUILD_SOURCE),https://ftp.gnu.org/gnu/texinfo/texinfo-$(TEXINFO_VERSION).tar.xz{$(comma).sig})
	$(call PGP_VERIFY,texinfo-$(TEXINFO_VERSION).tar.xz)
	$(call EXTRACT_TAR,texinfo-$(TEXINFO_VERSION).tar.xz,texinfo-$(TEXINFO_VERSION),texinfo)

ifneq ($(wildcard $(BUILD_WORK)/texinfo/.build_complete),)
texinfo:
	@echo "Using previously built texinfo."
else
texinfo: texinfo-setup perl ncurses gettext
	$(call DO_PATCH,texinfo,texinfo,-p1)
	mkdir -p $(BUILD_WORK)/texinfo/build
	cd $(BUILD_WORK)/texinfo/build && ../configure -C \
		$(DEFAULT_CONFIGURE_FLAGS) \
		--enable-perl-xs \
		PERL=$(PERL_HOST) \
		PERL_EXT_CFLAGS="$(CFLAGS)" \
		PERL_EXT_CPPFLAGS="$(CPPFLAGS)" \
		PERL_EXT_LDFLAGS="$(LDFLAGS) -L$(PERL_TARGET_CORE) -lperl" \
		PERL_EXT_CC="$(CC)"
	sed -i -e 's|^PERL_INC =.*|PERL_INC = $(PERL_TARGET_CORE)|' \
		-e 's|^PERL_CONF_ccdlflags =.*|PERL_CONF_ccdlflags =|' $(BUILD_WORK)/texinfo/build/tp/Texinfo/XS/Makefile
	+$(MAKE) -C $(BUILD_WORK)/texinfo/build
	+$(MAKE) -C $(BUILD_WORK)/texinfo/build install \
		DESTDIR=$(BUILD_STAGE)/texinfo
ifneq ($(filter -flto%,$(CFLAGS)),)
	# Keep installed LTO commands/XS modules; rebuild their public archives only.
	find $(BUILD_WORK)/texinfo/build/tp/Texinfo/XS -name '*.lo' -type f -delete
	rm -f $(BUILD_WORK)/texinfo/build/tp/Texinfo/XS/{gnulib/lib/libgnu,XSParagraph,MiscXS,Parsetexi}.la
	+$(MAKE) -C $(BUILD_WORK)/texinfo/build/tp/Texinfo/XS/gnulib/lib libgnu.la \
		CFLAGS="$$(sed -n 's/^CFLAGS = //p' $(BUILD_WORK)/texinfo/build/tp/Texinfo/XS/gnulib/lib/Makefile) -fno-lto"
	+$(MAKE) -C $(BUILD_WORK)/texinfo/build/tp/Texinfo/XS XSParagraph.la MiscXS.la Parsetexi.la \
		CFLAGS="$$(sed -n 's/^CFLAGS = //p' $(BUILD_WORK)/texinfo/build/tp/Texinfo/XS/Makefile) -fno-lto" \
		LDFLAGS="$$(sed -n 's/^LDFLAGS = //p' $(BUILD_WORK)/texinfo/build/tp/Texinfo/XS/Makefile) -fno-lto -static"
	cp -a $(BUILD_WORK)/texinfo/build/tp/Texinfo/XS/.libs/{XSParagraph,MiscXS,Parsetexi}.a $(BUILD_STAGE)/texinfo/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/texinfo/
endif
	$(call AFTER_BUILD)
endif

texinfo-package: texinfo-stage
	# texinfo.mk Package Structure
	rm -rf $(BUILD_DIST)/texinfo

	# texinfo.mk Prep texinfo
	cp -a $(BUILD_STAGE)/texinfo $(BUILD_DIST)

	# texinfo.mk Sign
	$(call SIGN,texinfo,general.xml)

	# texinfo.mk Make .debs
	$(call PACK,texinfo,DEB_TEXINFO_V)

	# texinfo.mk Build cleanup
	rm -rf $(BUILD_DIST)/texinfo

.PHONY: texinfo texinfo-package
