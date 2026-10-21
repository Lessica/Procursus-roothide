# 工作流风险台账

更新时间：2026-10-21。初始审计范围为 `roothide/main@0bd8c14f` 到 `fd9ee216c` 的最终文件差异；普通 Procursus main 作二次对照。本文按机制维护，不按构建批次堆叠历史。

上游约定可以按明确需求改变，参见[上游工作流与本分支边界](upstream-workflow.md)。状态“已修复”不代表全仓重新构建；验证范围单列。上一轮 stash 的编排不在当前实现中，也不自动恢复。

## 需要恢复的兼容性

| ID | 项目及文件 | 判断和处理 | 状态 / 验证 |
| --- | --- | --- | --- |
| W01 | Makefile：macOS/iOS PATH | 无条件把上游工具目录放在调用者 PATH 后，会让 BSD 工具抢先，影响整套构建。未选择 HOST_TOOL_ROOT 时恢复上游顺序；显式准备环境保留 host-env.sh 的 patched signer/GNU 工具顺序。命令行 PATH 覆盖仍遵循 GNU make 原语义 | 已修复。用真实 GNU make 读取修改后的条件块，分别检查 macOS/iOS、普通/显式准备环境共四种路径顺序；不是干净 macOS 全仓验收 |
| W02 | makefiles/rust.mk：完成后跳过 | 删除 .build_complete 判断会使已完成 Rust 再进入 setup、x.py build/install。恢复原判断；未完成的构建继续使用底层缓存 | 已修复。临时目录中分别检查有/无完成标记的 make dry-run：完成时仅提示复用；未完成时仍有依赖、build/install。未运行 Rust 编译 |
| W03 | Makefile：Bootstrap 输出命名 | 专用 BOOTSTRAP_NAME 覆盖原 SSH 分流，导致两种归档同名。保留既有 Relaxin 非 SSH 名称 bootstrap_1900.tar.zst，SSH 改为 bootstrap-ssh_1900.tar.zst；显式 BOOTSTRAP_NAME 覆盖保留 | 已修复。GNU make 检查两种默认值和显式覆盖；未重打 Bootstrap |
| W04 | CONTRIBUTING.md / README.md：文档职责 | CONTRIBUTING恢复上游贡献指南；README移除Bender限制、阶段性发布声明和审计状态链接。构建过程中的问题及验收边界只在台账维护，不向面向用户/贡献者的文档逐轮追加 | 已修复。CONTRIBUTING与roothide/main逐字节一致；README相关内容已移除 |

## 已澄清决策及后续收敛

| ID | 项目及文件 | 建议处理 | 状态 |
| --- | --- | --- | --- |
| W05 | Makefile：Relaxin 默认值范围 | 用户明确本项目只服务 Relaxin；撤回基于“通用RootHide发行版”假设的缩小范围建议。实际只继承两个iPhoneOS RootHide编译目标。保留OwnGoal地址、默认签名策略和专用名称 | 已决策，保留；SSH命名冲突由W03修复 |
| W06 | build_tools/prepare_linux_host.sh / build_tools/prepare_native_tools.sh：准备职责与目录 | 保留Linux交叉准备与公共本机工具分工及既有入口/参数。64项公共Linux依赖集中于build_misc/host-tools/linux-packages.txt；Linux入口只补22项特有依赖，不再重复维护公共清单。SDK路径由Linux入口传入，host-env.sh由公共脚本单独生成并原子替换；调用公共脚本时固定HOST_PLATFORM=linux。保留外部专用工具目录和原缓存/构建顺序 | 去重已完成。原Linux入口85项依赖无删减，显式补齐公共脚本已要求的perl；macOS/iOS依赖不变。已检查依赖打印、deps-only/skip分支、重复执行、SDK导出及中断写入保留旧环境；未实际安装或构建 |
| W07 | makefiles/llvm.mk、shshd.mk：固定 Swift/SDK 路径 | 现有编译器变量支持显式覆盖；未指定准备根时从PATH选择swiftc，资源查询实际编译器。LLVM完整macOS SDK可覆盖，默认保留现有准备输入，否则使用MACOSX_SYSROOT。shshd仍要求选中资源中有apinotes | 已修复选择逻辑。GNU make检查准备/手工/覆盖三种情形，并执行实际资源链接命令配合模拟编译器元数据；未运行LLVM/shshd编译，也未宣称任意Swift版本可用 |
| W08 | build_misc/llvm/ProcursusNativeArchives.cmake、LLVM/Swift补丁和配方 | 用户只要求最终Deb所带静态库必须是机器码，内部是否LTO由实现决定。当前选择保留已用克隆机制，不为删代码重编LLVM。源码走读确认机制在原配方内部，无额外用户构建入口；后续专项审查仍需覆盖生成源、对象库依赖、编译选项、安装覆盖及最终归档成员 | 不再等待用户选择。保留当前实现；源码走读不作为全量静态库产物验收，本轮没有重做该验收 |

