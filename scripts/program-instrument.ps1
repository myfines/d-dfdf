param(
    [ValidateSet('SRAM','Flash')][string]$Mode='SRAM',
    [string]$Bitstream='E:\gaoyun\projects\instrument_io\instrument_io\impl\pnr\instrument_io.fs',
    [string]$ExpectedSha256,
    [switch]$UsbReconnected,
    [switch]$DryRun,
    [switch]$SupervisedSram,
    [switch]$AuthorizedE021Flash
)
$ErrorActionPreference='Stop'
$repoDir=Split-Path $PSScriptRoot -Parent
$holdFile=Join-Path $repoDir 'docs\hardware-hold.json'
if((Test-Path -LiteralPath $holdFile) -and -not $DryRun){
    $hardwareHold=Get-Content -Raw $holdFile | ConvertFrom-Json
    if($hardwareHold.deployment_blocked){
        $scopedTrial=$SupervisedSram -and $Mode -eq 'SRAM'
        $scopedFlash=$AuthorizedE021Flash -and $UsbReconnected -and $Mode -eq 'Flash'
        if((-not $scopedTrial -and -not $scopedFlash) -or $ExpectedSha256 -ne '6D89D33520697199C489A78BA5FEB17C31F13B1D3CC9D1A175C7B2718CC42C5D'){
            throw "Thermal incident unresolved: $($hardwareHold.reason)"
        }
        Write-Warning 'Explicitly authorized fixed-hash E021 trial. Thermal cause remains unresolved; default deployment hold remains in place.'
    }
}
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
if($Mode -eq 'SRAM'){
    $programText=Get-Content -Raw $programLog
    if($programText -notmatch 'Status Code is: 0x00006020' -or $programText -notmatch '100%'){
        throw "SRAM completion/status missing; see $programLog"
    }
    if($programText -match 'User code mismatch'){
        if(-not $SupervisedSram -or $actualHash -ne '6D89D33520697199C489A78BA5FEB17C31F13B1D3CC9D1A175C7B2718CC42C5D' -or $programText -notmatch 'User Code is: 0x0000E021'){
            throw "Unexpected user code mismatch; see $programLog"
        }
        Write-Warning 'E021 was reported with a user-code mismatch warning. Independently read operations 73/74 and verify physical heartbeat before acceptance.'
    }
}
if($Mode -eq 'Flash' -and (Get-Content -Raw $programLog) -notmatch 'Program and Verify flash successfully'){throw "Flash verification success missing; see $programLog"}
"Completed $Mode; log: $programLog"
