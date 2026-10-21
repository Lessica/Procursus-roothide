ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS        += nodejs
NODEJS_VERSION     := 17.0.1
DEB_NODEJS_V       ?= $(NODEJS_VERSION)

SUBPROJECTS        += nodejs-lts
NODEJS_LTS_VERSION := 16.13.0
DEB_NODEJS_LTS_V   ?= $(NODEJS_LTS_VERSION)

ifeq ($(UNAME),Linux)
NODEJS_HOST := linux
else ifeq ($(UNAME),Darwin)
NODEJS_HOST := mac
endif

NODEJS_PYTHON ?= python$(PYTHON3_MAJOR_V)
NODEJS_HOST_ARCH := $(if $(filter x86_64,$(UNAME_M)),x64,$(if $(filter aarch64,$(UNAME_M)),arm64,$(UNAME_M)))
NODEJS_MACOS_HOST_MIN := $(if $(filter Darwin,$(UNAME)),-mmacosx-version-min=$(MACOSX_DEPLOYMENT_TARGET))

NODEJS_MAKE_FLAGS := \
	PYTHON="$(NODEJS_PYTHON)" \
	CFLAGS_host="$(CFLAGS_FOR_BUILD) $(NODEJS_MACOS_HOST_MIN) -Wreturn-type $(if $(filter Darwin,$(UNAME)),-Wno-error=deprecated-non-prototype)" \
	CXXFLAGS_host="$(CXXFLAGS_FOR_BUILD) $(NODEJS_MACOS_HOST_MIN)" \
	CPPFLAGS_host="$(CPPFLAGS_FOR_BUILD)" \
	LDFLAGS_host="$(LDFLAGS_FOR_BUILD) $(NODEJS_MACOS_HOST_MIN)" \
	CFLAGS="$(CFLAGS) -Wreturn-type -Wno-error=deprecated-non-prototype" \
	LDFLAGS="$(LDFLAGS) -undefined dynamic_lookup"

ifeq ($(PLATFORM),iphoneos)
NODEJS_TARGET := ios
endif

NODEJS_COMMON_FLAGS := \
	--prefix=$(MEMO_PREFIX)$(MEMO_SUB_PREFIX) \
	--dest-os=$(NODEJS_TARGET) \
	--dest-cpu=$(MEMO_ARCH) \
	--cross-compiling \
	--without-npm \
	--shared \
	--shared-zlib \
	--shared-libuv \
	--shared-brotli \
	--shared-nghttp2 \
	--shared-cares \
	--openssl-use-def-ca-store \
	--with-intl=full-icu --download=all

nodejs-setup: setup
	$(call GITHUB_ARCHIVE,1Conan,node,v$(NODEJS_VERSION),v$(NODEJS_VERSION)-ios)
	$(call EXTRACT_TAR,node-v$(NODEJS_VERSION).tar.gz,node-$(NODEJS_VERSION)-ios,nodejs)
	$(call DO_PATCH,nodejs,nodejs,-p1)

nodejs-lts-setup: setup
	$(call GITHUB_ARCHIVE,1Conan,node,v$(NODEJS_LTS_VERSION),v$(NODEJS_LTS_VERSION)-ios)
	$(call EXTRACT_TAR,node-v$(NODEJS_LTS_VERSION).tar.gz,node-$(NODEJS_LTS_VERSION)-ios,nodejs-lts)
	$(call DO_PATCH,nodejs,nodejs-lts,-p1)

ifeq (,$(NODEJS_HOST))
nodejs:
	@echo "nodejs building not supported on this host os."
else ifeq (,$(NODEJS_TARGET))
nodejs:
	@echo "nodejs building not supported on this target os."
else ifneq ($(wildcard $(BUILD_WORK)/nodejs/.build_complete),)
nodejs:
	@echo "Using previously built nodejs."
