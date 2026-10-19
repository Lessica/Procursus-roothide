<p align="center">
    <h1 align="center">Procursus</h1>
    <p align="center">
        <a href="https://github.com/ProcursusTeam/Procursus/wiki">Documentation</a> —
        <a href="https://procursus.creator-spring.com/">Merchandise</a> —
        <a href="https://diatr.us/discord">Discord</a>
    </p>
</p>

A new, powerful, cross-compilation *OS bootstrap. At its core, Procursus is a build-system that provides a large set of consistently up-to-date *nix tools cross compiled to work on Darwin based platforms.

The build-system is built in a manner where maintenance of packages is fairly simple, helping to not fall behind upstream.

## History
At its birth, this build-system was meant to be an APT repository included in a specific jailbreak. However, that never came to pass, turning the project into a hobby.

In the iOS jailbreak scene, Procursus attempts to address an odd fragmentation problem seen over the past couple of years. Many new APT repositories have arisen from the ashes of Saurik's Telesphoreo, both with their respective flaws. One of the main issues is that each repository is targeted to one specific jailbreak.

Procursus attempts to circumvent this by excluding hooking platforms or packages that provide code-injection, providing a "plug-and-play" experience for anyone who decides to use it on their specific project. In the context of iOS jailbreaks, this allows developers to provide and maintain their own hooking libraries, while we maintain core, system packages seperately.

## Features
Here are a few changes over other existing build-systems
- Based on Makefiles, allowing parallel package building that is much quicker while also making easier to add new packages
- Fully open-sourced (utilizing GNU tools) and open to community contribution. See [Contributing](#Contributing)
- No jailbreak-specific software, making it easier to implement with other projects
- **First ever bootstrap** to be fully functional with each of the main 4 package managers out of the box (e.g Sileo and Zebra), making it easier to switch to your preferred package manager
- Better Obj-C implementation of ``firmware.sh`` that's not only quicker, but also based on CPU subtype (e.g ``cy.cpu.arm64e``)

## Contributing
Contributions (Issues or Pull Requests) are welcome with open arms. Check out the [contribution guidelines](./CONTRIBUTING.md) before helping out.

## RootHide host tools

RootHide builds require patched host `ldid` and `symredirect` on `PATH`. Restore their sources from the versions in [ldid.mk](makefiles/ldid.mk) and [roothide.mk](makefiles/roothide.mk), applying the checked-in patches before compiling for the host. The following prepares sources only; set `CHECKOUT` to this checkout's absolute path and use a fresh directory beneath it:

```sh
: "${CHECKOUT:?Set CHECKOUT to the absolute checkout path}"
HOST_TOOL_ROOT="$CHECKOUT/build_work/host-tools"
(
set -e
test ! -e "$HOST_TOOL_ROOT"
mkdir -p "$HOST_TOOL_ROOT/src" "$HOST_TOOL_ROOT/bin"
git clone --depth 1 --branch v2.1.5-procursus7 https://github.com/ProcursusTeam/ldid.git "$HOST_TOOL_ROOT/src/ldid"
for patch in bundle-code-signing-flags.patch entitlement-memory.patch preserve-linkedit-extent.patch; do
    patch -d "$HOST_TOOL_ROOT/src/ldid" -p1 < "$CHECKOUT/build_patch/ldid/$patch" || exit 1
done
git init "$HOST_TOOL_ROOT/src/libroothide"
git -C "$HOST_TOOL_ROOT/src/libroothide" fetch --depth 1 https://github.com/roothide/libroothide.git 7764c54759009272b4f2f23c18c62b21794fe6dd
git -C "$HOST_TOOL_ROOT/src/libroothide" checkout --detach FETCH_HEAD
patch -d "$HOST_TOOL_ROOT/src/libroothide" -p1 < "$CHECKOUT/build_patch/roothide/symredirect-universal.diff"
)
```

Host compilation needs a host C++ toolchain and, for `ldid`, host OpenSSL/libcrypto and libplist headers and libraries. Select the compiler, macOS SDK and dependency prefixes explicitly; keep the login `HOME` and place generated tools in `$HOST_TOOL_ROOT/bin`, then prepend that directory to `PATH`. Do not use the iOS libraries or package-install targets to prepare host tools. These instructions prepare the patched sources; host dependency installation and compilation remain manual. The Linux setup script still clones `ldid` HEAD and does not supply these pinned, patched tools.

## Credits
Build system created by [Diatrus](https://twitter.com/Diatrus) and [Kirb](https://twitter.com/hbkirb). Built better by all our wonderful contributors. Made worth it by people like you!

Thank you to Macstadium for sponsoring us through their open source program!
