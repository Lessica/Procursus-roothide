ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS    += gping
GPING_VERSION  := 1.2.6
DEB_GPING_V    ?= $(GPING_VERSION)-1

gping-setup: setup
	$(call GITHUB_ARCHIVE,orf,gping,$(GPING_VERSION),gping-v$(GPING_VERSION))
	$(call EXTRACT_TAR,gping-$(GPING_VERSION).tar.gz,gping-gping-v$(GPING_VERSION),gping)
	$(call DO_PATCH,gping,gping,-p1)
ifneq ($(filter appletvos%,$(MEMO_TARGET)),)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/parking_lot_core-0.8.5.crate,https://static.crates.io/crates/parking_lot_core/parking_lot_core-0.8.5.crate)
	$(call CHECKSUM_VERIFY,sha256,parking_lot_core-0.8.5.crate,d76e8e1493bcac0d2766c42737f34458f1c8c50c0d23bcb24ea953affb273216)
	$(call EXTRACT_TAR,parking_lot_core-0.8.5.crate,parking_lot_core-0.8.5,gping-parking-lot)
	$(call DO_PATCH,gping-parking-lot,gping-parking-lot,-p1)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/mio-0.7.13.crate,https://static.crates.io/crates/mio/mio-0.7.13.crate)
	$(call CHECKSUM_VERIFY,sha256,mio-0.7.13.crate,8c2bdb6314ec10835cd3293dd268473a835c02b7b352e788be788b3c6ca6bb16)
	$(call EXTRACT_TAR,mio-0.7.13.crate,mio-0.7.13,gping-mio)
	$(call DO_PATCH,gping-mio,gping-mio,-p1)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/socket2-0.4.10.crate,https://static.crates.io/crates/socket2/socket2-0.4.10.crate)
	$(call CHECKSUM_VERIFY,sha256,socket2-0.4.10.crate,9f7916fc008ca5542385b89a3d3ce689953c143e9304a9bf8beec1de48994c0d)
	$(call EXTRACT_TAR,socket2-0.4.10.crate,socket2-0.4.10,gping-socket2)
	$(call DO_PATCH,gping-socket2,gping-socket2,-p1)
	$(call DO_PATCH,gping-tvos,gping,-p1)
endif

ifneq ($(wildcard $(BUILD_WORK)/gping/.build_complete),)
gping:
	@echo "Using previously built gping."
else
gping: gping-setup $(if $(filter appletvos-arm64-roothide,$(MEMO_TARGET)),libiosexec)
	cd $(BUILD_WORK)/gping && $(DEFAULT_RUST_FLAGS) $(if $(filter appletvos-arm64-roothide,$(MEMO_TARGET)),RUSTFLAGS="-L $(BUILD_BASE)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib -C link-arg=-liosexec -C link-arg=-lresolv") cargo build \
		--release \
		--all-features \
		--locked \
		--target=$(RUST_TARGET)
	$(INSTALL) -Dm755 $(BUILD_WORK)/gping/target/$(RUST_TARGET)/release/gping $(BUILD_STAGE)/gping/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/gping
	$(call AFTER_BUILD)
endif

gping-package: gping-stage
	# gping.mk Package Structure
	rm -rf $(BUILD_DIST)/gping

	# gping.mk Prep gping
	cp -a $(BUILD_STAGE)/gping $(BUILD_DIST)

	# gping.mk Sign
	$(call SIGN,gping,general.xml)

	# gping.mk Make .debs
	$(call PACK,gping,DEB_GPING_V)

	# gping.mk Build cleanup
	rm -rf $(BUILD_DIST)/gping

.PHONY: gping gping-package
