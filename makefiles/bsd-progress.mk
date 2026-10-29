ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS          += bsd-progress
BSD_PROGRESS_VERSION := 9.99.81
BSD_PROGRESS_COMMIT  := a9bda63998e2f358b07a50a8dd4ed48100f9a9ee
DEB_BSD_PROGRESS_V   ?= $(BSD_PROGRESS_VERSION)

bsd-progress-setup: setup
	$(call DOWNLOAD_FILES,$(BUILD_SOURCE), \
		https://github.com/CRKatri/bsd-progress/archive/$(BSD_PROGRESS_COMMIT).tar.gz)
	@echo "300a9e6a08da645aee0b26893f735cf3436f46d107778b0fc4f0f3ee697b0a22  $(BUILD_SOURCE)/$(BSD_PROGRESS_COMMIT).tar.gz" | shasum -a 256 -c -
	$(call EXTRACT_TAR,$(BSD_PROGRESS_COMMIT).tar.gz,bsd-progress-$(BSD_PROGRESS_COMMIT),bsd-progress)
	# Preserve the original per-file BSD copyright and license notices.
	cd $(BUILD_WORK)/bsd-progress && for file in progress.c progressbar.c strsuftoll.c include/progressbar.h include/tzfile.h; do \
		printf '\n%s\n' "$$file"; sed -n '/^\/\*[- ]*$$/,/^ \*\//p' "$$file"; \
	done > COPYING

ifneq ($(wildcard $(BUILD_WORK)/bsd-progress/.build_complete),)
bsd-progress:
	@echo "Using previously built bsd-progress."
else
bsd-progress: bsd-progress-setup ncurses
	+$(MAKE) -C $(BUILD_WORK)/bsd-progress install \
		UNAME="Darwin" \
		PROG_PREFIX="bsd-" \
		PREFIX="$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)" \
		DESTDIR="$(BUILD_STAGE)/bsd-progress"
	$(call AFTER_BUILD)
endif

bsd-progress-package: bsd-progress-stage
	# bsd-progress.mk Package Structure
	rm -rf $(BUILD_DIST)/bsd-progress

	# bsd-progress.mk Prep bsd-progress
	cp -a $(BUILD_STAGE)/bsd-progress $(BUILD_DIST)

	# bsd-progress.mk Sign
	$(call SIGN,bsd-progress,general.xml)

	# bsd-progress.mk Make .debs
	$(call PACK,bsd-progress,DEB_BSD_PROGRESS_V)

	# bsd-progress.mk Build cleanup
	rm -rf $(BUILD_DIST)/bsd-progress

.PHONY: bsd-progress bsd-progress-package
