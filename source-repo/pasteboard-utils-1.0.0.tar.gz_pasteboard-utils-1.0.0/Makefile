.PHONY: clean all pbupload pbcopy pbpaste

CC     := xcrun --sdk iphoneos clang
CFLAGS := -O2 -arch arm64 -fobjc-arc -miphoneos-version-min=10.0
LIBS   := -framework Foundation -framework UIKit
SIGN   := ldid -Sent.plist

clean:
	rm -rf bin/

all: pbupload pbcopy pbpaste

pbupload:
	$(CC) $(CFLAGS) pbupload/pbupload.m -o bin/pbupload $(LIBS)
	$(SIGN) bin/pbupload

pbcopy:
	$(CC) $(CFLAGS) pbcopy/pbcopy.m -o bin/pbcopy $(LIBS)
	$(SIGN) bin/pbcopy

pbpaste:
	$(CC) $(CFLAGS) pbpaste/pbpaste.m -o bin/pbpaste $(LIBS)
	$(SIGN) bin/pbpaste