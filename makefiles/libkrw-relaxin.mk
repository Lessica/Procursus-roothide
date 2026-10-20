ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

# Optional integration: invoke libkrw-relaxin-package explicitly.
# Do not add this jailbreak-specific provider to SUBPROJECTS or STRAPPROJECTS.
ifneq (,$(findstring roothide,$(MEMO_TARGET)))
ifeq ($(shell [ "$(MEMO_CFVER)" -ge 1800 ] && echo 1),1)

RELAXIN_PROVIDER_COMMIT := 88548b8033a0302536321206bd2d1411772cd031
LIBKRW_RELAXIN_VERSION  := 2.0.6
DEB_LIBKRW_RELAXIN_V    ?= 0:$(LIBKRW_RELAXIN_VERSION):compat

libkrw-relaxin-setup: setup
	$(call EXTRACT_TAR,libkrw-relaxin-$(RELAXIN_PROVIDER_COMMIT).tar.gz,libkrw-relaxin-$(RELAXIN_PROVIDER_COMMIT),libkrw-relaxin)
	$(call DO_PATCH,libkrw-relaxin,libkrw-relaxin,-p1)
	mkdir -p $(BUILD_STAGE)/libkrw-relaxin/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libkrw

ifneq ($(wildcard $(BUILD_WORK)/libkrw-relaxin/.build_complete),)
libkrw-relaxin:
	@echo "Using previously built libkrw-relaxin."
else
libkrw-relaxin: libkrw-relaxin-setup
	$(CC) $(CFLAGS) -fobjc-arc -fblocks -dynamiclib \
		-I$(BUILD_WORK)/libkrw-relaxin/include \
		-install_name "$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libkrw/libkrw-relaxin.dylib" \
		-o $(BUILD_STAGE)/libkrw-relaxin/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libkrw/libkrw-relaxin.dylib \
		$(BUILD_WORK)/libkrw-relaxin/src/main.c \
		$(LDFLAGS) \
		-L$(BUILD_WORK)/libkrw-relaxin/lib \
		-ljailbreak -framework Foundation
	$(call AFTER_BUILD)
endif

libkrw-relaxin-package: libkrw-relaxin-stage
	rm -rf $(BUILD_DIST)/libkrw-relaxin
	mkdir -p $(BUILD_DIST)/libkrw-relaxin/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libkrw
	cp -a $(BUILD_STAGE)/libkrw-relaxin/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libkrw/libkrw-relaxin.dylib $(BUILD_DIST)/libkrw-relaxin/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libkrw
	$(call SIGN,libkrw-relaxin,general.xml)
	$(call PACK,libkrw-relaxin,DEB_LIBKRW_RELAXIN_V)
	rm -rf $(BUILD_DIST)/libkrw-relaxin

.PHONY: libkrw-relaxin libkrw-relaxin-package

endif
endif
