ifneq ($(PROCURSUS),1)
$(error Use the main Makefile)
endif

SUBPROJECTS   += xmlto
XMLTO_VERSION := 0.0.28
DEB_XMLTO_V   ?= $(XMLTO_VERSION)-1
GETOPT_FOR_BUILD ?= getopt

xmlto-setup: setup
	$(call DOWNLOAD_FILE,$(BUILD_SOURCE)/xmlto-$(XMLTO_VERSION).tar.bz2,https://deb.debian.org/debian/pool/main/x/xmlto/xmlto_$(XMLTO_VERSION).orig.tar.bz2)
	$(call EXTRACT_TAR,xmlto-$(XMLTO_VERSION).tar.bz2,xmlto-$(XMLTO_VERSION),xmlto)
	$(call DO_PATCH,xmlto,xmlto,-p1)

ifneq ($(wildcard $(BUILD_WORK)/xmlto/.build_complete),)
xmlto:
	@echo "Using previously built xmlto."
else
xmlto: xmlto-setup gnu-getopt
	cd $(BUILD_WORK)/xmlto && ./configure -C \
		$(DEFAULT_CONFIGURE_FLAGS) \
		GETOPT="$(GETOPT_FOR_BUILD)"
	+$(MAKE) -C $(BUILD_WORK)/xmlto
	+$(MAKE) -C $(BUILD_WORK)/xmlto install \
		DESTDIR=$(BUILD_STAGE)/xmlto
	$(call AFTER_BUILD)
endif

xmlto-package: xmlto-stage
	# xmlto.mk Package Structure
	rm -rf $(BUILD_DIST)/xmlto

	# xmlto.mk Prep xmlto
	cp -a $(BUILD_STAGE)/xmlto $(BUILD_DIST)
	# Configure probes use host tools; the installed script resolves target tools via PATH.
	for tool in FIND=find MKTEMP=mktemp BASH=bash GETOPT=ggetopt TAIL=tail GREP=grep SED=sed \
		PAPERCONF_PATH=paperconf LOCALE_PATH=locale XMLLINT_PATH=xmllint XSLTPROC_PATH=xsltproc \
		FOP_PATH=fop DBLATEX_PATH=dblatex XMLTEX_PATH=xmltex PDFXMLTEX_PATH=pdfxmltex \
		LINKS_PATH=elinks LYNX_PATH=lynx GCP_PATH=cp SED_PATH=sed GREP_PATH=grep ZIP_PATH=zip; do \
		sed -i "s|^$${tool%%=*}=.*|$$tool|" $(BUILD_DIST)/xmlto/$(MEMO_PREFIX)$(MEMO_SUB_PREFIX)/bin/xmlto; \
	done

	# xmlto.mk Sign
	$(call SIGN,xmlto,general.xml)

	# xmlto.mk Make .debs
	$(call PACK,xmlto,DEB_XMLTO_V)

	# xmlto.mk Build cleanup
	rm -rf $(BUILD_DIST)/xmlto

.PHONY: xmlto xmlto-package
