param([string]$Sdk="$env:LOCALAPPDATA\Android\Sdk",[string]$Jdk='')
$ErrorActionPreference='Stop'
if(!$Jdk){$Jdk=(Get-ChildItem E:\gaoyun\tools\mobile-jdk -Directory | Where-Object {Test-Path (Join-Path $_.FullName 'bin\javac.exe')} | Select-Object -First 1).FullName}
if(!$Jdk){throw 'Set -Jdk to a JDK 17+ directory'}
$env:JAVA_HOME=$Jdk
$env:PATH="$Jdk\bin;"+$env:PATH
$bt=Join-Path $Sdk 'build-tools\36.0.0'
$api=Join-Path $Sdk 'platforms\android-37.0\android.jar'
$build=Join-Path $PSScriptRoot 'build'
New-Item -ItemType Directory -Force "$build\classes","$build\tests","$build\dex" | Out-Null
function Check([string]$step){if($LASTEXITCODE -ne 0){throw "$step failed ($LASTEXITCODE)"}}
& "$Jdk\bin\javac.exe" -encoding UTF-8 -d "$build\tests" "$PSScriptRoot\src\cn\myfines\instrument\SynthCore.java" "$PSScriptRoot\tests\CoreTest.java"
Check 'Core test compile'
& "$Jdk\bin\java.exe" -cp "$build\tests" cn.myfines.instrument.CoreTest
Check 'Core tests'
& "$Jdk\bin\javac.exe" -encoding UTF-8 -d "$build\tests" "$PSScriptRoot\src\cn\myfines\instrument\WifiProtocol.java" "$PSScriptRoot\src\cn\myfines\instrument\WifiSession.java" "$PSScriptRoot\tests\WifiProtocolTest.java" "$PSScriptRoot\tests\WifiSessionTest.java"
Check 'WiFi tests compile'
& "$Jdk\bin\java.exe" -cp "$build\tests" cn.myfines.instrument.WifiProtocolTest
Check 'WiFi protocol tests'
& "$Jdk\bin\java.exe" -cp "$build\tests" cn.myfines.instrument.WifiSessionTest
Check 'WiFi socket tests'
$sources=@(Get-ChildItem "$PSScriptRoot\src" -Recurse -Filter *.java | ForEach-Object {$_.FullName})
& "$Jdk\bin\javac.exe" -encoding UTF-8 -source 8 -target 8 -classpath $api -d "$build\classes" @sources
Check 'App compile'
& "$Jdk\bin\jar.exe" cf "$build\classes.jar" -C "$build\classes" .
Check 'Classes archive'
& "$bt\d8.bat" --min-api 26 --lib $api --output "$build\dex" "$build\classes.jar"
Check 'Dex'
& "$bt\aapt.exe" package -f -M "$PSScriptRoot\AndroidManifest.xml" -I $api -F "$build\unsigned.apk"
Check 'APK package'
Push-Location "$build\dex"
try{& "$bt\aapt.exe" add "$build\unsigned.apk" classes.dex;Check 'Add dex'}finally{Pop-Location}
& "$bt\zipalign.exe" -f 4 "$build\unsigned.apk" "$build\aligned.apk"
Check 'Align'
if(!(Test-Path "$PSScriptRoot\debug.keystore")){
 & "$Jdk\bin\keytool.exe" -genkeypair -keystore "$PSScriptRoot\debug.keystore" -storepass android -keypass android -alias androiddebugkey -dname 'CN=Instrument Local Debug' -keyalg RSA -validity 3650
 Check 'Debug signing key'
}
& "$bt\apksigner.bat" sign --ks "$PSScriptRoot\debug.keystore" --ks-pass pass:android --out "$build\instrument-companion.apk" "$build\aligned.apk"
Check 'Sign'
& "$bt\apksigner.bat" verify "$build\instrument-companion.apk"
Check 'Verify signature'
Write-Output "APK: $build\instrument-companion.apk"
