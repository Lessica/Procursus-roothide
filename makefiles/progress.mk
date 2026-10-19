ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS      += progress
PROGRESS_VERSION := 0.16
DEB_PROGRESS_V   ?= $(PROGRESS_VERSION)

progress-setup: setup
	$(call GITHUB_ARCHIVE,Xfennec,progress,$(PROGRESS_VERSION),v$(PROGRESS_VERSION))
	$(call EXTRACT_TAR,progress-$(PROGRESS_VERSION).tar.gz,progress-$(PROGRESS_VERSION),progress)
	sed -i 's/-lncursesww/-lncursesw/g; s/-lncurses\([^w]\|$\)/-lncursesw\1/g' $(BUILD_WORK)/progress/Makefile

ifeq (,$(findstring darwin,$(MEMO_TARGET)))
	$(call DOWNLOAD_FILES,$(BUILD_WORK)/progress,https://raw.githubusercontent.com/NetBSD/src/trunk/{lib/libc/gen/wordexp.c$(comma)include/wordexp.h})
	echo 'b4b5590b58c72c37d5284767275b175c1feaa569c5f269b2f90d669b6108c20b  $(BUILD_WORK)/progress/wordexp.c' | shasum -a 256 -c -
	echo '9497c55ed1a5640bfaf1b3956549dd893b31a2acc7a83b07cb9a76c7b5f2f213  $(BUILD_WORK)/progress/wordexp.h' | shasum -a 256 -c -
	$(call DO_PATCH,progress,progress,-p1)
endif
	mv $(BUILD_WORK)/progress/progress.1 $(BUILD_WORK)/progress/cv-progress.1

ifneq ($(wildcard $(BUILD_WORK)/progress/.build_complete),)
progress:
	@echo "Using previously built progress."
else
progress: progress-setup ncurses
	+$(MAKE) -C $(BUILD_WORK)/progress install \
		OBJ="cv-progress" \
		UNAME="Darwin" \
		PREFIX="$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)" \
		DESTDIR="$(BUILD_STAGE)/progress"
	$(call AFTER_BUILD)
endif

progress-package: progress-stage
	# progress.mk Package Structure
	rm -rf $(BUILD_DIST)/progress

	# progress.mk Prep progress
	cp -a $(BUILD_STAGE)/progress $(BUILD_DIST)

	# progress.mk Sign
	$(call SIGN,progress,general.xml)

	# progress.mk Make .debs
	$(call PACK,progress,DEB_PROGRESS_V)

	# progress.mk Build cleanup
	rm -rf $(BUILD_DIST)/progress

.PHONY: progress progress-package
