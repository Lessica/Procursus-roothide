ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS       += tesseract
TESSERACT_VERSION := 5.1.0
DEB_TESSERACT_V   ?= $(TESSERACT_VERSION)-3

###
# TODO:
# tesseract-lang package with the rest of the languages.
###

### Needs asciidoc

tesseract-setup: setup
	$(call GITHUB_ARCHIVE,tesseract-ocr,tesseract,$(TESSERACT_VERSION),$(TESSERACT_VERSION))
	$(call EXTRACT_TAR,tesseract-$(TESSERACT_VERSION).tar.gz,tesseract-$(TESSERACT_VERSION),tesseract)

ifneq ($(wildcard $(BUILD_WORK)/tesseract/.build_complete),)
tesseract:
	@echo "Using previously built tesseract."
else
tesseract: tesseract-setup leptonica libarchive curl openmp
	cd $(BUILD_WORK)/tesseract && ./autogen.sh
	rm -f $(BUILD_WORK)/tesseract/VERSION # This, amazingly enough, makes compiling on macOS not work. (Non-case-sensitive)
	cd $(BUILD_WORK)/tesseract && PKG_CONFIG_PATH="$(BUILD_BASE)$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/pkgconfig:$(BUILD_BASE)$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)$(MEMO_ALT_PREFIX)/lib/pkgconfig:$(BUILD_BASE)$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/pkgconfig" ./configure -C \
		$(DEFAULT_CONFIGURE_FLAGS) \
		--datarootdir=$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/tesseract-ocr/5/ \
		--disable-doc # The docs do not work, so we'll disable them for now
	+$(MAKE) -C $(BUILD_WORK)/tesseract
	+$(MAKE) -C $(BUILD_WORK)/tesseract install \
		DESTDIR="$(BUILD_STAGE)/tesseract"
	sed -i -e 's|$(BUILD_BASE)$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)|$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)|g' \
		-e 's|^datarootdir = |datarootdir=|' \
		$(BUILD_STAGE)/tesseract/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/pkgconfig/tesseract.pc
ifneq ($(filter iphoneos% appletvos%,$(MEMO_TARGET)),)
	# Static consumers of the public C API also require the Apple C++ runtime.
	sed -i '/^Libs.private:/s/$$/ -lc++/' $(BUILD_STAGE)/tesseract/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/pkgconfig/tesseract.pc
endif
ifneq ($(filter -flto%,$(CFLAGS)),)
	# Keep installed LTO runtime; rebuild the public library and folded helpers.
	+$(MAKE) -C $(BUILD_WORK)/tesseract clean
	+$(MAKE) -C $(BUILD_WORK)/tesseract libtesseract.la \
		CFLAGS="$$(sed -n 's/^CFLAGS = //p' $(BUILD_WORK)/tesseract/Makefile | sed -E 's/(^|[[:space:]])-flto(=[^[:space:]]*)?//g') -fno-lto" \
		CXXFLAGS="$$(sed -n 's/^CXXFLAGS = //p' $(BUILD_WORK)/tesseract/Makefile | sed -E 's/(^|[[:space:]])-flto(=[^[:space:]]*)?//g') -fno-lto" \
		LDFLAGS="$$(sed -n 's/^LDFLAGS = //p' $(BUILD_WORK)/tesseract/Makefile | sed -E 's/(^|[[:space:]])-flto(=[^[:space:]]*)?//g') -static"
	cp -a $(BUILD_WORK)/tesseract/.libs/libtesseract.a $(BUILD_STAGE)/tesseract/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/
endif
	$(call AFTER_BUILD,copy)
endif

tesseract-package: tesseract-stage
	# tesseract.mk Package Structure
	rm -rf $(BUILD_DIST)/libtesseract5 $(BUILD_DIST)/libtesseract-dev $(BUILD_DIST)/tesseract-ocr
	mkdir -p \
		$(BUILD_DIST)/libtesseract-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib \
		$(BUILD_DIST)/tesseract-ocr/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX) \
		$(BUILD_DIST)/libtesseract5/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/{lib,share/tesseract-ocr/5/}

	# tesseract.mk Prep libtesseract-dev
	cp -a $(BUILD_STAGE)/tesseract/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include $(BUILD_DIST)/libtesseract-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)
	cp -a $(BUILD_STAGE)/tesseract/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/!(libtesseract.5.dylib) $(BUILD_DIST)/libtesseract-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# tesseract.mk Prep tesseract-ocr
	cp -a $(BUILD_STAGE)/tesseract/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin $(BUILD_DIST)/tesseract-ocr/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)
	#cp -a $(BUILD_STAGE)/tesseract/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man $(BUILD_DIST)/tesseract-ocr/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share

	# tesseract.mk Prep libtesseract5
	cp -a $(BUILD_STAGE)/tesseract/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libtesseract.5.dylib $(BUILD_DIST)/libtesseract5/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/tesseract/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/tesseract-ocr/5/tessdata $(BUILD_DIST)/libtesseract5/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/tesseract-ocr/5/
	# Just bundle eng and osd with the library.
	$(call DOWNLOAD_FILES,$(BUILD_DIST)/libtesseract5/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/tesseract-ocr/5/tessdata, \
		https://github.com/tesseract-ocr/tessdata_fast/raw/4.0.0/eng.traineddata \
		https://github.com/tesseract-ocr/tessdata_fast/raw/4.0.0/osd.traineddata)

	chmod 0644 $(BUILD_DIST)/libtesseract5/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/tesseract-ocr/5/tessdata/{eng,osd}.traineddata

	# tesseract.mk Sign
	$(call SIGN,libtesseract5,general.xml)
	$(call SIGN,tesseract-ocr,general.xml)

	# tesseract.mk Make .debs
	$(call PACK,libtesseract-dev,DEB_TESSERACT_V)
	$(call PACK,tesseract-ocr,DEB_TESSERACT_V)
	$(call PACK,libtesseract5,DEB_TESSERACT_V)

	# tesseract.mk Build cleanup
	rm -rf $(BUILD_DIST)/libtesseract5 $(BUILD_DIST)/libtesseract-dev $(BUILD_DIST)/tesseract-ocr

.PHONY: tesseract tesseract-package
