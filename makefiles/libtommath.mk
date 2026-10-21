ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS        += libtommath
LIBTOMMATH_VERSION := 1.2.0
DEB_LIBTOMMATH_V   ?= $(LIBTOMMATH_VERSION)-2

libtommath-setup: setup
	$(call DOWNLOAD_FILES,$(BUILD_SOURCE),https://github.com/libtom/libtommath/releases/download/v$(LIBTOMMATH_VERSION)/ltm-$(LIBTOMMATH_VERSION).tar.xz)
	$(call EXTRACT_TAR,ltm-$(LIBTOMMATH_VERSION).tar.xz,libtommath-$(LIBTOMMATH_VERSION),libtommath)
	mkdir -p $(BUILD_WORK)/libtommath/libtool
	echo -e "AC_INIT([dummy],[1.0])\n\
LT_INIT\n\
AC_PROG_LIBTOOL\n\
AC_OUTPUT" > $(BUILD_WORK)/libtommath/libtool/configure.ac

ifneq ($(wildcard $(BUILD_WORK)/libtommath/.build_complete),)
libtommath:
	@echo "Using previously built libtommath."
else
libtommath: libtommath-setup
	# libtommath.mk Make libtool executable
	cd $(BUILD_WORK)/libtommath/libtool && LIBTOOLIZE="$(LIBTOOLIZE) -i" autoreconf -fi
	cd $(BUILD_WORK)/libtommath/libtool && ./configure -C \
		$(DEFAULT_CONFIGURE_FLAGS)
	+$(MAKE) -C $(BUILD_WORK)/libtommath -f makefile.shared \
		PREFIX="$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)" \
		LIBTOOL="$(BUILD_WORK)/libtommath/libtool/libtool"
	+$(MAKE) -C $(BUILD_WORK)/libtommath -f makefile.shared install \
		LIBTOOL="$(BUILD_WORK)/libtommath/libtool/libtool" \
		PREFIX="$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)" \
		DESTDIR="$(BUILD_STAGE)/libtommath"
ifneq ($(filter -flto%,$(CFLAGS)),)
	# Keep the installed LTO dylib; rebuild only the public static target.
	+$(MAKE) -C $(BUILD_WORK)/libtommath -f makefile.shared clean
	+$(MAKE) -C $(BUILD_WORK)/libtommath -f makefile.shared libtommath.la \
		PREFIX="$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)" \
		LIBTOOL="$(BUILD_WORK)/libtommath/libtool/libtool" \
		CFLAGS="$(filter-out -flto%,$(CFLAGS)) -fno-lto" \
		LDFLAGS="$(filter-out -flto%,$(LDFLAGS)) -static"
	cp -a $(BUILD_WORK)/libtommath/.libs/libtommath.a \
		$(BUILD_STAGE)/libtommath/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/
endif
	$(call AFTER_BUILD,copy)
endif

libtommath-package: libtommath-stage
	# libtommath.mk Package Structure
	rm -rf $(BUILD_DIST)/libtommath{1,-dev}
	mkdir -p $(BUILD_DIST)/libtommath{1,-dev}/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libtommath.mk Prep libtommath
	cp -a $(BUILD_STAGE)/libtommath/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libtommath.1.dylib $(BUILD_DIST)/libtommath1/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libtommath/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include $(BUILD_DIST)/libtommath-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)
	cp -a $(BUILD_STAGE)/libtommath/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/{libtommath.{a,dylib},pkgconfig} $(BUILD_DIST)/libtommath-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libtommath.mk Sign
	$(call SIGN,libtommath1,general.xml)

	# libtommath.mk Make .debs
	$(call PACK,libtommath1,DEB_LIBTOMMATH_V)
	$(call PACK,libtommath-dev,DEB_LIBTOMMATH_V)

	# libtommath.mk Build cleanup
	rm -rf $(BUILD_DIST)/libtommath{1,-dev}

.PHONY: libtommath libtommath-package
