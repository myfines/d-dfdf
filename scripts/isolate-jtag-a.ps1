$ErrorActionPreference = 'Stop'
$stamp = Get-Date -Format yyyyMMdd-HHmmss
Start-Transcript "E:\gaoyun\d-dfdf\logs\$stamp-isolate-jtag-a.txt"
try {
    $b = 'USB\VID_0403&PID_6010&MI_01\7&2FEB2BE7&0&0001'
    $parent = 'USB\VID_0403&PID_6010\FACTORYAIOT_PRO'
    Get-PnpDevice -PresentOnly -InstanceId $b,$parent | Format-List Status,InstanceId
    & pnputil /disable-device $b
    if ($LASTEXITCODE -ne 0) { throw 'Could not disable B' }
    & pnputil /restart-device $parent
    if ($LASTEXITCODE -ne 0) { throw 'Could not restart parent' }
    'B temporarily disabled for isolation; its FTDIBUS binding is retained. Restore with pnputil /enable-device on the same instance.'
} finally { Stop-Transcript }
