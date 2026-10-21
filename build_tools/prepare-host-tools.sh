#!/usr/bin/env bash
# Build native tools only. Never change HOME or install target packages.
set -euo pipefail
umask 022

CHECKOUT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
HOST_TOOL_ROOT=${HOST_TOOL_ROOT:-"$CHECKOUT/build_work/host-tools"}
HOST_PLATFORM=${HOST_PLATFORM:-auto}
HOST_CC=${HOST_CC:-cc}
HOST_CXX=${HOST_CXX:-c++}
HOST_PYTHON=${HOST_PYTHON:-python3}
HOST_MAKE=${HOST_MAKE:-make}
HOST_PKG_CONFIG=${HOST_PKG_CONFIG:-pkg-config}
HOST_JOBS=${HOST_JOBS:-4}
LDID_COMMIT=aaf8f23d7975ecdb8e77e3a8f22253e0a2352cef
ROOTHIDE_COMMIT=7764c54759009272b4f2f23c18c62b21794fe6dd
CCTOOLS_COMMIT=904de2a71d4da6a9b30d2efaf912a10ddc7d9ddb
TRIEHASH_COMMIT=971282a3aaa3905e63ed1dd5401ea1094e7ea2c3

fail() { printf 'prepare-host-tools: %s\n' "$*" >&2; exit 1; }
usage() {
    cat <<'HELP'
Usage: build_tools/prepare-host-tools.sh [--print-system-deps|--install-system-deps]

Default: build pinned patched ldid, symredirect, and a Python venv containing
Cython 0.29.37 / Meson 0.64.0 in HOST_TOOL_ROOT (default build_work/host-tools).
Source the resulting host-env.sh before using the main Makefile.

HOST_PLATFORM=macos|linux|ios overrides automatic detection. System dependency
installation is opt-in, then preparation continues; --print-system-deps only prints.
macOS requires Homebrew and full Xcode with the iPhoneOS and macOS SDKs. iOS apt must be run on the iOS host,
never against a macOS/Linux root. No target packages are installed by default.

Overrides: HOST_CC, HOST_CXX, HOST_PYTHON, HOST_MAKE, HOST_PKG_CONFIG, HOST_JOBS,
HOST_SDKROOT (Darwin native SDK), HOST_CPPFLAGS, HOST_CXXFLAGS, HOST_LDFLAGS.
HOST_SIGN_LDID selects the pre-existing native signer needed for iOS bootstrap.
These host-only flags intentionally ignore ambient target compiler/linker flags.
PIP_INDEX_URL / PIP_EXTRA_INDEX_URL are honored, with pip caches kept locally.
HELP
}
case ${1:-} in --help|-h) usage; exit 0;; ''|--print-system-deps|--install-system-deps) ;; *) usage >&2; exit 2;; esac
[[ $# -le 1 ]] || fail 'at most one option is supported'
if [[ $HOST_PLATFORM == auto ]]; then
    case $(uname -s) in
        Linux) HOST_PLATFORM=linux ;;
        Darwin)
            case $(sw_vers -productName 2>/dev/null || true) in
                macOS|"Mac OS X") HOST_PLATFORM=macos ;;
                *) HOST_PLATFORM=ios ;;
            esac ;;
        *) fail 'unsupported host; select HOST_PLATFORM=macos, linux or ios' ;;
    esac
fi
case $HOST_PLATFORM in
    linux) deps=(apt-get install -y build-essential clang perl git curl ca-certificates patch pkg-config libssl-dev zlib1g-dev libbz2-dev liblzma-dev libffi-dev libplist-dev python3 python3-venv python3-dev ninja-build autoconf automake libtool bison flex cmake gettext gawk autopoint fakeroot dpkg-dev zstd gnupg groff docbook-xsl docbook-xml libxml2-utils itstool xsltproc po4a zip unzip xz-utils lzip tcl ghc protobuf-compiler neovim luajit lua-lpeg lua-mpack bsdextrautils nodejs libmodule-build-perl ruby asciidoctor gtk-doc-tools) ;;
    macos) deps=(brew install bash make gpatch file-formula ncurses gnu-sed gawk grep gnu-tar findutils coreutils bison flex autoconf automake libtool cmake gettext fakeroot dpkg zstd gnupg groff docbook-xsl po4a openssl@3 libplist pkg-config python@3.12 ninja) ;;
    ios) deps=(apt-get install -y clang make perl ncurses-bin git curl ca-certificates patch pkg-config openssl libssl-dev libplist-dev python3 libpython3.9-dev ninja bash coreutils findutils sed gawk grep tar bison flex autoconf automake libtool cmake gettext fakeroot dpkg zstd gnupg groff docbook-xsl po4a zip unzip xz-utils ldid) ;;
    *) fail 'HOST_PLATFORM must be macos, linux or ios' ;;
