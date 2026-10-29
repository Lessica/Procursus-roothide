# 新增软件包

以 fastfetch 为例。命令从仓库根目录执行，先设置 `umask 022`。

```bash
umask 022
```

## 配方

新增三个文件：

| 路径 | 内容 |
| --- | --- |
| `makefiles/<pkg>.mk` | 下载源码、应用补丁、构建、打包 |
| `build_info/<pkg>.control` | 包名、版本、依赖、描述 |
| `build_patch/<pkg>/*.patch` | 按文件名顺序应用的补丁 |

`include makefiles/*.mk` 会自动纳入新配方。

## 本机构建

```bash
source build_work/host-tools/host-env.sh
make fastfetch-package
```

产物在 `build_dist/iphoneos-arm64-roothide/1900/fastfetch/`。

## 容器构建

查看容器与 SSH 端口：

```bash
ssh <build-host> 'docker ps | grep procursus'
```

把配方送进容器的 `/work`：

```bash
tar -cf - makefiles/fastfetch.mk build_info/fastfetch.control build_patch/fastfetch \
  | ssh -p <port> <build-host> 'tar -xf - -C /work'
```

在容器内构建：

```bash
cd /work
source build_work/host-tools/host-env.sh
make fastfetch-package
```

## 增量归档

在容器内设置签名环境：

```bash
cd /work
export GNUPGHOME=/root/.gnupg-procursus-relaxin
export MEMO_PGP_SIGN_KEY=<key>
export BOOTSTRAP_APT_KEYRING=/work/build_work/procursus-relaxin.gpg
make repository MEMO_REPO_URI=https://procursus.82flex.com
```

## 上传

取本次变化的索引与新增包：

```bash
rm -rf /tmp/apt-push && mkdir -p /tmp/apt-push
ssh -p <port> <build-host> \
  'tar -cf - -C /work/build_repo dists pool/main/iphoneos-arm64-roothide/1900/fastfetch' \
  | tar -xf - -C /tmp/apt-push
rsync -av /tmp/apt-push/ <source-host>:/srv/apt/
```

```text
sending incremental file list
dists/1900/InRelease
dists/1900/Release
dists/1900/Release.gpg
dists/1900/main/Contents-iphoneos-arm64e
dists/1900/main/Contents-iphoneos-arm64e.xz
dists/1900/main/Contents-iphoneos-arm64e.zst
dists/1900/main/binary-iphoneos-arm64e/
dists/1900/main/binary-iphoneos-arm64e/Packages
dists/1900/main/binary-iphoneos-arm64e/Packages.xz
dists/1900/main/binary-iphoneos-arm64e/Packages.zst
dists/1900/main/binary-iphoneos-arm64e/Release
pool/
pool/main/
pool/main/iphoneos-arm64-roothide/
pool/main/iphoneos-arm64-roothide/1900/
pool/main/iphoneos-arm64-roothide/1900/fastfetch/
pool/main/iphoneos-arm64-roothide/1900/fastfetch/fastfetch_2.70.0-1_iphoneos-arm64e.deb

sent 2833653 bytes  received 45082 bytes  694826 bytes/sec
total size is 15899039  speedup is 5.52
```

## 验证

在客户端执行：

```bash
apt-get update
apt-get download fastfetch
```
