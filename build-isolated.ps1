param(
    [ValidateSet("FDroidDebug", "FDroidRelease", "PlayStoreDebug", "PlayStoreRelease")]
    [string]$Variant = "FDroidDebug"
)

$ErrorActionPreference = "Stop"

$projectRoot = $PSScriptRoot
$javaHome = "C:\AndroidDev\jdk17\jdk-17.0.20.1+1"
$androidSdk = Join-Path $projectRoot ".toolchains\android-sdk"
$gradleHome = Join-Path $projectRoot ".gradle-user-home"

if (-not (Test-Path -LiteralPath (Join-Path $javaHome "bin\java.exe"))) {
    throw "JDK 17 is not ready at $javaHome. Run setup-toolchain.ps1 first."
}
if (-not (Test-Path -LiteralPath (Join-Path $androidSdk "platforms\android-37.0"))) {
    throw "Project-local Android SDK is not ready. Run setup-toolchain.ps1 first."
}

$env:JAVA_HOME = $javaHome
$env:ANDROID_HOME = $androidSdk
$env:ANDROID_SDK_ROOT = $androidSdk
$env:GRADLE_USER_HOME = $gradleHome
$env:Path = "$javaHome\bin;$androidSdk\platform-tools;$env:Path"

& (Join-Path $projectRoot "gradlew.bat") ":app:assemble$Variant" --no-daemon "-Pkotlin.compiler.execution.strategy=in-process"
exit $LASTEXITCODE
