param(
    [Parameter(Mandatory = $true)]
    [string]$Serial,

    [string]$ApkPath = "",

    [switch]$Install
)

$ErrorActionPreference = "Stop"

$projectRoot = $PSScriptRoot
$adb = Join-Path $projectRoot ".toolchains\android-sdk\platform-tools\adb.exe"
if (-not (Test-Path -LiteralPath $adb)) {
    throw "Project-local adb is missing. Run setup-toolchain.ps1 first."
}

if ([string]::IsNullOrWhiteSpace($ApkPath)) {
    $ApkPath = Join-Path $projectRoot "app\build\outputs\apk\FDroid\debug\app-FDroid-debug.apk"
}

# Never stop or reset the shared ADB server: other APK projects may be using it.
& $adb -s $Serial get-state
if ($LASTEXITCODE -ne 0) {
    throw "Device '$Serial' is not available. Check USB debugging and the RSA authorization prompt."
}

& $adb -s $Serial shell getprop ro.product.manufacturer
& $adb -s $Serial shell getprop ro.product.model
& $adb -s $Serial shell getprop ro.build.version.release
& $adb -s $Serial shell getprop ro.build.version.sdk

if ($Install) {
    if (-not (Test-Path -LiteralPath $ApkPath)) {
        throw "APK not found: $ApkPath"
    }
    & $adb -s $Serial install -r $ApkPath
    if ($LASTEXITCODE -ne 0) {
        throw "APK installation failed."
    }
}
