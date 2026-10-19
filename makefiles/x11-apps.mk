ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS      += x11-apps
X11_APPS_VERSION := 7.7+8
DEB_X11_APPS_V   ?= $(X11_APPS_VERSION)-1

x11-apps-setup: setup
	$(call DOWNLOAD_FILES,$(BUILD_SOURCE),https://salsa.debian.org/xorg-team/app/x11-apps/-/archive/x11-apps-$(X11_APPS_VERSION)/x11-apps-x11-apps-$(X11_APPS_VERSION).tar.gz)
	$(call EXTRACT_TAR,x11-apps-x11-apps-$(X11_APPS_VERSION).tar.gz,x11-apps-x11-apps-$(X11_APPS_VERSION),x11-apps)
	$(call DO_PATCH,xedit,x11-apps/xedit,-p1)

ifneq ($(wildcard $(BUILD_WORK)/x11-apps/.build_complete),)
x11-apps:
	@echo "Using previously built x11-apps."
else
x11-apps: x11-apps-setup libsm libx11 libxaw libxcursor libxext libxft libxmu libxrender libxt libpng16 libxkbfile
	mkdir -p $(BUILD_WORK)/x11-apps/include/protocols
	rm -f $(BUILD_WORK)/x11-apps/include/protocols/rwhod.h
	cp -a $(MACOSX_SYSROOT)/usr/include/protocols/rwhod.h $(BUILD_WORK)/x11-apps/include/protocols/rwhod.h
	find $(BUILD_WORK)/x11-apps -name config.cache -type f -delete
	+set -e; for dir in $(BUILD_WORK)/x11-apps/*; do \
		if [ -f $$dir/configure ]; then \
			cd $$dir && ac_cv_file__etc_man_conf=no ac_cv_file__etc_man_config=no ac_cv_file__etc_manpath_config=no ac_cv_file__usr_share_misc_man_conf=no ./configure -C \
				$(DEFAULT_CONFIGURE_FLAGS) \
				CPPFLAGS="$(CPPFLAGS) -I$(BUILD_WORK)/x11-apps/include" \
				--with-appdefaultdir=$(MEMO_PREFIX)/etc/X11/app-defaults || exit $$?; \
			$(MAKE) -C $$dir || exit $$?; \
			$(MAKE) -C $$dir install \
				DESTDIR=$(BUILD_STAGE)/x11-apps || exit $$?; \
		fi; \
	done
	$(call AFTER_BUILD)
endif

x11-apps-package: x11-apps-stage
	# x11-apps.mk Package Structure
	rm -rf $(BUILD_DIST)/x11-apps
	sed -i 's|^MKTEMP=.*$$|MKTEMP="$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/mktemp"|' $(BUILD_STAGE)/x11-apps/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/x11perfcomp

	# x11-apps.mk Prep x11-apps
	cp -a $(BUILD_STAGE)/x11-apps $(BUILD_DIST)

	# x11-apps.mk Sign
	$(call SIGN,x11-apps,general.xml)

	# x11-apps.mk Make .debs
	$(call PACK,x11-apps,DEB_X11_APPS_V)

	# x11-apps.mk Build cleanup
	rm -rf $(BUILD_DIST)/x11-apps

.PHONY: x11-apps x11-apps-package
