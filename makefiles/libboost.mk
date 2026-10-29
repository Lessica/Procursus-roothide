ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS       += libboost
LIBBOOST_VERSION  := 1.84.0
DEB_LIBBOOST_V    ?= $(LIBBOOST_VERSION)-1

ifneq (,$(findstring amd64,$(MEMO_TARGET)))
LIBBOOST_CONFIGURE_ARGS := abi=sysv architecture=x86
else
LIBBOOST_CONFIGURE_ARGS := abi=aapcs architecture=arm
endif
LIBBOOST_CONFIGURE_ARGS += target-os=darwin binary-format=mach-o address-model=64

libboost-setup: setup
	$(call DOWNLOAD_FILES,$(BUILD_SOURCE),https://archives.boost.io/release/$(LIBBOOST_VERSION)/source/boost_$(shell echo $(LIBBOOST_VERSION) | sed 's/\./_/g').tar.bz2)
	$(call EXTRACT_TAR,boost_$(shell echo $(LIBBOOST_VERSION) | sed 's/\./_/g').tar.bz2,boost_$(shell echo $(LIBBOOST_VERSION) | sed 's/\./_/g'),libboost)

ifneq ($(wildcard $(BUILD_WORK)/libboost/.build_complete),)
libboost:
	@echo "Using previously built libboost."
else
libboost: libboost-setup xz zstd icu4c python3
	# Reinstall from b2 outputs before applying the versioned dylib layout.
	rm -rf $(BUILD_STAGE)/libboost
	rm -rf $(BUILD_BASE)$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libboost_*
	$(BUILD_WORK)/libboost/tools/build/src/engine/build.sh --cxx="$(CXX_FOR_BUILD)" --cxxflags="-std=c++14 $(CXXFLAGS_FOR_BUILD)"
ifneq (,$(findstring amd64,$(MEMO_TARGET)))
	echo "using clang-darwin : x86 : $(CXX) : <archiver>$(AR) <ranlib>$(RANLIB) <compileflags>\"$(CPPFLAGS) -I$(BUILD_STAGE)/python3/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include/$$(ls $(BUILD_STAGE)/python3/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include)\" <cflags>\"$(CFLAGS) -I$(BUILD_STAGE)/python3/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include/$$(ls $(BUILD_STAGE)/python3/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include)\" <cxxflags>\"$(CXXFLAGS) -I$(BUILD_STAGE)/python3/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include/$$(ls $(BUILD_STAGE)/python3/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include)\" <linkflags>\"$(LDFLAGS)\" ;" > $(BUILD_WORK)/libboost/tools/build/src/user-config.jam
else
	echo "using clang-darwin : arm : $(CXX) : <archiver>$(AR) <ranlib>$(RANLIB) <compileflags>\"$(CPPFLAGS) -I$(BUILD_STAGE)/python3/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include/$$(ls $(BUILD_STAGE)/python3/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include)\" <cflags>\"$(CFLAGS) -I$(BUILD_STAGE)/python3/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include/$$(ls $(BUILD_STAGE)/python3/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include)\" <cxxflags>\"$(CXXFLAGS) -I$(BUILD_STAGE)/python3/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include/$$(ls $(BUILD_STAGE)/python3/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include)\" <linkflags>\"$(LDFLAGS) $(BUILD_BASE)$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)$(MEMO_ALT_PREFIX)/lib/liblzma.dylib\" ;" > $(BUILD_WORK)/libboost/tools/build/src/user-config.jam
endif
	echo "using python : $(PYTHON3_MAJOR_V) : $(shell command -v $(PYTHON_HOST)) : $(BUILD_STAGE)/python3/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include/python$(PYTHON3_MAJOR_V) : $(BUILD_STAGE)/python3/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib : <target-os>darwin ;" >> $(BUILD_WORK)/libboost/tools/build/src/user-config.jam
	cd $(BUILD_WORK)/libboost && $(BUILD_WORK)/libboost/tools/build/src/engine/b2 \
		--reconfigure -j$(CORE_COUNT) \
		--prefix=$(BUILD_STAGE)/libboost/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX) \
		--without-mpi \
		--without-graph_parallel \
		threading=multi \
		variant=release \
		cxxstd="11" \
		$(LIBBOOST_CONFIGURE_ARGS) \
		install
