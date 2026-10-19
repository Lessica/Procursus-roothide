ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS   += just
JUST_VERSION  := 1.13.0
DEB_JUST_V    ?= $(JUST_VERSION)-1

just-setup: setup
	$(call GITHUB_ARCHIVE,casey,just,$(JUST_VERSION),$(JUST_VERSION))
	$(call EXTRACT_TAR,just-$(JUST_VERSION).tar.gz,just-$(JUST_VERSION),just)
	$(call DO_PATCH,just,just,-p1)

ifneq ($(wildcard $(BUILD_WORK)/just/.build_complete),)
just:
	@echo "Using previously built just."
else
just: just-setup
	printf '%s\n' '#!/bin/sh' 'exec "$(CC)" -isysroot "$(TARGET_SYSROOT)" "$$@"' > $(BUILD_WORK)/just/target-cc-wrapper
	printf '%s\n' '#!/bin/sh' 'exec "$(CXX)" -isysroot "$(TARGET_SYSROOT)" "$$@"' > $(BUILD_WORK)/just/target-cxx-wrapper
	chmod 755 $(BUILD_WORK)/just/target-cc-wrapper $(BUILD_WORK)/just/target-cxx-wrapper
	cd $(BUILD_WORK)/just && $(DEFAULT_RUST_FLAGS) \
		$(if $(filter iphoneos-arm64-roothide,$(MEMO_TARGET)),JUST_ROOT_HIDE=1) \
		SDKROOT="$(MACOSX_SYSROOT)" \
		CC="$(CC_FOR_BUILD)" CXX="$(CXX_FOR_BUILD)" \
		CC_$(subst -,_,$(RUST_TARGET))="$(BUILD_WORK)/just/target-cc-wrapper" \
		CXX_$(subst -,_,$(RUST_TARGET))="$(BUILD_WORK)/just/target-cxx-wrapper" \
		CFLAGS_$(subst -,_,$(RUST_TARGET))="$(CFLAGS)" CXXFLAGS_$(subst -,_,$(RUST_TARGET))="$(CXXFLAGS)" \
		CARGO_TARGET_$(subst -,_,$(shell echo $(RUST_TARGET) | tr '[:lower:]' '[:upper:]'))_LINKER="$(BUILD_WORK)/just/target-cc-wrapper" \
		CFLAGS= CXXFLAGS= RUSTFLAGS="-L $(BUILD_BASE)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib $(if $(filter iphoneos-arm64-roothide,$(MEMO_TARGET)),-C link-arg=-liosexec)" cargo build \
		--release \
		--locked \
		--all-features \
		--target=$(RUST_TARGET)
	$(INSTALL) -Dm755 $(BUILD_WORK)/just/target/$(RUST_TARGET)/release/just $(BUILD_STAGE)/just/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/just

	rm -rf $(BUILD_STAGE)/just/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/man1
	$(INSTALL) -Dm644 $(BUILD_WORK)/just/man/just.1 \
	    -t $(BUILD_STAGE)/just/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/man1
	$(INSTALL) -Dm644 $(BUILD_WORK)/just/completions/just.zsh \
	    $(BUILD_STAGE)/just/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/zsh/site-functions/_just
	$(INSTALL) -Dm644 $(BUILD_WORK)/just/completions/just.fish \
		$(BUILD_STAGE)/just/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/fish/vendor_completions.d/just.fish
	$(INSTALL) -Dm644 $(BUILD_WORK)/just/completions/just.bash \
	    $(BUILD_STAGE)/just/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/bash-completion/completions/just

	$(call AFTER_BUILD)
endif

just-package: just-stage
	# just.mk Package Structure
	rm -rf $(BUILD_DIST)/just

	# just.mk Prep just
	cp -a $(BUILD_STAGE)/just $(BUILD_DIST)

	# just.mk Sign
	$(call SIGN,just,general.xml)

	# just.mk Make .debs
	$(call PACK,just,DEB_JUST_V)

	# just.mk Build cleanup
	rm -rf $(BUILD_DIST)/just

.PHONY: just just-package
