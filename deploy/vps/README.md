# VPS 一键部署

适用于 Ubuntu/Debian VPS。部署前，在 Cloudflare 创建：

- `ingest.mulinsen.win`：DNS Only（灰色云）
- `view.mulinsen.win`：DNS Only，指向 VPS 公网 IP
- `api.mulinsen.win`：DNS Only，指向 VPS 的 Tailscale IP

`ingest` 和 `view` 指向 VPS 公网 IP；`api` 指向 `tailscale ip -4` 显示的 `100.x` 地址。VPS 必须已经安装并登录 Tailscale。

> 必须使用灰色云，不能开启 Cloudflare 代理。如果个别网络的 DNS 拦截 `100.x` 私网地址，请在 Tailscale 管理后台配置 Split DNS，让 `mulinsen.win` 由能够返回这三条记录的 DNS 服务器解析。

画面查看页面不设用户名和密码，只有同一 Tailnet 内的设备才能访问：

```text
http://api.mulinsen.win
```

APK 下载页 `http://view.mulinsen.win/apk1` 可以从公网打开，但下载闸门默认关闭。连接 Tailscale 后打开：

```text
http://api.mulinsen.win/download-control
```

控制页可立即关闭下载，也可开放指定分钟、限制指定下载次数或永久开放。次数只在实际请求 APK 文件时扣减。

## 从 GitHub 一键安装

在 VPS 的 root 终端中粘贴这一行：

```bash
curl -fsSL https://raw.githubusercontent.com/JAX290/ScreenStream-Mulinsen/main/deploy/vps/bootstrap.sh | sudo bash
```

脚本会从 GitHub 下载最新代码和 APK，然后进入中文安装向导。仓库必须是公开仓库；如果仓库保持私有，GitHub 会拒绝匿名下载，需要先手动下载项目。

## 已下载项目的安装方式

在项目目录中执行：

```bash
sudo bash deploy/vps/install.sh
```

脚本会逐项询问邮箱、录像保留天数及手机推流账号。推流密码留空会自动生成；网页查看不需要密码。部署结果保存在仅 root 可读的：

```text
/opt/mulinsen-screenstream/DEPLOYMENT_INFO.txt
```

日常更新：

```bash
sudo bash update.sh
```

查看状态：

```bash
cd /opt/mulinsen-screenstream
sudo docker compose ps
sudo docker compose logs --tail=100
```