ifneq ($(filter -flto%,$(CXXFLAGS)),)
	# Keep the installed LTO shared family. Reuse its b2 configuration and
	# force only static library targets, retaining original assembly members.
	+cd $(BUILD_WORK)/libboost && \
		cp tools/build/src/user-config.jam tools/build/src/user-config.jam.lto && \
		trap 'mv -f tools/build/src/user-config.jam.lto tools/build/src/user-config.jam' EXIT && \
		sed -i -E 's/-flto(=[^ "]+)?/-fno-lto/g' tools/build/src/user-config.jam && \
		tools/build/src/engine/b2 -a -j$(CORE_COUNT) \
			--stagedir=$(BUILD_WORK)/libboost/stage-native \
			--without-mpi --without-graph_parallel \
			threading=multi variant=release cxxstd="11" \
			$(LIBBOOST_CONFIGURE_ARGS) link=static stage && \
		cp -a stage-native/lib/libboost_*.a $(BUILD_STAGE)/libboost/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/
endif
	# F u boost!
	for lib in $(BUILD_STAGE)/libboost/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libboost_*.dylib; do \
		$(I_N_T) -id @rpath/$$(basename $$lib .dylib).$(LIBBOOST_VERSION).dylib $$lib; \
		for linked in $$($(OTOOL) -L $$lib | grep @rpath | sed 's/\ .*$$//' | tr -d '\011\013\014\015\040' | grep "libboost"); do \
			$(I_N_T) -change $$linked @rpath/$$(basename $$linked .dylib).$(LIBBOOST_VERSION).dylib $$lib; \
		done; \
		mv $$lib $$(dirname $$lib)/$$(basename $$lib .dylib).$(LIBBOOST_VERSION).dylib; \
		$(LN_S) $$(basename $$lib .dylib).$(LIBBOOST_VERSION).dylib $$lib; \
	done
	# Installed CMake packages must resolve from their own location, not the
	# temporary b2 install prefix (the original block only preserves symlinks).
	find $(BUILD_STAGE)/libboost/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/cmake -name '*.cmake' -type f \
		-exec sed -i '/^# If the computed and the original directories are symlink-equivalent, use original$$/,/^endif()$$/d' {} +
	$(call AFTER_BUILD,copy)
endif

