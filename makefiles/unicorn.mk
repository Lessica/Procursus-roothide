ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS     += unicorn
UNICORN_VERSION := 2.0.1.post1
DEB_UNICORN_V   ?= $(UNICORN_VERSION)-2

unicorn-setup: setup
	$(call GITHUB_ARCHIVE,unicorn-engine,unicorn,$(UNICORN_VERSION),$(UNICORN_VERSION))
	$(call EXTRACT_TAR,unicorn-$(UNICORN_VERSION).tar.gz,unicorn-$(UNICORN_VERSION),unicorn)
	$(call DO_PATCH,unicorn,unicorn,-p1)
	rm $(BUILD_WORK)/unicorn/qemu/include/tcg/tcg-apple-jit.h
	$(call DOWNLOAD_FILES,$(BUILD_WORK)/unicorn/qemu/include/tcg/,https://raw.githubusercontent.com/utmapp/qemu/80c0e30/include/tcg/tcg-apple-jit.h)
	mkdir -p $(BUILD_WORK)/unicorn/build

ifneq ($(wildcard $(BUILD_WORK)/unicorn/.build_complete),)
unicorn:
	@echo "Using previously built unicorn."
else
unicorn: unicorn-setup
	cd $(BUILD_WORK)/unicorn/build && cmake . \
		$(DEFAULT_CMAKE_FLAGS) \
		-Dlib_tool="$$(command -v $(LIBTOOL))" \
		..
	+$(MAKE) -C $(BUILD_WORK)/unicorn/build
	+$(MAKE) -C $(BUILD_WORK)/unicorn/build install \
		DESTDIR="$(BUILD_STAGE)/unicorn"
	cd $(BUILD_WORK)/unicorn/bindings/python && unset MACOSX_DEPLOYMENT_TARGET && python3 ./setup.py \
		build \
		--executable="$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/python3" \
		install \
		--install-lib="$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/python3/dist-packages" \
		--root="$(BUILD_STAGE)/unicorn" \
		--prefix="$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)"
	find $(BUILD_STAGE)/unicorn -name __pycache__ -prune -exec rm -rf {} \;
ifneq ($(filter -flto%,$(CFLAGS)),)
	# Preserve installed LTO runtime/bindings; keep all configured emulator targets.
	: > $(BUILD_WORK)/unicorn/build/.native-static-flags
	cd $(BUILD_WORK)/unicorn/build && for link in CMakeFiles/*.dir/link.txt; do \
		grep -qE '(^|[[:space:]])[^[:space:]]*ar qc ' "$$link" || continue; \
		dir=$$(dirname "$$link"); flags="$$dir/flags.make"; \
		cp -p "$$flags" "$$flags.lto"; \
		sed -E -i '/^(C|CXX)_FLAGS[^[:space:]]* =/ { s/(^|[[:space:]])-flto(=[^[:space:]]+)?//g; s/$$/ -fno-lto/; }' "$$flags"; \
		touch -r "$$flags.lto" "$$flags"; echo "$$flags" >> .native-static-flags; \
		find "$$dir" -type f \( -name '*.c.o' -o -name '*.cc.o' -o -name '*.cpp.o' -o -name '*.cxx.o' \) -delete; \
	done
	rm -f $(BUILD_WORK)/unicorn/build/libunicorn.a
	+$(MAKE) -C $(BUILD_WORK)/unicorn/build bundling_target
	cd $(BUILD_WORK)/unicorn/build && while read flags; do mv -f "$$flags.lto" "$$flags"; done < .native-static-flags
	rm -f $(BUILD_WORK)/unicorn/build/.native-static-flags
	cp -a $(BUILD_WORK)/unicorn/build/libunicorn.a $(BUILD_STAGE)/unicorn/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/
endif
	$(call AFTER_BUILD,copy)
endif

unicorn-package: unicorn-stage
	# unicorn.mk Package Structure
	rm -rf $(BUILD_DIST)/{libunicorn{2,-dev},python3-unicorn}
	mkdir -p $(BUILD_DIST)/{libunicorn{2,-dev},python3-unicorn}/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# unicorn.mk Prep libunicorn2
	cp -a $(BUILD_STAGE)/unicorn/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libunicorn.2.dylib $(BUILD_DIST)/libunicorn2/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/

	# unicorn.mk Prep libunicorn-dev
	cp -a $(BUILD_STAGE)/unicorn/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/{pkgconfig,libunicorn.{dylib,a}} $(BUILD_DIST)/libunicorn-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/
	cp -a $(BUILD_STAGE)/unicorn/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include $(BUILD_DIST)/libunicorn-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/

	# unicorn.mk Prep python3-unicorn
	cp -a $(BUILD_STAGE)/unicorn/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/python3 $(BUILD_DIST)/python3-unicorn/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/

	# unicorn.mk Sign
	$(call SIGN,libunicorn2,general.xml)

	# unicorn.mk Make .debs
	$(call PACK,libunicorn2,DEB_UNICORN_V)
	$(call PACK,libunicorn-dev,DEB_UNICORN_V)
	$(call PACK,python3-unicorn,DEB_UNICORN_V)

	# unicorn.mk Build cleanup
	rm -rf $(BUILD_DIST)/{libunicorn{2,-dev},python3-unicorn}

.PHONY: unicorn unicorn-package
