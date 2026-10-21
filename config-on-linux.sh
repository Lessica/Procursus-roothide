#!/usr/bin/env bash
# Prepare a self-contained Linux host toolchain inside this checkout.
set -euo pipefail
umask 022
PROJDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
HOST_TOOL_ROOT=${HOST_TOOL_ROOT:-"$PROJDIR/build_work/host-tools"}
case ${1:-} in
 --help) printf '%s\n' 'Usage: bash config-on-linux.sh [--skip-system-deps|--deps-only]' 'Ubuntu 24.04 / Debian-compatible Linux. Installs native apt dependencies, downloads' 'pinned toolchain/SDK inputs, builds patched host tools and writes host-env.sh.' 'HOST_TOOL_ROOT must be inside the checkout; HOME is preserved.' 'Set TARGET_SYSROOT and MACOSX_SYSROOT to use explicitly supplied SDKs.' 'Docker containers must use --init to reap fakeroot helper processes.'; exit 0;;
 ''|--skip-system-deps|--deps-only) ;;
 *) echo 'Unknown option; use --help' >&2;exit 2;;
esac
[[ $(uname -s) == Linux ]] || { echo 'Use build_tools/prepare-host-tools.sh on macOS or iOS.' >&2;exit 1; }
HOST_TOOL_ROOT=$(realpath -m -- "$HOST_TOOL_ROOT")
[[ $HOST_TOOL_ROOT != "$PROJDIR" ]] || { echo "HOST_TOOL_ROOT must be below checkout" >&2; exit 1; }
case "$HOST_TOOL_ROOT/" in "$PROJDIR/"*) ;; *) echo 'HOST_TOOL_ROOT must be inside the checkout' >&2;exit 1;; esac
mkdir -p "$HOST_TOOL_ROOT"
if [[ ${1:-} != --skip-system-deps ]]; then
 SUDO=(); [[ $(id -u) == 0 ]] || SUDO=(sudo)
 "${SUDO[@]}" apt-get update
 "${SUDO[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  ca-certificates build-essential clang clang-18 llvm llvm-18-dev lld make coreutils findutils sed gawk tar patch bash \
  openssl gnupg libtool libtool-bin automake autoconf bison flex groff fakeroot dpkg-dev zstd \
  xz-utils lzip libncurses-dev wget cmake docbook-xsl docbook-xml libxml2-utils itstool xsltproc python3 python3-dev python3-venv git pkg-config \
  autopoint po4a zip unzip triehash ninja-build curl libssl-dev libplist-dev libplist++-dev \
  libbz2-dev liblzma-dev libffi-dev zlib1g-dev libbsd-dev file gettext gperf texinfo help2man rsync tcl ghc protobuf-compiler neovim luajit lua-lpeg lua-mpack bsdextrautils nodejs libmodule-build-perl ruby asciidoctor asciidoc-base xmlto intltool gtk-doc-tools libedit-dev libicu-dev libxml2-dev libsqlite3-dev libcurl4-openssl-dev uuid-dev
fi
[[ ${1:-} != --deps-only ]] || exit 0
mkdir -p "$HOST_TOOL_ROOT"/{downloads,toolchain,SDK,bin}
fetch() {
 local url=$1 dst=$2
 if [[ ! -s $dst ]]; then
  curl --fail --location --retry 3 --connect-timeout 30 --output "$dst.part" "$url"
  mv "$dst.part" "$dst"
 fi
}
case $(uname -m) in aarch64|arm64) arch=aarch64;; x86_64) arch=x86_64;; *) echo 'Unsupported Linux architecture' >&2;exit 1;; esac
# The release used by the upstream Theos installer, pinned instead of /latest.
release=test-210562a
archive="$HOST_TOOL_ROOT/downloads/iOSToolchain-$arch.tar.xz"
fetch "https://github.com/L1ghtmann/llvm-project/releases/download/$release/iOSToolchain-$arch.tar.xz" "$archive"
if [[ $arch == aarch64 ]]; then
 echo "9051e9d531de5e511f0fab40d925d625bc6efe7ed9dce821d179c09de9bc690b  $archive" | sha256sum -c -
