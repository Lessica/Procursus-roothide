# Linux 构建指南

Ubuntu 24.04。准备脚本需要 sudo。以下命令从仓库根目录执行，并先设置 `umask 022`。

```bash
umask 022
```

## 准备宿主

### 直接使用 Linux

```bash
./build_tools/prepare_linux_host.sh
source build_work/host-tools/host-env.sh
```

`--deps-only` 只安装系统依赖；`--skip-system-deps` 跳过系统依赖安装。每开一个新终端，重新执行：

```bash
source build_work/host-tools/host-env.sh
```

### 使用容器

```bash
docker run -d --init --name owngoal-stripe-build ubuntu:24.04 sleep infinity
docker exec owngoal-stripe-build mkdir -p /work
git archive HEAD | docker exec -i owngoal-stripe-build tar -x -C /work
docker exec -it -w /work owngoal-stripe-build bash
```

进入容器后执行 `prepare_linux_host.sh` 并加载 `host-env.sh`。之后重新进入容器：

```bash
docker exec -it -w /work owngoal-stripe-build bash
```

需要构建未提交修改时，用 `rsync` 或重新克隆替代 `git archive`。

## 准备 Mac 输入

全量构建需要以下材料：

| 材料 | Mac 路径 | 用途 |
| --- | --- | --- |
| libroothide 导出包 | `build_work/iphoneos-arm64-roothide/1900/libroothide-xcode.tar` | libroothide |
| Apple SDK | `build_work/apple-sdks.tar` | LLVM 运行时、tvOS Swift 包 |
| locale 数据 | `build_work/mac-locale.tar` | gettext-localizations |

### 在 Mac 上生成

检出与 Linux 相同的提交，准备完整 Xcode、Homebrew 和 Git：

```bash
umask 022
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
./build_tools/prepare_macos_host.sh
source build_work/host-tools/host-env.sh
```

生成 libroothide 导出包和 locale：

```bash
make roothide-xcode-export
tar -cf build_work/mac-locale.tar -C /usr/share locale
```

在 Xcode 的 Platforms 或 Components 页面安装 iOS、tvOS 和 watchOS 平台支持，然后收集 SDK：

```bash
(
set -e
mkdir -p build_work/apple-sdks
for sdk in macosx iphonesimulator appletvos appletvsimulator watchos watchsimulator; do
    sdk_path=$(xcrun --sdk "$sdk" --show-sdk-path)
    case "$sdk" in
        macosx) sdk_name=MacOSX ;;
        iphonesimulator) sdk_name=iPhoneSimulator ;;
        appletvos) sdk_name=AppleTVOS ;;
        appletvsimulator) sdk_name=AppleTVSimulator ;;
        watchos) sdk_name=WatchOS ;;
        watchsimulator) sdk_name=WatchSimulator ;;
    esac
    mkdir -p "build_work/apple-sdks/$sdk_name.sdk"
    cp -R "$sdk_path/." "build_work/apple-sdks/$sdk_name.sdk/"
done
)
```

构建 tvOS 的 `swift-5.9.2` 包还需 tvOS 16.4 SDK。安装 Xcode 14.3.1 后执行，路径按实际安装位置调整：

```bash
swift_sdk="/Applications/Xcode-14.3.1.app/Contents/Developer/Platforms/AppleTVOS.platform/Developer/SDKs/AppleTVOS.sdk"
mkdir -p build_work/apple-sdks/AppleTVOS-Swift5.9.sdk
cp -R "$swift_sdk/." build_work/apple-sdks/AppleTVOS-Swift5.9.sdk/
```

归档 SDK：

```bash
COPYFILE_DISABLE=1 tar --exclude='._*' -cf build_work/apple-sdks.tar -C build_work/apple-sdks .
```

### 传入 Linux

独立服务器使用 `scp` 或 `rsync`，保留表中的相对路径。使用容器时：

```bash
docker exec owngoal-stripe-build mkdir -p /work/build_work/iphoneos-arm64-roothide/1900
docker cp build_work/iphoneos-arm64-roothide/1900/libroothide-xcode.tar owngoal-stripe-build:/work/build_work/iphoneos-arm64-roothide/1900/
docker cp build_work/mac-locale.tar owngoal-stripe-build:/work/build_work/
docker cp build_work/apple-sdks.tar owngoal-stripe-build:/work/build_work/
```

### 在 Linux 上解包

```bash
source build_work/host-tools/host-env.sh
tar -xf build_work/mac-locale.tar -C build_work
tar --exclude='._*' -xf build_work/apple-sdks.tar -C "$HOST_TOOL_ROOT/SDK"

make roothide-xcode-check
test -f "$GETTEXT_LOCALIZATIONS_INPUT/en_US.UTF-8/LC_CTYPE"
test -f "$HOST_TOOL_ROOT/SDK/MacOSX.sdk/SDKSettings.json"
```

## 配置签名

- `BOOTSTRAP_APT_KEYRING`：软件源公钥文件，`make package` 前设置。
- `MEMO_PGP_SIGN_KEY`：签名私钥指纹，生成 Bootstrap 和软件源时使用。

生成测试密钥：

```bash
export GNUPGHOME="$HOME/.gnupg-owngoal-stripe"
mkdir -p "$GNUPGHOME"
chmod 700 "$GNUPGHOME"
export GPG_TTY=$(tty)
gpg --quick-generate-key "OwnGoal Stripe" rsa3072 sign 5y
```

导出公钥并设置变量：

