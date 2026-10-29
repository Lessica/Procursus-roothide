ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

ifeq (,$(findstring darwin,$(MEMO_TARGET)))

STRAPPROJECTS       += debianutils
DEBIANUTILS_VERSION := 5.19
DEB_DEBIANUTILS_V   ?= $(DEBIANUTILS_VERSION)-1

debianutils-setup: setup
	if [ ! -d $(BUILD_WORK)/debianutils ]; then \
		$(call DOWNLOAD_FILES,$(BUILD_SOURCE),https://snapshot.debian.org/archive/debian/20240609T083025Z/pool/main/d/debianutils/debianutils_$(DEBIANUTILS_VERSION).tar.xz); \
		$(call CHECKSUM_VERIFY,sha256,debianutils_$(DEBIANUTILS_VERSION).tar.xz,1f5552d3f7ecc811a37ba3a70a446bd988fdce64813a475f4038646d126b2019) || exit 1; \
		$(call EXTRACT_TAR,debianutils_$(DEBIANUTILS_VERSION).tar.xz,debianutils,debianutils-$(DEBIANUTILS_VERSION)-source) || exit 1; \
		mv $(BUILD_WORK)/debianutils-$(DEBIANUTILS_VERSION)-source $(BUILD_WORK)/debianutils || exit 1; \
	fi
ifneq (,$(findstring roothide,$(MEMO_TARGET)))
	$(call DO_PATCH,debianutils,debianutils,-p1)
endif
	sed -i 's|/etc/shells|$(MEMO_PREFIX)/etc/shells|g' $(BUILD_WORK)/debianutils/add-shell
	sed -i 's|/etc/shells|$(MEMO_PREFIX)/etc/shells|g' $(BUILD_WORK)/debianutils/remove-shell

ifneq ($(wildcard $(BUILD_WORK)/debianutils/.build_complete),)
debianutils:
	@echo "Using previously built debianutils."
else
debianutils: debianutils-setup
	cd $(BUILD_WORK)/debianutils && autoreconf -fi && ./configure -C \
		$(DEFAULT_CONFIGURE_FLAGS) \
		--disable-dependency-tracking
	+$(MAKE) -C $(BUILD_WORK)/debianutils install \
		DESTDIR=$(BUILD_STAGE)/debianutils
	rm -f $(BUILD_STAGE)/debianutils/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/sbin/installkernel \
		$(BUILD_STAGE)/debianutils/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/{ischroot,which}
	rm -rf $(BUILD_STAGE)/debianutils/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/{,??}/man1 \
		$(BUILD_STAGE)/debianutils/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/{,??}/man8/installkernel.8
	mkdir -p $(BUILD_STAGE)/debianutils/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/debianutils
	echo -e "# /etc/shells: valid login shells\n\
$(MEMO_PREFIX)/bin/sh\n\
$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/sh" > $(BUILD_STAGE)/debianutils/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/debianutils/shells
	$(call AFTER_BUILD)
endif

debianutils-package: debianutils-stage
	# debianutils.mk Package Structure
	rm -rf $(BUILD_DIST)/debianutils
	mkdir -p $(BUILD_DIST)/debianutils/$(MEMO_PREFIX)/bin

	# debianutils.mk Prep debianutils
	cp -a $(BUILD_STAGE)/debianutils $(BUILD_DIST)
ifneq ($(MEMO_SUB_PREFIX),)
	$(LN_S) $(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/run-parts $(BUILD_DIST)/debianutils/$(MEMO_PREFIX)/bin
endif

	# debianutils.mk Sign
	$(call SIGN,debianutils,general.xml)

	# debianutils.mk Make .debs
	$(call PACK,debianutils,DEB_DEBIANUTILS_V)

	# debianutils.mk Build cleanup
	rm -rf $(BUILD_DIST)/debianutils

.PHONY: debianutils debianutils-package

endif
