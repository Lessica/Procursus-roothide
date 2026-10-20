ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS    += libglu
LIBGLU_VERSION := 9.0.1
DEB_LIBGLU_V   ?= $(LIBGLU_VERSION)-2

libglu-setup: setup
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/libglu-$(LIBGLU_VERSION).tar.xz, \
		https://mesa.freedesktop.org/archive/glu/glu-$(LIBGLU_VERSION).tar.xz)
	$(call EXTRACT_TAR,libglu-$(LIBGLU_VERSION).tar.xz,glu-$(LIBGLU_VERSION),libglu)
	$(call DO_PATCH,libglu,libglu,-p1)

ifneq ($(wildcard $(BUILD_WORK)/libglu/.build_complete),)
libglu:
	@echo "Using previously built libglu."
else
libglu: libglu-setup mesa
	cd $(BUILD_WORK)/libglu && ./configure -C \
		$(DEFAULT_CONFIGURE_FLAGS)
	# libtool's Darwin CXX archive path creates a master object with bare CC,
	# dropping the target flags that configure recorded in CXXFLAGS.
	sed -i 's|\$$CC -r -keep_private_externs -nostdlib|\$$CC \$$CXXFLAGS -r -keep_private_externs -nostdlib|g' $(BUILD_WORK)/libglu/libtool
	+$(MAKE) -C $(BUILD_WORK)/libglu
	+$(MAKE) -C $(BUILD_WORK)/libglu install \
		DESTDIR=$(BUILD_STAGE)/libglu
	$(call AFTER_BUILD,copy)
endif

libglu-package: libglu-stage
	# libglu.mk Package Structure
	rm -rf $(BUILD_DIST)/libglu1-mesa{,-dev}
	mkdir -p $(BUILD_DIST)/libglu1-mesa{,-dev}/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libglu.mk Prep libglu1-mesa
	cp -a $(BUILD_STAGE)/libglu/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libGLU.1.dylib $(BUILD_DIST)/libglu1-mesa/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libglu.mk Prep libglu1-mesa-dev
	cp -a $(BUILD_STAGE)/libglu/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/!(libGLU.1.dylib) $(BUILD_DIST)/libglu1-mesa-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libglu/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include $(BUILD_DIST)/libglu1-mesa-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)

	# libglu.mk Sign
	$(call SIGN,libglu1-mesa,general.xml)

	# libglu.mk Make .debs
	$(call PACK,libglu1-mesa,DEB_LIBGLU_V)
	$(call PACK,libglu1-mesa-dev,DEB_LIBGLU_V)

	# libglu.mk Build cleanup
	rm -rf $(BUILD_DIST)/libglu1-mesa{,-dev}

.PHONY: libglu libglu-package
