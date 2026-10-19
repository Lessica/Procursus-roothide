ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS     += choose
CHOOSE_VERSION  := 1.3.3
DEB_CHOOSE_V    ?= $(CHOOSE_VERSION)

choose-setup: setup
	$(call GITHUB_ARCHIVE,theryangeary,choose,$(CHOOSE_VERSION),v$(CHOOSE_VERSION))
	$(call EXTRACT_TAR,choose-$(CHOOSE_VERSION).tar.gz,choose-$(CHOOSE_VERSION),choose)

ifneq ($(wildcard $(BUILD_WORK)/choose/.build_complete),)
choose:
	@echo "Using previously built choose."
else
choose: choose-setup
	printf '%s\n' '#!/bin/sh' 'exec "$(CC)" -isysroot "$(TARGET_SYSROOT)" "$$@"' > $(BUILD_WORK)/choose/target-cc-wrapper
	printf '%s\n' '#!/bin/sh' 'exec "$(CXX)" -isysroot "$(TARGET_SYSROOT)" "$$@"' > $(BUILD_WORK)/choose/target-cxx-wrapper
	chmod 755 $(BUILD_WORK)/choose/target-cc-wrapper $(BUILD_WORK)/choose/target-cxx-wrapper
	cd $(BUILD_WORK)/choose && $(DEFAULT_RUST_FLAGS) \
		SDKROOT="$(MACOSX_SYSROOT)" \
		CC="$(CC_FOR_BUILD)" CXX="$(CXX_FOR_BUILD)" \
		CC_$(subst -,_,$(RUST_TARGET))="$(BUILD_WORK)/choose/target-cc-wrapper" \
		CXX_$(subst -,_,$(RUST_TARGET))="$(BUILD_WORK)/choose/target-cxx-wrapper" \
		CFLAGS_$(subst -,_,$(RUST_TARGET))="$(CFLAGS)" CXXFLAGS_$(subst -,_,$(RUST_TARGET))="$(CXXFLAGS)" \
		CARGO_TARGET_$(subst -,_,$(shell echo $(RUST_TARGET) | tr '[:lower:]' '[:upper:]'))_LINKER="$(BUILD_WORK)/choose/target-cc-wrapper" \
		CFLAGS= CXXFLAGS= cargo build \
		--release \
		--locked \
		--all-features \
		--target=$(RUST_TARGET)
	$(INSTALL) -Dm755 $(BUILD_WORK)/choose/target/$(RUST_TARGET)/release/choose $(BUILD_STAGE)/choose/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/choose
	$(call AFTER_BUILD)
endif

choose-package: choose-stage
	# choose.mk Package Structure
	rm -rf $(BUILD_DIST)/choose

	# choose.mk Prep choose
	cp -a $(BUILD_STAGE)/choose $(BUILD_DIST)

	# choose.mk Sign
	$(call SIGN,choose,general.xml)

	# choose.mk Make .debs
	$(call PACK,choose,DEB_CHOOSE_V)

	# choose.mk Build cleanup
	rm -rf $(BUILD_DIST)/choose

.PHONY: choose choose-package
