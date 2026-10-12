param(
    [ValidateSet('SRAM','Flash')][string]$Mode='SRAM',
    [string]$Bitstream='E:\gaoyun\projects\instrument_io\instrument_io\impl\pnr\instrument_io.fs',
    [string]$ExpectedSha256,
    [switch]$UsbReconnected,
    [switch]$DryRun
)
$ErrorActionPreference='Stop'
$repoDir=Split-Path $PSScriptRoot -Parent
$cli='E:\gaoyun\tools\gowin\Gowin_V1.9.11.03_Education\Gowin_V1.9.11.03_Education_x64\Programmer\bin\programmer_cli.exe'
if(-not $ExpectedSha256){
    $manifest=Get-Content -Raw (Join-Path $repoDir 'logs\20261012-complete-release-checks.json') | ConvertFrom-Json
    $ExpectedSha256=$manifest.bitstream_sha256
}
$actualHash=(Get-FileHash -LiteralPath $Bitstream -Algorithm SHA256).Hash
if($actualHash -ne $ExpectedSha256){throw "Bitstream SHA256 mismatch: $actualHash"}
if($Mode -eq 'Flash' -and -not $UsbReconnected){throw 'Reconnect USB after closing all UART programs; then use -UsbReconnected.'}
if(@(Get-Process -Name programmer_cli -ErrorAction SilentlyContinue).Count){throw 'Another programmer is running.'}
$operation=if($Mode -eq 'Flash'){37}else{2}
$programArgs=@('--device','GW2A-18C','--cable-index','1','--frequency','2.5MHz','--operation_index',"$operation",'--fsFile',$Bitstream)
if($Mode -eq 'Flash'){$programArgs+=@('--spiaddr','0x000000')}
if($DryRun){"Validated SHA256 $actualHash";"$cli $($programArgs -join ' ')";return}
$taskStamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$scanLog=Join-Path $repoDir "logs\$taskStamp-instrument-scan.log"
$programLog=Join-Path $repoDir "logs\$taskStamp-instrument-$Mode.log"
& $cli --cable-index 1 --frequency 2.5MHz --scan *> $scanLog
if($LASTEXITCODE -ne 0 -or (Get-Content -Raw $scanLog) -notmatch '0x0000081B'){throw "JTAG scan failed; see $scanLog"}
& $cli @programArgs *> $programLog
$programExit=$LASTEXITCODE
Get-Content $programLog -Tail 8
if($programExit -ne 0){throw "Programming failed with exit $programExit; see $programLog"}
if($Mode -eq 'Flash' -and (Get-Content -Raw $programLog) -notmatch 'Program and Verify flash successfully'){throw "Flash verification success missing; see $programLog"}
"Completed $Mode; log: $programLog"
