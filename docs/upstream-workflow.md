# 上游工作流与本分支边界

本文记录上游原用法，作为维护和审查的参照，不要求本分支永久保持所有上游约定。OwnGoal Stripe 是专门服务 Relaxin 的分支，不承担通用 RootHide 发行版的支持承诺。最后核对：2026-10-27。

## 对照版本与原则

- RootHide 基线：[Procursus-roothide `0bd8c14f`](https://github.com/roothide/Procursus-roothide/tree/0bd8c14fab70c67c7500ac8a7a08fb74da4687a0)。
- 普通 Procursus 对照：[`b6185221`](https://github.com/ProcursusTeam/Procursus/tree/b6185221bf1ce3dda8b4baeee61e75e3f7c7d399)（版本号以本仓库 `procursus/main` 冻结引用为准）。
- 代码中的实际目标和路径优先于过时 Wiki。上述版本的无参数 `make` 显示帮助；全量打包明确执行 `make package`。
- RootHide 的 `iphoneos-arm64e` 是 Debian 包架构标识，不代表包内 Mach-O 必须具有 arm64e slice。普通 Procursus 包不能直接替代 RootHide 包。
- 升级以普通 Procursus main 的方法为对照，保留 RootHide 语义以及 RootHide 已有的较新版本，不做降级。
- 新的需求可以改变约定；要区分明确产品决策、必要构建适配和无意破坏。变更及验证边界登记于[风险台账](workflow-risk-register.md)。

OwnGoal Stripe 交付两个 RootHide 目标：

| `MEMO_TARGET` | 平台 | Debian 架构 | Mach-O 架构 |
| --- | --- | --- | --- |
| `iphoneos-arm64-roothide` | iOS | `iphoneos-arm64e` | arm64 |
| `appletvos-arm64-roothide` | tvOS | `appletvos-arm64e` | arm64 |

`appletvos-arm64e` 是 tvOS 目标的别名。Debian 架构名里的 `arm64e` 是 RootHide 的包架构语义，与 Mach-O slice 无关。仓库还保留 `iphoneos-arm64e-roothide` 目标；它的 `MEMO_ARCH` 是 arm64e，编译目标确实选择 arm64e，这与 Debian 架构名是两回事。保留旧目标代码不等于新增支持承诺。

## 1. 准备宿主

原设计由使用者先安装宿主工具和 SDK，再调用主 Makefile；不是先启动一个统一的容器或发布编排程序。

macOS 是普通 Procursus 主要构建宿主，使用完整 Xcode 和 GNU 工具。原 Makefile 优先使用 `/opt/procursus/bin`、`/opt/procursus/libexec/gnubin`，然后 `/usr/bin` 和调用者 PATH。不能把 GNU 工具无条件放到 BSD 工具后面。iOS 宿主原来优先使用 `/usr/bin`。

Linux 使用 Darwin 交叉工具链（例如 cctools-port）、签名工具和 Apple SDK。RootHide 上游已经有 `config-on-linux.sh`，其实现依赖 HOME 下的 Theos/toolchain 和 cctools 路径；它不代表所有包都能在任意干净 Linux 上无需额外输入地构建。上游也没有要求使用 Docker。

常用参数来自主 Makefile：

| 参数 | 用途 |
| --- | --- |
| `MEMO_TARGET` | 目标平台，例如 `iphoneos-arm64-roothide` |
| `MEMO_CFVER` | 最低目标系统对应的 CoreFoundation 版本，iOS 16 使用 `1900` |
| `TARGET_SYSROOT` | 目标 SDK |
| `MACOSX_SYSROOT` | macOS SDK，用于有关宿主/交叉构建步骤 |
| `BUILD_ROOT` | 构建根目录；不是发布站点目录 |
| `CORE_COUNT` | 构建并发参数 |

本分支的 `build_tools/prepare_native_tools.sh`、固定宿主工具版本和生成的 `host-env.sh` 是后续扩展，不能当作上游原有接口。本分支将上游的根目录 `config-on-linux.sh` 移为 `build_tools/prepare_linux_host.sh`，统一放在构建辅助工具目录。准备脚本的存在不应破坏已经备好工具链的普通 make 用法。

已逐一核对的工具职责：

| 工具 | 普通 Procursus main | RootHide main | 实际职责 |
| --- | --- | --- | --- |
| `config-on-linux.sh` | 无 | 有 | Linux 宿主工具链和 SDK 准备 |
| `build_tools/prepare_native_tools.sh` | 无 | 无 | 本分支新增：宿主依赖、patched ldid/symredirect、语言引导工具 |
| `setup_base.sh` | 有 | 有 | 从现有 Deb 填充目标 build_base，必要时调用源码构建；不是安装宿主依赖 |
| `prosdk.sh` | 有 | 有 | 处理 Deb/SDK 开发材料；不是宿主自动准备替代品 |
| `compile*.sh` | 有 | 有 | 多目标逐包重建辅助，不是宿主安装器 |

当前处理选择：保留既有 Linux 入口与公共宿主准备脚本，不增加第三个入口。Linux 脚本负责 Darwin 交叉工具链/SDK/目标运行时，公共脚本负责本机工具；两份 Linux 系统依赖清单仍需去重。HOST_TOOL_ROOT 默认位置不变，现在也可指定 checkout 外的专用目录。不是每次 make 都重新运行准备脚本。

使用自行准备的 Linux 工具时，LLVM 的 `LLVM_BOOTSTRAP_SWIFTC`、shshd 的 `SWIFTC` 可以显式指定；未设置 HOST_TOOL_ROOT 时默认从 PATH 选择 swiftc。资源目录查询选中的编译器，不再拼接固定安装路径。LLVM 的 `LLVM_RT_MACOS_SYSROOT` 可以显式覆盖，默认优先保留准备目录内的完整 MacOSX.sdk，否则使用 MACOSX_SYSROOT。仍需提供与源码兼容的引导 Swift、Darwin SDK 和所需 apinotes；这不是允许任意版本互换的承诺。

来源：[macOS/iOS 指南](https://github.com/ProcursusTeam/Procursus/wiki/Building-on-iOS-and-macOS)、[Linux 指南](https://github.com/ProcursusTeam/Procursus/wiki/Building-on-Linux)、[RootHide Makefile](https://github.com/roothide/Procursus-roothide/blob/0bd8c14fab70c67c7500ac8a7a08fb74da4687a0/Makefile)。

## 2. 构建软件包

在已经具备所需工具和 SDK 的 shell 中使用 GNU make；若系统 `make` 不是合适的 GNU make，使用安装后的 `gmake`。

```sh
umask 022
# 编译单个配方及其构建依赖
make MEMO_TARGET=iphoneos-arm64-roothide MEMO_CFVER=1900 bash
# 编译并打包
make MEMO_TARGET=iphoneos-arm64-roothide MEMO_CFVER=1900 bash-package
# 当前目标的全部适用配方，不是所有平台的排列组合
make MEMO_TARGET=iphoneos-arm64-roothide MEMO_CFVER=1900 package
```

`makefiles/*.mk` 注册 `SUBPROJECTS` 和 `STRAPPROJECTS`，主 Makefile 把它们接入构建图。包配方负责下载、补丁、编译和拆包；公共 `AFTER_BUILD`、`SIGN`、`PACK` 负责后处理、代码签名和 Deb 打包；`build_info` 提供控制文件及维护脚本。

普通包的 Deb 输出位于：

```text
build_dist/<MEMO_TARGET>/<MEMO_CFVER>/<配方>/*.deb
```

`BUILD_DIST` 内部指向该目标目录下的 `work/`，PACK 把最终 Deb 写入相邻的配方子目录。`build_source` 存下载材料，`build_work` 存源码和中间构建，`build_stage` 存暂存安装树，`build_base` 存供其他配方使用的目标开发文件。

RootHide 上游还已有 `source-repo` 固定源码覆盖、`source-temp` 解包副本及 `pack-cache` 打包树缓存；它们不是新的发布系统，也不能代替正式配方的修复。

`build_tools/compile.sh` 原本只是调用 macOS/iPhoneOS 多目标辅助脚本，内部使用 `rebuild-*`。它不是一键干净构建或断点恢复入口，也不自动选择 OwnGoal Stripe 目标。

## 3. 续建和有意重建

同一套源码、目标和构建输入下，再次运行原 make 命令。已完成配方通常通过 `.build_complete` 跳过编译；未完成构建可能继续利用 Make/Ninja/Cargo 等底层缓存。

这不是内容寻址缓存：修改版本、补丁、工具链、SDK 或外部输入后，不能假定旧完成标记会自动失效。需要重建的包明确使用：

```sh
make MEMO_TARGET=iphoneos-arm64-roothide MEMO_CFVER=1900 rebuild-bash-package
```

该目标删除对应配方的 work/stage 后重新执行。`clean`、`extreme-clean` 不用于普通续建；运行前以当前 Makefile 的实际删除范围为准，不照抄旧帮助文本。也不要以“为了构建成功”为理由取消所有已完成包的短路判断。

## 4. 独立构建 Bootstrap

```sh
make MEMO_TARGET=iphoneos-arm64-roothide MEMO_CFVER=1900 bootstrap
# 原有 SSH 开关
make MEMO_TARGET=iphoneos-arm64-roothide MEMO_CFVER=1900 SSH_STRAP=1 bootstrap
```

主 Makefile 的 `bootstrap` 依赖 `strapprojects`。后者构建 `STRAPPROJECTS` 的包，Bootstrap 逻辑再按 Makefile 内的二进制成员名单解包、组织 dpkg 状态和初始化文件，最终生成 tar.zst。它不要求先执行全量 `package`。

Bootstrap 使用 `build_strap/<目标>/<CF版本>/` 下的工作区和包文件；这与普通 `build_dist` 输出的区别是原有设计。复用编译完成标记不等于任意历史 Deb 都会自动成为 Bootstrap 输入。

上游文件名为 `bootstrap.tar.zst` 或 `bootstrap-ssh.tar.zst`，并使用其配置的 GPG 身份生成归档签名。本分支按上游结构使用 `bootstrap-<DEB_ARCH>.tar.zst` 和 `bootstrap-ssh-<DEB_ARCH>.tar.zst`，本地放在 `build_strap/<目标>/<CF版本>/`，发布到 `/bootstraps/<CF版本>/`。iOS 对应 `bootstrap-iphoneos-arm64e.tar.zst`，tvOS 对应 `bootstrap-appletvos-arm64e.tar.zst`。

## 5. 生成软件源与发布

构建仓库产出 Deb 和 Bootstrap；APT 软件源元数据和托管属于外部发布环节。构建仓库原先没有 `build_repo/`、时间戳快照层级或统一 `repository` 目标；现在只提供本地 `repository` 目标，不包含上传或部署。

本分支采用普通 Procursus 上游的源形态：suite 为 CF 版本（本分支为 `1900`），pool 按目标和 CF 版本分目录，`dists` 下按 Deb 架构生成二进制索引。iOS 与 tvOS 共享 suite `1900`，同一份根 Release 下同时提供 `binary-iphoneos-arm64e` 和 `binary-appletvos-arm64e`；Bootstrap sources 因此保持 `Suites: $(MEMO_CFVER)`。不采用 RootHide 的 `<debarch>/<cfver>` suite、alt 拆分和 GitHub Pages 托管。

发布侧继续使用成熟的 Debian 工具：[update_repo.sh](https://github.com/roothide/roothide.github.io/blob/main/procursus/update_repo.sh) 展示了 `apt-ftparchive packages`、`contents`、`release` 以及 xz/zstd 压缩和 GPG 签名的具体用法，可作为命令参考。其 pool 布局、alt 处理和静态托管方式不属于本分支决策。

本仓库现在提供本地归档入口：`python3 build_tools/publish_repo.py` 与 `make repository`。它把 iOS 构建输出增量复制到 `build_repo/`，生成并签名 `dists/1900`，再验证 Release、keyring、Bootstrap 和本地 `apt-get`。该入口不上传、不部署；tvOS 暂缓。

Mach-O 代码签名、Bootstrap 归档签名、APT Release 签名是不同环节。APT 公钥进入设备的方式和 keyring 包升级路径也需要单独闭合；仅打包出 Deb 不代表软件源发布已验收。

## 6. 本分支已明确的偏离与待定项

| 项目 | 决策 |
| --- | --- |
| 项目名称 | `OwnGoal Stripe`。文档、README 和终端展示使用新名称；`procursus-keyring`、`procursus.sources`、`.procursus_strapped`、`owngoal-procursus.gpg` 和内部 `PROCURSUS` 守卫保留原名以兼容 Relaxin 与现有 Bootstrap |
| 支持平台 | `iphoneos-arm64-roothide`（Debian 架构 `iphoneos-arm64e`）与 `appletvos-arm64-roothide`（`appletvos-arm64e`）；二者 Mach-O 架构均为 arm64 |
| 源地址 | `https://stripe.owngoal.dev`；正式发布筹备中 |
| alt 拆分 | 不采用。发布侧只保留一个主源，不复制 LLVM 到 alt-repo，也不从主 pool 删除 LLVM |
| 源布局 | 采用普通 Procursus 上游形态：suite 为 CF 版本，pool 按目标和 CF 版本分目录，dists 按 Deb 架构生成索引；iOS 与 tvOS 共享 suite `1900`，不采用 RootHide 的 `<debarch>/<cfver>` suite |
| Bootstrap 归档 | 使用 `bootstrap-<DEB_ARCH>.tar.zst` / `bootstrap-ssh-<DEB_ARCH>.tar.zst`；iOS 发布到 `/bootstraps/<CF版本>/`，tvOS 发布到 `/bootstraps/<DEB_ARCH>/<CF版本>/` |
| 发布工具 | 复用 apt-ftparchive、GPG、xz、zstd；入口为 `build_tools/publish_repo.py` / `make repository`，不自行生成 Debian 索引，不引入时间戳快照机制 |
| 发布承载 | 自有 HTTPS 静态托管；不使用 GitHub Release、Pages 或 Actions。构建仓库只提供本地归档入口，不上传 |
| 本地输出目录 | `build_repo/` 是本地归档输出，已加入 `.gitignore`；不作为上传或部署接口 |
| 项目定位 | 仅服务 Relaxin；保留 RootHide 兼容性。OwnGoal 地址和 OwnGoal Stripe 默认值不因为“通用 fork”假设而撤销或缩小范围 |
| 静态库 | 交付的所有 Debian 包中，静态库成员必须是机器码对象，而非 LTO/LLVM bitcode 对象。内部构建是否使用 LTO 不属于强制要求；当前保留已用实现，不为形式统一重新构建 |

当前 HEAD 提供本地归档与验证入口，不包含上传或部署；tvOS 暂缓。发布侧接入时按本表和台账执行并验收。
