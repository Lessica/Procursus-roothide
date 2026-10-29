# 双平台软件源维护

分别使用 iOS、tvOS 构建容器维护各自的源码和构建结果；归档容器只接收产物，不运行编译。

## 共享交付目录

在 Docker 宿主上创建：

```bash
mkdir -p "$HOME/procursus-delivery"/{ios,tvos}
```

创建容器时增加以下挂载，源码、SDK 和编译缓存不共享：

| 容器 | 挂载参数 |
| --- | --- |
| iOS 构建 | `--mount type=bind,src="$HOME/procursus-delivery/ios",dst=/delivery` |
| tvOS 构建 | `--mount type=bind,src="$HOME/procursus-delivery/tvos",dst=/delivery` |
| 软件源归档 | `--mount type=bind,src="$HOME/procursus-delivery",dst=/delivery,readonly` |

已有容器不能原地增加挂载。先停止并用 `docker commit` 保存状态，再从该镜像创建带挂载的新容器；核对原有工作目录、环境变量和端口，验证产物及缓存后再删除原容器。

归档容器使用 Ubuntu 24.04，安装工具并导入本仓源码：

```bash
apt-get update
apt-get install -y --no-install-recommends apt-utils gnupg python3 xz-utils zstd ca-certificates openssh-client rsync
```

两平台 Bootstrap 和软件源使用同一签名身份。将密钥目录单独挂载，并设置 `GNUPGHOME`；不要把私钥放入交付目录或新交付镜像。公钥文件由 `BOOTSTRAP_APT_KEYRING` 指定。

## 构建与导出

在对应平台容器中按构建指南准备环境。升级或增加配方时，只更新需要的平台，使用原入口：

```bash
make package SUBPROJECTS="curl"
python3 build_tools/publish_repo.py export \
  --packages "build_dist/$MEMO_TARGET/1900" \
  --output /delivery --recipe curl
```

可重复指定 `--recipe`；省略时导出全部已构建包。导出保留配方目录，校验 SHA-256，并写入 `delivery.json`。可用 `--revision` 记录对应的源码提交。同名文件内容改变会被拒绝；正常更新应提升包版本，确需替换才显式使用 `--replace`。

Bootstrap 需要更新时，可复用已有 DEB，不重新编译或打包软件包：

```bash
export DEB_ARCH=iphoneos-arm64e # tvOS: appletvos-arm64e
make bootstrap BOOTSTRAP_PACKAGES_DIR="$(pwd)/build_dist/$MEMO_TARGET/1900"
python3 build_tools/publish_repo.py export \
  --packages "build_dist/$MEMO_TARGET/1900" --output /delivery \
  --bootstrap "build_strap/$MEMO_TARGET/1900/bootstrap-$DEB_ARCH.tar.zst"
```

`DEB_ARCH` 分别为 `iphoneos-arm64e`、`appletvos-arm64e`，表示 RootHide 包架构。Bootstrap 成员和版本固定在 `build_info/bootstrap/<DEB_ARCH>.txt`，每行使用 `包名==Debian版本`；支持注释和 `-r 相对路径`。`SSH_STRAP=1` 另包含 `openssh.txt`。更新 Bootstrap 成员版本时修改对应清单；升级配方不会自动更新清单。组装按 DEB 内部的包名、版本和架构匹配，旧版本可留在构建目录；缺少指定版本或同版本包内容冲突时会报错。签名参数沿用构建指南；测试地址通过 `MEMO_REPO_URI` 指定，正式默认地址为 `https://stripe.owngoal.dev`。替换已导出的同名 Bootstrap 时需显式加 `--replace`。

## 本地归档与验收

在归档容器的仓库根目录执行。选择一个平台：

```bash
platform=ios
pool_target=iphoneos-arm64-roothide
arch=iphoneos-arm64e
```

tvOS 对应 `platform=tvos`、`pool_target=appletvos-arm64-roothide`、`arch=appletvos-arm64e`。

```bash
python3 build_tools/publish_repo.py update \
  --packages "/delivery/$platform/packages" --repo build_repo \
  --arch "$arch" --pool-target "$pool_target" \
  --signing-key "$MEMO_PGP_SIGN_KEY"

python3 build_tools/publish_repo.py verify \
  --repo build_repo --arch "$arch" --pool-target "$pool_target" \
  --keyring "$BOOTSTRAP_APT_KEYRING" \
  --bootstrap "/delivery/$platform/bootstrap/bootstrap-$arch.tar.zst" \
  --uri "${MEMO_REPO_URI:-https://stripe.owngoal.dev}" \
  --report-dir "build_work/acceptance-$platform"
```

两平台分别归档到自己的 `pool/main/<target>/1900`，共用 `dists/1900` 的 Release 和签名。更新一个平台保留另一个平台的索引；两次操作必须使用相同的 `--state-dir`（默认 `build_work/publish-state`），以共用归档锁。

默认保留旧包。只有输入目录代表该平台完整期望包集合时才使用 `update --prune`；不得对局部导出使用它。拆包、删除包需明确移除旧交付文件后再按完整集合清理。`Architecture: all` 包也保留各平台路径，不跨平台覆盖；同版本内容不同应先核对原因。

验收检查 Release 签名、索引和包哈希、keyring、Bootstrap，并使用隔离的 APT 状态通过本机 HTTP 更新索引和下载样本。可在 `verify` 后追加 `--check-install curl`，在空的隔离状态中模拟指定包的依赖安装，不执行安装。它不上传网站，也不等同于全仓运行时测试或全部依赖可安装性检查。

## 上传

在配置好发布服务器 SSH 认证的归档容器中执行，先上传包与 Bootstrap，再更新索引。只传公开产物，不传密钥目录或构建缓存。

```bash
rsync -avc --partial build_repo/pool/ <source-host>:/srv/apt/pool/
rsync -avc --partial /delivery/ios/bootstrap/ <source-host>:/srv/apt/bootstraps/1900/
rsync -avc --partial /delivery/tvos/bootstrap/ <source-host>:/srv/apt/bootstraps/appletvos-arm64e/1900/
rsync -avc --delay-updates build_repo/dists/ <source-host>:/srv/apt/dists/
rsync -avc build_repo/CydiaIcon.png <source-host>:/srv/apt/
```

不用 `--delete`，避免删除其他平台或保留版本。上传失败后可重跑；前三条成功后才执行索引上传。容器无法联网时，可将这些产物取到配置好网络的宿主机，用相同的 rsync 顺序上传。

测试站点使用 `procursus.82flex.com`，正式发布使用 `stripe.owngoal.dev`，Bootstrap 内置地址须与用途一致。发布后在客户端执行 `apt-get update`，并下载两个架构的样本包验证。

## 软件源图标

`update` 每次都会把 `build_misc/repository/CydiaIcon.png` 写到 `build_repo/CydiaIcon.png` 和 `build_repo/dists/<suite>/CydiaIcon.png`，Cydia、Sileo、Zebra 会在这两处查找。图标不在 Release 的哈希列表里，更换图标不需要重建索引或重新签名。

图标源文件在 `artwork/`：`OwnGoal.icon` 是 Icon Composer 文档，背景由 `ribbon.html?export=background&ss=4` 导出后缩到 1024。修改后在 macOS 上运行 `artwork/build-icon.sh`，重新生成 `stripe-icon.png`、`stripe-icon-square.png` 和 `CydiaIcon.png`，再按上文上传。
