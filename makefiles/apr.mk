ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS += apr
APR_VERSION := 1.7.0
DEB_APR_V   ?= $(APR_VERSION)-1
APR_SYS_LIB_SEARCH_PATHS := $(sort $(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib $(MEMO_PREFIX)$(MEMO_SUB_PREFIX)$(MEMO_ALT_PREFIX)/lib /usr/lib /usr/local/lib)
APR_SYS_LIB_DLSEARCH_PATHS := $(sort $(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib $(MEMO_PREFIX)$(MEMO_SUB_PREFIX)$(MEMO_ALT_PREFIX)/lib /usr/local/lib /lib /usr/lib)
APR_TARGET_LIB_SEARCH_FLAGS := $(addprefix -L,$(sort $(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib $(MEMO_PREFIX)$(MEMO_SUB_PREFIX)$(MEMO_ALT_PREFIX)/lib /usr/lib /usr/local/lib))
APR_TARGET_CFLAGS := -Os -flto=thin -arch $(MEMO_ARCH) $(PLATFORM_VERSION_MIN)
APR_TARGET_CPPFLAGS := -arch $(MEMO_ARCH) $(PLATFORM_VERSION_MIN)
APR_TARGET_LDFLAGS := -Os -flto=thin -arch $(MEMO_ARCH) $(PLATFORM_VERSION_MIN) $(APR_TARGET_LIB_SEARCH_FLAGS) -Wl,-not_for_dyld_shared_cache $(filter -liosexec,$(LDFLAGS))

apr-setup: setup
	$(call DOWNLOAD_FILES,$(BUILD_SOURCE),https://archive.apache.org/dist/apr/apr-$(APR_VERSION).tar.gz{$(comma).asc})
	$(call PGP_VERIFY,apr-$(APR_VERSION).tar.gz,asc)
	$(call EXTRACT_TAR,apr-$(APR_VERSION).tar.gz,apr-$(APR_VERSION),apr)
	$(call DO_PATCH,apr,apr,-p1)

ifneq ($(wildcard $(BUILD_WORK)/apr/.build_complete),)
apr:
	@echo "Using previously built apr."
else
apr: apr-setup
	cd $(BUILD_WORK)/apr && ./configure -C \
		$(DEFAULT_CONFIGURE_FLAGS) \
		--includedir=$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include/apr-1.0 \
		--with-installbuilddir=$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/apr-1.0/build \
		ac_cv_file__dev_zero=yes \
		ac_cv_func_setpgrp_void=yes \
		apr_cv_process_shared_works=yes \
		apr_cv_mutex_robust_shared=no \
		apr_cv_tcp_nodelay_with_cork=yes \
		ac_cv_sizeof_struct_iovec=8 \
		apr_cv_mutex_recursive=yes
	+$(MAKE) -C $(BUILD_WORK)/apr all \
		CC_FOR_BUILD=$(shell command -v clang)
	+$(MAKE) -C $(BUILD_WORK)/apr install \
		DESTDIR="$(BUILD_STAGE)/apr"
	sed -i -e 's|^CC=".*"|CC="cc"|' \
		-e 's|^CPP=".*"|CPP="cc -E"|' \
		-e 's|^APR_SOURCE_DIR=".*"|APR_SOURCE_DIR=""|' \
		-e 's|^APR_BUILD_DIR=".*"|APR_BUILD_DIR=""|' \
		$(BUILD_STAGE)/apr/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/apr-1-config
	$(LN_S) apr-1-config $(BUILD_STAGE)/apr/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/apr-config
	$(call AFTER_BUILD,copy)
endif

apr-package: apr-stage
	# apr.mk Package Structure
	rm -rf $(BUILD_DIST)/libapr1{,-dev}
	# Remove host compiler, SDK and build-root paths from the exported APR build files.
	sed -i -E \
		-e 's#^CC=.*$$#CC=clang#' \
		-e 's#^CFLAGS=.*$$#CFLAGS=$(APR_TARGET_CFLAGS)#' \
		-e 's#^CPPFLAGS=.*$$#CPPFLAGS=$(APR_TARGET_CPPFLAGS)#' \
		-e 's#^LDFLAGS=.*$$#LDFLAGS=$(APR_TARGET_LDFLAGS)#' \
		$(BUILD_STAGE)/apr/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/apr-1.0/build/apr_rules.mk
	sed -i -E \
		-e 's#^SED=".*"$$#SED="sed"#' \
		-e 's#^GREP=".*"$$#GREP="grep"#' \
		-e 's#^EGREP=".*"$$#EGREP="grep -E"#' \
		-e 's#^FGREP=".*"$$#FGREP="grep -F"#' \
		-e 's#^LTCC=".*"$$#LTCC="clang"#' \
		-e 's#^LTCFLAGS=".*"$$#LTCFLAGS="-arch $(MEMO_ARCH) $(PLATFORM_VERSION_MIN)"#' \
		-e 's#^lt_truncate_bin=".*"$$#lt_truncate_bin="dd bs=4096 count=1"#' \
		-e 's#^sys_lib_search_path_spec=".*"$$#sys_lib_search_path_spec="$(APR_SYS_LIB_SEARCH_PATHS)"#' \
		-e 's#^sys_lib_dlsearch_path_spec=".*"$$#sys_lib_dlsearch_path_spec="$(APR_SYS_LIB_DLSEARCH_PATHS)"#' \
		-e 's#^CC="([^"]*/)?(cc|gcc|clang)"$$#CC="clang"#' \
		$(BUILD_STAGE)/apr/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/apr-1.0/build/libtool
	mkdir -p $(BUILD_DIST)/libapr1{,-dev}/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# apr.mk Prep libapr1
	cp -a $(BUILD_STAGE)/apr/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libapr-1.0.dylib $(BUILD_DIST)/libapr1/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# apr.mk Prep libapr1-dev
	cp -a $(BUILD_STAGE)/apr/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/{bin,include,share} $(BUILD_DIST)/libapr1-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)
	cp -a $(BUILD_STAGE)/apr/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/!(libapr-1.0.dylib) $(BUILD_DIST)/libapr1-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# apr.mk Sign
	$(call SIGN,libapr1,general.xml)
	$(call SIGN,libapr1-dev,general.xml)

	# apr.mk Make .debs
	$(call PACK,libapr1,DEB_APR_V)
	$(call PACK,libapr1-dev,DEB_APR_V)

	# apr.mk Build cleanup
	rm -rf $(BUILD_DIST)/libapr1{,-dev}

.PHONY: apr apr-package
