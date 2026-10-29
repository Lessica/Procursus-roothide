ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS         += libipatcher
LIBIPATCHER_VERSION := 81
LIBIPATCHER_COMMIT  := ad44d0da23f5120c3c77a72062bd627c50f37e71
LIBIPATCHER_IBOOT32PATCHER_COMMIT := 266f2383874b7242ec65ad4feb8b89a4b6ac7215
LIBIPATCHER_JSSY_COMMIT           := 10ee9e17ab48cbeccc1038e5d7e72c5421719a51
DEB_LIBIPATCHER_V   ?= $(LIBIPATCHER_VERSION)-4

libipatcher-setup: setup
	$(call GITHUB_ARCHIVE,tihmstar,libipatcher,$(LIBIPATCHER_VERSION),$(LIBIPATCHER_VERSION))
	$(call EXTRACT_TAR,libipatcher-$(LIBIPATCHER_VERSION).tar.gz,libipatcher-$(LIBIPATCHER_VERSION),libipatcher)

	$(call GITHUB_ARCHIVE,tihmstar,iBoot32Patcher,$(LIBIPATCHER_IBOOT32PATCHER_COMMIT),$(LIBIPATCHER_IBOOT32PATCHER_COMMIT))
	$(call GITHUB_ARCHIVE,tihmstar,jssy,$(LIBIPATCHER_JSSY_COMMIT),$(LIBIPATCHER_JSSY_COMMIT))
	rm -rf $(BUILD_WORK)/libipatcher/external/{jssy,iBoot32Patcher}
	rm -f $(BUILD_WORK)/libipatcher/arm64-address-type.patch.done
	$(call EXTRACT_TAR,jssy-$(LIBIPATCHER_JSSY_COMMIT).tar.gz,jssy-$(LIBIPATCHER_JSSY_COMMIT),libipatcher/external/jssy)
	$(call EXTRACT_TAR,iBoot32Patcher-$(LIBIPATCHER_IBOOT32PATCHER_COMMIT).tar.gz,iBoot32Patcher-$(LIBIPATCHER_IBOOT32PATCHER_COMMIT),libipatcher/external/iBoot32Patcher)
	$(call DO_PATCH,libipatcher,libipatcher,-p1)

	sed -i '/AC_FUNC_MALLOC/d' $(BUILD_WORK)/libipatcher/configure.ac
	sed -i '/AC_FUNC_REALLOC/d' $(BUILD_WORK)/libipatcher/configure.ac
	sed -i 's|$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/local/lib/|$(BUILD_BASE)$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib|g' $(BUILD_WORK)/libipatcher/libipatcher/Makefile.am
	sed -i 's/git rev\-list \-\-count HEAD/printf ${LIBIPATCHER_VERSION}/g' $(BUILD_WORK)/libipatcher/configure.ac
	sed -i 's/git rev\-parse HEAD/printf ${LIBIPATCHER_COMMIT}/g' $(BUILD_WORK)/libipatcher/configure.ac

ifneq ($(wildcard $(BUILD_WORK)/libipatcher/.build_complete),)
libipatcher:
	@echo "Using previously built libipatcher."
else
libipatcher: libipatcher-setup libpng16 openssl img4tool liboffsetfinder64 libgeneral libplist curl xpwn
	cd $(BUILD_WORK)/libipatcher && $(LIBTOOLIZE) --force --copy
	cd $(BUILD_WORK)/libipatcher && ./autogen.sh \
		$(DEFAULT_CONFIGURE_FLAGS) \
		CFLAGS="$(CFLAGS) -I$(BUILD_BASE)$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include/xpwn" \
		CPPFLAGS="$(CPPFLAGS) -I$(BUILD_BASE)$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include/xpwn" \
		LDFLAGS="$(LDFLAGS) -L$(BUILD_WORK)/xpwn/common -L$(BUILD_WORK)/xpwn/ipsw-patch -L$(BUILD_BASE)$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/xpwn"
	+$(MAKE) -C $(BUILD_WORK)/libipatcher \
		LIBS="-lcurl"
	+$(MAKE) -C $(BUILD_WORK)/libipatcher install \
		DESTDIR="$(BUILD_STAGE)/libipatcher"
ifneq ($(filter -flto%,$(CXXFLAGS)),)
	# Preserve normal LTO runtime, including original xpwn static link input;
	# rebuild both folded convenience libraries together with the public archive.
	find $(BUILD_WORK)/libipatcher -name '*.lo' -type f -delete
	rm -f $(BUILD_WORK)/libipatcher/libipatcher/{libiBoot32Patcher,libjssy,libipatcher}.la
	+$(MAKE) -C $(BUILD_WORK)/libipatcher/libipatcher libiBoot32Patcher.la libjssy.la libipatcher.la \
		CFLAGS="$$(sed -n 's/^CFLAGS = //p' $(BUILD_WORK)/libipatcher/libipatcher/Makefile) -fno-lto" \
		CXXFLAGS="$$(sed -n 's/^CXXFLAGS = //p' $(BUILD_WORK)/libipatcher/libipatcher/Makefile) -fno-lto" \
		LDFLAGS="$$(sed -n 's/^LDFLAGS = //p' $(BUILD_WORK)/libipatcher/libipatcher/Makefile) -fno-lto -static" \
		LIBS="-lcurl"
	cp -a $(BUILD_WORK)/libipatcher/libipatcher/.libs/libipatcher.a \
		$(BUILD_STAGE)/libipatcher/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/
endif
	$(call AFTER_BUILD,copy)
endif

libipatcher-package: libipatcher-stage
	# libipatcher.mk Package Structure
	rm -rf $(BUILD_DIST)/libipatcher{0,-dev}
	mkdir -p $(BUILD_DIST)/libipatcher{0,-dev}/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libipatcher.mk Prep libipatcher0
	cp -a $(BUILD_STAGE)/libipatcher/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libipatcher.0.dylib $(BUILD_DIST)/libipatcher0/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libipatcher.mk Prep libipatcher-dev
	cp -a $(BUILD_STAGE)/libipatcher/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/!(libipatcher.0.dylib) $(BUILD_DIST)/libipatcher-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libipatcher/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include $(BUILD_DIST)/libipatcher-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)

	# libipatcher.mk Sign
	$(call SIGN,libipatcher0,general.xml)

	# libipatcher.mk Make .debs
	$(call PACK,libipatcher0,DEB_LIBIPATCHER_V)
	$(call PACK,libipatcher-dev,DEB_LIBIPATCHER_V)

	# libipatcher.mk Build cleanup
	rm -rf $(BUILD_DIST)/libipatcher{0,-dev}

.PHONY: libipatcher libipatcher-package
