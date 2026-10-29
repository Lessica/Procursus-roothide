ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

ifeq (,$(findstring darwin,$(MEMO_TARGET)))

SUBPROJECTS         += snaprestore
SNAPRESTORE_VERSION := 0.3
SNAPRESTORE_COMMIT  := bd76a8431a0ad66d8b8345ab9237c411cea41887
DEB_SNAPRESTORE_V   ?= $(SNAPRESTORE_VERSION)

snaprestore-setup: setup
	$(call DOWNLOAD_FILES,$(BUILD_SOURCE), \
		https://github.com/CRKatri/snaprestore/archive/$(SNAPRESTORE_COMMIT).tar.gz)
	@echo "601d86ce0b0f6b9ba556a10f6437b7eb0d148047907874bbb4dcab5b945e8310  $(BUILD_SOURCE)/$(SNAPRESTORE_COMMIT).tar.gz" | shasum -a 256 -c -
	$(call EXTRACT_TAR,$(SNAPRESTORE_COMMIT).tar.gz,snaprestore-$(SNAPRESTORE_COMMIT),snaprestore)
	$(call DO_PATCH,snaprestore,snaprestore,-p1)

ifneq ($(wildcard $(BUILD_WORK)/snaprestore/.build_complete),)
snaprestore:
	@echo "Using previously built snaprestore."
else
snaprestore: snaprestore-setup
	$(MAKE) -C $(BUILD_WORK)/snaprestore
	$(MAKE) -C $(BUILD_WORK)/snaprestore install \
		PREFIX="$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)" \
		DESTDIR="$(BUILD_STAGE)/snaprestore"
	$(call AFTER_BUILD)
endif

snaprestore-package: snaprestore-stage
	# snaprestore.mk Package Structure
	rm -rf $(BUILD_DIST)/snaprestore

	# snaprestore.mk Prep snaprestore
	cp -a $(BUILD_STAGE)/snaprestore $(BUILD_DIST)

	# snaprestore.mk Sign
	$(call SIGN,snaprestore,snaprestore.xml)

	# snaprestore.mk Make .debs
	$(call PACK,snaprestore,DEB_SNAPRESTORE_V)

	# snaprestore.mk Build cleanup
	rm -rf $(BUILD_DIST)/snaprestore

.PHONY: snaprestore snaprestore-package

endif
