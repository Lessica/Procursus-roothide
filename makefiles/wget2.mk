ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS   += wget2
WGET2_VERSION := 2.0.1
DEB_WGET2_V   ?= $(WGET2_VERSION)-2

wget2-setup: setup
	$(call DOWNLOAD_FILES,$(BUILD_SOURCE),https://ftpmirror.gnu.org/wget/wget2-$(WGET2_VERSION).tar.gz{$(comma).sig})
	$(call PGP_VERIFY,wget2-$(WGET2_VERSION).tar.gz)
	$(call EXTRACT_TAR,wget2-$(WGET2_VERSION).tar.gz,wget2-$(WGET2_VERSION),wget2)
	$(call DO_PATCH,wget2,wget2,-p1)

ifneq ($(wildcard $(BUILD_WORK)/wget2/.build_complete),)
wget2:
	@echo "Using previously built wget2."
else
wget2: wget2-setup openssl pcre2 xz zstd nghttp2 libidn2 gettext brotli gpgme libhsts
	cd $(BUILD_WORK)/wget2 && ./configure -C \
		$(DEFAULT_CONFIGURE_FLAGS) \
		--with-ssl=openssl \
		--with-openssl \
		--with-lzma \
		--with-bzip2 \
		--disable-valgrind-tests \
		--without-libpsl \
		--disable-doc # Disable doc until we have `graphviz`.
	+$(MAKE) -C $(BUILD_WORK)/wget2
	+$(MAKE) -C $(BUILD_WORK)/wget2 install \
		DESTDIR="$(BUILD_STAGE)/wget2"
ifneq ($(filter -flto%,$(CFLAGS)),)
	# Preserve installed LTO runtime; include both convenience libraries.
	find $(BUILD_WORK)/wget2/{lib,libwget} -name '*.lo' -type f -delete
	rm -f $(BUILD_WORK)/wget2/lib/libgnu.la $(BUILD_WORK)/wget2/libwget/{libcsstokenizer,libwget}.la
	+$(MAKE) -C $(BUILD_WORK)/wget2/lib libgnu.la \
		CFLAGS="$$(sed -n 's/^CFLAGS = //p' $(BUILD_WORK)/wget2/lib/Makefile) -fno-lto"
	+$(MAKE) -C $(BUILD_WORK)/wget2/libwget libcsstokenizer.la libwget.la \
		CFLAGS="$$(sed -n 's/^CFLAGS = //p' $(BUILD_WORK)/wget2/libwget/Makefile) -fno-lto" \
		LDFLAGS="$$(sed -n 's/^LDFLAGS = //p' $(BUILD_WORK)/wget2/libwget/Makefile) -fno-lto -static"
	cp -a $(BUILD_WORK)/wget2/libwget/.libs/libwget.a $(BUILD_STAGE)/wget2/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/
endif
	$(call AFTER_BUILD,copy)
endif

wget2-package: wget2-stage
	# wget2.mk Package Structure
	rm -rf $(BUILD_DIST)/wget2{,-dev} $(BUILD_DIST)/libwget1
	mkdir -p $(BUILD_DIST)/wget2/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/{bin,share/man} \
		$(BUILD_DIST)/libwget1/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib \
		$(BUILD_DIST)/wget2-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/{lib,share/man}

	# wget2.mk Prep wget2
	cp -a $(BUILD_STAGE)/wget2/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/wget2 $(BUILD_DIST)/wget2/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin
#	cp -a $(BUILD_STAGE)/wget2/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/man1 $(BUILD_DIST)/wget2/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man
	cp -a $(BUILD_STAGE)/wget2/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/locale $(BUILD_DIST)/wget2/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share

	# wget2.mk Prep libwget1
	cp -a $(BUILD_STAGE)/wget2/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libwget.1.dylib $(BUILD_DIST)/libwget1/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# wget2.mk Prep wget2-dev
	cp -a $(BUILD_STAGE)/wget2/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include $(BUILD_DIST)/wget2-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)
	cp -a $(BUILD_STAGE)/wget2/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/!(libwget.1.dylib) $(BUILD_DIST)/wget2-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
#	cp -a $(BUILD_STAGE)/wget2/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/man3 $(BUILD_DIST)/wget2/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man

	# wget2.mk Sign
	$(call SIGN,wget2,general.xml)
	$(call SIGN,libwget1,general.xml)
	$(call SIGN,wget2-dev,general.xml)

	# wget2.mk Make .debs
	$(call PACK,wget2,DEB_WGET2_V)
	$(call PACK,libwget1,DEB_WGET2_V)
	$(call PACK,wget2-dev,DEB_WGET2_V)

	# wget2.mk Build cleanup
	rm -rf $(BUILD_DIST)/wget2{,-dev} $(BUILD_DIST)/libwget1

.PHONY: wget2 wget2-package