fi
tar -xf "$archive" -C "$HOST_TOOL_ROOT/toolchain"
toolbin="$HOST_TOOL_ROOT/toolchain/linux/iphone/bin"
# The upstream archiver invokes this configured ranlib name internally.
ln -sf ranlib "$toolbin/aarch64-apple-darwin14-ranlib"
# Use the distribution's Clang 18 with the pinned Darwin binutils. The
# bundled clang11 cannot parse all modern SDK headers. No host/iOS library mix.
for name in ld strings strip install_name_tool nm lipo otool libtool; do
 test -x "$toolbin/$name"
 ln -sf "$toolbin/$name" "$HOST_TOOL_ROOT/bin/aarch64-apple-darwin-$name"
done
# LLVM bitcode archives need an index produced by the matching LLVM version.
rm -f "$HOST_TOOL_ROOT/bin/aarch64-apple-darwin-ar"
printf '#!/usr/bin/env bash\nexec %q --format=darwin "$@"\n' "$(command -v llvm-ar-18)" > "$HOST_TOOL_ROOT/bin/aarch64-apple-darwin-ar"
chmod +x "$HOST_TOOL_ROOT/bin/aarch64-apple-darwin-ar"
ln -sfn "$(command -v llvm-ranlib-18)" "$HOST_TOOL_ROOT/bin/aarch64-apple-darwin-ranlib"
resource_dir="$HOST_TOOL_ROOT/clang-resource"
mkdir -p "$resource_dir"
ln -sfn "$(clang-18 -print-resource-dir)/include" "$resource_dir/include"
for name in clang clang++; do
 compiler=$(command -v "$name-18")
 # C compilations reject the unused C++ library option when using -Werror.
 stdlib_flag=
 [[ $name != clang++ ]] || stdlib_flag=-stdlib=libc++
 printf '#!/usr/bin/env bash\nexec %q --target=aarch64-apple-darwin -B%q -resource-dir=%q %s "$@"\n' "$compiler" "$toolbin" "$resource_dir" "$stdlib_flag" > "$HOST_TOOL_ROOT/bin/aarch64-apple-darwin-$name"
 chmod +x "$HOST_TOOL_ROOT/bin/aarch64-apple-darwin-$name"
done
for name in tapi vtool; do
 test -x "$toolbin/$name"
 ln -sf "$toolbin/$name" "$HOST_TOOL_ROOT/bin/$name"
done
if [[ -z ${TARGET_SYSROOT:-} ]]; then
 archive="$HOST_TOOL_ROOT/downloads/iPhoneOS16.5.sdk.tar.xz"
 fetch 'https://github.com/theos/sdks/releases/download/master-146e41f/iPhoneOS16.5.sdk.tar.xz' "$archive"
 [[ -d "$HOST_TOOL_ROOT/SDK/iPhoneOS16.5.sdk" ]] || tar -xf "$archive" -C "$HOST_TOOL_ROOT/SDK"
 TARGET_SYSROOT="$HOST_TOOL_ROOT/SDK/iPhoneOS16.5.sdk"
fi
if [[ -z ${MACOSX_SYSROOT:-} ]]; then
 archive="$HOST_TOOL_ROOT/downloads/MacOSX11.3.sdk.tar.xz"
 fetch 'https://github.com/phracker/MacOSX-SDKs/releases/download/11.3/MacOSX11.3.sdk.tar.xz' "$archive"
 [[ -d "$HOST_TOOL_ROOT/SDK/MacOSX11.3.sdk" ]] || tar -xf "$archive" -C "$HOST_TOOL_ROOT/SDK"
 MACOSX_SYSROOT="$HOST_TOOL_ROOT/SDK/MacOSX11.3.sdk"
