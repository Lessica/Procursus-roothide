ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS += lsd
LSD_VERSION := 0.23.1
DEB_LSD_V   ?= $(LSD_VERSION)

lsd-setup: setup
	$(call GITHUB_ARCHIVE,Peltoche,lsd,$(LSD_VERSION),$(LSD_VERSION))
	$(call EXTRACT_TAR,lsd-$(LSD_VERSION).tar.gz,lsd-$(LSD_VERSION),lsd)
	$(call DO_PATCH,lsd,lsd,-p1)

ifneq ($(wildcard $(BUILD_WORK)/lsd/.build_complete),)
lsd:
	@echo "Using previously built lsd."
else
lsd: lsd-setup
	printf '%s\n' '#!/bin/sh' 'exec "$(CC)" -isysroot "$(TARGET_SYSROOT)" "$$@"' > $(BUILD_WORK)/lsd/target-cc-wrapper
	printf '%s\n' '#!/bin/sh' 'exec "$(CXX)" -isysroot "$(TARGET_SYSROOT)" "$$@"' > $(BUILD_WORK)/lsd/target-cxx-wrapper
	chmod 755 $(BUILD_WORK)/lsd/target-cc-wrapper $(BUILD_WORK)/lsd/target-cxx-wrapper
	cd $(BUILD_WORK)/lsd && $(DEFAULT_RUST_FLAGS) \
		SDKROOT="$(MACOSX_SYSROOT)" \
		CC="$(CC_FOR_BUILD)" CXX="$(CXX_FOR_BUILD)" \
		CC_$(subst -,_,$(RUST_TARGET))="$(BUILD_WORK)/lsd/target-cc-wrapper" \
		CXX_$(subst -,_,$(RUST_TARGET))="$(BUILD_WORK)/lsd/target-cxx-wrapper" \
		CFLAGS_$(subst -,_,$(RUST_TARGET))="$(CFLAGS)" CXXFLAGS_$(subst -,_,$(RUST_TARGET))="$(CXXFLAGS)" \
		CARGO_TARGET_$(subst -,_,$(shell echo $(RUST_TARGET) | tr '[:lower:]' '[:upper:]'))_LINKER="$(BUILD_WORK)/lsd/target-cc-wrapper" \
		CFLAGS= CXXFLAGS= RUSTFLAGS="-L $(BUILD_BASE)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib $(if $(filter iphoneos-arm64-roothide,$(MEMO_TARGET)),-C link-arg=-liosexec)" cargo build \
		--release \
		--locked \
		--target=$(RUST_TARGET)
	$(INSTALL) -Dm755 $(BUILD_WORK)/lsd/target/$(RUST_TARGET)/release/lsd \
		$(BUILD_STAGE)/lsd/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/lsd
	$(call AFTER_BUILD)
endif

lsd-package: lsd-stage
	# lsd.mk Package Structure
	rm -rf $(BUILD_DIST)/lsd
	cp -a $(BUILD_STAGE)/lsd $(BUILD_DIST)

	# lsd.mk Sign
	$(call SIGN,lsd,general.xml)

	# lsd.mk Make .debs
	$(call PACK,lsd,DEB_LSD_V)

	# lsd.mk Build Cleanup
	rm -rf $(BUILD_DIST)/lsd

.PHONY: lsd lsd-package
