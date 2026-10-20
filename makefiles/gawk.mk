ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS  += gawk
GAWK_VERSION := 5.3.0
DEB_GAWK_V   ?= $(GAWK_VERSION)-1

gawk-setup: setup
	$(call DOWNLOAD_FILES,$(BUILD_SOURCE),https://ftpmirror.gnu.org/gawk/gawk-$(GAWK_VERSION).tar.xz{$(comma).sig})
	$(call PGP_VERIFY,gawk-$(GAWK_VERSION).tar.xz)
	$(call EXTRACT_TAR,gawk-$(GAWK_VERSION).tar.xz,gawk-$(GAWK_VERSION),gawk)

ifneq ($(wildcard $(BUILD_WORK)/gawk/.build_complete),)
gawk:
	@echo "Using previously built gawk."
else
gawk: gawk-setup gettext mpfr4 libgmp10
	cd $(BUILD_WORK)/gawk && ./configure \
		$(DEFAULT_CONFIGURE_FLAGS) \
		--without-libsigsegv-prefix
	+$(MAKE) -C $(BUILD_WORK)/gawk install \
		DESTDIR=$(BUILD_STAGE)/gawk
ifneq ($(filter -flto%,$(CFLAGS)),)
	# Preserve installed LTO extensions and gawk; only public archives change.
	find $(BUILD_WORK)/gawk/extension -maxdepth 1 \( -name '*.lo' -o -name '*.la' \) -type f -delete
	+set -e; targets=""; for archive in $(BUILD_STAGE)/gawk/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/gawk/*.a; do \
		targets="$$targets $$(basename $$archive .a).la"; \
	done; $(MAKE) -C $(BUILD_WORK)/gawk/extension $$targets \
		CFLAGS="$$(sed -n 's/^CFLAGS = //p' $(BUILD_WORK)/gawk/extension/Makefile) -fno-lto" \
		LDFLAGS="$$(sed -n 's/^LDFLAGS = //p' $(BUILD_WORK)/gawk/extension/Makefile) -fno-lto -static"
	set -e; for archive in $(BUILD_STAGE)/gawk/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/gawk/*.a; do \
		cp -a $(BUILD_WORK)/gawk/extension/.libs/$$(basename $$archive) $$archive; \
	done
endif
	rm -f $(BUILD_STAGE)/gawk/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/*awk-*
	rm -f $(BUILD_STAGE)/gawk/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/awk
	$(call AFTER_BUILD)
endif

gawk-package: gawk-stage
	# gawk.mk Package Structure
	rm -rf $(BUILD_DIST)/gawk

	# gawk.mk Prep gawk
	cp -a $(BUILD_STAGE)/gawk $(BUILD_DIST)

	# gawk.mk Sign
	$(call SIGN,gawk,general.xml)

	# gawk.mk Make .debs
	$(call PACK,gawk,DEB_GAWK_V)

	# gawk.mk Build cleanup
	rm -rf $(BUILD_DIST)/gawk

.PHONY: gawk gawk-package