fi
test -f "$TARGET_SYSROOT/usr/include/stdio.h"
test -d "$MACOSX_SYSROOT/System/Library/Frameworks/CoreServices.framework"
# Older Rust cc/gcc build helpers query SDKs through xcrun even with explicit CC.
{
 printf '#!/usr/bin/env bash\nset -euo pipefail\niphoneos_sdk=%q\nmacosx_sdk=%q\n' "$TARGET_SYSROOT" "$MACOSX_SYSROOT"
 cat <<'EOF'
sdk= operation=
while (( $# )); do
 case $1 in
  --sdk|-sdk) [[ $# -ge 2 ]] || exit 2; sdk=$2; shift 2 ;;
  --show-sdk-path|-show-sdk-path) operation=path; shift ;;
  *) echo "Unsupported Linux xcrun argument: $1" >&2; exit 2 ;;
 esac
done
[[ $operation == path ]] || { echo 'Linux xcrun supports explicit SDK path queries only' >&2; exit 2; }
case $sdk in
 iphoneos) printf '%s\n' "$iphoneos_sdk" ;;
 macosx) printf '%s\n' "$macosx_sdk" ;;
 *) echo "Unsupported Linux xcrun SDK: $sdk" >&2; exit 2 ;;
esac
EOF
} > "$HOST_TOOL_ROOT/bin/xcrun"
chmod +x "$HOST_TOOL_ROOT/bin/xcrun"
# The distributed ld64-609 lacks LTO support. Build the same linker series
# against the host LLVM used by the cross compiler, retaining bundled TAPI.
ld64_commit=df82634ce7c3eddba9722e881433fbe357396e16
archive="$HOST_TOOL_ROOT/downloads/cctools-ld64-$ld64_commit.tar.gz"
fetch "https://github.com/tpoechtrager/cctools-port/archive/$ld64_commit.tar.gz" "$archive"
echo "f137bf519be7f08303923b28bdc0fdfd87ca0533e15ad9050eedda2f6d59b420  $archive" | sha256sum -c -
ld64_src="$HOST_TOOL_ROOT/src/cctools-port-$ld64_commit"
mkdir -p "$HOST_TOOL_ROOT/src"
[[ -d $ld64_src ]] || tar -xf "$archive" -C "$HOST_TOOL_ROOT/src"
timestamp_patch="$PROJDIR/build_patch/host-cctools/archive-timestamps.patch"
if patch -d "$ld64_src" -p1 --forward --dry-run < "$timestamp_patch" >/dev/null 2>&1; then
 patch -d "$ld64_src" -p1 < "$timestamp_patch"
else
 patch -d "$ld64_src" -p1 --reverse --dry-run < "$timestamp_patch" >/dev/null
fi
(
 unset CC CXX CPP CFLAGS CXXFLAGS CPPFLAGS LDFLAGS LD AR RANLIB NM SDKROOT MACOSX_DEPLOYMENT_TARGET
 cd "$ld64_src/cctools"
 ./autogen.sh
 CC=clang-18 CXX=clang++-18 ./configure --target=aarch64-apple-darwin \
  --prefix="$HOST_TOOL_ROOT/ld64-lto" --with-libtapi="$HOST_TOOL_ROOT/toolchain/linux/iphone" \
  --with-llvm-config="$(command -v llvm-config-18)"
 make -C ld64 -j"${HOST_JOBS:-4}"
 make -C libmacho -j"${HOST_JOBS:-4}"
 make -C libstuff -j"${HOST_JOBS:-4}"
 make -C misc -j"${HOST_JOBS:-4}" strip
)
install -m755 "$ld64_src/cctools/ld64/src/ld/ld" "$toolbin/ld"
install -m755 "$ld64_src/cctools/misc/strip" "$toolbin/strip"
# Bundled strip invokes its configured target-prefixed linker for Mach-O objects.
ln -sfn ld "$toolbin/aarch64-apple-darwin14-ld"
ln -sfn ld "$toolbin/aarch64-apple-darwin-ld"
# Build the matching compiler-rt builtins with upstream's Darwin source selection,
# including os_version_check. This is the iOS arm64 cross-link runtime, not a
# target LLVM/Swift package build or an arm64e ABI substitute.
runtime_version=18.1.3
runtime_src="$HOST_TOOL_ROOT/src/llvm-runtime-$runtime_version"
mkdir -p "$runtime_src"
for project in compiler-rt cmake; do
 archive="$HOST_TOOL_ROOT/downloads/$project-$runtime_version.src.tar.xz"
 fetch "https://github.com/llvm/llvm-project/releases/download/llvmorg-$runtime_version/$project-$runtime_version.src.tar.xz" "$archive"
 case $project in
  compiler-rt) checksum=9a7df9300413696b0c4f7ff1e2729cb82aca375f35c05d698c44f26a4edf1c27 ;;
  cmake) checksum=acfecb615d41c5b1a0a31e15324994ca06f7a3f37d8958d719b20de0d217b71b ;;
 esac
 echo "$checksum  $archive" | sha256sum -c -
 mkdir -p "$runtime_src/$project"
 tar -xf "$archive" --strip-components=1 -C "$runtime_src/$project"
