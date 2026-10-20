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
  ca-certificates build-essential clang llvm lld make coreutils findutils sed tar patch bash \
  openssl gnupg libtool libtool-bin automake autoconf bison flex groff fakeroot dpkg-dev zstd \
  xz-utils libncurses-dev wget cmake docbook-xsl python3 python3-dev python3-venv git pkg-config \
  autopoint po4a unzip triehash ninja-build curl libssl-dev libplist-dev libplist++-dev \
  libbsd-dev file gettext gperf texinfo help2man rsync
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
# Use the distribution's current clang with the pinned Darwin binutils. The
# bundled clang11 cannot parse all modern SDK headers. No host/iOS library mix.
for name in ar ld ranlib strings strip install_name_tool nm lipo otool libtool; do
 test -x "$toolbin/$name"
 ln -sf "$toolbin/$name" "$HOST_TOOL_ROOT/bin/aarch64-apple-darwin-$name"
done
for name in clang clang++; do
 compiler=$(command -v "$name")
 # C compilations reject the unused C++ library option when using -Werror.
 stdlib_flag=
 [[ $name != clang++ ]] || stdlib_flag=-stdlib=libc++
 printf '#!/usr/bin/env bash\nexec %q --target=aarch64-apple-darwin -B%q %s "$@"\n' "$compiler" "$toolbin" "$stdlib_flag" > "$HOST_TOOL_ROOT/bin/aarch64-apple-darwin-$name"
 chmod +x "$HOST_TOOL_ROOT/bin/aarch64-apple-darwin-$name"
done
ln -sf "$toolbin/tapi" "$HOST_TOOL_ROOT/bin/tapi"
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
