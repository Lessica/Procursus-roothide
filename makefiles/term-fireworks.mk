ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS            += term-fireworks
TERM-FIREWORKS_VERSION := 1.0.4
DEB_TERM-FIREWORKS_V   ?= $(TERM-FIREWORKS_VERSION)

term-fireworks-setup: setup
	$(call DOWNLOAD_FILES,$(BUILD_SOURCE),https://gitlab.com/DarrienG/term-fireworks/-/archive/v$(TERM-FIREWORKS_VERSION)/term-fireworks-v$(TERM-FIREWORKS_VERSION).tar.bz2)
	$(call EXTRACT_TAR,term-fireworks-v$(TERM-FIREWORKS_VERSION).tar.bz2,term-fireworks-v$(TERM-FIREWORKS_VERSION),term-fireworks)
	$(call DO_PATCH,term-fireworks,term-fireworks,-p1)

ifneq ($(wildcard $(BUILD_WORK)/term-fireworks/.build_complete),)
term-fireworks:
	@echo "Using previously built term-fireworks."
else
term-fireworks: term-fireworks-setup
	printf '%s\n' '#!/bin/sh' 'exec "$(CC)" -isysroot "$(TARGET_SYSROOT)" "$$@"' > $(BUILD_WORK)/term-fireworks/target-cc-wrapper
	printf '%s\n' '#!/bin/sh' 'exec "$(CXX)" -isysroot "$(TARGET_SYSROOT)" "$$@"' > $(BUILD_WORK)/term-fireworks/target-cxx-wrapper
	chmod 755 $(BUILD_WORK)/term-fireworks/target-cc-wrapper $(BUILD_WORK)/term-fireworks/target-cxx-wrapper
	cd $(BUILD_WORK)/term-fireworks && $(DEFAULT_RUST_FLAGS) \
		SDKROOT="$(MACOSX_SYSROOT)" \
		CC="$(CC_FOR_BUILD)" CXX="$(CXX_FOR_BUILD)" \
		CC_$(subst -,_,$(RUST_TARGET))="$(BUILD_WORK)/term-fireworks/target-cc-wrapper" \
		CXX_$(subst -,_,$(RUST_TARGET))="$(BUILD_WORK)/term-fireworks/target-cxx-wrapper" \
		CFLAGS_$(subst -,_,$(RUST_TARGET))="$(CFLAGS)" CXXFLAGS_$(subst -,_,$(RUST_TARGET))="$(CXXFLAGS)" \
		CARGO_TARGET_$(subst -,_,$(shell echo $(RUST_TARGET) | tr '[:lower:]' '[:upper:]'))_LINKER="$(BUILD_WORK)/term-fireworks/target-cc-wrapper" \
		CFLAGS= CXXFLAGS= cargo build \
		--release \
		--locked \
		--target=$(RUST_TARGET)
	$(INSTALL) -Dm775 $(BUILD_WORK)/term-fireworks/target/$(RUST_TARGET)/release/fireworks \
		$(BUILD_STAGE)/term-fireworks/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/fireworks
	$(call AFTER_BUILD)
endif

term-fireworks-package: term-fireworks-stage
	# term-fireworks.mk Package Structure
	rm -rf $(BUILD_DIST)/term-fireworks

	# term-fireworks.mk Prep term-fireworks
	cp -a $(BUILD_STAGE)/term-fireworks $(BUILD_DIST)

	# term-fireworks.mk Sign
	$(call SIGN,term-fireworks,general.xml)

	# term-fireworks.mk Make .debs
	$(call PACK,term-fireworks,DEB_TERM-FIREWORKS_V)

	# term-fireworks.mk Build cleanup
	rm -rf $(BUILD_DIST)/term-fireworks

.PHONY: term-fireworks term-fireworks-package
