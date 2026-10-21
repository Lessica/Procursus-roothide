# 在 Mac 上准备材料，在 Linux 容器中构建

这份记录跟随本次手工构建逐步补齐。面向能够使用终端、但不熟悉本仓库构建细节的使用者。只记录已经走到的步骤；尚未完成的步骤会明确注明，不代表已经验证通过。

## 本次要做什么

使用 Mac 上的 OrbStack 运行 Ubuntu 24.04 容器，在容器里测试大部分软件包的干净构建。需要 Xcode 的材料先在 Mac 上准备，再传入容器。

本次暂不构建 LLVM/Swift、Rust、GHC、OpenJDK 和 cctools，以缩短测试时间。ElleKit 保留，由 Mac 构建。SwiftLint 属于 macOS 目标，不在这次 iPhoneOS 目标的构建范围内。

以下路径、容器名称和 Xcode 版本是本次实际使用的值。换一台机器时，需要按实际安装位置调整。

## 1. 分清两个终端

**Mac 终端**用于操作 Docker、运行 Xcode 和准备待传输的材料。项目目录是：

```bash
cd ~/Codelab/Procursus-roothide-integration
```

**容器终端**用于准备 Linux 环境和运行 Linux 构建。当前容器名为 `procursus-linux-rebuild-20261021-2`，项目位于 `/work`。

本次已经创建好容器，并放入了仓库中受 Git 跟踪的源码，没有带入旧构建缓存。它没有挂载 Mac 项目目录：两边的文件是独立副本，修改 Mac 文件不会自动更新容器。

需要重新进入现有容器时，在 **Mac 终端**执行：

```bash
docker exec -it procursus-linux-rebuild-20261021-2 bash
cd /work
```

在容器终端执行 `exit` 会退出这个终端，不会删除容器。不要为了重新进入而另建容器，否则现有准备结果不会自动转移过去。

## 2. 准备 Linux 环境（已完成）

在 **容器终端**的 `/work` 中执行：

```bash
./build_tools/prepare_linux_host.sh
```

脚本可以直接执行，不必在前面加 `bash`。它会安装 Ubuntu 软件包，并下载、准备交叉编译工具、SDK 和必要的宿主工具。看到大量依赖安装以及下载、编译日志是正常的；此时还没有开始构建本项目的软件包。

等命令成功结束后，执行：

```bash
source /work/build_work/host-tools/host-env.sh
```

这条命令让当前终端使用准备好的工具和 SDK。以后新开一个容器终端，也需要重新执行它；不需要因此重新安装整套环境。

## 3. 选定 Mac 上的 Xcode 和已有工具（已完成）

本次 Mac 不是干净环境。检查后确认已有工具可以继续使用，因此没有重新执行整套 Mac 准备。

在 **Mac 终端**的项目目录执行：

```bash
export DEVELOPER_DIR=/Applications/Xcode-16.2.0.app/Contents/Developer
source build_work/host-tools/host-env.sh
```

这里使用 Xcode 16.2，与已有环境中的 iPhoneOS 18.2 和 macOS 15.2 SDK 对应。`DEVELOPER_DIR` 只影响当前终端，不会修改系统全局选择的 Xcode。

如果以后换了新终端，需要重新执行这两条。如果是全新 Mac、还没有 `host-env.sh`，不要直接跳过准备；本记录尚未覆盖全新 Mac 的安装过程。

## 4. 构建并导出 libroothide（已完成）

仍在 **Mac 终端**的项目目录执行：

```bash
make MEMO_TARGET=iphoneos-arm64-roothide MEMO_CFVER=1900 CORE_COUNT=10 roothide-xcode-export
```

这些参数后续会继续使用：

- `MEMO_TARGET=iphoneos-arm64-roothide`：选择本次 Relaxin 使用的 RootHide 目标。
- `MEMO_CFVER=1900`：选择对应的构建版本目录；Mac 和 Linux 两边保持一致。
- `CORE_COUNT=10`：使用 10 路构建并发。
- `roothide-xcode-export`：从源码构建 libroothide，并导出供 Linux 使用的材料。

成功后生成：

```text
build_work/iphoneos-arm64-roothide/1900/libroothide-xcode.tar
```

## 5. 构建 ElleKit（已完成）

上一步成功后，在 **Mac 终端**执行：

```bash
make MEMO_TARGET=iphoneos-arm64-roothide MEMO_CFVER=1900 CORE_COUNT=10 rebuild-ellekit-package
```

本次使用 `rebuild-ellekit-package`，是因为 Mac 上已有 ElleKit 的旧构建记录，需要亲自走一遍源码构建。这个目标会清理并重建 ElleKit，不是普通断点续建命令，后续不应反复执行它。

成功后的 Debian 包位于：

```text
build_dist/iphoneos-arm64-roothide/1900/ellekit/
```

## 6. 收集 Mac 的 locale 数据（已完成）

在 **Mac 终端**执行：

```bash
tar -cf build_work/mac-locale.tar -C /usr/share locale
```

这一步只是把 Mac 已有的 locale 数据打包，不会编译或修改系统文件。Linux 构建中的 `gettext-localizations` 需要这份输入。

## 7. 将材料复制到 Linux 容器（已完成）

以下命令全部在 **Mac 终端**的项目目录运行。`docker cp` 会直接复制到 OrbStack 的容器，不需要配置 SSH。

先建立接收目录，并同步当前 Makefile：

```bash
docker exec procursus-linux-rebuild-20261021-2 mkdir -p /work/build_work/iphoneos-arm64-roothide/1900 /work/build_dist/iphoneos-arm64-roothide/1900
docker cp Makefile procursus-linux-rebuild-20261021-2:/work/Makefile
```

