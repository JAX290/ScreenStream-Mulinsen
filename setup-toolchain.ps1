$ErrorActionPreference = "Stop"

$projectRoot = $PSScriptRoot
$sharedSdk = "C:\AndroidDev\sdk"
$bootstrapJavaHome = "C:\AndroidDev\jdk17\jdk-17.0.20.1+1"
$localSdk = Join-Path $projectRoot ".toolchains\android-sdk"

if (-not (Test-Path -LiteralPath (Join-Path $bootstrapJavaHome "bin\java.exe"))) {
    throw "Bootstrap JDK not found at $bootstrapJavaHome"
}
if (-not (Test-Path -LiteralPath (Join-Path $sharedSdk "cmdline-tools"))) {
    throw "Android command-line tools not found at $sharedSdk"
}

New-Item -ItemType Directory -Force -Path $localSdk | Out-Null
Copy-Item -Recurse -Force -LiteralPath (Join-Path $sharedSdk "cmdline-tools") -Destination $localSdk
if (Test-Path -LiteralPath (Join-Path $sharedSdk "licenses")) {
    Copy-Item -Recurse -Force -LiteralPath (Join-Path $sharedSdk "licenses") -Destination $localSdk
}

$env:JAVA_HOME = $bootstrapJavaHome
$env:ANDROID_HOME = $localSdk
$env:ANDROID_SDK_ROOT = $localSdk

$sdkManager = Join-Path $localSdk "cmdline-tools\latest\bin\sdkmanager.bat"
& $sdkManager --sdk_root=$localSdk --channel=3 "platform-tools" "platforms;android-37.0" "build-tools;37.0.0"
if ($LASTEXITCODE -ne 0) {
    throw "Android SDK package installation failed with exit code $LASTEXITCODE"
}

$escapedSdkPath = -join ($localSdk.Replace('\', '\\').ToCharArray() | ForEach-Object {
    if ([int][char]$_ -gt 127) { '\u{0:x4}' -f [int][char]$_ } else { [string]$_ }
})
Set-Content -LiteralPath (Join-Path $projectRoot "local.properties") -Value "sdk.dir=$escapedSdkPath" -Encoding ASCII
Write-Host "ScreenStream SDK ready at $localSdk (JDK 17: $bootstrapJavaHome)"
