ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS    += jtool2
JTOOL2_VERSION := 2020.12.21
DEB_JTOOL2_V   ?= $(JTOOL2_VERSION)

jtool2-setup: setup
ifeq ($(MEMO_TARGET),iphoneos-arm64-roothide)
	# The vendor's mutable tarball now contains a different jtool2 binary.
	# Reuse the frozen, exact-version iOS distribution, not a source build.
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/jtool2_2020.12.21_iphoneos-arm64.deb,https://apt.procurs.us/pool/main/iphoneos-arm64-rootless/1900/jtool2/jtool2_2020.12.21_iphoneos-arm64.deb)
	echo 'dc3c749337c3506e52ec075f213e7272ce154694bc1f7405fbbb0dd03c6d3048  $(BUILD_SOURCE)/jtool2_2020.12.21_iphoneos-arm64.deb' | sha256sum -c -
	rm -rf $(BUILD_WORK)/jtool2 && mkdir -p $(BUILD_WORK)/jtool2
	$(DPKG_DEB) --extract $(BUILD_SOURCE)/jtool2_2020.12.21_iphoneos-arm64.deb $(BUILD_WORK)/jtool2
else
	$(call DOWNLOAD_FILES,$(BUILD_SOURCE),http://newosxbook.com/tools/jtool2.tgz)
	rm -rf $(BUILD_WORK)/jtool2 && mkdir -p $(BUILD_WORK)/jtool2 && pushd $(BUILD_WORK)/jtool2 && tar -C . -xf $(BUILD_SOURCE)/jtool2.tgz && popd
endif

ifneq ($(wildcard $(BUILD_WORK)/jtool2/.build_complete),)
jtool2:
	@echo "Using previously built jtool2."
else
jtool2: jtool2-setup
ifeq ($(MEMO_TARGET),iphoneos-arm64-roothide)
	mkdir -p $(BUILD_STAGE)/jtool2/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin
	cp -a $(BUILD_WORK)/jtool2/var/jb/usr/bin/{jtool2,disarm} $(BUILD_STAGE)/jtool2/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin
	# Both pinned tools are already thin arm64, min iOS 8.0 (SDK unspecified).
	# Their sole ordinary-rootless path is this rpath; retain original code.
	$(I_N_T) -delete_rpath /var/jb/usr/lib $(BUILD_STAGE)/jtool2/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/jtool2
	$(I_N_T) -delete_rpath /var/jb/usr/lib $(BUILD_STAGE)/jtool2/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/disarm
else
	-LIPO_OUTPUT_TARGET=""; \
	[[ $$(echo $(MEMO_TARGET) | cut -d- -f2) = "amd64" ]] && LIPO_OUTPUT_TARGET="x86_64" || LIPO_OUTPUT_TARGET="arm64"; \
	mkdir -p $(BUILD_STAGE)/jtool2/$(MEMO_PREFIX)/$(MEMO_SUB_PREFIX)/bin; \
	$(LIPO) $(BUILD_WORK)/jtool2/jtool2 -thin $$LIPO_OUTPUT_TARGET -output $(BUILD_STAGE)/jtool2/$(MEMO_PREFIX)/$(MEMO_SUB_PREFIX)/bin/jtool2; \
	$(LIPO) $(BUILD_WORK)/jtool2/disarm -thin $$LIPO_OUTPUT_TARGET -output $(BUILD_STAGE)/jtool2/$(MEMO_PREFIX)/$(MEMO_SUB_PREFIX)/bin/disarm; \
	[ $(MEMO_TARGET) = "darwin-arm64" ] && \
		vtool -arch arm64 -remove-build-version ios -output $(BUILD_STAGE)/jtool2/$(MEMO_PREFIX)/$(MEMO_SUB_PREFIX)/bin/jtool2 $(BUILD_STAGE)/jtool2/$(MEMO_PREFIX)/$(MEMO_SUB_PREFIX)/bin/jtool2 && \
		vtool -arch arm64 -remove-build-version ios -output $(BUILD_STAGE)/jtool2/$(MEMO_PREFIX)/$(MEMO_SUB_PREFIX)/bin/disarm $(BUILD_STAGE)/jtool2/$(MEMO_PREFIX)/$(MEMO_SUB_PREFIX)/bin/disarm
endif
	$(call AFTER_BUILD)
endif

jtool2-package: jtool2-stage
	# jtool2.mk Package Structure
	mkdir -p $(BUILD_DIST)/jtool2/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin

	# jtool2.mk Prep jtool2
	cp -a $(BUILD_STAGE)/jtool2/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/jtool2 $(BUILD_DIST)/jtool2/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin
	cp -a $(BUILD_STAGE)/jtool2/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/disarm $(BUILD_DIST)/jtool2/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin

	# jtool2.mk Sign
	$(call SIGN,jtool2,general.xml)

	# jtool2.mk Make .debs
	$(call PACK,jtool2,DEB_JTOOL2_V)

	# jtool2.mk Build cleanup
	rm -rf $(BUILD_DIST)/jtool2

.PHONY: jtool2 jtool2-package
