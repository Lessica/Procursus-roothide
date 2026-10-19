ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS += python3-pyparsing
PYTHON3_PYPARSING_VERSION := 2.4.7
DEB_PYTHON3_PYPARSING_V ?= $(PYTHON3_PYPARSING_VERSION)
PYTHON_HOST ?= python$(PYTHON3_MAJOR_V)

python3-pyparsing-setup: setup
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/pyparsing-2.4.7.tar.gz,https://files.pythonhosted.org/packages/c1/47/dfc9c342c9842bbe0036c7f763d2d6686bcf5eb1808ba3e170afdb282210/pyparsing-2.4.7.tar.gz)
	echo 'c203ec8783bf771a155b207279b9bccb8dea02d8f0c9e5f8ead507bc3246ecc1  $(BUILD_SOURCE)/pyparsing-2.4.7.tar.gz' | sha256sum -c -
	$(call EXTRACT_TAR,pyparsing-2.4.7.tar.gz,pyparsing-2.4.7,python3-pyparsing)

ifneq ($(wildcard $(BUILD_WORK)/python3-pyparsing/.build_complete),)
python3-pyparsing:
	@echo "Using previously built python3-pyparsing."
else
python3-pyparsing: python3-pyparsing-setup python3
	$(PYTHON_HOST) -c 'import sys; assert sys.version_info[:2] == tuple(map(int, "$(PYTHON3_MAJOR_V)".split("."))), "Host Python must match target major/minor"'
	cd $(BUILD_WORK)/python3-pyparsing && $(PYTHON_HOST) setup.py \
		build --executable="$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/python3" \
		install --install-lib="$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/python3/dist-packages" \
		--root="$(BUILD_STAGE)/python3-pyparsing" --prefix="$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)"
	find $(BUILD_STAGE)/python3-pyparsing -name __pycache__ -prune -exec rm -rf {} \;
	$(call AFTER_BUILD,copy)
endif

python3-pyparsing-package: python3-pyparsing-stage
	rm -rf $(BUILD_DIST)/python3-pyparsing
	cp -a $(BUILD_STAGE)/python3-pyparsing $(BUILD_DIST)/python3-pyparsing
	$(call PACK,python3-pyparsing,DEB_PYTHON3_PYPARSING_V)
	rm -rf $(BUILD_DIST)/python3-pyparsing

.PHONY: python3-pyparsing python3-pyparsing-package
