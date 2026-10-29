ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS      += openjdk
OPENJDK_MAJOR_V  := 17
OPENJDK_MINOR_V  := 0
OPENJDK_PATCH_V  := 1
OPENJDK_REVISION := ga
OPENJDK_VERSION  := $(OPENJDK_MAJOR_V).$(OPENJDK_MINOR_V).$(OPENJDK_PATCH_V)-$(OPENJDK_REVISION)
DEB_OPENJDK_V    ?= $(OPENJDK_VERSION)
OPENJDK_BOOT_ARCHIVE := openjdk-17_$(if $(filter Linux,$(UNAME)),linux,macos)-$(if $(filter aarch64 arm64,$(UNAME_M)),aarch64,x64)_bin.tar.gz
OPENJDK_BOOT_ROOT := $(if $(filter Linux,$(UNAME)),jdk-17,jdk-17.jdk)
OPENJDK_BOOT_HOME := $(BUILD_WORK)/boot-jdk.jdk$(if $(filter Linux,$(UNAME)),,/Contents/Home)

# Change "ea" to nothing on general availability...

OPENJDK_VENDOR_ARGS := --with-version-pre= \
		--without-version-opt \
		--with-vendor-bug-url="https://github.com/ProcursusTeam/Procursus/issues" \
		--with-vendor-name=Procursus \
		--with-vendor-url="https://github.com/ProcursusTeam/Procursus" \
		--with-vendor-version-string=Procursus \
		--with-vendor-vm-bug-url="https://github.com/ProcursusTeam/Procursus/issues" \

# It gets mad if you try to make it use the system freetype
# on Darwin so just let it use the bundled one

ifneq (,$(findstring darwin,$(MEMO_TARGET)))
OPENJDK_CONFIG_ARGS := --with-freetype=bundled
else
OPENJDK_CONFIG_ARGS := --with-freetype=system \
		--with-freetype-lib=$(BUILD_BASE)$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib \
		--with-freetype-include=$(BUILD_BASE)$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include
endif

###
# The patches are still horribly ugly, please pay no mind.
# TODO: Try and get libjsound working.
###

