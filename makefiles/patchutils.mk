ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS        += patchutils
PATCHUTILS_VERSION := 0.4.2
DEB_PATCHUTILS_V   ?= $(PATCHUTILS_VERSION)-1

patchutils-setup: setup
	$(call DOWNLOAD_FILES,$(BUILD_SOURCE),https://distfiles.gentoo.org/distfiles/1b/patchutils-$(PATCHUTILS_VERSION).tar.xz)
	# Original cyberelk.net release signature; signer 4629AFE960EC20BEC12E3104B7C20D079491EA63.
	# Gentoo mirrors the archive but not its detached signature.
	cp $(BUILD_MISC)/patchutils/patchutils-$(PATCHUTILS_VERSION).tar.xz.sig $(BUILD_SOURCE)/
	$(call PGP_VERIFY,patchutils-$(PATCHUTILS_VERSION).tar.xz)
	$(call EXTRACT_TAR,patchutils-$(PATCHUTILS_VERSION).tar.xz,patchutils-$(PATCHUTILS_VERSION),patchutils)

ifneq ($(wildcard $(BUILD_WORK)/patchutils/.build_complete),)
patchutils:
	@echo "Using previously built patchutils."
else
patchutils: patchutils-setup pcre2
	cd $(BUILD_WORK)/patchutils && ./configure -C \
		$(DEFAULT_CONFIGURE_FLAGS) \
		--with-pcre2
	+$(MAKE) -C $(BUILD_WORK)/patchutils
	+$(MAKE) -C $(BUILD_WORK)/patchutils install \
		DESTDIR=$(BUILD_STAGE)/patchutils
	sed -i -e "s|$$(cat $(BUILD_STAGE)/patchutils/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/recountdiff | grep \#! | sed 's/#!//')|$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/perl|" \
		-e "s|$$(cat $(BUILD_STAGE)/patchutils/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/gitdiff | grep \#! | sed 's/#!//')|$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/python3|" $(BUILD_STAGE)/patchutils/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/*
	$(call AFTER_BUILD)
endif

patchutils-package: patchutils-stage
	# patchutils.mk Package Structure
	rm -rf $(BUILD_DIST)/patchutils

	# patchutils.mk Prep patchutils
	cp -a $(BUILD_STAGE)/patchutils $(BUILD_DIST)

	# patchutils.mk Sign
	$(call SIGN,patchutils,general.xml)

	# patchutils.mk Make .debs
	$(call PACK,patchutils,DEB_PATCHUTILS_V)

	# patchutils.mk Build cleanup
	rm -rf $(BUILD_DIST)/patchutils

.PHONY: patchutils patchutils-package
