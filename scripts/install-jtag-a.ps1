$ErrorActionPreference = 'Stop'
$repo = 'E:\gaoyun\d-dfdf'
$log = Join-Path $repo 'logs\20260926-winusb-install.txt'
Start-Transcript -Path $log -Force
try {
    $principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
    if (!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Administrator token required' }
    $a = 'USB\VID_0403&PID_6010&MI_00\7&2FEB2BE7&0&0000'
    $b = 'USB\VID_0403&PID_6010&MI_01\7&2FEB2BE7&0&0001'
    $targets = @(Get-PnpDevice -PresentOnly | Where-Object InstanceId -like 'USB\VID_0403&PID_6010&MI_00\*')
    if ($targets.Count -ne 1 -or $targets[0].InstanceId -ne $a) { throw 'Exact JTAG A target is missing or ambiguous' }
    if (@(Get-Process programmer_cli,openFPGALoader,programmer -ErrorAction SilentlyContinue).Count) { throw 'Programmer process is running' }
    $exe = 'E:\gaoyun\tools\libwdi-src\wdi-simple.exe'
    if ((Get-FileHash $exe).Hash -ne '5B96731BFBDBA2E1EF5BA5AA02963AB365A1A9DDE187A9FC343F2B1F5B31CFF9') { throw 'Installer hash mismatch' }
    $beforeB = (Get-PnpDeviceProperty -InstanceId $b -KeyName DEVPKEY_Device_Service).Data
    New-Item -ItemType Directory -Force 'E:\gaoyun\tools\ftdi-driver-backup' | Out-Null
    & pnputil /export-driver oem178.inf E:\gaoyun\tools\ftdi-driver-backup
    if ($LASTEXITCODE -ne 0) { throw 'FTDI driver backup failed' }
    & $exe --vid 0x0403 --pid 0x6010 --iid 0 --type 0 --name 'Tang Primer 20K JTAG A' --manufacturer Sipeed --inf tang20k_jtag_a.inf --dest E:\gaoyun\tools\tang20k-winusb-a --timeout 30000 --log 0
    $installExit = $LASTEXITCODE
    "Installer exit: $installExit"
    Get-PnpDevice -InstanceId $a,$b | Format-List Status,InstanceId
    Get-PnpDeviceProperty -InstanceId $a -KeyName DEVPKEY_Device_Service,DEVPKEY_Device_DriverInfPath | Format-List KeyName,Data
    $afterB = (Get-PnpDeviceProperty -InstanceId $b -KeyName DEVPKEY_Device_Service).Data
    "B driver before=$beforeB after=$afterB"
    if ($beforeB -ne $afterB) { throw 'B driver unexpectedly changed' }
    if ($installExit -ne 0) { throw "Installer failed: $installExit" }
    if ((Get-PnpDeviceProperty -InstanceId $a -KeyName DEVPKEY_Device_Service).Data -ne 'WinUSB') { throw 'A is not bound to WinUSB' }
    'SUCCESS: JTAG A uses WinUSB; B driver retained.'
} catch {
    $_ | Out-String | Write-Output
    exit 1
} finally {
    Stop-Transcript
}
