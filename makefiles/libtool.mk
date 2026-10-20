ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS     += libtool
LIBTOOL_VERSION := 2.4.7
DEB_LIBTOOL_V   ?= $(LIBTOOL_VERSION)-3
LIBTOOL_SYS_LIB_SEARCH_PATHS := $(sort $(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib $(MEMO_PREFIX)$(MEMO_SUB_PREFIX)$(MEMO_ALT_PREFIX)/lib /usr/lib /usr/local/lib)
LIBTOOL_SYS_LIB_DLSEARCH_PATHS := $(sort $(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib $(MEMO_PREFIX)$(MEMO_SUB_PREFIX)$(MEMO_ALT_PREFIX)/lib /usr/local/lib /lib /usr/lib)

libtool-setup: setup
	$(call DOWNLOAD_FILES,$(BUILD_SOURCE),https://ftpmirror.gnu.org/libtool/libtool-$(LIBTOOL_VERSION).tar.gz{$(comma).sig})
	$(call PGP_VERIFY,libtool-$(LIBTOOL_VERSION).tar.gz)
	$(call EXTRACT_TAR,libtool-$(LIBTOOL_VERSION).tar.gz,libtool-$(LIBTOOL_VERSION),libtool)

ifneq ($(wildcard $(BUILD_WORK)/libtool/.build_complete),)
libtool:
	@echo "Using previously built libtool."
else
libtool: libtool-setup
	cd $(BUILD_WORK)/libtool && ./configure -C \
		$(DEFAULT_CONFIGURE_FLAGS) \
		--program-prefix=g \
		--enable-ltdl-install \
		SED="sed" \
		GREP="grep" \
		EGREP="grep -E" \
		FGREP="grep -F"
	+$(MAKE) -C $(BUILD_WORK)/libtool
	+$(MAKE) -C $(BUILD_WORK)/libtool install \
		DESTDIR=$(BUILD_STAGE)/libtool
ifneq ($(filter -flto%,$(CFLAGS)),)
	# Preserve the installed LTO runtime; rebuild only ltdl's archive inputs.
	# Libtool compiles its generated dlpreopen table using captured LTCFLAGS.
	sed -i '/^LTCFLAGS=/s/"$$/ -fno-lto"/' $(BUILD_WORK)/libtool/libtool
	find $(BUILD_WORK)/libtool/libltdl -name '*.lo' -type f -delete
	find $(BUILD_WORK)/libtool/libltdl -name '*.la' -type f -delete
	+$(MAKE) -C $(BUILD_WORK)/libtool libltdl/libltdl.la \
		CFLAGS="$(CFLAGS) -fno-lto" LDFLAGS="$(LDFLAGS) -fno-lto -static"
	sed -i '/^LTCFLAGS=/s/ -fno-lto"$$/"/' $(BUILD_WORK)/libtool/libtool
	cp -a $(BUILD_WORK)/libtool/libltdl/.libs/libltdl.a $(BUILD_STAGE)/libtool/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/
endif
	$(call AFTER_BUILD,copy)
endif
libtool-package: libtool-stage
	# libtool.mk Package Structure
	rm -rf $(BUILD_DIST)/libtool{,-bin} $(BUILD_DIST)/libltdl{7,-dev}
	# Remove host-only compiler and SDK paths from the installed runtime script.
	sed -i -E \
		-e 's#^LTCC=".*"$$#LTCC="clang"#' \
		-e 's#^LTCFLAGS=".*"$$#LTCFLAGS="-arch $(MEMO_ARCH) $(PLATFORM_VERSION_MIN)"#' \
		-e 's#^sys_lib_search_path_spec=".*"$$#sys_lib_search_path_spec="$(LIBTOOL_SYS_LIB_SEARCH_PATHS)"#' \
		-e 's#^sys_lib_dlsearch_path_spec=".*"$$#sys_lib_dlsearch_path_spec="$(LIBTOOL_SYS_LIB_DLSEARCH_PATHS)"#' \
		-e 's#^CC="([^\"]*/)?(cc|gcc|clang)"$$#CC="clang"#' \
		-e 's#^CC="([^\"]*/)?(c\+\+|g\+\+|clang\+\+)"$$#CC="clang++"#' \
		-e 's#^lt_truncate_bin=".*"$$#lt_truncate_bin="dd bs=4096 count=1"#' \
		-e 's#^max_cmd_len=$$#max_cmd_len=49152#' \
		$(BUILD_STAGE)/libtool$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/glibtool
	mkdir -p $(BUILD_DIST)/libtool/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/{bin,share/{man/man1,libtool,aclocal}} \
		$(BUILD_DIST)/libtool-bin/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/{bin,share/man/man1} \
		$(BUILD_DIST)/libltdl7/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib \
		$(BUILD_DIST)/libltdl-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/{include,lib,share/{libtool,aclocal}}

	# libtool.mk Prep libtool
	cp -a $(BUILD_STAGE)/libtool/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/glibtoolize $(BUILD_DIST)/libtool/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin
	cp -a $(BUILD_STAGE)/libtool/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/man1/glibtoolize.1$(MEMO_MANPAGE_SUFFIX) $(BUILD_DIST)/libtool/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/man1
	cp -a $(BUILD_STAGE)/libtool/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/aclocal/!(ltdl.m4) $(BUILD_DIST)/libtool/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/aclocal
	cp -a $(BUILD_STAGE)/libtool/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/libtool/build-aux $(BUILD_DIST)/libtool/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/libtool

	# libtool.mk Prep libtool-bin
	cp -a $(BUILD_STAGE)/libtool/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/glibtool $(BUILD_DIST)/libtool-bin/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin
	cp -a $(BUILD_STAGE)/libtool/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/man1/glibtool.1$(MEMO_MANPAGE_SUFFIX) $(BUILD_DIST)/libtool-bin/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/man1

	# libtool.mk Prep libltdl7
	cp -a $(BUILD_STAGE)/libtool/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libltdl.7.dylib $(BUILD_DIST)/libltdl7/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libtool.mk Prep libltdl-dev
	cp -a $(BUILD_STAGE)/libtool/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include/{ltdl.h,libltdl} $(BUILD_DIST)/libltdl-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include
	cp -a $(BUILD_STAGE)/libtool/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/!(libltdl.7.dylib) $(BUILD_DIST)/libltdl-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libtool/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/aclocal/ltdl.m4 $(BUILD_DIST)/libltdl-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/aclocal
	cp -a $(BUILD_STAGE)/libtool/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/libtool/!(build-aux) $(BUILD_DIST)/libltdl-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/libtool

	# libtool.mk Sign
	$(call SIGN,libtool,general.xml)
	$(call SIGN,libtool-bin,general.xml)
	$(call SIGN,libltdl7,general.xml)

	# libtool.mk Make .debs
	$(call PACK,libtool,DEB_LIBTOOL_V)
	$(call PACK,libtool-bin,DEB_LIBTOOL_V)
	$(call PACK,libltdl7,DEB_LIBTOOL_V)
	$(call PACK,libltdl-dev,DEB_LIBTOOL_V)

	# libtool.mk Build cleanup
	rm -rf $(BUILD_DIST)/libtool{,-bin} $(BUILD_DIST)/libltdl{7,-dev}

.PHONY: libtool libtool-package
