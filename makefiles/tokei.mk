ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS    += tokei
TOKEI_VERSION  := 12.1.2
DEB_TOKEI_V    ?= $(TOKEI_VERSION)

tokei-setup: setup
	$(call GITHUB_ARCHIVE,XAMPPRocky,tokei,$(TOKEI_VERSION),v$(TOKEI_VERSION))
	$(call EXTRACT_TAR,tokei-$(TOKEI_VERSION).tar.gz,tokei-$(TOKEI_VERSION),tokei)

ifneq ($(wildcard $(BUILD_WORK)/tokei/.build_complete),)
tokei:
	@echo "Using previously built tokei."
else
tokei: tokei-setup
	printf '%s\n' '#!/bin/sh' 'exec "$(CC)" -isysroot "$(TARGET_SYSROOT)" "$$@"' > $(BUILD_WORK)/tokei/target-cc-wrapper
	printf '%s\n' '#!/bin/sh' 'exec "$(CXX)" -isysroot "$(TARGET_SYSROOT)" "$$@"' > $(BUILD_WORK)/tokei/target-cxx-wrapper
	chmod 755 $(BUILD_WORK)/tokei/target-cc-wrapper $(BUILD_WORK)/tokei/target-cxx-wrapper
	cd $(BUILD_WORK)/tokei && $(DEFAULT_RUST_FLAGS) \
		SDKROOT="$(MACOSX_SYSROOT)" \
		CC="$(CC_FOR_BUILD)" CXX="$(CXX_FOR_BUILD)" \
		CC_$(subst -,_,$(RUST_TARGET))="$(BUILD_WORK)/tokei/target-cc-wrapper" \
		CXX_$(subst -,_,$(RUST_TARGET))="$(BUILD_WORK)/tokei/target-cxx-wrapper" \
		CFLAGS_$(subst -,_,$(RUST_TARGET))="$(CFLAGS)" CXXFLAGS_$(subst -,_,$(RUST_TARGET))="$(CXXFLAGS)" \
		CARGO_TARGET_$(subst -,_,$(shell echo $(RUST_TARGET) | tr '[:lower:]' '[:upper:]'))_LINKER="$(BUILD_WORK)/tokei/target-cc-wrapper" \
		CFLAGS= CXXFLAGS= RUSTFLAGS="-L $(BUILD_BASE)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib $(if $(filter iphoneos-arm64-roothide,$(MEMO_TARGET)),-C link-arg=-liosexec)" cargo build \
		--release \
		--locked \
		--all-features \
		--target=$(RUST_TARGET)
	$(INSTALL) -Dm755 $(BUILD_WORK)/tokei/target/$(RUST_TARGET)/release/tokei $(BUILD_STAGE)/tokei/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/tokei
	$(call AFTER_BUILD)
endif

tokei-package: tokei-stage
	# tokei.mk Package Structure
	rm -rf $(BUILD_DIST)/tokei

	# tokei.mk Prep tokei
	cp -a $(BUILD_STAGE)/tokei $(BUILD_DIST)

	# tokei.mk Sign
	$(call SIGN,tokei,general.xml)

	# tokei.mk Make .debs
	$(call PACK,tokei,DEB_TOKEI_V)

	# tokei.mk Build cleanup
	rm -rf $(BUILD_DIST)/tokei

.PHONY: tokei tokei-package