## 保留明确需求，补齐交付边界

| ID | 项目及文件 | 处理结论及下一步 | 状态 |
| --- | --- | --- | --- |
| W09 | makefiles/roothide.mk：Xcode导出/导入 | Linux 无法提供所需 Xcode ABI 能力时，允许 Mac 从源码构建再导入是已确认需求。保留现有可选入口、校验和正常 stage/sign/pack；不要为了回到上游而删除这个能力 | 保留。完成标记不会自动响应替换输入，仍需按原 rebuild 规则失效；无新的归档协议或统一导入框架 |
| W10 | makefiles/gettext-localizations.mk：Mac locale 输入 | 保留显式 GETTEXT_LOCALIZATIONS_INPUT。直接复制 Mac 数据符合上游方式；许可和固化入库尚未决定 | 保留，不开发 Linux locale 生成器 |
| W11 | makefiles/ellekit.mk：Mac构建边界 | 当前 HEAD 仍为 Xcode 配方；Linux 导入方案在 stash 中。恢复前先确定最小接入位置，使用现有配方和打包步骤，不能把缓存 Deb 的手工搬运写成已完备流程 | 开放。当前不能宣称干净 Linux 全仓自动完成 |
| W12 | Makefile Bootstrap keyring；makefiles/keyring.mk | 目前额外复制公钥但 keyring Deb 不管理它。正式发布前统一公钥来源、Deb归属和升级方式；继续复用 keyring 配方，签名参数不自动生成正式私钥。修复后只重打相关包/Bootstrap，不重编全仓 | 开放，尚未改动密钥或产物 |
| W13 | Bootstrap sources 与外部发布脚本 | URI、suite、component、architecture 必须配套。当前 sources 的 1900 不能直接对应 RootHide脚本的 iphoneos-arm64e/1900。按最终选定布局统一二者，再用 apt-ftparchive 和客户端验收 | 开放，不预先新增输出目录或发布目标 |
| W14 | build_misc/prep_bootstrap.sh：RELAXIN_* 环境接口 | 本fork只服务Relaxin，因此专用命名本身不是偏离目的的风险。密码和本地化是明确需求，保留；后续只检查实际调用兼容性，不为通用化新增一套接口 | 已决策保留，未改设密行为 |
| W15 | libkrw-dopamine.mk、libkrw-relaxin.mk、source-repo provider | 按明确决定，Relaxin provider需显式选择，不进入通用 SUBPROJECTS/STRAPPROJECTS。这是有意的全量集合边界，不是遗漏注册 | 决策明确，保持现状 |
| W16 | jtool2.mk：闭源二进制输入 | 原配方本来就是二进制重打包；固定版本、校验后执行 RootHide处理，不能宣传成从源码重建，也不能把普通Deb整体直接替换进去 | 保留明确例外；不在本轮更换输入或重打包 |
| W17 | Makefile AFTER_BUILD/SIGN/PACK；通用 entitlements | 错误传播、硬链接、Mach-O类型、conffiles等修复保留；延后完成标记和framework签名钩子仍需与实际调用一起审查。通用权限变更影响所有使用该模板的包，不能与新编排混为一谈 | 不回退已有修复；本轮没有重新做全仓产物验证，也不据此关闭后续针对性审查 |

## 发布决策

| ID | 决策 | 后续动作与验收边界 | 状态 |
| --- | --- | --- | --- |
| P01 | 不拆 alt | 后续复用外部 update_repo.sh 时，删除将 LLVM 复制到 alt-repo 并从主 pool 删除的代码；全部工具链在主源。不能只是关闭 alt 站点 | 已决定，待发布脚本实际接入时实施；当前 HEAD 没有该脚本 |
| P02 | 不绑定 GitHub Release / Pages / Actions | 上游托管方式只作事实记录。本分支可使用其他 HTTP托管和执行环境；复用 apt-ftparchive、GPG及标准pool/dists即可 | 平台待定，不为此先增加 CI、Docker或部署入口 |
| P03 | 临时副本与暂存编排 | build_repo 已移除；上一轮未接收的编排留在 stash。不得把其存在当作正式发布约定 | 已处理，无需恢复副本 |

## 验证边界

宿主准备去重采用命令拦截检查，没有执行APT安装、网络下载或软件包构建：

- 三个平台的公共准备依赖输出与去重前一致；Linux完整准备覆盖原清单与公共清单的并集，无重复项。
- `--deps-only` 及重复调用正常结束；`--skip-system-deps` 不调用APT。缓存目录中的既有文件内容和时间戳保留。
- 执行实际环境写出代码，验证包含空格的SDK路径可往返读取、重复生成不重复追加变量；中途失败不会覆盖原host-env.sh。
- 脚本语法及 `git diff --check` 通过。上述检查不等同于重新验收干净宿主准备或全量构建。

此前PATH、Rust完成标记和Swift/SDK选址的检查范围仍记录在对应条目。没有新增持久测试框架，也未清理现有产物或构建缓存。