openjdk-setup: setup
	$(call DOWNLOAD_FILES,$(BUILD_SOURCE),https://github.com/openjdk/jdk17u/archive/refs/tags/jdk-$(OPENJDK_VERSION).tar.gz)
	$(call DOWNLOAD_FILES,$(BUILD_SOURCE), \
		https://github.com/apple/cups/releases/download/v2.3.3/cups-2.3.3-source.tar.gz \
		https://download.java.net/java/GA/jdk17/0d483333a00540d886896bac774ff48b/35/GPL/$(OPENJDK_BOOT_ARCHIVE))
	$(call EXTRACT_TAR,jdk-$(OPENJDK_VERSION).tar.gz,jdk17u-jdk-$(OPENJDK_VERSION),openjdk)
	$(call EXTRACT_TAR,cups-2.3.3-source.tar.gz,cups-2.3.3,apple-cups)
	$(call EXTRACT_TAR,$(OPENJDK_BOOT_ARCHIVE),$(OPENJDK_BOOT_ROOT),boot-jdk.jdk)
ifeq (,$(findstring darwin,$(MEMO_TARGET)))
	$(call DO_PATCH,openjdk-ios,openjdk,-p1)
	sed -i '/^#include <CFNetwork\/CFNetwork.h>$$/d' $(BUILD_WORK)/openjdk/src/java.base/macosx/native/libnet/DefaultProxySelector.c
	sed -i '/<CoreServices\/CoreServices.h>/a #include <CFNetwork/CFNetwork.h>' $(BUILD_WORK)/openjdk/src/java.base/macosx/native/libnet/DefaultProxySelector.c
	for file in $(BUILD_WORK)/openjdk/src/java.base/macosx/native/libjli/java_md_macosx.m \
	$(BUILD_WORK)/openjdk/src/java.security.jgss/macosx/native/libosxkrb5/SCDynamicStoreConfig.m \
	$(BUILD_WORK)/openjdk/src/java.base/macosx/native/libosxsecurity/KeystoreImpl.m; do \
		sed -i 's|<Cocoa/Cocoa.h>|<Foundation/Foundation.h>|' $$file || exit 1; \
	done
	for file in $(BUILD_WORK)/openjdk/src/java.desktop/share/native/libfontmanager/HBShaper.c \
	$(BUILD_WORK)/openjdk/src/java.desktop/share/native/common/java2d/opengl/OGLFuncs.h \
	$(BUILD_WORK)/openjdk/src/java.desktop/share/native/libmlib_image/mlib_image.h \
	$(BUILD_WORK)/openjdk/src/java.desktop/share/native/libmlib_image/mlib_types.h \
	$(BUILD_WORK)/openjdk/src/java.desktop/share/native/libmlib_image/mlib_ImageAffine.h \
	$(BUILD_WORK)/openjdk/src/java.desktop/share/native/common/java2d/opengl/OGLBlitLoops.c \
	$(BUILD_WORK)/openjdk/src/java.desktop/unix/native/libawt/awt/awt_LoadLibrary.c \
	$(BUILD_WORK)/openjdk/src/java.desktop/unix/native/common/awt/color.h \
	$(BUILD_WORK)/openjdk/src/java.desktop/unix/native/common/awt/utility/rect.h \
	$(BUILD_WORK)/openjdk/src/java.desktop/unix/native/common/awt/awt.h \
	$(BUILD_WORK)/openjdk/src/java.desktop/unix/native/common/awt/img_util_md.h \
	$(BUILD_WORK)/openjdk/src/java.desktop/unix/native/libawt/java2d/j2d_md.h \
	$(BUILD_WORK)/openjdk/src/java.desktop/unix/native/common/java2d/opengl/OGLFuncs_md.h; do \
		sed -i 's|\bMACOSX\b|MACOSXXXXXX|' $$file || exit 1; \
	done
	cp $(BUILD_WORK)/openjdk/make/data/charsetmapping/stdcs-linux $(BUILD_WORK)/openjdk/make/data/charsetmapping/stdcs-macosx
	rm -rf $(BUILD_WORK)/openjdk/src/java.desktop/macosx/
endif

ifneq ($(wildcard $(BUILD_WORK)/openjdk/.build_complete),)
openjdk:
	@echo "Using previously built openjdk."
else
openjdk: openjdk-setup libx11 libxext libxi libxrender libxrandr libxtst freetype libgif harfbuzz lcms2 libpng16 xorgproto fontconfig libjpeg-turbo
	rm -rf $(BUILD_STAGE)/openjdk
	mkdir -p $(BUILD_STAGE)/openjdk/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/jvm
	chmod 0755 $(BUILD_WORK)/openjdk/configure
	cd $(BUILD_WORK)/openjdk && bash ./configure \
		BUILD_CC="$(shell command -v clang) $(CFLAGS_FOR_BUILD)" BUILD_CXX="$(shell command -v clang++) $(CXXFLAGS_FOR_BUILD)" \
		OTOOL="$(OTOOL)" LIPO="$(LIPO)" INSTALL_NAME_TOOL="$(I_N_T)" \
		PKG_CONFIG="$(BUILD_TOOLS)/cross-pkg-config" \
		--disable-warnings-as-errors \
		--prefix=$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib \
		--openjdk-target=$(GNU_HOST_TRIPLE) \
		--with-extra-cflags="$(CFLAGS) $(if $(filter appletvos,$(PLATFORM)),,-DTARGET_OS_OSX)" \
		--with-extra-cxxflags="$(CXXFLAGS) $(if $(filter appletvos,$(PLATFORM)),,-DTARGET_OS_OSX)" \
		--with-extra-ldflags="$(LDFLAGS) -headerpad_max_install_names" \
		--with-sysroot="$(TARGET_SYSROOT)" \
		$(OPENJDK_VENDOR_ARGS) \
		--with-boot-jdk="$(OPENJDK_BOOT_HOME)" \
		$(if $(filter Linux,$(UNAME)),--with-build-jdk="$(OPENJDK_BOOT_HOME)") \
		--with-debug-level=release \
		--with-native-debug-symbols=none \
		--with-jvm-variants=server \
		--with-x=$(BUILD_BASE)$(MEMO_PREFIX)$(MEMO_SUB_PREFIX) \
		--with-cups-include="$(BUILD_WORK)/apple-cups" \
		--with-fontconfig=$(BUILD_BASE)$(MEMO_PREFIX)$(MEMO_SUB_PREFIX) \
		$(OPENJDK_CONFIG_ARGS) \
		--with-libjpeg=system \
		--with-giflib=system \
		--with-libpng=system \
		--with-zlib=system \
		--with-lcms=system \
		--with-harfbuzz=system
	env -u MAKEFLAGS -u MFLAGS -u MAKEOVERRIDES $(MAKE) -C $(BUILD_WORK)/openjdk images \
			JOBS=$(CORE_COUNT)
	cp -a $(BUILD_WORK)/openjdk/build/*/images/jdk $(BUILD_STAGE)/openjdk/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/jvm/java-$(OPENJDK_MAJOR_V)-openjdk
	for dylib in $(BUILD_STAGE)/openjdk/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/jvm/java-$(OPENJDK_MAJOR_V)-openjdk/lib/{,*/}*.dylib; do \
		$(LN_S) $$(basename $$dylib) $$(echo $$dylib | sed s/.dylib//).so; \
	done
	$(call AFTER_BUILD)
endif

openjdk-package: openjdk-stage
	# openjdk.mk Package Structure
	rm -rf $(BUILD_DIST)/openjdk*-{jre,jdk}
	mkdir -p $(BUILD_DIST)/openjdk-$(OPENJDK_MAJOR_V)-{jre,jdk}/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/jvm/java-$(OPENJDK_MAJOR_V)-openjdk/{bin,lib,man/man1} \
		$(BUILD_DIST)/openjdk-{jre,jdk}/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/{bin,share/man/man1}

	# openjdk.mk Prep openjdk-$(OPENJDK_MAJOR_V)-jre
	cp -a $(BUILD_STAGE)/openjdk/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/jvm/java-$(OPENJDK_MAJOR_V)-openjdk/bin/{java,jfr,keytool,rmiregistry} \
		$(BUILD_DIST)/openjdk-$(OPENJDK_MAJOR_V)-jre/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/jvm/java-$(OPENJDK_MAJOR_V)-openjdk/bin
	for bin in $(BUILD_DIST)/openjdk-$(OPENJDK_MAJOR_V)-jre/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/jvm/java-$(OPENJDK_MAJOR_V)-openjdk/bin/*; do \
		$(I_N_T) -add_rpath $(MEMO_LINK_PREFIX)$(MEMO_SUB_PREFIX)/lib/jvm/java-$(OPENJDK_MAJOR_V)-openjdk/lib $$bin; \
	done
	cp -a $(BUILD_STAGE)/openjdk/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/jvm/java-$(OPENJDK_MAJOR_V)-openjdk/man/man1/{java,jfr,keytool,rmiregistry}.1 \
		$(BUILD_DIST)/openjdk-$(OPENJDK_MAJOR_V)-jre/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/jvm/java-$(OPENJDK_MAJOR_V)-openjdk/man/man1
	cp -a $(BUILD_STAGE)/openjdk/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/jvm/java-$(OPENJDK_MAJOR_V)-openjdk/{conf,legal,release} \
		$(BUILD_DIST)/openjdk-$(OPENJDK_MAJOR_V)-jre/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/jvm/java-$(OPENJDK_MAJOR_V)-openjdk
	cp -a $(BUILD_STAGE)/openjdk/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/jvm/java-$(OPENJDK_MAJOR_V)-openjdk/lib/!(src.zip) \
		$(BUILD_DIST)/openjdk-$(OPENJDK_MAJOR_V)-jre/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/jvm/java-$(OPENJDK_MAJOR_V)-openjdk/lib

	# openjdk.mk Prep openjdk-jre
	for bin in java jfr keytool rmiregistry; do \
		$(LN_S) $(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/jvm/java-$(OPENJDK_MAJOR_V)-openjdk/bin/$${bin} $(BUILD_DIST)/openjdk-jre/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/$${bin}; \
		$(LN_S) $(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/jvm/java-$(OPENJDK_MAJOR_V)-openjdk/man/man1/$${bin}.1 $(BUILD_DIST)/openjdk-jre/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/man1/$${bin}.1; \
	done

	# openjdk.mk Prep openjdk-jdk
	for bin in jar jarsigner javac javadoc javap jcmd jconsole jdb jdeprscan jdeps jhsdb jimage jinfo jlink jmap jmod jpackage jps jrunscript jshell jstack jstat jstatd serialver; do \
		$(LN_S) $(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/jvm/java-$(OPENJDK_MAJOR_V)-openjdk/bin/$${bin} $(BUILD_DIST)/openjdk-jdk/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/$${bin}; \
		if [ -f $(BUILD_STAGE)/openjdk/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/jvm/java-$(OPENJDK_MAJOR_V)-openjdk/man/man1/$${bin}.1 ]; then \
			$(LN_S) $(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/jvm/java-$(OPENJDK_MAJOR_V)-openjdk/man/man1/$${bin}.1 $(BUILD_DIST)/openjdk-jdk/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/man1/$${bin}.1; \
		fi; \
	done

	# openjdk.mk Prep openjdk-$(OPENJDK_MAJOR_V)-jdk
	cp -a $(BUILD_STAGE)/openjdk/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/jvm/java-$(OPENJDK_MAJOR_V)-openjdk/bin/!(java|jfr|keytool|rmiregistry) \
		$(BUILD_DIST)/openjdk-$(OPENJDK_MAJOR_V)-jdk/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/jvm/java-$(OPENJDK_MAJOR_V)-openjdk/bin
	for bin in $(BUILD_DIST)/openjdk-$(OPENJDK_MAJOR_V)-jdk/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/jvm/java-$(OPENJDK_MAJOR_V)-openjdk/bin/*; do \
		$(I_N_T) -add_rpath $(MEMO_LINK_PREFIX)$(MEMO_SUB_PREFIX)/lib/jvm/java-$(OPENJDK_MAJOR_V)-openjdk/lib $$bin; \
	done
	cp -a $(BUILD_STAGE)/openjdk/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/jvm/java-$(OPENJDK_MAJOR_V)-openjdk/{demo,include,jmods} \
		$(BUILD_DIST)/openjdk-$(OPENJDK_MAJOR_V)-jdk/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/jvm/java-$(OPENJDK_MAJOR_V)-openjdk
	cp -a $(BUILD_STAGE)/openjdk/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/jvm/java-$(OPENJDK_MAJOR_V)-openjdk/lib/src.zip \
		$(BUILD_DIST)/openjdk-$(OPENJDK_MAJOR_V)-jdk/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/jvm/java-$(OPENJDK_MAJOR_V)-openjdk/lib
	cp -a $(BUILD_STAGE)/openjdk/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/jvm/java-$(OPENJDK_MAJOR_V)-openjdk/man/man1/!(java.1|jfr.1|keytool.1|rmiregistry.1) \
		$(BUILD_DIST)/openjdk-$(OPENJDK_MAJOR_V)-jdk/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/jvm/java-$(OPENJDK_MAJOR_V)-openjdk/man/man1

	# Setup openjdk-wrapper
	mkdir -p $(BUILD_DIST)/openjdk-$(OPENJDK_MAJOR_V)-wrapper/Library/Java/JavaVirtualMachines/procursus.jdk/Contents/MacOS
	ln -s $(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/jvm/java-$(OPENJDK_MAJOR_V)-openjdk \
			$(BUILD_DIST)/openjdk-$(OPENJDK_MAJOR_V)-wrapper/Library/Java/JavaVirtualMachines/procursus.jdk/Contents/Home
	ln -s ../Home/lib/libjli.dylib $(BUILD_DIST)/openjdk-$(OPENJDK_MAJOR_V)-wrapper/Library/Java/JavaVirtualMachines/procursus.jdk/Contents/MacOS/

	cp $(BUILD_MISC)/openjdk-$(OPENJDK_MAJOR_V).infoplist $(BUILD_DIST)/openjdk-$(OPENJDK_MAJOR_V)-wrapper/Library/Java/JavaVirtualMachines/procursus.jdk/Contents/Info.plist


	# openjdk.mk Sign
ifneq (,$(findstring darwin,$(MEMO_TARGET)))
	$(call SIGN,openjdk-$(OPENJDK_MAJOR_V)-jre,qemu-ios.xml,jre-macos.xml,nohardened)
	$(call SIGN,openjdk-$(OPENJDK_MAJOR_V)-jre,qemu-ios.xml,jre-macos.xml,nohardened)
else
	$(call SIGN,openjdk-$(OPENJDK_MAJOR_V)-jdk,qemu-ios.xml)
	$(call SIGN,openjdk-$(OPENJDK_MAJOR_V)-jre,qemu-ios.xml)
endif

	# openjdk.mk Make .debs
ifneq (,$(findstring darwin,$(MEMO_TARGET)))
	$(call PACK,openjdk-$(OPENJDK_MAJOR_V)-wrapper,DEB_OPENJDK_V)
	$(call PACK,openjdk-wrapper,DEB_OPENJDK_V)
endif
	$(call PACK,openjdk-$(OPENJDK_MAJOR_V)-jdk,DEB_OPENJDK_V)
	$(call PACK,openjdk-$(OPENJDK_MAJOR_V)-jre,DEB_OPENJDK_V)
	$(call PACK,openjdk-jdk,DEB_OPENJDK_V)
	$(call PACK,openjdk-jre,DEB_OPENJDK_V)

	# openjdk.mk Build cleanup
	rm -rf $(BUILD_DIST)/openjdk*-{jre,jdk,wrapper}


.PHON/: openjdk openjdk-package
