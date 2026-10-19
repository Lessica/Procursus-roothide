ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS += exa
EXA_VERSION := 0.10.1
DEB_EXA_V   ?= $(EXA_VERSION)

exa-setup: setup
	$(call GITHUB_ARCHIVE,ogham,exa,$(EXA_VERSION),v$(EXA_VERSION))
	$(call EXTRACT_TAR,exa-$(EXA_VERSION).tar.gz,exa-$(EXA_VERSION),exa)
	$(call DO_PATCH,exa,exa,-p1)

ifneq ($(wildcard $(BUILD_WORK)/exa/.build_complete),)
exa:
	@echo "Using previously built exa."
else
exa: exa-setup
	printf '%s\n' '#!/bin/sh' 'exec "$(CC)" -isysroot "$(TARGET_SYSROOT)" "$$@"' > $(BUILD_WORK)/exa/target-cc-wrapper
	printf '%s\n' '#!/bin/sh' 'exec "$(CXX)" -isysroot "$(TARGET_SYSROOT)" "$$@"' > $(BUILD_WORK)/exa/target-cxx-wrapper
	chmod 755 $(BUILD_WORK)/exa/target-cc-wrapper $(BUILD_WORK)/exa/target-cxx-wrapper
	cd $(BUILD_WORK)/exa && $(DEFAULT_RUST_FLAGS) \
		SDKROOT="$(MACOSX_SYSROOT)" \
		CC="$(CC_FOR_BUILD)" CXX="$(CXX_FOR_BUILD)" \
		CC_$(subst -,_,$(RUST_TARGET))="$(BUILD_WORK)/exa/target-cc-wrapper" \
		CXX_$(subst -,_,$(RUST_TARGET))="$(BUILD_WORK)/exa/target-cxx-wrapper" \
		CFLAGS_$(subst -,_,$(RUST_TARGET))="$(CFLAGS)" CXXFLAGS_$(subst -,_,$(RUST_TARGET))="$(CXXFLAGS)" \
		CARGO_TARGET_$(subst -,_,$(shell echo $(RUST_TARGET) | tr '[:lower:]' '[:upper:]'))_LINKER="$(BUILD_WORK)/exa/target-cc-wrapper" \
		CFLAGS= CXXFLAGS= RUSTFLAGS="-L $(BUILD_BASE)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib $(if $(filter iphoneos-arm64-roothide,$(MEMO_TARGET)),-C link-arg=-liosexec)" cargo build \
		--release \
		--locked \
		--no-default-features \
		--target=$(RUST_TARGET)
	$(INSTALL) -Dm755 $(BUILD_WORK)/exa/target/$(RUST_TARGET)/release/exa \
		$(BUILD_STAGE)/exa/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/exa
	$(call AFTER_BUILD)
endif

exa-package: exa-stage
	# exa.mk Package Structure
	mkdir -p $(BUILD_DIST)/exa
	cp -a $(BUILD_STAGE)/exa $(BUILD_DIST)

	# exa.mk Sign
	$(call SIGN,exa,general.xml)

	# exa.mk Make .debs
	$(call PACK,exa,DEB_EXA_V)

	# exa.mk Build Cleanup
	rm -rf $(BUILD_DIST)/exa

.PHONY: exa exa-package
