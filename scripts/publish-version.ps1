param(
    [ValidateSet("FDroidDebug", "FDroidRelease")]
    [string]$Variant = "FDroidDebug"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildFile = Join-Path $projectRoot "app\build.gradle.kts"
$buildText = Get-Content -Raw -LiteralPath $buildFile
$versionMatch = [regex]::Match($buildText, 'versionName\s*=\s*"([^"]+)"')
if (-not $versionMatch.Success) { throw "Cannot read versionName from app/build.gradle.kts" }
$version = $versionMatch.Groups[1].Value

& (Join-Path $projectRoot "build-isolated.ps1") -Variant $Variant
if ($LASTEXITCODE -ne 0) { throw "APK build failed" }

$buildType = if ($Variant.EndsWith("Debug")) { "debug" } else { "release" }
$source = Join-Path $projectRoot "app\build\outputs\apk\FDroid\$buildType\app-FDroid-$buildType.apk"
if (-not (Test-Path -LiteralPath $source)) { throw "APK not found: $source" }

$suffix = if ($buildType -eq "debug") { "-debug" } else { "" }
$fileName = "ScreenStream-Mulinsen-v$version$suffix.apk"
$versionDir = Join-Path $projectRoot "apk\v$version"
$latestDir = Join-Path $projectRoot "apk\latest"
New-Item -ItemType Directory -Force -Path $versionDir,$latestDir | Out-Null
Copy-Item -LiteralPath $source -Destination (Join-Path $versionDir $fileName) -Force
Copy-Item -LiteralPath $source -Destination (Join-Path $latestDir $fileName) -Force

$hash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
Set-Content -LiteralPath (Join-Path $versionDir "$fileName.sha256") -Value "$hash  $fileName" -Encoding utf8
Set-Content -LiteralPath (Join-Path $latestDir "$fileName.sha256") -Value "$hash  $fileName" -Encoding utf8

$index = @"
<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>ScreenStream APK 下载</title><body style="font-family:system-ui;max-width:720px;margin:50px auto;padding:20px">
<h1>ScreenStream 木林森版</h1><p>当前推荐版本：v$version</p>
<p><a href="latest/$fileName">下载 $fileName</a></p>
<p>SHA-256：<code>$hash</code></p></body></html>
"@
Set-Content -LiteralPath (Join-Path $projectRoot "apk\index.html") -Value $index -Encoding utf8
Write-Output "Published APK: apk/v$version/$fileName"
Write-Output "SHA-256: $hash"
