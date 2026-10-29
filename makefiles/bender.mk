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
ifneq ($(filter appletvos%,$(MEMO_TARGET)),)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/block-0.1.6.crate,https://static.crates.io/crates/block/block-0.1.6.crate)
	$(call CHECKSUM_VERIFY,sha256,block-0.1.6.crate,0d8c1fef690941d3e7788d328517591fecc684c084084702d6ff1641e993699a)
	$(call EXTRACT_TAR,block-0.1.6.crate,block-0.1.6,bender-block)
	$(call DO_PATCH,bender-block,bender-block,-p1)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/objc-0.2.7.crate,https://static.crates.io/crates/objc/objc-0.2.7.crate)
	$(call CHECKSUM_VERIFY,sha256,objc-0.2.7.crate,915b1b472bc21c53464d6c8461c9d3af805ba1ef837e1cac254428f4a77177b1)
	$(call EXTRACT_TAR,objc-0.2.7.crate,objc-0.2.7,bender-objc)
	$(call DO_PATCH,bender-objc,bender-objc,-p1)
	$(call DO_PATCH,bender-tvos,bender,-p1)
endif

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
		BINDGEN_EXTRA_CLANG_ARGS="--target=$(RUST_TARGET) $(CPPFLAGS)" \
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