libboost-package: libboost-stage
	# libboost.mk Package Structure
	rm -rf $(BUILD_DIST)/libboost*/
	mkdir -p $(BUILD_DIST)/libboost-all-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib \
		$(BUILD_DIST)/libboost-{atomic,chrono,container,context,contract,coroutine,date-time,fiber,filesystem,graph,iostreams,json,locale,log,math,nowide,program-options,python,random,regex,serialization,stacktrace,system,test,thread,timer,type-erasure,wave}$(LIBBOOST_VERSION)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib \
		$(BUILD_DIST)/libboost$(LIBBOOST_VERSION)-all

	# libboost.mk Prep libboost-all-dev
	cp -a $(BUILD_STAGE)/libboost/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include $(BUILD_DIST)/libboost-all-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/
	cp -a $(BUILD_STAGE)/libboost/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/!(*$(LIBBOOST_VERSION)*) $(BUILD_DIST)/libboost-all-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libboost.mk Prep libboost-*$(LIBBOOST_VERSION)
	cp -a $(BUILD_STAGE)/libboost/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libboost_atomic.$(LIBBOOST_VERSION).dylib $(BUILD_DIST)/libboost-atomic$(LIBBOOST_VERSION)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libboost/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libboost_chrono.$(LIBBOOST_VERSION).dylib $(BUILD_DIST)/libboost-chrono$(LIBBOOST_VERSION)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libboost/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libboost_container.$(LIBBOOST_VERSION).dylib $(BUILD_DIST)/libboost-container$(LIBBOOST_VERSION)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libboost/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libboost_context.$(LIBBOOST_VERSION).dylib $(BUILD_DIST)/libboost-context$(LIBBOOST_VERSION)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libboost/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libboost_contract.$(LIBBOOST_VERSION).dylib $(BUILD_DIST)/libboost-contract$(LIBBOOST_VERSION)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libboost/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libboost_coroutine.$(LIBBOOST_VERSION).dylib $(BUILD_DIST)/libboost-coroutine$(LIBBOOST_VERSION)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libboost/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libboost_date_time.$(LIBBOOST_VERSION).dylib $(BUILD_DIST)/libboost-date-time$(LIBBOOST_VERSION)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libboost/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libboost_fiber.$(LIBBOOST_VERSION).dylib $(BUILD_DIST)/libboost-fiber$(LIBBOOST_VERSION)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libboost/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libboost_filesystem.$(LIBBOOST_VERSION).dylib $(BUILD_DIST)/libboost-filesystem$(LIBBOOST_VERSION)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libboost/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libboost_graph.$(LIBBOOST_VERSION).dylib $(BUILD_DIST)/libboost-graph$(LIBBOOST_VERSION)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libboost/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libboost_iostreams.$(LIBBOOST_VERSION).dylib $(BUILD_DIST)/libboost-iostreams$(LIBBOOST_VERSION)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libboost/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libboost_json.$(LIBBOOST_VERSION).dylib $(BUILD_DIST)/libboost-json$(LIBBOOST_VERSION)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libboost/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libboost_locale.$(LIBBOOST_VERSION).dylib $(BUILD_DIST)/libboost-locale$(LIBBOOST_VERSION)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libboost/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libboost_log{,_setup}.$(LIBBOOST_VERSION).dylib $(BUILD_DIST)/libboost-log$(LIBBOOST_VERSION)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libboost/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libboost_math_*.$(LIBBOOST_VERSION).dylib $(BUILD_DIST)/libboost-math$(LIBBOOST_VERSION)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libboost/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libboost_nowide.$(LIBBOOST_VERSION).dylib $(BUILD_DIST)/libboost-nowide$(LIBBOOST_VERSION)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libboost/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libboost_program_options.$(LIBBOOST_VERSION).dylib $(BUILD_DIST)/libboost-program-options$(LIBBOOST_VERSION)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libboost/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libboost_python*.$(LIBBOOST_VERSION).dylib $(BUILD_DIST)/libboost-python$(LIBBOOST_VERSION)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libboost/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libboost_random.$(LIBBOOST_VERSION).dylib $(BUILD_DIST)/libboost-random$(LIBBOOST_VERSION)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libboost/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libboost_regex.$(LIBBOOST_VERSION).dylib $(BUILD_DIST)/libboost-regex$(LIBBOOST_VERSION)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libboost/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libboost_{,w}serialization.$(LIBBOOST_VERSION).dylib $(BUILD_DIST)/libboost-serialization$(LIBBOOST_VERSION)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libboost/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libboost_stacktrace*.$(LIBBOOST_VERSION).dylib $(BUILD_DIST)/libboost-stacktrace$(LIBBOOST_VERSION)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libboost/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libboost_system.$(LIBBOOST_VERSION).dylib $(BUILD_DIST)/libboost-system$(LIBBOOST_VERSION)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libboost/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libboost_{prg_exec_monitor,unit_test_framework}.$(LIBBOOST_VERSION).dylib $(BUILD_DIST)/libboost-test$(LIBBOOST_VERSION)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libboost/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libboost_thread.$(LIBBOOST_VERSION).dylib $(BUILD_DIST)/libboost-thread$(LIBBOOST_VERSION)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libboost/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libboost_timer.$(LIBBOOST_VERSION).dylib $(BUILD_DIST)/libboost-timer$(LIBBOOST_VERSION)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libboost/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libboost_type_erasure.$(LIBBOOST_VERSION).dylib $(BUILD_DIST)/libboost-type-erasure$(LIBBOOST_VERSION)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/libboost/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libboost_wave.$(LIBBOOST_VERSION).dylib $(BUILD_DIST)/libboost-wave$(LIBBOOST_VERSION)/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# libboost.mk Sign
	$(call SIGN,libboost-atomic$(LIBBOOST_VERSION),general.xml)
	$(call SIGN,libboost-chrono$(LIBBOOST_VERSION),general.xml)
	$(call SIGN,libboost-container$(LIBBOOST_VERSION),general.xml)
	$(call SIGN,libboost-context$(LIBBOOST_VERSION),general.xml)
	$(call SIGN,libboost-contract$(LIBBOOST_VERSION),general.xml)
	$(call SIGN,libboost-coroutine$(LIBBOOST_VERSION),general.xml)
	$(call SIGN,libboost-date-time$(LIBBOOST_VERSION),general.xml)
	$(call SIGN,libboost-fiber$(LIBBOOST_VERSION),general.xml)
	$(call SIGN,libboost-filesystem$(LIBBOOST_VERSION),general.xml)
	$(call SIGN,libboost-graph$(LIBBOOST_VERSION),general.xml)
	$(call SIGN,libboost-iostreams$(LIBBOOST_VERSION),general.xml)
	$(call SIGN,libboost-json$(LIBBOOST_VERSION),general.xml)
	$(call SIGN,libboost-locale$(LIBBOOST_VERSION),general.xml)
	$(call SIGN,libboost-log$(LIBBOOST_VERSION),general.xml)
	$(call SIGN,libboost-math$(LIBBOOST_VERSION),general.xml)
	$(call SIGN,libboost-nowide$(LIBBOOST_VERSION),general.xml)
	$(call SIGN,libboost-program-options$(LIBBOOST_VERSION),general.xml)
	$(call SIGN,libboost-python$(LIBBOOST_VERSION),general.xml)
	$(call SIGN,libboost-random$(LIBBOOST_VERSION),general.xml)
	$(call SIGN,libboost-regex$(LIBBOOST_VERSION),general.xml)
	$(call SIGN,libboost-serialization$(LIBBOOST_VERSION),general.xml)
	$(call SIGN,libboost-stacktrace$(LIBBOOST_VERSION),general.xml)
	$(call SIGN,libboost-system$(LIBBOOST_VERSION),general.xml)
	$(call SIGN,libboost-test$(LIBBOOST_VERSION),general.xml)
	$(call SIGN,libboost-thread$(LIBBOOST_VERSION),general.xml)
	$(call SIGN,libboost-timer$(LIBBOOST_VERSION),general.xml)
	$(call SIGN,libboost-type-erasure$(LIBBOOST_VERSION),general.xml)
	$(call SIGN,libboost-wave$(LIBBOOST_VERSION),general.xml)

	# libboost.mk Make .debs
	$(call PACK,libboost-all-dev,DEB_LIBBOOST_V)
	$(call PACK,libboost$(LIBBOOST_VERSION)-all,DEB_LIBBOOST_V)
	$(call PACK,libboost-atomic$(LIBBOOST_VERSION),DEB_LIBBOOST_V)
	$(call PACK,libboost-chrono$(LIBBOOST_VERSION),DEB_LIBBOOST_V)
	$(call PACK,libboost-container$(LIBBOOST_VERSION),DEB_LIBBOOST_V)
	$(call PACK,libboost-context$(LIBBOOST_VERSION),DEB_LIBBOOST_V)
	$(call PACK,libboost-contract$(LIBBOOST_VERSION),DEB_LIBBOOST_V)
	$(call PACK,libboost-coroutine$(LIBBOOST_VERSION),DEB_LIBBOOST_V)
	$(call PACK,libboost-date-time$(LIBBOOST_VERSION),DEB_LIBBOOST_V)
	$(call PACK,libboost-fiber$(LIBBOOST_VERSION),DEB_LIBBOOST_V)
	$(call PACK,libboost-filesystem$(LIBBOOST_VERSION),DEB_LIBBOOST_V)
	$(call PACK,libboost-graph$(LIBBOOST_VERSION),DEB_LIBBOOST_V)
	$(call PACK,libboost-iostreams$(LIBBOOST_VERSION),DEB_LIBBOOST_V)
	$(call PACK,libboost-json$(LIBBOOST_VERSION),DEB_LIBBOOST_V)
	$(call PACK,libboost-locale$(LIBBOOST_VERSION),DEB_LIBBOOST_V)
	$(call PACK,libboost-log$(LIBBOOST_VERSION),DEB_LIBBOOST_V)
	$(call PACK,libboost-math$(LIBBOOST_VERSION),DEB_LIBBOOST_V)
	$(call PACK,libboost-nowide$(LIBBOOST_VERSION),DEB_LIBBOOST_V)
	$(call PACK,libboost-program-options$(LIBBOOST_VERSION),DEB_LIBBOOST_V)
	$(call PACK,libboost-python$(LIBBOOST_VERSION),DEB_LIBBOOST_V)
	$(call PACK,libboost-random$(LIBBOOST_VERSION),DEB_LIBBOOST_V)
	$(call PACK,libboost-regex$(LIBBOOST_VERSION),DEB_LIBBOOST_V)
	$(call PACK,libboost-serialization$(LIBBOOST_VERSION),DEB_LIBBOOST_V)
	$(call PACK,libboost-stacktrace$(LIBBOOST_VERSION),DEB_LIBBOOST_V)
	$(call PACK,libboost-system$(LIBBOOST_VERSION),DEB_LIBBOOST_V)
	$(call PACK,libboost-test$(LIBBOOST_VERSION),DEB_LIBBOOST_V)
	$(call PACK,libboost-thread$(LIBBOOST_VERSION),DEB_LIBBOOST_V)
	$(call PACK,libboost-timer$(LIBBOOST_VERSION),DEB_LIBBOOST_V)
	$(call PACK,libboost-type-erasure$(LIBBOOST_VERSION),DEB_LIBBOOST_V)
	$(call PACK,libboost-wave$(LIBBOOST_VERSION),DEB_LIBBOOST_V)

	# libboost.mk Build cleanup
	rm -rf $(BUILD_DIST)/libboost*/

.PHONY: libboost libboost-package