```bash
export GNUPGHOME="$HOME/.gnupg-owngoal-stripe"
export GPG_TTY=$(tty)
export MEMO_PGP_SIGN_KEY=$(gpg --with-colons --list-keys \
  "OwnGoal Stripe" |
  awk -F: '$1 == "fpr" {print $10; exit}')
export BOOTSTRAP_APT_KEYRING="$PWD/build_work/owngoal-stripe.gpg"

gpg --yes --output "$BOOTSTRAP_APT_KEYRING" --export "$MEMO_PGP_SIGN_KEY"
```

正式发布使用正式签名身份。私钥不放入仓库、Bootstrap 或软件源。带口令的密钥需先执行 `export GPG_TTY=$(tty)` 并解锁；非交互环境使用已解锁的 GPG agent 或无口令的发布密钥。

## 目标平台

| MEMO_TARGET | Debian 架构 | 用途 |
| --- | --- | --- |
| `iphoneos-arm64-roothide` | `iphoneos-arm64e` | iOS |
| `appletvos-arm64-roothide` | `appletvos-arm64e` | tvOS |

`appletvos-arm64e` 是 `appletvos-arm64-roothide` 的别名。`arm64e` 是 RootHide 的 Debian 包架构命名，两种目标的 Mach-O 架构都是 arm64。默认目标为 `iphoneos-arm64-roothide`。

### tvOS

Mac 准备入口执行前选择目标，其余 Mac 输入准备步骤相同：

```bash
export MEMO_TARGET=appletvos-arm64-roothide
```

libroothide 导出包路径改为 `build_work/appletvos-arm64-roothide/1900/libroothide-xcode.tar`。传入容器时：

```bash
docker exec owngoal-stripe-build mkdir -p /work/build_work/appletvos-arm64-roothide/1900
docker cp build_work/appletvos-arm64-roothide/1900/libroothide-xcode.tar owngoal-stripe-build:/work/build_work/appletvos-arm64-roothide/1900/
```

tvOS 的 Linux 准备入口需要预先导入 AppleTVOS SDK。先执行 `./build_tools/prepare_linux_host.sh --deps-only`，按上文传入 Mac 材料，再执行：

```bash
export MEMO_TARGET=appletvos-arm64-roothide
mkdir -p build_work/host-tools/SDK
tar -xf build_work/mac-locale.tar -C build_work
tar --exclude='._*' -xf build_work/apple-sdks.tar -C build_work/host-tools/SDK
./build_tools/prepare_linux_host.sh
source build_work/host-tools/host-env.sh
make roothide-xcode-check
```

构建：

```bash
make package MEMO_TARGET=appletvos-arm64-roothide
```

## 构建软件包

```bash
make package
make xcb-util-xrm-package
make package SUBPROJECTS="xz zstd"
```

所选配方的依赖会自动构建。保存日志：

```bash
set -o pipefail
make --output-sync=target package 2>&1 | tee -a build_work/linux-build.log
```

终端状态界面：

```bash
python3 build_tools/build_status.py package
```

`RECIPE_JOBS` 控制外层配方步骤并发，默认 1；`CORE_COUNT` 控制配方内部编译并发，默认取 CPU 核心数。两者的并发额度会叠加。例如：

```bash
export RECIPE_JOBS=1
export CORE_COUNT=32
```

## 断点续建

重复原构建命令即可续建。新终端先执行 `source build_work/host-tools/host-env.sh`，并保留原来的 `SUBPROJECTS`。

修改已完成配方的源码或编译参数后，重建该配方：

```bash
make rebuild-xcb-util-xrm-package
```

## 生成 Bootstrap

如需自定义源地址，先设置 `MEMO_REPO_URI`；默认 `https://stripe.owngoal.dev`。生成并验证：

```bash
make bootstrap

gpg --verify \
  build_strap/iphoneos-arm64-roothide/1900/bootstrap-iphoneos-arm64e.tar.zst.asc \
  build_strap/iphoneos-arm64-roothide/1900/bootstrap-iphoneos-arm64e.tar.zst
```

tvOS：

```bash
make bootstrap MEMO_TARGET=appletvos-arm64-roothide
gpg --verify \
  build_strap/appletvos-arm64-roothide/1900/bootstrap-appletvos-arm64e.tar.zst.asc \
  build_strap/appletvos-arm64-roothide/1900/bootstrap-appletvos-arm64e.tar.zst
```

## 生成本地 APT 软件源

`make repository` 使用当前 `MEMO_TARGET`，默认是 `iphoneos-arm64-roothide`。它把 Deb 归档到 `build_repo/`，生成并签名 `dists/1900`，然后校验索引、keyring 和 Bootstrap，并执行一次本地 `apt-get` 验收。

```bash
make repository
```

源使用 `MEMO_REPO_URI`、suite `1900` 和 component `main`；Bootstrap 使用相同的 URI、suite 和 keyring。重复运行只更新新增或变化的包。

## 输出目录

| 目录 | 内容 |
| --- | --- |
| `build_source/` | 下载的源码归档 |
| `build_dist/<目标>/<CF版本>/<配方>/` | Debian 软件包 |
| `build_stage/<目标>/<CF版本>/` | 安装暂存文件 |
| `build_base/<目标>/<CF版本>/` | 目标依赖 |
| `build_work/<目标>/<CF版本>/` | 源码、编译目录和完成标记 |
| `build_strap/<目标>/<CF版本>/` | Bootstrap 及其组装材料 |
| `build_repo/` | 本地 APT 软件源 |

## 常见问题

- `Please run umask 022`：执行 `umask 022` 后重试。
- `Set BOOTSTRAP_APT_KEYRING ...`：先导出公钥并设置该变量。
- `gpg: signing failed: Inappropriate ioctl for device`：设置 `GPG_TTY=$(tty)` 并解锁密钥，或使用已解锁的 agent。
