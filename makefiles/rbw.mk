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

ifneq ($(wildcard $(BUILD_WORK)/rbw/.build_complete),)
rbw:
	@echo "Using previously built rbw."
else
rbw: rbw-setup
	$(call DO_PATCH,rbw,rbw,-p1)
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
		CFLAGS= CXXFLAGS= CPPFLAGS= ASFLAGS= LDFLAGS= RUSTFLAGS="-L $(BUILD_BASE)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib $(if $(filter iphoneos-arm64-roothide,$(MEMO_TARGET)),-C link-arg=-liosexec)" cargo build \
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
