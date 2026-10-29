ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS        += hyperfine
HYPERFINE_VERSION  := 1.15.0
DEB_HYPERFINE_V    ?= $(HYPERFINE_VERSION)-1

hyperfine-setup: setup
	$(call GITHUB_ARCHIVE,sharkdp,hyperfine,$(HYPERFINE_VERSION),v$(HYPERFINE_VERSION))
	$(call EXTRACT_TAR,hyperfine-$(HYPERFINE_VERSION).tar.gz,hyperfine-$(HYPERFINE_VERSION),hyperfine)
ifneq ($(filter appletvos%,$(MEMO_TARGET)),)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/rand_os-0.1.3.crate,https://static.crates.io/crates/rand_os/rand_os-0.1.3.crate)
	$(call CHECKSUM_VERIFY,sha256,rand_os-0.1.3.crate,7b75f676a1e053fc562eafbb47838d67c84801e38fc1ba459e8f180deabd5071)
	$(call EXTRACT_TAR,rand_os-0.1.3.crate,rand_os-0.1.3,hyperfine-rand-os)
	$(call DO_PATCH,hyperfine-rand-os,hyperfine-rand-os,-p1)
	$(call DO_PATCH,hyperfine-tvos,hyperfine,-p1)
endif

ifneq ($(wildcard $(BUILD_WORK)/hyperfine/.build_complete),)
hyperfine:
	@echo "Using previously built hyperfine."
else
hyperfine: hyperfine-setup $(if $(filter appletvos-arm64-roothide,$(MEMO_TARGET)),libiosexec)
	printf '%s\n' '#!/bin/sh' 'exec "$(CC)" -isysroot "$(TARGET_SYSROOT)" "$$@"' > $(BUILD_WORK)/hyperfine/target-cc-wrapper
	printf '%s\n' '#!/bin/sh' 'exec "$(CXX)" -isysroot "$(TARGET_SYSROOT)" "$$@"' > $(BUILD_WORK)/hyperfine/target-cxx-wrapper
	chmod 755 $(BUILD_WORK)/hyperfine/target-cc-wrapper $(BUILD_WORK)/hyperfine/target-cxx-wrapper
	cd $(BUILD_WORK)/hyperfine && $(DEFAULT_RUST_FLAGS) \
		CC="$(CC_FOR_BUILD)" CXX="$(CXX_FOR_BUILD)" \
		CC_$(subst -,_,$(RUST_TARGET))="$(BUILD_WORK)/hyperfine/target-cc-wrapper" \
		CXX_$(subst -,_,$(RUST_TARGET))="$(BUILD_WORK)/hyperfine/target-cxx-wrapper" \
		CFLAGS_$(subst -,_,$(RUST_TARGET))="$(CFLAGS)" CXXFLAGS_$(subst -,_,$(RUST_TARGET))="$(CXXFLAGS)" \
		CARGO_TARGET_$(subst -,_,$(shell echo $(RUST_TARGET) | tr '[:lower:]' '[:upper:]'))_LINKER="$(BUILD_WORK)/hyperfine/target-cc-wrapper" \
		CFLAGS= CXXFLAGS= $(if $(filter appletvos-arm64-roothide,$(MEMO_TARGET)),RUSTFLAGS="-L $(BUILD_BASE)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib -C link-arg=-liosexec") cargo build \
		--release \
		--locked \
		--all-features \
		--target=$(RUST_TARGET)
	$(INSTALL) -Dm755 $(BUILD_WORK)/hyperfine/target/$(RUST_TARGET)/release/hyperfine $(BUILD_STAGE)/hyperfine/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/hyperfine
	$(INSTALL) -Dm644 $(BUILD_WORK)/hyperfine/target/$(RUST_TARGET)/release/build/hyperfine-*/out/hyperfine.bash $(BUILD_STAGE)/hyperfine/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/bash-completion/completions/hyperfine
	$(INSTALL) -Dm644 $(BUILD_WORK)/hyperfine/target/$(RUST_TARGET)/release/build/hyperfine-*/out/hyperfine.fish $(BUILD_STAGE)/hyperfine/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/fish/vendor_completions.d/hyperfine.fish
	$(INSTALL) -Dm644 $(BUILD_WORK)/hyperfine/target/$(RUST_TARGET)/release/build/hyperfine-*/out/_hyperfine $(BUILD_STAGE)/hyperfine/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/zsh/site-functions/_hyperfine
	$(call AFTER_BUILD)
endif

hyperfine-package: hyperfine-stage
	# hyperfine.mk Package Structure
	rm -rf $(BUILD_DIST)/hyperfine

	# hyperfine.mk Prep hyperfine
	cp -a $(BUILD_STAGE)/hyperfine $(BUILD_DIST)

	# hyperfine.mk Sign
	$(call SIGN,hyperfine,general.xml)

	# hyperfine.mk Make .debs
	$(call PACK,hyperfine,DEB_HYPERFINE_V)

	# hyperfine.mk Build cleanup
	rm -rf $(BUILD_DIST)/hyperfine

.PHONY: hyperfine hyperfine-package
