ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS      += torsocks
TORSOCKS_VERSION := 2.3.0
DEB_TORSOCKS_V   ?= $(TORSOCKS_VERSION)-2

torsocks-setup: setup
	$(call DOWNLOAD_FILES,$(BUILD_SOURCE), \
		https://people.torproject.org/~dgoulet/torsocks/torsocks-$(TORSOCKS_VERSION).tar.xz{$(comma).asc})
	$(call PGP_VERIFY,torsocks-$(TORSOCKS_VERSION).tar.xz,asc)
	$(call EXTRACT_TAR,torsocks-$(TORSOCKS_VERSION).tar.xz,torsocks-$(TORSOCKS_VERSION),torsocks)
	$(call DO_PATCH,torsocks,torsocks,-p1)

ifneq (,$(findstring roothide,$(MEMO_TARGET)))
TORSOCKS_CONFIGURE_ARGS := LDFLAGS="$(LDFLAGS) -Wl,-rpath,@loader_path/.."
endif

ifneq ($(wildcard $(BUILD_WORK)/torsocks/.build_complete),)
torsocks:
	@echo "Using previously built torsocks."
else
torsocks: torsocks-setup
	cd $(BUILD_WORK)/torsocks && ./configure -C \
		$(DEFAULT_CONFIGURE_FLAGS) \
		$(TORSOCKS_CONFIGURE_ARGS)
	+$(MAKE) -C $(BUILD_WORK)/torsocks \
		CFLAGS="$(CFLAGS) -DLIBIOSEXEC_INTERNAL" \
		CPPFLAGS="$(CPPFLAGS) -DLIBIOSEXEC_INTERNAL"
	+$(MAKE) -C $(BUILD_WORK)/torsocks install \
		DESTDIR=$(BUILD_STAGE)/torsocks
ifneq ($(filter -flto%,$(CFLAGS)),)
	# Rebuild the folded common objects too; installed LTO runtime stays intact.
	find $(BUILD_WORK)/torsocks/src/{common,lib} -maxdepth 1 \( -name '*.lo' -o -name '*.la' \) -type f -delete
	+set -e; for pair in common:libcommon lib:libtorsocks; do \
		sub=$${pair%:*}; target=$${pair#*:}; \
		$(MAKE) -C $(BUILD_WORK)/torsocks/src/$$sub $$target.la \
			CFLAGS="$$(sed -n 's/^CFLAGS = //p' $(BUILD_WORK)/torsocks/src/$$sub/Makefile) -DLIBIOSEXEC_INTERNAL -fno-lto" \
			CPPFLAGS="$$(sed -n 's/^CPPFLAGS = //p' $(BUILD_WORK)/torsocks/src/$$sub/Makefile) -DLIBIOSEXEC_INTERNAL" \
			LDFLAGS="$$(sed -n 's/^LDFLAGS = //p' $(BUILD_WORK)/torsocks/src/$$sub/Makefile) -fno-lto -static"; \
	done
	cp -a $(BUILD_WORK)/torsocks/src/lib/.libs/libtorsocks.a $(BUILD_STAGE)/torsocks/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/torsocks/
endif
	mv $(BUILD_STAGE)/torsocks/$(MEMO_PREFIX)/etc/tor/torsocks.conf \
		$(BUILD_STAGE)/torsocks/$(MEMO_PREFIX)/etc/tor/torsocks.conf.sample
	touch $(BUILD_WORK)/torsocks/.build_complete
endif

torsocks-package: torsocks-stage
	# torsocks.mk Package Structure
	rm -rf $(BUILD_DIST)/torsocks

	# torsocks.mk Prep torsocks
	cp -a $(BUILD_STAGE)/torsocks $(BUILD_DIST)

	# torsocks.mk Sign
	$(call SIGN,torsocks,general.xml)

	# torsocks.mk Make .debs
	$(call PACK,torsocks,DEB_TORSOCKS_V)

	# torsocks.mk Build cleanup
	rm -rf $(BUILD_DIST)/torsocks

.PHONY: torsocks torsocks-package
