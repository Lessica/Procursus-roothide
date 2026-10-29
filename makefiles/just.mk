ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS   += just
JUST_VERSION  := 1.13.0
DEB_JUST_V    ?= $(JUST_VERSION)-2

just-setup: setup
	$(call GITHUB_ARCHIVE,casey,just,$(JUST_VERSION),$(JUST_VERSION))
	$(call EXTRACT_TAR,just-$(JUST_VERSION).tar.gz,just-$(JUST_VERSION),just)
	$(call DO_PATCH,just,just,-p1)
ifneq ($(filter appletvos%,$(MEMO_TARGET)),)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/nix-0.26.2.crate,https://static.crates.io/crates/nix/nix-0.26.2.crate)
	$(call CHECKSUM_VERIFY,sha256,nix-0.26.2.crate,bfdda3d196821d6af13126e40375cdf7da646a96114af134d5f417a9a1dc8e1a)
	$(call EXTRACT_TAR,nix-0.26.2.crate,nix-0.26.2,just-nix)
	$(call DO_PATCH,nix-0.26-tvos,just-nix,-p1)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/ctrlc-3.2.4.crate,https://static.crates.io/crates/ctrlc/ctrlc-3.2.4.crate)
	$(call CHECKSUM_VERIFY,sha256,ctrlc-3.2.4.crate,1631ca6e3c59112501a9d87fd86f21591ff77acd31331e8a73f8d80a65bbdd71)
	$(call EXTRACT_TAR,ctrlc-3.2.4.crate,ctrlc-3.2.4,just-ctrlc)
	$(call DO_PATCH,just-ctrlc,just-ctrlc,-p1)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/rustix-0.36.7.crate,https://static.crates.io/crates/rustix/rustix-0.36.7.crate)
	$(call CHECKSUM_VERIFY,sha256,rustix-0.36.7.crate,d4fdebc4b395b7fbb9ab11e462e20ed9051e7b16e42d24042c776eca0ac81b03)
	$(call EXTRACT_TAR,rustix-0.36.7.crate,rustix-0.36.7,just-rustix)
	$(call DO_PATCH,just-rustix,just-rustix,-p1)
	$(call DO_PATCH,just-tvos,just,-p1)
endif

ifneq ($(wildcard $(BUILD_WORK)/just/.build_complete),)
just:
	@echo "Using previously built just."
else
just: just-setup
	printf '%s\n' '#!/bin/sh' 'exec "$(CC)" -isysroot "$(TARGET_SYSROOT)" "$$@"' > $(BUILD_WORK)/just/target-cc-wrapper
	printf '%s\n' '#!/bin/sh' 'exec "$(CXX)" -isysroot "$(TARGET_SYSROOT)" "$$@"' > $(BUILD_WORK)/just/target-cxx-wrapper
	chmod 755 $(BUILD_WORK)/just/target-cc-wrapper $(BUILD_WORK)/just/target-cxx-wrapper
	cd $(BUILD_WORK)/just && $(DEFAULT_RUST_FLAGS) \
		$(if $(filter iphoneos-arm64-roothide appletvos-arm64-roothide,$(MEMO_TARGET)),JUST_ROOT_HIDE=1) \
		CC="$(CC_FOR_BUILD)" CXX="$(CXX_FOR_BUILD)" \
		CC_$(subst -,_,$(RUST_TARGET))="$(BUILD_WORK)/just/target-cc-wrapper" \
		CXX_$(subst -,_,$(RUST_TARGET))="$(BUILD_WORK)/just/target-cxx-wrapper" \
		CFLAGS_$(subst -,_,$(RUST_TARGET))="$(CFLAGS)" CXXFLAGS_$(subst -,_,$(RUST_TARGET))="$(CXXFLAGS)" \
		CARGO_TARGET_$(subst -,_,$(shell echo $(RUST_TARGET) | tr '[:lower:]' '[:upper:]'))_LINKER="$(BUILD_WORK)/just/target-cc-wrapper" \
		CFLAGS= CXXFLAGS= RUSTFLAGS="-L $(BUILD_BASE)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib $(if $(filter iphoneos-arm64-roothide appletvos-arm64-roothide,$(MEMO_TARGET)),-C link-arg=-liosexec)" cargo build \
		--release \
		--locked \
		--all-features \
		--target=$(RUST_TARGET)
	$(INSTALL) -Dm755 $(BUILD_WORK)/just/target/$(RUST_TARGET)/release/just $(BUILD_STAGE)/just/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/just

	rm -rf $(BUILD_STAGE)/just/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/man1
	$(INSTALL) -Dm644 $(BUILD_WORK)/just/man/just.1 \
	    -t $(BUILD_STAGE)/just/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/man1
	$(INSTALL) -Dm644 $(BUILD_WORK)/just/completions/just.zsh \
	    $(BUILD_STAGE)/just/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/zsh/site-functions/_just
	$(INSTALL) -Dm644 $(BUILD_WORK)/just/completions/just.fish \
		$(BUILD_STAGE)/just/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/fish/vendor_completions.d/just.fish
	$(INSTALL) -Dm644 $(BUILD_WORK)/just/completions/just.bash \
	    $(BUILD_STAGE)/just/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/bash-completion/completions/just

	$(call AFTER_BUILD)
endif

just-package: just-stage
	# just.mk Package Structure
	rm -rf $(BUILD_DIST)/just

	# just.mk Prep just
	cp -a $(BUILD_STAGE)/just $(BUILD_DIST)

	# just.mk Sign
	$(call SIGN,just,general.xml)

	# just.mk Make .debs
	$(call PACK,just,DEB_JUST_V)

	# just.mk Build cleanup
	rm -rf $(BUILD_DIST)/just

.PHONY: just just-package
