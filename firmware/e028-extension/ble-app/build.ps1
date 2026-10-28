param(
    [string]$Jdk = $env:JAVA_HOME,
    [string]$Sdk = $env:ANDROID_HOME
)

# Offline local toolchain, same layout as fpga-instrument-app/build.ps1.
# Override JAVA_HOME/ANDROID_HOME or pass -Jdk/-Sdk on another machine.
if (!$Jdk) { $Jdk = 'D:\MCLDownload\ext\jre-v64-220420\jdk17' }
if (!$Sdk) { $Sdk = 'E:\DS working space\android-sdk' }

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$build = Join-Path $root 'build'
$dist = Join-Path $root 'dist'
$bt = Join-Path $Sdk 'build-tools\34.0.0'
$api = Join-Path $Sdk 'platforms\android-34\android.jar'
$keystore = Join-Path $root 'debug.keystore'
$javac = Join-Path $Jdk 'bin\javac.exe'
$java = Join-Path $Jdk 'bin\java.exe'
$jar = Join-Path $Jdk 'bin\jar.exe'
$keytool = Join-Path $Jdk 'bin\keytool.exe'
$aapt = Join-Path $bt 'aapt.exe'
$d8 = Join-Path $bt 'd8.bat'
$zipalign = Join-Path $bt 'zipalign.exe'
$apksigner = Join-Path $bt 'apksigner.bat'

if (!(Test-Path $javac)) { throw "JDK not found: $Jdk" }
if (!(Test-Path $aapt)) { throw "build-tools 34 not found: $bt" }
if (!(Test-Path $api)) { throw "android.jar not found: $api" }

$env:JAVA_HOME = $Jdk
$env:PATH = (Join-Path $Jdk 'bin') + ';' + $env:PATH

# Only the local build directory is removed; never touch src/res/dist.
if ($build -ne (Join-Path $root 'build')) { throw "Unexpected build path: $build" }
if (Test-Path $build) {
    Remove-Item -Recurse -Force $build
}
New-Item -ItemType Directory -Force $build,
    (Join-Path $build 'classes'), (Join-Path $build 'tests'),
    (Join-Path $build 'dex'), $dist | Out-Null

function Check([string]$step) {
    if ($LASTEXITCODE -ne 0) { throw "$step failed ($LASTEXITCODE)" }
}

Write-Host '== protocol tests =='
$testSources = @(
    (Join-Path $root 'src\com\fpga\instrument\ble\Protocol.java'),
    (Join-Path $root 'tests\ProtocolTest.java')
)
& $javac -encoding UTF-8 -d (Join-Path $build 'tests') @testSources
Check 'Test compile'
& $java -cp (Join-Path $build 'tests') ProtocolTest
Check 'Protocol tests'

Write-Host '== app compile =='
$sources = @(Get-ChildItem (Join-Path $root 'src') -Recurse -Filter *.java |
    ForEach-Object { $_.FullName })
if ($sources.Count -eq 0) { throw 'No Java sources found' }
& $javac -encoding UTF-8 -source 8 -target 8 -Xlint:-options `
    -classpath $api -d (Join-Path $build 'classes') @sources
Check 'App compile'

& $jar cf (Join-Path $build 'classes.jar') -C (Join-Path $build 'classes') .
Check 'Classes archive'

Write-Host '== dex =='
& $d8 --min-api 26 --lib $api --output (Join-Path $build 'dex') `
    (Join-Path $build 'classes.jar')
Check 'Dex'

Write-Host '== package =='
$unsigned = Join-Path $build 'unsigned.apk'
$aligned = Join-Path $build 'aligned.apk'
& $aapt package -f -M (Join-Path $root 'AndroidManifest.xml') `
    -S (Join-Path $root 'res') -I $api -F $unsigned
Check 'APK package'

Push-Location (Join-Path $build 'dex')
try {
    & $aapt add $unsigned classes.dex
    Check 'Add dex'
} finally {
    Pop-Location
}

& $zipalign -f 4 $unsigned $aligned
Check 'Align'

if (!(Test-Path $keystore)) {
    & $keytool -genkeypair -keystore $keystore `
        -storepass android -keypass android -alias androiddebugkey `
        -dname 'CN=FPGA BLE Local Debug' -keyalg RSA -validity 3650
    Check 'Debug signing key'
}

$apk = Join-Path $dist 'FPGA-BLE.apk'
Remove-Item -Force $apk -ErrorAction SilentlyContinue
& $apksigner sign --ks $keystore --ks-pass pass:android `
    --key-pass pass:android --ks-key-alias androiddebugkey `
    --v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled true `
    --out $apk $aligned
Check 'Sign'

& $apksigner verify --verbose --print-certs $apk
Check 'Verify signature'

Write-Host ''
Write-Host '== APK =='
& $aapt dump badging $apk | Select-String -Pattern 'package:|sdkVersion|targetSdkVersion|application-label'
$hash = (Get-FileHash -Algorithm SHA256 -Path $apk).Hash
$size = (Get-Item $apk).Length
Write-Host ("Path:   {0}" -f $apk)
Write-Host ("Size:   {0:N0} bytes ({1:N1} KiB)" -f $size, ($size / 1024.0))
Write-Host ("SHA256: {0}" -f $hash)
