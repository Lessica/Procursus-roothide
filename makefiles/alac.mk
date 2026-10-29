ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS  += alac
ALAC_VERSION := 0.0.7
DEB_ALAC_V   ?= $(ALAC_VERSION)-1

alac-setup: setup
	$(call GITHUB_ARCHIVE,mikebrady,alac,$(ALAC_VERSION),$(ALAC_VERSION))
	$(call EXTRACT_TAR,alac-$(ALAC_VERSION).tar.gz,alac-$(ALAC_VERSION),alac)

ifneq ($(wildcard $(BUILD_WORK)/alac/.build_complete),)
alac:
	@echo "Using previously built alac."
else
alac: alac-setup
	cd $(BUILD_WORK)/alac; \
	autoreconf -fi; \
	CFLAGS="$(CFLAGS) -DTARGET_OS_MAC" ./configure -C \
		$(DEFAULT_CONFIGURE_FLAGS)

	+$(MAKE) -C $(BUILD_WORK)/alac
	+$(MAKE) -C $(BUILD_WORK)/alac install \
		DESTDIR=$(BUILD_STAGE)/alac

ifneq ($(filter -flto%,$(CFLAGS) $(CXXFLAGS)),)
	# Keep the installed LTO dylib and rebuild only its static C/C++ target.
	+$(MAKE) -C $(BUILD_WORK)/alac/codec clean
	+$(MAKE) -C $(BUILD_WORK)/alac/codec libalac.la \
		CFLAGS="$(filter-out -flto%,$(CFLAGS)) -DTARGET_OS_MAC -fno-lto" \
		CXXFLAGS="$(filter-out -flto%,$(CXXFLAGS)) -fno-lto" \
		LDFLAGS="$(filter-out -flto%,$(LDFLAGS)) -static"
	cp -a $(BUILD_WORK)/alac/codec/.libs/libalac.a \
		$(BUILD_STAGE)/alac/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/
endif
	$(call AFTER_BUILD,copy)
endif

alac-package: alac-stage
	# alac.mk Package Structure
	rm -rf $(BUILD_DIST)/libalac{0,-dev}
	mkdir -p $(BUILD_DIST)/libalac{0,-dev}/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# alac.mk Prep libalac0
	cp -a $(BUILD_STAGE)/alac/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libalac.*.dylib $(BUILD_DIST)/libalac0/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# alac.mk Prep libalac-dev
	cp -a $(BUILD_STAGE)/alac/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include $(BUILD_DIST)/libalac-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)
	cp -a $(BUILD_STAGE)/alac/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/{pkgconfig,libalac.{a,dylib}} $(BUILD_DIST)/libalac-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# alac.mk Sign
	$(call SIGN,libalac0,general.xml)

	# alac.mk Make .debs
	$(call PACK,libalac0,DEB_ALAC_V)
	$(call PACK,libalac-dev,DEB_ALAC_V)

	# alac.mk Build cleanup
	rm -rf $(BUILD_DIST)/libalac{0,-dev}

.PHONY: alac alac-package
