ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

ifeq (,$(findstring darwin,$(MEMO_TARGET)))

SUBPROJECTS                   += gettext-localizations
GETTEXT-LOCALIZATIONS_VERSION := 2020.10.07
DEB_GETTEXT-LOCALIZATIONS_V   ?= $(GETTEXT-LOCALIZATIONS_VERSION)
GETTEXT_LOCALIZATIONS_INPUT ?= $(if $(filter Darwin,$(UNAME)),/usr/share/locale)

ifneq ($(wildcard $(BUILD_WORK)/gettext-localizations/.build_complete),)
gettext-localizations:
	@echo "Using previously built gettext-localizations."
else
gettext-localizations: setup
	test -n "$(GETTEXT_LOCALIZATIONS_INPUT)" && test -f "$(GETTEXT_LOCALIZATIONS_INPUT)/en_US.UTF-8/LC_CTYPE" && test -f "$(GETTEXT_LOCALIZATIONS_INPUT)/en_US.UTF-8/LC_COLLATE" || { echo "Set GETTEXT_LOCALIZATIONS_INPUT to a copy of Mac /usr/share/locale." >&2; exit 1; }
	mkdir -p $(BUILD_STAGE)/gettext-localizations/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share
	mkdir -p $(BUILD_STAGE)/gettext-localizations/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/locale
	cp -af "$(GETTEXT_LOCALIZATIONS_INPUT)/." $(BUILD_STAGE)/gettext-localizations/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/locale/
	rm -f $(BUILD_STAGE)/gettext-localizations/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/locale/locale.alias
endif

gettext-localizations-package: gettext-localizations-stage
	# gettext-localizations.mk Package Structure
	rm -rf $(BUILD_DIST)/gettext-localizations

	# gettext-localizations.mk Prep gettext-localizations
	cp -a $(BUILD_STAGE)/gettext-localizations $(BUILD_DIST)

	# gettext-localizations.mk Make .debs
	$(call PACK,gettext-localizations,DEB_GETTEXT-LOCALIZATIONS_V)

	# gettext-localizations.mk Build cleanup
	rm -rf $(BUILD_DIST)/gettext-localizations

.PHONY: gettext-localizations gettext-localizations-package

endif
