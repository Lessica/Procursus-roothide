ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS   += dust
DUST_VERSION  := 0.7.5
DEB_DUST_V    ?= $(DUST_VERSION)

dust-setup: setup
	$(call GITHUB_ARCHIVE,bootandy,dust,$(DUST_VERSION),v$(DUST_VERSION))
	$(call EXTRACT_TAR,dust-$(DUST_VERSION).tar.gz,dust-$(DUST_VERSION),dust)
ifneq ($(filter appletvos%,$(MEMO_TARGET)),)
	$(call DO_PATCH,dust-tvos,dust,-p1)
endif

ifneq ($(wildcard $(BUILD_WORK)/dust/.build_complete),)
dust:
	@echo "Using previously built dust."
else
dust: dust-setup
	printf '%s\n' '#!/bin/sh' 'exec "$(CC)" -isysroot "$(TARGET_SYSROOT)" "$$@"' > $(BUILD_WORK)/dust/target-cc-wrapper
	printf '%s\n' '#!/bin/sh' 'exec "$(CXX)" -isysroot "$(TARGET_SYSROOT)" "$$@"' > $(BUILD_WORK)/dust/target-cxx-wrapper
	chmod 755 $(BUILD_WORK)/dust/target-cc-wrapper $(BUILD_WORK)/dust/target-cxx-wrapper
	cd $(BUILD_WORK)/dust && $(DEFAULT_RUST_FLAGS) \
		SDKROOT="$(MACOSX_SYSROOT)" \
		CC="$(CC_FOR_BUILD)" CXX="$(CXX_FOR_BUILD)" \
		CC_$(subst -,_,$(RUST_TARGET))="$(BUILD_WORK)/dust/target-cc-wrapper" \
		CXX_$(subst -,_,$(RUST_TARGET))="$(BUILD_WORK)/dust/target-cxx-wrapper" \
		CFLAGS_$(subst -,_,$(RUST_TARGET))="$(CFLAGS)" CXXFLAGS_$(subst -,_,$(RUST_TARGET))="$(CXXFLAGS)" \
		CARGO_TARGET_$(subst -,_,$(shell echo $(RUST_TARGET) | tr '[:lower:]' '[:upper:]'))_LINKER="$(BUILD_WORK)/dust/target-cc-wrapper" \
		CFLAGS= CXXFLAGS= RUSTFLAGS="-L $(BUILD_BASE)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib $(if $(filter iphoneos-arm64-roothide appletvos-arm64-roothide,$(MEMO_TARGET)),-C link-arg=-liosexec)" cargo build \
		--release \
		--locked \
		--all-features \
		--target=$(RUST_TARGET)
	$(INSTALL) -Dm755 $(BUILD_WORK)/dust/target/$(RUST_TARGET)/release/dust $(BUILD_STAGE)/dust/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/dust
	$(call AFTER_BUILD)
endif

dust-package: dust-stage
	# dust.mk Package Structure
	rm -rf $(BUILD_DIST)/dust

	# dust.mk Prep dust
	cp -a $(BUILD_STAGE)/dust $(BUILD_DIST)

	# dust.mk Sign
	$(call SIGN,dust,general.xml)

	# dust.mk Make .debs
	$(call PACK,dust,DEB_DUST_V)

	# dust.mk Build cleanup
	rm -rf $(BUILD_DIST)/dust

.PHONY: dust dust-package
