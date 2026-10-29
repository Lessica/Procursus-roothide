ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

STRAPPROJECTS += xz
XZ_VERSION    := 5.4.4
DEB_XZ_V      ?= $(XZ_VERSION)-1

xz-setup: setup
	$(call DOWNLOAD_FILES,$(BUILD_SOURCE),https://web.archive.org/web/20230930004231id_/https://tukaani.org/xz/xz-5.4.4.tar.xz{.sig$(comma)})
	$(call PGP_VERIFY,xz-$(XZ_VERSION).tar.xz)
	$(call EXTRACT_TAR,xz-$(XZ_VERSION).tar.xz,xz-$(XZ_VERSION),xz)

ifneq ($(wildcard $(BUILD_WORK)/xz/.build_complete),)
xz:
	@echo "Using previously built xz."
else
xz: xz-setup gettext
	cd $(BUILD_WORK)/xz && ./configure -C \
		$(DEFAULT_CONFIGURE_FLAGS) \
		--libdir="$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)$(MEMO_ALT_PREFIX)/lib" \
		--enable-threads \
		--disable-xzdec \
		--disable-lzmadec \
		--enable-nls \
		--with-libintl-prefix="$(BUILD_BASE)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)"
	+$(MAKE) -C $(BUILD_WORK)/xz install \
		DESTDIR="$(BUILD_STAGE)/xz"
ifneq ($(filter -flto%,$(CFLAGS)),)
	# Keep the installed full-feature LTO dylib/tools; only its public static
	# archive gets native objects with the same full-feature configuration.
	+$(MAKE) -C $(BUILD_WORK)/xz/src/liblzma clean
	+$(MAKE) -C $(BUILD_WORK)/xz/src/liblzma liblzma.la \
		CFLAGS="$$(sed -n 's/^CFLAGS = //p' $(BUILD_WORK)/xz/src/liblzma/Makefile) -fno-lto" \
		CCASFLAGS="$$(sed -n 's/^CCASFLAGS = //p' $(BUILD_WORK)/xz/src/liblzma/Makefile) -fno-lto" \
		LDFLAGS="$(filter-out -flto%,$(LDFLAGS)) -static"
	cp -a $(BUILD_WORK)/xz/src/liblzma/.libs/liblzma.a \
		$(BUILD_STAGE)/xz/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)$(MEMO_ALT_PREFIX)/lib/
	# The pre-existing decoder-only pass below must compile its original LTO
	# objects, rather than reuse this static-only native pass.
	+$(MAKE) -C $(BUILD_WORK)/xz/src/liblzma clean
endif
	cd $(BUILD_WORK)/xz && ./configure -C \
		$(DEFAULT_CONFIGURE_FLAGS) \
		--disable-shared \
		--enable-nls \
		--disable-encoders \
		--enable-small \
		--disable-threads \
		--disable-lzmainfo \
		--disable-scripts \
		--disable-xz \
		--disable-lzma-links \
		--with-libintl-prefix="$(BUILD_BASE)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)"
	+$(MAKE) -C $(BUILD_WORK)/xz install \
		DESTDIR="$(BUILD_STAGE)/xz"
ifneq ($(MEMO_ALT_PREFIX),)
	# Do not expose the decoder-only private library ahead of the public one.
	rm -f $(BUILD_STAGE)/xz/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/liblzma.{a,la} \
		$(BUILD_STAGE)/xz/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/pkgconfig/liblzma.pc
endif
	$(call AFTER_BUILD,copy)
endif

xz-package: xz-stage
	# xz.mk Package Structure
	rm -rf $(BUILD_DIST)/xz{dec,-utils} $(BUILD_DIST)/liblzma{5,-dev}
	mkdir -p $(BUILD_DIST)/xz{dec,-utils}/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/{bin,share/man/man1} \
		$(BUILD_DIST)/liblzma{5,-dev}/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)$(MEMO_ALT_PREFIX)/lib

	# xz.mk Prep xz-utils
	cp -a $(BUILD_STAGE)/xz/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/!(*dec) $(BUILD_DIST)/xz-utils/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin
	cp -a $(BUILD_STAGE)/xz/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/man1/!(*dec.1$(MEMO_MANPAGE_SUFFIX)) $(BUILD_DIST)/xz-utils/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/man1
	cp -a $(BUILD_STAGE)/xz/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/locale $(BUILD_DIST)/xz-utils/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share

	# xz.mk Prep xzdec
	cp -a $(BUILD_STAGE)/xz/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/*dec $(BUILD_DIST)/xzdec/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin
	cp -a $(BUILD_STAGE)/xz/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/man1/*dec.1$(MEMO_MANPAGE_SUFFIX) $(BUILD_DIST)/xzdec/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/man1

	# xz.mk Prep liblzma5
	cp -a $(BUILD_STAGE)/xz/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)$(MEMO_ALT_PREFIX)/lib/liblzma.5.dylib $(BUILD_DIST)/liblzma5/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)$(MEMO_ALT_PREFIX)/lib

	# xz.mk Prep liblzma-dev
	cp -a $(BUILD_STAGE)/xz/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)$(MEMO_ALT_PREFIX)/lib/!(liblzma.5.dylib) $(BUILD_DIST)/liblzma-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)$(MEMO_ALT_PREFIX)/lib
	cp -a $(BUILD_STAGE)/xz/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include $(BUILD_DIST)/liblzma-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)

	# xz.mk Sign
	$(call SIGN,xz-utils,general.xml)
	$(call SIGN,xzdec,general.xml)
	$(call SIGN,liblzma5,general.xml)

	# xz.mk Make .debs
	$(call PACK,xz-utils,DEB_XZ_V)
	$(call PACK,xzdec,DEB_XZ_V)
	$(call PACK,liblzma5,DEB_XZ_V)
	$(call PACK,liblzma-dev,DEB_XZ_V)

	# xz.mk Build cleanup
	rm -rf $(BUILD_DIST)/xz{dec,-utils} $(BUILD_DIST)/liblzma{5,-dev}

.PHONY: xz xz-package
