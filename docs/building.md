# 开发者构建指南

Procursus (Relaxin) 使用 GNU Make 构建面向 Relaxin 的 RootHide 软件包。本文介绍宿主准备、跨宿主输入、软件包构建与断点续建；所有命令从仓库根目录执行，除非另有说明。

## 目标与构建参数

```bash
export MEMO_TARGET=iphoneos-arm64-roothide
export MEMO_CFVER=1900
export CORE_COUNT=10
```

Mac 和 Linux 使用相同源码版本、目标及 `MEMO_CFVER`。`CORE_COUNT` 控制构建并发，可按机器资源调整。Debian 架构标识 `iphoneos-arm64e` 表示 RootHide 包格式，不等同于 Mach-O 的 arm64e 架构。

## 准备宿主

### macOS

需要完整 Xcode、Homebrew 和 Git。选择包含 iPhoneOS SDK 的 Xcode 后，安装依赖并准备宿主工具：

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
./build_tools/prepare_native_tools.sh --install-system-deps
source build_work/host-tools/host-env.sh
```

已安装系统依赖时，省略 `--install-system-deps`。准备脚本负责宿主工具；软件包仍通过主 Makefile 构建。可用 `--print-system-deps` 查看系统依赖安装命令。

### Linux

使用 Ubuntu 24.04。准备入口安装系统依赖、Darwin 交叉工具链及 SDK，并调用宿主工具准备脚本：

```bash
./build_tools/prepare_linux_host.sh
source build_work/host-tools/host-env.sh
```

安装系统依赖需要 root 或 sudo。依赖清单位于 [linux-packages.txt](../build_misc/host-tools/linux-packages.txt)。准备入口的 `--deps-only` 只安装系统依赖；`--skip-system-deps` 用于系统依赖已就绪的环境。

每次新开终端，需要重新加载 `host-env.sh` 和构建参数，无需重复准备环境。

### 使用 Docker 或 OrbStack

在 Mac 仓库目录创建独立的 Linux 容器，并导入当前提交的源码：

```bash
docker run -d --init --name procursus-build ubuntu:24.04 sleep infinity
docker exec procursus-build mkdir -p /work
git archive HEAD | docker exec -i procursus-build tar -x -C /work
docker exec -it -w /work procursus-build bash
```

进入容器后执行前述 Linux 准备命令。源码位于容器自己的文件系统中；`git archive HEAD` 不包含未提交修改和本地构建缓存。后续可用以下命令重新进入同一容器：

```bash
docker exec -it -w /work procursus-build bash
```

## 为 Linux 准备 Mac 输入

libroothide 和 ElleKit 使用 Xcode 构建；`gettext-localizations` 使用 macOS locale 数据。Mac 和 Linux 各自准备宿主工具，只传递下面列出的材料。

### 在 Mac 上生成

加载 Mac 工具环境并设置构建参数后执行：

```bash
make roothide-xcode-export
make ellekit-package
tar -cf build_work/mac-locale.tar -C /usr/share locale
```

需要传递的材料：

| 材料 | Mac 路径 | Linux 用途 |
| --- | --- | --- |
| libroothide 导出包 | `build_work/iphoneos-arm64-roothide/1900/libroothide-xcode.tar` | libroothide 构建输入 |
| locale 数据 | `build_work/mac-locale.tar` | gettext-localizations 构建输入 |
| ElleKit Debian 包 | `build_dist/iphoneos-arm64-roothide/1900/ellekit/` | 合并到最终软件包输出 |

### 传入 Linux

独立服务器可使用 `scp` 或 `rsync` 传输，保留表中的相对路径。使用上述容器时，在 Mac 执行：

```bash
docker exec procursus-build mkdir -p /work/build_work/iphoneos-arm64-roothide/1900 /work/build_dist/iphoneos-arm64-roothide/1900
docker cp build_work/iphoneos-arm64-roothide/1900/libroothide-xcode.tar procursus-build:/work/build_work/iphoneos-arm64-roothide/1900/
docker cp build_work/mac-locale.tar procursus-build:/work/build_work/
docker cp build_dist/iphoneos-arm64-roothide/1900/ellekit procursus-build:/work/build_dist/iphoneos-arm64-roothide/1900/
```

在 Linux 仓库目录解包并配置输入：

```bash
tar -xf build_work/mac-locale.tar -C build_work
export ROOTHIDE_XCODE_INPUT="$PWD/build_work/iphoneos-arm64-roothide/1900/libroothide-xcode.tar"
export GETTEXT_LOCALIZATIONS_INPUT="$PWD/build_work/locale"
make roothide-xcode-check
```

检查目标会验证 libroothide 输入与当前源码及目标是否匹配。Linux 默认构建列表不包含 ElleKit；从 Mac 传入的 Debian 包保留在输出目录中。

## 构建软件包

单个配方及其依赖：

```bash
make xcb-util-xrm-package
```

所有当前目标启用的配方：

```bash
make package
```

常规包开发可排除耗时较长的工具链配方：

```bash
packages=$(make MEMO_QUIET=1 print-SUBPROJECTS | tr ' ' '\n' | grep -Ev '^(llvm|rust|ghc|openjdk|cctools)$' | sort -u | xargs)
make package SUBPROJECTS="$packages"
```

Swift 属于 LLVM 配方。上述范围不包含完整工具链；若需构建这些包，应按对应配方准备额外输入，尤其是 LLVM 的 Darwin 运行时所需 Apple SDK。`SUBPROJECTS` 选择打包目标，不会关闭它们的必要依赖。

保存普通构建日志：

```bash
set -o pipefail
make --output-sync=target package SUBPROJECTS="$packages" 2>&1 | tee -a build_work/linux-build.log
```

### 可选终端界面

Ubuntu 环境准备完成后，可直接使用终端状态界面：

```bash
python3 build_tools/build_status.py package SUBPROJECTS="$packages"
```

完整日志自动追加到 `build_work/build-ui.log`，无需接 `tee`。界面分别显示配方完成数、本轮 DEB 产出数、下载与缓存计数，以及活动任务。下载计数覆盖公共下载逻辑，不包含 Cargo、Go 等工具自行下载的依赖。

失败目标与最近诊断分区显示。诊断可能来自可选探测，不能单凭出现 `error` 判断整个构建失败；最终结果以 Make 退出码为准。`--plain` 可切换为普通输出，`--log` 可指定日志路径。

## 断点续建

在同一终端重复原构建命令即可续建。新终端应先加载工具环境、设置目标参数，并在 Linux 上重新设置两个 Mac 输入变量及所需的 `packages` 列表。

构建复用已有源码、编译缓存和完成标记；打包阶段可能再次执行。保留 `build_work`、`build_stage`、`build_base` 等构建目录，不要通过清理全仓解决单包错误。

修改已完成配方的源码或编译参数后，需要显式重建该配方，例如：

```bash
make rebuild-xcb-util-xrm-package
```

`rebuild-*` 用于主动重建，不是普通续建命令。切换目标或宿主时，不要混用宿主工具与编译缓存。

## 输出与 Bootstrap

| 目录 | 内容 |
| --- | --- |
| `build_dist/<目标>/<CF版本>/<配方>/` | Debian 软件包 |
| `build_stage/<目标>/<CF版本>/` | 各配方的安装暂存文件 |
| `build_base/<目标>/<CF版本>/` | 供其他配方使用的目标依赖 |
| `build_work/<目标>/<CF版本>/` | 源码、编译目录和完成标记 |
| `build_strap/<目标>/<CF版本>/` | Bootstrap 及其组装材料 |

Bootstrap 使用原有入口和 Makefile 中的成员列表，无需先完成全仓构建：

```bash
make bootstrap
```

RootHide 默认源地址为 `https://procursus.owngoal.dev`，可通过 `MEMO_REPO_URI` 指定。`BOOTSTRAP_APT_KEYRING` 用于导入源公钥，`MEMO_PGP_SIGN_KEY` 用于 Bootstrap 归档的分离签名；两者用途不同。生成软件包或 Bootstrap 不会自动发布软件源。

## 配方维护

配方位于 `makefiles/`，Debian 元数据位于 `build_info/`，源码补丁位于 `build_patch/`。修改依赖或配置时，应先核对上游实现，将修复写回配方或补丁，而不是修改已经生成的 Debian 包。

新增或更新配方时显式声明构建依赖，保留 RootHide 语义及已有较新版本，并验证实际受影响的构建与打包步骤。
