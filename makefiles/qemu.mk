ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS  += qemu
QEMU_VERSION := 5.2.0
DEB_QEMU_V   ?= $(QEMU_VERSION)-2

qemu-setup: setup
	$(call DOWNLOAD_FILES,$(BUILD_SOURCE),https://github.com/utmapp/qemu/releases/download/v$(QEMU_VERSION)-asi/qemu-$(QEMU_VERSION)-asi.tar.bz2)
	$(call EXTRACT_TAR,qemu-$(QEMU_VERSION)-asi.tar.bz2,qemu-$(QEMU_VERSION)-asi,qemu)
	$(call DO_PATCH,qemu,qemu,-p1)
	if [ -f $(BUILD_WORK)/qemu/VERSION ]; then mv $(BUILD_WORK)/qemu/VERSION $(BUILD_WORK)/qemu/VERSION.txt; fi

ifneq ($(wildcard $(BUILD_WORK)/qemu/.build_complete),)
qemu:
	@echo "Using previously built qemu."
else
qemu: qemu-setup glib2.0 gnutls libjpeg-turbo libpng16 libssh libusb liblzo2 ncurses nettle libpixman libsnappy lzfse gnutls curl libvde capstone openpam zstd
	cd $(BUILD_WORK)/qemu && STRIP="$(STRIP) -x" PKG_CONFIG="$(BUILD_TOOLS)/cross-pkg-config" CFLAGS+=" -DNCURSES_WIDECHAR=1 -I$(BUILD_BASE)$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include/pixman-1" ./configure \
		$(filter-out --enable-silent-rules --enable-shared --enable-static PKG_CONFIG=%,$(DEFAULT_CONFIGURE_FLAGS)) \
		--cpu=aarch64 \
		--cross-prefix="" \
		--cc=$(CC) \
		--objcc=$(CC) \
		--host-cc="$(CC_FOR_BUILD)" \
		--prefix=$(MEMO_PREFIX)$(MEMO_SUB_PREFIX) \
		--disable-bsd-user \
		--disable-guest-agent \
		--enable-curses \
		--enable-libssh \
		--enable-lzfse \
		--enable-vde \
		--enable-zstd \
		--enable-tools \
		--disable-sdl \
		--disable-gtk \
		--enable-modules \
		--enable-module-upgrades
	+$(MAKE) -C $(BUILD_WORK)/qemu install \
		SHELL=bash \
		.SHELLFLAGS="-o pipefail -c" \
		DESTDIR=$(BUILD_STAGE)/qemu
	$(call AFTER_BUILD)
endif

qemu-package: qemu-stage
	# qemu.mk Package Structure
	rm -rf $(BUILD_DIST)/qemu-{utils,block-extra,system-{common,data,arm,mips,misc,ppc,sparc,x86}} $(BUILD_DIST)/qemu-system
	mkdir -p $(BUILD_DIST)/qemu-block-extra/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/qemu \
		$(BUILD_DIST)/qemu-system-data/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/qemu \
		$(BUILD_DIST)/qemu-system-common/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/{bin,{lib,share}/qemu} \
		$(BUILD_DIST)/qemu-system-{arm,mips,x86}/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin \
		$(BUILD_DIST)/qemu-system-{misc,ppc,sparc}/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/{bin,share/qemu} \
		$(BUILD_DIST)/qemu-utils/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin \
		$(BUILD_DIST)/qemu-system

	# qemu.mk Prep qemu-block-extra
	cp -a $(BUILD_STAGE)/qemu/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/qemu/block-*.dylib $(BUILD_DIST)/qemu-block-extra/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/qemu

	# qemu.mk Prep qemu-system-common
	cp -a $(BUILD_STAGE)/qemu/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/qemu/hw-display-virtio-*.dylib $(BUILD_DIST)/qemu-system-common/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/qemu
	cp -a $(BUILD_STAGE)/qemu/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/qemu/ui-curses.dylib $(BUILD_DIST)/qemu-system-common/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/qemu
	cp -a $(BUILD_STAGE)/qemu/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/qemu-storage-daemon $(BUILD_DIST)/qemu-system-common/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin
	cp -a $(BUILD_STAGE)/qemu/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/qemu/trace-events-all $(BUILD_DIST)/qemu-system-common/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/qemu

	# qemu.mk Prep qemu-system-data
	cp -a $(BUILD_STAGE)/qemu/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/qemu/!(trace-events-all|petalogix-*.dtb|bamboo.dtb|canyonlands.dtb|openbios-sparc32|openbios-sparc64) $(BUILD_DIST)/qemu-system-data/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/qemu

	# qemu.mk Prep qemu-system-arm
	cp -a $(BUILD_STAGE)/qemu/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/qemu-system-{arm,aarch64} $(BUILD_DIST)/qemu-system-arm/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin

	# qemu.mk Prep qemu-system-mips
	cp -a $(BUILD_STAGE)/qemu/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/qemu-system-{mips,mips64,mips64el,mipsel} $(BUILD_DIST)/qemu-system-mips/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin

	# qemu.mk Prep qemu-system-misc
	cp -a $(BUILD_STAGE)/qemu/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/qemu-system-{alpha,avr,cris,hppa,m68k,microblaze{,el},moxie,nios2,or1k,riscv32,riscv64,rx,s390x,sh4{,eb},tricore,xtensa{,eb}} $(BUILD_DIST)/qemu-system-misc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin
	cp -a $(BUILD_STAGE)/qemu/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/qemu/petalogix-*.dtb $(BUILD_DIST)/qemu-system-misc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/qemu

	# qemu.mk Prep qemu-system-ppc
	cp -a $(BUILD_STAGE)/qemu/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/qemu-system-ppc{,64} $(BUILD_DIST)/qemu-system-ppc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin
	cp -a $(BUILD_STAGE)/qemu/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/qemu/{bamboo,canyonlands}.dtb $(BUILD_DIST)/qemu-system-ppc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/qemu

	# qemu.mk Prep qemu-system-sparc
	cp -a $(BUILD_STAGE)/qemu/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/qemu-system-{sparc,sparc64} $(BUILD_DIST)/qemu-system-sparc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin
	cp -a $(BUILD_STAGE)/qemu/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/qemu/openbios-sparc{32,64} $(BUILD_DIST)/qemu-system-sparc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/qemu

	# qemu.mk Prep qemu-system-x86
	cp -a $(BUILD_STAGE)/qemu/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/qemu-system-{i386,x86_64} $(BUILD_DIST)/qemu-system-x86/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin

	# qemu.mk Prep qemu-utils
	cp -a $(BUILD_STAGE)/qemu/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/qemu-{img,io,nbd,edid} $(BUILD_DIST)/qemu-utils/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin
	cp -a $(BUILD_STAGE)/qemu/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/elf2dmp $(BUILD_DIST)/qemu-utils/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin

	# qemu.mk Sign
	$(call SIGN,qemu-block-extra,qemu-roothide.xml)
	$(call SIGN,qemu-system-common,qemu-roothide.xml)
	$(call SIGN,qemu-system-arm,qemu-roothide.xml)
	$(call SIGN,qemu-system-mips,qemu-roothide.xml)
	$(call SIGN,qemu-system-misc,qemu-roothide.xml)
	$(call SIGN,qemu-system-ppc,qemu-roothide.xml)
	$(call SIGN,qemu-system-sparc,qemu-roothide.xml)
	$(call SIGN,qemu-system-x86,qemu-roothide.xml)
	$(call SIGN,qemu-utils,qemu-roothide.xml)

	# qemu.mk Make .debs
	$(call PACK,qemu-system,DEB_QEMU_V)
	$(call PACK,qemu-block-extra,DEB_QEMU_V)
	$(call PACK,qemu-system-common,DEB_QEMU_V)
	$(call PACK,qemu-system-data,DEB_QEMU_V)
	$(call PACK,qemu-system-arm,DEB_QEMU_V)
	$(call PACK,qemu-system-mips,DEB_QEMU_V)
	$(call PACK,qemu-system-misc,DEB_QEMU_V)
	$(call PACK,qemu-system-ppc,DEB_QEMU_V)
	$(call PACK,qemu-system-sparc,DEB_QEMU_V)
	$(call PACK,qemu-system-x86,DEB_QEMU_V)
	$(call PACK,qemu-utils,DEB_QEMU_V)

	# qemu.mk Build cleanup
	rm -rf $(BUILD_DIST)/qemu-{utils,block-extra,system-{common,data,arm,mips,misc,ppc,sparc,x86}} $(BUILD_DIST)/qemu-system

.PHONY: qemu qemu-package
