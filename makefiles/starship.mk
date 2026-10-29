ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS      += starship
STARSHIP_VERSION := 0.53.0
DEB_STARSHIP_V   ?= $(STARSHIP_VERSION)-1

starship-setup: setup
	$(call GITHUB_ARCHIVE,starship,starship,$(STARSHIP_VERSION),v$(STARSHIP_VERSION))
	$(call EXTRACT_TAR,starship-$(STARSHIP_VERSION).tar.gz,starship-$(STARSHIP_VERSION),starship)
	# remove this when the following upstream PRs are merged:
	#  https://github.com/FillZpp/sys-info-rs/pull/88
	$(call DO_PATCH,starship,starship,-p1)
ifneq ($(filter appletvos%,$(MEMO_TARGET)),)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/nix-0.20.0.crate,https://static.crates.io/crates/nix/nix-0.20.0.crate)
	$(call CHECKSUM_VERIFY,sha256,nix-0.20.0.crate,fa9b4819da1bc61c0ea48b63b7bc8604064dd43013e7cc325df098d49cd7c18a)
	$(call EXTRACT_TAR,nix-0.20.0.crate,nix-0.20.0,starship-nix)
	$(call DO_PATCH,nix-0.20-tvos,starship-nix,-p1)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/open-1.7.0.crate,https://static.crates.io/crates/open/open-1.7.0.crate)
	$(call CHECKSUM_VERIFY,sha256,open-1.7.0.crate,1711eb4b31ce4ad35b0f316d8dfba4fe5c7ad601c448446d84aae7a896627b20)
	$(call EXTRACT_TAR,open-1.7.0.crate,open-1.7.0,starship-open)
	$(call DO_PATCH,starship-open,starship-open,-p1)
	$(call GITHUB_ARCHIVE,FillZpp,sys-info-rs,70a7aed786347bb2e5f7c6eb26efc52ff3328437,70a7aed786347bb2e5f7c6eb26efc52ff3328437)
	$(call EXTRACT_TAR,sys-info-rs-70a7aed786347bb2e5f7c6eb26efc52ff3328437.tar.gz,sys-info-rs-70a7aed786347bb2e5f7c6eb26efc52ff3328437,starship-sys-info)
	$(call DO_PATCH,starship-sys-info,starship-sys-info,-p1)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/socket2-0.4.10.crate,https://static.crates.io/crates/socket2/socket2-0.4.10.crate)
	$(call CHECKSUM_VERIFY,sha256,socket2-0.4.10.crate,9f7916fc008ca5542385b89a3d3ce689953c143e9304a9bf8beec1de48994c0d)
	$(call EXTRACT_TAR,socket2-0.4.10.crate,socket2-0.4.10,starship-socket2)
	$(call DO_PATCH,gping-socket2,starship-socket2,-p1)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/battery-0.7.8.crate,https://static.crates.io/crates/battery/battery-0.7.8.crate)
	$(call CHECKSUM_VERIFY,sha256,battery-0.7.8.crate,b4b624268937c0e0a3edb7c27843f9e547c320d730c610d3b8e6e8e95b2026e4)
	$(call EXTRACT_TAR,battery-0.7.8.crate,battery-0.7.8,starship-battery)
	$(call DO_PATCH,starship-battery,starship-battery,-p1)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/mach-0.3.2.crate,https://static.crates.io/crates/mach/mach-0.3.2.crate)
	$(call CHECKSUM_VERIFY,sha256,mach-0.3.2.crate,b823e83b2affd8f40a9ee8c29dbc56404c1e34cd2710921f2801e2cf29527afa)
	$(call EXTRACT_TAR,mach-0.3.2.crate,mach-0.3.2,starship-mach)
	$(call DO_PATCH,rbw-mach,starship-mach,-p1)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/attohttpc-0.17.0.crate,https://static.crates.io/crates/attohttpc/attohttpc-0.17.0.crate)
	$(call CHECKSUM_VERIFY,sha256,attohttpc-0.17.0.crate,9a8bda305457262b339322106c776e3fd21df860018e566eb6a5b1aa4b6ae02d)
	$(call EXTRACT_TAR,attohttpc-0.17.0.crate,attohttpc-0.17.0,starship-attohttpc)
	$(call DO_PATCH,starship-attohttpc,starship-attohttpc,-p1)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/native-tls-0.2.7.crate,https://static.crates.io/crates/native-tls/native-tls-0.2.7.crate)
	$(call CHECKSUM_VERIFY,sha256,native-tls-0.2.7.crate,b8d96b2e1c8da3957d58100b09f102c6d9cfdfced01b7ec5a8974044bb09dbd4)
	$(call EXTRACT_TAR,native-tls-0.2.7.crate,native-tls-0.2.7,starship-native-tls)
	$(call DO_PATCH,starship-native-tls,starship-native-tls,-p1)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/security-framework-2.2.0.crate,https://static.crates.io/crates/security-framework/security-framework-2.2.0.crate)
	$(call CHECKSUM_VERIFY,sha256,security-framework-2.2.0.crate,3670b1d2fdf6084d192bc71ead7aabe6c06aa2ea3fbd9cc3ac111fa5c2b1bd84)
	$(call EXTRACT_TAR,security-framework-2.2.0.crate,security-framework-2.2.0,starship-security-framework)
	$(call DO_PATCH,starship-security-framework,starship-security-framework,-p1)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/security-framework-sys-2.2.0.crate,https://static.crates.io/crates/security-framework-sys/security-framework-sys-2.2.0.crate)
	$(call CHECKSUM_VERIFY,sha256,security-framework-sys-2.2.0.crate,3676258fd3cfe2c9a0ec99ce3038798d847ce3e4bb17746373eb9f0f1ac16339)
	$(call EXTRACT_TAR,security-framework-sys-2.2.0.crate,security-framework-sys-2.2.0,starship-security-framework-sys)
	$(call DO_PATCH,starship-security-framework-sys,starship-security-framework-sys,-p1)
	$(call DO_PATCH,starship-tvos,starship,-p1)
