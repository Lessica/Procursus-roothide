ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS        += tsschecker
TSSCHECKER_VERSION := 367
TSSCHECKER_COMMIT  := 9e7762e0edcc4821635b96feddf232b930c34e90
# Gitlink recorded by the fixed tsschecker source commit.
TSSCHECKER_JSSY_COMMIT := 6de3dc6b853d9338b971c1bea0c41465276e640a
DEB_TSSCHECKER_V   ?= $(TSSCHECKER_VERSION)-1

tsschecker-setup: setup
	$(call GITHUB_ARCHIVE,1Conan,tsschecker,$(TSSCHECKER_VERSION),$(TSSCHECKER_VERSION))
	$(call GITHUB_ARCHIVE,tihmstar,jssy,$(TSSCHECKER_JSSY_COMMIT),$(TSSCHECKER_JSSY_COMMIT))
	$(call EXTRACT_TAR,tsschecker-$(TSSCHECKER_VERSION).tar.gz,tsschecker-$(TSSCHECKER_VERSION),tsschecker)
	$(call DO_PATCH,tsschecker,tsschecker,-p1)
	# so EXTRACT_TAR wont fail
	-rmdir $(BUILD_WORK)/tsschecker/external/jssy
	$(call EXTRACT_TAR,jssy-$(TSSCHECKER_JSSY_COMMIT).tar.gz,jssy-$(TSSCHECKER_JSSY_COMMIT),tsschecker/external/jssy)

	sed -i 's/git rev\-list \-\-count HEAD/printf ${TSSCHECKER_VERSION}/g' $(BUILD_WORK)/tsschecker/configure.ac
	sed -i 's/git rev\-parse HEAD/printf ${TSSCHECKER_COMMIT}/g' $(BUILD_WORK)/tsschecker/configure.ac

ifneq ($(wildcard $(BUILD_WORK)/tsschecker/.build_complete),)
tsschecker:
	@echo "Using previously built tsschecker."
else
tsschecker: tsschecker-setup libfragmentzip libplist curl libirecovery
	cd $(BUILD_WORK)/tsschecker && ./autogen.sh \
		$(DEFAULT_CONFIGURE_FLAGS)
	+$(MAKE) -C $(BUILD_WORK)/tsschecker
	+$(MAKE) -C $(BUILD_WORK)/tsschecker install \
		DESTDIR="$(BUILD_STAGE)/tsschecker"
	$(call AFTER_BUILD)
endif

tsschecker-package: tsschecker-stage
	# tsschecker.mk Package Structure
	rm -rf $(BUILD_DIST)/tsschecker

	# tsschecker.mk Prep tsschecker
	cp -a $(BUILD_STAGE)/tsschecker $(BUILD_DIST)

	# tsschecker.mk Sign
	$(call SIGN,tsschecker,general.xml)

	# tsschecker.mk Make .debs
	$(call PACK,tsschecker,DEB_TSSCHECKER_V)

	# tsschecker.mk Build cleanup
	rm -rf $(BUILD_DIST)/tsschecker

.PHONY: tsschecker tsschecker-package
