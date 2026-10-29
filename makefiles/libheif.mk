ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS     += libheif
LIBHEIF_VERSION := 1.12.0
DEB_LIBHEIF_V   ?= $(LIBHEIF_VERSION)-2

libheif-setup: setup
	$(call DOWNLOAD_FILES,$(BUILD_SOURCE),https://github.com/strukturag/libheif/releases/download/v$(LIBHEIF_VERSION)/libheif-$(LIBHEIF_VERSION).tar.gz)
	$(call EXTRACT_TAR,libheif-$(LIBHEIF_VERSION).tar.gz,libheif-$(LIBHEIF_VERSION),libheif)
	$(call DO_PATCH,libheif,libheif,-p1)

ifneq ($(wildcard $(BUILD_WORK)/libheif/.build_complete),)
libheif:
	@echo "Using previously built libheif."
else
libheif: libheif-setup x265 libde265 aom rav1e dav1d
	cd $(BUILD_WORK)/libheif && ./configure -C \
		$(DEFAULT_CONFIGURE_FLAGS) \
		CXX="$(CXX) $(CXXFLAGS)" \
		--disable-tests \
		--disable-examples
	+$(MAKE) -C $(BUILD_WORK)/libheif
	+$(MAKE) -C $(BUILD_WORK)/libheif install \
		DESTDIR=$(BUILD_STAGE)/libheif
ifneq ($(filter iphoneos% appletvos%,$(MEMO_TARGET)),)
	# iOS uses libc++, including static pkg-config consumers.
	sed -i 's/-lstdc++/-lc++/g' $(BUILD_STAGE)/libheif/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/pkgconfig/libheif.pc
endif
ifneq ($(filter -flto%,$(CFLAGS)),)
	# Preserve the installed LTO dylib and all configured codec backends.
	+$(MAKE) -C $(BUILD_WORK)/libheif/libheif clean
	+$(MAKE) -C $(BUILD_WORK)/libheif/libheif libheif.la \
		CFLAGS="$$(sed -n 's/^CFLAGS = //p' $(BUILD_WORK)/libheif/libheif/Makefile | sed -E 's/(^|[[:space:]])-flto(=[^[:space:]]*)?//g') -fno-lto" \
		CXXFLAGS="$$(sed -n 's/^CXXFLAGS = //p' $(BUILD_WORK)/libheif/libheif/Makefile | sed -E 's/(^|[[:space:]])-flto(=[^[:space:]]*)?//g') -fno-lto" \
		LDFLAGS="$$(sed -n 's/^LDFLAGS = //p' $(BUILD_WORK)/libheif/libheif/Makefile | sed -E 's/(^|[[:space:]])-flto(=[^[:space:]]*)?//g') -static"
	cp -a $(BUILD_WORK)/libheif/libheif/.libs/libheif.a $(BUILD_STAGE)/libheif/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/
endif
	$(call AFTER_BUILD,copy)
endif

libheif-package: libheif-stage
	# libheif.mk Package Structure
	rm -rf $(BUILD_DIST)/libheif{1,-dev}
	mkdir -p $(BUILD_DIST)/libheif{1,-dev}/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libheif.mk Prep libheif1
	cp -a $(BUILD_STAGE)/libheif/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libheif.1.dylib $(BUILD_DIST)/libheif1/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libheif.mk Prep libheif-dev
	cp -a $(BUILD_STAGE)/libheif/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/{libheif.{dylib,a},pkgconfig} $(BUILD_DIST)/libheif-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libheif/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include $(BUILD_DIST)/libheif-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)

	# libheif.mk Sign
	$(call SIGN,libheif1,general.xml)

	# libheif.mk Make .debs
	$(call PACK,libheif1,DEB_LIBHEIF_V)
	$(call PACK,libheif-dev,DEB_LIBHEIF_V)

	# libheif.mk Build cleanup
	rm -rf $(BUILD_DIST)/libheif{1,-dev}

.PHONY: libheif libheif-package
