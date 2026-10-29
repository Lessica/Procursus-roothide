ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS    += libxaw
LIBXAW_VERSION := 1.0.13
DEB_LIBXAW_V  ?= $(LIBXAW_VERSION)-1
DEB_LIBXAW_DEV_V ?= $(LIBXAW_VERSION)-2

libxaw-setup: setup
	$(call DOWNLOAD_FILES,$(BUILD_SOURCE),https://www.x.org/archive/individual/lib/libXaw-$(LIBXAW_VERSION).tar.gz{$(comma).sig})
	$(call PGP_VERIFY,libXaw-$(LIBXAW_VERSION).tar.gz)
	$(call EXTRACT_TAR,libXaw-$(LIBXAW_VERSION).tar.gz,libXaw-$(LIBXAW_VERSION),libxaw)

ifneq ($(wildcard $(BUILD_WORK)/libxaw/.build_complete),)
libxaw:
	@echo "Using previously built libxaw."
else
libxaw: libxaw-setup libx11 libxau libxmu xorgproto libxpm libxt libxext
	cd $(BUILD_WORK)/libxaw && ./configure -C \
		$(DEFAULT_CONFIGURE_FLAGS) \
		--disable-xaw6
	+$(MAKE) -C $(BUILD_WORK)/libxaw
	+$(MAKE) -C $(BUILD_WORK)/libxaw install \
		DESTDIR=$(BUILD_STAGE)/libxaw
ifneq ($(filter -flto%,$(CFLAGS)),)
	# Preserve installed LTO outputs and configured static compiler flags.
	+$(MAKE) -C $(BUILD_WORK)/libxaw/src clean
	+$(MAKE) -C $(BUILD_WORK)/libxaw/src libXaw7.la \
		CFLAGS="$$(sed -n 's/^CFLAGS = //p' $(BUILD_WORK)/libxaw/src/Makefile | sed -E 's/(^|[[:space:]])-flto(=[^[:space:]]*)?//g') -fno-lto" \
		LDFLAGS="$$(sed -n 's/^LDFLAGS = //p' $(BUILD_WORK)/libxaw/src/Makefile | sed -E 's/(^|[[:space:]])-flto(=[^[:space:]]*)?//g') -static"
	cp -a $(BUILD_WORK)/libxaw/src/.libs/libXaw7.a $(BUILD_STAGE)/libxaw/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/
endif
	$(call AFTER_BUILD,copy)
endif

libxaw-package: libxaw-stage
# libxau.mk Package Structure
	rm -rf $(BUILD_DIST)/libxaw7 $(BUILD_DIST)/libxaw7-dev
	mkdir -p $(BUILD_DIST)/libxaw7{,-dev}/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libxaw.mk Prep libxaw7
	cp -a $(BUILD_STAGE)/libxaw/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libXaw{7,}.7.dylib $(BUILD_DIST)/libxaw7/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libxaw.mk Prep libxaw7-dev
	cp -a $(BUILD_STAGE)/libxaw/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libXaw7.{a,dylib} $(BUILD_DIST)/libxaw7-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libxaw/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/{include,share} $(BUILD_DIST)/libxaw7-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)
	cp -a $(BUILD_STAGE)/libxaw/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/pkgconfig $(BUILD_DIST)/libxaw7-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libxaw.mk Sign
	$(call SIGN,libxaw7,general.xml)

	# libxaw.mk Make .debs
	$(call PACK,libxaw7,DEB_LIBXAW_V)
	$(call PACK,libxaw7-dev,DEB_LIBXAW_DEV_V)

	# libxaw.mk Build cleanup
	rm -rf $(BUILD_DIST)/libxaw7 $(BUILD_DIST)/libxaw7-dev

.PHONY: libxaw libxaw-package
