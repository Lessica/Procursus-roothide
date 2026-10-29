ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS  += calc
CALC_VERSION := 2.13.0.1
DEB_CALC_V   ?= $(CALC_VERSION)-1
CALC_TARGET_CFLAGS = $(CFLAGS) -DCALC_SRC -DCUSTOMHELPDIR=\"\\\"$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/calc/custhelp\\\"\" -DHELPDIR=\"\\\"$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/calc/help\\\"\" -DDEFAULTCALCPATH=\"\\\".:./cal:~/.cal:$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/calc:$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/calc/custom\\\"\" -I$(BUILD_WORK)

calc-setup: setup
	$(call DOWNLOAD_FILES,$(BUILD_SOURCE),https://github.com/lcn2/calc/releases/download/v$(CALC_VERSION)/calc-$(CALC_VERSION).tar.bz2)
	$(call EXTRACT_TAR,calc-$(CALC_VERSION).tar.bz2,calc-$(CALC_VERSION),calc)
	$(call DO_PATCH,calc,calc,-p1)
	sed -i '/#include <stdio.h>/a #include <string.h>' $(BUILD_WORK)/calc/have_memmv.c
	sed -i '/#include <stdio.h>/a #include <string.h>' $(BUILD_WORK)/calc/have_newstr.c
	sed -i '/#include <stdio.h>/a #include <unistd.h>' $(BUILD_WORK)/calc/have_posscl.c

ifneq ($(wildcard $(BUILD_WORK)/calc/.build_complete),)
calc:
	@echo "Using previously built calc."
else
calc: calc-setup ncurses readline
	+$(MAKE) -C $(BUILD_WORK)/calc install \
		LCC="$(CC_FOR_BUILD)" \
		ICFLAGS="$(CFLAGS_FOR_BUILD)" \
		ILDFLAGS="$(LDFLAGS_FOR_BUILD)" \
		CC="$(CC)" AR="$(AR)" RANLIB="$(RANLIB)" \
		CFLAGS="$(CALC_TARGET_CFLAGS)" \
		LDFLAGS="$(LDFLAGS)" \
		target="Darwin" \
		BINDIR="$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin" \
		LIBDIR="$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib" \
		INCDIR="$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include" \
		CALC_SHAREDIR="$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/share/calc" \
		CALCPAGER="pager" \
		USE_READLINE="-DUSE_READLINE" \
		READLINE_LIB="-lreadline" \
		READLINE_EXTRAS="-L$(BUILD_BASE)$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib -lncursesw" \
		BLD_TYPE="calc-static-only" \
		T="$(BUILD_STAGE)/calc" \
		-j1
ifneq ($(filter -flto%,$(CFLAGS)),)
	# The installed executable retains its normal LTO-linked libraries.
	set -e; for obj in $$($(AR) t $(BUILD_WORK)/calc/libcalc.a); do rm -f $(BUILD_WORK)/calc/$$obj; done
	set -e; for obj in $$($(AR) t $(BUILD_WORK)/calc/custom/libcustcalc.a); do rm -f $(BUILD_WORK)/calc/custom/$$obj; done
	rm -f $(BUILD_WORK)/calc/{libcalc,libcustcalc}.a $(BUILD_WORK)/calc/custom/libcustcalc.a
	+$(MAKE) -C $(BUILD_WORK)/calc libcalc.a libcustcalc.a \
		LCC="$(CC_FOR_BUILD)" ICFLAGS="$(CFLAGS_FOR_BUILD)" ILDFLAGS="$(LDFLAGS_FOR_BUILD)" \
		CC="$(CC)" AR="$(AR)" RANLIB="$(RANLIB)" CFLAGS="$(CALC_TARGET_CFLAGS) -fno-lto" LDFLAGS="$(LDFLAGS) -fno-lto" \
		USE_READLINE="-DUSE_READLINE" READLINE_LIB="-lreadline" \
		READLINE_EXTRAS="-L$(BUILD_BASE)$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib -lncursesw" \
		target="Darwin" BLD_TYPE="calc-static-only" -j1
	cp -a $(BUILD_WORK)/calc/{libcalc,libcustcalc}.a $(BUILD_STAGE)/calc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/
endif
	rm -rf $(BUILD_STAGE)/calc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/{cscript,calc-static}
	$(call AFTER_BUILD)
endif

calc-package: calc-stage
	# calc.mk Package Structure
	rm -rf $(BUILD_DIST)/calc{,-dev}
	mkdir -p $(BUILD_DIST)/calc{,-dev}/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# calc.mk Prep calc
	cp -a $(BUILD_STAGE)/calc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/{bin,share} $(BUILD_DIST)/calc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)

	# calc.mk Prep calc-dev
	cp -a $(BUILD_STAGE)/calc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/include $(BUILD_DIST)/calc-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)
	cp -a $(BUILD_STAGE)/calc/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib/*.a $(BUILD_DIST)/calc-dev/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/lib

	# calc.mk Sign
	$(call SIGN,calc,general.xml)

	# calc.mk Make .debs
	$(call PACK,calc,DEB_CALC_V)
	$(call PACK,calc-dev,DEB_CALC_V)

	# calc.mk Build cleanup
	rm -rf $(BUILD_DIST)/calc{,-dev}

.PHONY: calc calc-package
