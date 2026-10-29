ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS   += xonsh
XONSH_COMMIT  := 33a5689db2d23e6c403aa463dddf50f7474241e5
XONSH_VERSION := 0.10.1-$(shell echo $(XONSH_COMMIT) | cut -c -7)
DEB_XONSH_V   ?= $(XONSH_VERSION)
PYTHON_HOST ?= python$(PYTHON3_MAJOR_V)

xonsh-setup: setup
	$(call GITHUB_ARCHIVE,xonsh,xonsh,$(XONSH_COMMIT),$(XONSH_COMMIT))
	$(call EXTRACT_TAR,xonsh-$(XONSH_COMMIT).tar.gz,xonsh-$(XONSH_COMMIT),xonsh)

ifneq ($(wildcard $(BUILD_WORK)/xonsh/.build_complete),)
xonsh:
	@echo "Using previously built xonsh."
else
xonsh: xonsh-setup python3-prompt-toolkit
	cd $(BUILD_WORK)/xonsh && $(PYTHON_HOST) ./setup.py \
		build \
		--executable="$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/python3" \
		install \
		--install-lib="$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/python3/dist-packages" \
		--root=$(BUILD_STAGE)/xonsh \
		--prefix=$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)
	sed -i "s|$$(cat $(BUILD_STAGE)/xonsh/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/xonsh | grep \#! | sed 's/#!//')|$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/python3|" $(BUILD_STAGE)/xonsh/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/*
	find $(BUILD_STAGE)/xonsh -name __pycache__ -prune -exec rm -rf {} \;
	$(call AFTER_BUILD)
endif

xonsh-package: xonsh-stage
	# xonsh.mk Package Structure
	mkdir -p $(BUILD_DIST)/xonsh
	cp -a $(BUILD_STAGE)/xonsh $(BUILD_DIST)

	# xonsh.mk Sign
	$(call SIGN,xonsh,general.xml)

	# PACK collects LICENSE; the source uses a lowercase filename.
	if [ ! -f $(BUILD_WORK)/xonsh/LICENSE ]; then \
		cp $(BUILD_WORK)/xonsh/license $(BUILD_WORK)/xonsh/LICENSE; \
	fi

	# xonsh.mk Make .debs
	$(call PACK,xonsh,DEB_XONSH_V)

	# xonsh.mk Build Cleanup
	rm -rf $(BUILD_DIST)/xonsh

.PHONY: xonsh xonsh-package
