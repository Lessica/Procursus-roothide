ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS              += libimobiledevice
LIBIMOBILEDEVICE_COMMIT  := 2eec1b9a172354c8521123a767d998b17bd2ac18
LIBIMOBILEDEVICE_VERSION := 1.3.0+git20220702.$(shell echo $(LIBIMOBILEDEVICE_COMMIT) | cut -c -7)
DEB_LIBIMOBILEDEVICE_V   ?= $(LIBIMOBILEDEVICE_VERSION)-2

libimobiledevice-setup: setup
	$(call GITHUB_ARCHIVE,libimobiledevice,libimobiledevice,$(LIBIMOBILEDEVICE_COMMIT),$(LIBIMOBILEDEVICE_COMMIT))
	$(call EXTRACT_TAR,libimobiledevice-$(LIBIMOBILEDEVICE_COMMIT).tar.gz,libimobiledevice-$(LIBIMOBILEDEVICE_COMMIT),libimobiledevice)

ifneq ($(wildcard $(BUILD_WORK)/libimobiledevice/.build_complete),)
libimobiledevice:
	@echo "Using previously built libimobiledevice."
else
libimobiledevice: libimobiledevice-setup libusbmuxd libplist libimobiledevice-glue openssl
	cd $(BUILD_WORK)/libimobiledevice && ./autogen.sh \
		$(DEFAULT_CONFIGURE_FLAGS) \
		PACKAGE_VERSION="$(LIBIMOBILEDEVICE_VERSION)" \
		--without-cython
	+$(MAKE) -C $(BUILD_WORK)/libimobiledevice
	+$(MAKE) -C $(BUILD_WORK)/libimobiledevice install \
		DESTDIR="$(BUILD_STAGE)/libimobiledevice"
ifneq ($(filter -flto%,$(CFLAGS)),)
	# Rebuild every convenience library folded into the public archive, after
	# preserving the original LTO runtime and command-line tools in stage.
	+set -e; for entry in common:libinternalcommon.la 3rd_party/ed25519:libed25519.la 3rd_party/libsrp6a-sha512:libsrp6a-sha512.la src:libimobiledevice-1.0.la; do \
		sub=$${entry%:*}; target=$${entry##*:}; \
		if [ -f $(BUILD_WORK)/libimobiledevice/$$sub/$$target ]; then \
			find $(BUILD_WORK)/libimobiledevice/$$sub -name '*.lo' -type f -delete; \
			rm -f $(BUILD_WORK)/libimobiledevice/$$sub/$$target; \
			$(MAKE) -C $(BUILD_WORK)/libimobiledevice/$$sub $$target \
				CFLAGS="$$(sed -n 's/^CFLAGS = //p' $(BUILD_WORK)/libimobiledevice/$$sub/Makefile) -fno-lto" \
				LDFLAGS="$$(sed -n 's/^LDFLAGS = //p' $(BUILD_WORK)/libimobiledevice/$$sub/Makefile) -fno-lto -static"; \
		fi; \
	done
	cp -a $(BUILD_WORK)/libimobiledevice/src/.libs/libimobiledevice-1.0.a \
		$(BUILD_STAGE)/libimobiledevice/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/
endif
	$(call AFTER_BUILD,copy)
endif

libimobiledevice-package: libimobiledevice-stage
	# libimobiledevice.mk Package Structure
	rm -rf $(BUILD_DIST)/libimobiledevice{6,-dev,-utils}
	mkdir -p $(BUILD_DIST)/libimobiledevice6/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib \
		$(BUILD_DIST)/libimobiledevice-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib \
		$(BUILD_DIST)/libimobiledevice-utils/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)

	# libimobiledevice.mk Prep libimobiledevice6
	cp -a $(BUILD_STAGE)/libimobiledevice/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libimobiledevice-1.0.6.dylib $(BUILD_DIST)/libimobiledevice6/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libimobiledevice.mk Prep libimobiledevice-dev
	cp -a $(BUILD_STAGE)/libimobiledevice/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/{pkgconfig,libimobiledevice-1.0.{a,dylib}} $(BUILD_DIST)/libimobiledevice-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libimobiledevice/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include $(BUILD_DIST)/libimobiledevice-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)

	# libimobiledevice.mk Prep libimobiledevice-utils
	cp -a $(BUILD_STAGE)/libimobiledevice/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/{bin,share} $(BUILD_DIST)/libimobiledevice-utils/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)

	# libimobiledevice.mk Sign
	$(call SIGN,libimobiledevice6,general.xml)
	$(call SIGN,libimobiledevice-utils,usb.xml)

	# libimobiledevice.mk Make .debs
	$(call PACK,libimobiledevice6,DEB_LIBIMOBILEDEVICE_V)
	$(call PACK,libimobiledevice-dev,DEB_LIBIMOBILEDEVICE_V)
	$(call PACK,libimobiledevice-utils,DEB_LIBIMOBILEDEVICE_V)

	# libimobiledevice.mk Build cleanup
	rm -rf $(BUILD_DIST)/libimobiledevice{6,-dev,-utils}

.PHONY: libimobiledevice libimobiledevice-package
