ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS   += meson
MESON_VERSION := 0.64.0
DEB_MESON_V   ?= $(MESON_VERSION)
PYTHON_HOST ?= python$(PYTHON3_MAJOR_V)

meson-setup: setup
	$(call GITHUB_ARCHIVE,mesonbuild,meson,$(MESON_VERSION),$(MESON_VERSION))
	$(call EXTRACT_TAR,meson-$(MESON_VERSION).tar.gz,meson-$(MESON_VERSION),meson)

ifneq ($(wildcard $(BUILD_WORK)/meson/.build_complete),)
meson:
	@echo "Using previously built meson."
else
meson: meson-setup python3 ninja
	cd $(BUILD_WORK)/meson && $(PYTHON_HOST) ./setup.py build \
		--executable="$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/python3" \
		install \
		--install-lib="$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/python3/dist-packages" \
		--root="$(BUILD_STAGE)/meson" \
		--prefix="$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)"
	find $(BUILD_STAGE)/meson -name __pycache__ -prune -exec rm -rf {} \;
	$(call AFTER_BUILD)
endif

meson-package: meson-stage
	# meson.mk Package Structure
	rm -rf $(BUILD_DIST)/meson
	cp -a $(BUILD_STAGE)/meson $(BUILD_DIST)

	# meson.mk Sign
	$(call SIGN,meson,general.xml)

	# meson.mk Make .debs
	$(call PACK,meson,DEB_MESON_V)

	# meson.mk Build Cleanup
	rm -rf $(BUILD_DIST)/meson

.PHONY: meson meson-package
