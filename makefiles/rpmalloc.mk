ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS      += rpmalloc
RPMALLOC_VERSION := 1.4.1
DEB_RPMALLOC_V   ?= $(RPMALLOC_VERSION)-2

rpmalloc-setup: setup
	$(call DOWNLOAD_FILES,$(BUILD_WORK)/rpmalloc, \
		https://raw.githubusercontent.com/mjansson/rpmalloc/1.4.1/rpmalloc/malloc.c \
		https://raw.githubusercontent.com/mjansson/rpmalloc/1.4.1/rpmalloc/rpmalloc.{c$(comma)h})

ifneq ($(wildcard $(BUILD_WORK)/rpmalloc/.build_complete),)
rpmalloc:
	@echo "Using previously built rpmalloc."
else
rpmalloc: rpmalloc-setup
	$(CC) $(CFLAGS) $(BUILD_WORK)/rpmalloc/rpmalloc.c -DENABLE_PRELOAD=1 -DENABLE_OVERRIDE=1 -o $(BUILD_WORK)/rpmalloc/rpmalloc.o -c
	$(AR) -crs $(BUILD_WORK)/rpmalloc/librpmalloc.a $(BUILD_WORK)/rpmalloc/rpmalloc.o
	$(CC) $(CFLAGS) $(LDFLAGS) $(BUILD_WORK)/rpmalloc/rpmalloc.o -dynamiclib -o $(BUILD_WORK)/rpmalloc/librpmalloc.0.dylib -install_name "$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/librpmalloc.0.dylib"
	$(INSTALL) -Dm0755 $(BUILD_WORK)/rpmalloc/librpmalloc.0.dylib $(BUILD_STAGE)/rpmalloc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/librpmalloc.0.dylib
ifneq ($(filter -flto%,$(CFLAGS)),)
	# Keep the installed LTO dylib and compile an independent native archive input.
	mkdir -p $(BUILD_WORK)/rpmalloc/static
	$(CC) $(CFLAGS) -fno-lto $(BUILD_WORK)/rpmalloc/rpmalloc.c -DENABLE_PRELOAD=1 -DENABLE_OVERRIDE=1 -o $(BUILD_WORK)/rpmalloc/static/rpmalloc.o -c
	rm -f $(BUILD_WORK)/rpmalloc/librpmalloc.a
	$(AR) -crs $(BUILD_WORK)/rpmalloc/librpmalloc.a $(BUILD_WORK)/rpmalloc/static/rpmalloc.o
endif
	$(INSTALL) -Dm0644 $(BUILD_WORK)/rpmalloc/librpmalloc.a $(BUILD_STAGE)/rpmalloc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/librpmalloc.a
	$(INSTALL) -Dm0644 $(BUILD_WORK)/rpmalloc/rpmalloc.h $(BUILD_STAGE)/rpmalloc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include/rpmalloc.h
	$(LN_S) librpmalloc.0.dylib $(BUILD_STAGE)/rpmalloc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/librpmalloc.dylib
	$(call AFTER_BUILD,copy)
endif

rpmalloc-package: rpmalloc-stage
	# rpmalloc.mk Package Structure
	rm -rf $(BUILD_DIST)/librpmalloc{0,-dev}
	mkdir -p $(BUILD_DIST)/librpmalloc{0,-dev}/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# rpmalloc.mk Prep librpmalloc0
	cp -a $(BUILD_STAGE)/rpmalloc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/librpmalloc.0.dylib $(BUILD_DIST)/librpmalloc0/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# rpmalloc.mk Prep librpmalloc-dev
	cp -a $(BUILD_STAGE)/rpmalloc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/librpmalloc.{dylib,a} $(BUILD_DIST)/librpmalloc-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/rpmalloc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include $(BUILD_DIST)/librpmalloc-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)

	# rpmalloc.mk Sign
	$(call SIGN,librpmalloc0,general.xml)

	# rpmalloc.mk Make .debs
	$(call PACK,librpmalloc0,DEB_RPMALLOC_V)
	$(call PACK,librpmalloc-dev,DEB_RPMALLOC_V)

	# rpmalloc.mk Build cleanup
	rm -rf $(BUILD_DIST)/librpmalloc{0,-dev}

.PHONY: rpmalloc rpmalloc-package
