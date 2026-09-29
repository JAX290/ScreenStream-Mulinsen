param(
    [string]$VpsHost = "",
    [int]$SshPort = 22,
    [string]$SshUser = "root"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($VpsHost)) { $VpsHost = Read-Host "请输入 VPS 公网 IP 或主机名" }
if ($VpsHost -notmatch '^[a-zA-Z0-9.:-]+$') { throw "VPS 地址格式不正确" }
if ($SshUser -notmatch '^[a-zA-Z0-9_-]+$') { throw "SSH 用户名格式不正确" }
if ($SshPort -lt 1 -or $SshPort -gt 65535) { throw "SSH 端口格式不正确" }

$remote = "$SshUser@$VpsHost"
$remoteRoot = "/tmp/mulinsen-screenstream-deploy"
Write-Output "正在上传部署文件到 $remote……"
& ssh -p $SshPort $remote "mkdir -p $remoteRoot/deploy $remoteRoot/apk"
if ($LASTEXITCODE -ne 0) { throw "无法连接 VPS" }
& scp -P $SshPort -r (Join-Path $projectRoot "deploy\vps") "$remote`:$remoteRoot/deploy/"
if ($LASTEXITCODE -ne 0) { throw "上传 VPS 部署文件失败" }
& scp -P $SshPort -r (Join-Path $projectRoot "apk\.") "$remote`:$remoteRoot/apk/"
if ($LASTEXITCODE -ne 0) { throw "上传 APK 失败" }

Write-Output "上传完成，即将进入 VPS 一键安装向导。"
& ssh -t -p $SshPort $remote "chmod +x $remoteRoot/deploy/vps/install.sh && sudo bash $remoteRoot/deploy/vps/install.sh"
if ($LASTEXITCODE -ne 0) { throw "VPS 部署没有成功完成" }
