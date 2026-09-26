$ErrorActionPreference='Stop'
$stamp=Get-Date -Format yyyyMMdd-HHmmss
Start-Transcript "E:\gaoyun\d-dfdf\logs\$stamp-restore-b.txt"
try {
 $b='USB\VID_0403&PID_6010&MI_01\7&2FEB2BE7&0&0001'
 & pnputil /enable-device $b
 "EnableExit=$LASTEXITCODE"
 Get-PnpDevice -InstanceId $b | Format-List Status,InstanceId
 Get-PnpDeviceProperty -InstanceId $b -KeyName DEVPKEY_Device_Service,DEVPKEY_Device_ProblemCode | Format-List KeyName,Data
} finally {Stop-Transcript}
