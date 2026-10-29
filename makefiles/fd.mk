ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS += fd
FD_VERSION  := 8.6.0
DEB_FD_V    ?= $(FD_VERSION)-1

fd-setup: setup $(if $(filter appletvos%,$(MEMO_TARGET)),lsd-setup)
	$(call GITHUB_ARCHIVE,sharkdp,fd,$(FD_VERSION),v$(FD_VERSION))
	$(call EXTRACT_TAR,fd-$(FD_VERSION).tar.gz,fd-$(FD_VERSION),fd)
	sed -i 's+users = "0.11.0"+users = {git = "https://github.com/ogham/rust-users", rev = "5208452"}+g' \
		$(BUILD_WORK)/fd/Cargo.toml
	$(call DO_PATCH,fd,fd,-p1)
ifneq ($(filter appletvos%,$(MEMO_TARGET)),)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/nix-0.24.2.crate,https://static.crates.io/crates/nix/nix-0.24.2.crate)
	$(call CHECKSUM_VERIFY,sha256,nix-0.24.2.crate,195cdbc1741b8134346d515b3a56a1c94b0912758009cfd53f99ea0f57b065fc)
	$(call EXTRACT_TAR,nix-0.24.2.crate,nix-0.24.2,fd-nix-0.24.2)
	$(call DO_PATCH,nix-0.24-tvos,fd-nix-0.24.2,-p1)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/nix-0.25.0.crate,https://static.crates.io/crates/nix/nix-0.25.0.crate)
	$(call CHECKSUM_VERIFY,sha256,nix-0.25.0.crate,e322c04a9e3440c327fca7b6c8a63e6890a32fa2ad689db972425f07e0d22abb)
	$(call EXTRACT_TAR,nix-0.25.0.crate,nix-0.25.0,fd-nix-0.25.0)
	$(call DO_PATCH,nix-0.25-tvos,fd-nix-0.25.0,-p1)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/rustix-0.35.12.crate,https://static.crates.io/crates/rustix/rustix-0.35.12.crate)
	$(call CHECKSUM_VERIFY,sha256,rustix-0.35.12.crate,985947f9b6423159c4726323f373be0a21bdb514c5af06a849cb3d2dce2d01e8)
	$(call EXTRACT_TAR,rustix-0.35.12.crate,rustix-0.35.12,fd-rustix)
	$(call DO_PATCH,fd-rustix,fd-rustix,-p1)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/ctrlc-3.2.3.crate,https://static.crates.io/crates/ctrlc/ctrlc-3.2.3.crate)
	$(call CHECKSUM_VERIFY,sha256,ctrlc-3.2.3.crate,1d91974fbbe88ec1df0c24a4f00f99583667a7e2e6272b2b92d294d81e462173)
	$(call EXTRACT_TAR,ctrlc-3.2.3.crate,ctrlc-3.2.3,fd-ctrlc)
	$(call DO_PATCH,fd-ctrlc,fd-ctrlc,-p1)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/errno-0.2.8.crate,https://static.crates.io/crates/errno/errno-0.2.8.crate)
	$(call CHECKSUM_VERIFY,sha256,errno-0.2.8.crate,f639046355ee4f37944e44f60642c6f3a7efa3cf6b78c78a0d989a8ce6c396a1)
	$(call EXTRACT_TAR,errno-0.2.8.crate,errno-0.2.8,fd-errno)
	$(call DO_PATCH,fd-errno,fd-errno,-p1)
	$(call DO_PATCH,fd-tvos,fd,-p1)
endif
	sed -i 's|(target_os = "macos")|(target_vendor = "apple")|' \
		$(BUILD_WORK)/fd/Cargo.toml $(BUILD_WORK)/fd/src/main.rs $(BUILD_WORK)/fd/src/walk.rs

ifneq ($(wildcard $(BUILD_WORK)/fd/.build_complete),)
fd:
	@echo "Using previously built fd."
else
fd: fd-setup $(if $(filter appletvos-arm64-roothide,$(MEMO_TARGET)),libiosexec)
	printf '%s\n' '#!/bin/sh' 'exec "$(CC)" -isysroot "$(TARGET_SYSROOT)" "$$@"' > $(BUILD_WORK)/fd/target-cc-wrapper
	printf '%s\n' '#!/bin/sh' 'exec "$(CXX)" -isysroot "$(TARGET_SYSROOT)" "$$@"' > $(BUILD_WORK)/fd/target-cxx-wrapper
	chmod 755 $(BUILD_WORK)/fd/target-cc-wrapper $(BUILD_WORK)/fd/target-cxx-wrapper
	cd $(BUILD_WORK)/fd && $(DEFAULT_RUST_FLAGS) \
		CC="$(CC_FOR_BUILD)" CXX="$(CXX_FOR_BUILD)" \
		CC_$(subst -,_,$(RUST_TARGET))="$(BUILD_WORK)/fd/target-cc-wrapper" \
		CXX_$(subst -,_,$(RUST_TARGET))="$(BUILD_WORK)/fd/target-cxx-wrapper" \
		CFLAGS_$(subst -,_,$(RUST_TARGET))="$(CFLAGS)" CXXFLAGS_$(subst -,_,$(RUST_TARGET))="$(CXXFLAGS)" \
		CARGO_TARGET_$(subst -,_,$(shell echo $(RUST_TARGET) | tr '[:lower:]' '[:upper:]'))_LINKER="$(BUILD_WORK)/fd/target-cc-wrapper" \
		CFLAGS= CXXFLAGS= $(if $(filter appletvos-arm64-roothide,$(MEMO_TARGET)),RUSTFLAGS="-L $(BUILD_BASE)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib -C link-arg=-liosexec") cargo build \
		--release \
		--locked \
		--target=$(RUST_TARGET)
	$(INSTALL) -Dm755 $(BUILD_WORK)/fd/target/$(RUST_TARGET)/release/fd $(BUILD_STAGE)/fd/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/fd
	$(INSTALL) -Dm644 $(BUILD_WORK)/fd/doc/fd.1 $(BUILD_STAGE)/fd/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/man1/fd.1
	$(call AFTER_BUILD)
endif

fd-package: fd-stage
	# fd.mk Package Structure
	rm -rf $(BUILD_DIST)/fd

	# fd.mk Prep fd
	cp -a $(BUILD_STAGE)/fd $(BUILD_DIST)

	# fd.mk Sign
	$(call SIGN,fd,general.xml)

	# fd.mk Make .debs
	$(call PACK,fd,DEB_FD_V)

	# fd.mk Build cleanup
	rm -rf $(BUILD_DIST)/fd

.PHONY: fd fd-package
