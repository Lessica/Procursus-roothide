ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS     += libhsts
LIBHSTS_VERSION := 0.1.0
DEB_LIBHSTS_V   ?= $(LIBHSTS_VERSION)

libhsts-setup: setup
	$(call DOWNLOAD_FILES,$(BUILD_SOURCE),https://gitlab.com/rockdaboot/libhsts/-/archive/libhsts-$(LIBHSTS_VERSION)/libhsts-libhsts-$(LIBHSTS_VERSION).tar.gz)
	$(call EXTRACT_TAR,libhsts-libhsts-$(LIBHSTS_VERSION).tar.gz,libhsts-libhsts-$(LIBHSTS_VERSION),libhsts)
	$(call DO_PATCH,libhsts,libhsts,-p1)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/libhsts-hsts-2c1118f2.json,https://raw.githubusercontent.com/chromium/chromium/2c1118f2b055a94ad6a14abcc0e8ebb42c9ef202/net/http/transport_security_state_static.json)
	$(call CHECKSUM_VERIFY,sha256,libhsts-hsts-2c1118f2.json,7405979fe3080d733da2e3c86fe6cb42a000bd6fa9ca0f9661721bff50fddd62)
	sed 's/^[[:space:]]*\/\/.*$$//g' $(BUILD_SOURCE)/libhsts-hsts-2c1118f2.json > $(BUILD_WORK)/libhsts/tests/hsts.json

ifneq ($(wildcard $(BUILD_WORK)/libhsts/.build_complete),)
libhsts:
	@echo "Using previously built libhsts."
else
libhsts: libhsts-setup
	cd $(BUILD_WORK)/libhsts && autoreconf -fi
	cd $(BUILD_WORK)/libhsts && ./configure -C \
		$(DEFAULT_CONFIGURE_FLAGS) \
		--with-hsts-distfile="$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/hstspreload/hsts.dafsa" \
		--disable-doc # Enable after adding graphviz.
	+$(MAKE) -C $(BUILD_WORK)/libhsts
	+$(MAKE) -C $(BUILD_WORK)/libhsts install \
		DESTDIR="$(BUILD_STAGE)/libhsts"
	$(call AFTER_BUILD,copy)
endif

libhsts-package: libhsts-stage
	# libhsts.mk Package Structure
	rm -rf $(BUILD_DIST)/libhsts{0,-dev}
	mkdir -p $(BUILD_DIST)/libhsts{0,-dev}/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libhsts.mk Prep libhsts
	cp -a $(BUILD_STAGE)/libhsts/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libhsts.0.dylib $(BUILD_DIST)/libhsts0/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libhsts.mk Prep libhsts-dev
	cp -a $(BUILD_STAGE)/libhsts/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/{bin,include} $(BUILD_DIST)/libhsts-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)
	cp -a $(BUILD_STAGE)/libhsts/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/{libhsts.{a,dylib},pkgconfig} $(BUILD_DIST)/libhsts-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libhsts.mk Sign
	$(call SIGN,libhsts0,general.xml)
	$(call SIGN,libhsts-dev,general.xml)

	# libhsts.mk Make .debs
	$(call PACK,libhsts0,DEB_LIBHSTS_V)
	$(call PACK,libhsts-dev,DEB_LIBHSTS_V)

	# libhsts.mk Build cleanup
	rm -rf $(BUILD_DIST)/libhsts{0,-dev}

.PHONY: libhsts libhsts-package
