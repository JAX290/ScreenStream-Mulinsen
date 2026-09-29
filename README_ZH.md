# ScreenStream 木林森无人值守版

这是基于开源项目 ScreenStream 改造的 Android 异地屏幕查看方案，面向不会写代码的使用者。手机主动连接 VPS，VPS 负责录像、转发和后续图像分析。

## 已固定的地址

- 手机推流：`rtsps://ingest.mulinsen.win:8322/phone/nova6`
- 网页查看：`http://api.mulinsen.win`（仅 Tailscale 内网）
- 管理 API：`http://api.mulinsen.win`（仅 Tailscale 内网）
- APK 下载：`http://view.mulinsen.win/apk1`（公网可打开，下载默认关闭）
- 下载控制：`http://api.mulinsen.win/download-control`（仅 Tailscale 内网）

域名已经编译进 APK，但账号密码不会写入代码或 GitHub。

## 第一次使用

1. 在 Cloudflare 创建 `ingest`、`view`、`api` 三条 DNS 记录并指向 VPS。
2. `ingest` 和 `view` 指向 VPS 公网 IP；`api` 指向 VPS 的 Tailscale IP，三条记录均使用 DNS Only。
3. 把本项目上传到 VPS，执行 `sudo bash deploy/vps/install.sh`。
4. 打开 VPS 上的 `/opt/mulinsen-screenstream/DEPLOYMENT_INFO.txt`。
5. 将其中的完整“手机推流地址”填入 APP 的 RTSP 服务器地址。
6. 在 APP 中开启“无人值守重启恢复”，并按系统提示启用无障碍服务。

VPS 详细步骤见 [deploy/vps/README.md](deploy/vps/README.md)。

## APK

版本化 APK 位于 [apk](apk) 目录。每次发布大版本时运行：

```powershell
.\scripts\publish-version.ps1
```

脚本会构建 APK，复制到对应版本目录，并更新 `latest`。

## 一键上传并部署 VPS

Windows 电脑可以运行：

```powershell
.\scripts\deploy-to-vps.ps1
```

按提示输入 VPS IP、SSH 端口和用户名即可。密码由 SSH 自己询问，不会保存到项目。

## 大版本发布规则

每个大版本必须同时更新：

1. `app/build.gradle.kts` 中的 `versionCode` 和 `versionName`。
2. `README.md`、本文件及部署说明。
3. `apk/v版本号/` 和 `apk/latest/` 中的 APK。
4. Git 提交、版本标签和 GitHub Release。

完成代码和文档检查后运行：

```powershell
.\scripts\release-major.ps1 -Version 5.0.0
```

## 安全说明

- 不要把 VPS 密码、推流密码、Cloudflare Token 或签名密钥提交到 GitHub。
- `ingest.mulinsen.win` 使用 RTSPS/TCP 和独立的发布账号。
- `api.mulinsen.win` 的画面和控制面板只允许 Tailscale 地址访问，因此不设置网页账号密码。
- `/apk1` 公网入口由下载闸门保护，默认关闭，可按分钟、下载次数或永久开放。
- VPS 管理端口不直接暴露公网。

## 上游项目

原项目和导入版本记录在 [UPSTREAM.md](UPSTREAM.md)，原始许可证保留在 [LICENSE](LICENSE)。
