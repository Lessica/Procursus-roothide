ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS   += sdl2
SDL2_VERSION  := 2.0.14
DEB_SDL2_V    ?= $(SDL2_VERSION)-1

### Do X11 stuff with this later

ifneq (,$(findstring darwin,$(MEMO_TARGET)))
SDL2_CONFIGURE_FLAGS :=
else
SDL2_CONFIGURE_FLAGS := --host=aarch64-ios-darwin \
						CFLAGS="-DNDEBUG -DIOS_DYLIB -fPIC -fobjc-arc $(CFLAGS)" \
						CPPFLAGS="-DNDEBUG -DIOS_DYLIB -fPIC -fobjc-arc $(CPPFLAGS)"
endif

sdl2-setup: setup
	$(call DOWNLOAD_FILES,$(BUILD_SOURCE),https://libsdl.org/release/SDL2-$(SDL2_VERSION).tar.gz)
	$(call EXTRACT_TAR,SDL2-$(SDL2_VERSION).tar.gz,SDL2-$(SDL2_VERSION),sdl2)
ifneq ($(filter appletvos%,$(MEMO_TARGET)),)
	# SDL's CoreMotion backend is guarded by TARGET_OS_IOS, not TARGET_OS_TV.
	sed -i -e '/EXTRA_LDFLAGS=.*-framework,CoreMotion/d' \
		-e 's/SDL_SENSOR_COREMOTION/SDL_SENSOR_DUMMY/g' \
		-e 's@src/sensor/coremotion/\*.m@src/sensor/dummy/*.c@g' $(BUILD_WORK)/sdl2/configure
endif
ifeq (,$(findstring darwin,$(MEMO_TARGET)))
	sed -i -e 's/have_metal=no/have_metal=yes/' -e '/\ CheckMETAL/a CheckHIDAPI' \
		-e '/framework,UIKit/a EXTRA_LDFLAGS="\$$EXTRA_LDFLAGS -Wl,-framework,IOKit -Wl,-framework,CoreHaptics"' $(BUILD_WORK)/sdl2/configure
	sed -i 's/#elif __MACOSX__/#elif __APPLE__/' $(BUILD_WORK)/sdl2/src/hidapi/SDL_hidapi.c
endif

ifneq ($(wildcard $(BUILD_WORK)/sdl2/.build_complete),)
sdl2:
	@echo "Using previously built sdl2."
else
sdl2: sdl2-setup
	cd $(BUILD_WORK)/sdl2 && ./configure -C \
		$(DEFAULT_CONFIGURE_FLAGS) \
		--enable-hidapi \
		--without-x \
		LIBS="-framework GameController -framework CoreHaptics" \
		$(SDL2_CONFIGURE_FLAGS)
ifeq (,$(findstring darwin,$(MEMO_TARGET)))
	cp $(BUILD_WORK)/sdl2/include/SDL_config_iphoneos.h $(BUILD_WORK)/sdl2/include/SDL_config.h
endif
	# iOS backends use C99 declarations; retain the warning without treating it as an error.
	sed -i 's/-Werror=declaration-after-statement/-Wno-error=declaration-after-statement/g' $(BUILD_WORK)/sdl2/Makefile
	+$(MAKE) -C $(BUILD_WORK)/sdl2 install \
		DESTDIR=$(BUILD_STAGE)/sdl2
ifneq ($(filter -flto%,$(CFLAGS)),)
	# Keep installed LTO dylib and all iOS backends; cover all three archives.
	+$(MAKE) -C $(BUILD_WORK)/sdl2 clean
	+$(MAKE) -C $(BUILD_WORK)/sdl2 build/libSDL2.la build/libSDL2main.la build/libSDL2_test.la \
		CFLAGS="$$(sed -n 's/^CFLAGS[[:space:]]*=[[:space:]]*//p' $(BUILD_WORK)/sdl2/Makefile | sed -E 's/(^|[[:space:]])-flto(=[^[:space:]]*)?//g') -fno-lto" \
		EXTRA_CFLAGS="$$(sed -n 's/^EXTRA_CFLAGS[[:space:]]*=[[:space:]]*//p' $(BUILD_WORK)/sdl2/Makefile | sed -E 's/(^|[[:space:]])-flto(=[^[:space:]]*)?//g') -fno-lto" \
		LDFLAGS="$$(sed -n 's/^LDFLAGS[[:space:]]*=[[:space:]]*//p' $(BUILD_WORK)/sdl2/Makefile | sed -E 's/(^|[[:space:]])-flto(=[^[:space:]]*)?//g') -static"
	cp -a $(BUILD_WORK)/sdl2/build/.libs/libSDL2{,main,_test}.a $(BUILD_STAGE)/sdl2/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/
endif
	$(call AFTER_BUILD,copy)
endif

sdl2-package: sdl2-stage
	# sdl2.mk Package Structure
	rm -rf $(BUILD_DIST)/libsdl2-{2.0-0,dev}
	mkdir -p $(BUILD_DIST)/libsdl2-{2.0-0,dev}/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# sdl2.mk Prep libsdl2-2.0-0
	cp -a $(BUILD_STAGE)/sdl2/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/libSDL2-2.0.0.dylib $(BUILD_DIST)/libsdl2-2.0-0/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# sdl2.mk Prep libsdl2-dev
	cp -a $(BUILD_STAGE)/sdl2/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/!(libSDL2-2.0.0.dylib) $(BUILD_DIST)/libsdl2-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib
	cp -a $(BUILD_STAGE)/sdl2/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/!(lib) $(BUILD_DIST)/libsdl2-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)

	# sdl2.mk Sign
	$(call SIGN,libsdl2-2.0-0,general.xml)

	# sdl2.mk Make .debs
	$(call PACK,libsdl2-2.0-0,DEB_SDL2_V)
	$(call PACK,libsdl2-dev,DEB_SDL2_V)

	# sdl2.mk Build cleanup
	rm -rf $(BUILD_DIST)/libsdl2-{2.0-0,dev}

.PHONY: sdl2 sdl2-package
