ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS   += texlive
TEXLIVE_VERSION := 2024.2
TEXLIVE_COMMIT := cf0f89c44f5d409c6d1bc0592a808af278611428
TEXLIVE_INSTALLER_COMMIT := d141dbf36a93c17b7984f142bfebdc670eb45eee
TEXLIVE_REPOSITORY := https://ftp.math.utah.edu/pub/tex/historic/systems/texlive/2024/tlnet-final
TEXLIVE_BUILD_PKG_CONFIG_PATH ?=
DEB_TEXLIVE_V   ?= $(TEXLIVE_VERSION)

TLROOT=$(BUILD_STAGE)/texlive$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/texlive
ORIGINAL_BIN_DIR=$(BUILD_STAGE)/texlive$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin
TEXLIVE_INSTALL_ENV_NOCHECK=1 # avoid installer to check the env, it's just a warning and we don't need it

texlive-setup: setup
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/texlive-source-$(TEXLIVE_COMMIT).tar.gz,https://github.com/TeX-Live/texlive-source/archive/$(TEXLIVE_COMMIT).tar.gz)
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/texlive-installer-$(TEXLIVE_INSTALLER_COMMIT).tar.gz,https://github.com/TeX-Live/installer/archive/$(TEXLIVE_INSTALLER_COMMIT).tar.gz)
	@echo "4bc7aceb79bf9bdf18a96edd4d4f8bcd8e2ebcceffe7eb9ea080a1bc759f4653  $(BUILD_SOURCE)/texlive-source-$(TEXLIVE_COMMIT).tar.gz" | shasum -a 256 -c -
	@echo "f8734e873030be0983771bc4353d2d4e3e689070a5df2f478c8e17f2ec31c029  $(BUILD_SOURCE)/texlive-installer-$(TEXLIVE_INSTALLER_COMMIT).tar.gz" | shasum -a 256 -c -
	$(call EXTRACT_TAR,texlive-source-$(TEXLIVE_COMMIT).tar.gz,texlive-source-$(TEXLIVE_COMMIT),texlive)
	$(call EXTRACT_TAR,texlive-installer-$(TEXLIVE_INSTALLER_COMMIT).tar.gz,installer-$(TEXLIVE_INSTALLER_COMMIT),texlive/installer)
	$(call DO_PATCH,texlive,texlive,-p1)

ifneq ($(wildcard $(BUILD_WORK)/texlive/.build_complete),)
texlive:
	@echo "Using previously built texlive."