esac
if [[ ${1:-} == --print-system-deps ]]; then printf '%q ' "${deps[@]}"; printf '\n'; exit 0; fi
if [[ ${1:-} == --install-system-deps ]]; then
    if [[ $HOST_PLATFORM == macos ]]; then
        command -v brew >/dev/null || fail 'install Homebrew before --install-system-deps'
        command -v xcrun >/dev/null || fail 'install and select full Xcode before --install-system-deps'
        xcrun --sdk iphoneos --show-sdk-path >/dev/null || fail 'select full Xcode with DEVELOPER_DIR or xcode-select; its iPhoneOS SDK is required'
    fi
    if [[ $HOST_PLATFORM == macos || $(id -u) == 0 ]]; then "${deps[@]}"; else sudo "${deps[@]}"; fi
fi

for command_name in git patch perl "$HOST_CC" "$HOST_CXX" "$HOST_PYTHON" "$HOST_MAKE" "$HOST_PKG_CONFIG"; do
    command -v "$command_name" >/dev/null 2>&1 || fail "missing $command_name; see --print-system-deps"
done
[[ $HOST_JOBS =~ ^[1-9][0-9]*$ ]] || fail 'HOST_JOBS must be a positive integer'
# Resolve parent symlinks before writing: all generated material stays in checkout.
HOST_TOOL_ROOT=$("$HOST_PYTHON" - "$CHECKOUT" "$HOST_TOOL_ROOT" <<'PY'
import os, sys
checkout, root = map(os.path.realpath, sys.argv[1:])
if root == checkout or os.path.commonpath([checkout, root]) != checkout:
    sys.exit('HOST_TOOL_ROOT must be a directory beneath this checkout')
print(root)
PY
)
mkdir -p "$HOST_TOOL_ROOT"/{src,bin,cache,tmp,SDK}
for local_dir in src bin cache tmp SDK; do
    [[ ! -L $HOST_TOOL_ROOT/$local_dir ]] || fail "refusing symlink $HOST_TOOL_ROOT/$local_dir"
