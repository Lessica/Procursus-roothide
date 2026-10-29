ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS       += fastfetch
FASTFETCH_VERSION := 2.70.0
FASTFETCH_COMMIT  := 17bb3fd2384bd814b421d73b8c8b8d08e06cfa26
DEB_FASTFETCH_V   ?= $(FASTFETCH_VERSION)-1

fastfetch-setup: setup
	$(call GITHUB_ARCHIVE,fastfetch-cli,fastfetch,$(FASTFETCH_COMMIT),$(FASTFETCH_COMMIT))
	$(call EXTRACT_TAR,fastfetch-$(FASTFETCH_COMMIT).tar.gz,fastfetch-$(FASTFETCH_COMMIT),fastfetch)
	$(call DO_PATCH,fastfetch,fastfetch,-p1)

ifneq ($(wildcard $(BUILD_WORK)/fastfetch/.build_complete),)
fastfetch:
	@echo "Using previously built fastfetch."
else
fastfetch: fastfetch-setup libiosexec
	# The iOS SDK omits headers for APIs the system still exports. Borrow those
	# headers from the macOS SDK the build host provides, as theos does.
	shim="$(BUILD_WORK)/fastfetch/sdk-shim"; \
	rm -rf "$$shim"; \
	mkdir -p "$$shim/sys" "$$shim/net" "$$shim/IOKit"; \
	for header in libproc.h sys/proc_info.h sys/kern_control.h sys/user.h net/route.h net/if_mib.h net/if_media.h; do \
		if [ ! -e "$(TARGET_SYSROOT)/usr/include/$$header" ]; then \
			ln -s "$(MACOSX_SYSROOT)/usr/include/$$header" "$$shim/$$header"; \
		fi; \
	done; \
	for entry in "$(MACOSX_SYSROOT)"/System/Library/Frameworks/IOKit.framework/Headers/*; do \
		name="$$(basename "$$entry")"; \
		if [ ! -e "$(TARGET_SYSROOT)/System/Library/Frameworks/IOKit.framework/Headers/$$name" ]; then \
			ln -s "$$entry" "$$shim/IOKit/$$name"; \
		fi; \
	done
	mkdir -p $(BUILD_WORK)/fastfetch/build
	cd $(BUILD_WORK)/fastfetch/build && cmake .. \
		$(DEFAULT_CMAKE_FLAGS) \
		-DIOS=ON \
		-DCMAKE_C_FLAGS="$(CFLAGS) -isystem $(BUILD_WORK)/fastfetch/sdk-shim -include TargetConditionals.h -include $(BUILD_WORK)/fastfetch/src/common/apple/chip_ios.h" \
		-DCMAKE_OBJC_FLAGS="$(CFLAGS) -isystem $(BUILD_WORK)/fastfetch/sdk-shim -include TargetConditionals.h -include $(BUILD_WORK)/fastfetch/src/common/apple/chip_ios.h" \
		-DCMAKE_CXX_FLAGS="$(CXXFLAGS) -isystem $(BUILD_WORK)/fastfetch/sdk-shim -include TargetConditionals.h -include $(BUILD_WORK)/fastfetch/src/common/apple/chip_ios.h" \
		-DBUILD_FLASHFETCH=OFF \
		-DBUILD_TESTS=OFF \
		-DENABLE_WORDEXP=OFF \
		-DHAVE_PIPE2=0 \
		-DINSTALL_LICENSE=OFF \
		-DCMAKE_EXE_LINKER_FLAGS="$(LDFLAGS) -Wl,-U,_VTRegisterSupplementalVideoDecoderIfAvailable" \
		.
	+$(MAKE) -C $(BUILD_WORK)/fastfetch/build
	+$(MAKE) -C $(BUILD_WORK)/fastfetch/build install \
		DESTDIR="$(BUILD_STAGE)/fastfetch"
	$(call AFTER_BUILD)
endif

fastfetch-package: fastfetch-stage
	# fastfetch.mk Package Structure
	rm -rf $(BUILD_DIST)/fastfetch

	# fastfetch.mk Prep fastfetch
	cp -a $(BUILD_STAGE)/fastfetch $(BUILD_DIST)

	# fastfetch.mk Sign
	$(call SIGN,fastfetch,general.xml)

	# fastfetch.mk Make .debs
	$(call PACK,fastfetch,DEB_FASTFETCH_V)

	# fastfetch.mk Build cleanup
	rm -rf $(BUILD_DIST)/fastfetch

.PHONY: fastfetch fastfetch-package
