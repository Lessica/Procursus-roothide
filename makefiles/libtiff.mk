ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS     += libtiff
LIBTIFF_VERSION := 4.2.0
DEB_LIBTIFF_V   ?= $(LIBTIFF_VERSION)-3

libtiff-setup: setup
	$(call DOWNLOAD_FILES,$(BUILD_SOURCE), \
		https://download.osgeo.org/libtiff/tiff-$(LIBTIFF_VERSION).tar.gz)
	$(call EXTRACT_TAR,tiff-$(LIBTIFF_VERSION).tar.gz,tiff-$(LIBTIFF_VERSION),libtiff)
	sed -i 's/-keep_private_externs -nostdlib/-keep_private_externs $(PLATFORM_VERSION_MIN) -arch $(MEMO_ARCH) -nostdlib/g' $(BUILD_WORK)/libtiff/configure

ifneq ($(wildcard $(BUILD_WORK)/libtiff/.build_complete),)
libtiff:
	@echo "Using previously built libtiff."
else
libtiff: libtiff-setup libjpeg-turbo jbigkit xz zstd
	cd $(BUILD_WORK)/libtiff && ./configure -C \
		$(DEFAULT_CONFIGURE_FLAGS) \
		--disable-webp \
		--with-lzma-lib-dir=$(BUILD_BASE)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)$(MEMO_ALT_PREFIX)/lib \
		--with-lzma-include-dir=$(BUILD_BASE)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)$(MEMO_ALT_PREFIX)/include
	+$(MAKE) -C $(BUILD_WORK)/libtiff
	+$(MAKE) -C $(BUILD_WORK)/libtiff install \
		DESTDIR="$(BUILD_STAGE)/libtiff"
ifneq ($(filter -flto%,$(CFLAGS)),)
	# Include the folded portability archive in the same native static pass.
	+$(MAKE) -C $(BUILD_WORK)/libtiff/port clean
	+$(MAKE) -C $(BUILD_WORK)/libtiff/port libport.la \
		CFLAGS="$$(sed -n 's/^CFLAGS = //p' $(BUILD_WORK)/libtiff/port/Makefile | sed -E 's/(^|[[:space:]])-flto(=[^[:space:]]*)?//g') -fno-lto" \
		CXXFLAGS="$$(sed -n 's/^CXXFLAGS = //p' $(BUILD_WORK)/libtiff/port/Makefile | sed -E 's/(^|[[:space:]])-flto(=[^[:space:]]*)?//g') -fno-lto" \
		LDFLAGS="$$(sed -n 's/^LDFLAGS = //p' $(BUILD_WORK)/libtiff/port/Makefile | sed -E 's/(^|[[:space:]])-flto(=[^[:space:]]*)?//g') -static"
	+$(MAKE) -C $(BUILD_WORK)/libtiff/libtiff clean
	+$(MAKE) -C $(BUILD_WORK)/libtiff/libtiff libtiff.la libtiffxx.la \
		CFLAGS="$$(sed -n 's/^CFLAGS = //p' $(BUILD_WORK)/libtiff/libtiff/Makefile | sed -E 's/(^|[[:space:]])-flto(=[^[:space:]]*)?//g') -fno-lto" \
		CXXFLAGS="$$(sed -n 's/^CXXFLAGS = //p' $(BUILD_WORK)/libtiff/libtiff/Makefile | sed -E 's/(^|[[:space:]])-flto(=[^[:space:]]*)?//g') -fno-lto" \
		LDFLAGS="$$(sed -n 's/^LDFLAGS = //p' $(BUILD_WORK)/libtiff/libtiff/Makefile | sed -E 's/(^|[[:space:]])-flto(=[^[:space:]]*)?//g') -static"
	cp -a $(BUILD_WORK)/libtiff/libtiff/.libs/libtiff{,xx}.a $(BUILD_STAGE)/libtiff/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/
endif
	$(call AFTER_BUILD,copy)
endif

libtiff-package: libtiff-stage
	# libtiff.mk Package Structure
	rm -rf $(BUILD_DIST)/libtiff{-dev,-doc-tools,5,xx5}
	mkdir -p \
		$(BUILD_DIST)/libtiff-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/{lib,share/man} \
		$(BUILD_DIST)/libtiff-doc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share \
		$(BUILD_DIST)/libtiff-tools/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man \
		$(BUILD_DIST)/libtiff{5,xx5}/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libtiff.mk Prep libtiff-dev
	cp -a $(BUILD_STAGE)/libtiff/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include $(BUILD_DIST)/libtiff-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)
	cp -a $(BUILD_STAGE)/libtiff/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libtiff{,xx}.{a,la,dylib} $(BUILD_DIST)/libtiff-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libtiff/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/pkgconfig $(BUILD_DIST)/libtiff-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libtiff/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/man3 $(BUILD_DIST)/libtiff-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man

	# libtiff.mk Prep libtiff-doc
	cp -a $(BUILD_STAGE)/libtiff/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/doc $(BUILD_DIST)/libtiff-doc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share

	# libtiff.mk Prep libtiff-tools
	cp -a $(BUILD_STAGE)/libtiff/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin $(BUILD_DIST)/libtiff-tools/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)
	cp -a $(BUILD_STAGE)/libtiff/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/man1 $(BUILD_DIST)/libtiff-tools/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man

	# libtiff.mk Prep libtiff5
	cp -a $(BUILD_STAGE)/libtiff/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libtiff.*.dylib $(BUILD_DIST)/libtiff5/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libtiff.mk Prep libtiffxx5
	cp -a $(BUILD_STAGE)/libtiff/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libtiffxx.*.dylib $(BUILD_DIST)/libtiff5/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib


	# libtiff.mk Sign
	$(call SIGN,libtiff-dev,general.xml)
	$(call SIGN,libtiff-tools,general.xml)
	$(call SIGN,libtiff5,general.xml)
	$(call SIGN,libtiffxx5,general.xml)

	# libtiff.mk Make .debs
	$(call PACK,libtiff-dev,DEB_LIBTIFF_V)
	$(call PACK,libtiff-doc,DEB_LIBTIFF_V)
	$(call PACK,libtiff-tools,DEB_LIBTIFF_V)
	$(call PACK,libtiff5,DEB_LIBTIFF_V)
	$(call PACK,libtiffxx5,DEB_LIBTIFF_V)

	# libtiff.mk Build cleanup
	rm -rf $(BUILD_DIST)/libtiff{-dev,-doc,-tools,5,xx5}

.PHONY: libtiff libtiff-package
