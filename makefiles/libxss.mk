ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS   += libxss
LIBXSS_VERSION := 1.2.3
DEB_LIBXSS_V   ?= $(LIBXSS_VERSION)-1

libxss-setup: setup
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/libxss-$(LIBXSS_VERSION).tar.bz2, \
		https://gitlab.freedesktop.org/xorg/lib/libxscrnsaver/-/archive/libXScrnSaver-$(LIBXSS_VERSION)/libxscrnsaver-libXScrnSaver-$(LIBXSS_VERSION).tar.bz2)
	$(call EXTRACT_TAR,libxss-$(LIBXSS_VERSION).tar.bz2,libxscrnsaver-libXScrnSaver-$(LIBXSS_VERSION),libxss)

ifneq ($(wildcard $(BUILD_WORK)/libxss/.build_complete),)
libxss:
	@echo "Using previously built libxss."
else
libxss: libxss-setup libx11 libxext util-macros
	cd $(BUILD_WORK)/libxss && autoreconf -fi && ./configure -C \
		$(DEFAULT_CONFIGURE_FLAGS) \
		  --enable-malloc0returnsnull=no
	+$(MAKE) -C $(BUILD_WORK)/libxss
	+$(MAKE) -C $(BUILD_WORK)/libxss install \
		DESTDIR=$(BUILD_STAGE)/libxss
ifneq ($(filter -flto%,$(CFLAGS)),)
	# Preserve installed LTO outputs and configured static compiler flags.
	+$(MAKE) -C $(BUILD_WORK)/libxss/src clean
	+$(MAKE) -C $(BUILD_WORK)/libxss/src libXss.la \
		CFLAGS="$$(sed -n 's/^CFLAGS = //p' $(BUILD_WORK)/libxss/src/Makefile | sed -E 's/(^|[[:space:]])-flto(=[^[:space:]]*)?//g') -fno-lto" \
		LDFLAGS="$$(sed -n 's/^LDFLAGS = //p' $(BUILD_WORK)/libxss/src/Makefile | sed -E 's/(^|[[:space:]])-flto(=[^[:space:]]*)?//g') -static"
	cp -a $(BUILD_WORK)/libxss/src/.libs/libXss.a $(BUILD_STAGE)/libxss/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/
endif
	$(call AFTER_BUILD,copy)
endif

libxss-package: libxss-stage
	# libxss.mk Package Structure
	rm -rf $(BUILD_DIST)/libxss{1,-dev}
	mkdir -p $(BUILD_DIST)/libxss{1,-dev}/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	
	# libxss.mk Prep libxss1
	cp -a $(BUILD_STAGE)/libxss/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libXss.1.dylib $(BUILD_DIST)/libxss1/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	
	# libxss.mk Prep libxss-dev
	cp -a $(BUILD_STAGE)/libxss/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/{include,share} $(BUILD_DIST)/libxss-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)
	cp -a $(BUILD_STAGE)/libxss/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/{pkgconfig,libXss.{dylib,a}} $(BUILD_DIST)/libxss-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	
	# libxss.mk Sign
	$(call SIGN,libxss1,general.xml)
	
	# libxss.mk Make .debs
	$(call PACK,libxss1,DEB_LIBXSS_V)
	$(call PACK,libxss-dev,DEB_LIBXSS_V)
	
	# libxss.mk Build cleanup
	rm -rf $(BUILD_DIST)/libxss{1,-dev}

.PHONY: libxss libxss-package
