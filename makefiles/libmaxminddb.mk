ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS          += libmaxminddb
LIBMAXMINDDB_VERSION := 1.6.0
DEB_LIBMAXMINDDB_V   ?= $(LIBMAXMINDDB_VERSION)-1

libmaxminddb-setup: setup
	$(call DOWNLOAD_FILES,$(BUILD_SOURCE),https://github.com/maxmind/libmaxminddb/releases/download/$(LIBMAXMINDDB_VERSION)/libmaxminddb-$(LIBMAXMINDDB_VERSION).tar.gz)
	$(call EXTRACT_TAR,libmaxminddb-$(LIBMAXMINDDB_VERSION).tar.gz,libmaxminddb-$(LIBMAXMINDDB_VERSION),libmaxminddb)

ifneq ($(wildcard $(BUILD_WORK)/libmaxminddb/.build_complete),)
libmaxminddb:
	@echo "Using previously built libmaxminddb."
else
libmaxminddb: libmaxminddb-setup
	cd $(BUILD_WORK)/libmaxminddb && ./configure -C \
		$(DEFAULT_CONFIGURE_FLAGS)
	+$(MAKE) -C $(BUILD_WORK)/libmaxminddb
	+$(MAKE) -C $(BUILD_WORK)/libmaxminddb install \
		DESTDIR=$(BUILD_STAGE)/libmaxminddb
ifneq ($(filter -flto%,$(CFLAGS)),)
	# Keep staged LTO tools/dylib and the same configured API/features.
	rm -f $(BUILD_WORK)/libmaxminddb/src/*.lo $(BUILD_WORK)/libmaxminddb/src/libmaxminddb.la
	+$(MAKE) -C $(BUILD_WORK)/libmaxminddb/src libmaxminddb.la \
		CFLAGS="$$(sed -n 's/^CFLAGS = //p' $(BUILD_WORK)/libmaxminddb/src/Makefile) -fno-lto" \
		LDFLAGS="$$(sed -n 's/^LDFLAGS = //p' $(BUILD_WORK)/libmaxminddb/src/Makefile) -fno-lto -static"
	cp -a $(BUILD_WORK)/libmaxminddb/src/.libs/libmaxminddb.a \
		$(BUILD_STAGE)/libmaxminddb/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/
endif
	$(call AFTER_BUILD,copy)
endif

libmaxminddb-package: libmaxminddb-stage
	# libmaxminddb.mk Package Structure
	rm -rf $(BUILD_DIST)/libmaxminddb{0,-dev} $(BUILD_DIST)/mmdb-bin
	mkdir -p $(BUILD_DIST)/libmaxminddb0/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib \
		$(BUILD_DIST)/libmaxminddb-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/{lib,share/man} \
		$(BUILD_DIST)/mmdb-bin/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man

	# libmaxminddb.mk Prep libmaxminddb0
	cp -a $(BUILD_STAGE)/libmaxminddb/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libmaxminddb.0.dylib $(BUILD_DIST)/libmaxminddb0/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libmaxminddb.mk Prep libmaxminddb-dev
	cp -a $(BUILD_STAGE)/libmaxminddb/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/!(libmaxminddb.0.dylib) $(BUILD_DIST)/libmaxminddb-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libmaxminddb/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include $(BUILD_DIST)/libmaxminddb-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)
	cp -a $(BUILD_STAGE)/libmaxminddb/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/man3 $(BUILD_DIST)/libmaxminddb-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man

	# libmaxminddb.mk Prep mmdb-bin
	cp -a $(BUILD_STAGE)/libmaxminddb/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin $(BUILD_DIST)/mmdb-bin/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)
	cp -a $(BUILD_STAGE)/libmaxminddb/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man/man1 $(BUILD_DIST)/mmdb-bin/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/man

	# libmaxminddb.mk Sign
	$(call SIGN,libmaxminddb0,general.xml)
	$(call SIGN,mmdb-bin,general.xml)

	# libmaxminddb.mk Make .debs
	$(call PACK,libmaxminddb0,DEB_LIBMAXMINDDB_V)
	$(call PACK,libmaxminddb-dev,DEB_LIBMAXMINDDB_V)
	$(call PACK,mmdb-bin,DEB_LIBMAXMINDDB_V)

	# libmaxminddb.mk Build cleanup
	rm -rf $(BUILD_DIST)/libmaxminddb{0,-dev} $(BUILD_DIST)/mmdb-bin

.PHONY: libmaxminddb libmaxminddb-package
