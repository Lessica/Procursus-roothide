# Linux 开发者构建指南

本文介绍在 Ubuntu 24.04 上全量构建 Procursus (Relaxin) 软件包、生成 Bootstrap 和断点续建。Mac 仅用于提供 Linux 构建所需的材料。所有命令从仓库根目录执行，除非另有说明。

## 构建并发

`CORE_COUNT` 默认按当前设备的 CPU 核心数设置，无需手动指定。如需限制并发，可执行 `export CORE_COUNT=10`。

## 准备宿主

Linux 宿主支持 arm64 和 x86_64，需要联网获取系统依赖、源码及引导工具链。已有 Linux 服务器可直接在仓库目录执行准备命令；使用容器则先按下面的步骤创建环境。

### 使用 Docker 或 OrbStack

在 Mac 仓库目录创建独立的 Linux 容器，并导入当前提交的源码：

```bash
docker run -d --init --name procursus-build ubuntu:24.04 sleep infinity
docker exec procursus-build mkdir -p /work
git archive HEAD | docker exec -i procursus-build tar -x -C /work
docker exec -it -w /work procursus-build bash
```

进入容器后，继续执行下一节的 Linux 准备命令。源码位于容器自己的文件系统中；`git archive HEAD` 不包含未提交修改和本地构建缓存。后续可用以下命令重新进入同一容器：

```bash
docker exec -it -w /work procursus-build bash
```

### Linux

使用 Ubuntu 24.04，执行以下命令准备系统依赖和交叉编译环境：

```bash
./build_tools/prepare_linux_host.sh
source build_work/host-tools/host-env.sh
```

安装系统依赖需要 root 或 sudo。依赖清单位于 [linux-packages.txt](../build_misc/host-tools/linux-packages.txt)。准备入口的 `--deps-only` 只安装系统依赖；`--skip-system-deps` 用于系统依赖已就绪的环境。

准备脚本也会配置 Python、GHC、Rust、Go 和 Swift 等宿主引导工具，无需从 Mac 复制这些工具。OpenJDK 配方会自行下载宿主 JDK。

```bash
source build_work/host-tools/host-env.sh
```

新开终端或重新进入容器后，执行上述 `source` 命令即可恢复构建环境。

## 为 Linux 准备 Mac 输入

Linux 全量构建需要从 Mac 获取 libroothide、ElleKit、locale 数据和 LLVM 运行时所需的 Apple SDK。两台宿主应使用同一版本的仓库源码。

### 准备材料提供端

需要完整 Xcode、Homebrew 和 Git。选择包含 iPhoneOS SDK 的 Xcode 后，安装依赖并准备宿主工具：

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
./build_tools/prepare_native_tools.sh --install-system-deps
source build_work/host-tools/host-env.sh
```

已安装系统依赖时，可省略 `--install-system-deps`。

### 在 Mac 上生成

加载 Mac 工具环境后执行：

```bash
make roothide-xcode-export
make ellekit-package
tar -cf build_work/mac-locale.tar -C /usr/share locale
```

从当前选定的 Xcode 收集额外 SDK。请先在 Xcode 设置的 Platforms 或 Components 页面中安装 iOS、tvOS 和 watchOS 平台支持，确保以下 SDK 查询均能成功：

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
tar -cf build_work/apple-sdks.tar -C build_work/apple-sdks .
)
```

如有查询或复制失败，补齐对应平台后再继续。Linux 准备脚本已提供 iPhoneOS SDK；这里的 MacOSX SDK 供 LLVM 运行时使用，不替换准备脚本配置的基础 macOS SDK。

需要传递的材料：

| 材料 | Mac 路径 | Linux 用途 |
| --- | --- | --- |
| libroothide 导出包 | `build_work/iphoneos-arm64-roothide/1900/libroothide-xcode.tar` | libroothide 构建输入 |
| Apple SDK | `build_work/apple-sdks.tar` | LLVM 运行时构建输入 |
| locale 数据 | `build_work/mac-locale.tar` | gettext-localizations 构建输入 |
| ElleKit Debian 包 | `build_dist/iphoneos-arm64-roothide/1900/ellekit/` | 合并到最终软件包输出 |

### 传入 Linux

独立服务器可使用 `scp` 或 `rsync` 传输，保留表中的相对路径。使用上述容器时，在 Mac 执行：

```bash
docker exec procursus-build mkdir -p /work/build_work/iphoneos-arm64-roothide/1900 /work/build_dist/iphoneos-arm64-roothide/1900
docker cp build_work/iphoneos-arm64-roothide/1900/libroothide-xcode.tar procursus-build:/work/build_work/iphoneos-arm64-roothide/1900/
docker cp build_work/mac-locale.tar procursus-build:/work/build_work/
docker cp build_work/apple-sdks.tar procursus-build:/work/build_work/
docker cp build_dist/iphoneos-arm64-roothide/1900/ellekit procursus-build:/work/build_dist/iphoneos-arm64-roothide/1900/
```

在 Linux 仓库目录解包并配置输入：

