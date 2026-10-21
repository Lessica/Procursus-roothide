ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS += ghc
GHC_VERSION := 9.2.2
DEB_GHC_V   ?= $(GHC_VERSION)-1
GHC_BOOTSTRAP ?= ghc
GHC_SPHINXBUILD ?= sphinx-build

ifeq ($(UNAME),Darwin)
GHC_STAGE0_CC := $(abspath $(BUILD_WORK)/ghc/probin/ghc-stage0-cc)
GHC_STAGE0_LD := $(abspath $(BUILD_WORK)/ghc/probin/ghc-stage0-ld)
GHC_STAGE0_ENV = CC_STAGE0="$(GHC_STAGE0_CC)" LD_STAGE0="$(GHC_STAGE0_LD)"
endif

ghc-setup: setup
	command -v "$(GHC_BOOTSTRAP)" >/dev/null || { echo "GHC native bootstrap compiler not found: $(GHC_BOOTSTRAP)" >&2; exit 1; }
	command -v "$(GHC_SPHINXBUILD)" >/dev/null || { echo "GHC host Sphinx is required; see build_misc/ghc/requirements-sphinx.txt" >&2; exit 1; }
	$(call DOWNLOAD_FILES,$(BUILD_SOURCE),https://downloads.haskell.org/~ghc/$(GHC_VERSION)/ghc-$(GHC_VERSION)-src.tar.xz{$(comma).sig})
	$(call PGP_VERIFY,ghc-$(GHC_VERSION)-src.tar.xz)
	$(call EXTRACT_TAR,ghc-$(GHC_VERSION)-src.tar.xz,ghc-$(GHC_VERSION),ghc)
	$(call DO_PATCH,ghc,ghc,-p1)

#	GHC only properly compiles with prefixed cross tools and no LTO. Do what it wants.
#	No libiosexec right now, as I have not put in the time to make that compile/function properly.
	mkdir -p $(BUILD_WORK)/ghc/probin
ifeq ($(UNAME),Darwin)
	printf '%s\n' '#!/bin/sh' 'exec "$(DEVELOPER_DIR)/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang" -arch "$(UNAME_M)" -mmacosx-version-min="$(MACOSX_DEPLOYMENT_TARGET)" -isysroot "$(MACOSX_SYSROOT)" "$$@"' > "$(GHC_STAGE0_CC)"
	printf '%s\n' '#!/bin/sh' 'exec "$(DEVELOPER_DIR)/Toolchains/XcodeDefault.xctoolchain/usr/bin/ld" -syslibroot "$(MACOSX_SYSROOT)" "$$@"' > "$(GHC_STAGE0_LD)"
	chmod +x "$(GHC_STAGE0_CC)" "$(GHC_STAGE0_LD)"
endif
	printf '%s\n' '#!/bin/sh' 'exec "$(CC)" -DLIBIOSEXEC_INTERNAL $(patsubst -flto=thin,,$(CFLAGS)) "$$@"' > $(BUILD_WORK)/ghc/probin/$(GNU_HOST_TRIPLE)-cc
	chmod +x $(BUILD_WORK)/ghc/probin/$(GNU_HOST_TRIPLE)-cc

	echo "HADDOCK_DOCS=NO" > $(BUILD_WORK)/ghc/mk/build.mk
	echo "BuildFlavour  = quick-cross-ncg" >> $(BUILD_WORK)/ghc/mk/build.mk
	echo "BUILD_MAN=YES" >> $(BUILD_WORK)/ghc/mk/build.mk

ifeq (,$(findstring darwin,$(MEMO_TARGET)))
GHC_CONFIG_ARGS := --disable-large-address-space
endif
ifeq ($(PLATFORM),iphoneos)
GHC_CONFIG_ARGS += --disable-dtrace
endif

ifneq ($(wildcard $(BUILD_WORK)/ghc/.build_complete),)
ghc:
	@echo "Using previously built ghc."
else
ghc: ghc-setup libffi libgmp10 ncurses
	+unset CC CPP CXX CFLAGS CPPFLAGS CXXFLAGS LDFLAGS && export PATH="$(abspath $(BUILD_WORK)/ghc/probin):$(PATH)" && \
	cd $(BUILD_WORK)/ghc && { test ! -f config.cache || sed -i -e '/^ac_cv_path_SPHINXBUILD=/d' -e '/^fp_cv_sphinx_version=/d' config.cache; } && \
	GHC="$(GHC_BOOTSTRAP)" SPHINXBUILD="$(GHC_SPHINXBUILD)" $(GHC_STAGE0_ENV) ./configure -C \
		$(DEFAULT_CONFIGURE_FLAGS) \
		--host="$$($(BUILD_MISC)/config.guess)" \
		--target="$(GNU_HOST_TRIPLE)" \
		--with-system-libffi \
		--with-ffi-includes="$(BUILD_BASE)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include" \
		--with-ffi-libraries="$(BUILD_BASE)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib" \
		--with-gmp-includes="$(BUILD_BASE)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include" \
		--with-gmp-libraries="$(BUILD_BASE)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib" \
		$(GHC_CONFIG_ARGS) && \
	$(MAKE) -S -C $(BUILD_WORK)/ghc PATH="$(abspath $(BUILD_WORK)/ghc/probin):$(PATH)" && \
	$(MAKE) -C $(BUILD_WORK)/ghc install -j1 \
		DESTDIR=$(BUILD_STAGE)/ghc \
		PATH="$(abspath $(BUILD_WORK)/ghc/probin):$(PATH)"
	mv $(BUILD_STAGE)/ghc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/ghc-$(GHC_VERSION) $(BUILD_STAGE)/ghc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/ghc
	for bin in $(BUILD_STAGE)/ghc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/*; do \
		sed -i 's/-$(GHC_VERSION)//' $$bin; \
	done
	for file in $(BUILD_STAGE)/ghc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/ghc/package.conf.d/*.conf; do \
		sed -i \
			-e 's|$(BUILD_BASE)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)|$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)|' \
			-e 's|lib/ghc-$(GHC_VERSION)|lib/ghc|' $$file; \
	done
	sed -i \
		-e 's|$(GNU_HOST_TRIPLE)-cc|cc|' \
		-e 's|$(LD)|ld|' -e 's|$(AR)|ar|' -e 's|$(RANLIB)|ranlib|' -e 's|$(OTOOL)|otool|' \
		-e 's|/usr/bin/false|false|' -e 's|/bin/false|false|' \
		-e 's|--target=[^ "]*|--target=$(LLVM_TARGET)|g' \
		-e 's|("LLVM target", "[^"]*")|("LLVM target", "$(LLVM_TARGET)")|' \
		-e '/cross compiling/s/YES/NO/' \
		$(BUILD_STAGE)/ghc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/ghc/settings
	for bin in $(BUILD_STAGE)/ghc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/ghc/bin/ghc-iserv $(BUILD_STAGE)/ghc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/ghc/bin/ghc-iserv-prof; do \
		if $(OTOOL) -l $$bin | grep -Fq '$(BUILD_BASE)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib'; then \
			$(I_N_T) -delete_rpath "$(BUILD_BASE)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib" $$bin || exit 1; \
		fi; \
	done
	rm -f $(BUILD_STAGE)/ghc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/ghc/package.conf.d/package.cache*
	$(call AFTER_BUILD)
endif

ghc-package: ghc-stage
	# ghc.mk Package Structure
	rm -rf $(BUILD_DIST)/ghc{,-prof}
	mkdir -p $(BUILD_DIST)/ghc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share \
		$(BUILD_DIST)/ghc-prof/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)

	# ghc.mk Prep ghc
	cp -a $(BUILD_STAGE)/ghc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/{bin,lib} $(BUILD_DIST)/ghc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)
	cp -a $(BUILD_STAGE)/ghc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man $(BUILD_DIST)/ghc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share
	find $(BUILD_DIST)/ghc \( -name "*.p_*" -o -name "*_p.*" \) -type f -delete

	# ghc.mk Prep ghc-prof
	cp -a $(BUILD_STAGE)/ghc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib $(BUILD_DIST)/ghc-prof/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)
	find $(BUILD_DIST)/ghc-prof -not -name "*.p_*" -not -name "*_p.*" -type f -delete
	find $(BUILD_DIST)/ghc-prof -type d -empty -delete

	# ghc.mk Sign
	$(call SIGN,ghc,general.xml)
	$(call SIGN,ghc-prof,general.xml)

	# ghc.mk Make .debs
	$(call PACK,ghc,DEB_GHC_V)
	$(call PACK,ghc-prof,DEB_GHC_V)

	# ghc.mk Build cleanup
	rm -rf $(BUILD_DIST)/ghc{,-prof}

.PHONY: ghc ghc-package
