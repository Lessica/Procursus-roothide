ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS       += libdvbpsi
LIBDVBPSI_VERSION := 1.3.3
DEB_LIBDVBPSI_V   ?= $(LIBDVBPSI_VERSION)-1

libdvbpsi-setup: setup
	$(call DOWNLOAD_FILES,$(BUILD_SOURCE),https://download.videolan.org/pub/videolan/libdvbpsi/$(LIBDVBPSI_VERSION)/libdvbpsi-$(LIBDVBPSI_VERSION).tar.bz2)
	$(call EXTRACT_TAR,libdvbpsi-$(LIBDVBPSI_VERSION).tar.bz2,libdvbpsi-$(LIBDVBPSI_VERSION),libdvbpsi)

ifneq ($(wildcard $(BUILD_WORK)/libdvbpsi/.build_complete),)
libdvbpsi:
	@echo "Using previously built libdvbpsi."
else
libdvbpsi: libdvbpsi-setup
	cd $(BUILD_WORK)/libdvbpsi && ./configure -C \
		$(DEFAULT_CONFIGURE_FLAGS)
	+$(MAKE) -C $(BUILD_WORK)/libdvbpsi
	+$(MAKE) -C $(BUILD_WORK)/libdvbpsi install \
		DESTDIR=$(BUILD_STAGE)/libdvbpsi
ifneq ($(filter -flto%,$(CFLAGS)),)
	# Keep installed LTO outputs and the complete configured compiler flags.
	+$(MAKE) -C $(BUILD_WORK)/libdvbpsi/src clean
	+$(MAKE) -C $(BUILD_WORK)/libdvbpsi/src libdvbpsi.la \
		CFLAGS="$$(sed -n 's/^CFLAGS = //p' $(BUILD_WORK)/libdvbpsi/src/Makefile | sed -E 's/(^|[[:space:]])-flto(=[^[:space:]]*)?//g') -fno-lto" \
		LDFLAGS="$$(sed -n 's/^LDFLAGS = //p' $(BUILD_WORK)/libdvbpsi/src/Makefile | sed -E 's/(^|[[:space:]])-flto(=[^[:space:]]*)?//g') -static"
	cp -a $(BUILD_WORK)/libdvbpsi/src/.libs/libdvbpsi.a \
		$(BUILD_STAGE)/libdvbpsi/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/
endif
	$(call AFTER_BUILD,copy)
endif

libdvbpsi-package: libdvbpsi-stage
	# libdvbpsi.mk Package Structure
	rm -rf $(BUILD_DIST)/libdvbpsi{10,-dev}
	mkdir -p $(BUILD_DIST)/libdvbpsi{10,-dev}/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	
	# libdvbpsi.mk Prep libdvbpsi10
	cp -a $(BUILD_STAGE)/libdvbpsi/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libdvbpsi.10.dylib $(BUILD_DIST)/libdvbpsi10/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	
	# libdvbpsi.mk Prep libdvbpsi-dev
	cp -a $(BUILD_STAGE)/libdvbpsi/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include $(BUILD_DIST)/libdvbpsi-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)
	cp -a $(BUILD_STAGE)/libdvbpsi/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/{pkgconfig,libdvbpsi.{dylib,a}} $(BUILD_DIST)/libdvbpsi-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	
	# libdvbpsi.mk Sign
	$(call SIGN,libdvbpsi10,general.xml)
	
	# libdvbpsi.mk Make .debs
	$(call PACK,libdvbpsi10,DEB_LIBDVBPSI_V)
	$(call PACK,libdvbpsi-dev,DEB_LIBDVBPSI_V)
	
	# libdvbpsi.mk Build cleanup
	rm -rf $(BUILD_DIST)/libdvbpsi{10,-dev}

.PHONY: libdvbpsi libdvbpsi-package
