# This is literally just a search and replace of ripgrep.mk, thank you rust

ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS += rbw
RBW_VERSION := 1.0.0
DEB_RBW_V   ?= $(RBW_VERSION)-1
RBW_TARGET_SYSROOT = $(BUILD_WORK)/rbw/apple-sdk/SDKs/$(notdir $(TARGET_SYSROOT))

rbw-setup: setup
	$(call GITHUB_ARCHIVE,doy,rbw,$(RBW_VERSION),$(RBW_VERSION))
	$(call EXTRACT_TAR,rbw-$(RBW_VERSION).tar.gz,rbw-$(RBW_VERSION),rbw)
ifneq ($(filter appletvos%,$(MEMO_TARGET)),)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/openssl-src-111.28.2+1.1.1w.crate,https://static.crates.io/crates/openssl-src/openssl-src-111.28.2+1.1.1w.crate)
	$(call CHECKSUM_VERIFY,sha256,openssl-src-111.28.2+1.1.1w.crate,bb1830e20a48a975ca898ca8c1d036a36c3c6c5cb7dabc1c216706587857920f)
	$(call EXTRACT_TAR,openssl-src-111.28.2+1.1.1w.crate,openssl-src-111.28.2+1.1.1w,rbw-openssl-src)
	$(call DO_PATCH,rbw-openssl-src,rbw-openssl-src,-p1)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/ring-0.16.20.crate,https://static.crates.io/crates/ring/ring-0.16.20.crate)
	$(call CHECKSUM_VERIFY,sha256,ring-0.16.20.crate,3053cf52e236a3ed746dfc745aa9cacf1b791d846bdaf412f60a8d7d6e17c8fc)
	$(call EXTRACT_TAR,ring-0.16.20.crate,ring-0.16.20,rbw-ring)
	$(call DO_PATCH,rbw-ring,rbw-ring,-p1)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/nix-0.19.1.crate,https://static.crates.io/crates/nix/nix-0.19.1.crate)
	$(call CHECKSUM_VERIFY,sha256,nix-0.19.1.crate,b2ccba0cfe4fdf15982d1674c69b1fd80bad427d293849982668dfe454bd61f2)
	$(call EXTRACT_TAR,nix-0.19.1.crate,nix-0.19.1,rbw-nix)
	$(call DO_PATCH,rbw-nix,rbw-nix,-p1)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/net2-0.2.37.crate,https://static.crates.io/crates/net2/net2-0.2.37.crate)
	$(call CHECKSUM_VERIFY,sha256,net2-0.2.37.crate,391630d12b68002ae1e25e8f974306474966550ad82dac6886fb8910c19568ae)
	$(call EXTRACT_TAR,net2-0.2.37.crate,net2-0.2.37,rbw-net2)
	$(call DO_PATCH,net2-0.2-tvos,rbw-net2,-p1)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/socket2-0.3.19.crate,https://static.crates.io/crates/socket2/socket2-0.3.19.crate)
	$(call CHECKSUM_VERIFY,sha256,socket2-0.3.19.crate,122e570113d28d773067fab24266b66753f6ea915758651696b6e35e49f88d6e)
	$(call EXTRACT_TAR,socket2-0.3.19.crate,socket2-0.3.19,rbw-socket2)
	$(call DO_PATCH,rbw-socket2,rbw-socket2,-p1)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/region-2.2.0.crate,https://static.crates.io/crates/region/region-2.2.0.crate)
	$(call CHECKSUM_VERIFY,sha256,region-2.2.0.crate,877e54ea2adcd70d80e9179344c97f93ef0dffd6b03e1f4529e6e83ab2fa9ae0)
	$(call EXTRACT_TAR,region-2.2.0.crate,region-2.2.0,rbw-region)
	$(call DO_PATCH,rbw-region,rbw-region,-p1)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/mach-0.3.2.crate,https://static.crates.io/crates/mach/mach-0.3.2.crate)
	$(call CHECKSUM_VERIFY,sha256,mach-0.3.2.crate,b823e83b2affd8f40a9ee8c29dbc56404c1e34cd2710921f2801e2cf29527afa)
	$(call EXTRACT_TAR,mach-0.3.2.crate,mach-0.3.2,rbw-mach)
	$(call DO_PATCH,rbw-mach,rbw-mach,-p1)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/mio-0.6.23.crate,https://static.crates.io/crates/mio/mio-0.6.23.crate)
	$(call CHECKSUM_VERIFY,sha256,mio-0.6.23.crate,4afd66f5b91bf2a3bc13fad0e21caedac168ca4c707504e75585648ae80e4cc4)
	$(call EXTRACT_TAR,mio-0.6.23.crate,mio-0.6.23,rbw-mio)
	$(call DO_PATCH,mio-0.6-tvos,rbw-mio,-p1)
