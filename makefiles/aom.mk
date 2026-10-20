ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS   += aom
AOM_VERSION   := 3.3.0
DEB_AOM_V     ?= $(AOM_VERSION)-1

aom-setup: setup
	$(call GIT_CLONE,https://aomedia.googlesource.com/aom.git,v$(AOM_VERSION),aom)

ifneq ($(wildcard $(BUILD_WORK)/aom/.build_complete),)
aom:
	@echo "Using previously built aom."
else
aom: aom-setup
	cd $(BUILD_WORK)/aom/build && cmake . \
		$(DEFAULT_CMAKE_FLAGS) \
		-DBUILD_SHARED_LIBS=1 \
		-DCONFIG_RUNTIME_CPU_DETECT=0 \
		-DENABLE_TESTS=0 \
		-DENABLE_DOCS=0 \
		-DGIT_EXECUTABLE=/non-existant-binary \
		-DAOM_TARGET_CPU="$(MEMO_ARCH)" \
		..
	+$(MAKE) -C $(BUILD_WORK)/aom/build
	+$(MAKE) -C $(BUILD_WORK)/aom/build install \
		DESTDIR="$(BUILD_STAGE)/aom"
ifneq ($(filter -flto%,$(CFLAGS)),)
	# Keep installed LTO programs/dylib and original assembly objects.
	# The static target shares object libraries; retain their CPU options/macros.
	for flags in $$(find $(BUILD_WORK)/aom/build -type f -name flags.make \
		! -path '*/CMakeFiles/aom.dir/*' ! -path '*/CMakeFiles/aom_version.dir/*'); do \
		cp -p "$$flags" "$$flags.lto"; \
		sed -E '/^(C|CXX)_FLAGS[^=]* =/ { s/(^|[[:space:]])-flto(=[^[:space:]]*)?//g; s/$$/ -fno-lto/; }' "$$flags.lto" > "$$flags"; \
		touch -r "$$flags.lto" "$$flags"; \
		find "$$(dirname "$$flags")" -type f \
			\( -name '*.c.o' -o -name '*.cc.o' -o -name '*.cpp.o' -o -name '*.cxx.o' \) -delete; \
	done
	rm -f $(BUILD_WORK)/aom/build/libaom.a
	+$(MAKE) -C $(BUILD_WORK)/aom/build aom_static
	cp -a $(BUILD_WORK)/aom/build/libaom.a $(BUILD_STAGE)/aom/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/
	for flags in $$(find $(BUILD_WORK)/aom/build -type f -name flags.make.lto); do mv "$$flags" "$${flags%.lto}"; done
endif
	$(call AFTER_BUILD,copy)
endif

aom-package: aom-stage
	# aom.mk Package Structure
	rm -rf $(BUILD_DIST)/aom-tools $(BUILD_DIST)/libaom{3,-dev}
	mkdir -p $(BUILD_DIST)/aom-tools/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/ \
		$(BUILD_DIST)/libaom{3,-dev}/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# aom.mk Prep aom-tools
	cp -a $(BUILD_STAGE)/aom/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin $(BUILD_DIST)/aom-tools/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)

	# aom.mk Prep libaom3
	cp -a $(BUILD_STAGE)/aom/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libaom.3*.dylib $(BUILD_DIST)/libaom3/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# aom.mk Prep libaom-pkg-dev
	cp -a $(BUILD_STAGE)/aom/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/!(libaom.3*.dylib) $(BUILD_DIST)/libaom-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/aom/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include $(BUILD_DIST)/libaom-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)

	# aom.mk Sign
	$(call SIGN,aom-tools,general.xml)
	$(call SIGN,libaom3,general.xml)

	# aom.mk Make .debs
	$(call PACK,aom-tools,DEB_AOM_V)
	$(call PACK,libaom3,DEB_AOM_V)
	$(call PACK,libaom-dev,DEB_AOM_V)

	# aom.mk Build cleanup
	rm -rf $(BUILD_DIST)/aom-tools $(BUILD_DIST)/libaom{3,-dev}

.PHONY: aom aom-package
