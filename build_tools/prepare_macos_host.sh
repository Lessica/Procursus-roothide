#!/usr/bin/env bash
# Prepare a macOS host; target packages are built through the main Makefile.
set -euo pipefail
umask 022

PROJDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
case ${1:-} in
    --help|-h)
        printf '%s\n' \
            'Usage: build_tools/prepare_macos_host.sh [--skip-system-deps]' \
            'Requires full Xcode and Homebrew; installs build dependencies by default.' \
            'Prepares native tools and bootstrap compilers through prepare_native_tools.sh.' \
            'Does not build target packages. Source build_work/host-tools/host-env.sh afterwards.'
        exit 0 ;;
    ''|--skip-system-deps) ;;
    *) echo 'Unknown option; use --help' >&2; exit 2 ;;
esac
[[ $# -le 1 ]] || { echo 'At most one option is supported.' >&2; exit 2; }
[[ $(uname -s) == Darwin && $(sw_vers -productName) == macOS ]] || {
    echo 'This preparation entry point requires macOS.' >&2; exit 1;
}
command -v brew >/dev/null || { echo 'Install Homebrew before preparing the host.' >&2; exit 1; }
export DEVELOPER_DIR=${DEVELOPER_DIR:-$(xcode-select -p)}
xcodebuild -version
xcodebuild -checkFirstLaunchStatus || {
    echo 'Complete the selected Xcode license and first-launch setup before preparing the host.' >&2
    exit 1
}
for sdk in macosx iphoneos iphonesimulator appletvos appletvsimulator watchos watchsimulator; do
    xcrun --sdk "$sdk" --show-sdk-path >/dev/null
done
test -f /usr/share/locale/en_US.UTF-8/LC_CTYPE
test -f /usr/share/locale/en_US.UTF-8/LC_COLLATE

if [[ ${1:-} == --skip-system-deps ]]; then
    HOST_PLATFORM=macos bash "$PROJDIR/build_tools/prepare_native_tools.sh"
else
    HOST_PLATFORM=macos bash "$PROJDIR/build_tools/prepare_native_tools.sh" --install-system-deps
fi
