ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS    += micro
MICRO_VERSION  := 2.0.10
DEB_MICRO_V    ?= $(MICRO_VERSION)-3

micro-setup: setup
	$(call GITHUB_ARCHIVE,zyedidia,micro,$(MICRO_VERSION),v$(MICRO_VERSION),micro)
	$(call EXTRACT_TAR,micro-$(MICRO_VERSION).tar.gz,micro-$(MICRO_VERSION),micro)
	mkdir -p $(BUILD_STAGE)/micro/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin

ifneq ($(wildcard $(BUILD_WORK)/micro/.build_complete),)
micro:
	@echo "Using previously built micro."
else
micro: micro-setup
	$(MAKE) -C $(BUILD_WORK)/micro build \
		VERSION="$(MICRO_VERSION)" \
		HASH=archive \
		$(DEFAULT_GOLANG_FLAGS)
	$(INSTALL) -Dm755 $(BUILD_WORK)/micro/micro $(BUILD_STAGE)/micro/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/micro
	$(INSTALL) -Dm644 $(BUILD_WORK)/micro/assets/packaging/micro.1 $(BUILD_STAGE)/micro/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/man1/micro.1
	$(INSTALL) -Dm644 $(BUILD_WORK)/micro/assets/packaging/micro.desktop $(BUILD_STAGE)/micro/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/applications/micro.desktop
	$(call AFTER_BUILD)
endif

micro-package: micro-stage
	# micro.mk Package Structure
	rm -rf $(BUILD_DIST)/micro
	mkdir -p $(BUILD_DIST)/micro/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)

	# micro.mk Prep micro
	cp -a $(BUILD_STAGE)/micro/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/{bin,share} $(BUILD_DIST)/micro/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)
	# Reconstruct the manual from the pinned source to avoid duplicate compression
	rm -f $(BUILD_DIST)/micro/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/man1/micro.1*
	$(INSTALL) -Dm644 $(BUILD_WORK)/micro/assets/packaging/micro.1 $(BUILD_DIST)/micro/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/man1/micro.1
	$(MEMO_MANPAGE_COMPCMD) $(MEMO_MANPAGE_COMPFLGS) $(BUILD_DIST)/micro/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/man1/micro.1

	# micro.mk Sign
	$(call SIGN,micro,general.xml)

	# micro.mk Make .debs
	$(call PACK,micro,DEB_MICRO_V)

	# micro.mk Build cleanup
	rm -rf $(BUILD_DIST)/micro

.PHONY: micro micro-package
