ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS    += pyyaml
PYYAML_VERSION := 5.4.1.1
DEB_PYYAML_V   ?= $(PYYAML_VERSION)-1
PYTHON_HOST ?= python$(PYTHON3_MAJOR_V)
CYTHON_HOST ?= cython

pyyaml-setup: setup
	$(call GITHUB_ARCHIVE,yaml,pyyaml,$(PYYAML_VERSION),$(PYYAML_VERSION))
	$(call EXTRACT_TAR,pyyaml-$(PYYAML_VERSION).tar.gz,pyyaml-$(PYYAML_VERSION),pyyaml)
	$(call DO_PATCH,pyyaml,pyyaml,-p1)

ifneq ($(wildcard $(BUILD_WORK)/pyyaml/.build_complete),)
pyyaml:
	@echo "Using previously built pyyaml."
else
pyyaml: pyyaml-setup libyaml python3
	cd $(BUILD_WORK)/pyyaml && $(CYTHON_HOST) -3 -o yaml/_yaml.c yaml/_yaml.pyx
	$(PYTHON_HOST) -c 'import sys; assert sys.version_info[:2] == tuple(map(int, "$(PYTHON3_MAJOR_V)".split("."))), "Host Python must match target major/minor"'
	cd $(BUILD_WORK)/pyyaml && pyyaml_host_site=$$($(PYTHON_HOST) -c 'import site; print(":".join(site.getsitepackages()))') && \
		$(DEFAULT_SETUP_PY_ENV) \
		PYTHONPATH="$$(dirname $(BUILD_STAGE)/python3/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/python*/_sysconfigdata__darwin_darwin.py):$$pyyaml_host_site" \
		ARCHFLAGS="-arch $(MEMO_ARCH)" \
		CFLAGS="$(CFLAGS) -I$(BUILD_BASE)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include/python$(PYTHON3_MAJOR_V)" \
		LDSHARED="$(CC) -bundle -lpython$(PYTHON3_MAJOR_V)" \
		$(PYTHON_HOST) ./setup.py --with-libyaml \
		build \
		--executable="$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/python3" \
		install \
		--prefix="$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)" \
		--root="$(BUILD_STAGE)/pyyaml" \
		--install-lib="$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/python3/dist-packages"
	find $(BUILD_STAGE)/pyyaml -name __pycache__ -prune -exec rm -rf {} \;
	$(call AFTER_BUILD)
endif
pyyaml-package: pyyaml-stage
	# pyyaml.mk Package Structure
	rm -rf $(BUILD_DIST)/python3-yaml
	mkdir -p $(BUILD_DIST)/python3-yaml/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)

	# pyyaml.mk Prep python3-yaml
	cp -a $(BUILD_STAGE)/pyyaml/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib $(BUILD_DIST)/python3-yaml/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)

	# pyyaml.mk Sign
	$(call SIGN,python3-yaml,general.xml)

	#pyyaml.mk Make .debs
	$(call PACK,python3-yaml,DEB_PYYAML_V)

	# pyyaml.mk Build cleanup
	rm -rf $(BUILD_DIST)/python3-yaml

.PHONY: pyyaml pyyaml-package
