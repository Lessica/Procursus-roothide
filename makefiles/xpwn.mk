ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS  += xpwn
XPWN_COMMIT  := c89fba5f7390fde9bb0443d0c7be81ccc17f02ff
XPWN_VERSION := 0.5.8+git20220711.$(shell echo $(XPWN_COMMIT) | cut -c -7)
LIBUSB_COMPAT_VERSION := 0.1.9
LIBUSB_COMPAT_COMMIT := 4831748a1439aec81e9cbb9984b1b0289c1c7051
DEB_XPWN_V   ?= $(XPWN_VERSION)-3

xpwn-setup: setup
	$(call GITHUB_ARCHIVE,OothecaPickle,xpwn,$(XPWN_COMMIT),$(XPWN_COMMIT))
	$(call EXTRACT_TAR,xpwn-$(XPWN_COMMIT).tar.gz,xpwn-$(XPWN_COMMIT),xpwn)
	$(call DO_PATCH,xpwn,xpwn,-p1)
	$(call GITHUB_ARCHIVE,libusb,libusb-compat-0.1,$(LIBUSB_COMPAT_COMMIT),$(LIBUSB_COMPAT_COMMIT))
	$(call EXTRACT_TAR,libusb-compat-0.1-$(LIBUSB_COMPAT_COMMIT).tar.gz,libusb-compat-0.1-$(LIBUSB_COMPAT_COMMIT),libusb-compat)
	cp -a $(BUILD_WORK)/libusb-compat/COPYING $(BUILD_WORK)/xpwn/COPYING

	sed -i 's/powerpc-apple-darwin8-libtool/libtool/' $(BUILD_WORK)/xpwn/ipsw-patch/CMakeLists.txt

ifneq ($(wildcard $(BUILD_WORK)/xpwn/.build_complete),)
xpwn:
	@echo "Using previously built xpwn."
else
xpwn: xpwn-setup libpng16 openssl libusb
	cd $(BUILD_WORK)/libusb-compat && ./autogen.sh \
		$(DEFAULT_CONFIGURE_FLAGS) \
		--disable-shared --enable-static --disable-examples-build
	+$(MAKE) -C $(BUILD_WORK)/libusb-compat
	+$(MAKE) -C $(BUILD_WORK)/libusb-compat install DESTDIR="$(BUILD_STAGE)/libusb-compat"
	mkdir -p $(BUILD_BASE)$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/{include,lib}
	cp -a $(BUILD_STAGE)/libusb-compat$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include/usb.h $(BUILD_BASE)$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include/
	cp -a $(BUILD_STAGE)/libusb-compat$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libusb.a $(BUILD_BASE)$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/
	cd $(BUILD_WORK)/xpwn && cmake . \
		$(DEFAULT_CMAKE_FLAGS) \
		-DUSB_INCLUDE_DIR="$(BUILD_BASE)$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include" \
		-DUSB_INCLUDE_DIRS="$(BUILD_BASE)$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include" \
		-DUSB_LIBRARY="$(BUILD_BASE)$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libusb.a" \
		-DUSB_LIBRARIES="$(BUILD_BASE)$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libusb.a;$(BUILD_BASE)$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libusb-1.0.dylib" \
		-DBZIP2_LIBRARIES="-L$(TARGET_SYSROOT)/usr/lib -lbz2" \
		-DZLIB_LIBRARY="-L$(TARGET_SYSROOT)/usr/lib -lz"
	+$(MAKE) -C $(BUILD_WORK)/xpwn
	+$(MAKE) -C $(BUILD_WORK)/xpwn install \
		DESTDIR=$(BUILD_STAGE)/xpwn
	mv $(BUILD_STAGE)/xpwn/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/ipsw $(BUILD_STAGE)/xpwn/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/ipsw-xpwn
	mkdir -p {$(BUILD_BASE),$(BUILD_STAGE)/xpwn}/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/{include/xpwn,lib/xpwn}
	cp -a $(BUILD_WORK)/xpwn/includes/* $(BUILD_STAGE)/xpwn/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include/xpwn
	+$(MAKE) -C $(BUILD_WORK)/xpwn xpwn-native minizip-native common-native hfs-native dmg-native
	set -e; for entry in ipsw-patch:xpwn minizip:minizip common:common hfs:hfs dmg:dmg; do \
		sub=$${entry%:*}; name=$${entry##*:}; \
		cp -a $(BUILD_WORK)/xpwn/$$sub/lib$$name-native.a $(BUILD_STAGE)/xpwn/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/xpwn/lib$$name.a; \
	done
ifneq ($(filter -flto%,$(CFLAGS)),)
	# libusb-compat is also public, but its original LTO archive was already
	# consumed by the normal installed xpwn programs above.
	find $(BUILD_WORK)/libusb-compat/libusb -name '*.lo' -type f -delete
	rm -f $(BUILD_WORK)/libusb-compat/libusb/libusb.la
	+$(MAKE) -C $(BUILD_WORK)/libusb-compat/libusb libusb.la \
		CFLAGS="$$(sed -n 's/^CFLAGS = //p' $(BUILD_WORK)/libusb-compat/libusb/Makefile) -fno-lto" \
		LDFLAGS="$$(sed -n 's/^LDFLAGS = //p' $(BUILD_WORK)/libusb-compat/libusb/Makefile) -fno-lto -static"
	cp -a $(BUILD_WORK)/libusb-compat/libusb/.libs/libusb.a $(BUILD_STAGE)/libusb-compat$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/
endif
	$(call AFTER_BUILD,copy)
endif

xpwn-package: xpwn-stage
	# xpwn.mk Package Structure
	rm -rf $(BUILD_DIST)/{libxpwn-dev,xpwn}
	mkdir -p $(BUILD_DIST)/{libxpwn-dev,xpwn}/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)

	# xpwn.mk Prep xpwn
	cp -a $(BUILD_STAGE)/xpwn/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/{bin,share} $(BUILD_DIST)/xpwn/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)
	cp -a $(BUILD_STAGE)/xpwn/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/{dfu-util,xpwn,dripwn,ramdisk.dmg} $(BUILD_DIST)/xpwn/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)

	# xpwn.mk Prep libxpwn-dev
	cp -a $(BUILD_STAGE)/xpwn/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/{include,lib} $(BUILD_DIST)/libxpwn-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)
	cp -a $(BUILD_STAGE)/libusb-compat$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include/usb.h $(BUILD_DIST)/libxpwn-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include/
	cp -a $(BUILD_STAGE)/libusb-compat$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libusb.a $(BUILD_DIST)/libxpwn-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/

	# xpwn.mk Sign
	$(call SIGN,xpwn,general.xml)

	# xpwn.mk Make .debs
	$(call PACK,xpwn,DEB_XPWN_V)
	$(call PACK,libxpwn-dev,DEB_XPWN_V)

	# xpwn.mk Build cleanup
	rm -rf $(BUILD_DIST)/{libxpwn-dev,xpwn}

.PHONY: xpwn xpwn-package