done
macos_sdk_version=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["Version"])' "$MACOSX_SYSROOT/SDKSettings.json")
cmake -S "$runtime_src/compiler-rt/lib/builtins" -B "$runtime_src/build" -G Ninja \
 -DLLVM_DIR="$(llvm-config-18 --cmakedir)" \
 -DCMAKE_SYSTEM_NAME=Darwin -DCMAKE_BUILD_TYPE=Release \
 -DCMAKE_C_COMPILER="$(command -v clang-18)" -DCMAKE_ASM_COMPILER="$(command -v clang-18)" \
 -DCMAKE_C_COMPILER_TARGET=arm64-apple-darwin -DCMAKE_ASM_COMPILER_TARGET=arm64-apple-darwin \
 -DCMAKE_OSX_SYSROOT="$TARGET_SYSROOT" -DCMAKE_OSX_ARCHITECTURES=arm64 \
 -DCMAKE_LINKER="$toolbin/ld" -DCMAKE_LIBTOOL="$toolbin/libtool" -DCMAKE_LIPO="$toolbin/lipo" \
 -DCOMPILER_RT_ENABLE_IOS=ON -DCOMPILER_RT_ENABLE_TVOS=OFF -DCOMPILER_RT_ENABLE_WATCHOS=OFF \
 -DDARWIN_iphoneos_CACHED_SYSROOT="$TARGET_SYSROOT" -DDARWIN_macosx_CACHED_SYSROOT="$MACOSX_SYSROOT" \
 -DDARWIN_macosx_OVERRIDE_SDK_VERSION="$macos_sdk_version" \
 -DDARWIN_iphonesimulator_OVERRIDE_SDK_VERSION=0.0 \
 -DDARWIN_ios_BUILTIN_ARCHS=arm64 -DDARWIN_osx_BUILTIN_ARCHS=arm64 \
 -DDARWIN_ios_SKIP_CC_KEXT=ON -DCOMPILER_RT_INCLUDE_TESTS=OFF \
 -DCMAKE_INSTALL_PREFIX="$resource_dir"
# Only the device iOS library is needed; no simulator, macOS, or sanitizer build.
cmake --build "$runtime_src/build" --target clang_rt.ios -j"${HOST_JOBS:-4}"
cmake --install "$runtime_src/build" --component clang_rt.ios
test -s "$resource_dir/lib/darwin/libclang_rt.ios.a"
# Fail during preparation, rather than much later in a package link.
printf '%s\n' 'int main(void) { return __builtin_available(iOS 18.0, *) ? 0 : 1; }' > "$runtime_src/build/availability.c"
"$HOST_TOOL_ROOT/bin/aarch64-apple-darwin-clang" --target=arm64-apple-ios16.0 \
 -isysroot "$TARGET_SYSROOT" "$runtime_src/build/availability.c" -o "$runtime_src/build/availability"
