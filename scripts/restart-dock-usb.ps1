$ErrorActionPreference='Stop'
Start-Transcript E:\gaoyun\d-dfdf\logs\20260926-usb-restart.txt -Force
try {
    $id='USB\VID_0403&PID_6010\FACTORYAIOT_PRO'
    Get-PnpDevice -PresentOnly -InstanceId $id | Format-List Status,InstanceId
    & pnputil /restart-device $id
    "RestartExit=$LASTEXITCODE"
} finally { Stop-Transcript }
