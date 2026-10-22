ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS         += debootstrap
DEBOOTSTRAP_VERSION := 1.0.128+nmu2
DEB_DEBOOTSTRAP_V   ?= $(DEBOOTSTRAP_VERSION)

debootstrap-setup: setup
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/debootstrap_$(DEBOOTSTRAP_VERSION).tar.gz,https://snapshot.debian.org/file/dd207b1f59a6b84fb357c2fb9c1ca5c4d8a6eb5f)
	$(call CHECKSUM_VERIFY,sha256,debootstrap_$(DEBOOTSTRAP_VERSION).tar.gz,528523228d93a31c9e0cd4eb932977ea8ceec2bfbf8db1103bec2397cc7434fa)
	$(call EXTRACT_TAR,debootstrap_$(DEBOOTSTRAP_VERSION).tar.gz,debootstrap,debootstrap)
	$(call DO_PATCH,debootstrap,debootstrap,-p1)
	sed -i 's/@VERSION@/$(DEB_DEBOOTSTRAP_V)/g' $(BUILD_WORK)/debootstrap/debootstrap

ifneq ($(wildcard $(BUILD_WORK)/debootstrap/.build_complete),)
debootstrap:
	@echo "Using previously built debootstrap."
else
debootstrap: debootstrap-setup
	+$(MAKE) -C $(BUILD_WORK)/debootstrap install \
		DESTDIR=$(BUILD_STAGE)/debootstrap
	$(INSTALL) -Dm644 $(BUILD_WORK)/debootstrap/debootstrap.8 \
		$(BUILD_STAGE)/debootstrap/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/man8/debootstrap.8
	$(call AFTER_BUILD)
endif

debootstrap-package: debootstrap-stage
	# debootstrap.mk Package Structure
	rm -rf $(BUILD_DIST)/debootstrap

	# debootstrap.mk Prep debootstrap
	cp -a $(BUILD_STAGE)/debootstrap $(BUILD_DIST)

	# debootstrap.mk Make .debs
	$(call PACK,debootstrap,DEB_DEBOOTSTRAP_V)

	# debootstrap.mk Build cleanup
	rm -rf $(BUILD_DIST)/debootstrap

.PHONY: debootstrap debootstrap-package