else
texlive: texlive-setup cairo fontconfig freetype graphite2 harfbuzz icu4c libgd libgmp10 libpixman libpaper libpng16 libx11 libxaw mpfr4 potrace teckit zlib-ng zziplib
	# just to clarify, in autotools convention we call "build" the
	# system that is building the program, and "host" (iOS) the
	# system that will run the program

	# using the host AR instead of build AR
	sed -i "s|AR = ar|AR = @AR@|" $(BUILD_WORK)/texlive/libs/xpdf/Makefile.in
	sed -i "s|ac_subst_vars='am__EXEEXT_FALSE|ac_subst_vars='AR\nam__EXEEXT_FALSE|" $(BUILD_WORK)/texlive/libs/xpdf/configure
	
	# when cross compiling, we must use himktables from PATH
	sed -i 's%./himktables$$(EXEEXT)%eval $$(shell command -v himktables >/dev/null 2>\&1 \&\& echo himktables || echo ./himktables)$$(EXEEXT)%' $(BUILD_WORK)/texlive/texk/web2c/Makefile.in

	# when cross installing we must use build binaries instead of host ones
	sed -i 's|my $$plat_bindir = "$$TEXDIR/bin/$$vars{'"'"'this_platform'"'"'}"|my $$plat_bindir = ""|' $(BUILD_WORK)/texlive/installer/install-tl

	# build some tools explicitly for build (otherwise texlive explodes):
	# 1 - configure for build
	mkdir -p $(BUILD_WORK)/texlive/host
	cd $(BUILD_WORK)/texlive/host && \
		CC= CXX= CPP= AR= LD= RANLIB= STRINGS= STRIP= I_N_T= NM= \
		LIPO= OTOOL= LIBTOOL= PKG_CONFIG_PATH="$(TEXLIVE_BUILD_PKG_CONFIG_PATH)" ../configure \
		-C $(BUILD_CONFIGURE_FLAGS) --disable-native-texlive-build \
		--disable-xindy --disable-all-pkgs --without-x \
		--enable-web2c --with-system-icu
	# 2 - build the native generators used by the cross build.
	$(MAKE) -C $(BUILD_WORK)/texlive/host/texk/kpathsea
	$(MAKE) -C $(BUILD_WORK)/texlive/host/texk/web2c/web2c
	$(MAKE) -C $(BUILD_WORK)/texlive/host/texk/web2c himktables tangle ctangle tie otangle

	# 3 - copy the result where we need it
	mkdir -p $(BUILD_WORK)/texlive/host/bin
	cp $(BUILD_WORK)/texlive/host/texk/web2c/himktables \
		$(BUILD_WORK)/texlive/host/bin/

	# finally build texlive for host
	# 1 - configure for host
	mkdir -p $(BUILD_WORK)/texlive/target
	cd $(BUILD_WORK)/texlive/target && \
		PATH="$(abspath $(BUILD_WORK)/texlive/host/texk/web2c):$$PATH" ../configure -C \
		$(DEFAULT_CONFIGURE_FLAGS) --disable-native-texlive-build \
		--with-system-harfbuzz --with-system-icu \
		--with-system-teckit --with-system-graphite2 \
		--with-system-zziplib --without-system-mpfi \
		--with-system-mpfr --with-system-gmp \
		--with-system-cairo --with-system-pixman \
		--with-system-gd --with-system-potrace \
		--with-system-freetype2 --with-system-libpng \
		--with-system-libpaper --with-system-zlib \
		--disable-xindy --with-banner-add='/iOS' \
		--datarootdir=$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/texlive \
		CXXFLAGS='$(CXXFLAGS) -std=c++17'

	# using the host web2c/web2c for cross building
	rm -rf $(BUILD_WORK)/texlive/target/texk/web2c/web2c
	mkdir -p $(BUILD_WORK)/texlive/target/texk/web2c
	cp -ar $(BUILD_WORK)/texlive/host/texk/web2c/web2c \
		$(BUILD_WORK)/texlive/target/texk/web2c/

	# 2 - make for host
	$(MAKE) -C $(BUILD_WORK)/texlive/target \
		PATH="$(abspath $(BUILD_WORK)/texlive/host/texk/web2c):$(abspath $(BUILD_WORK)/texlive/host/bin):$(PATH)"

	# 3 - make install strip for host
	rm -rf $(BUILD_STAGE)/texlive
	$(MAKE) -C $(BUILD_WORK)/texlive/target world \
		DESTDIR=$(BUILD_STAGE)/texlive

	# Post-install only needs portable shell scripts and native kpsewhich.
	# Do not put cross-compiled engines on the host PATH.
	mkdir -p $(BUILD_WORK)/texlive/host/postinstall-bin
	cp $(BUILD_WORK)/texlive/texk/texlive/linked_scripts/texlive/mktexlsr \
		$(BUILD_WORK)/texlive/host/texk/kpathsea/{kpseaccess,kpsestat,kpsereadlink} $(BUILD_WORK)/texlive/host/postinstall-bin/
	printf '%s\n' '#!/bin/sh' 'TEXMFROOT="$(TLROOT)" TEXMFCNF="$(TLROOT):$(TLROOT)/texmf-dist/web2c" exec "$(BUILD_WORK)/texlive/host/texk/kpathsea/kpsewhich" "$$@"' > $(BUILD_WORK)/texlive/host/postinstall-bin/kpsewhich
	chmod 755 $(BUILD_WORK)/texlive/host/postinstall-bin/{mktexlsr,kpsewhich}

	# create a working installation
	PATH="$(BUILD_WORK)/texlive/host/postinstall-bin:$(PATH)" \
		TEXLIVE_INSTALL_ENV_NOCHECK=1 TEXLIVE_INSTALL_NO_WELCOME=1 \
		$(BUILD_WORK)/texlive/installer/install-tl --no-interaction \
		-repository $(TEXLIVE_REPOSITORY) \
		-custom-bin $(BUILD_STAGE)/texlive$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin \
		-texdir $(TLROOT) -scheme scheme-minimal \
		-texmfhome '~/texmf' -texmfvar '~/.texlive2024/texmf-var' -texmfconfig '~/.texlive2024/texmf-config'

	# fix what the installer did 'cause it sucks (can't preserve symlinks)
	rm -f $(TLROOT)/bin/custom/*
	cd $(TLROOT)/bin/custom/ && \
		for orig_file_path in $(ORIGINAL_BIN_DIR)/*; do \
			file_name=$$(basename -- $$orig_file_path); \
			if [ -L "$$orig_file_path" ]; then \
				real_orig_file_path=$$(realpath $$orig_file_path); \
				if [ "$$(dirname -- $$real_orig_file_path)" = "$(ORIGINAL_BIN_DIR)" ]; then \
					cp -a $$orig_file_path .; \
				else \
					ln -s $$(realpath --relative-to=. "$$orig_file_path") $$file_name; \
				fi \
			else \
				cp -a $$orig_file_path .; \
			fi \
		done

	# fix texlive package manager (it has to run all commands with sudo since it operates system wide)
	# this will mess up some comments and indentations but I'd say that this is not a problem
	perl -i -pe 's/(?<=do_cmd_and_check)\s+//g' $(TLROOT)/texmf-dist/scripts/texlive/tlmgr.pl
	perl -i -pe 's/(?<=do_cmd_and_check)\s+//g' $(TLROOT)/texmf-dist/scripts/texlive/tlmgr.pl # yes we have to run it twice if you are better than me with regex please fix this
	sed -i 's|do_cmd_and_check("|do_cmd_and_check("sudo |' $(TLROOT)/texmf-dist/scripts/texlive/tlmgr.pl

	# replace the original binaries with links to the right ones in TLROOT/bin/custom
	rm -f $(BUILD_STAGE)/texlive$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/*
	cd $(BUILD_STAGE)/texlive$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/ && \
		for bin in $(TLROOT)/bin/custom/*; do \
			bin_name=$$(basename -- $$bin); \
			ln -s $$(realpath -s --relative-to=. "$$bin") $$bin_name; \
		done

	# Generate only portable font maps; all file queries use native kpsewhich.
	PATH="$(BUILD_WORK)/texlive/host/postinstall-bin:$(PATH)" \
		TEXMFROOT="$(TLROOT)" TEXMFSYSVAR="$(TLROOT)/texmf-var" \
		TEXMFSYSCONFIG="$(TLROOT)/texmf-config" TEXMFHOME="$(TLROOT)/texmf-local" \
		TEXMFVAR="$(TLROOT)/texmf-var" TEXMFCONFIG="$(TLROOT)/texmf-config" \
		perl $(TLROOT)/texmf-dist/scripts/texlive/updmap.pl --sys --nohash \
		--cnffile $(TLROOT)/texmf-dist/web2c/updmap.cfg
	# Keep generated maps relocatable; the build transcript is not runtime data.
	find $(TLROOT)/texmf-var/fonts/map -type f -name '*.map' -exec sed -i 's|$(TLROOT)|$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/texlive|g' '{}' \;
	rm -f $(TLROOT)/texmf-var/web2c/updmap.log
	PATH="$(BUILD_WORK)/texlive/host/postinstall-bin:$(PATH)" \
		$(BUILD_WORK)/texlive/host/postinstall-bin/mktexlsr $(TLROOT)/texmf-var $(TLROOT)/texmf-config

	# Installer profiles are reusable target inputs, so strip the staging root.
	for profile in $(TLROOT)/texlive.profile $(TLROOT)/tlpkg/texlive.profile; do \
		if [ -f "$$profile" ]; then sed -i 's|$(TLROOT)|$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/texlive|g' "$$profile"; fi; \
	done

	$(call AFTER_BUILD)
endif

texlive-package: texlive-stage
	# texlive.mk Package Structure
	rm -rf $(BUILD_DIST)/texlive

	# texlive.mk Prep texlive
	cp -a $(BUILD_STAGE)/texlive $(BUILD_DIST)

	# texlive.mk Sign
	$(call SIGN,texlive,general.xml)

	# texlive.mk Make .debs
	$(call PACK,texlive,DEB_TEXLIVE_V)

	# texlive.mk Build cleanup
	rm -rf $(BUILD_DIST)/texlive

.PHONY: texlive texlive-package
