ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS  += dog
DOG_VERSION  := 0.1.0
DEB_DOG_V    ?= $(DOG_VERSION)-1

dog-setup: setup
	$(call GITHUB_ARCHIVE,ogham,dog,$(DOG_VERSION),v$(DOG_VERSION))
	$(call EXTRACT_TAR,dog-$(DOG_VERSION).tar.gz,dog-$(DOG_VERSION),dog)
ifneq ($(filter appletvos%,$(MEMO_TARGET)),)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/getrandom-0.1.15.crate,https://static.crates.io/crates/getrandom/getrandom-0.1.15.crate)
	$(call CHECKSUM_VERIFY,sha256,getrandom-0.1.15.crate,fc587bc0ec293155d5bfa6b9891ec18a1e330c234f896ea47fbada4cadbe47e6)
	$(call EXTRACT_TAR,getrandom-0.1.15.crate,getrandom-0.1.15,dog-getrandom)
	$(call DO_PATCH,dog-getrandom,dog-getrandom,-p1)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/native-tls-0.2.4.crate,https://static.crates.io/crates/native-tls/native-tls-0.2.4.crate)
	$(call CHECKSUM_VERIFY,sha256,native-tls-0.2.4.crate,2b0d88c06fe90d5ee94048ba40409ef1d9315d86f6f38c2efdaad4fb50c58b2d)
	$(call EXTRACT_TAR,native-tls-0.2.4.crate,native-tls-0.2.4,dog-native-tls)
	$(call DO_PATCH,dog-native-tls,dog-native-tls,-p1)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/security-framework-0.4.4.crate,https://static.crates.io/crates/security-framework/security-framework-0.4.4.crate)
	$(call CHECKSUM_VERIFY,sha256,security-framework-0.4.4.crate,64808902d7d99f78eaddd2b4e2509713babc3dc3c85ad6f4c447680f3c01e535)
	$(call EXTRACT_TAR,security-framework-0.4.4.crate,security-framework-0.4.4,dog-security-framework)
	$(call DO_PATCH,dog-security-framework,dog-security-framework,-p1)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/security-framework-sys-0.4.3.crate,https://static.crates.io/crates/security-framework-sys/security-framework-sys-0.4.3.crate)
	$(call CHECKSUM_VERIFY,sha256,security-framework-sys-0.4.3.crate,17bf11d99252f512695eb468de5516e5cf75455521e69dfe343f3b74e4748405)
	$(call EXTRACT_TAR,security-framework-sys-0.4.3.crate,security-framework-sys-0.4.3,dog-security-framework-sys)
	$(call DO_PATCH,dog-security-framework-sys,dog-security-framework-sys,-p1)
	$(call DO_PATCH,dog-tvos,dog,-p1)
endif

ifneq ($(wildcard $(BUILD_WORK)/dog/.build_complete),)
dog:
	@echo "Using previously built dog."
else
dog: dog-setup
	printf '%s\n' '#!/bin/sh' 'exec "$(CC)" -isysroot "$(TARGET_SYSROOT)" "$$@"' > $(BUILD_WORK)/dog/target-cc-wrapper
	printf '%s\n' '#!/bin/sh' 'exec "$(CXX)" -isysroot "$(TARGET_SYSROOT)" "$$@"' > $(BUILD_WORK)/dog/target-cxx-wrapper
	chmod 755 $(BUILD_WORK)/dog/target-cc-wrapper $(BUILD_WORK)/dog/target-cxx-wrapper
	cd $(BUILD_WORK)/dog && $(DEFAULT_RUST_FLAGS) \
		CC="$(CC_FOR_BUILD)" CXX="$(CXX_FOR_BUILD)" \
		CC_$(subst -,_,$(RUST_TARGET))="$(BUILD_WORK)/dog/target-cc-wrapper" \
		CXX_$(subst -,_,$(RUST_TARGET))="$(BUILD_WORK)/dog/target-cxx-wrapper" \
		CFLAGS_$(subst -,_,$(RUST_TARGET))="$(CFLAGS)" CXXFLAGS_$(subst -,_,$(RUST_TARGET))="$(CXXFLAGS)" \
		CARGO_TARGET_$(subst -,_,$(shell echo $(RUST_TARGET) | tr '[:lower:]' '[:upper:]'))_LINKER="$(BUILD_WORK)/dog/target-cc-wrapper" \
		CFLAGS= CXXFLAGS= RUSTFLAGS="-L $(BUILD_BASE)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib $(if $(filter iphoneos-arm64-roothide appletvos-arm64-roothide,$(MEMO_TARGET)),-C link-arg=-liosexec)" cargo build \
		--release \
		--locked \
		--all-features \
		--target=$(RUST_TARGET)
	$(INSTALL) -Dm755 $(BUILD_WORK)/dog/target/$(RUST_TARGET)/release/dog $(BUILD_STAGE)/dog/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/dog
	$(call AFTER_BUILD)
endif

dog-package: dog-stage
	# dog.mk Package Structure
	rm -rf $(BUILD_DIST)/dog

	# dog.mk Prep dog
	cp -a $(BUILD_STAGE)/dog $(BUILD_DIST)

	# dog.mk Sign
	$(call SIGN,dog,general.xml)

	# dog.mk Make .debs
	$(call PACK,dog,DEB_DOG_V)

	# dog.mk Build cleanup
	rm -rf $(BUILD_DIST)/dog

.PHONY: dog dog-package
