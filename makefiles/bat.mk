ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS += bat
BAT_VERSION := 0.21.0
DEB_BAT_V   ?= $(BAT_VERSION)-1

bat-setup: setup
	$(call GITHUB_ARCHIVE,sharkdp,bat,$(BAT_VERSION),v$(BAT_VERSION))
	$(call EXTRACT_TAR,bat-$(BAT_VERSION).tar.gz,bat-$(BAT_VERSION),bat)
#	Remove after https://github.com/rust-lang/git2-rs/pull/859 is merged.
#	If said pull request is denied, move to maintaining fork from upstream.
	$(call DO_PATCH,bat,bat,-p1)
ifneq ($(filter appletvos%,$(MEMO_TARGET)),)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/sys-info-0.9.1.crate,https://static.crates.io/crates/sys-info/sys-info-0.9.1.crate)
	$(call CHECKSUM_VERIFY,sha256,sys-info-0.9.1.crate,0b3a0d0aba8bf96a0e1ddfdc352fc53b3df7f39318c71854910c3c4b024ae52c)
	$(call EXTRACT_TAR,sys-info-0.9.1.crate,sys-info-0.9.1,bat-sys-info)
	$(call DO_PATCH,bat-sys-info,bat-sys-info,-p1)
	$(call DO_PATCH,bat-tvos,bat,-p1)
endif

ifneq ($(wildcard $(BUILD_WORK)/bat/.build_complete),)
bat:
	@echo "Using previously built bat."
else
bat: bat-setup libgit2
	printf '%s\n' '#!/bin/sh' 'exec "$(CC)" -isysroot "$(TARGET_SYSROOT)" "$$@"' > $(BUILD_WORK)/bat/target-cc-wrapper
	printf '%s\n' '#!/bin/sh' 'exec "$(CXX)" -isysroot "$(TARGET_SYSROOT)" "$$@"' > $(BUILD_WORK)/bat/target-cxx-wrapper
	chmod 755 $(BUILD_WORK)/bat/target-cc-wrapper $(BUILD_WORK)/bat/target-cxx-wrapper
	cd $(BUILD_WORK)/bat && $(DEFAULT_RUST_FLAGS) \
		SDKROOT="$(MACOSX_SYSROOT)" \
		CC="$(CC_FOR_BUILD)" CXX="$(CXX_FOR_BUILD)" \
		CC_$(subst -,_,$(RUST_TARGET))="$(BUILD_WORK)/bat/target-cc-wrapper" \
		CXX_$(subst -,_,$(RUST_TARGET))="$(BUILD_WORK)/bat/target-cxx-wrapper" \
		CFLAGS_$(subst -,_,$(RUST_TARGET))="$(CFLAGS) -include stdio.h" CXXFLAGS_$(subst -,_,$(RUST_TARGET))="$(CXXFLAGS)" \
		CARGO_TARGET_$(subst -,_,$(shell echo $(RUST_TARGET) | tr '[:lower:]' '[:upper:]'))_LINKER="$(BUILD_WORK)/bat/target-cc-wrapper" \
		CFLAGS= CXXFLAGS= RUSTFLAGS="-L $(BUILD_BASE)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib -C link-arg=-liosexec" cargo build \
		--release \
		--locked \
		--target=$(RUST_TARGET)
	$(INSTALL) -Dm755 $(BUILD_WORK)/bat/target/$(RUST_TARGET)/release/bat $(BUILD_STAGE)/bat/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/bat
	sed -e 's/{{PROJECT_NAME}}/bat/g' -e 's/{{PROJECT_EXECUTABLE}}/bat/g' -e 's/{{PROJECT_EXECUTABLE_UPPERCASE}}/BAT/g' -e 's/{{PROJECT_VERSION}}/$(BAT_VERSION)/g' \
		$(BUILD_WORK)/bat/assets/manual/bat.1.in > $(BUILD_WORK)/bat/generated-bat.1
	$(INSTALL) -Dm644 $(BUILD_WORK)/bat/generated-bat.1 \
		$(BUILD_STAGE)/bat/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/man1/bat.1
	sed -e 's/{{PROJECT_NAME}}/bat/g' -e 's/{{PROJECT_EXECUTABLE}}/bat/g' -e 's/{{PROJECT_EXECUTABLE_UPPERCASE}}/BAT/g' -e 's/{{PROJECT_VERSION}}/$(BAT_VERSION)/g' \
		$(BUILD_WORK)/bat/assets/completions/bat.zsh.in > $(BUILD_WORK)/bat/generated-bat.zsh
	$(INSTALL) -Dm644 $(BUILD_WORK)/bat/generated-bat.zsh \
		$(BUILD_STAGE)/bat/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/zsh/site-functions/_bat
	$(call AFTER_BUILD)
endif

bat-package: bat-stage
	# bat.mk Package Structure
	rm -rf $(BUILD_DIST)/bat

	# bat.mk Prep bat
	cp -a $(BUILD_STAGE)/bat $(BUILD_DIST)

	# bat.mk Sign
	$(call SIGN,bat,general.xml)

	# bat.mk Make .debs
	$(call PACK,bat,DEB_BAT_V)

	# bat.mk Build cleanup
	rm -rf $(BUILD_DIST)/bat

.PHONY: bat bat-package
