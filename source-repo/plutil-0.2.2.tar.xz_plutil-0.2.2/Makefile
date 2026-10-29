CC      ?= xcrun -sdk iphoneos clang
CFLAGS  ?= -arch arm64 -arch armv6 -miphoneos-version-min=6.0
DESTDIR ?= .
LDID    ?= ldid

plutil:
	$(CC) $(CFLAGS) -o plutil json-framework/Classes/*.m plutil.m iphone-3.0-cookbook-/C16-Push/02-PushUtil/JSONHelper.m -Iiphone-3.0-cookbook-/C16-Push/02-PushUtil -Ijson-framework/Classes -framework Foundation
	$(LDID) -Sent.xml plutil

install: plutil
	mkdir -p $(DESTDIR)/bin
	cp -a plutil $(DESTDIR)/bin
	chmod 0755 $(DESTDIR)/bin/plutil

clean:
	rm -f plutil