endif

ifneq ($(wildcard $(BUILD_WORK)/starship/.build_complete),)
starship:
	@echo "Using previously built starship."
else
starship: starship-setup $(if $(filter iphoneos-arm64-roothide appletvos-arm64-roothide,$(MEMO_TARGET)),libiosexec)
	printf '%s\n' '#!/bin/sh' 'exec "$(CC)" -isysroot "$(TARGET_SYSROOT)" "$$@"' > $(BUILD_WORK)/starship/target-cc-wrapper
	printf '%s\n' '#!/bin/sh' 'exec "$(CXX)" -isysroot "$(TARGET_SYSROOT)" "$$@"' > $(BUILD_WORK)/starship/target-cxx-wrapper
	chmod 755 $(BUILD_WORK)/starship/target-cc-wrapper $(BUILD_WORK)/starship/target-cxx-wrapper
	# pkg-config 0.3.19 selects host/target search paths, but not executables.
	cd $(BUILD_WORK)/starship && $(DEFAULT_RUST_FLAGS) \
		PKG_CONFIG=pkg-config TARGET_PKG_CONFIG_PATH= \
		TARGET_PKG_CONFIG_LIBDIR="$(BUILD_BASE)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/pkgconfig:$(BUILD_BASE)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)$(MEMO_ALT_PREFIX)/lib/pkgconfig:$(BUILD_BASE)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/pkgconfig" \
		TARGET_PKG_CONFIG_SYSROOT_DIR="$(BUILD_BASE)" \
		CC="$(CC_FOR_BUILD)" CXX="$(CXX_FOR_BUILD)" \
		AR="$(AR_FOR_BUILD)" RANLIB="$(RANLIB_FOR_BUILD)" \
		AR_$(subst -,_,$(RUST_TARGET))="$(AR)" RANLIB_$(subst -,_,$(RUST_TARGET))="$(RANLIB)" \
		CC_$(subst -,_,$(RUST_TARGET))="$(BUILD_WORK)/starship/target-cc-wrapper" \
		CXX_$(subst -,_,$(RUST_TARGET))="$(BUILD_WORK)/starship/target-cxx-wrapper" \
		CFLAGS_$(subst -,_,$(RUST_TARGET))="$(CFLAGS) $(if $(filter aarch64-apple-ios,$(RUST_TARGET)),-include stdio.h)" CXXFLAGS_$(subst -,_,$(RUST_TARGET))="$(CXXFLAGS)" \
		CARGO_TARGET_$(subst -,_,$(shell echo $(RUST_TARGET) | tr '[:lower:]' '[:upper:]'))_LINKER="$(BUILD_WORK)/starship/target-cc-wrapper" \
		CFLAGS= CXXFLAGS= CPPFLAGS= ASFLAGS= LDFLAGS= RUSTFLAGS="$(if $(filter appletvos%,$(MEMO_TARGET)),-L framework=$(BUILD_BASE)/$(MEMO_PREFIX)/System/Library/Frameworks) -L $(BUILD_BASE)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib $(if $(filter iphoneos-arm64-roothide appletvos-arm64-roothide,$(MEMO_TARGET)),-C link-arg=-liosexec)" cargo build \
		--release \
		--locked \
		--target=$(RUST_TARGET)
	$(INSTALL) -Dm755 $(BUILD_WORK)/starship/target/$(RUST_TARGET)/release/starship $(BUILD_STAGE)/starship/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/starship
	$(call AFTER_BUILD)
endif

starship-package: starship-stage
	# starship.mk Package Structure
	rm -rf $(BUILD_DIST)/starship

	# starship.mk Prep starship
	cp -a $(BUILD_STAGE)/starship $(BUILD_DIST)

	# starship.mk Sign
	$(call SIGN,starship,general.xml)

	# starship.mk Make .debs
	$(call PACK,starship,DEB_STARSHIP_V)

	# starship.mk Build cleanup
	rm -rf $(BUILD_DIST)/starship

.PHONY: starship starship-package
