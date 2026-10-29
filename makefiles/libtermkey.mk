ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS        += libtermkey
LIBTERMKEY_VERSION := 0.22
DEB_LIBTERMKEY_V   ?= $(LIBTERMKEY_VERSION)-1

libtermkey-setup: setup
	$(call DOWNLOAD_FILES,$(BUILD_SOURCE),http://www.leonerd.org.uk/code/libtermkey/libtermkey-$(LIBTERMKEY_VERSION).tar.gz)
	$(call EXTRACT_TAR,libtermkey-$(LIBTERMKEY_VERSION).tar.gz,libtermkey-$(LIBTERMKEY_VERSION),libtermkey)
	$(call DO_PATCH,libtermkey,libtermkey)
	mkdir -p $(BUILD_WORK)/libtermkey/libtool
	echo -e "AC_INIT([dummy],[1.0])\n\
LT_INIT\n\
AC_PROG_LIBTOOL\n\
AC_OUTPUT" > $(BUILD_WORK)/libtermkey/libtool/configure.ac

ifneq ($(wildcard $(BUILD_WORK)/libtermkey/.build_complete),)
libtermkey:
	@echo "Using previously built libtermkey."
else
libtermkey: libtermkey-setup unibilium
	cd $(BUILD_WORK)/libtermkey/libtool && LIBTOOLIZE="$(LIBTOOLIZE) -i" autoreconf -fi
	cd $(BUILD_WORK)/libtermkey/libtool && ./configure -C \
		$(DEFAULT_CONFIGURE_FLAGS)
	+$(MAKE) -C $(BUILD_WORK)/libtermkey \
		PREFIX=$(MEMO_PREFIX)$(MEMO_SUB_PREFIX) \
		PKG_CONFIG="$(BUILD_TOOLS)/cross-pkg-config" \
		LIBTOOL="$(BUILD_WORK)/libtermkey/libtool/libtool" \
		CC="$(CC) $(CFLAGS)" \
		DEMOS=""
	+$(MAKE) -C $(BUILD_WORK)/libtermkey install PREFIX=$(MEMO_PREFIX)$(MEMO_SUB_PREFIX) \
		LIBTOOL="$(BUILD_WORK)/libtermkey/libtool/libtool" \
		DESTDIR="$(BUILD_STAGE)/libtermkey"
ifneq ($(filter -flto%,$(CFLAGS)),)
	# Keep the installed shared library from the LTO build; rebuild only
	# the archive target with native objects for downstream linkers.
	+$(MAKE) -C $(BUILD_WORK)/libtermkey clean
	+$(MAKE) -C $(BUILD_WORK)/libtermkey libtermkey.la \
		PREFIX=$(MEMO_PREFIX)$(MEMO_SUB_PREFIX) \
		PKG_CONFIG="$(BUILD_TOOLS)/cross-pkg-config" \
		LIBTOOL="$(BUILD_WORK)/libtermkey/libtool/libtool" \
		CC="$(CC)" \
		DEMOS="" \
		CFLAGS="$(filter-out -flto%,$(CFLAGS)) -fno-lto" \
		LDFLAGS="$(filter-out -flto%,$(LDFLAGS)) -static"
	cp -a $(BUILD_WORK)/libtermkey/.libs/libtermkey.a \
		$(BUILD_STAGE)/libtermkey/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/
endif
	$(call AFTER_BUILD,copy)
endif

libtermkey-package: libtermkey-stage
	# libtermkey.mk Package Structure
	rm -rf $(BUILD_DIST)/libtermkey{-dev,1}
	mkdir -p $(BUILD_DIST)/libtermkey{1,-dev}/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libtermkey.mk Prep libtermkey-dev
	cp -a $(BUILD_STAGE)/libtermkey/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/{include,share} $(BUILD_DIST)/libtermkey-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)
	cp -a $(BUILD_STAGE)/libtermkey/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/{pkgconfig,libtermkey.{a,dylib}} $(BUILD_DIST)/libtermkey-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libtermkey.mk Prep libtermkey1
	cp -a $(BUILD_STAGE)/libtermkey/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libtermkey.1.dylib $(BUILD_DIST)/libtermkey1/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libtermkey.mk Sign
	$(call SIGN,libtermkey1,general.xml)

	# libtermkey.mk Make .debs
	$(call PACK,libtermkey-dev,DEB_LIBTERMKEY_V)
	$(call PACK,libtermkey1,DEB_LIBTERMKEY_V)

	# libtermkey.mk Build cleanup
	rm -rf $(BUILD_DIST)/libtermkey{-dev,1}

.PHONY: libtermkey libtermkey-package
