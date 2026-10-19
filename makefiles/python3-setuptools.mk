ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS += python3-setuptools
PYTHON3_SETUPTOOLS_VERSION := 59.6.0
DEB_PYTHON3_SETUPTOOLS_V ?= $(PYTHON3_SETUPTOOLS_VERSION)
PYTHON_HOST ?= python$(PYTHON3_MAJOR_V)

python3-setuptools-setup: setup
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/setuptools-59.6.0.tar.gz,https://files.pythonhosted.org/packages/6a/fa/5ec0fa9095c9b72cb1c31a8175c4c6745bf5927d1045d7a70df35d54944f/setuptools-59.6.0.tar.gz)
	echo '22c7348c6d2976a52632c67f7ab0cdf40147db7789f9aed18734643fe9cf3373  $(BUILD_SOURCE)/setuptools-59.6.0.tar.gz' | sha256sum -c -
	$(call EXTRACT_TAR,setuptools-59.6.0.tar.gz,setuptools-59.6.0,python3-setuptools)

ifneq ($(wildcard $(BUILD_WORK)/python3-setuptools/.build_complete),)
python3-setuptools:
	@echo "Using previously built python3-setuptools."
else
python3-setuptools: python3-setuptools-setup python3
	$(PYTHON_HOST) -c 'import sys; assert sys.version_info[:2] == tuple(map(int, "$(PYTHON3_MAJOR_V)".split("."))), "Host Python must match target major/minor"'
	cd $(BUILD_WORK)/python3-setuptools && $(PYTHON_HOST) setup.py \
		build --executable="$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/python3" \
		install --install-lib="$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/python3/dist-packages" \
		--root="$(BUILD_STAGE)/python3-setuptools" --prefix="$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)"
	find $(BUILD_STAGE)/python3-setuptools -name __pycache__ -prune -exec rm -rf {} \;
	$(call AFTER_BUILD,copy)
endif

python3-setuptools-package: python3-setuptools-stage
	rm -rf $(BUILD_DIST)/python3-setuptools
	cp -a $(BUILD_STAGE)/python3-setuptools $(BUILD_DIST)/python3-setuptools
	rm -rf $(BUILD_DIST)/python3-pkg-resources
	mkdir -p $(BUILD_DIST)/python3-pkg-resources/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/python3/dist-packages
	mv $(BUILD_DIST)/python3-setuptools/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/python3/dist-packages/pkg_resources $(BUILD_DIST)/python3-pkg-resources/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/python3/dist-packages/
	$(call PACK,python3-pkg-resources,DEB_PYTHON3_SETUPTOOLS_V)
	rm -rf $(BUILD_DIST)/python3-pkg-resources
	$(call PACK,python3-setuptools,DEB_PYTHON3_SETUPTOOLS_V)
	rm -rf $(BUILD_DIST)/python3-setuptools

.PHONY: python3-setuptools python3-setuptools-package
