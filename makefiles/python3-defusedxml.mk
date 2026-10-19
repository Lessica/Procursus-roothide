ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS += python3-defusedxml
PYTHON3_DEFUSEDXML_VERSION := 0.7.1
DEB_PYTHON3_DEFUSEDXML_V ?= $(PYTHON3_DEFUSEDXML_VERSION)
PYTHON_HOST ?= python$(PYTHON3_MAJOR_V)

python3-defusedxml-setup: setup
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/defusedxml-0.7.1.tar.gz,https://files.pythonhosted.org/packages/0f/d5/c66da9b79e5bdb124974bfe172b4daf3c984ebd9c2a06e2b8a4dc7331c72/defusedxml-0.7.1.tar.gz)
	echo '1bb3032db185915b62d7c6209c5a8792be6a32ab2fedacc84e01b52c51aa3e69  $(BUILD_SOURCE)/defusedxml-0.7.1.tar.gz' | sha256sum -c -
	$(call EXTRACT_TAR,defusedxml-0.7.1.tar.gz,defusedxml-0.7.1,python3-defusedxml)

ifneq ($(wildcard $(BUILD_WORK)/python3-defusedxml/.build_complete),)
python3-defusedxml:
	@echo "Using previously built python3-defusedxml."
else
python3-defusedxml: python3-defusedxml-setup python3
	$(PYTHON_HOST) -c 'import sys; assert sys.version_info[:2] == tuple(map(int, "$(PYTHON3_MAJOR_V)".split("."))), "Host Python must match target major/minor"'
	cd $(BUILD_WORK)/python3-defusedxml && $(PYTHON_HOST) setup.py \
		build --executable="$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/python3" \
		install --install-lib="$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/python3/dist-packages" \
		--root="$(BUILD_STAGE)/python3-defusedxml" --prefix="$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)"
	find $(BUILD_STAGE)/python3-defusedxml -name __pycache__ -prune -exec rm -rf {} \;
	$(call AFTER_BUILD,copy)
endif

python3-defusedxml-package: python3-defusedxml-stage
	rm -rf $(BUILD_DIST)/python3-defusedxml
	cp -a $(BUILD_STAGE)/python3-defusedxml $(BUILD_DIST)/python3-defusedxml
	$(call PACK,python3-defusedxml,DEB_PYTHON3_DEFUSEDXML_V)
	rm -rf $(BUILD_DIST)/python3-defusedxml

.PHONY: python3-defusedxml python3-defusedxml-package
