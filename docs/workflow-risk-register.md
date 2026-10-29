# 工作流风险台账

更新时间：2026-10-27。初始审计范围为 `roothide/main@0bd8c14f` 到 `fd9ee216c` 的最终文件差异；普通 Procursus main 作二次对照。本文按机制维护，不按构建批次堆叠历史。

上游约定可以按明确需求改变，参见[上游工作流与本分支边界](upstream-workflow.md)。状态“已修复”不代表全仓重新构建；验证范围单列。上一轮 stash 的编排不在当前实现中，也不自动恢复。

## 需要恢复的兼容性

| ID | 项目及文件 | 判断和处理 | 状态 / 验证 |
| --- | --- | --- | --- |
| W01 | Makefile：macOS/iOS PATH | 无条件把上游工具目录放在调用者 PATH 后，会让 BSD 工具抢先，影响整套构建。未选择 HOST_TOOL_ROOT 时恢复上游顺序；显式准备环境保留 host-env.sh 的 patched signer/GNU 工具顺序。命令行 PATH 覆盖仍遵循 GNU make 原语义 | 已修复。用真实 GNU make 读取修改后的条件块，分别检查 macOS/iOS、普通/显式准备环境共四种路径顺序；不是干净 macOS 全仓验收 |
| W02 | makefiles/rust.mk：完成后跳过 | 删除 .build_complete 判断会使已完成 Rust 再进入 setup、x.py build/install。恢复原判断；未完成的构建继续使用底层缓存 | 已修复。临时目录中分别检查有/无完成标记的 make dry-run：完成时仅提示复用；未完成时仍有依赖、build/install。未运行 Rust 编译 |
| W03 | Makefile：Bootstrap 输出命名 | 按上游结构使用 `bootstrap-<DEB_ARCH>.tar.zst` 和 `bootstrap-ssh-<DEB_ARCH>.tar.zst`；iOS 为 `bootstrap-iphoneos-arm64e.tar.zst`，tvOS 为 `bootstrap-appletvos-arm64e.tar.zst`。显式 `BOOTSTRAP_NAME` 覆盖保留 | 已修改；iOS Bootstrap 已按新名称重打并上传 |
| W04 | CONTRIBUTING.md / README.md：文档职责 | CONTRIBUTING 和 README 按 OwnGoal Stripe 品牌重写，移除上游联系方式和链接；构建过程中的问题及验收边界只在台账维护，不向面向用户/贡献者的文档逐轮追加 | 已按品牌决策更新；不再要求与 roothide/main 逐字节一致 |

## 已澄清决策及后续收敛

| ID | 项目及文件 | 建议处理 | 状态 |
| --- | --- | --- | --- |
| W05 | Makefile：OwnGoal Stripe 默认值范围 | 用户明确本项目只服务 Relaxin；撤回基于“通用RootHide发行版”假设的缩小范围建议。实际继承 iPhoneOS 与 AppleTVOS 的 RootHide 编译目标。保留 OwnGoal 地址、默认签名策略和专用名称 | 已决策，保留；SSH命名冲突由W03修复 |
| W06 | build_tools/prepare_linux_host.sh / build_tools/prepare_native_tools.sh：准备职责与目录 | 保留Linux交叉准备与公共本机工具分工及既有入口/参数。64项公共Linux依赖集中于build_misc/host-tools/linux-packages.txt；Linux入口只补22项特有依赖，不再重复维护公共清单。SDK路径由Linux入口传入，host-env.sh由公共脚本单独生成并原子替换；调用公共脚本时固定HOST_PLATFORM=linux。保留外部专用工具目录和原缓存/构建顺序 | 去重已完成。原Linux入口85项依赖无删减，显式补齐公共脚本已要求的perl；macOS/iOS依赖不变。已检查依赖打印、deps-only/skip分支、重复执行、SDK导出及中断写入保留旧环境；未实际安装或构建 |
| W07 | makefiles/llvm.mk、shshd.mk：固定 Swift/SDK 路径 | 现有编译器变量支持显式覆盖；未指定准备根时从PATH选择swiftc，资源查询实际编译器。LLVM完整macOS SDK可覆盖，默认保留现有准备输入，否则使用MACOSX_SYSROOT。shshd仍要求选中资源中有apinotes | 已修复选择逻辑。GNU make检查准备/手工/覆盖三种情形，并执行实际资源链接命令配合模拟编译器元数据；未运行LLVM/shshd编译，也未宣称任意Swift版本可用 |
| W08 | build_misc/llvm/ProcursusNativeArchives.cmake、LLVM/Swift补丁和配方 | 用户只要求最终Deb所带静态库必须是机器码，内部是否LTO由实现决定。当前选择保留已用克隆机制，不为删代码重编LLVM。源码走读确认机制在原配方内部，无额外用户构建入口；后续专项审查仍需覆盖生成源、对象库依赖、编译选项、安装覆盖及最终归档成员 | 不再等待用户选择。保留当前实现；源码走读不作为全量静态库产物验收，本轮没有重做该验收 |