再复制 libroothide、locale 和 ElleKit 的 Debian 包目录：

```bash
docker cp build_work/iphoneos-arm64-roothide/1900/libroothide-xcode.tar procursus-linux-rebuild-20261021-2:/work/build_work/iphoneos-arm64-roothide/1900/libroothide-xcode.tar
docker cp build_work/mac-locale.tar procursus-linux-rebuild-20261021-2:/work/build_work/mac-locale.tar
docker cp build_dist/iphoneos-arm64-roothide/1900/ellekit procursus-linux-rebuild-20261021-2:/work/build_dist/iphoneos-arm64-roothide/1900/
```

这些命令只复制材料，不启动编译，也不会将 iOS 软件包安装到 Ubuntu。不要复制 Mac 的整个 `build_work`，其中的宿主工具不能直接拿到 Linux 使用。

## 8. 配置容器输入，复用 ElleKit（已完成）

回到 **容器终端**。如果已退出，在 Mac 终端用第 1 步的 `docker exec` 命令重新进入。

先进入项目目录，加载工具环境，设置本次构建参数：

```bash
cd /work
source build_work/host-tools/host-env.sh
export MEMO_TARGET=iphoneos-arm64-roothide
export MEMO_CFVER=1900
export CORE_COUNT=10
export ROOTHIDE_XCODE_INPUT=/work/build_work/iphoneos-arm64-roothide/1900/libroothide-xcode.tar
export GETTEXT_LOCALIZATIONS_INPUT=/work/build_work/locale
```

这些 `export` 只对当前终端及其启动的构建生效；以后新开终端续建时，需要重新执行这一组。

解开 locale 数据，检查所需文件，并让现有配方检查 libroothide 输入：

```bash
tar -xf build_work/mac-locale.tar -C build_work
test -f "$GETTEXT_LOCALIZATIONS_INPUT/en_US.UTF-8/LC_CTYPE" && test -f "$GETTEXT_LOCALIZATIONS_INPUT/en_US.UTF-8/LC_COLLATE" && echo 'locale 输入就绪'
make roothide-xcode-check
```

`roothide-xcode-check` 会核对配方身份、文件校验值和所需架构，不会重新编译 libroothide。出现错误时先处理错误，不要继续下一组。

然后把 ElleKit 包解到交叉构建使用的 `build_base`，成功后写入现有机制使用的完成标记：

```bash
mkdir -p build_base/iphoneos-arm64-roothide/1900
dpkg-deb -x build_dist/iphoneos-arm64-roothide/1900/ellekit/ellekit_0.1+git20221221.5fe185d_iphoneos-arm64e.deb build_base/iphoneos-arm64-roothide/1900 && mkdir -p build_work/iphoneos-arm64-roothide/1900/ellekit && touch build_work/iphoneos-arm64-roothide/1900/ellekit/.build_complete
make ellekit
```

`dpkg-deb -x` 只解包，不会在 Ubuntu 中安装或执行这个 iOS 包。最后的 `make ellekit` 应输出 `Using previously built ellekit.`，确认不会调用 Xcode。完成标记必须在解包成功后建立，所以这里用 `&&` 连接。

原始 Debian 包保留在 `build_dist`，作为最终输出的一部分。后续批量构建需跳过 `ellekit-package`，因为它已经在 Mac 打包完成；这里没有复制供重新打包使用的 `build_stage`。不要在容器中运行 `rebuild-ellekit` 或 `rebuild-ellekit-package`。

## 9. 启动本次批量构建

继续使用第 8 步配置好的 **容器终端**，当前目录为 `/work`。

先从 Makefile 取得当前目标实际启用的配方列表，排除本次不构建的大包，以及已经在 Mac 打包的 ElleKit：

```bash
packages=$(make MEMO_QUIET=1 print-SUBPROJECTS | tr ' ' '\n' | grep -Ev '^(llvm|rust|ghc|openjdk|cctools|ellekit)$' | sort -u | xargs)
```

当前结果为 617 个配方，不是 617 个 Debian 包；一个配方可能输出多个包。Swift 随 LLVM 配方一起排除。ElleKit 的成品包仍然保留在输出目录，只是不再执行它的打包目标。

使用原有 `package` 入口启动构建，并把终端输出保存到日志：

```bash
set -o pipefail
make --output-sync=target package SUBPROJECTS="$packages" 2>&1 | tee -a build_work/linux-build.log
```

这里用 `SUBPROJECTS` 指定本次范围，没有修改配方或新建构建入口。依赖仍由 Makefile 处理。`CORE_COUNT=10` 沿用前面的设置；准备阶段已经安装的 Rust、Swift 等宿主工具仍可被普通包使用，排除的是这些工具链本身的目标软件包构建。

`--output-sync=target` 按目标归组输出，避免并行任务的日志相互穿插；目标执行期间可能暂时没有新输出。日志追加到 `build_work/linux-build.log`。保持终端打开。出现 `Error` 并返回提示符时，先检查具体错误；有并行任务时，报错后可能还会等待其他任务退出。

输出的 Debian 包位于：

```text
build_dist/iphoneos-arm64-roothide/1900/<配方名称>/
```

## 中断后继续

如果仍在同一终端，处理错误后重新执行上面的 `make package` 命令即可。如果换了终端，先重新执行第 8 步的环境加载和 `export` 命令，再重新生成 `packages` 并启动构建；不需要重新解包已导入的材料。

普通构建目标会复用已有完成标记和构建缓存。部分打包步骤仍可能再次执行，这不是从零重建。不要运行 `clean`、`extreme-clean` 或 `rebuild-package`，它们会清理续建所需内容。若清理过构建目录，ElleKit 也需要重新导入。
