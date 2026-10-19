ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS        += hyperfine
HYPERFINE_VERSION  := 1.15.0
DEB_HYPERFINE_V    ?= $(HYPERFINE_VERSION)

hyperfine-setup: setup
	$(call GITHUB_ARCHIVE,sharkdp,hyperfine,$(HYPERFINE_VERSION),v$(HYPERFINE_VERSION))
	$(call EXTRACT_TAR,hyperfine-$(HYPERFINE_VERSION).tar.gz,hyperfine-$(HYPERFINE_VERSION),hyperfine)

ifneq ($(wildcard $(BUILD_WORK)/hyperfine/.build_complete),)
hyperfine:
	@echo "Using previously built hyperfine."
else
hyperfine: hyperfine-setup
	printf '%s\n' '#!/bin/sh' 'exec "$(CC)" -isysroot "$(TARGET_SYSROOT)" "$$@"' > $(BUILD_WORK)/hyperfine/target-cc-wrapper
	printf '%s\n' '#!/bin/sh' 'exec "$(CXX)" -isysroot "$(TARGET_SYSROOT)" "$$@"' > $(BUILD_WORK)/hyperfine/target-cxx-wrapper
	chmod 755 $(BUILD_WORK)/hyperfine/target-cc-wrapper $(BUILD_WORK)/hyperfine/target-cxx-wrapper
	cd $(BUILD_WORK)/hyperfine && $(DEFAULT_RUST_FLAGS) \
		SDKROOT="$(MACOSX_SYSROOT)" \
		CC="$(CC_FOR_BUILD)" CXX="$(CXX_FOR_BUILD)" \
		CC_$(subst -,_,$(RUST_TARGET))="$(BUILD_WORK)/hyperfine/target-cc-wrapper" \
		CXX_$(subst -,_,$(RUST_TARGET))="$(BUILD_WORK)/hyperfine/target-cxx-wrapper" \
		CFLAGS_$(subst -,_,$(RUST_TARGET))="$(CFLAGS)" CXXFLAGS_$(subst -,_,$(RUST_TARGET))="$(CXXFLAGS)" \
		CARGO_TARGET_$(subst -,_,$(shell echo $(RUST_TARGET) | tr '[:lower:]' '[:upper:]'))_LINKER="$(BUILD_WORK)/hyperfine/target-cc-wrapper" \
		CFLAGS= CXXFLAGS= cargo build \
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