## 保留明确需求，补齐交付边界

| ID | 项目及文件 | 处理结论及下一步 | 状态 |
| --- | --- | --- | --- |
| W09 | makefiles/roothide.mk：Xcode导出/导入 | Linux 无法提供所需 Xcode ABI 能力时，允许 Mac 从源码构建再导入是已确认需求。保留现有可选入口、校验和正常 stage/sign/pack；不要为了回到上游而删除这个能力 | 保留。完成标记不会自动响应替换输入，仍需按原 rebuild 规则失效；无新的归档协议或统一导入框架 |
| W10 | makefiles/gettext-localizations.mk：Mac locale 输入 | 保留显式 GETTEXT_LOCALIZATIONS_INPUT。直接复制 Mac 数据符合上游方式；许可和固化入库尚未决定 | 保留，不开发 Linux locale 生成器 |
| W12 | Makefile Bootstrap keyring；makefiles/keyring.mk | 目前额外复制公钥但 keyring Deb 不管理它。正式发布前统一公钥来源、Deb归属和升级方式；继续复用 keyring 配方，签名参数不自动生成正式私钥。修复后只重打相关包/Bootstrap，不重编全仓 | 开放，尚未改动密钥或产物 |
| W13 | Bootstrap sources 与外部发布脚本 | 已决策采用普通 Procursus 上游布局：suite 为 CF 版本（1900），pool 按目标和 CF 版本分目录，`dists/1900` 下同时提供 `binary-iphoneos-arm64e` 与 `binary-appletvos-arm64e`；当前 sources 的 `Suites: 1900` 与该布局一致，不采用 RootHide 的 `iphoneos-arm64e/1900` suite。发布侧按此生成 pool/dists 后再做 apt-ftparchive 和客户端验收 | 已决策，未验收；本轮不新增发布脚本或输出目录 |
| W14 | build_misc/prep_bootstrap.sh：RELAXIN_* 环境接口 | 本fork只服务Relaxin，因此专用命名本身不是偏离目的的风险。密码和本地化是明确需求，保留；后续只检查实际调用兼容性，不为通用化新增一套接口 | 已决策保留，未改设密行为 |
| W15 | libkrw provider 构建归属 | libkrw-relaxin 由 Relaxin 随 BaseBin 构建；本仓移除重复配方和源码快照。软件源若收录该包，使用 Relaxin 的原始 DEB | 已明确，重复构建已移除 |
| W16 | jtool2.mk：闭源二进制输入 | 原配方本来就是二进制重打包；固定版本、校验后执行 RootHide处理，不能宣传成从源码重建，也不能把普通Deb整体直接替换进去 | 保留明确例外；不在本轮更换输入或重打包 |
| W17 | Makefile AFTER_BUILD/SIGN/PACK；通用 entitlements | 错误传播、硬链接、Mach-O类型、conffiles等修复保留；延后完成标记和framework签名钩子仍需与实际调用一起审查。通用权限变更影响所有使用该模板的包，不能与新编排混为一谈 | 不回退已有修复；本轮没有重新做全仓产物验证，也不据此关闭后续针对性审查 |
| W18 | 品牌重命名范围 | 项目名称改为 OwnGoal Stripe；README、docs、终端展示、错误提示和 keyring 包描述使用新名称。`procursus-keyring`、`procursus.sources`、`.procursus_strapped`、`owngoal-procursus.gpg` 和内部 `PROCURSUS` 守卫保留，避免 Relaxin 安装器与现有 Bootstrap 失配。preferences 按 pin 决策改名为 `owngoal-stripe.preferences` | 已决策并修改；未重打 Bootstrap 或 Debian 包 |

## 发布决策