endif

ifneq ($(wildcard $(BUILD_WORK)/rbw/.build_complete),)
rbw:
	@echo "Using previously built rbw."
else
rbw: rbw-setup
	$(call DO_PATCH,rbw,rbw,-p1)
ifneq ($(filter appletvos%,$(MEMO_TARGET)),)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/tokio-0.2.25.crate,https://static.crates.io/crates/tokio/tokio-0.2.25.crate)
	$(call CHECKSUM_VERIFY,sha256,tokio-0.2.25.crate,6703a273949a90131b290be1fe7b039d0fc884aa1935860dfcbe056f28cd8092)
	$(call EXTRACT_TAR,tokio-0.2.25.crate,tokio-0.2.25,rbw-tokio)
	$(call DO_PATCH,rbw-tokio,rbw-tokio,-p1)
	$(call DO_PATCH,rbw-tvos,rbw,-p1)
endif
	# openssl-src expects Apple's /SDKs/ layout; retain the selected SDK bytes.
	mkdir -p $(BUILD_WORK)/rbw/apple-sdk/SDKs
	ln -sfn "$(TARGET_SYSROOT)" "$(RBW_TARGET_SYSROOT)"
	printf '%s\n' '#!/bin/sh' 'exec "$(CC)" -isysroot "$(RBW_TARGET_SYSROOT)" "$$@"' > $(BUILD_WORK)/rbw/target-cc-wrapper
	printf '%s\n' '#!/bin/sh' 'exec "$(CXX)" -isysroot "$(RBW_TARGET_SYSROOT)" "$$@"' > $(BUILD_WORK)/rbw/target-cxx-wrapper
	chmod 755 $(BUILD_WORK)/rbw/target-{cc,cxx}-wrapper
	cd $(BUILD_WORK)/rbw && $(DEFAULT_RUST_FLAGS) \
		SDKROOT="$(MACOSX_SYSROOT)" \
		CC="$(CC_FOR_BUILD)" CXX="$(CXX_FOR_BUILD)" \
		CC_$(subst -,_,$(RUST_TARGET))="$(BUILD_WORK)/rbw/target-cc-wrapper" \
		CXX_$(subst -,_,$(RUST_TARGET))="$(BUILD_WORK)/rbw/target-cxx-wrapper" \
		CFLAGS_$(subst -,_,$(RUST_TARGET))="$(subst $(TARGET_SYSROOT),$(RBW_TARGET_SYSROOT),$(CFLAGS))" CXXFLAGS_$(subst -,_,$(RUST_TARGET))="$(subst $(TARGET_SYSROOT),$(RBW_TARGET_SYSROOT),$(CXXFLAGS))" \
		CARGO_TARGET_$(subst -,_,$(shell echo $(RUST_TARGET) | tr '[:lower:]' '[:upper:]'))_LINKER="$(BUILD_WORK)/rbw/target-cc-wrapper" \
		CFLAGS= CXXFLAGS= CPPFLAGS= ASFLAGS= LDFLAGS= RUSTFLAGS="-L $(BUILD_BASE)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib $(if $(filter iphoneos-arm64-roothide appletvos-arm64-roothide,$(MEMO_TARGET)),-C link-arg=-liosexec)" cargo build \
		--release \
		--locked \
		--target=$(RUST_TARGET)
	$(INSTALL) -Dm755 $(BUILD_WORK)/rbw/target/$(RUST_TARGET)/release/rbw $(BUILD_STAGE)/rbw/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/rbw
	$(INSTALL) -Dm755 $(BUILD_WORK)/rbw/target/$(RUST_TARGET)/release/rbw-agent $(BUILD_STAGE)/rbw/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/rbw-agent
	$(INSTALL) -Dm755 $(BUILD_WORK)/rbw/bin/rbw-fzf $(BUILD_STAGE)/rbw/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/rbw-fzf
	$(INSTALL) -Dm755 $(BUILD_WORK)/rbw/bin/pass-import $(BUILD_STAGE)/rbw/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/pass-import
	$(call AFTER_BUILD)
endif

rbw-package: rbw-stage
	# rbw.mk Package Structure
	rm -rf $(BUILD_DIST)/rbw

	# rbw.mk Prep rbw
	cp -a $(BUILD_STAGE)/rbw $(BUILD_DIST)

	# rbw.mk Sign
	$(call SIGN,rbw,general.xml)

	# rbw.mk Make .debs
	$(call PACK,rbw,DEB_RBW_V)

	# rbw.mk Build cleanup
	rm -rf $(BUILD_DIST)/rbw

.PHONY: rbw rbw-package
