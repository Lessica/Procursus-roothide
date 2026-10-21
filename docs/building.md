# 开发者构建指南

Procursus (Relaxin) 使用 GNU Make 构建面向 Relaxin 的 RootHide 软件包。本文介绍宿主准备、跨宿主输入、软件包构建与断点续建；所有命令从仓库根目录执行，除非另有说明。

## 构建并发

`CORE_COUNT` 默认按当前设备的 CPU 核心数设置，无需手动指定。如需限制并发，可执行 `export CORE_COUNT=10`。

## 准备宿主

### macOS

需要完整 Xcode、Homebrew 和 Git。选择包含 iPhoneOS SDK 的 Xcode 后，安装依赖并准备宿主工具：

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
./build_tools/prepare_native_tools.sh --install-system-deps
source build_work/host-tools/host-env.sh
```

已安装系统依赖时，可省略 `--install-system-deps`。

### Linux

使用 Ubuntu 24.04，执行以下命令准备系统依赖和交叉编译环境：

```bash
./build_tools/prepare_linux_host.sh
source build_work/host-tools/host-env.sh
```

安装系统依赖需要 root 或 sudo。依赖清单位于 [linux-packages.txt](../build_misc/host-tools/linux-packages.txt)。准备入口的 `--deps-only` 只安装系统依赖；`--skip-system-deps` 用于系统依赖已就绪的环境。

每次新开终端，需要重新加载 `host-env.sh`，无需重复准备环境。

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

Linux 构建需要从 Mac 获取 libroothide、ElleKit 和 locale 数据。两台宿主应使用同一版本的仓库源码。

### 在 Mac 上生成

加载 Mac 工具环境后执行：

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

默认全量构建当前宿主和目标支持的所有配方：

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

所选配方的依赖会自动构建。Linux 上构建 LLVM 还需准备相应的 Apple SDK。

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

在同一终端重复原构建命令即可续建。新终端应先加载工具环境，并在 Linux 上重新设置两个 Mac 输入变量。如指定了构建范围，续建时使用相同的 `SUBPROJECTS` 参数。

续建会复用已有源码和编译结果，打包阶段可能再次执行。请保留 `build_work`、`build_stage`、`build_base` 等构建目录。

修改已完成配方的源码或编译参数后，需要显式重建该配方，例如：

```bash
make rebuild-xcb-util-xrm-package
```

不同宿主应使用各自的编译缓存。

## 输出与 Bootstrap

| 目录 | 内容 |
| --- | --- |
| `build_dist/<目标>/<CF版本>/<配方>/` | Debian 软件包 |
| `build_stage/<目标>/<CF版本>/` | 各配方的安装暂存文件 |
| `build_base/<目标>/<CF版本>/` | 供其他配方使用的目标依赖 |
| `build_work/<目标>/<CF版本>/` | 源码、编译目录和完成标记 |
| `build_strap/<目标>/<CF版本>/` | Bootstrap 及其组装材料 |

以下命令按 Makefile 中的成员列表构建 Bootstrap 所需软件包并生成归档，无需先完成全仓构建：

```bash
make bootstrap
```

RootHide 默认源地址为 `https://procursus.owngoal.dev`，可通过 `MEMO_REPO_URI` 指定。`BOOTSTRAP_APT_KEYRING` 用于导入源公钥，`MEMO_PGP_SIGN_KEY` 用于 Bootstrap 归档的分离签名。软件源发布需另行进行。

## 配方维护

配方位于 `makefiles/`，Debian 元数据位于 `build_info/`，源码补丁位于 `build_patch/`。更新配方时，应核对上游实现、声明构建依赖，并验证受影响软件包的构建与打包结果。
