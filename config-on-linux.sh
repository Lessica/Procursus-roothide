#Build Procursus-roothide on Debian/Ubuntu

set -e
set -x

IOS_SDK_VERSION=16.5 #from https://github.com/theos/sdks/releases/tag/master-146e41f
MACOSX_SDK_VERSION=11.3 #from https://github.com/phracker/MacOSX-SDKs/releases/tag/11.3

# Resolve the checkout before changing to the login home directory.
PROJDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

if [ -e "$HOME/ldid" ] || [ -L "$HOME/ldid" ]; then
    echo "*** host ldid path already exists at $HOME/ldid; move it aside before preparing the pinned, patched host ldid"
    exit 1
fi

cd ~

if ! eval $(echo "echo $PATH") || echo "$PATH" | grep -qE '[[:space:]]|[^[:print:]]' ; then
    echo "*** your PATH contains special characters, please start a new shell with a clean PATH to build Procursus-roothide"
    echo "$PATH"
    exit
fi

TEST_INODE_1=$(touch "$PROJDIR/.inode_test_file_1"; stat -c %i "$PROJDIR/.inode_test_file_1"; rm -f "$PROJDIR/.inode_test_file_1")
TEST_INODE_2=$(touch "$PROJDIR/.inode_test_file_2"; stat -c %i "$PROJDIR/.inode_test_file_2"; rm -f "$PROJDIR/.inode_test_file_2")
if [ "$TEST_INODE_1" = "$TEST_INODE_2" ]; then
	echo "*** The file system where the build directory is located reuses inodes, fakeroot will not work correctly. You can move the build directory to a different type of file system for building."
	exit
fi

if [ -d ~/cctools ]; then
    echo "*** cctools already exists in $(realpath ~/cctools), please remove it before running this script"
    exit
fi

if which aarch64-apple-darwin-clang; then
    echo "*** an exists toolchain is already in your PATH, please remove it from PATH before running this script"
    exit
fi

echo "Installing dependencies"

# sudo apt update || true

sudo apt install -y build-essential clang llvm make coreutils findutils sed tar patch bash openssl gnupg libtool automake bison flex groff fakeroot dpkg zstd libncurses6 wget cmake docbook-xsl python3 git pkg-config autopoint po4a unzip triehash meson ninja-build curl

echo "Installing toolchain and SDKs with iOS($IOS_SDK_VERSION) and MacOSX($MACOSX_SDK_VERSION)"


echo "Installing toolchain for Procursus from theos"

if [ ! -d ~/theos ]; then
    echo 'theos not installed, try: bash -c "$(curl -fsSL https://raw.githubusercontent.com/roothide/theos/master/bin/install-theos)"'
    exit
fi

if [ ! -d ~/theos/toolchain/linux/iphone ]; then
    echo "toolchain not found, try reinstalling latest theos"
    exit
fi

