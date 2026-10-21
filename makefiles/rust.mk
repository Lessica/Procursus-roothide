ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS  += rust
RUST_VERSION := 1.56.1
DEB_RUST_V   ?= $(RUST_VERSION)
RUST_SOURCE_SHA256 := 61fdcc8bc2530ee18f91318347e09b7cc07e9ca04b1c627c135ecc8dcb8f2ac5
RUST_SOURCE_ARCHIVE := rustc-$(RUST_VERSION)-src.tar.xz
RUST_BUILD_HOST ?= $(shell rustc -vV 2>/dev/null | sed -n 's/^host: //p')
ifeq ($(strip $(RUST_BUILD_HOST)),)
RUST_BUILD_HOST := $(shell $(BUILD_MISC)/config.guess)
endif
RUST_HOST_SDKROOT := $(if $(filter Darwin,$(UNAME)),$(MACOSX_SYSROOT),)
RUST_HOST_CFLAGS := $(if $(filter Darwin,$(UNAME)),-arch $(shell uname -m) -isysroot $(MACOSX_SYSROOT) -mmacosx-version-min=$(MACOSX_DEPLOYMENT_TARGET),$(CFLAGS_FOR_BUILD))
RUST_HOST_CC_COMMAND := $(if $(filter Darwin,$(UNAME)),$(CC),$(CC_FOR_BUILD))
RUST_HOST_CXX_COMMAND := $(if $(filter Darwin,$(UNAME)),$(CXX),$(CXX_FOR_BUILD))
RUST_TARGET_ENV := $(subst -,_,$(RUST_TARGET))
RUST_TARGET_UPPER := $(shell printf '%s' '$(RUST_TARGET)' | tr '[:lower:]-' '[:upper:]_')
ifeq ($(findstring apple-ios,$(RUST_TARGET)),apple-ios)
RUST_TARGET_CFLAGS := -arch $(MEMO_ARCH) -target $(RUST_TARGET) -isysroot $(TARGET_SYSROOT) $(PLATFORM_VERSION_MIN)
else ifeq ($(findstring apple-darwin,$(RUST_TARGET)),apple-darwin)
RUST_TARGET_CFLAGS := -arch $(MEMO_ARCH) -target $(RUST_TARGET) -isysroot $(MACOSX_SYSROOT) -mmacosx-version-min=$(MACOSX_DEPLOYMENT_TARGET)
else
RUST_TARGET_CFLAGS := $(CFLAGS)
endif
RUST_HOST_CC_WRAPPER := $(abspath $(BUILD_WORK)/rust/host-cc-wrapper)
RUST_HOST_CXX_WRAPPER := $(abspath $(BUILD_WORK)/rust/host-cxx-wrapper)
RUST_TARGET_CC_WRAPPER := $(abspath $(BUILD_WORK)/rust/target-cc-wrapper)
RUST_TARGET_CXX_WRAPPER := $(abspath $(BUILD_WORK)/rust/target-cxx-wrapper)

rust-setup: setup
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/$(RUST_SOURCE_ARCHIVE),https://static.rust-lang.org/dist/$(RUST_SOURCE_ARCHIVE))
	$(call CHECKSUM_VERIFY,sha256,$(RUST_SOURCE_ARCHIVE),$(RUST_SOURCE_SHA256))
	$(call EXTRACT_TAR,$(RUST_SOURCE_ARCHIVE),rustc-$(RUST_VERSION)-src,rust)
	$(call DO_PATCH,rust,rust,-p1)

	mkdir -p $(BUILD_STAGE)/rust $(BUILD_WORK)/rust/build
	cp -f "$(BUILD_INFO)/rust_config.toml" "$(BUILD_WORK)/rust/config.toml"
	sed -i -e 's|PROCURSUS_BUILD_DIR|$(abspath $(BUILD_WORK)/rust/build)|g' \
		-e 's|PROCURSUS_BUILD_HOST|$(RUST_BUILD_HOST)|g' \
		-e 's|PROCURSUS_TARGET|$(RUST_TARGET)|g' \
		-e 's|PROCURSUS_INSTALL_PREFIX|$(abspath $(BUILD_STAGE)/rust/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX))|g' \
		-e 's|PROCURSUS_HOST_CC|$(abspath $(RUST_TARGET_CC_WRAPPER))|g' \
		-e 's|PROCURSUS_HOST_CXX|$(abspath $(RUST_TARGET_CXX_WRAPPER))|g' \
		-e 's|PROCURSUS_HOST_LINKER|$(abspath $(RUST_TARGET_CC_WRAPPER))|g' "$(BUILD_WORK)/rust/config.toml"
	printf '%s\n' '#!/bin/sh' 'exec $(RUST_HOST_CC_COMMAND) "$$@" $(RUST_HOST_CFLAGS)' > "$(RUST_HOST_CC_WRAPPER)"
	printf '%s\n' '#!/bin/sh' 'exec $(RUST_HOST_CXX_COMMAND) "$$@" $(RUST_HOST_CFLAGS)' > "$(RUST_HOST_CXX_WRAPPER)"
	printf '%s\n' '#!/bin/sh' 'exec "$(CC)" "$$@" $(RUST_TARGET_CFLAGS)' > "$(RUST_TARGET_CC_WRAPPER)"
	printf '%s\n' '#!/bin/sh' 'exec "$(CXX)" "$$@" $(RUST_TARGET_CFLAGS)' > "$(RUST_TARGET_CXX_WRAPPER)"
	chmod 755 "$(RUST_HOST_CC_WRAPPER)" "$(RUST_HOST_CXX_WRAPPER)" "$(RUST_TARGET_CC_WRAPPER)" "$(RUST_TARGET_CXX_WRAPPER)"

