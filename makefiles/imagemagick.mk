ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS         += imagemagick
IMAGEMAGICK_VERSION := 7.0.10-60
DEB_IMAGEMAGICK_V   ?= $(shell echo $(IMAGEMAGICK_VERSION) | sed s/-/./)-2

###
#
# Packaging should be re-looked at next update, specifically the versioning specific parts. (7, 7.0.10)
#
###

imagemagick-setup: setup
	$(call DOWNLOAD_FILES,$(BUILD_SOURCE),https://mirror.accum.se/mirror/imagemagick.org/ftp/releases/ImageMagick-$(IMAGEMAGICK_VERSION).tar.xz)
	$(call EXTRACT_TAR,ImageMagick-$(IMAGEMAGICK_VERSION).tar.xz,ImageMagick-$(IMAGEMAGICK_VERSION),imagemagick)

ifneq ($(wildcard $(BUILD_WORK)/imagemagick/.build_complete),)
imagemagick:
	@echo "Using previously built imagemagick."
else
imagemagick: imagemagick-setup openexr fontconfig freetype glib2.0 ghostscript libheif gettext jbigkit libjemalloc lcms2 liblqr xz openmp openjpeg libpng16 libtiff libwebp libzip libtool libxt libxext
	cd $(BUILD_WORK)/imagemagick && ./configure -C \
		$(DEFAULT_CONFIGURE_FLAGS) \
		CXX="$(CXX) $(CXXFLAGS)" \
		--enable-osx-universal-binary=no \
		--disable-dependency-tracking \
		--disable-silent-rules \
		--enable-shared \
		--enable-static \
		--with-jemalloc \
		--disable-opencl \
		--with-modules \
		--with-x=yes \
		--with-freetype=yes \
		--with-openjp2 \
		--with-openexr \
		--with-webp=yes \
		--with-heic=yes \
		--with-gslib \
		--with-gs-font-dir=$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/ghostscript/fonts \
		--with-lqr \
		--without-fftw \
		--without-pango \
		--without-wmf \
		--enable-openmp \
		ac_cv_prog_c_openmp=-Xpreprocessor\ -fopenmp \
		ac_cv_prog_cxx_openmp=-Xpreprocessor\ -fopenmp \
		LDFLAGS="-L$(BUILD_BASE)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)$(MEMO_ALT_PREFIX)/lib $(LDFLAGS) -lomp -lz"
	sed -i 's/|-fopenmp//' $(BUILD_WORK)/imagemagick/libtool
	+$(MAKE) -C $(BUILD_WORK)/imagemagick
	+$(MAKE) -C $(BUILD_WORK)/imagemagick install \
		DESTDIR=$(BUILD_STAGE)/imagemagick
ifneq ($(filter -flto%,$(CFLAGS) $(CXXFLAGS)),)
	# Preserve installed LTO tools/coders; replace the three development archives.
	find $(BUILD_WORK)/imagemagick/{MagickCore,MagickWand,Magick++/lib} -name '*.lo' -type f -delete
	rm -f $(BUILD_WORK)/imagemagick/{MagickCore/libMagickCore,MagickWand/libMagickWand,Magick++/lib/libMagick++}-7.Q16HDRI.la
	+$(MAKE) -C $(BUILD_WORK)/imagemagick \
		MagickCore/libMagickCore-7.Q16HDRI.la MagickWand/libMagickWand-7.Q16HDRI.la Magick++/lib/libMagick++-7.Q16HDRI.la \
		CFLAGS="$$(sed -n 's/^CFLAGS = //p' $(BUILD_WORK)/imagemagick/Makefile) -fno-lto" \
		CXXFLAGS="$$(sed -n 's/^CXXFLAGS = //p' $(BUILD_WORK)/imagemagick/Makefile) -fno-lto" \
		LDFLAGS="$$(sed -n 's/^LDFLAGS = //p' $(BUILD_WORK)/imagemagick/Makefile) -fno-lto -static"
	cp -a $(BUILD_WORK)/imagemagick/{MagickCore/.libs/libMagickCore,MagickWand/.libs/libMagickWand,Magick++/lib/.libs/libMagick++}-7.Q16HDRI.a $(BUILD_STAGE)/imagemagick/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/
endif
	$(call AFTER_BUILD,copy)
endif

imagemagick-package: imagemagick-stage
	# imagemagick.mk Package Structure
	rm -rf $(BUILD_DIST)/*magick*7*/ $(BUILD_DIST)/imagemagick
	mkdir -p $(BUILD_DIST)/imagemagick/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/{bin,share/man/man1} \
		$(BUILD_DIST)/imagemagick-7-common/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share \
		$(BUILD_DIST)/libmagick++-7.q16hdri-4/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib \
		$(BUILD_DIST)/libmagick++-7.q16hdri-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/{pkgconfig,ImageMagick-7.0.10/bin} \
		$(BUILD_DIST)/libmagick++-7-headers/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include/ImageMagick-7 \
		$(BUILD_DIST)/libmagickcore-7.q16hdri-8/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib \
		$(BUILD_DIST)/libmagickcore-7.q16hdri-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/{pkgconfig,ImageMagick-7.0.10/bin} \
		$(BUILD_DIST)/libmagickcore-7-headers/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include/ImageMagick-7 \
		$(BUILD_DIST)/libmagickwand-7.q16hdri-8/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib \
		$(BUILD_DIST)/libmagickwand-7.q16hdri-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/{pkgconfig,ImageMagick-7.0.10/bin} \
		$(BUILD_DIST)/libmagickwand-7-headers/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include/ImageMagick-7

	# imagemagick.mk Prep imagemagick
	cp -a $(BUILD_STAGE)/imagemagick/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/!(Magick++-config|MagickCore-config|MagickWand-config) $(BUILD_DIST)/imagemagick/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin
	cp -a $(BUILD_STAGE)/imagemagick/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/man1/!(Magick++-config.1|MagickCore-config.1|MagickWand-config.1) $(BUILD_DIST)/imagemagick/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/man1

	# imagemagick.mk Prep imagemagick-7-common
	cp -a $(BUILD_STAGE)/imagemagick/etc $(BUILD_DIST)/imagemagick-7-common
	cp -a $(BUILD_STAGE)/imagemagick/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/ImageMagick-7 $(BUILD_DIST)/imagemagick-7-common/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share

	# imagemagick.mk Prep libmagick++-7.q16hdri-4
	cp -a $(BUILD_STAGE)/imagemagick/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libMagick++-7.Q16HDRI.4.dylib $(BUILD_DIST)/libmagick++-7.q16hdri-4/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# imagemagick.mk Prep libmagick++-7.q16hdri-dev
	cp -a $(BUILD_STAGE)/imagemagick/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libMagick++-7.Q16HDRI.{a,dylib} $(BUILD_DIST)/libmagick++-7.q16hdri-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/imagemagick/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/pkgconfig/Magick++-7.Q16HDRI.pc $(BUILD_DIST)/libmagick++-7.q16hdri-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/pkgconfig
	cp -a $(BUILD_STAGE)/imagemagick/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/Magick++-config $(BUILD_DIST)/libmagick++-7.q16hdri-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/ImageMagick-7.0.10/bin

	# imagemagick.mk Prep libmagick++-7-headers
	cp -a $(BUILD_STAGE)/imagemagick/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include/ImageMagick-7/Magick++* $(BUILD_DIST)/libmagick++-7-headers/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include/ImageMagick-7

	# imagemagick.mk Prep libmagickcore-7.q16hdri-8
	cp -a $(BUILD_STAGE)/imagemagick/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libMagickCore-7.Q16HDRI.8.dylib $(BUILD_DIST)/libmagickcore-7.q16hdri-8/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/imagemagick/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/ImageMagick-7.0.10 $(BUILD_DIST)/libmagickcore-7.q16hdri-8/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# imagemagick.mk Prep libmagickcore-7.q16hdri-dev
	cp -a $(BUILD_STAGE)/imagemagick/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libMagickCore-7.Q16HDRI.{a,dylib} $(BUILD_DIST)/libmagickcore-7.q16hdri-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/imagemagick/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/pkgconfig/{MagickCore,ImageMagick}-7.Q16HDRI.pc $(BUILD_DIST)/libmagickcore-7.q16hdri-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/pkgconfig
	cp -a $(BUILD_STAGE)/imagemagick/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/MagickCore-config $(BUILD_DIST)/libmagickcore-7.q16hdri-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/ImageMagick-7.0.10/bin

	# imagemagick.mk Prep libmagickcore-7-headers
	cp -a $(BUILD_STAGE)/imagemagick/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include/ImageMagick-7/MagickCore $(BUILD_DIST)/libmagickcore-7-headers/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include/ImageMagick-7

	# imagemagick.mk Prep libmagickwand-7.q16hdri-8
	cp -a $(BUILD_STAGE)/imagemagick/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libMagickWand-7.Q16HDRI.8.dylib $(BUILD_DIST)/libmagickwand-7.q16hdri-8/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# imagemagick.mk Prep libmagickwand-7.q16hdri-dev
	cp -a $(BUILD_STAGE)/imagemagick/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libMagickWand-7.Q16HDRI.{a,dylib} $(BUILD_DIST)/libmagickwand-7.q16hdri-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/imagemagick/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/pkgconfig/MagickWand-7.Q16HDRI.pc $(BUILD_DIST)/libmagickwand-7.q16hdri-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/pkgconfig
	cp -a $(BUILD_STAGE)/imagemagick/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/MagickWand-config $(BUILD_DIST)/libmagickwand-7.q16hdri-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/ImageMagick-7.0.10/bin

	# imagemagick.mk Prep libmagickwand-7-headers
	cp -a $(BUILD_STAGE)/imagemagick/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include/ImageMagick-7/MagickWand $(BUILD_DIST)/libmagickwand-7-headers/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include/ImageMagick-7

	# Remove repeated compression output from resumed stage processing and make
	# installed development metadata relocatable outside this build checkout.
	find $(BUILD_DIST)/imagemagick $(BUILD_DIST)/imagemagick-7-common $(BUILD_DIST)/libmagick++-7.q16hdri-4 $(BUILD_DIST)/libmagick++-7.q16hdri-dev $(BUILD_DIST)/libmagick++-7-headers $(BUILD_DIST)/libmagickcore-7.q16hdri-8 $(BUILD_DIST)/libmagickcore-7.q16hdri-dev $(BUILD_DIST)/libmagickcore-7-headers $(BUILD_DIST)/libmagickwand-7.q16hdri-8 $(BUILD_DIST)/libmagickwand-7.q16hdri-dev $(BUILD_DIST)/libmagickwand-7-headers -type f -name '*.zst.zst*' -delete
	find $(BUILD_DIST)/imagemagick $(BUILD_DIST)/imagemagick-7-common $(BUILD_DIST)/libmagick++-7.q16hdri-4 $(BUILD_DIST)/libmagick++-7.q16hdri-dev $(BUILD_DIST)/libmagick++-7-headers $(BUILD_DIST)/libmagickcore-7.q16hdri-8 $(BUILD_DIST)/libmagickcore-7.q16hdri-dev $(BUILD_DIST)/libmagickcore-7-headers $(BUILD_DIST)/libmagickwand-7.q16hdri-8 $(BUILD_DIST)/libmagickwand-7.q16hdri-dev $(BUILD_DIST)/libmagickwand-7-headers -type f -name '*.1' -exec sh -c 'for page do if [ -f "$$page.zst" ]; then rm -f "$$page"; fi; done' sh {} +
	find $(BUILD_DIST)/imagemagick $(BUILD_DIST)/imagemagick-7-common $(BUILD_DIST)/libmagick++-7.q16hdri-4 $(BUILD_DIST)/libmagick++-7.q16hdri-dev $(BUILD_DIST)/libmagick++-7-headers $(BUILD_DIST)/libmagickcore-7.q16hdri-8 $(BUILD_DIST)/libmagickcore-7.q16hdri-dev $(BUILD_DIST)/libmagickcore-7-headers $(BUILD_DIST)/libmagickwand-7.q16hdri-8 $(BUILD_DIST)/libmagickwand-7.q16hdri-dev $(BUILD_DIST)/libmagickwand-7-headers -type f \( -name '*.pc' -o -name '*.la' -o -name '*-config' \) -exec sed -i \
		-e 's|$(BUILD_BASE)||g' \
		-e 's|$(BUILD_TOOLS)/cross-pkg-config|pkg-config|g' {} +

	# imagemagick.mk Sign
	$(call SIGN,imagemagick,general.xml)
	$(call SIGN,libmagick++-7.q16hdri-4,general.xml)
	$(call SIGN,libmagickcore-7.q16hdri-8,general.xml)
	$(call SIGN,libmagickwand-7.q16hdri-8,general.xml)

	# imagemagick.mk Make .debs
	$(call PACK,imagemagick,DEB_IMAGEMAGICK_V)
	$(call PACK,imagemagick-7-common,DEB_IMAGEMAGICK_V)
	$(call PACK,libmagick++-7.q16hdri-4,DEB_IMAGEMAGICK_V)
	$(call PACK,libmagick++-7.q16hdri-dev,DEB_IMAGEMAGICK_V)
	$(call PACK,libmagick++-7-headers,DEB_IMAGEMAGICK_V)
	$(call PACK,libmagickcore-7.q16hdri-8,DEB_IMAGEMAGICK_V,,SettingFourthVar)
	$(call PACK,libmagickcore-7.q16hdri-dev,DEB_IMAGEMAGICK_V)
	$(call PACK,libmagickcore-7-headers,DEB_IMAGEMAGICK_V)
	$(call PACK,libmagickwand-7.q16hdri-8,DEB_IMAGEMAGICK_V)
	$(call PACK,libmagickwand-7.q16hdri-dev,DEB_IMAGEMAGICK_V)
	$(call PACK,libmagickwand-7-headers,DEB_IMAGEMAGICK_V)

	# imagemagick.mk Build cleanup
	rm -rf $(BUILD_DIST)/*magick*7*/ $(BUILD_DIST)/imagemagick

.PHONY: imagemagick imagemagick-package
