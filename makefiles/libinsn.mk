ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS     += libinsn
LIBINSN_VERSION := 35
LIBINSN_COMMIT  := 64124fd2b1b57d7b76a0e2b0c06434a7048758d2
DEB_LIBINSN_V   ?= $(LIBINSN_VERSION)-2

libinsn-setup: setup
	$(call GITHUB_ARCHIVE,tihmstar,libinsn,$(LIBINSN_COMMIT),$(LIBINSN_COMMIT))
	$(call EXTRACT_TAR,libinsn-$(LIBINSN_COMMIT).tar.gz,libinsn-$(LIBINSN_COMMIT),libinsn)
	sed -i 's/git rev\-list \-\-count HEAD/printf ${LIBINSN_VERSION}/g' $(BUILD_WORK)/libinsn/configure.ac
	sed -i 's/git rev\-parse HEAD/printf ${LIBINSN_COMMIT}/g' $(BUILD_WORK)/libinsn/configure.ac

ifneq ($(wildcard $(BUILD_WORK)/libinsn/.build_complete),)
libinsn:
	@echo "Using previously built libinsn."
else
libinsn: libinsn-setup libgeneral
	cd $(BUILD_WORK)/libinsn && $(LIBTOOLIZE) --force --copy
	cd $(BUILD_WORK)/libinsn && ./autogen.sh \
		$(DEFAULT_CONFIGURE_FLAGS)
	+$(MAKE) -C $(BUILD_WORK)/libinsn
	+$(MAKE) -C $(BUILD_WORK)/libinsn install \
		DESTDIR="$(BUILD_STAGE)/libinsn"
ifneq ($(filter -flto%,$(CXXFLAGS)),)
	# Keep normal installed LTO runtime; replace only the public C++ archive.
	find $(BUILD_WORK)/libinsn/libinsn -name '*.lo' -type f -delete
	rm -f $(BUILD_WORK)/libinsn/libinsn/libinsn.la
	+$(MAKE) -C $(BUILD_WORK)/libinsn/libinsn libinsn.la \
		CFLAGS="$$(sed -n 's/^CFLAGS = //p' $(BUILD_WORK)/libinsn/libinsn/Makefile) -fno-lto" \
		CXXFLAGS="$$(sed -n 's/^CXXFLAGS = //p' $(BUILD_WORK)/libinsn/libinsn/Makefile) -fno-lto" \
		LDFLAGS="$$(sed -n 's/^LDFLAGS = //p' $(BUILD_WORK)/libinsn/libinsn/Makefile) -fno-lto -static"
	cp -a $(BUILD_WORK)/libinsn/libinsn/.libs/libinsn.a \
		$(BUILD_STAGE)/libinsn/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/
endif
	$(call AFTER_BUILD,copy)
endif

libinsn-package: libinsn-stage
	# libinsn.mk Package Structure
	rm -rf $(BUILD_DIST)/libinsn{0,-dev}
	mkdir -p $(BUILD_DIST)/libinsn{0,-dev}/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libinsn.mk Prep libinsn0
	cp -a $(BUILD_STAGE)/libinsn/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libinsn.0.dylib $(BUILD_DIST)/libinsn0/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libinsn.mk Prep libinsn-dev
	cp -a $(BUILD_STAGE)/libinsn/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/!(libinsn.0.dylib) $(BUILD_DIST)/libinsn-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libinsn/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include $(BUILD_DIST)/libinsn-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)

	# libinsn.mk Sign
	$(call SIGN,libinsn0,general.xml)

	# libinsn.mk Make .debs
	$(call PACK,libinsn0,DEB_LIBINSN_V)
	$(call PACK,libinsn-dev,DEB_LIBINSN_V)

	# libinsn.mk Build cleanup
	rm -rf $(BUILD_DIST)/libinsn{0,-dev}

.PHONY: libinsn libinsn-package