rust: rust-setup openssl curl
	cd "$(BUILD_WORK)/rust" && \
		export PATH="$(BUILD_TOOLS)/bin:$(PATH)" \
		DEVELOPER_DIR="$(DEVELOPER_DIR)" \
		MACOSX_DEPLOYMENT_TARGET=$(MACOSX_DEPLOYMENT_TARGET) \
		CC="$(RUST_HOST_CC_WRAPPER)" CXX="$(RUST_HOST_CXX_WRAPPER)" \
		AR="$(AR_FOR_BUILD)" RANLIB="$(RANLIB_FOR_BUILD)" \
		CFLAGS= CPPFLAGS= CXXFLAGS= ASFLAGS= LDFLAGS= PKG_CONFIG_PATH= && unset PKG_CONFIG OPENSSL_DIR SDKROOT && \
	env CC_$(RUST_TARGET_ENV)="$(RUST_TARGET_CC_WRAPPER)" \
		CXX_$(RUST_TARGET_ENV)="$(RUST_TARGET_CXX_WRAPPER)" \
		AR_$(RUST_TARGET_ENV)="$(AR)" RANLIB_$(RUST_TARGET_ENV)="$(RANLIB)" \
		CFLAGS_$(RUST_TARGET_ENV)="$(RUST_TARGET_CFLAGS)" \
		CXXFLAGS_$(RUST_TARGET_ENV)="$(RUST_TARGET_CFLAGS)" \
		PKG_CONFIG_$(RUST_TARGET_ENV)="$(BUILD_TOOLS)/$(RUST_TARGET)-pkg-config" \
		PKG_CONFIG_ALLOW_CROSS_$(RUST_TARGET_ENV)=1 \
		$(RUST_TARGET_UPPER)_OPENSSL_DIR="$(abspath $(BUILD_BASE)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX))" \
		python3 x.py build -j$(CORE_COUNT) && \
	env CC_$(RUST_TARGET_ENV)="$(RUST_TARGET_CC_WRAPPER)" \
		CXX_$(RUST_TARGET_ENV)="$(RUST_TARGET_CXX_WRAPPER)" \
		AR_$(RUST_TARGET_ENV)="$(AR)" RANLIB_$(RUST_TARGET_ENV)="$(RANLIB)" \
		CFLAGS_$(RUST_TARGET_ENV)="$(RUST_TARGET_CFLAGS)" \
		CXXFLAGS_$(RUST_TARGET_ENV)="$(RUST_TARGET_CFLAGS)" \
		PKG_CONFIG_$(RUST_TARGET_ENV)="$(BUILD_TOOLS)/$(RUST_TARGET)-pkg-config" \
		PKG_CONFIG_ALLOW_CROSS_$(RUST_TARGET_ENV)=1 \
		$(RUST_TARGET_UPPER)_OPENSSL_DIR="$(abspath $(BUILD_BASE)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX))" \
		python3 x.py install -j$(CORE_COUNT)
	rm -rf $(BUILD_STAGE)/rust/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/{share/doc,etc}
	rm -rf $(BUILD_STAGE)/rust/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/rustlib/{src,manifest-*,components,install.log,uninstall.sh,rust-installer-version}
	rm -rf $(BUILD_STAGE)/rust/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/rustlib/*/analysis
	$(if $(findstring apple-ios,$(RUST_TARGET)),install -m 755 "$(BUILD_WORK)/rust/build/$(RUST_TARGET)/llvm/bin/llvm-dwp" "$(BUILD_STAGE)/rust/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/rustlib/$(RUST_TARGET)/bin/rust-llvm-dwp")
	$(call AFTER_BUILD)

rust-package: rust
	# rust.mk Package Structure
	rm -rf $(BUILD_DIST)/{rust{,-toolchain},cargo}
	mkdir -p $(BUILD_DIST)/{rust,cargo}/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/{bin,share/man/man1}
	mkdir -p $(BUILD_DIST)/rust-toolchain/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)

	# rust.mk Prep rust
	cp -a $(BUILD_STAGE)/rust/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/{rust*,clippy-driver} $(BUILD_DIST)/rust/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin
	cp -a $(BUILD_STAGE)/rust/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/man1/rust* $(BUILD_DIST)/rust/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/man1

	# rust.mk Prep cargo
	cp -a $(BUILD_STAGE)/rust/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/cargo* $(BUILD_DIST)/cargo/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin
	cp -a $(BUILD_STAGE)/rust/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/zsh $(BUILD_DIST)/cargo/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share
	cp -a $(BUILD_STAGE)/rust/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/man1/cargo* $(BUILD_DIST)/cargo/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/man1

	# rust.mk Prep rust-toolchain
	cp -a $(BUILD_STAGE)/rust/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib $(BUILD_DIST)/rust-toolchain/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)

	# rust.mk Sign
	$(call SIGN,rust,general.xml)
	$(call SIGN,cargo,general.xml)
	$(call SIGN,rust-toolchain,general.xml)

	# rust.mk Make .debs
	$(call PACK,rust,DEB_RUST_V)
	$(call PACK,cargo,DEB_RUST_V)
	$(call PACK,rust-toolchain,DEB_RUST_V)

	# rust.mk Build cleanup
	rm -rf $(BUILD_DIST)/{cargo,rust{,-toolchain}}

.PHONY: rust rust-package