else
nodejs: nodejs-setup nghttp2 openssl brotli libc-ares libuv1
	cd $(BUILD_WORK)/nodejs;\
	CC_host="$(CC_FOR_BUILD) $(NODEJS_MACOS_HOST_MIN)" \
	CXX_host="$(CXX_FOR_BUILD) $(NODEJS_MACOS_HOST_MIN) -std=gnu++14" \
	AR_host="$(AR_FOR_BUILD)" \
	CFLAGS_host="$(CFLAGS_FOR_BUILD) $(NODEJS_MACOS_HOST_MIN) -Wreturn-type $(if $(filter Darwin,$(UNAME)),-Wno-error=deprecated-non-prototype)" \
	CXXFLAGS_host="$(CXXFLAGS_FOR_BUILD) $(NODEJS_MACOS_HOST_MIN)" \
	CPPFLAGS_host="$(CPPFLAGS_FOR_BUILD)" \
	LDFLAGS_host="$(LDFLAGS_FOR_BUILD) $(NODEJS_MACOS_HOST_MIN)" \
	SDKROOT="$(TARGET_SYSROOT)" \
	CXX="$(CXX) -std=gnu++14" \
	CFLAGS="$(CFLAGS) -Wreturn-type" \
	CXXFLAGS="$(CXXFLAGS)" \
	LDFLAGS="$(LDFLAGS) -undefined dynamic_lookup" \
	PKG_CONFIG_PATH="$(BUILD_BASE)$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/pkgconfig" \
	GYP_DEFINES="target_arch=$(MEMO_ARCH) host_arch=$(NODEJS_HOST_ARCH) host_os=$(NODEJS_HOST) target_os=$(NODEJS_TARGET)" \
	$(NODEJS_PYTHON) configure \
		$(NODEJS_COMMON_FLAGS)

	+$(MAKE) -C $(BUILD_WORK)/nodejs $(NODEJS_MAKE_FLAGS) PATH="$(BUILD_WORK)/nodejs/out/tools/bin:$(PATH)"
	# AFTER_BUILD compresses staged manuals; discard the previous install's copies.
	rm -f $(BUILD_STAGE)/nodejs/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/man1/node.1.*
	+$(MAKE) -C $(BUILD_WORK)/nodejs install $(NODEJS_MAKE_FLAGS) PATH="$(BUILD_WORK)/nodejs/out/tools/bin:$(PATH)" \
		DESTDIR=$(BUILD_STAGE)/nodejs

	mkdir -p $(BUILD_STAGE)/nodejs/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin
	cp -a $(BUILD_WORK)/nodejs/out/Release/node $(BUILD_STAGE)/nodejs/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin
	$(call AFTER_BUILD,copy)
endif

ifeq (,$(NODEJS_HOST))
nodejs-lts:
	@echo "nodejs-lts building not supported on this host os."
else ifeq (,$(NODEJS_TARGET))
nodejs-lts:
	@echo "nodejs-lts building not supported on this target os."
else ifneq ($(wildcard $(BUILD_WORK)/nodejs-lts/.build_complete),)
nodejs-lts:
	@echo "Using previously built nodejs-lts."
else
nodejs-lts: nodejs-lts-setup nghttp2 openssl brotli libc-ares libuv1
	cd $(BUILD_WORK)/nodejs-lts;\
	CC_host="$(CC_FOR_BUILD) $(NODEJS_MACOS_HOST_MIN)" \
	CXX_host="$(CXX_FOR_BUILD) $(NODEJS_MACOS_HOST_MIN) -std=gnu++14" \
	AR_host="$(AR_FOR_BUILD)" \
	CFLAGS_host="$(CFLAGS_FOR_BUILD) $(NODEJS_MACOS_HOST_MIN) -Wreturn-type $(if $(filter Darwin,$(UNAME)),-Wno-error=deprecated-non-prototype)" \
	CXXFLAGS_host="$(CXXFLAGS_FOR_BUILD) $(NODEJS_MACOS_HOST_MIN)" \
	CPPFLAGS_host="$(CPPFLAGS_FOR_BUILD)" \
	LDFLAGS_host="$(LDFLAGS_FOR_BUILD) $(NODEJS_MACOS_HOST_MIN)" \
	SDKROOT="$(TARGET_SYSROOT)" \
	CXX="$(CXX) -std=gnu++14" \
	CFLAGS="$(CFLAGS) -Wreturn-type" \
	CXXFLAGS="$(CXXFLAGS)" \
	LDFLAGS="$(LDFLAGS) -undefined dynamic_lookup" \
	PKG_CONFIG_PATH="$(BUILD_BASE)$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/pkgconfig" \
	GYP_DEFINES="target_arch=$(MEMO_ARCH) host_arch=$(NODEJS_HOST_ARCH) host_os=$(NODEJS_HOST) target_os=$(NODEJS_TARGET)" \
	$(NODEJS_PYTHON) configure \
		$(NODEJS_COMMON_FLAGS) \
		--shared-openssl

	+$(MAKE) -C $(BUILD_WORK)/nodejs-lts $(NODEJS_MAKE_FLAGS) PATH="$(BUILD_WORK)/nodejs-lts/out/tools/bin:$(PATH)"
	rm -f $(BUILD_STAGE)/nodejs-lts/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/man1/node.1.*
	+$(MAKE) -C $(BUILD_WORK)/nodejs-lts install $(NODEJS_MAKE_FLAGS) PATH="$(BUILD_WORK)/nodejs-lts/out/tools/bin:$(PATH)" \
		DESTDIR=$(BUILD_STAGE)/nodejs-lts

	mkdir -p $(BUILD_STAGE)/nodejs-lts/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin
	cp -a $(BUILD_WORK)/nodejs-lts/out/Release/node $(BUILD_STAGE)/nodejs-lts/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin
	$(call AFTER_BUILD,copy)
