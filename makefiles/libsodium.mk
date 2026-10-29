ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS           += libsodium
LIBSODIUM_VERSION     := 1.0.18
DEB_LIBSODIUM_V       ?= $(LIBSODIUM_VERSION)-1

libsodium-setup: setup
	$(call DOWNLOAD_FILES,$(BUILD_SOURCE),https://download.libsodium.org/libsodium/releases/old/libsodium-$(LIBSODIUM_VERSION).tar.gz)
	$(call EXTRACT_TAR,libsodium-$(LIBSODIUM_VERSION).tar.gz,libsodium-$(LIBSODIUM_VERSION),libsodium)

ifneq ($(wildcard $(BUILD_WORK)/libsodium/.build_complete),)
libsodium:
	@echo "Using previously built libsodium."
else
libsodium: libsodium-setup
	cd $(BUILD_WORK)/libsodium && ./configure -C \
		$(DEFAULT_CONFIGURE_FLAGS)
	+$(MAKE) -C $(BUILD_WORK)/libsodium
	+$(MAKE) -C $(BUILD_WORK)/libsodium install \
		DESTDIR=$(BUILD_STAGE)/libsodium
ifneq ($(filter -flto%,$(CFLAGS)),)
	# Rebuild the library's nested and CPU convenience objects after preserving the LTO install.
	find $(BUILD_WORK)/libsodium/src/libsodium -name '*.lo' -delete
	rm -f $(BUILD_WORK)/libsodium/src/libsodium/*.la
	+$(MAKE) -C $(BUILD_WORK)/libsodium/src/libsodium libsodium.la \
		CFLAGS="$$(sed -n 's/^CFLAGS = //p' $(BUILD_WORK)/libsodium/src/libsodium/Makefile) -fno-lto" \
		LDFLAGS="$$(sed -n 's/^LDFLAGS = //p' $(BUILD_WORK)/libsodium/src/libsodium/Makefile) -fno-lto -static"
	cp -a $(BUILD_WORK)/libsodium/src/libsodium/.libs/libsodium.a \
		$(BUILD_STAGE)/libsodium/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/
endif
	$(call AFTER_BUILD,copy)
endif

libsodium-package: libsodium-stage
	# libsodium.mk Package Structure
	rm -rf $(BUILD_DIST)/libsodium{23,-dev}
	mkdir -p $(BUILD_DIST)/libsodium{23,-dev}/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libsodium.mk Prep libsodium
	cp -a $(BUILD_STAGE)/libsodium/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libsodium.23.dylib $(BUILD_DIST)/libsodium23/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libsodium.mk Prep libsodium-dev
	cp -a $(BUILD_STAGE)/libsodium/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include $(BUILD_DIST)/libsodium-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)
	cp -a $(BUILD_STAGE)/libsodium/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/!(libsodium.23.dylib) $(BUILD_DIST)/libsodium-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libsodium.mk Sign
	$(call SIGN,libsodium23,general.xml)

	# libsodium.mk Make .debs
	$(call PACK,libsodium23,DEB_LIBSODIUM_V)
	$(call PACK,libsodium-dev,DEB_LIBSODIUM_V)

	# libsodium.mk Build cleanup
	rm -rf $(BUILD_DIST)/libsodium{23,-dev}

.PHONY: libsodium libsodium-package