done
export TMPDIR="$HOST_TOOL_ROOT/tmp"
export PIP_CACHE_DIR="$HOST_TOOL_ROOT/cache/pip"
export PYTHONNOUSERSITE=1
# Do not allow a target toolchain's pkg-config sysroot into native dependencies.
unset PKG_CONFIG_SYSROOT_DIR PKG_CONFIG_LIBDIR PYTHONPATH PYTHONHOME CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH LIBRARY_PATH SDKROOT
if [[ $HOST_PLATFORM == macos ]]; then
    command -v xcrun >/dev/null || fail 'install and select full Xcode with iPhoneOS/macOS SDKs'
    HOST_SDKROOT=${HOST_SDKROOT:-$(xcrun --sdk macosx --show-sdk-path)}
    if [[ -z ${TARGET_SYSROOT:-} ]]; then
        TARGET_SYSROOT=$(xcrun --sdk iphoneos --show-sdk-path) || fail 'full Xcode iPhoneOS SDK missing; select Xcode with DEVELOPER_DIR or xcode-select'
    fi
    MACOSX_SYSROOT=${MACOSX_SYSROOT:-$HOST_SDKROOT}
    if command -v brew >/dev/null; then
        brew_prefix=$(brew --prefix)
        # Keg-only GNU tools must precede Apple's tools for the main Makefile.
        host_gnu_paths=()
        for formula_path in bash/bin make/libexec/gnubin gnu-sed/libexec/gnubin grep/libexec/gnubin gnu-tar/libexec/gnubin findutils/libexec/gnubin coreutils/libexec/gnubin bison/bin flex/bin gettext/bin gpatch/libexec/gnubin file-formula/bin ncurses/bin; do
            if [[ -d $brew_prefix/opt/$formula_path ]]; then
                host_gnu_paths+=("$brew_prefix/opt/$formula_path")
            fi
        done
        for ((path_index=${#host_gnu_paths[@]}-1; path_index>=0; path_index--)); do
            export PATH="${host_gnu_paths[path_index]}:$PATH"
        done
        DOCBOOK_XSL=${DOCBOOK_XSL:-$(brew --prefix docbook-xsl)/docbook-xsl}
        [[ -f $DOCBOOK_XSL/html/docbook.xsl ]] || fail 'DOCBOOK_XSL must point to the DocBook XSL stylesheet directory'
        file -bi /bin/sh | grep -q 'x-mach-binary; charset=binary' || fail 'file must identify Mach-O MIME types; install Homebrew file-formula and prepend its bin directory'
        patch --version | grep -q 'GNU patch' || fail 'GNU patch missing; install Homebrew gpatch and prepend its libexec/gnubin directory'
        tic -V 2>&1 | grep -q 'ncurses 6' || fail 'ncurses 6 tic missing; install Homebrew ncurses and prepend its bin directory'
        openssl_prefix=$(brew --prefix openssl@3)
        plist_prefix=$(brew --prefix libplist)
        export PKG_CONFIG_PATH="$openssl_prefix/lib/pkgconfig:$plist_prefix/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
    fi
fi
fetch_sdk() {
    local name=$1 url=$2 archive="$HOST_TOOL_ROOT/cache/$1.tar.xz"
    if [[ ! -d $HOST_TOOL_ROOT/SDK/$name ]]; then
        if [[ ! -f $archive ]]; then
            curl --fail --location --retry 3 "$url" -o "$archive.part"
            mv "$archive.part" "$archive"
        fi
        tar -xf "$archive" -C "$HOST_TOOL_ROOT/SDK"
    fi
    [[ -d $HOST_TOOL_ROOT/SDK/$name ]] || fail "SDK archive missing $name"
}
if [[ $HOST_PLATFORM == ios ]]; then
    command -v curl >/dev/null || fail 'curl is required to fetch native iOS SDKs'
    if [[ -z ${TARGET_SYSROOT:-} ]]; then
        fetch_sdk iPhoneOS16.5.sdk 'https://github.com/theos/sdks/releases/download/master-146e41f/iPhoneOS16.5.sdk.tar.xz'
        TARGET_SYSROOT="$HOST_TOOL_ROOT/SDK/iPhoneOS16.5.sdk"
    fi
    if [[ -z ${MACOSX_SYSROOT:-} ]]; then
        fetch_sdk MacOSX11.3.sdk 'https://github.com/phracker/MacOSX-SDKs/releases/download/11.3/MacOSX11.3.sdk.tar.xz'
        MACOSX_SYSROOT="$HOST_TOOL_ROOT/SDK/MacOSX11.3.sdk"
    fi
    [[ -f $TARGET_SYSROOT/usr/include/stdio.h ]] || fail 'TARGET_SYSROOT is missing iOS SDK headers'
    [[ -d $MACOSX_SYSROOT/System/Library/Frameworks/CoreServices.framework ]] || fail 'MACOSX_SYSROOT is missing macOS CoreServices.framework'
    HOST_SDKROOT=${HOST_SDKROOT:-$TARGET_SYSROOT}
fi
"$HOST_PKG_CONFIG" --exists libcrypto libplist-2.0 || fail 'native libcrypto/libplist-2.0 development files missing; see --print-system-deps'
# Flags are whitespace-separated shell words, not shell programs.
read -r -a host_cppflags <<< "${HOST_CPPFLAGS:-}"
read -r -a host_cxxflags <<< "${HOST_CXXFLAGS:--O2 -pipe}"
read -r -a host_ldflags <<< "${HOST_LDFLAGS:-}"
if [[ -n ${HOST_SDKROOT:-} ]]; then
    host_cppflags+=(-isysroot "$HOST_SDKROOT")
    host_ldflags+=(-isysroot "$HOST_SDKROOT")
fi

fetch_source() {
    local name=$1 url=$2 commit=$3 directory="$HOST_TOOL_ROOT/src/$1"
    if [[ -e $directory ]]; then
        [[ ! -L $directory && -d $directory/.git ]] || fail "refusing unmanaged source path $directory"
        [[ $(git -C "$directory" rev-parse HEAD) == "$commit" ]] || fail "wrong source revision in $directory"
    else
        git init -q "$directory"
        git -C "$directory" fetch --depth 1 "$url" "$commit"
        git -C "$directory" checkout -q --detach FETCH_HEAD
    fi
}
apply_patch() {
    local directory=$1 patchfile=$2
    if patch -d "$directory" -p1 --forward --dry-run < "$patchfile" >/dev/null 2>&1; then
        patch -d "$directory" -p1 --forward < "$patchfile"
    elif ! patch -d "$directory" -p1 --reverse --dry-run < "$patchfile" >/dev/null 2>&1; then
        fail "patch does not apply cleanly: $patchfile"
    fi
}
# Triehash v0.3 is a portable Perl script; Homebrew has no formula for it.
# Keep the pinned original plus a native-interpreter copy inside this checkout.
fetch_source triehash https://github.com/julian-klode/triehash.git "$TRIEHASH_COMMIT"
[[ ! -L $HOST_TOOL_ROOT/bin/triehash ]] || fail 'refusing existing symlink bin/triehash'
"$HOST_PYTHON" - "$HOST_TOOL_ROOT/src/triehash/triehash.pl" "$HOST_TOOL_ROOT/bin/triehash" "$(command -v perl)" <<'PYTHON'
import os, pathlib, sys
source, output, perl = sys.argv[1:]
lines = pathlib.Path(source).read_bytes().splitlines(keepends=True)
pathlib.Path(output).write_bytes(b'#!' + os.fsencode(perl) + b' -w\n' + b''.join(lines[1:]))
os.chmod(output, 0o755)
PYTHON
perl -c "$HOST_TOOL_ROOT/bin/triehash"
fetch_source ldid https://github.com/ProcursusTeam/ldid.git "$LDID_COMMIT"
for patch_name in bundle-code-signing-flags.patch entitlement-memory.patch preserve-linkedit-extent.patch; do
    apply_patch "$HOST_TOOL_ROOT/src/ldid" "$CHECKOUT/build_patch/ldid/$patch_name"
done
"$HOST_MAKE" -C "$HOST_TOOL_ROOT/src/ldid" clean
"$HOST_MAKE" -C "$HOST_TOOL_ROOT/src/ldid" -j"$HOST_JOBS" \
    CC="$HOST_CC" CXX="$HOST_CXX" VERSION=2.1.5-procursus7 \
    CPPFLAGS="${host_cppflags[*]:-}" CXXFLAGS="${host_cxxflags[*]:-}" LDFLAGS="${host_ldflags[*]:-}" \
    LIBCRYPTO_INCLUDES="$("$HOST_PKG_CONFIG" --cflags libcrypto)" \
    LIBCRYPTO_LIBS="$("$HOST_PKG_CONFIG" --libs libcrypto)" \
    LIBPLIST_INCLUDES="$("$HOST_PKG_CONFIG" --cflags libplist-2.0)" \
    LIBPLIST_LIBS="$("$HOST_PKG_CONFIG" --libs libplist-2.0)"
[[ ! -L $HOST_TOOL_ROOT/bin/ldid ]] || fail 'refusing existing symlink bin/ldid'
install -m 755 "$HOST_TOOL_ROOT/src/ldid/ldid" "$HOST_TOOL_ROOT/bin/ldid"
ln -sf ldid "$HOST_TOOL_ROOT/bin/ldid2"

fetch_source libroothide https://github.com/roothide/libroothide.git "$ROOTHIDE_COMMIT"
apply_patch "$HOST_TOOL_ROOT/src/libroothide" "$CHECKOUT/build_patch/roothide/symredirect-universal.diff"
apply_patch "$HOST_TOOL_ROOT/src/libroothide" "$CHECKOUT/build_patch/host-symredirect/portable-headers.diff"
if [[ $HOST_PLATFORM == linux ]]; then
    # Header definitions only: do not link a target SDK or build cctools/libtapi.
    fetch_source cctools-headers https://github.com/tpoechtrager/cctools-port.git "$CCTOOLS_COMMIT"
    cctools_include="$HOST_TOOL_ROOT/src/cctools-headers/cctools"
    # Prefer current Mach-O definitions; foreign fallback headers must not
    # shadow glibc's strings.h and other native system headers.
    host_cppflags+=(-I"$cctools_include/include" -idirafter "$cctools_include/include/foreign" -I"$cctools_include/otool")
fi
[[ ! -L $HOST_TOOL_ROOT/bin/symredirect ]] || fail 'refusing existing symlink bin/symredirect'
"$HOST_CXX" -std=c++11 ${host_cppflags[@]+"${host_cppflags[@]}"} ${host_cxxflags[@]+"${host_cxxflags[@]}"} \
    "$HOST_TOOL_ROOT/src/libroothide/symredirect.cpp" ${host_ldflags[@]+"${host_ldflags[@]}"} \
    -o "$HOST_TOOL_ROOT/bin/symredirect"

if [[ $HOST_PLATFORM == ios ]]; then
    # Native iOS requires a pre-existing signer to bootstrap newly linked tools.
    host_sign_ldid=${HOST_SIGN_LDID:-$(command -v ldid || true)}
    [[ -n $host_sign_ldid ]] || fail 'iOS bootstrap requires native ldid (or HOST_SIGN_LDID)'
    "$host_sign_ldid" -S "$HOST_TOOL_ROOT/bin/ldid"
    "$host_sign_ldid" -S "$HOST_TOOL_ROOT/bin/symredirect"
fi
if [[ ! -e $HOST_TOOL_ROOT/venv ]]; then
    "$HOST_PYTHON" -m venv --without-pip "$HOST_TOOL_ROOT/venv" || fail 'Python venv creation failed; Linux needs python3-venv, iOS needs the complete native libpython3.9 standard library'
fi
[[ ! -L $HOST_TOOL_ROOT/venv && -x $HOST_TOOL_ROOT/venv/bin/python ]] || fail 'invalid local Python venv'
if ! "$HOST_TOOL_ROOT/venv/bin/python" -m pip --version >/dev/null 2>&1; then
    # --without-ensurepip in Python's configure skips automatic installation;
    # it does not remove the stdlib ensurepip module or bundled wheels.
    "$HOST_TOOL_ROOT/venv/bin/python" -m ensurepip --upgrade || fail 'venv ensurepip failed; restore the Python ensurepip module/bundled wheels (on Debian/Ubuntu install python3-venv), then rerun'
fi
"$HOST_TOOL_ROOT/venv/bin/python" -m pip install --disable-pip-version-check \
    'pip==24.3.1' 'setuptools==75.3.2' 'wheel==0.45.1'
"$HOST_TOOL_ROOT/venv/bin/python" -m pip install --disable-pip-version-check \
    'Cython==0.29.37' 'meson==0.64.0' 'commonmark==0.9.1'
"$HOST_TOOL_ROOT/venv/bin/python" -c 'import Cython; assert Cython.__version__ == "0.29.37"'
"$HOST_TOOL_ROOT/venv/bin/meson" --version
"$HOST_TOOL_ROOT/venv/bin/python" -m pip install --disable-pip-version-check \
    -r "$CHECKOUT/build_misc/ghc/requirements-sphinx.txt"
"$HOST_TOOL_ROOT/venv/bin/sphinx-build" --version
if [[ $HOST_PLATFORM == linux ]]; then
    # Duktape's upstream source generator still requires Python 2 and PyYAML.
    host_python2_prefix="$HOST_TOOL_ROOT/python2.7"
    host_python2_archive="$HOST_TOOL_ROOT/cache/Python-2.7.18.tar.xz"
    if [[ ! -x $host_python2_prefix/bin/python2.7 ]]; then
        if [[ ! -f $host_python2_archive ]]; then
            curl --fail --location --retry 3 -o "$host_python2_archive.part" \
                https://www.python.org/ftp/python/2.7.18/Python-2.7.18.tar.xz
            mv "$host_python2_archive.part" "$host_python2_archive"
        fi
        printf '%s  %s\n' b62c0e7937551d0cc02b8fd5cb0f544f9405bafc9a54d3808ed4594812edef43 "$host_python2_archive" | sha256sum -c -
        mkdir -p "$HOST_TOOL_ROOT/src/host-python2.7"
        tar -xf "$host_python2_archive" --strip-components=1 -C "$HOST_TOOL_ROOT/src/host-python2.7"
        (
            unset CC CXX CPP CFLAGS CXXFLAGS CPPFLAGS LDFLAGS LDSHARED AR RANLIB LD NM CONFIG_SITE MACOSX_DEPLOYMENT_TARGET
            cd "$HOST_TOOL_ROOT/src/host-python2.7"
            CC="$HOST_CC" CXX="$HOST_CXX" CFLAGS="-O2 -std=gnu89" ./configure \
                --prefix="$host_python2_prefix" --with-ensurepip=no
            "$HOST_MAKE" -j "$HOST_JOBS"
            "$HOST_MAKE" altinstall
        )
    fi
    "$host_python2_prefix/bin/python2.7" -c 'import sys, zlib; assert sys.version_info[:3] == (2, 7, 18)'
    if ! "$host_python2_prefix/bin/python2.7" -c 'import yaml; assert yaml.__version__ == "5.3.1"' 2>/dev/null; then
        host_yaml_archive="$HOST_TOOL_ROOT/cache/PyYAML-5.3.1.tar.gz"
        if [[ ! -f $host_yaml_archive ]]; then
            curl --fail --location --retry 3 -o "$host_yaml_archive.part" \
                https://files.pythonhosted.org/packages/64/c2/b80047c7ac2478f9501676c988a5411ed5572f35d1beff9cae07d321512c/PyYAML-5.3.1.tar.gz
            mv "$host_yaml_archive.part" "$host_yaml_archive"
        fi
        printf '%s  %s\n' b8eac752c5e14d3eca0e6dd9199cd627518cb5ec06add0de9d32baeee6fe645d "$host_yaml_archive" | sha256sum -c -
        mkdir -p "$HOST_TOOL_ROOT/src/host-pyyaml"
        tar -xf "$host_yaml_archive" --strip-components=1 -C "$HOST_TOOL_ROOT/src/host-pyyaml"
        (cd "$HOST_TOOL_ROOT/src/host-pyyaml" && "$host_python2_prefix/bin/python2.7" setup.py --without-libyaml install --prefix="$host_python2_prefix")
    fi
    "$host_python2_prefix/bin/python2.7" -c 'import yaml; assert yaml.safe_load("test: yes")["test"] is True'
    ln -sfn "$host_python2_prefix/bin/python2.7" "$HOST_TOOL_ROOT/bin/python2"
    # Python package recipes use the target's 3.9 ABI, independently of Meson.
    host_python_prefix="$HOST_TOOL_ROOT/python3.9"
    host_python_archive="$HOST_TOOL_ROOT/cache/Python-3.9.9.tar.xz"
    if [[ ! -x $host_python_prefix/bin/python3.9 ]]; then
        if [[ ! -f $host_python_archive ]]; then
            curl --fail --location --retry 3 -o "$host_python_archive.part" \
                https://www.python.org/ftp/python/3.9.9/Python-3.9.9.tar.xz
            mv "$host_python_archive.part" "$host_python_archive"
        fi
        printf '%s  %s\n' 06828c04a573c073a4e51c4292a27c1be4ae26621c3edc7cf9318418ce3b6d27 "$host_python_archive" | sha256sum -c -
        mkdir -p "$HOST_TOOL_ROOT/src/host-python3.9"
        tar -xf "$host_python_archive" --strip-components=1 -C "$HOST_TOOL_ROOT/src/host-python3.9"
        (
            unset CC CXX CPP CFLAGS CXXFLAGS CPPFLAGS LDFLAGS LDSHARED AR RANLIB LD NM CONFIG_SITE MACOSX_DEPLOYMENT_TARGET
            cd "$HOST_TOOL_ROOT/src/host-python3.9"
            CC="$HOST_CC" CXX="$HOST_CXX" ./configure --prefix="$host_python_prefix" --with-ensurepip=install
            "$HOST_MAKE" -j "$HOST_JOBS"
            "$HOST_MAKE" altinstall
        )
    fi
    "$host_python_prefix/bin/python3.9" -c 'import sys, ssl, zlib, bz2, lzma, ctypes; assert sys.version_info[:3] == (3, 9, 9)'
    "$host_python_prefix/bin/python3.9" -m pip install --disable-pip-version-check \
        'pip==24.3.1' 'setuptools==75.3.2' 'wheel==0.45.1' 'Cython==0.29.37'
    ln -sfn "$host_python_prefix/bin/python3.9" "$HOST_TOOL_ROOT/bin/python3.9"
fi
if [[ $HOST_PLATFORM == linux ]]; then
    export CARGO_HOME="$HOST_TOOL_ROOT/cargo" RUSTUP_HOME="$HOST_TOOL_ROOT/rustup"
    case $(uname -m) in
        aarch64|arm64) rust_host=aarch64-unknown-linux-gnu; rustup_sha=1cffbf51e63e634c746f741de50649bbbcbd9dbe1de363c9ecef64e278dba2b2 ;;
        x86_64) rust_host=x86_64-unknown-linux-gnu; rustup_sha=6aeece6993e902708983b209d04c0d1dbb14ebb405ddb87def578d41f920f56d ;;
        *) fail 'unsupported Linux Rust host architecture' ;;
    esac
    if [[ ! -x $CARGO_HOME/bin/rustup ]]; then
        rustup_init="$HOST_TOOL_ROOT/cache/rustup-init-1.27.1-$rust_host"
        curl --fail --location --retry 3 -o "$rustup_init" "https://static.rust-lang.org/rustup/archive/1.27.1/$rust_host/rustup-init"
        printf '%s  %s\n' "$rustup_sha" "$rustup_init" | sha256sum -c -
        chmod 755 "$rustup_init"
        "$rustup_init" -y --no-modify-path --profile minimal --default-toolchain none
    fi
    "$CARGO_HOME/bin/rustup" toolchain install 1.88.0 --profile minimal --target aarch64-apple-ios --no-self-update
    "$CARGO_HOME/bin/rustup" default 1.88.0
    "$CARGO_HOME/bin/cargo" install cargo-c --version 0.10.13 --locked
    case $rust_host in
        aarch64-*) go_arch=arm64; go_sha=a8e177c354d2e4a1b61020aca3562e27ea3e8f8247eca3170e3fa1e0c2f9e771 ;;
        x86_64-*) go_arch=amd64; go_sha=ba79d4526102575196273416239cca418a651e049c2b099f3159db85e7bade7d ;;
    esac
    go_archive="$HOST_TOOL_ROOT/cache/go1.22.4.linux-$go_arch.tar.gz"
    if [[ ! -f $go_archive ]]; then
        curl --fail --location --retry 3 -o "$go_archive.part" "https://go.dev/dl/go1.22.4.linux-$go_arch.tar.gz"
        mv "$go_archive.part" "$go_archive"
    fi
    printf '%s  %s\n' "$go_sha" "$go_archive" | sha256sum -c -
    mkdir -p "$HOST_TOOL_ROOT/go1.22.4"
    tar -xf "$go_archive" --strip-components=1 -C "$HOST_TOOL_ROOT/go1.22.4"
    "$HOST_TOOL_ROOT/go1.22.4/bin/go" version
