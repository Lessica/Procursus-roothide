# macOS 构建指南

以下命令从仓库根目录执行，并先设置 `umask 022`。

```bash
umask 022
```

## 环境准备

- 完整 Xcode 16，包含 macOS、iOS、tvOS 和 watchOS 的设备及模拟器 SDK
- Homebrew

## 准备宿主

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
./build_tools/prepare_macos_host.sh
source build_work/host-tools/host-env.sh
```

依赖已安装时可加 `--skip-system-deps`。每开一个新终端，重新执行：

```bash
source build_work/host-tools/host-env.sh
```

构建 tvOS 的 `swift-5.9.2` 包还需 tvOS 16.4 SDK。安装 Xcode 14.3.1 后执行，路径按实际安装位置调整：

```bash
swift_sdk="/Applications/Xcode-14.3.1.app/Contents/Developer/Platforms/AppleTVOS.platform/Developer/SDKs/AppleTVOS.sdk"
mkdir -p build_work/host-tools/SDK/AppleTVOS-Swift5.9.sdk
cp -R "$swift_sdk/." build_work/host-tools/SDK/AppleTVOS-Swift5.9.sdk/
```

`RECIPE_JOBS` 控制外层配方步骤并发，默认 1；`CORE_COUNT` 控制配方内部编译并发，默认取 CPU 核心数。两者的并发额度会叠加。例如：

```bash
export RECIPE_JOBS=1
export CORE_COUNT=32
```

## 配置签名

- `BOOTSTRAP_APT_KEYRING`：软件源公钥文件，`make package` 前设置。
- `MEMO_PGP_SIGN_KEY`：签名私钥指纹，生成 Bootstrap 时使用。

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

正式发布使用正式签名身份。带口令的密钥需先设置 `GPG_TTY=$(tty)` 并解锁；非交互环境使用已解锁的 GPG agent 或无口令的发布密钥。

## 目标平台

| MEMO_TARGET | Debian 架构 | 用途 |
| --- | --- | --- |
| `iphoneos-arm64-roothide` | `iphoneos-arm64e` | iOS |
| `appletvos-arm64-roothide` | `appletvos-arm64e` | tvOS |

`appletvos-arm64e` 是 `appletvos-arm64-roothide` 的别名。`arm64e` 是 RootHide 的 Debian 包架构命名，两种目标的 Mach-O 架构都是 arm64。默认目标为 `iphoneos-arm64-roothide`。

构建 tvOS：

```bash
make package MEMO_TARGET=appletvos-arm64-roothide
```

## 构建软件包

```bash
make package
make xz-package
make package SUBPROJECTS="xz zstd"
```

所选配方的依赖会自动构建。保存日志：

```bash
set -o pipefail
make --output-sync=target package 2>&1 | tee -a build_work/macos-build.log
```

终端状态界面：

```bash
python3 build_tools/build_status.py package
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

## 断点续建

重复原构建命令即可续建。修改已完成配方的源码或编译参数后，重建该配方：

```bash
make rebuild-xz-package
```

## 输出

| 目录 | 内容 |
| --- | --- |
| `build_dist/<目标>/<CF版本>/<配方>/` | Debian 软件包 |
| `build_stage/<目标>/<CF版本>/` | 安装暂存文件 |
| `build_base/<目标>/<CF版本>/` | 目标依赖 |
| `build_work/<目标>/<CF版本>/` | 源码、编译目录和完成标记 |
| `build_strap/<目标>/<CF版本>/` | Bootstrap 及其组装材料 |

## 生成本地 APT 软件源

APT 软件源在 Linux 宿主生成和验收，步骤见 [Linux 构建指南](./building.md#生成本地-apt-软件源)。

## 常见问题

- `Please run umask 022`：执行 `umask 022` 后重试。
- `Set BOOTSTRAP_APT_KEYRING ...`：先导出公钥并设置该变量。
- `gpg: signing failed: Inappropriate ioctl for device`：设置 `GPG_TTY=$(tty)` 并解锁密钥，或使用已解锁的 agent。
