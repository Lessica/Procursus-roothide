ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS     += libwebp
LIBWEBP_VERSION := 1.2.2
DEB_LIBWEBP_V   ?= $(LIBWEBP_VERSION)-1

libwebp-setup: setup
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/libwebp-$(LIBWEBP_VERSION).tar.gz, \
		https://chromium.googlesource.com/webm/libwebp/+archive/refs/heads/$(LIBWEBP_VERSION).tar.gz)
	# Fuck this lib.
	mkdir -p $(BUILD_WORK)/libwebp
	tar xf $(BUILD_SOURCE)/libwebp-$(LIBWEBP_VERSION).tar.gz -C $(BUILD_WORK)/libwebp

ifneq ($(wildcard $(BUILD_WORK)/libwebp/.build_complete),)
libwebp:
	@echo "Using previously built libwebp."
else
libwebp: libwebp-setup libpng16 libgif libtiff libjpeg-turbo
	cd $(BUILD_WORK)/libwebp && ./autogen.sh && ./configure \
		$(DEFAULT_CONFIGURE_FLAGS) \
		--disable-{sdl,gl} \
		--enable-libwebp{mux,demux,decoder,extras}
	+$(MAKE) -C $(BUILD_WORK)/libwebp
	+$(MAKE) -C $(BUILD_WORK)/libwebp install \
		DESTDIR="$(BUILD_STAGE)/libwebp"
ifneq ($(filter -flto%,$(CFLAGS)),)
	# Recursively rebuild all folded dec/enc/dsp/utils convenience objects.
	# Runtime/tools/extras were installed with their original LTO settings.
	+$(MAKE) -C $(BUILD_WORK)/libwebp/src clean
	+$(MAKE) -C $(BUILD_WORK)/libwebp/src all \
		CFLAGS="$$(sed -n 's/^CFLAGS = //p' $(BUILD_WORK)/libwebp/src/Makefile | sed -E 's/(^|[[:space:]])-flto(=[^[:space:]]*)?//g') -fno-lto" \
		LDFLAGS="$$(sed -n 's/^LDFLAGS = //p' $(BUILD_WORK)/libwebp/src/Makefile | sed -E 's/(^|[[:space:]])-flto(=[^[:space:]]*)?//g') -static"
	cp -a $(BUILD_WORK)/libwebp/src/.libs/libwebp{,decoder}.a \
		$(BUILD_WORK)/libwebp/src/{mux,demux}/.libs/*.a $(BUILD_STAGE)/libwebp/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/
endif
	$(call AFTER_BUILD,copy)
endif

libwebp-package: libwebp-stage
	# libwebp.mk Package Structure
	rm -rf \
		$(BUILD_DIST)/libwebp{7,-dev} \
		$(BUILD_DIST)/libwebp{decoder3,demux2,mux3} \
		$(BUILD_DIST)/webp
	mkdir -p \
		$(BUILD_DIST)/libwebp-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/{include,lib/pkgconfig} \
		$(BUILD_DIST)/libwebp{7,decoder3,demux2,mux3}/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib \
		$(BUILD_DIST)/webp/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin

	# libwebp.mk Prep libwebp-dev
	cp -a $(BUILD_STAGE)/libwebp/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include $(BUILD_DIST)/libwebp-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)
	cp -a $(BUILD_STAGE)/libwebp/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/*.a $(BUILD_DIST)/libwebp-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libwebp/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libwebp{,decoder,demux,mux}.dylib $(BUILD_DIST)/libwebp-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libwebp/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/pkgconfig $(BUILD_DIST)/libwebp-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libwebp.mk Prep libwebp7
	cp -a $(BUILD_STAGE)/libwebp/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libwebp.7*.dylib $(BUILD_DIST)/libwebp7/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libwebp.mk Prep libwebpdecoder3
	cp -a $(BUILD_STAGE)/libwebp/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libwebpdecoder.3*.dylib $(BUILD_DIST)/libwebpdecoder3/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libwebp.mk Prep libwebpdemux2
	cp -a $(BUILD_STAGE)/libwebp/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libwebpdemux.2*.dylib $(BUILD_DIST)/libwebpdemux2/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libwebp.mk Prep libwebpmux3
	cp -a $(BUILD_STAGE)/libwebp/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libwebpmux.3*.dylib $(BUILD_DIST)/libwebpmux3/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libwebp.mk Prep webp
	cp -a $(BUILD_STAGE)/libwebp/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin $(BUILD_DIST)/webp/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)

	# libwebp.mk Sign
	$(call SIGN,libwebp-dev,general.xml)
	$(call SIGN,libwebp7,general.xml)
	$(call SIGN,libwebpdecoder3,general.xml)
	$(call SIGN,libwebpdemux2,general.xml)
	$(call SIGN,libwebpmux3,general.xml)
	$(call SIGN,webp,general.xml)

	# libwebp.mk Make .debs
	$(call PACK,libwebp-dev,DEB_LIBWEBP_V)
	$(call PACK,libwebp7,DEB_LIBWEBP_V)
	$(call PACK,libwebpdecoder3,DEB_LIBWEBP_V)
	$(call PACK,libwebpdemux2,DEB_LIBWEBP_V)
	$(call PACK,libwebpmux3,DEB_LIBWEBP_V)
	$(call PACK,webp,DEB_LIBWEBP_V)

	# libwebp.mk Build cleanup
	rm -rf $(BUILD_DIST)/libwebp{7,-dev,decoder3,demux2,mux3} $(BUILD_DIST)/webp

.PHONY: libwebp libwebp-package