# Exercise both LTO modes through the same driver used by target recipes.
printf '%s\n' 'int procursus_lto_probe(void) { return 0; }' > "$runtime_src/build/archive-probe.c"
printf '%s\n' 'int procursus_lto_probe(void); int main(void) { return procursus_lto_probe(); }' > "$runtime_src/build/archive-main.c"
"$HOST_TOOL_ROOT/bin/aarch64-apple-darwin-clang" --target=arm64-apple-ios16.0 \
 -isysroot "$TARGET_SYSROOT" -c "$runtime_src/build/archive-probe.c" \
 -o "$runtime_src/build/strip-probe.o"
"$HOST_TOOL_ROOT/bin/aarch64-apple-darwin-strip" -x "$runtime_src/build/strip-probe.o"
for lto_mode in full thin; do
 "$HOST_TOOL_ROOT/bin/aarch64-apple-darwin-clang" --target=arm64-apple-ios16.0 \
  -isysroot "$TARGET_SYSROOT" -flto="$lto_mode" "$runtime_src/build/availability.c" \
  -o "$runtime_src/build/availability-$lto_mode"
 "$HOST_TOOL_ROOT/bin/aarch64-apple-darwin-clang" --target=arm64-apple-ios16.0 \
  -isysroot "$TARGET_SYSROOT" -flto="$lto_mode" -c "$runtime_src/build/archive-probe.c" \
  -o "$runtime_src/build/archive-$lto_mode.o"
 "$HOST_TOOL_ROOT/bin/aarch64-apple-darwin-ar" rcs "$runtime_src/build/archive-$lto_mode.a" "$runtime_src/build/archive-$lto_mode.o"
 "$HOST_TOOL_ROOT/bin/aarch64-apple-darwin-ranlib" "$runtime_src/build/archive-$lto_mode.a"
 "$HOST_TOOL_ROOT/bin/aarch64-apple-darwin-clang" --target=arm64-apple-ios16.0 \
  -isysroot "$TARGET_SYSROOT" -flto="$lto_mode" "$runtime_src/build/archive-main.c" \
  "$runtime_src/build/archive-$lto_mode.a" -o "$runtime_src/build/archive-$lto_mode"
done
export HOST_TOOL_ROOT
export HOST_CC=${HOST_CC:-clang}
export HOST_CXX=${HOST_CXX:-clang++}
bash "$PROJDIR/build_tools/prepare-host-tools.sh"
# Apple's Mach interface generator is required by the main setup target.
mig_commit=f337e600741638896fb6056ce87c6479f74b89a3
archive="$HOST_TOOL_ROOT/downloads/bootstrap_cmds-$mig_commit.tar.gz"
fetch "https://github.com/markmentovai/bootstrap_cmds/archive/$mig_commit.tar.gz" "$archive"
mig_src="$HOST_TOOL_ROOT/src/bootstrap_cmds-$mig_commit"
[[ -d $mig_src ]] || tar -xf "$archive" -C "$HOST_TOOL_ROOT/src"
(
 cd "$mig_src"
 autoreconf -fi
 CC="$HOST_CC" ./configure --prefix="$HOST_TOOL_ROOT"
 make -j"${HOST_JOBS:-4}"
 make install
)
# Supplement the shared host-tool environment with cross compiler and SDK paths.
{
 printf '\nexport TARGET_SYSROOT=%q\nexport MACOSX_SYSROOT=%q\n' "$TARGET_SYSROOT" "$MACOSX_SYSROOT"
} >> "$HOST_TOOL_ROOT/host-env.sh"
sha256sum "$HOST_TOOL_ROOT"/downloads/* > "$HOST_TOOL_ROOT/downloads.sha256"
printf 'Ready. Run: source %q\n' "$HOST_TOOL_ROOT/host-env.sh"