endif

nodejs-package: nodejs-stage
	# nodejs.mk Package Structure
	rm -rf \
		$(BUILD_DIST)/libnode{102,-dev} \
		$(BUILD_DIST)/nodejs
	mkdir -p \
		$(BUILD_DIST)/libnode-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX) \
		$(BUILD_DIST)/libnode102/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share \
		$(BUILD_DIST)/nodejs/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/doc/nodejs

	# nodejs.mk Prep libnode-dev
	cp -a $(BUILD_STAGE)/nodejs/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include $(BUILD_DIST)/libnode-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)

	# nodejs.mk Prep libnode102
	cp -a $(BUILD_STAGE)/nodejs/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib $(BUILD_DIST)/libnode102/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)
	cp -a $(BUILD_STAGE)/nodejs/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/systemtap $(BUILD_DIST)/libnode102/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share

	# nodejs.mk Prep nodejs
	cp -a $(BUILD_STAGE)/nodejs/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin $(BUILD_DIST)/nodejs/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)
	cp -a $(BUILD_STAGE)/nodejs/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/doc/node/* $(BUILD_DIST)/nodejs/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/doc/nodejs
	cp -a $(BUILD_STAGE)/nodejs/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man $(BUILD_DIST)/nodejs/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share

	# nodejs.mk Sign
	$(call SIGN,libnode102,general.xml)
	$(call SIGN,nodejs,general.xml)

	# nodejs.mk Make .debs
	$(call PACK,libnode-dev,DEB_NODEJS_V)
	$(call PACK,libnode102,DEB_NODEJS_V)
	$(call PACK,nodejs,DEB_NODEJS_V)

	# nodejs.mk Build cleanup
	rm -rf \
		$(BUILD_DIST)/libnode{102,-dev} \
		$(BUILD_DIST)/nodejs

nodejs-lts-package: nodejs-lts-stage
	# nodejs.mk Package Structure
	rm -rf \
		$(BUILD_DIST)/libnode{93,-lts-dev} \
		$(BUILD_DIST)/nodejs-lts
	mkdir -p \
		$(BUILD_DIST)/libnode-lts-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX) \
		$(BUILD_DIST)/libnode93/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share \
		$(BUILD_DIST)/nodejs-lts/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/doc/nodejs

	# nodejs.mk Prep libnode-lts-dev
	cp -a $(BUILD_STAGE)/nodejs-lts/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include $(BUILD_DIST)/libnode-lts-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)

	# nodejs.mk Prep libnode93
	cp -a $(BUILD_STAGE)/nodejs-lts/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib $(BUILD_DIST)/libnode93/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)
	cp -a $(BUILD_STAGE)/nodejs-lts/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/systemtap $(BUILD_DIST)/libnode93/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share

	# nodejs.mk Prep nodejs-lts
	cp -a $(BUILD_STAGE)/nodejs-lts/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin $(BUILD_DIST)/nodejs-lts/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)
	cp -a $(BUILD_STAGE)/nodejs-lts/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/doc/node/* $(BUILD_DIST)/nodejs-lts/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/doc/nodejs
	cp -a $(BUILD_STAGE)/nodejs-lts/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man $(BUILD_DIST)/nodejs-lts/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share

	# nodejs.mk Sign
	$(call SIGN,libnode93,general.xml)
	$(call SIGN,nodejs-lts,general.xml)

	# nodejs.mk Make .debs
	$(call PACK,libnode-lts-dev,DEB_NODEJS_LTS_V)
	$(call PACK,libnode93,DEB_NODEJS_LTS_V)
	$(call PACK,nodejs-lts,DEB_NODEJS_LTS_V)

	# nodejs.mk Build cleanup
	rm -rf \
		$(BUILD_DIST)/libnode{93,-lts-dev} \
		$(BUILD_DIST)/nodejs-lts

.PHONY: nodejs nodejs-package nodejs-lts nodejs-lts-package
