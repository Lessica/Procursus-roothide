ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS      += starship
STARSHIP_VERSION := 0.53.0
DEB_STARSHIP_V   ?= $(STARSHIP_VERSION)

starship-setup: setup
	$(call GITHUB_ARCHIVE,starship,starship,$(STARSHIP_VERSION),v$(STARSHIP_VERSION))
	$(call EXTRACT_TAR,starship-$(STARSHIP_VERSION).tar.gz,starship-$(STARSHIP_VERSION),starship)
	# remove this when the following upstream PRs are merged:
	#  https://github.com/FillZpp/sys-info-rs/pull/88
	$(call DO_PATCH,starship,starship,-p1)

ifneq ($(wildcard $(BUILD_WORK)/starship/.build_complete),)
starship:
	@echo "Using previously built starship."
else
starship: starship-setup $(if $(filter iphoneos-arm64-roothide,$(MEMO_TARGET)),libiosexec)
	printf '%s\n' '#!/bin/sh' 'exec "$(CC)" -isysroot "$(TARGET_SYSROOT)" "$$@"' > $(BUILD_WORK)/starship/target-cc-wrapper
	printf '%s\n' '#!/bin/sh' 'exec "$(CXX)" -isysroot "$(TARGET_SYSROOT)" "$$@"' > $(BUILD_WORK)/starship/target-cxx-wrapper
	chmod 755 $(BUILD_WORK)/starship/target-cc-wrapper $(BUILD_WORK)/starship/target-cxx-wrapper
	# pkg-config 0.3.19 selects host/target search paths, but not executables.
	cd $(BUILD_WORK)/starship && $(DEFAULT_RUST_FLAGS) \
		PKG_CONFIG=pkg-config TARGET_PKG_CONFIG_PATH= \
		TARGET_PKG_CONFIG_LIBDIR="$(BUILD_BASE)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/pkgconfig:$(BUILD_BASE)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)$(MEMO_ALT_PREFIX)/lib/pkgconfig:$(BUILD_BASE)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/pkgconfig" \
		TARGET_PKG_CONFIG_SYSROOT_DIR="$(BUILD_BASE)" \
		SDKROOT="$(MACOSX_SYSROOT)" \
		CC="$(CC_FOR_BUILD)" CXX="$(CXX_FOR_BUILD)" \
		AR="$(AR_FOR_BUILD)" RANLIB="$(RANLIB_FOR_BUILD)" \
		AR_$(subst -,_,$(RUST_TARGET))="$(AR)" RANLIB_$(subst -,_,$(RUST_TARGET))="$(RANLIB)" \
		CC_$(subst -,_,$(RUST_TARGET))="$(BUILD_WORK)/starship/target-cc-wrapper" \
		CXX_$(subst -,_,$(RUST_TARGET))="$(BUILD_WORK)/starship/target-cxx-wrapper" \
		CFLAGS_$(subst -,_,$(RUST_TARGET))="$(CFLAGS) $(if $(filter aarch64-apple-ios,$(RUST_TARGET)),-include stdio.h)" CXXFLAGS_$(subst -,_,$(RUST_TARGET))="$(CXXFLAGS)" \
		CARGO_TARGET_$(subst -,_,$(shell echo $(RUST_TARGET) | tr '[:lower:]' '[:upper:]'))_LINKER="$(BUILD_WORK)/starship/target-cc-wrapper" \
		CFLAGS= CXXFLAGS= CPPFLAGS= ASFLAGS= LDFLAGS= RUSTFLAGS="-L $(BUILD_BASE)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib $(if $(filter iphoneos-arm64-roothide,$(MEMO_TARGET)),-C link-arg=-liosexec)" cargo build \
		--release \
		--locked \
		--target=$(RUST_TARGET)
	$(INSTALL) -Dm755 $(BUILD_WORK)/starship/target/$(RUST_TARGET)/release/starship $(BUILD_STAGE)/starship/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/starship
	$(call AFTER_BUILD)
endif

starship-package: starship-stage
	# starship.mk Package Structure
	rm -rf $(BUILD_DIST)/starship

	# starship.mk Prep starship
	cp -a $(BUILD_STAGE)/starship $(BUILD_DIST)

	# starship.mk Sign
	$(call SIGN,starship,general.xml)

	# starship.mk Make .debs
	$(call PACK,starship,DEB_STARSHIP_V)

	# starship.mk Build cleanup
	rm -rf $(BUILD_DIST)/starship

.PHONY: starship starship-package