fi
# Source from bash/zsh; retain caller PATH and real HOME.
{
    printf 'umask 022\n'
    printf 'export HOST_TOOL_ROOT=%q\n' "$HOST_TOOL_ROOT"
    if [[ $HOST_PLATFORM != linux ]]; then
        printf 'export TARGET_SYSROOT=%q\nexport MACOSX_SYSROOT=%q\n' "$TARGET_SYSROOT" "$MACOSX_SYSROOT"
    fi
    if [[ -n ${DOCBOOK_XSL:-} ]]; then printf 'export DOCBOOK_XSL=%q\n' "$DOCBOOK_XSL"; fi
    if [[ $HOST_PLATFORM == macos ]]; then printf 'export LIBTOOLIZE=glibtoolize\n'; fi
    if [[ $HOST_PLATFORM == linux ]]; then
        printf 'export CARGO_HOME=%q\nexport RUSTUP_HOME=%q\n' "$CARGO_HOME" "$RUSTUP_HOME"
        printf 'export GOPATH=%q\nexport GOCACHE=%q\nexport GOROOT_BOOTSTRAP=%q\n' "$HOST_TOOL_ROOT/go-work" "$HOST_TOOL_ROOT/cache/go-build" "$HOST_TOOL_ROOT/go1.22.4"
    fi
    printf 'export PATH=%q:%q:' "$HOST_TOOL_ROOT/bin" "$HOST_TOOL_ROOT/venv/bin"
    if [[ $HOST_PLATFORM == linux ]]; then printf '%q:%q:' "$CARGO_HOME/bin" "$HOST_TOOL_ROOT/go1.22.4/bin"; fi
    if [[ $HOST_PLATFORM == macos && -n ${host_gnu_paths[*]:-} ]]; then
        for host_gnu_path in "${host_gnu_paths[@]}"; do printf '%q:' "$host_gnu_path"; done
    fi
    printf '"$PATH"\n'
} > "$HOST_TOOL_ROOT/host-env.sh"
printf 'Prepared native tools; source %q\n' "$HOST_TOOL_ROOT/host-env.sh"
