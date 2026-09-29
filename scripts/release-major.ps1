param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version,
    [string]$Message = ""
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

$buildText = Get-Content -Raw -LiteralPath "app\build.gradle.kts"
if ($buildText -notmatch "versionName\s*=\s*`"$([regex]::Escape($Version))`"") {
    throw "app/build.gradle.kts 的 versionName 不是 $Version"
}
if ((Get-Content -Raw -LiteralPath "README_ZH.md") -notmatch [regex]::Escape($Version)) {
    throw "README_ZH.md 尚未包含版本 $Version，请先更新说明"
}

& "$PSScriptRoot\publish-version.ps1"
if ($LASTEXITCODE -ne 0) { throw "APK 发布失败" }
& gh auth status
if ($LASTEXITCODE -ne 0) { throw "请先运行 gh auth login -h github.com 完成 GitHub 登录" }

$commitMessage = if ($Message) { $Message } else { "Release v$Version" }
git add --all
git commit -m $commitMessage
git tag -a "v$Version" -m $commitMessage
git push origin HEAD
git push origin "v$Version"

$apk = Get-ChildItem -LiteralPath "apk\v$Version" -Filter '*.apk' | Select-Object -First 1
if ($apk) {
    gh release create "v$Version" $apk.FullName --title "ScreenStream Mulinsen v$Version" --generate-notes
}
