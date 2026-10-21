ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS     += libyaml
LIBYAML_VERSION := 0.2.5
DEB_LIBYAML_V   ?= $(LIBYAML_VERSION)-1

libyaml-setup: setup
	$(call GITHUB_ARCHIVE,yaml,libyaml,$(LIBYAML_VERSION),$(LIBYAML_VERSION))
	$(call EXTRACT_TAR,libyaml-$(LIBYAML_VERSION).tar.gz,libyaml-$(LIBYAML_VERSION),libyaml)

ifneq ($(wildcard $(BUILD_WORK)/libyaml/.build_complete),)
libyaml:
	@echo "Using previously built libyaml."
else
libyaml: libyaml-setup
	cd $(BUILD_WORK)/libyaml && ./bootstrap && ./configure -C \
		$(DEFAULT_CONFIGURE_FLAGS)
	+$(MAKE) -C $(BUILD_WORK)/libyaml
	+$(MAKE) -C $(BUILD_WORK)/libyaml install \
		DESTDIR=$(BUILD_STAGE)/libyaml
ifneq ($(filter -flto%,$(CFLAGS)),)
	# Preserve the installed LTO dylib; rebuild only its public static target.
	+$(MAKE) -C $(BUILD_WORK)/libyaml/src clean
	+$(MAKE) -C $(BUILD_WORK)/libyaml/src libyaml.la \
		CFLAGS="$(filter-out -flto%,$(CFLAGS)) -fno-lto" \
		LDFLAGS="$(filter-out -flto%,$(LDFLAGS)) -static"
	cp -a $(BUILD_WORK)/libyaml/src/.libs/libyaml.a \
		$(BUILD_STAGE)/libyaml/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/
endif
	$(call AFTER_BUILD,copy)
endif

libyaml-package: libyaml-stage
	# libyaml.mk Package Structure
	rm -rf $(BUILD_DIST)/libyaml-{0-2,dev}
	mkdir -p $(BUILD_DIST)/libyaml-{0-2,dev}/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libyaml.mk Prep libyaml-0-2
	cp -a $(BUILD_STAGE)/libyaml/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libyaml-0.2.dylib $(BUILD_DIST)/libyaml-0-2/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libyaml.mk Prep libyaml-dev
	cp -a $(BUILD_STAGE)/libyaml/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/{libyaml.{a,dylib},pkgconfig} $(BUILD_DIST)/libyaml-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libyaml/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include $(BUILD_DIST)/libyaml-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)

	# libyaml.mk Sign
	$(call SIGN,libyaml-0-2,general.xml)

	# libyaml.mk Make .debs
	$(call PACK,libyaml-0-2,DEB_LIBYAML_V)
	$(call PACK,libyaml-dev,DEB_LIBYAML_V)

	# libyaml.mk Build cleanup
	rm -rf $(BUILD_DIST)/libyaml-{0-2,dev}

.PHONY: libyaml libyaml-package
