ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS      += spotifyd
SPOTIFYD_VERSION := 0.3.4
DEB_SPOTIFYD_V   ?= $(SPOTIFYD_VERSION)

spotifyd-setup: setup $(if $(and $(filter appletvos%,$(MEMO_TARGET)),$(filter rbw,$(SUBPROJECTS))),rbw-setup)
	$(call GITHUB_ARCHIVE,Spotifyd,spotifyd,v$(SPOTIFYD_VERSION),v$(SPOTIFYD_VERSION))
	$(call EXTRACT_TAR,spotifyd-v$(SPOTIFYD_VERSION).tar.gz,spotifyd-$(SPOTIFYD_VERSION),spotifyd)
	$(call DO_PATCH,spotifyd,spotifyd,-p1)
ifneq ($(filter appletvos%,$(MEMO_TARGET)),)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/keyring-1.2.1.crate,https://static.crates.io/crates/keyring/keyring-1.2.1.crate)
	$(call CHECKSUM_VERIFY,sha256,keyring-1.2.1.crate,ba264b266563c1363dcce004776cbf198d7422a4262f77f4ca285bf26ae30955)
	$(call EXTRACT_TAR,keyring-1.2.1.crate,keyring-1.2.1,spotifyd-keyring)
	sed -i 's/\r$$//' $(BUILD_WORK)/spotifyd-keyring/src/lib.rs
	$(call DO_PATCH,spotifyd-keyring,spotifyd-keyring,-p1)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/security-framework-2.7.0.crate,https://static.crates.io/crates/security-framework/security-framework-2.7.0.crate)
	$(call CHECKSUM_VERIFY,sha256,security-framework-2.7.0.crate,2bc1bb97804af6631813c55739f771071e0f2ed33ee20b68c86ec505d906356c)
	$(call EXTRACT_TAR,security-framework-2.7.0.crate,security-framework-2.7.0,spotifyd-security-framework)
	$(call DO_PATCH,spotifyd-security-framework,spotifyd-security-framework,-p1)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/security-framework-sys-2.6.1.crate,https://static.crates.io/crates/security-framework-sys/security-framework-sys-2.6.1.crate)
	$(call CHECKSUM_VERIFY,sha256,security-framework-sys-2.6.1.crate,0160a13a177a45bfb43ce71c01580998474f556ad854dcbca936dd2841a5c556)
	$(call EXTRACT_TAR,security-framework-sys-2.6.1.crate,security-framework-sys-2.6.1,spotifyd-security-framework-sys)
	$(call DO_PATCH,spotifyd-security-framework-sys,spotifyd-security-framework-sys,-p1)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/mio-0.6.23.crate,https://static.crates.io/crates/mio/mio-0.6.23.crate)
	$(call CHECKSUM_VERIFY,sha256,mio-0.6.23.crate,4afd66f5b91bf2a3bc13fad0e21caedac168ca4c707504e75585648ae80e4cc4)
	$(call EXTRACT_TAR,mio-0.6.23.crate,mio-0.6.23,spotifyd-mio)
	$(call DO_PATCH,mio-0.6-tvos,spotifyd-mio,-p1)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/net2-0.2.37.crate,https://static.crates.io/crates/net2/net2-0.2.37.crate)
	$(call CHECKSUM_VERIFY,sha256,net2-0.2.37.crate,391630d12b68002ae1e25e8f974306474966550ad82dac6886fb8910c19568ae)
	$(call EXTRACT_TAR,net2-0.2.37.crate,net2-0.2.37,spotifyd-net2)
	$(call DO_PATCH,net2-0.2-tvos,spotifyd-net2,-p1)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/parking_lot_core-0.6.2.crate,https://static.crates.io/crates/parking_lot_core/parking_lot_core-0.6.2.crate)
	$(call CHECKSUM_VERIFY,sha256,parking_lot_core-0.6.2.crate,b876b1b9e7ac6e1a74a6da34d25c42e17e8862aa409cbbbdcfc8d86c6f3bc62b)
	$(call EXTRACT_TAR,parking_lot_core-0.6.2.crate,parking_lot_core-0.6.2,spotifyd-parking_lot_core)
	$(call DO_PATCH,spotifyd-parking_lot_core,spotifyd-parking_lot_core,-p1)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/if-addrs-0.6.7.crate,https://static.crates.io/crates/if-addrs/if-addrs-0.6.7.crate)
	$(call CHECKSUM_VERIFY,sha256,if-addrs-0.6.7.crate,2273e421f7c4f0fc99e1934fe4776f59d8df2972f4199d703fc0da9f2a9f73de)
	$(call EXTRACT_TAR,if-addrs-0.6.7.crate,if-addrs-0.6.7,spotifyd-if-addrs)
	$(call DO_PATCH,spotifyd-if-addrs,spotifyd-if-addrs,-p1)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/socket2-0.4.10.crate,https://static.crates.io/crates/socket2/socket2-0.4.10.crate)
	$(call CHECKSUM_VERIFY,sha256,socket2-0.4.10.crate,9f7916fc008ca5542385b89a3d3ce689953c143e9304a9bf8beec1de48994c0d)
	$(call EXTRACT_TAR,socket2-0.4.10.crate,socket2-0.4.10,spotifyd-socket2)
	$(call DO_PATCH,gping-socket2,spotifyd-socket2,-p1)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/tokio-1.21.1.crate,https://static.crates.io/crates/tokio/tokio-1.21.1.crate)
	$(call CHECKSUM_VERIFY,sha256,tokio-1.21.1.crate,0020c875007ad96677dcc890298f4b942882c5d4eb7cc8f439fc3bf813dc9c95)
	$(call EXTRACT_TAR,tokio-1.21.1.crate,tokio-1.21.1,spotifyd-tokio)
	$(call DO_PATCH,spotifyd-tokio,spotifyd-tokio,-p1)
	$(call DO_PATCH,spotifyd-tvos,spotifyd,-p1)
endif

ifneq ($(wildcard $(BUILD_WORK)/spotifyd/.build_complete),)
spotifyd:
	@echo "Using previously built spotifyd."
else
spotifyd: spotifyd-setup portaudio
	# Old gcc-rs appends its own SDK/minOS; the selected target flags must win.
	printf '%s\n' '#!/bin/sh' 'exec "$(CC)" "$$@" -isysroot "$(TARGET_SYSROOT)" $(filter -miphoneos-version-min=% -mappletvos-version-min=% -mios-simulator-version-min=% -mmacosx-version-min=%,$(CFLAGS))' > $(BUILD_WORK)/spotifyd/target-cc-wrapper
	printf '%s\n' '#!/bin/sh' 'exec "$(CXX)" "$$@" -isysroot "$(TARGET_SYSROOT)" $(filter -miphoneos-version-min=% -mappletvos-version-min=% -mios-simulator-version-min=% -mmacosx-version-min=%,$(CXXFLAGS))' > $(BUILD_WORK)/spotifyd/target-cxx-wrapper
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
		CFLAGS= CXXFLAGS= CPPFLAGS= ASFLAGS= LDFLAGS= RUSTFLAGS="-L $(BUILD_BASE)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib $(if $(filter iphoneos-arm64-roothide appletvos-arm64-roothide,$(MEMO_TARGET)),-C link-arg=-liosexec)" cargo build \
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