| ID | 决策 | 后续动作与验收边界 | 状态 |
| --- | --- | --- | --- |
| P01 | 不拆 alt | 发布侧只保留一个主源：不复制 LLVM 到 alt-repo，不从主 pool 删除 LLVM，不部署 alt 站点。新增的本地归档脚本只生成主源，不包含 alt | 已决定；脚本已按此实现 |
| P02 | 不使用 GitHub Release / Pages / Actions | 采用自有 HTTPS 静态托管，源地址 `https://stripe.owngoal.dev`；复用 apt-ftparchive、GPG 及标准 pool/dists。构建仓库只提供本地归档入口，不新增 CI、Docker 或部署入口 | 已决策；域名筹备中，不作为构建阻塞 |
| P03 | 临时副本与暂存编排 | `build_repo` 作为本地输出目录重新引入，并加入 `.gitignore`；上一轮 stash 的旧编排仍不作为正式约定，新脚本独立实现 | 已处理；stash 未应用 |
| P04 | 双平台共享 suite | iOS 与 tvOS 共用 suite `1900`；`dists/1900` 下生成 `binary-iphoneos-arm64e` 与 `binary-appletvos-arm64e`，根 Release 列出两种架构；pool 按 `iphoneos-arm64-roothide` / `appletvos-arm64-roothide` 分目录。Bootstrap sources 保持 `Suites: 1900` | 已决策，未发布；发布侧负责合并两个目标的索引 |
| P05 | 双平台 Bootstrap 命名 | 使用 `bootstrap-<DEB_ARCH>.tar.zst` / `bootstrap-ssh-<DEB_ARCH>.tar.zst`；iOS 发布到 `/bootstraps/<CF版本>/`，tvOS 发布到 `/bootstraps/<DEB_ARCH>/<CF版本>/` | 已实施；iOS Bootstrap 已上传 |
| P06 | 本地 APT 归档 | 新脚本 `build_tools/publish_repo.py` 与 `make repository`：第一批 iOS；按 SHA256 增量；默认保留旧版本和外部包；同名不同内容默认报错，`--replace` 才覆盖；包集合未变时跳过索引重建；状态在 `build_work/publish-state/`；验证含 Bootstrap 和本地 `apt-get`；不上传 | 已实现；Ubuntu 24.04 容器 76 Deb 与全量构建容器 1390 Deb（临时密钥、合成 keyring/Bootstrap）通过；正式密钥和真实 Bootstrap 未完成无终端签名验收 |

## 验证边界

宿主准备去重采用命令拦截检查，没有执行APT安装、网络下载或软件包构建：

- 三个平台的公共准备依赖输出与去重前一致；Linux完整准备覆盖原清单与公共清单的并集，无重复项。
- `--deps-only` 及重复调用正常结束；`--skip-system-deps` 不调用APT。缓存目录中的既有文件内容和时间戳保留。
- 执行实际环境写出代码，验证包含空格的SDK路径可往返读取、重复生成不重复追加变量；中途失败不会覆盖原host-env.sh。
- 脚本语法及 `git diff --check` 通过。上述检查不等同于重新验收干净宿主准备或全量构建。

此前PATH、Rust完成标记和Swift/SDK选址的检查范围仍记录在对应条目。没有新增持久测试框架，也未清理现有产物或构建缓存。

本轮品牌与双平台决策的验证范围：`git diff --check` 通过，`make print-MEMO_REPO_URI` 解析为新地址；未重打 Bootstrap 或 Debian 包，现有 `build_strap` 产物仍使用旧源地址和旧 preferences 文件名。双平台的发布聚合尚未实际运行。

本地归档器的验证范围：7 个单元测试通过（增量复制、mtime/inode 不变、同名冲突、`--replace`、`--prune`、Deb822 解析、索引重建判定）；用真实 Deb、临时 GPG 密钥和合成 keyring/Bootstrap 构造的验收通过；`update --dry-run` 在真实 `build_dist` 上识别出 75 个 iOS 包；`make -n repository` 展开正确。

另在 Ubuntu 24.04 容器中用 76 个真实 Deb（含合成 `procursus-keyring`）跑通 `update`、第二次运行的索引跳过（Release/InRelease/Packages 的 inode 与 mtime 不变）以及 `verify` 的 Release、Packages、keyring、Bootstrap 和本地 `apt-get update`/`download`。在已全量构建的 `procursus-final-06` 容器上，用 1390 个最终 Deb、临时密钥、合成 keyring 和 70 成员合成 Bootstrap 跑通首次归档、索引生成与签名，以及第二次 `make repository` 的索引跳过和完整 `verify`（`hello=2.10` 下载通过）。真实发布密钥带口令，无终端环境无法完成签名；正式验收需先解锁 GPG agent，或改用无口令的发布密钥。真实 keyring 包和正式 Bootstrap 也尚未验收。
