ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS += npm
NPM_VERSION := 8.1.1
DEB_NPM_V   ?= $(NPM_VERSION)
NPM_NODE_FOR_BUILD ?= node

npm-setup: setup
	$(call DOWNLOAD_FILES,$(BUILD_SOURCE),https://registry.npmjs.org/npm/-/npm-$(NPM_VERSION).tgz)
	@echo "f2481c4e0e784a312835b1a6190fe753966066b716d9165b3b8b9305c5ce4088  $(BUILD_SOURCE)/npm-$(NPM_VERSION).tgz" | shasum -a 256 -c -
	$(call EXTRACT_TAR,npm-$(NPM_VERSION).tgz,package,npm)

ifneq ($(wildcard $(BUILD_WORK)/npm/.build_complete),)
npm:
	@echo "Using previously built npm."
else
npm: npm-setup
	mkdir -p $(BUILD_STAGE)/npm/$(MEMO_PREFIX)/{etc,$(MEMO_SUB_PREFIX)/share}
	cp -a $(BUILD_WORK)/npm $(BUILD_STAGE)/npm/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share
	mkdir -p $(BUILD_ROOT)/npm-cache
	: > $(BUILD_ROOT)/npm-cache/user.npmrc
	: > $(BUILD_ROOT)/npm-cache/global.npmrc
	$(NPM_NODE_FOR_BUILD) $(BUILD_WORK)/npm/bin/npm-cli.js install \
		-ddd --global --offline --no-audit --no-fund --update-notifier=false \
		--cache="$(BUILD_ROOT)/npm-cache" \
		--userconfig="$(BUILD_ROOT)/npm-cache/user.npmrc" \
		--globalconfig="$(BUILD_ROOT)/npm-cache/global.npmrc" \
		--prefix="$(BUILD_STAGE)/npm/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)" \
		$(BUILD_STAGE)/npm/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/npm
	printf '%s\n' '# DO NOT MODIFY THIS FILE - use /etc/npmrc instead.' \
		'globalconfig=$(MEMO_PREFIX)/etc/npmrc' \
		'globalignorefile=$(MEMO_PREFIX)/etc/npmignore' \
		'prefix=$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)' > $(BUILD_STAGE)/npm/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/node_modules/npm/npmrc
	cp -a $(BUILD_WORK)/npm/package.json $(BUILD_STAGE)/npm/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/npm
	touch $(BUILD_STAGE)/npm/$(MEMO_PREFIX)/etc/npmrc
	mkdir -p $(BUILD_STAGE)/npm/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/nodejs
	$(LN_S) ../npm $(BUILD_STAGE)/npm/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/nodejs/npm
	$(call AFTER_BUILD)
endif

npm-package: npm-stage
	# npm.mk Package Structure
	rm -rf $(BUILD_DIST)/npm
	mkdir -p $(BUILD_DIST)/npm

	# npm.mk Prep npm
	cp -a $(BUILD_STAGE)/npm $(BUILD_DIST)

	# npm.mk Make .debs
	$(call PACK,npm,DEB_NPM_V)

	# npm.mk Build cleanup
	rm -rf $(BUILD_DIST)/npm

.PHONY: npm npm-package
