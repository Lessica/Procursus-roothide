ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

STRAPPROJECTS    += keyring
KEYRING_VERSION  := 2020.05.09
DEB_KEYRING_V    ?= $(KEYRING_VERSION)-4

ifneq ($(wildcard $(BUILD_STAGE)/keyring/.build_complete),)
keyring:
	@echo "Using previously built keyring."
else
keyring: setup
	mkdir -p $(BUILD_STAGE)/keyring/$(MEMO_PREFIX)/etc/apt/trusted.gpg.d
ifeq (,$(findstring roothide,$(MEMO_TARGET)))
	cp -a $(BUILD_MISC)/keyrings/procursus/memo.gpg $(BUILD_STAGE)/keyring/$(MEMO_PREFIX)/etc/apt/trusted.gpg.d
endif
	$(call AFTER_BUILD)
endif

keyring-package: keyring-stage
	# keyring.mk Package Structure
	rm -rf $(BUILD_DIST)/keyring

	# keyring.mk Prep keyring
	cp -a $(BUILD_STAGE)/keyring $(BUILD_DIST)
ifneq (,$(findstring roothide,$(MEMO_TARGET)))
	@test -n "$(BOOTSTRAP_APT_KEYRING)" || { echo 'Set BOOTSTRAP_APT_KEYRING to the OwnGoal repository public key.' >&2; exit 1; }
	gpg --batch --show-keys "$(BOOTSTRAP_APT_KEYRING)" >/dev/null
	rm -f $(BUILD_DIST)/keyring/$(MEMO_PREFIX)/etc/apt/trusted.gpg.d/memo.gpg
	mkdir -p $(BUILD_DIST)/keyring/$(MEMO_PREFIX)/usr/share/keyrings
	$(INSTALL) -m644 "$(BOOTSTRAP_APT_KEYRING)" $(BUILD_DIST)/keyring/$(MEMO_PREFIX)/usr/share/keyrings/owngoal-procursus.gpg
endif

	# keyring.mk Make .debs
	$(call PACK,keyring,DEB_KEYRING_V)

	# keyring.mk Build cleanup
	rm -rf $(BUILD_DIST)/keyring

.PHONY: keyring keyring-package
