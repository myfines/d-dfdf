$ErrorActionPreference='Stop'
$project=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$jdk=(Get-ChildItem E:/gaoyun/tools/mobile-jdk -Directory | Where-Object {Test-Path (Join-Path $_.FullName 'bin/javac.exe')} | Select-Object -First 1).FullName
$env:JAVA_HOME=$jdk
$env:PATH="$jdk/bin;"+$env:PATH
$sdk="$env:LOCALAPPDATA/Android/Sdk"
$tools="$sdk/build-tools/36.0.0"
$android="$sdk/platforms/android-37.0/android.jar"
$out="$project/build/device-tests"
New-Item -ItemType Directory -Force "$out/classes","$out/dex" | Out-Null
function Check($name){if($LASTEXITCODE -ne 0){throw "$name failed ($LASTEXITCODE)"}}
& "$jdk/bin/javac.exe" -encoding UTF-8 -source 8 -target 8 -cp "$android;$project/build/classes.jar" -d "$out/classes" "$PSScriptRoot/DeviceSuite.java"
Check 'Device suite compile'
& "$jdk/bin/jar.exe" cf "$out/tests.jar" -C "$out/classes" .
Check 'Device archive'
& "$tools/d8.bat" --min-api 26 --lib $android --classpath "$project/build/classes.jar" --output "$out/dex" "$out/tests.jar"
Check 'Device dex'
& "$tools/aapt.exe" package -f -M "$PSScriptRoot/AndroidManifest.xml" -I $android -F "$out/unsigned.apk"
Check 'Device package'
Push-Location "$out/dex"
try{& "$tools/aapt.exe" add "$out/unsigned.apk" classes.dex;Check 'Device add dex'}finally{Pop-Location}
& "$tools/zipalign.exe" -f 4 "$out/unsigned.apk" "$out/aligned.apk"
Check 'Device align'
& "$tools/apksigner.bat" sign --ks "$project/debug.keystore" --ks-pass pass:android --out "$out/device-tests.apk" "$out/aligned.apk"
Check 'Device sign'
& "$tools/apksigner.bat" verify "$out/device-tests.apk"
Check 'Device verify'
Write-Output "$out/device-tests.apk"
