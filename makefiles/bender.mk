ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

ifeq (,$(findstring darwin,$(MEMO_TARGET)))

SUBPROJECTS      += bender
BENDER_VERSION   := 1.1.1
DEB_BENDER_V     ?= $(BENDER_VERSION)

bender-setup: setup
	$(call GITHUB_ARCHIVE,Absolucy,bender,$(BENDER_VERSION),v$(BENDER_VERSION))
	$(call EXTRACT_TAR,bender-$(BENDER_VERSION).tar.gz,bender-$(BENDER_VERSION),bender)
	$(call DO_PATCH,bender,bender,-p1)

ifneq ($(wildcard $(BUILD_WORK)/bender/.build_complete),)
bender:
	@echo "Using previously built bender."
else
bender: bender-setup
	sed -e "24,25s|aspen.*/|dfrankland/|" -e "5s|aspen.*<.*>|Absolucy <lucy@absolucy.moe>|" -i $(BUILD_WORK)/bender/Cargo.toml
	printf '%s\n' '#!/bin/sh' 'exec "$(CC)" -isysroot "$(TARGET_SYSROOT)" "$$@"' > $(BUILD_WORK)/bender/target-cc-wrapper
	printf '%s\n' '#!/bin/sh' 'exec "$(CXX)" -isysroot "$(TARGET_SYSROOT)" "$$@"' > $(BUILD_WORK)/bender/target-cxx-wrapper
	chmod 755 $(BUILD_WORK)/bender/target-{cc,cxx}-wrapper
	cd $(BUILD_WORK)/bender && $(DEFAULT_RUST_FLAGS) \
		CC="$(CC_FOR_BUILD)" CXX="$(CXX_FOR_BUILD)" \
		CC_$(subst -,_,$(RUST_TARGET))="$(BUILD_WORK)/bender/target-cc-wrapper" \
		CXX_$(subst -,_,$(RUST_TARGET))="$(BUILD_WORK)/bender/target-cxx-wrapper" \
		CFLAGS_$(subst -,_,$(RUST_TARGET))="$(CFLAGS)" CXXFLAGS_$(subst -,_,$(RUST_TARGET))="$(CXXFLAGS)" \
		CARGO_TARGET_$(subst -,_,$(shell echo $(RUST_TARGET) | tr '[:lower:]' '[:upper:]'))_LINKER="$(BUILD_WORK)/bender/target-cc-wrapper" \
		CFLAGS= CXXFLAGS= cargo build \
		--release \
		--locked \
		--target=$(RUST_TARGET)
	$(INSTALL) -Dm755 $(BUILD_WORK)/bender/target/$(RUST_TARGET)/release/bender $(BUILD_STAGE)/bender/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/bender
	$(call AFTER_BUILD)
endif

bender-package: bender-stage
	# bender.mk Package Structure
	rm -rf $(BUILD_DIST)/bender

	# bender.mk Prep bender
	cp -a $(BUILD_STAGE)/bender $(BUILD_DIST)

	# bender.mk Sign
	$(call SIGN,bender,general.xml)

	# bender.mk Make .debs
	$(call PACK,bender,DEB_BENDER_V)

	# bender.mk Build cleanup
	rm -rf $(BUILD_DIST)/bender

.PHONY: bender bender-package

endif
