ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS += python3-packaging
PYTHON3_PACKAGING_VERSION := 21.3
DEB_PYTHON3_PACKAGING_V ?= $(PYTHON3_PACKAGING_VERSION)
PYTHON_HOST ?= python$(PYTHON3_MAJOR_V)

python3-packaging-setup: setup
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/packaging-21.3.tar.gz,https://files.pythonhosted.org/packages/df/9e/d1a7217f69310c1db8fdf8ab396229f55a699ce34a203691794c5d1cad0c/packaging-21.3.tar.gz)
	echo 'dd47c42927d89ab911e606518907cc2d3a1f38bbd026385970643f9c5b8ecfeb  $(BUILD_SOURCE)/packaging-21.3.tar.gz' | sha256sum -c -
	$(call EXTRACT_TAR,packaging-21.3.tar.gz,packaging-21.3,python3-packaging)

ifneq ($(wildcard $(BUILD_WORK)/python3-packaging/.build_complete),)
python3-packaging:
	@echo "Using previously built python3-packaging."
else
python3-packaging: python3-packaging-setup python3
	$(PYTHON_HOST) -c 'import sys; assert sys.version_info[:2] == tuple(map(int, "$(PYTHON3_MAJOR_V)".split("."))), "Host Python must match target major/minor"'
	cd $(BUILD_WORK)/python3-packaging && $(PYTHON_HOST) setup.py \
		build --executable="$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/python3" \
		install --install-lib="$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/python3/dist-packages" \
		--root="$(BUILD_STAGE)/python3-packaging" --prefix="$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)"
	find $(BUILD_STAGE)/python3-packaging -name __pycache__ -prune -exec rm -rf {} \;
	mkdir -p $(BUILD_STAGE)/python3-packaging/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/doc/python3-packaging
	cp -a $(BUILD_WORK)/python3-packaging/LICENSE* $(BUILD_STAGE)/python3-packaging/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/doc/python3-packaging/
	$(call AFTER_BUILD,copy)
endif

PYTHON3_PACKAGING_PACK = $(subst /share/{info$(comma)doc},/share/info,$(call PACK,$(1),DEB_PYTHON3_PACKAGING_V))

python3-packaging-package: python3-packaging-stage
	rm -rf $(BUILD_DIST)/python3-packaging
	cp -a $(BUILD_STAGE)/python3-packaging $(BUILD_DIST)/python3-packaging
	$(call PYTHON3_PACKAGING_PACK,python3-packaging)
	rm -rf $(BUILD_DIST)/python3-packaging

.PHONY: python3-packaging python3-packaging-package
