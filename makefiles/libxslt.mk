ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS += libxslt
LIBXSLT_VERSION := 1.1.34
DEB_LIBXSLT_V ?= $(LIBXSLT_VERSION)

libxslt-setup: setup
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/libxslt-$(LIBXSLT_VERSION).tar.xz,https://download.gnome.org/sources/libxslt/1.1/libxslt-$(LIBXSLT_VERSION).tar.xz)
	echo '28c47db33ab4daefa6232f31ccb3c65260c825151ec86ec461355247f3f56824  $(BUILD_SOURCE)/libxslt-$(LIBXSLT_VERSION).tar.xz' | sha256sum -c -
	$(call EXTRACT_TAR,libxslt-$(LIBXSLT_VERSION).tar.xz,libxslt-$(LIBXSLT_VERSION),libxslt)

ifneq ($(wildcard $(BUILD_WORK)/libxslt/.build_complete),)
libxslt:
	@echo "Using previously built libxslt."
else
libxslt: libxslt-setup libxml2 libgcrypt
	# The optional bindings in this release require Python 2, which this
	# corpus does not provide. All C/EXSLT/crypto/plugin features are retained.
	cd $(BUILD_WORK)/libxslt && \
		LIBXML_CFLAGS="-I$(BUILD_BASE)$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include/libxml2" \
		LIBXML_LIBS="-L$(BUILD_BASE)$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)$(MEMO_ALT_PREFIX)/lib -lxml2" \
		WITH_MODULES=1 \
		LIBGCRYPT_CONFIG="$(BUILD_BASE)$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/libgcrypt-config --prefix=$(BUILD_BASE)$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)" \
		./configure $(DEFAULT_CONFIGURE_FLAGS) \
			--libdir=$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)$(MEMO_ALT_PREFIX)/lib \
			--with-crypto --with-plugins --without-python
	+$(MAKE) -C $(BUILD_WORK)/libxslt
	+$(MAKE) -C $(BUILD_WORK)/libxslt install DESTDIR="$(BUILD_STAGE)/libxslt"
	# Build roots are valid inputs, never installed development metadata.
	sed -i 's|$(BUILD_BASE)||g' \
		$(BUILD_STAGE)/libxslt/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/xslt-config \
		$(BUILD_STAGE)/libxslt/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)$(MEMO_ALT_PREFIX)/lib/pkgconfig/*.pc \
		$(BUILD_STAGE)/libxslt/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)$(MEMO_ALT_PREFIX)/lib/xsltConf.sh
	$(call AFTER_BUILD,copy)
endif

# Keep the complete installed HTML/API/tutorial documentation.
LIBXSLT_COMMA := ,
LIBXSLT_PACK = $(subst /share/{info$(LIBXSLT_COMMA)doc},/share/info,$(call PACK,$(1),DEB_LIBXSLT_V))

libxslt-package: libxslt-stage
	rm -rf $(BUILD_DIST)/{libxslt1.1,libxslt1-dev,xsltproc,libxslt-doc}
	cp -a $(BUILD_STAGE)/libxslt $(BUILD_DIST)/libxslt1-dev
	mkdir -p $(BUILD_DIST)/libxslt1.1/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)$(MEMO_ALT_PREFIX)/lib \
		$(BUILD_DIST)/xsltproc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/{bin,share/man/man1} \
		$(BUILD_DIST)/libxslt-doc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share
	mv $(BUILD_DIST)/libxslt1-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)$(MEMO_ALT_PREFIX)/lib/lib{exslt,xslt}.[0-9]*.dylib \
		$(BUILD_DIST)/libxslt1.1/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)$(MEMO_ALT_PREFIX)/lib
	mv $(BUILD_DIST)/libxslt1-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/xsltproc $(BUILD_DIST)/xsltproc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin
	mv $(BUILD_DIST)/libxslt1-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/man1/xsltproc.1$(MEMO_MANPAGE_SUFFIX) \
		$(BUILD_DIST)/xsltproc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/man1
	mv $(BUILD_DIST)/libxslt1-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/doc $(BUILD_DIST)/libxslt-doc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share
	$(call SIGN,libxslt1.1,general.xml)
	$(call SIGN,xsltproc,general.xml)
	$(call LIBXSLT_PACK,libxslt1.1)
	$(call LIBXSLT_PACK,libxslt1-dev)
	$(call LIBXSLT_PACK,xsltproc)
	$(call LIBXSLT_PACK,libxslt-doc)
	rm -rf $(BUILD_DIST)/{libxslt1.1,libxslt1-dev,xsltproc,libxslt-doc}

.PHONY: libxslt libxslt-package
