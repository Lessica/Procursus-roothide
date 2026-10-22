ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

ifneq (,$(findstring roothide,$(MEMO_TARGET)))
STRAPPROJECTS += roothide
else
SUBPROJECTS += roothide
endif

ROOTHIDE_VERSION  := 0.1.0
ROOTHIDE_COMMIT  := 7764c54759009272b4f2f23c18c62b21794fe6dd
DEB_ROOTHIDE_V    ?= $(ROOTHIDE_VERSION)
export DEB_ROOTHIDE_V

# Optional cross-host input, produced only by roothide-xcode-export below.
ROOTHIDE_XCODE_INPUT ?=
ROOTHIDE_XCODE_OUTPUT ?= $(BUILD_WORK)/libroothide-xcode.tar
ROOTHIDE_BINARIES := roothideinit.dylib libroothide.dylib libvroot.dylib libvrootapi.dylib updatelink symredirect jbrand jbroot rootfs
ROOTHIDE_INPUT_ID = { printf '%s\n' '$(ROOTHIDE_COMMIT)' '$(MEMO_TARGET)' '$(MEMO_CFVER)' '$(MEMO_PREFIX)' '$(MEMO_SUB_PREFIX)' '$(MEMO_ALT_PREFIX)'; \
	cd "$(REPO_BASE)" && sha256sum makefiles/roothide.mk build_patch/roothide/* build_misc/roothide/* build_misc/libiosexec/*; } | sha256sum | cut -d' ' -f1

roothide-setup: setup
	$(call GITHUB_ARCHIVE,roothide,libroothide,$(ROOTHIDE_COMMIT),$(ROOTHIDE_COMMIT))
	$(call EXTRACT_TAR,libroothide-$(ROOTHIDE_COMMIT).tar.gz,libroothide-$(ROOTHIDE_COMMIT),libroothide)
	$(call DO_PATCH,roothide,libroothide,-p1)

# Compile without packaging: Linux performs the normal AFTER_BUILD/SIGN/PACK.
roothide-compile: roothide-setup
	$(MAKE) -C $(BUILD_WORK)/libroothide clean
	CFLAGS="$(CFLAGS) -DLIBIOSEXEC_INTERNAL" LDFLAGS="$(filter-out -liosexec,$(LDFLAGS))" $(MAKE) -C $(BUILD_WORK)/libroothide all

roothide-xcode-export: .SHELLFLAGS=-e -o pipefail -c
roothide-xcode-export: roothide-compile
	test "$(UNAME)" = Darwin && test "$(PLATFORM)" = iphoneos
	cd $(BUILD_WORK)/libroothide; for lib in *.dylib; do xcrun lipo "$$lib" -verify_arch arm64 arm64e; done
	$(ROOTHIDE_INPUT_ID) > $(BUILD_WORK)/libroothide/input-id
	cd $(BUILD_WORK)/libroothide && sha256sum $(ROOTHIDE_BINARIES) updatelinks.sh > SHA256SUMS
	{ xcodebuild -version; "$(CC)" --version; printf 'SDK: %s\n' "$(TARGET_SYSROOT)"; } > $(BUILD_WORK)/libroothide/toolchain.txt
	tar -cf "$(ROOTHIDE_XCODE_OUTPUT).tmp" -C $(BUILD_WORK)/libroothide $(ROOTHIDE_BINARIES) updatelinks.sh input-id SHA256SUMS toolchain.txt
	mv "$(ROOTHIDE_XCODE_OUTPUT).tmp" "$(ROOTHIDE_XCODE_OUTPUT)"

ifneq ($(ROOTHIDE_XCODE_INPUT),)
ROOTHIDE_RESULT := $(BUILD_WORK)/libroothide-xcode
roothide-xcode-check: .SHELLFLAGS=-e -o pipefail -c
roothide-xcode-check:
	mkdir -p "$(ROOTHIDE_RESULT)"
	tar -xf "$(ROOTHIDE_XCODE_INPUT)" -C "$(ROOTHIDE_RESULT)"
	test "$$($(ROOTHIDE_INPUT_ID))" = "$$(cat "$(ROOTHIDE_RESULT)/input-id")" || { echo 'libroothide Xcode input does not match this recipe/target; rebuild roothide-xcode-export.' >&2; exit 1; }
	cd "$(ROOTHIDE_RESULT)" && sha256sum -c SHA256SUMS
	for lib in roothideinit libroothide libvroot libvrootapi; do $(LIPO) "$(ROOTHIDE_RESULT)/$$lib.dylib" -verify_arch arm64 arm64e; done
roothide: roothide-xcode-check
else
ROOTHIDE_RESULT := $(BUILD_WORK)/libroothide
endif

ifneq ($(wildcard $(BUILD_WORK)/roothide/.build_complete),)
roothide:
	@echo "Using previously built roothide."
else
ifeq (,$(findstring darwin,$(MEMO_TARGET)))
roothide: roothide-setup base
else
roothide: roothide-setup
endif
	mkdir -p $(BUILD_STAGE)/roothide/$(MEMO_PREFIX)/{var/mobile,etc,$(MEMO_SUB_PREFIX)/{bin,sbin,lib,libexec}}
	
	mkdir -p $(BUILD_STAGE)/roothide/$(MEMO_PREFIX)/private
	$(LN_S) $(MEMO_ROOTFS)/private/preboot $(BUILD_STAGE)/roothide/$(MEMO_PREFIX)/private/preboot
	$(LN_S) ../var $(BUILD_STAGE)/roothide/$(MEMO_PREFIX)/private/var
	$(LN_S) ../tmp $(BUILD_STAGE)/roothide/$(MEMO_PREFIX)/var/tmp

	$(LN_S) $(MEMO_ROOTFS)/private/var/containers $(BUILD_STAGE)/roothide/$(MEMO_PREFIX)/var/containers
	$(LN_S) $(MEMO_ROOTFS)/private/var/mobile/Containers $(BUILD_STAGE)/roothide/$(MEMO_PREFIX)/var/mobile/Containers

	$(LN_S) $(MEMO_ROOTFS)/etc/hosts $(BUILD_STAGE)/roothide/$(MEMO_PREFIX)/etc/hosts
	$(LN_S) $(MEMO_ROOTFS)/etc/hosts.equiv $(BUILD_STAGE)/roothide/$(MEMO_PREFIX)/etc/hosts.equiv

	mkdir -p $(BUILD_STAGE)/roothide/$(MEMO_PREFIX)/usr/share/misc
	$(LN_S) $(MEMO_ROOTFS)/usr/share/misc/trace.codes $(BUILD_STAGE)/roothide/$(MEMO_PREFIX)/usr/share/misc/trace.codes
	$(LN_S) $(MEMO_ROOTFS)/usr/share/zoneinfo $(BUILD_STAGE)/roothide/$(MEMO_PREFIX)/usr/share/zoneinfo

	mkdir -p $(BUILD_STAGE)/roothide/$(MEMO_PREFIX)/var/db
	$(LN_S) $(MEMO_ROOTFS)/var/db/timezone $(BUILD_STAGE)/roothide/$(MEMO_PREFIX)/var/db/timezone

	mkdir -p $(BUILD_STAGE)/roothide/$(MEMO_PREFIX)/var/run
	$(LN_S) $(MEMO_ROOTFS)/var/run/utmpx $(BUILD_STAGE)/roothide/$(MEMO_PREFIX)/var/run/utmpx

	mkdir -p $(BUILD_STAGE)/roothide/$(MEMO_PREFIX)/bin
	$(LN_S) $(MEMO_ROOTFS)/bin/df $(BUILD_STAGE)/roothide/$(MEMO_PREFIX)/bin/df
	mkdir -p $(BUILD_STAGE)/roothide/$(MEMO_PREFIX)/sbin
	$(LN_S) $(MEMO_ROOTFS)/sbin/mount $(BUILD_STAGE)/roothide/$(MEMO_PREFIX)/sbin/mount

	mkdir -p $(BUILD_STAGE)/roothide/$(MEMO_PREFIX)/System/Library/CoreServices/
	$(LN_S) $(MEMO_ROOTFS)/System/Library/CoreServices/SystemVersion.plist $(BUILD_STAGE)/roothide/$(MEMO_PREFIX)/System/Library/CoreServices/SystemVersion.plist

ifeq ($(ROOTHIDE_XCODE_INPUT),)
	$(MAKE) -C $(BUILD_WORK)/libroothide clean
	CFLAGS="$(CFLAGS) -DLIBIOSEXEC_INTERNAL" LDFLAGS="$(filter-out -liosexec,$(LDFLAGS))" $(MAKE) -C $(BUILD_WORK)/libroothide all
endif

	cp -a $(ROOTHIDE_RESULT)/roothideinit.dylib	$(BUILD_STAGE)/roothide/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/
	cp -a $(ROOTHIDE_RESULT)/libroothide.dylib	$(BUILD_STAGE)/roothide/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/
	cp -a $(ROOTHIDE_RESULT)/libvroot.dylib	$(BUILD_STAGE)/roothide/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/
	cp -a $(ROOTHIDE_RESULT)/libvrootapi.dylib	$(BUILD_STAGE)/roothide/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/
	cp -a $(ROOTHIDE_RESULT)/updatelink	$(BUILD_STAGE)/roothide/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/libexec/
	cp -a $(ROOTHIDE_RESULT)/updatelinks.sh	$(BUILD_STAGE)/roothide/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/libexec/
	cp -a $(ROOTHIDE_RESULT)/jbrand	$(BUILD_STAGE)/roothide/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/
	cp -a $(ROOTHIDE_RESULT)/jbroot	$(BUILD_STAGE)/roothide/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/
	cp -a $(ROOTHIDE_RESULT)/rootfs	$(BUILD_STAGE)/roothide/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/
	cp -a $(ROOTHIDE_RESULT)/symredirect	$(BUILD_STAGE)/roothide/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/

	$(call AFTER_BUILD,,,,NO-VROOT)
endif

ROOTHIDE_METADATA = chown -hR 501:501 "$$1"/$(MEMO_PREFIX)/var/mobile

roothide-package: roothide-stage
	# roothide.mk Package Structure
	rm -rf $(BUILD_DIST)/roothide{,-dev}

	# roothide.mk Prep roothide
	cp -a $(BUILD_STAGE)/roothide $(BUILD_DIST)

	mkdir -p $(BUILD_DIST)/roothide-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/
	mv $(BUILD_DIST)/roothide/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/symredirect $(BUILD_DIST)/roothide-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/

	# roothide.mk Sign
	$(call SIGN,roothide,general.xml)
	
	# roothide.mk Make .debs
	$(call PACK,roothide,DEB_ROOTHIDE_V,$(ROOTHIDE_METADATA))

	# roothide.mk Sign
	$(call SIGN,roothide-dev,general.xml)
	
	# roothide.mk Make .debs
	$(call PACK,roothide-dev,DEB_ROOTHIDE_V)

	# roothide.mk Build cleanup
	rm -rf $(BUILD_DIST)/roothide{,-dev}

.PHONY: roothide roothide-package roothide-compile roothide-xcode-export roothide-xcode-check
