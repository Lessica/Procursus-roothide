ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

STRAPPROJECTS    += libtasn1
LIBTASN1_VERSION := 4.19.0
DEB_LIBTASN1_V   ?= $(LIBTASN1_VERSION)-1

libtasn1-setup: setup
	$(call DOWNLOAD_FILES,$(BUILD_SOURCE),https://ftpmirror.gnu.org/libtasn1/libtasn1-$(LIBTASN1_VERSION).tar.gz{$(comma).sig})
	$(call PGP_VERIFY,libtasn1-$(LIBTASN1_VERSION).tar.gz)
	$(call EXTRACT_TAR,libtasn1-$(LIBTASN1_VERSION).tar.gz,libtasn1-$(LIBTASN1_VERSION),libtasn1)

ifneq ($(wildcard $(BUILD_WORK)/libtasn1/.build_complete),)
libtasn1:
	@echo "Using previously built libtasn1."
else
libtasn1: libtasn1-setup
	cd $(BUILD_WORK)/libtasn1 && ./configure -C \
		$(DEFAULT_CONFIGURE_FLAGS)
	+$(MAKE) -C $(BUILD_WORK)/libtasn1
	+$(MAKE) -C $(BUILD_WORK)/libtasn1 install \
		DESTDIR=$(BUILD_STAGE)/libtasn1
ifneq ($(filter -flto%,$(CFLAGS)),)
	# Keep installed LTO programs/dylib; rebuild the public archive and
	# its embedded gnulib objects as native machine code in the same tree.
	+$(MAKE) -C $(BUILD_WORK)/libtasn1/lib clean
	+$(MAKE) -C $(BUILD_WORK)/libtasn1/lib/gl libgnu.la \
		CFLAGS="$(filter-out -flto%,$(CFLAGS)) -fno-lto" \
		LDFLAGS="$(filter-out -flto%,$(LDFLAGS)) -static"
	+$(MAKE) -C $(BUILD_WORK)/libtasn1/lib libtasn1.la \
		CFLAGS="$(filter-out -flto%,$(CFLAGS)) -fno-lto" \
		LDFLAGS="$(filter-out -flto%,$(LDFLAGS)) -static"
	cp -a $(BUILD_WORK)/libtasn1/lib/.libs/libtasn1.a \
		$(BUILD_STAGE)/libtasn1/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/
endif
	$(call AFTER_BUILD,copy)
endif

libtasn1-package: libtasn1-stage
	# libtasn1.mk Package Structure
	rm -rf $(BUILD_DIST)/libtasn1-{6{,-dev},bin}
	mkdir -p $(BUILD_DIST)/libtasn1-6/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib \
		$(BUILD_DIST)/libtasn1-6-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/{lib,share/man} \
		$(BUILD_DIST)/libtasn1-bin/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man

	# libtasn1.mk Prep libtasn1-6
	cp -a $(BUILD_STAGE)/libtasn1/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libtasn1.6.dylib $(BUILD_DIST)/libtasn1-6/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libtasn1.mk Prep libtasn1-dev
	cp -a $(BUILD_STAGE)/libtasn1/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/!(libtasn1.6.dylib) $(BUILD_DIST)/libtasn1-6-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libtasn1/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/man3 $(BUILD_DIST)/libtasn1-6-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man
	cp -a $(BUILD_STAGE)/libtasn1/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include $(BUILD_DIST)/libtasn1-6-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)

	# libtasn1.mk Prep libtasn1-bin
	cp -a $(BUILD_STAGE)/libtasn1/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/man1 $(BUILD_DIST)/libtasn1-bin/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man
	cp -a $(BUILD_STAGE)/libtasn1/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin $(BUILD_DIST)/libtasn1-bin/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)

	# libtasn1.mk Sign
	$(call SIGN,libtasn1-6,general.xml)
	$(call SIGN,libtasn1-bin,general.xml)

	# libtasn1.mk Make .debs
	$(call PACK,libtasn1-6,DEB_LIBTASN1_V)
	$(call PACK,libtasn1-bin,DEB_LIBTASN1_V)
	$(call PACK,libtasn1-6-dev,DEB_LIBTASN1_V)

	# libtasn1.mk Build cleanup
	rm -rf $(BUILD_DIST)/libtasn1-{6{,-dev},bin}

.PHONY: libtasn1 libtasn1-package
