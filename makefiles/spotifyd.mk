ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS      += spotifyd
SPOTIFYD_VERSION := 0.3.4
DEB_SPOTIFYD_V   ?= $(SPOTIFYD_VERSION)

spotifyd-setup: setup
	$(call GITHUB_ARCHIVE,Spotifyd,spotifyd,v$(SPOTIFYD_VERSION),v$(SPOTIFYD_VERSION))
	$(call EXTRACT_TAR,spotifyd-v$(SPOTIFYD_VERSION).tar.gz,spotifyd-$(SPOTIFYD_VERSION),spotifyd)
	$(call DO_PATCH,spotifyd,spotifyd,-p1)

ifneq ($(wildcard $(BUILD_WORK)/spotifyd/.build_complete),)
spotifyd:
	@echo "Using previously built spotifyd."
else
spotifyd: spotifyd-setup portaudio
	# Old gcc-rs appends its own SDK/minOS; the selected target flags must win.
	printf '%s\n' '#!/bin/sh' 'exec "$(CC)" "$$@" -isysroot "$(TARGET_SYSROOT)" $(filter -miphoneos-version-min=% -mios-simulator-version-min=% -mmacosx-version-min=%,$(CFLAGS))' > $(BUILD_WORK)/spotifyd/target-cc-wrapper
	printf '%s\n' '#!/bin/sh' 'exec "$(CXX)" "$$@" -isysroot "$(TARGET_SYSROOT)" $(filter -miphoneos-version-min=% -mios-simulator-version-min=% -mmacosx-version-min=%,$(CXXFLAGS))' > $(BUILD_WORK)/spotifyd/target-cxx-wrapper
	chmod 755 $(BUILD_WORK)/spotifyd/target-{cc,cxx}-wrapper
	cd $(BUILD_WORK)/spotifyd && $(DEFAULT_RUST_FLAGS) \
		SDKROOT="$(MACOSX_SYSROOT)" \
		COREAUDIO_SDK_PATH="$(TARGET_SYSROOT)" \
		PKG_CONFIG="$(BUILD_TOOLS)/cross-pkg-config" PKG_CONFIG_ALLOW_CROSS=1 \
		$(if $(filter Darwin,$(UNAME)),LIBCLANG_PATH="$(dir $(CC))../lib") \
		CC="$(CC_FOR_BUILD)" CXX="$(CXX_FOR_BUILD)" \
		CC_$(subst -,_,$(RUST_TARGET))="$(BUILD_WORK)/spotifyd/target-cc-wrapper" \
		CXX_$(subst -,_,$(RUST_TARGET))="$(BUILD_WORK)/spotifyd/target-cxx-wrapper" \
		CFLAGS_$(subst -,_,$(RUST_TARGET))="$(CFLAGS)" CXXFLAGS_$(subst -,_,$(RUST_TARGET))="$(CXXFLAGS)" \
		CARGO_TARGET_$(subst -,_,$(shell echo $(RUST_TARGET) | tr '[:lower:]' '[:upper:]'))_LINKER="$(BUILD_WORK)/spotifyd/target-cc-wrapper" \
		CFLAGS= CXXFLAGS= CPPFLAGS= ASFLAGS= LDFLAGS= RUSTFLAGS="-L $(BUILD_BASE)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib $(if $(filter iphoneos-arm64-roothide,$(MEMO_TARGET)),-C link-arg=-liosexec)" cargo build \
		--release \
		--locked \
		--no-default-features \
		--features dbus_keyring,portaudio_backend,rodio_backend \
		--target=$(RUST_TARGET)
	$(INSTALL) -Dm755 $(BUILD_WORK)/spotifyd/target/$(RUST_TARGET)/release/spotifyd $(BUILD_STAGE)/spotifyd/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/spotifyd
	$(call AFTER_BUILD)
endif

spotifyd-package: spotifyd-stage
	# spotifyd.mk Package Structure
	rm -rf $(BUILD_DIST)/spotifyd

	# spotifyd.mk Prep spotifyd
	cp -a $(BUILD_STAGE)/spotifyd $(BUILD_DIST)

	# spotifyd.mk Sign
	$(call SIGN,spotifyd,general.xml)

	# spotifyd.mk Make .debs
	$(call PACK,spotifyd,DEB_SPOTIFYD_V)

	# spotifyd.mk Build cleanup
	rm -rf $(BUILD_DIST)/spotifyd

.PHONY: spotifyd spotifyd-package
