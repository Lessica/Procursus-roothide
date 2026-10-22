# macOS 开发者构建指南

本文介绍在 macOS 上构建 Procursus (Relaxin) 软件包和断点续建。所有命令均从仓库根目录执行。

## 环境准备

需要已完成许可确认和首次启动设置的完整 Xcode 16，以及 Homebrew。Xcode 应包含 macOS、iOS、tvOS 和 watchOS 的设备及模拟器 SDK；仅安装 Command Line Tools 不足以构建全部配方。

选择 Xcode 后，执行宿主准备入口：

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
./build_tools/prepare_macos_host.sh
source build_work/host-tools/host-env.sh
```

准备入口安装 Homebrew 依赖，并通过 `prepare_native_tools.sh` 准备宿主工具和引导编译器。已安装系统依赖时，可使用 `--skip-system-deps`。SDK 和 locale 直接使用本机安装的内容，无需从其他宿主导入。

每次新开终端，重新加载 `host-env.sh` 即可。`CORE_COUNT` 默认按 CPU 核心数设置，可按机器资源调整，例如 `export CORE_COUNT=10`。

## 构建软件包

默认全量构建：

```bash
make package
```

构建单个配方及其依赖，或指定多个配方：

```bash
make xz-package
make package SUBPROJECTS="xz zstd"
```

终端状态界面使用相同的 Make 构建流程：

```bash
python3 build_tools/build_status.py package
```

完整日志保存在 `build_work/build-ui.log`。也可使用普通日志：

```bash
set -o pipefail
make --output-sync=target package 2>&1 | tee -a build_work/macos-build.log
```

## 续建与输出

重复原构建命令即可续建。保留 `build_source`、`build_work`、`build_stage`、`build_base` 和 `build_dist`；已完成的编译结果会复用，打包阶段可能再次执行。

修改已完成配方的源码或编译参数后，显式重建该配方：

```bash
make rebuild-xz-package
```

Debian 软件包输出到 `build_dist/iphoneos-arm64-roothide/1900/<配方>/`。不同宿主使用各自的编译缓存。