```bash
tar -xf build_work/mac-locale.tar -C build_work
tar -xf build_work/apple-sdks.tar -C "$HOST_TOOL_ROOT/SDK"
(
set -e
make roothide-xcode-check
test -f "$GETTEXT_LOCALIZATIONS_INPUT/en_US.UTF-8/LC_CTYPE"
test -f "$GETTEXT_LOCALIZATIONS_INPUT/en_US.UTF-8/LC_COLLATE"
dpkg-deb -f build_dist/iphoneos-arm64-roothide/1900/ellekit/ellekit_*.deb Package Version Architecture
python3 - "$HOST_TOOL_ROOT/SDK/MacOSX.sdk/SDKSettings.json" <<'PYSDK'
import json, sys
with open(sys.argv[1]) as f:
    sdk = json.load(f)
assert sdk['CanonicalName'] == 'macosx' + sdk['Version']
print('LLVM macOS SDK:', sdk['Version'])
PYSDK
for sdk in macosx iphoneos iphonesimulator appletvos appletvsimulator watchos watchsimulator; do
    xcrun --sdk "$sdk" --show-sdk-path
    xcrun --sdk "$sdk" --show-sdk-version
done
)
```

上述检查必须全部成功后再开始构建。libroothide 输入会与当前源码及目标核对；SDK 检查用于确认 Linux 能找到所需的平台。Linux 默认构建列表不包含 ElleKit；从 Mac 传入的 Debian 包保留在输出目录中。

## 构建软件包

在 Linux 仓库根目录加载环境后，即可全量构建当前宿主和目标支持的所有配方：

```bash
make package
```

构建单个配方及其依赖：

```bash
make xcb-util-xrm-package
```

通过 `SUBPROJECTS` 指定多个配方，以空格分隔：

```bash
make package SUBPROJECTS="xz zstd"
```

所选配方的依赖会自动构建。

保存普通构建日志：

```bash
set -o pipefail
make --output-sync=target package 2>&1 | tee -a build_work/linux-build.log
```

### 可选终端界面

Ubuntu 环境准备完成后，可直接使用终端状态界面：

```bash
python3 build_tools/build_status.py package
```

界面显示任务状态、构建进度和错误摘要，完整日志保存到 `build_work/build-ui.log`。如需限定构建范围，在命令末尾加上 `SUBPROJECTS="xz zstd"`。

## 断点续建

重复原构建命令即可续建。新终端先执行 `source build_work/host-tools/host-env.sh`。指定范围构建时，保留原来的 `SUBPROJECTS` 参数。

续建会复用已有源码和编译结果，打包阶段可能再次执行。请保留 `build_source`、`build_work`、`build_stage`、`build_base` 和 `build_dist`，以及已传入的 Mac 材料。

修改已完成配方的源码或编译参数后，需要显式重建该配方，例如：

```bash
make rebuild-xcb-util-xrm-package
```

不同宿主应使用各自的编译缓存。

## 输出与 Bootstrap

| 目录 | 内容 |
| --- | --- |
| `build_source/` | 下载的源码归档 |
| `build_dist/<目标>/<CF版本>/<配方>/` | Debian 软件包 |
| `build_stage/<目标>/<CF版本>/` | 各配方的安装暂存文件 |
| `build_base/<目标>/<CF版本>/` | 供其他配方使用的目标依赖 |
| `build_work/<目标>/<CF版本>/` | 源码、编译目录和完成标记 |
| `build_strap/<目标>/<CF版本>/` | Bootstrap 及其组装材料 |

### 配置签名

Procursus (Relaxin) 的 Bootstrap 归档和 APT 软件源都必须签名，Bootstrap 必须携带用于验证软件源的公钥。私钥保留在 GnuPG 密钥目录，不放入仓库、Bootstrap 或软件源目录。

首次本地验收可生成一把独立的测试密钥。以下命令只需执行一次，按提示设置口令：

```bash
export GNUPGHOME="$HOME/.gnupg-procursus-relaxin"
mkdir -p "$GNUPGHOME"
chmod 700 "$GNUPGHOME"
export GPG_TTY=$(tty)
gpg --quick-generate-key "Procursus Relaxin" rsa3072 sign 5y
```

在构建终端配置签名身份并导出公钥：

```bash
export GNUPGHOME="$HOME/.gnupg-procursus-relaxin"
export GPG_TTY=$(tty)
export MEMO_PGP_SIGN_KEY=$(gpg --with-colons --list-keys \
  "Procursus Relaxin" |
  awk -F: '$1 == "fpr" {print $10; exit}')
export BOOTSTRAP_APT_KEYRING="$PWD/build_work/procursus-relaxin.gpg"

gpg --yes --output "$BOOTSTRAP_APT_KEYRING" --export "$MEMO_PGP_SIGN_KEY"
gpg --show-keys --with-fingerprint "$BOOTSTRAP_APT_KEYRING"
```

正式交付时使用正式签名身份及对应公钥，不能沿用测试密钥。`MEMO_PGP_SIGN_KEY` 指定 Bootstrap 签名密钥的指纹；`BOOTSTRAP_APT_KEYRING` 指向软件源公钥文件。打包时公钥会写入 Bootstrap 的 `/usr/share/keyrings/owngoal-procursus.gpg`，APT 源配置通过 `Signed-By` 引用它。

### 生成并验证 Bootstrap

加载构建环境、Mac 输入及上述签名配置后执行。此命令按 Makefile 成员列表构建所需软件包并组装 Bootstrap，无需先完成全仓构建；已有编译结果会复用。

```bash
make bootstrap

gpg --verify \
  build_strap/iphoneos-arm64-roothide/1900/bootstrap_1900.tar.zst.asc \
  build_strap/iphoneos-arm64-roothide/1900/bootstrap_1900.tar.zst
```

验证必须成功，且签名者指纹应与配置的密钥一致。新开终端时，需要重新设置签名环境变量；无需重新生成密钥。

默认源地址为 `https://procursus.owngoal.dev`，可通过 `MEMO_REPO_URI` 指定。生成 Bootstrap 不会发布软件源，也不会自动签署 APT 元数据；软件源还需生成并签署 `Release.gpg` 和 `InRelease`。
