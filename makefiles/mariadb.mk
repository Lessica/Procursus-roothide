ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS  		+= mariadb
MARIADB_VERSION := 10.5.9
DEB_MARIADB_V   ?= $(MARIADB_VERSION)

mariadb-setup: setup
	$(call DOWNLOAD_FILES,$(BUILD_SOURCE), \
		https://downloads.mariadb.com/MariaDB/mariadb-$(MARIADB_VERSION)/source/mariadb-$(MARIADB_VERSION).tar.gz)
	$(call EXTRACT_TAR,mariadb-$(MARIADB_VERSION).tar.gz,mariadb-$(MARIADB_VERSION),mariadb)
	$(call DO_PATCH,mariadb,mariadb,-p1)

ifeq ($(UNAME),Linux)
	sed -i 's/COMMAND libtool/COMMAND $(GNU_HOST_TRIPLE)-libtool/' $(BUILD_WORK)/mariadb/cmake/libutils.cmake
endif

	mkdir -p $(BUILD_WORK)/mariadb/host

ifneq ($(wildcard $(BUILD_WORK)/mariadb/host/.build_complete),)
mariadb-import-executables:
	@echo "Using previously built mariadb-import-executables"
else
mariadb-import-executables: mariadb-setup
	# https://mariadb.com/kb/en/cross-compiling-mariadb/
	cd $(BUILD_WORK)/mariadb/host \
	&& unset CFLAGS CPPFLAGS CXXFLAGS LDFLAGS && \
			SDKROOT="$(MACOSX_SYSROOT)" PKG_CONFIG_PATH="" PKG_CONFIG_LIBDIR="" \
			CC=$(shell command -v cc) \
			CXX=$(shell command -v c++) \
			cmake .. \
				-DSTACK_DIRECTION=1 \
				-DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
				-DCMAKE_OSX_SYSROOT="$(MACOSX_SYSROOT)" \
				-DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
		&& SDKROOT="$(MACOSX_SYSROOT)" $(MAKE) import_executables
	touch $(BUILD_WORK)/mariadb/host/.build_complete
endif

ifneq ($(wildcard $(BUILD_WORK)/mariadb/.build_complete),)
mariadb:
	@echo "Using previously built mariadb."
else
mariadb: mariadb-import-executables openssl ncurses readline libevent curl lz4 libsnappy libunistring libjemalloc libcrack xz liblzo2 zstd msgpack openpam
	cd $(BUILD_WORK)/mariadb && SDKROOT="$(TARGET_SYSROOT)" LIBTOOL=$(GNU_HOST_TRIPLE)-libtool cmake . \
		$(DEFAULT_CMAKE_FLAGS) \
		-DCMAKE_OSX_DEPLOYMENT_TARGET=16.0 \
		-DCMAKE_FIND_ROOT_PATH="$(BUILD_BASE);$(TARGET_SYSROOT)" \
		-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
		-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
		-DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
		-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
		-DCOMPILATION_COMMENT="Procursus" \
		-Wno-dev \
		-DINSTALL_SYSCONFDIR=$(MEMO_PREFIX)/etc \
		-DINSTALL_SYSCONF2DIR=$(MEMO_PREFIX)/etc/my.cnf.d \
		-DINSTALL_UNIX_ADDRDIR=$(MEMO_PREFIX)/var/run/mysqld/mysqld.sock \
		-DINSTALL_SCRIPTDIR=bin \
		-DINSTALL_INCLUDEDIR=include/mysql \
		-DINSTALL_PLUGINDIR=lib/mysql/plugin \
		-DINSTALL_SHAREDIR=share \
		-DINSTALL_SUPPORTFILESDIR=share/mysql \
		-DINSTALL_MYSQLSHAREDIR=share/mysql \
		-DINSTALL_DOCREADMEDIR=share/doc/mariadb \
		-DINSTALL_DOCDIR=share/doc/mariadb \
		-DINSTALL_MANDIR=share/man \
		-DMYSQL_DATADIR=$(MEMO_PREFIX)/var/lib/mysql \
		-DDEFAULT_CHARSET=utf8mb4 \
		-DDEFAULT_COLLATION=utf8mb4_unicode_ci \
		-DENABLED_LOCAL_INFILE=ON \
		-DPLUGIN_EXAMPLE=NO \
		-DPLUGIN_FEDERATED=NO \
		-DPLUGIN_FEEDBACK=NO \
		-DWITH_EMBEDDED_SERVER=ON \
		-DWITH_EXTRA_CHARSETS=complex \
		-DWITH_JEMALLOC=yes \
		-DWITH_LIBWRAP=OFF \
		-DWITH_PCRE=bundled \
		-DWITH_READLINE=ON \
		-DWITH_SSL=system \
		-DWITH_SYSTEMD=no \
		-DWITH_UNIT_TESTS=OFF \
		-DWITH_ZLIB=system \
		-DCMAKE_EXE_LINKER_FLAGS="$(LDFLAGS) -L$(TARGET_SYSROOT)/usr/lib -liconv -lsnappy $(TARGET_SYSROOT)/usr/lib/libxml2.tbd" \
		-DCMAKE_MODULE_LINKER_FLAGS="$(LDFLAGS) -L$(TARGET_SYSROOT)/usr/lib -liconv -lsnappy $(TARGET_SYSROOT)/usr/lib/libxml2.tbd" \
		-DCMAKE_SHARED_LINKER_FLAGS="$(LDFLAGS) -L$(TARGET_SYSROOT)/usr/lib -liconv -lsnappy $(TARGET_SYSROOT)/usr/lib/libxml2.tbd" \
		-DSTACK_DIRECTION=1 \
		-DHAVE_IB_GCC_ATOMIC_BUILTINS=1 \
		-DLZMA_LIBRARY=$(BUILD_BASE)$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/local/lib/liblzma.dylib \
		-DREADLINE_LIBRARY=$(BUILD_BASE)$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libreadline.dylib \
		-DLZ4_LIBS=$(BUILD_BASE)$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/liblz4.dylib \
		-DCURSES_LIBRARY=$(BUILD_BASE)$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libncursesw.dylib \
		-DCURL_LIBRARY=$(BUILD_BASE)$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libcurl.dylib \
		-DLIBXML2_INCLUDE_DIR=$(TARGET_SYSROOT)/usr/include/libxml2 \
		-DLIBXML2_LIBRARY=$(TARGET_SYSROOT)/usr/lib/libxml2.tbd \
		-DICONV_LIBRARIES=$(TARGET_SYSROOT)/usr/lib/libiconv.tbd \
		-DIMPORT_EXECUTABLES=$(BUILD_WORK)/mariadb/host/import_executables.cmake

	+$(MAKE) -C $(BUILD_WORK)/mariadb
	+$(MAKE) -C $(BUILD_WORK)/mariadb install \
		DESTDIR="$(BUILD_STAGE)/mariadb"
	$(call AFTER_BUILD,copy,mariadb)
endif

# The frozen recipe stopped at a packaging TODO. Follow the pinned source's
# Debian component split, retaining the Darwin install layout and all payloads.
MARIADB_PACKAGES := libmariadb-dev libmariadb-dev-compat libmariadb3 libmariadbd-dev libmariadbd19 mariadb-backup mariadb-client-10.5 mariadb-client-core-10.5 mariadb-common mariadb-plugin-connect mariadb-plugin-cracklib-password-check mariadb-plugin-mroonga mariadb-plugin-rocksdb mariadb-plugin-s3 mariadb-plugin-spider mariadb-server-10.5 mariadb-server-core-10.5 mariadb-test mariadb-test-data
# Preserve the installed upstream documentation as well as PACK's licenses.
MARIADB_COMMA := ,
MARIADB_PACK = $(subst /share/{info$(MARIADB_COMMA)doc},/share/info,$(call PACK,$(1),DEB_MARIADB_V))

mariadb-package: mariadb-stage
	rm -rf $(addprefix $(BUILD_DIST)/,$(MARIADB_PACKAGES))
	cp -a $(BUILD_STAGE)/mariadb $(BUILD_DIST)/mariadb-server-10.5
	set -e; cd $(BUILD_DIST)/mariadb-server-10.5; \
	move_to() { dest="$(BUILD_DIST)/$$1"; shift; \
		for pattern in "$$@"; do for path in $$pattern; do \
			if [ -e "$$path" ] || [ -L "$$path" ]; then \
				mkdir -p "$$dest/$$(dirname "$$path")"; \
				mv "$$path" "$$dest/$$path"; \
			fi; \
		done; done; }; \
	move_to libmariadb-dev-compat 'usr/lib/libmysqlclient*.a' 'usr/lib/libmysqlclient*.dylib'; \
	move_to libmariadbd19 'usr/lib/libmariadbd.[0-9]*.dylib'; \
	move_to libmariadbd-dev 'usr/include/mysql/server' 'usr/lib/libmariadbd.a' 'usr/lib/libmariadbd.dylib' \
		'usr/lib/libmysqld.*' 'usr/lib/pkgconfig/mariadb.pc'; \
	move_to libmariadb3 'usr/lib/libmariadb.[0-9]*.dylib' \
		'usr/lib/mysql/plugin/caching_sha2_password.so' 'usr/lib/mysql/plugin/client_ed25519.so' \
		'usr/lib/mysql/plugin/dialog.so' 'usr/lib/mysql/plugin/mysql_clear_password.so' 'usr/lib/mysql/plugin/sha256_password.so'; \
	move_to libmariadb-dev 'usr/include' 'usr/lib/libmariadb*.a' 'usr/lib/libmariadb.dylib' 'usr/lib/libmysqlservices.a' \
		'usr/lib/pkgconfig/libmariadb.pc' 'usr/share/aclocal' 'usr/bin/mariadb_config' 'usr/bin/mariadb-config' 'usr/bin/mysql_config' \
		'usr/share/man/man1/mariadb_config.*' 'usr/share/man/man1/mysql_config.*'; \
	move_to mariadb-common 'etc/my.cnf' 'usr/share/doc'; \
	move_to mariadb-plugin-connect 'usr/lib/mysql/plugin/ha_connect.so' 'etc/my.cnf.d/connect.cnf'; \
	move_to mariadb-plugin-cracklib-password-check 'usr/lib/mysql/plugin/cracklib_password_check.so' 'etc/my.cnf.d/cracklib_password_check.cnf'; \
	move_to mariadb-plugin-mroonga 'usr/lib/mysql/plugin/ha_mroonga.so' 'usr/share/mysql/mroonga'; \
	move_to mariadb-plugin-rocksdb 'usr/lib/mysql/plugin/ha_rocksdb.so' 'usr/bin/mariadb-ldb' 'usr/bin/mysql_ldb' \
		'usr/bin/sst_dump' 'usr/bin/myrocks_hotbackup' 'etc/my.cnf.d/rocksdb.cnf' \
		'usr/share/man/man1/mariadb-ldb.*' 'usr/share/man/man1/mysql_ldb.*' 'usr/share/man/man1/myrocks_hotbackup.*'; \
	move_to mariadb-plugin-s3 'usr/lib/mysql/plugin/ha_s3.so' 'usr/bin/aria_s3_copy' 'etc/my.cnf.d/s3.cnf' 'usr/share/man/man1/aria_s3_copy.*'; \
	move_to mariadb-plugin-spider 'usr/lib/mysql/plugin/ha_spider.so' 'etc/my.cnf.d/spider.cnf' 'usr/share/mysql/*spider*'; \
	move_to mariadb-backup 'usr/bin/mariadb-backup' 'usr/bin/mariabackup' 'usr/bin/mbstream' \
		'usr/share/man/man1/mariadb-backup.*' 'usr/share/man/man1/mariabackup.*' 'usr/share/man/man1/mbstream.*'; \
	move_to mariadb-test 'usr/mysql-test/suite/plugins/pam/pam_mariadb_mtr.so'; \
	move_to mariadb-test-data 'usr/mysql-test/collections' 'usr/mysql-test/include' 'usr/mysql-test/main' \
		'usr/mysql-test/plugin' 'usr/mysql-test/std_data' 'usr/mysql-test/suite' 'usr/mysql-test/unstable-tests'; \
	move_to mariadb-test 'usr/bin/test-connect-t' 'usr/mysql-test' 'usr/bin/mariadb-client-test*' 'usr/bin/mysql_client_test*' \
		'usr/bin/mariadb-test*' 'usr/bin/mysqltest*' 'usr/lib/mysql/plugin/*test*.so' 'usr/lib/mysql/plugin/qa_auth*.so' \
		'usr/lib/mysql/plugin/*example*' 'usr/lib/mysql/plugin/debug_key_management.so' 'usr/lib/mysql/plugin/adt_null.so' \
		'usr/lib/mysql/plugin/audit_null.so' 'usr/share/man/man1/mariadb-client-test*' 'usr/share/man/man1/mysql_client_test*' \
		'usr/share/man/man1/mariadb-test*' 'usr/share/man/man1/mysqltest*' 'usr/share/man/man1/mysql-stress-test*' 'usr/share/man/man1/mysql-test-run*'; \
	move_to mariadb-client-core-10.5 'usr/bin/mariadb' 'usr/bin/mysql' 'usr/bin/mariadb-check' 'usr/bin/mysqlcheck' \
		'usr/share/man/man1/mariadb.1*' 'usr/share/man/man1/mysql.1*' 'usr/share/man/man1/mariadb-check.*' 'usr/share/man/man1/mysqlcheck.*'; \
	move_to mariadb-client-10.5 'usr/bin/mariadb-access' 'usr/bin/mysqlaccess' 'usr/bin/mariadb-admin' 'usr/bin/mysqladmin' \
		'usr/bin/mariadb-conv' 'usr/bin/mysqlconv' 'usr/bin/mariadb-dump' 'usr/bin/mysqldump' 'usr/bin/mariadb-dumpslow' 'usr/bin/mysqldumpslow' \
		'usr/bin/mariadb-find-rows' 'usr/bin/mysql_find_rows' 'usr/bin/mariadb-fix-extensions' 'usr/bin/mysql_fix_extensions' \
		'usr/bin/mariadb-import' 'usr/bin/mysqlimport' 'usr/bin/mariadb-show' 'usr/bin/mysqlshow' 'usr/bin/mariadb-slap' 'usr/bin/mysqlslap' \
		'usr/bin/mariadb-waitpid' 'usr/bin/mysql_waitpid' 'usr/bin/mytop' 'usr/bin/mariadb-embedded' 'usr/bin/mysql_embedded' \
		'etc/my.cnf.d/mysql-clients.cnf'; \
	for tool in mariadb-access mysqlaccess mariadb-admin mysqladmin mariadb-conv mysqlconv mariadb-dump mysqldump \
		mariadb-dumpslow mysqldumpslow mariadb-find-rows mysql_find_rows mariadb-fix-extensions mysql_fix_extensions \
		mariadb-import mysqlimport mariadb-show mysqlshow mariadb-slap mysqlslap mariadb-waitpid mysql_waitpid mytop mariadb-embedded mysql_embedded; do \
		move_to mariadb-client-10.5 "usr/share/man/man1/$$tool.*"; \
	done; \
	move_to mariadb-server-core-10.5 'usr/bin/mariadbd' 'usr/bin/mysqld' 'usr/bin/innochecksum' \
		'usr/bin/mariadb-install-db' 'usr/bin/mysql_install_db' 'usr/bin/mariadb-upgrade' 'usr/bin/mysql_upgrade' \
		'usr/bin/my_print_defaults' 'usr/bin/resolveip' 'usr/share/mysql/charsets' 'usr/share/mysql/*.sql' 'usr/share/man/man8'; \
	for tool in innochecksum mariadb-install-db mysql_install_db mariadb-upgrade mysql_upgrade my_print_defaults resolveip; do \
		move_to mariadb-server-core-10.5 "usr/share/man/man1/$$tool.*"; \
	done; \
	for messages in usr/share/mysql/*/errmsg.sys; do \
		if [ -f "$$messages" ]; then move_to mariadb-server-core-10.5 "$$(dirname "$$messages")"; fi; \
	done
	# Each output must contain real installed files, before adding licenses.
	set -e; for package in $(MARIADB_PACKAGES); do \
		test -d "$(BUILD_DIST)/$$package"; \
		find "$(BUILD_DIST)/$$package" \( -type f -o -type l \) -print -quit | grep -q .; \
	done
	# Keep the upstream aliases and provide Darwin's dynamic linker spelling.
	test -f $(BUILD_STAGE)/mariadb/usr/lib/libmariadbd.dylib
	ln -s libmariadbd.dylib $(BUILD_DIST)/libmariadbd-dev/usr/lib/libmysqld.dylib
	# The SDK liblzma is decode-only; embedded development needs the complete XZ library.
	sed -i 's| -llzma | $$pkglibdir/../local/lib/liblzma.dylib |' $(BUILD_DIST)/libmariadb-dev/usr/bin/mysql_config
	# Connector/C's LGPL license is distinct from the server license.
	set -e; for package in libmariadb3 libmariadb-dev libmariadb-dev-compat; do \
		$(INSTALL) -Dm644 $(BUILD_WORK)/mariadb/libmariadb/COPYING.LIB $(BUILD_DIST)/$$package/usr/share/doc/$$package/COPYING.LIB; \
	done
	$(call SIGN,libmariadb-dev,general.xml)
	$(call SIGN,libmariadb-dev-compat,general.xml)
	$(call SIGN,libmariadb3,general.xml)
	$(call SIGN,libmariadbd-dev,general.xml)
	$(call SIGN,libmariadbd19,general.xml)
	$(call SIGN,mariadb-backup,general.xml)
	$(call SIGN,mariadb-client-10.5,general.xml)
	$(call SIGN,mariadb-client-core-10.5,general.xml)
	$(call SIGN,mariadb-common,general.xml)
	$(call SIGN,mariadb-plugin-connect,general.xml)
	$(call SIGN,mariadb-plugin-cracklib-password-check,general.xml)
	$(call SIGN,mariadb-plugin-mroonga,general.xml)
	$(call SIGN,mariadb-plugin-rocksdb,general.xml)
	$(call SIGN,mariadb-plugin-s3,general.xml)
	$(call SIGN,mariadb-plugin-spider,general.xml)
	$(call SIGN,mariadb-server-10.5,general.xml)
	$(call SIGN,mariadb-server-core-10.5,general.xml)
	$(call SIGN,mariadb-test,general.xml)
	$(call SIGN,mariadb-test-data,general.xml)
	$(call MARIADB_PACK,libmariadb-dev)
	$(call MARIADB_PACK,libmariadb-dev-compat)
	$(call MARIADB_PACK,libmariadb3)
	$(call MARIADB_PACK,libmariadbd-dev)
	$(call MARIADB_PACK,libmariadbd19)
	$(call MARIADB_PACK,mariadb-backup)
	$(call MARIADB_PACK,mariadb-client-10.5)
	$(call MARIADB_PACK,mariadb-client-core-10.5)
	$(call MARIADB_PACK,mariadb-common)
	$(call MARIADB_PACK,mariadb-plugin-connect)
	$(call MARIADB_PACK,mariadb-plugin-cracklib-password-check)
	$(call MARIADB_PACK,mariadb-plugin-mroonga)
	$(call MARIADB_PACK,mariadb-plugin-rocksdb)
	$(call MARIADB_PACK,mariadb-plugin-s3)
	$(call MARIADB_PACK,mariadb-plugin-spider)
	$(call MARIADB_PACK,mariadb-server-10.5)
	$(call MARIADB_PACK,mariadb-server-core-10.5)
	$(call MARIADB_PACK,mariadb-test)
	$(call MARIADB_PACK,mariadb-test-data)
	rm -rf $(addprefix $(BUILD_DIST)/,$(MARIADB_PACKAGES))

.PHONY: mariadb mariadb-package