mkdir -p ~/cctools/theos-bin
for file in ~/theos/toolchain/linux/iphone/bin/*; do
    ln -sf $file ~/cctools/theos-bin/aarch64-apple-darwin-$(basename $file)
done
# `ar` in the (theos)lightman's toolchain might call aarch64-apple-darwin14-ranlib instead of aarch64-apple-darwin-ranlib
if [ ! -e ~/theos/linux/iphone/bin/aarch64-apple-darwin14-ranlib ]; then
    ln -sf ranlib  ~/theos/toolchain/linux/iphone/bin/aarch64-apple-darwin14-ranlib
fi
# fix: lightman's clang(++) cannot be called through symbolic links when building for ios on Ubuntu
rm -f ~/cctools/theos-bin/aarch64-apple-darwin-clang ~/cctools/theos-bin/aarch64-apple-darwin-clang++
echo '#!/bin/bash
~/theos/toolchain/linux/iphone/bin/clang $([ "$CLANG_VERBOSE_ENABLE" = "1" ] && echo "-v") --target=aarch64-apple-darwin "$@"
exit $?' > ~/cctools/theos-bin/aarch64-apple-darwin-clang
chmod +x ~/cctools/theos-bin/aarch64-apple-darwin-clang

rm -f ~/cctools/theos-bin/aarch64-apple-darwin-clang++
echo '#!/bin/bash
~/theos/toolchain/linux/iphone/bin/clang++ $([ "$CLANG_VERBOSE_ENABLE" = "1" ] && echo "-v") --target=aarch64-apple-darwin "$@"
exit $?' > ~/cctools/theos-bin/aarch64-apple-darwin-clang++
chmod +x ~/cctools/theos-bin/aarch64-apple-darwin-clang++


echo "Downloading iPhoneOS $IOS_SDK_VERSION SDK"
rm -f iPhoneOS$IOS_SDK_VERSION.sdk.tar.xz #the previously downloaded file may be corrupted.
wget https://github.com/theos/sdks/releases/download/master-146e41f/iPhoneOS$IOS_SDK_VERSION.sdk.tar.xz
DOWNLOADED_SDK_FILE_PATH=$(realpath ./iPhoneOS$IOS_SDK_VERSION.sdk.tar.xz)

# since cctools uses the host's llvm/clang but its own ld, they may be incompatible and the build may fail
# and, tapi may not be able to generate tbd file for macho built by cctools
echo "Installing cctools toolchain"

if [ ! -f ./cctools-port/.build_complete ]; then
    rm -rf ./cctools-port
    sudo apt install -y libssl-dev
    git clone --recursive https://github.com/tpoechtrager/cctools-port
fi

sed -i 's/HAVE_UTIMESAT/HAVE_UTIMENSAT/g' cctools-port/cctools/libstuff/writeout.c

pushd cctools-port/usage_examples/ios_toolchain

if [ ! -f ~/cctools-port/.build_complete ] || [ ! -d ./target/SDK/iPhoneOS$IOS_SDK_VERSION.sdk ]; then
sed -i 's/arm-apple-darwin11/aarch64-apple-darwin/g' build.sh
./build.sh $DOWNLOADED_SDK_FILE_PATH arm64
touch ~/cctools-port/.build_complete
fi

# remove the outdated ldid, we will install procursus ldid later
rm -f ./target/bin/ldid

mkdir -p ~/cctools/SDK
ln -sf $(realpath ./target/SDK/iPhoneOS$IOS_SDK_VERSION.sdk) ~/cctools/SDK/iPhoneOS.sdk

mkdir -p ~/cctools/bin
for file in ./target/bin/*; do
    ln -sf $(realpath $file) ~/cctools/bin/$(basename $file)
done

# if the sdk's c++ header is not compatible with the old llvm/clang, we need to use theos' c++ header to build for ios
if ! echo -e "#include <string>\n#include <iostream>\nint main(){std::cout << std::string(\"test\");return 0;}" | ./target/bin/aarch64-apple-darwin-clang++ -x c++ -c -stdlib=libc++ -isysroot ~/cctools/SDK/iPhoneOS.sdk -v - ; then
    echo "*** warning: the host's llvm/clang++ may not be compatible with the current iPhoneOS$IOS_SDK_VERSION.sdk, you can upgrade your llvm/clang or use an older version of iPhoneOS.sdk"
    exit
    # sudo apt install -y libc++-dev
    # rm -rf ~/cctools/SDK/iPhoneOS.sdk/usr/include/c++
    # LIBCXX_INCLUDE_PATH=$(dpkg -S include/c++/v1/ | grep libc++ | awk -F ': ' '{print $2}' | xargs -n 1 dirname | sort -u | head -n 1)
    # if [ ! -d $LIBCXX_INCLUDE_PATH ]; then
    #     echo "libc++ header path not found!"
    #     exit
    # fi
    # EXTRA_CXX_FLAGS="-isystem $LIBCXX_INCLUDE_PATH"
fi

# fix: some hosts' llvm/clang++ would not auto use libc++ for aarch64-apple-darwin
rm -f ~/cctools/bin/aarch64-apple-darwin-clang ~/cctools/bin/aarch64-apple-darwin-clang++

echo -e "#!/bin/bash\n\
$(realpath ./target/bin)/aarch64-apple-darwin-clang \
\$([ \"\$CLANG_VERBOSE_ENABLE\" = \"1\" ] && echo '-v') \
$EXTRA_CXX_FLAGS \
-stdlib=libc++ \"\$@\"\n\
exit \$?" > ~/cctools/bin/aarch64-apple-darwin-clang
chmod +x ~/cctools/bin/aarch64-apple-darwin-clang

echo -e "#!/bin/bash\n\
$(realpath ./target/bin)/aarch64-apple-darwin-clang++ \
\$([ \"\$CLANG_VERBOSE_ENABLE\" = \"1\" ] && echo '-v') \
$EXTRA_CXX_FLAGS \
-stdlib=libc++ -lc++ \"\$@\"\n\
exit \$?" > ~/cctools/bin/aarch64-apple-darwin-clang++
chmod +x ~/cctools/bin/aarch64-apple-darwin-clang++

popd

if [ ! -f ./apple-libtapi/.build_complete ]; then
    sudo apt install -y lld
    rm -rf apple-libtapi
    git clone https://github.com/tpoechtrager/apple-libtapi.git
    cd apple-libtapi
    INSTALLPREFIX=/usr/local ./build_tapi_tools.sh
    sudo ./install.sh
    cd -
    touch ./apple-libtapi/.build_complete
fi


echo "Installing MacOSX SDK"
rm -f MacOSX$MACOSX_SDK_VERSION.sdk.tar.xz #the previously downloaded file may be corrupted.
wget https://github.com/phracker/MacOSX-SDKs/releases/download/$MACOSX_SDK_VERSION/MacOSX$MACOSX_SDK_VERSION.sdk.tar.xz
mkdir -p ~/cctools/SDK
tar -xf MacOSX$MACOSX_SDK_VERSION.sdk.tar.xz -C ~/cctools/SDK/
mv ~/cctools/SDK/MacOSX$MACOSX_SDK_VERSION.sdk ~/cctools/SDK/MacOSX.sdk

echo "Building patched Procursus ldid v2.1.5-procursus7"
sudo apt install -y libssl-dev libplist-dev libplist++-dev
git clone --depth 1 --branch v2.1.5-procursus7 https://github.com/ProcursusTeam/ldid.git ./ldid
for patch in bundle-code-signing-flags.patch entitlement-memory.patch preserve-linkedit-extent.patch; do
    patch -d ./ldid -p1 < "$PROJDIR/build_patch/ldid/$patch"
done
cd ldid
make -j$(nproc)
sudo make -j$(nproc) install
cd ..
touch ./ldid/.build_complete

echo '*** All done ***, now you can add

 ~/cctools/bin          (using host'\''s llvm/clang)

  or
 ~/cctools/theos-bin    (using theos'\''s llvm/clang)
 
 to PATH to build Procursus-roothide ...
'

# export PATH=~/cctools/bin:$PATH or export PATH=~/cctools/theos-bin:$PATH
# make rebuild-libiosexec-package MEMO_TARGET=iphoneos-arm64-roothide NO_PGP=1 MEMO_CFVER=1900
