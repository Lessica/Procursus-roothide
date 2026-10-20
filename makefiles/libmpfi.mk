ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS   += libmpfi
LIBMPFI_VERSION := 1.5.3
DEB_LIBMPFI_V   ?= $(LIBMPFI_VERSION)-1

ifneq ($(wildcard $(BUILD_WORK)/libmpfi/.CRLFtoLF_done),)
libmpfi-setup: setup
	@echo "libmpfi already converted to LF. "
else
libmpfi-setup: setup
	$(call GIT_CLONE,https://gitlab.inria.fr/mpfi/mpfi.git,1.5.3,libmpfi)
	find $(BUILD_WORK)/libmpfi \( ! -regex '.*/\..*' \) -type f -exec dos2unix -f {} \;
	touch $(BUILD_WORK)/libmpfi/.CRLFtoLF_done
endif

ifneq ($(wildcard $(BUILD_WORK)/libmpfi/.build_complete),)
libmpfi:
	@echo "Using previously built libmpfi."
else
libmpfi: libmpfi-setup libgmp10 mpfr4
	cd $(BUILD_WORK)/libmpfi/mpfi && ./autogen.sh && ./configure -C \
		$(DEFAULT_CONFIGURE_FLAGS)
	+$(MAKE) -C $(BUILD_WORK)/libmpfi/mpfi
	+$(MAKE) -C $(BUILD_WORK)/libmpfi/mpfi install \
		DESTDIR=$(BUILD_STAGE)/libmpfi
ifneq ($(filter -flto%,$(CFLAGS)),)
	# Preserve original LTO installation and rebuild only the static library objects.
	rm -f $(BUILD_WORK)/libmpfi/mpfi/src/*.lo $(BUILD_WORK)/libmpfi/mpfi/src/libmpfi.la
	+$(MAKE) -C $(BUILD_WORK)/libmpfi/mpfi/src libmpfi.la \
		CFLAGS="$$(sed -n 's/^CFLAGS = //p' $(BUILD_WORK)/libmpfi/mpfi/src/Makefile) -fno-lto" \
		LDFLAGS="$$(sed -n 's/^LDFLAGS = //p' $(BUILD_WORK)/libmpfi/mpfi/src/Makefile) -fno-lto -static"
	cp -a $(BUILD_WORK)/libmpfi/mpfi/src/.libs/libmpfi.a \
		$(BUILD_STAGE)/libmpfi/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/
endif
	$(call AFTER_BUILD,copy)
endif

libmpfi-package: libmpfi-stage
	# libmpfi.mk Package Structure
	rm -rf $(BUILD_DIST)/libmpfi-dev

	# libmpfi.mk Prep libmpfi-dev
	cp -a $(BUILD_STAGE)/libmpfi $(BUILD_DIST)
	mv $(BUILD_DIST)/libmpfi $(BUILD_DIST)/libmpfi-dev

	# libmpfi.mk Sign
	$(call SIGN,libmpfi-dev,general.xml)

	# libmpfi.mk Make .debs
	$(call PACK,libmpfi-dev,DEB_LIBMPFI_V)

	# libmpfi.mk Build cleanup
	rm -rf $(BUILD_DIST)/libmpfi-dev

.PHONY: libmpfi libmpfi-package
