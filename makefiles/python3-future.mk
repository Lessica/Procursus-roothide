ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS += python3-future
PYTHON3_FUTURE_VERSION := 0.18.2
DEB_PYTHON3_FUTURE_V ?= $(PYTHON3_FUTURE_VERSION)
PYTHON_HOST ?= python$(PYTHON3_MAJOR_V)

python3-future-setup: setup
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/future-0.18.2.tar.gz,https://files.pythonhosted.org/packages/45/0b/38b06fd9b92dc2b68d58b75f900e97884c45bedd2ff83203d933cf5851c9/future-0.18.2.tar.gz)
	echo 'b1bead90b70cf6ec3f0710ae53a525360fa360d306a86583adc6bf83a4db537d  $(BUILD_SOURCE)/future-0.18.2.tar.gz' | sha256sum -c -
	$(call EXTRACT_TAR,future-0.18.2.tar.gz,future-0.18.2,python3-future)

ifneq ($(wildcard $(BUILD_WORK)/python3-future/.build_complete),)
python3-future:
	@echo "Using previously built python3-future."
else
python3-future: python3-future-setup python3
	$(PYTHON_HOST) -c 'import sys; assert sys.version_info[:2] == tuple(map(int, "$(PYTHON3_MAJOR_V)".split("."))), "Host Python must match target major/minor"'
	cd $(BUILD_WORK)/python3-future && $(PYTHON_HOST) setup.py \
		build --executable="$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/python3" \
		install --install-lib="$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/python3/dist-packages" \
		--root="$(BUILD_STAGE)/python3-future" --prefix="$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)"
	find $(BUILD_STAGE)/python3-future -name __pycache__ -prune -exec rm -rf {} \;
	mkdir -p $(BUILD_STAGE)/python3-future/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/doc/python3-future
	cp -a $(BUILD_WORK)/python3-future/LICENSE* $(BUILD_STAGE)/python3-future/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/doc/python3-future/
	$(call AFTER_BUILD,copy)
endif

PYTHON3_FUTURE_PACK = $(subst /share/{info$(comma)doc},/share/info,$(call PACK,$(1),DEB_PYTHON3_FUTURE_V))

python3-future-package: python3-future-stage
	rm -rf $(BUILD_DIST)/python3-future
	cp -a $(BUILD_STAGE)/python3-future $(BUILD_DIST)/python3-future
	$(call PYTHON3_FUTURE_PACK,python3-future)
	rm -rf $(BUILD_DIST)/python3-future

.PHONY: python3-future python3-future-package
