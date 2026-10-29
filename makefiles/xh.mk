ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS += xh
XH_VERSION  := 0.13.0
XH_TARGET_SYSROOT = $(if $(filter appletvos%,$(MEMO_TARGET)),$(abspath $(BUILD_WORK)/xh/SDKs/iPhoneOS.sdk),$(TARGET_SYSROOT))
DEB_XH_V    ?= $(XH_VERSION)-2

xh-setup: setup
	$(call GITHUB_ARCHIVE,ducaale,xh,$(XH_VERSION),v$(XH_VERSION))
	$(call EXTRACT_TAR,xh-$(XH_VERSION).tar.gz,xh-$(XH_VERSION),xh)
ifneq ($(filter appletvos%,$(MEMO_TARGET)),)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/openssl-src-111.28.2+1.1.1w.crate,https://static.crates.io/crates/openssl-src/openssl-src-111.28.2+1.1.1w.crate)
	$(call CHECKSUM_VERIFY,sha256,openssl-src-111.28.2+1.1.1w.crate,bb1830e20a48a975ca898ca8c1d036a36c3c6c5cb7dabc1c216706587857920f)
	$(call EXTRACT_TAR,openssl-src-111.28.2+1.1.1w.crate,openssl-src-111.28.2+1.1.1w,xh-openssl-src)
	$(call DO_PATCH,rbw-openssl-src,xh-openssl-src,-p1)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/ring-0.16.20.crate,https://static.crates.io/crates/ring/ring-0.16.20.crate)
	$(call CHECKSUM_VERIFY,sha256,ring-0.16.20.crate,3053cf52e236a3ed746dfc745aa9cacf1b791d846bdaf412f60a8d7d6e17c8fc)
	$(call EXTRACT_TAR,ring-0.16.20.crate,ring-0.16.20,xh-ring)
	$(call DO_PATCH,rbw-ring,xh-ring,-p1)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/socket2-0.4.0.crate,https://static.crates.io/crates/socket2/socket2-0.4.0.crate)
	$(call CHECKSUM_VERIFY,sha256,socket2-0.4.0.crate,9e3dfc207c526015c632472a77be09cf1b6e46866581aecae5cc38fb4235dea2)
	$(call EXTRACT_TAR,socket2-0.4.0.crate,socket2-0.4.0,xh-socket2)
	$(call DO_PATCH,xh-socket2,xh-socket2,-p1)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/mio-0.7.13.crate,https://static.crates.io/crates/mio/mio-0.7.13.crate)
	$(call CHECKSUM_VERIFY,sha256,mio-0.7.13.crate,8c2bdb6314ec10835cd3293dd268473a835c02b7b352e788be788b3c6ca6bb16)
	$(call EXTRACT_TAR,mio-0.7.13.crate,mio-0.7.13,xh-mio)
	$(call DO_PATCH,gping-mio,xh-mio,-p1)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/tokio-1.6.1.crate,https://static.crates.io/crates/tokio/tokio-1.6.1.crate)
	$(call CHECKSUM_VERIFY,sha256,tokio-1.6.1.crate,0a38d31d7831c6ed7aad00aa4c12d9375fd225a6dd77da1d25b707346319a975)
	$(call EXTRACT_TAR,tokio-1.6.1.crate,tokio-1.6.1,xh-tokio)
	$(call DO_PATCH,xh-tokio,xh-tokio,-p1)
	$(call DO_PATCH,xh-tvos,xh,-p1)
endif

ifneq ($(wildcard $(BUILD_WORK)/xh/.build_complete),)
xh:
	@echo "Using previously built xh."
else
xh: xh-setup
ifneq ($(filter appletvos%,$(MEMO_TARGET)),)
	mkdir -p $(BUILD_WORK)/xh/SDKs
	ln -sfn "$(TARGET_SYSROOT)" "$(XH_TARGET_SYSROOT)"
endif
	printf '%s\n' '#!/bin/sh' 'exec "$(CC)" -isysroot "$(XH_TARGET_SYSROOT)" "$$@"' > $(BUILD_WORK)/xh/target-cc-wrapper
	printf '%s\n' '#!/bin/sh' 'exec "$(CXX)" -isysroot "$(XH_TARGET_SYSROOT)" "$$@"' > $(BUILD_WORK)/xh/target-cxx-wrapper
	chmod 755 $(BUILD_WORK)/xh/target-cc-wrapper $(BUILD_WORK)/xh/target-cxx-wrapper
	cd $(BUILD_WORK)/xh && $(DEFAULT_RUST_FLAGS) \
		CC="$(CC_FOR_BUILD)" CXX="$(CXX_FOR_BUILD)" \
		CC_$(subst -,_,$(RUST_TARGET))="$(BUILD_WORK)/xh/target-cc-wrapper" \
		CXX_$(subst -,_,$(RUST_TARGET))="$(BUILD_WORK)/xh/target-cxx-wrapper" \
		CFLAGS_$(subst -,_,$(RUST_TARGET))="$(subst $(TARGET_SYSROOT),$(XH_TARGET_SYSROOT),$(CFLAGS))" CXXFLAGS_$(subst -,_,$(RUST_TARGET))="$(subst $(TARGET_SYSROOT),$(XH_TARGET_SYSROOT),$(CXXFLAGS))" \
		CARGO_TARGET_$(subst -,_,$(shell echo $(RUST_TARGET) | tr '[:lower:]' '[:upper:]'))_LINKER="$(BUILD_WORK)/xh/target-cc-wrapper" \
		CFLAGS= CXXFLAGS= cargo build \
		--release \
		--locked \
		--all-features \
		--target=$(RUST_TARGET)
	$(INSTALL) -Dm755 $(BUILD_WORK)/xh/target/$(RUST_TARGET)/release/xh $(BUILD_STAGE)/xh/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/xh
	$(INSTALL) -Dm644 $(BUILD_WORK)/xh/doc/xh.1 $(BUILD_STAGE)/xh/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/man1/xh.1
	$(INSTALL) -Dm644 $(BUILD_WORK)/xh/completions/xh.bash $(BUILD_STAGE)/xh/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/bash-completion/completions/xh
	$(INSTALL) -Dm644 $(BUILD_WORK)/xh/completions/xh.fish $(BUILD_STAGE)/xh/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/fish/vendor_completions.d/xh.fish
	$(INSTALL) -Dm644 $(BUILD_WORK)/xh/completions/_xh $(BUILD_STAGE)/xh/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/zsh/site-functions/_xh
	$(call AFTER_BUILD)
endif

xh-package: xh-stage
	# xh.mk Package Structure
	rm -rf $(BUILD_DIST)/xh

	# xh.mk Prep xh
	cp -a $(BUILD_STAGE)/xh $(BUILD_DIST)

	# xh.mk Sign
	$(call SIGN,xh,general.xml)

	# xh.mk Make .debs
	$(call PACK,xh,DEB_XH_V)

	# xh.mk Build cleanup
	rm -rf $(BUILD_DIST)/xh

.PHONY: xh xh-package
