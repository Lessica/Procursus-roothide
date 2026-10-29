ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS     += ripgrep
RIPGREP_VERSION := 12.1.1
DEB_RIPGREP_V   ?= $(RIPGREP_VERSION)-1

ripgrep-setup: setup
	$(call GITHUB_ARCHIVE,BurntSushi,ripgrep,$(RIPGREP_VERSION),$(RIPGREP_VERSION))
	$(call EXTRACT_TAR,ripgrep-$(RIPGREP_VERSION).tar.gz,ripgrep-$(RIPGREP_VERSION),ripgrep)
ifneq ($(filter appletvos%,$(MEMO_TARGET)),)
	$(call DO_PATCH,ripgrep-tvos,ripgrep,-p1)
endif

ifneq ($(wildcard $(BUILD_WORK)/ripgrep/.build_complete),)
ripgrep:
	@echo "Using previously built ripgrep."
else
ripgrep: ripgrep-setup pcre2
	printf '%s\n' '#!/bin/sh' 'exec "$(CC)" -isysroot "$(TARGET_SYSROOT)" "$$@"' > $(BUILD_WORK)/ripgrep/target-cc-wrapper
	printf '%s\n' '#!/bin/sh' 'exec "$(CXX)" -isysroot "$(TARGET_SYSROOT)" "$$@"' > $(BUILD_WORK)/ripgrep/target-cxx-wrapper
	chmod 755 $(BUILD_WORK)/ripgrep/target-cc-wrapper $(BUILD_WORK)/ripgrep/target-cxx-wrapper
	cd $(BUILD_WORK)/ripgrep && $(DEFAULT_RUST_FLAGS) \
		SDKROOT="$(MACOSX_SYSROOT)" \
		CC="$(CC_FOR_BUILD)" CXX="$(CXX_FOR_BUILD)" \
		CC_$(subst -,_,$(RUST_TARGET))="$(BUILD_WORK)/ripgrep/target-cc-wrapper" \
		CXX_$(subst -,_,$(RUST_TARGET))="$(BUILD_WORK)/ripgrep/target-cxx-wrapper" \
		CFLAGS_$(subst -,_,$(RUST_TARGET))="$(CFLAGS)" CXXFLAGS_$(subst -,_,$(RUST_TARGET))="$(CXXFLAGS)" \
		CARGO_TARGET_$(subst -,_,$(shell echo $(RUST_TARGET) | tr '[:lower:]' '[:upper:]'))_LINKER="$(BUILD_WORK)/ripgrep/target-cc-wrapper" \
		CFLAGS= CXXFLAGS= PKG_CONFIG=$(BUILD_TOOLS)/cross-pkg-config PKG_CONFIG_ALLOW_CROSS=1 cargo build \
		--release \
		--locked \
		--target=$(RUST_TARGET) \
		--features pcre2
	$(INSTALL) -Dm755 $(BUILD_WORK)/ripgrep/target/$(RUST_TARGET)/release/rg $(BUILD_STAGE)/ripgrep/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/rg
	$(INSTALL) -Dm644 $(BUILD_WORK)/ripgrep/complete/_rg $(BUILD_STAGE)/ripgrep/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/zsh/site-functions/_rg
	$(INSTALL) -Dm644 $(BUILD_WORK)/ripgrep/target/$(RUST_TARGET)/release/build/ripgrep-*/out/rg.bash $(BUILD_STAGE)/ripgrep/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/bash-completion/completions/rg
	$(call AFTER_BUILD)
endif

ripgrep-package: ripgrep-stage
	# ripgrep.mk Package Structure
	rm -rf $(BUILD_DIST)/ripgrep

	# ripgrep.mk Prep ripgrep
	cp -a $(BUILD_STAGE)/ripgrep $(BUILD_DIST)

	# ripgrep.mk Sign
	$(call SIGN,ripgrep,general.xml)

	# ripgrep.mk Make .debs
	$(call PACK,ripgrep,DEB_RIPGREP_V)

	# ripgrep.mk Build cleanup
	rm -rf $(BUILD_DIST)/ripgrep

.PHONY: ripgrep ripgrep-package
