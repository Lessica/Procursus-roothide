ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS        += libsigsegv
LIBSIGSEGV_VERSION := 2.13
DEB_LIBSIGSEGV_V   ?= $(LIBSIGSEGV_VERSION)-1

libsigsegv-setup: setup
	$(call DOWNLOAD_FILES,$(BUILD_SOURCE),https://ftp.gnu.org/gnu/libsigsegv/libsigsegv-$(LIBSIGSEGV_VERSION).tar.gz)
	$(call EXTRACT_TAR,libsigsegv-$(LIBSIGSEGV_VERSION).tar.gz,libsigsegv-$(LIBSIGSEGV_VERSION),libsigsegv)
	sed -i 's|#include <nlist.h>|#include <mach-o/nlist.h>|g' $(BUILD_WORK)/libsigsegv/src/stackvma-mach.c

ifneq ($(wildcard $(BUILD_WORK)/libsigsegv/.build_complete),)
libsigsegv:
	@echo "Using previously built libsigsegv."
else
libsigsegv: libsigsegv-setup
	cd $(BUILD_WORK)/libsigsegv && $(if $(filter appletvos,$(PLATFORM)),sv_cv_fault_posix=yes sv_cv_have_stack_overflow_recovery=yes) ./configure -C \
		$(DEFAULT_CONFIGURE_FLAGS)

ifneq ($(PLATFORM),appletvos)
#	Workaround for bad detection
	echo -e "#undef CFG_FAULT\n \
#define CFG_FAULT \"fault-macos.h\"\n \
#undef CFG_HANDLER\n \
#define CFG_HANDLER \"handler-macos.c\"\n \
#undef CFG_MACHFAULT\n \
#define CFG_MACHFAULT \"machfault-macos.h\"\n \
" >> $(BUILD_WORK)/libsigsegv/config.h
endif

	+$(MAKE) -C $(BUILD_WORK)/libsigsegv
	+$(MAKE) -C $(BUILD_WORK)/libsigsegv install \
		DESTDIR=$(BUILD_STAGE)/libsigsegv
ifneq ($(filter -flto%,$(CFLAGS)),)
	# Retain the configured Darwin fault handlers and installed LTO dylib.
	rm -f $(BUILD_WORK)/libsigsegv/src/*.lo $(BUILD_WORK)/libsigsegv/src/libsigsegv.la
	+$(MAKE) -C $(BUILD_WORK)/libsigsegv/src libsigsegv.la \
		CFLAGS="$$(sed -n 's/^CFLAGS = //p' $(BUILD_WORK)/libsigsegv/src/Makefile) -fno-lto" \
		LDFLAGS="$$(sed -n 's/^LDFLAGS = //p' $(BUILD_WORK)/libsigsegv/src/Makefile) -fno-lto -static"
	cp -a $(BUILD_WORK)/libsigsegv/src/.libs/libsigsegv.a \
		$(BUILD_STAGE)/libsigsegv/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/
endif
	$(call AFTER_BUILD,copy)
endif

libsigsegv-package: libsigsegv-stage
	# libsigsegv.mk Package Structure
	rm -rf $(BUILD_DIST)/libsigsegv{2,-dev}
	mkdir -p $(BUILD_DIST)/libsigsegv{2,-dev}/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libsigsegv.mk Prep libsigsegv2
	cp -a $(BUILD_STAGE)/libsigsegv/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libsigsegv.2.dylib $(BUILD_DIST)/libsigsegv2/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libsigsegv.mk Prep libsigsegv-dev
	cp -a $(BUILD_STAGE)/libsigsegv/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include $(BUILD_DIST)/libsigsegv-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)
	cp -a $(BUILD_STAGE)/libsigsegv/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libsigsegv.{dylib,a} $(BUILD_DIST)/libsigsegv-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libsigsegv.mk Sign
	$(call SIGN,libsigsegv2,general.xml)

	# libsigsegv.mk Make .debs
	$(call PACK,libsigsegv2,DEB_LIBSIGSEGV_V)
	$(call PACK,libsigsegv-dev,DEB_LIBSIGSEGV_V)

	# libsigsegv.mk Build cleanup
	rm -rf $(BUILD_DIST)/libsigsegv{2,-dev}

.PHONY: libsigsegv libsigsegv-package
