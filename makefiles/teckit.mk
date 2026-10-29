ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS   += teckit
TECKIT_VERSION := 2.5.12
DEB_TECKIT_V   ?= $(TECKIT_VERSION)-1

teckit-setup: setup
	$(call GITHUB_ARCHIVE,silnrsi,teckit,$(TECKIT_VERSION),refs/tags/v$(TECKIT_VERSION))
	$(call EXTRACT_TAR,teckit-$(TECKIT_VERSION).tar.gz,teckit-$(TECKIT_VERSION),teckit)

ifneq ($(wildcard $(BUILD_WORK)/teckit/.build_complete),)
teckit:
	@echo "Using previously built teckit."
else
teckit: teckit-setup zlib-ng
	cd $(BUILD_WORK)/teckit && autoreconf -fi
	mkdir -p $(BUILD_WORK)/teckit/build
	cd $(BUILD_WORK)/teckit/build && ../configure -C \
		$(DEFAULT_CONFIGURE_FLAGS) --with-system-zlib
	+$(MAKE) -C $(BUILD_WORK)/teckit/build
	+$(MAKE) -C $(BUILD_WORK)/teckit/build install \
		DESTDIR=$(BUILD_STAGE)/teckit
ifneq ($(filter -flto%,$(CFLAGS)),)
	# Keep installed LTO tools and dylibs; rebuild only both public archives.
	+$(MAKE) -C $(BUILD_WORK)/teckit/build/lib clean
	+$(MAKE) -C $(BUILD_WORK)/teckit/build/lib libTECkit.la libTECkit_Compiler.la \
		CFLAGS="$$(sed -n 's/^CFLAGS = //p' $(BUILD_WORK)/teckit/build/lib/Makefile | sed -E 's/(^|[[:space:]])-flto(=[^[:space:]]*)?//g') -fno-lto" \
		CXXFLAGS="$$(sed -n 's/^CXXFLAGS = //p' $(BUILD_WORK)/teckit/build/lib/Makefile | sed -E 's/(^|[[:space:]])-flto(=[^[:space:]]*)?//g') -fno-lto" \
		LDFLAGS="$$(sed -n 's/^LDFLAGS = //p' $(BUILD_WORK)/teckit/build/lib/Makefile | sed -E 's/(^|[[:space:]])-flto(=[^[:space:]]*)?//g') -static"
	cp -a $(BUILD_WORK)/teckit/build/lib/.libs/libTECkit{,_Compiler}.a $(BUILD_STAGE)/teckit/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/
endif
	$(call AFTER_BUILD,copy)
endif

teckit-package: teckit-stage
	# teckit.mk Package Structure
	rm -rf $(BUILD_DIST)/teckit

	# teckit.mk Prep teckit
	cp -a $(BUILD_STAGE)/teckit $(BUILD_DIST)

	# teckit.mk Sign
	$(call SIGN,teckit,general.xml)

	# teckit.mk Make .debs
	$(call PACK,teckit,DEB_TECKIT_V)

	# teckit.mk Build cleanup
	rm -rf $(BUILD_DIST)/teckit

.PHONY: teckit teckit-package
