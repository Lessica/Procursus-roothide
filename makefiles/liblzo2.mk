ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS     += liblzo2
LIBLZO2_VERSION := 2.10
DEB_LIBLZO2_V   ?= $(LIBLZO2_VERSION)-1

liblzo2-setup: setup
	$(call DOWNLOAD_FILES,$(BUILD_SOURCE),https://www.oberhumer.com/opensource/lzo/download/lzo-$(LIBLZO2_VERSION).tar.gz)
	$(call EXTRACT_TAR,lzo-$(LIBLZO2_VERSION).tar.gz,lzo-$(LIBLZO2_VERSION),liblzo2)

ifneq ($(wildcard $(BUILD_WORK)/liblzo2/.build_complete),)
liblzo2:
	@echo "Using previously built liblzo2."
else
liblzo2: liblzo2-setup
	cd $(BUILD_WORK)/liblzo2 && ./configure -C \
		$(DEFAULT_CONFIGURE_FLAGS) \
		--disable-dependency-tracking \
		--enable-shared
	+$(MAKE) -C $(BUILD_WORK)/liblzo2
	+$(MAKE) -C $(BUILD_WORK)/liblzo2 install \
		DESTDIR=$(BUILD_STAGE)/liblzo2
ifneq ($(filter -flto%,$(CFLAGS)),)
	# Keep installed LTO outputs and all configured LZO optimization flags.
	+$(MAKE) -C $(BUILD_WORK)/liblzo2 clean
	+$(MAKE) -C $(BUILD_WORK)/liblzo2 src/liblzo2.la \
		CFLAGS="$$(sed -n 's/^CFLAGS = //p' $(BUILD_WORK)/liblzo2/Makefile | sed -E 's/(^|[[:space:]])-flto(=[^[:space:]]*)?//g') -fno-lto" \
		LDFLAGS="$$(sed -n 's/^LDFLAGS = //p' $(BUILD_WORK)/liblzo2/Makefile | sed -E 's/(^|[[:space:]])-flto(=[^[:space:]]*)?//g') -static"
	cp -a $(BUILD_WORK)/liblzo2/src/.libs/liblzo2.a \
		$(BUILD_STAGE)/liblzo2/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/
endif
	$(call AFTER_BUILD,copy)
endif

liblzo2-package: liblzo2-stage
	# liblzo2.mk Package Structure
	rm -rf $(BUILD_DIST)/liblzo2{-2,-dev}
	mkdir -p $(BUILD_DIST)/liblzo2{-2/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib,-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/{include,lib}}

	# liblzo2.mk Prep liblzo2-2
	cp -a $(BUILD_STAGE)/liblzo2/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/liblzo2.2.dylib $(BUILD_DIST)/liblzo2-2/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# liblzo2.mk Prep liblzo2-dev
	cp -a $(BUILD_STAGE)/liblzo2/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include $(BUILD_DIST)/liblzo2-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)
	cp -a $(BUILD_STAGE)/liblzo2/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/{pkgconfig,liblzo2.{a,dylib}} $(BUILD_DIST)/liblzo2-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# liblzo2.mk Sign
	$(call SIGN,liblzo2-2,general.xml)

	# liblzo2.mk Make .debs
	$(call PACK,liblzo2-2,DEB_LIBLZO2_V)
	$(call PACK,liblzo2-dev,DEB_LIBLZO2_V)

	# liblzo2.mk Build cleanup
	rm -rf $(BUILD_DIST)/liblzo2{-2,-dev}

.PHONY: liblzo2 liblzo2-package
