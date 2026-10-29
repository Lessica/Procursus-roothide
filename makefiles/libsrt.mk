ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS    += libsrt
LIBSRT_VERSION := 1.4.4
DEB_LIBSRT_V   ?= $(LIBSRT_VERSION)-1

libsrt-setup: setup
	$(call GITHUB_ARCHIVE,Haivision,srt,$(LIBSRT_VERSION),v$(LIBSRT_VERSION),libsrt)
	$(call EXTRACT_TAR,libsrt-$(LIBSRT_VERSION).tar.gz,srt-$(LIBSRT_VERSION),libsrt)

ifneq ($(wildcard $(BUILD_WORK)/libsrt/.build_complete),)
libsrt:
	@echo "Using previously built libsrt."
else
libsrt: libsrt-setup openssl
	cd $(BUILD_WORK)/libsrt && cmake . \
		$(DEFAULT_CMAKE_FLAGS) \
		-DCOMMON_ARCH=$(DEB_ARCH) \
		-DBUILD_SHARED_LIBS=true \
		-DWITH_OPENSSL_INCLUDEDIR=$(BUILD_BASE)$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include/openssl \
		-DWITH_OPENSSL_LIBDIR=$(BUILD_BASE)$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	+$(MAKE) -C $(BUILD_WORK)/libsrt install \
		DESTDIR=$(BUILD_STAGE)/libsrt
ifneq ($(filter -flto%,$(CXXFLAGS)),)
	# srt_virtual is shared by both library targets. Keep the full installed
	# LTO runtime/tools, and rebuild only its public archive with native objects.
	set -e; for target in srt_virtual srt_static; do \
		flags=$(BUILD_WORK)/libsrt/CMakeFiles/$$target.dir/flags.make; \
		cp -p "$$flags" "$$flags.lto"; \
		sed -E '/^(C|CXX)_FLAGS[^=]* =/ { s/(^|[[:space:]])-flto(=[^[:space:]]*)?//g; s/$$/ -fno-lto/; }' "$$flags.lto" > "$$flags"; \
		touch -r "$$flags.lto" "$$flags"; \
		find "$$(dirname "$$flags")" -type f \( -name '*.c.o' -o -name '*.cpp.o' \) -delete; \
	done
	rm -f $(BUILD_WORK)/libsrt/libsrt.a
	+$(MAKE) -C $(BUILD_WORK)/libsrt srt_static
	cp -a $(BUILD_WORK)/libsrt/libsrt.a $(BUILD_STAGE)/libsrt/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/
	for target in srt_virtual srt_static; do \
		flags=$(BUILD_WORK)/libsrt/CMakeFiles/$$target.dir/flags.make; mv "$$flags.lto" "$$flags"; \
	done
endif
	$(call AFTER_BUILD,copy)
endif

libsrt-package: libsrt-stage
	# libsrt.mk Package Structure
	rm -rf $(BUILD_DIST)/libsrt{1,-dev} \
		$(BUILD_DIST)/srt-tools
	mkdir -p $(BUILD_DIST)/libsrt{1,-dev}/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib \
		$(BUILD_DIST)/srt-tools/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)

	# libsrt.mk Prep libsrt1
	cp -a $(BUILD_STAGE)/libsrt/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libsrt.{$(LIBSRT_VERSION),1.4}.dylib $(BUILD_DIST)/libsrt1/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libsrt.mk Prep libsrt-dev
	cp -a $(BUILD_STAGE)/libsrt/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libsrt.{dylib,a} $(BUILD_DIST)/libsrt-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libsrt/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include $(BUILD_DIST)/libsrt-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)
	cp -a $(BUILD_STAGE)/libsrt/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/pkgconfig $(BUILD_DIST)/libsrt-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libsrt.mk Prep srt-tools
	cp -a $(BUILD_STAGE)/libsrt/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin $(BUILD_DIST)/srt-tools/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)

	# libsrt.mk Sign
	$(call SIGN,libsrt1,general.xml)
	$(call SIGN,srt-tools,general.xml)

	# libsrt.mk Make .debs
	$(call PACK,libsrt1,DEB_LIBSRT_V)
	$(call PACK,libsrt-dev,DEB_LIBSRT_V)
	$(call PACK,srt-tools,DEB_LIBSRT_V)

	# libsrt.mk Build cleanup
	rm -rf $(BUILD_DIST)/libsrt{1,-dev} \
		$(BUILD_DIST)/srt-tools

.PHONY: libsrt libsrt-package
