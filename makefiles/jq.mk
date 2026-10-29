ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS  += jq
JQ_VERSION   := 1.6
DEB_JQ_V     ?= $(JQ_VERSION)-1

jq-setup: setup
	$(call DOWNLOAD_FILES,$(BUILD_SOURCE),https://github.com/stedolan/jq/releases/download/jq-$(JQ_VERSION)/jq-$(JQ_VERSION).tar.gz)
	$(call EXTRACT_TAR,jq-$(JQ_VERSION).tar.gz,jq-$(JQ_VERSION),jq)

ifneq ($(wildcard $(BUILD_WORK)/jq/.build_complete),)
jq:
	@echo "Using previously built jq."
else
jq: jq-setup libonig
	cd $(BUILD_WORK)/jq && autoreconf -fi
	cd $(BUILD_WORK)/jq && ./configure -C \
		$(DEFAULT_CONFIGURE_FLAGS) \
		--with-oniguruma=$(BUILD_STAGE)/libonig/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX) \
		--disable-docs \
		--disable-maintainer-mode \
		CFLAGS="$(CFLAGS) -D_REENTRANT"
	+$(MAKE) -C $(BUILD_WORK)/jq \
		DESTDIR=$(BUILD_STAGE)/jq
	+$(MAKE) -C $(BUILD_WORK)/jq install \
		DESTDIR=$(BUILD_STAGE)/jq
ifneq ($(filter -flto%,$(CFLAGS)),)
	# Retain the installed LTO runtime and command; rebuild only libjq inputs.
	find $(BUILD_WORK)/jq/src -name '*.lo' -type f -delete
	rm -f $(BUILD_WORK)/jq/libjq.la
	+$(MAKE) -C $(BUILD_WORK)/jq libjq.la \
		CFLAGS="$$(sed -n 's/^CFLAGS = //p' $(BUILD_WORK)/jq/Makefile) -fno-lto" \
		LDFLAGS="$$(sed -n 's/^LDFLAGS = //p' $(BUILD_WORK)/jq/Makefile) -fno-lto -static"
	cp -a $(BUILD_WORK)/jq/.libs/libjq.a $(BUILD_STAGE)/jq/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/
endif
	$(call AFTER_BUILD)
endif

jq-package: jq-stage
	# jq.mk Package Structure
	rm -rf $(BUILD_DIST)/{jq,libjq-dev,libjq1}
	mkdir -p $(BUILD_DIST)/jq/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/{bin,share} \
			$(BUILD_DIST)/libjq-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/{include,lib} \
			$(BUILD_DIST)/libjq1/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# jq.mk Prep jq
	cp -a $(BUILD_STAGE)/jq/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/jq $(BUILD_DIST)/jq/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin
	cp -a $(BUILD_STAGE)/jq/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man $(BUILD_DIST)/jq/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/

	# jq.mk Prep libjq-dev
	cp -a $(BUILD_STAGE)/jq/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include/{jq.h,jv.h} $(BUILD_DIST)/libjq-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include
	cp -a $(BUILD_STAGE)/jq/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libjq.{dylib,a} $(BUILD_DIST)/libjq-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# jq.mk Prep libjq1
	cp -a $(BUILD_STAGE)/jq/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libjq.1.dylib $(BUILD_DIST)/libjq1/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# jq.mk Sign
	$(call SIGN,jq,general.xml)
	$(call SIGN,libjq1,general.xml)

	# jq.mk Make .debs
	$(call PACK,jq,DEB_JQ_V)
	$(call PACK,libjq-dev,DEB_JQ_V)
	$(call PACK,libjq1,DEB_JQ_V)

	# jq.mk Build cleanup
	rm -rf $(BUILD_DIST)/{jq,libjq-dev,libjq1}

.PHONY: jq jq-package
