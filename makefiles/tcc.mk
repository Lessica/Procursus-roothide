ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS += tcc
TCC_COMMIT  := 605538f46d277fe0931f72f032a24a675417ee2a
TCC_VERSION := 0.9.27+git20230222.$(shell echo $(TCC_COMMIT) | cut -c -7)
DEB_TCC_V   ?= $(TCC_VERSION)-4

### Host-runnable compilers from this exact source commit build all runtime
### archives.  The installed compiler programs themselves target the device.
TCC_CROSS_TARGETS := i386 x86_64 i386-win32 x86_64-win32 x86_64-osx arm arm64 arm-wince c67 riscv64 arm64-osx

### WARN: Remove 'fixios.patch' when __clear_cache is natively implemented for
###       arm64-osx in tcc.

tcc-setup: setup
	$(call GITHUB_ARCHIVE,TinyCC,tinycc,$(TCC_COMMIT),$(TCC_COMMIT),tcc)
	$(call EXTRACT_TAR,tcc-$(TCC_COMMIT).tar.gz,tinycc-$(TCC_COMMIT),tcc)
	$(call DO_PATCH,tcc,tcc,-p1)
	$(call EXTRACT_TAR,tcc-$(TCC_COMMIT).tar.gz,tinycc-$(TCC_COMMIT),tcc-host)
	$(call DO_PATCH,tcc,tcc-host,-p1)

ifneq ($(wildcard $(BUILD_WORK)/tcc/.build_complete),)
tcc:
	@echo "Using previously built tcc."
else
tcc: tcc-setup
	cd $(BUILD_WORK)/tcc-host && CFLAGS="$(CFLAGS_FOR_BUILD)" CPPFLAGS="$(CPPFLAGS_FOR_BUILD)" LDFLAGS="$(LDFLAGS_FOR_BUILD)" ./configure \
		--cc="$(CC_FOR_BUILD)" --ar="$(AR_FOR_BUILD)" \
		--source-path=$(BUILD_WORK)/tcc-host \
		--extra-cflags="$(CFLAGS_FOR_BUILD)" \
		--extra-ldflags="$(LDFLAGS_FOR_BUILD)" \
		--enable-cross
	+$(MAKE) -C $(BUILD_WORK)/tcc-host \
		CC_FOR_BUILD="$(CC_FOR_BUILD)" \
		CFLAGS="$(CFLAGS_FOR_BUILD)" LDFLAGS="$(LDFLAGS_FOR_BUILD)" \
		tcc $(addsuffix -tcc,$(TCC_CROSS_TARGETS))
	cd $(BUILD_WORK)/tcc && ./configure -C \
		$(DEFAULT_CONFIGURE_FLAGS) \
		--targetos=Darwin \
		--cpu=$(MEMO_ARCH) \
		--cc=$(CC) \
		--ar=$(AR) \
		--source-path=$(BUILD_WORK)/tcc \
		--sysincludepaths=$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/tcc/include:$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include:/usr/local/include:/usr/include:$(ON_DEVICE_SDK_PATH)/usr/include:{B}/include \
		--libpaths=$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/tcc:$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib:/usr/local/lib:/usr/lib:$(ON_DEVICE_SDK_PATH)/usr/lib:{B}/lib \
		--enable-cross
	+$(MAKE) -C $(BUILD_WORK)/tcc \
		PATH="$(BUILD_WORK)/tcc-host:$(PATH)" CC_FOR_BUILD="$(CC_FOR_BUILD)" \
		MEMO_TARGET="$(MEMO_TARGET)" \
		MACOSX_DEPLOYMENT_TARGET=$(MACOSX_DEPLOYMENT_TARGET)
	+$(MAKE) -C $(BUILD_WORK)/tcc install \
		PATH="$(BUILD_WORK)/tcc-host:$(PATH)" CC_FOR_BUILD="$(CC_FOR_BUILD)" \
		MEMO_TARGET="$(MEMO_TARGET)" \
		DESTDIR=$(BUILD_STAGE)/tcc
ifneq ($(filter -flto%,$(CFLAGS)),)
	# Keep installed compiler programs and all host-TCC-generated runtimes.
	# Preserve config.mak and Makefile-added defines/includes in the archive pass.
	+cd $(BUILD_WORK)/tcc && cp config.mak config.mak.lto && \
		trap 'mv -f config.mak.lto config.mak' EXIT && \
		printf '%s\n' 'CFLAGS += -fno-lto' >> config.mak && \
		$(AR) t libtcc.a | while IFS= read -r object; do rm -f "$$object"; done && \
		rm -f libtcc.a && \
		$(MAKE) libtcc.a && \
		cp -a libtcc.a $(BUILD_STAGE)/tcc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/
endif
	$(call AFTER_BUILD)
endif

tcc-package: tcc-stage
	# tcc.mk Package Structure
	rm -rf $(BUILD_DIST)/tcc $(BUILD_DIST)/libtcc-dev
	mkdir -p $(BUILD_DIST)/libtcc-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/{lib,include}

	# tcc.mk Prep tcc
	cp -a $(BUILD_STAGE)/tcc $(BUILD_DIST)
	rm -rf $(BUILD_DIST)/tcc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libtcc.a \
		$(BUILD_DIST)/tcc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include

	# tcc.mk Prep libtcc-dev
	cp -a $(BUILD_STAGE)/tcc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include/libtcc.h $(BUILD_DIST)/libtcc-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include
	cp -a $(BUILD_STAGE)/tcc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libtcc.a $(BUILD_DIST)/libtcc-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# tcc.mk Sign
	$(call SIGN,tcc,general.xml)

	# tcc.mk Make .debs
	$(call PACK,tcc,DEB_TCC_V)
	$(call PACK,libtcc-dev,DEB_TCC_V)

	# tcc.mk Build cleanup
	rm -rf $(BUILD_DIST)/tcc $(BUILD_DIST)/libtcc-dev

.PHONY: tcc tcc-package
