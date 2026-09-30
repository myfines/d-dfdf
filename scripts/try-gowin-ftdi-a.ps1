$ErrorActionPreference = 'Stop'

$repoDir = 'E:\gaoyun\d-dfdf'
$aId = 'USB\VID_0403&PID_6010&MI_00\7&2FEB2BE7&0&0000'
$bId = 'USB\VID_0403&PID_6010&MI_01\7&2FEB2BE7&0&0001'
$winUsbInf = 'E:\gaoyun\tools\driver-switch\backup-winusb-20260930\tang20k_jtag_a.inf'
$installer = 'E:\gaoyun\tools\libwdi-src\wdi-simple.exe'
$cli = 'E:\gaoyun\tools\gowin\Gowin_V1.9.11.03_Education\Gowin_V1.9.11.03_Education_x64\Programmer\bin\programmer_cli.exe'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$transcript = Join-Path $repoDir "logs\$stamp-gowin-ftdi-driver-trial.txt"
$scanOut = Join-Path $repoDir "logs\$stamp-gowin-ftdi-scan.out.txt"
$scanErr = Join-Path $repoDir "logs\$stamp-gowin-ftdi-scan.err.txt"
$driverChanged = $false

Start-Transcript -Path $transcript
try {
    $principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
    if (!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Administrator token required; no driver operation attempted.'
    }
    foreach ($path in @($winUsbInf, $installer, $cli)) {
        if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required file missing: $path" }
    }
    if ((Get-FileHash -LiteralPath $winUsbInf -Algorithm SHA256).Hash -ne '17B84FCE55421DBC1092A6F3808C3B4F97935969BC5DF3967FBDA60468392469') {
        throw 'Exported WinUSB INF hash mismatch.'
    }
    if ((Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash -ne '5B96731BFBDBA2E1EF5BA5AA02963AB365A1A9DDE187A9FC343F2B1F5B31CFF9') {
        throw 'WinUSB rollback installer hash mismatch.'
    }
    $a = @(Get-PnpDevice -PresentOnly | Where-Object InstanceId -eq $aId)
    $b = @(Get-PnpDevice -PresentOnly | Where-Object InstanceId -eq $bId)
    if ($a.Count -ne 1 -or $b.Count -ne 1) { throw 'Exact USB A/B pair missing or ambiguous.' }
    if ($a[0].Status -ne 'OK' -or $b[0].Status -ne 'OK') { throw 'USB A/B status is not OK.' }
    if (@(Get-Process openFPGALoader,programmer_cli,programmer -ErrorAction SilentlyContinue).Count) {
        throw 'A programmer process is already running.'
    }
    $aInf = (Get-PnpDeviceProperty -InstanceId $aId -KeyName DEVPKEY_Device_DriverInfPath).Data
    $bService = (Get-PnpDeviceProperty -InstanceId $bId -KeyName DEVPKEY_Device_Service).Data
    if ($aInf -ne 'oem180.inf' -or $bService -ne 'FTDIBUS') {
        throw "Unexpected driver binding: A=$aInf B=$bService"
    }

    'Remove only the A-channel WinUSB driver package; Windows should bind its already staged FTDI driver.'
    $driverChanged = $true
    & pnputil /delete-driver oem180.inf /uninstall
    if ($LASTEXITCODE -ne 0) { throw "pnputil failed, exit=$LASTEXITCODE" }
    & pnputil /scan-devices
    if ($LASTEXITCODE -ne 0) { throw "PnP rescan failed, exit=$LASTEXITCODE" }
    Start-Sleep -Seconds 2
    $aService = (Get-PnpDeviceProperty -InstanceId $aId -KeyName DEVPKEY_Device_Service).Data
    $bAfter = (Get-PnpDeviceProperty -InstanceId $bId -KeyName DEVPKEY_Device_Service).Data
    $aStatus = (Get-PnpDevice -InstanceId $aId).Status
    $bStatus = (Get-PnpDevice -InstanceId $bId).Status
    "After switch: A=$aService/$aStatus B=$bAfter/$bStatus"
    if ($aService -ne 'FTDIBUS' -or $bAfter -ne $bService -or $aStatus -ne 'OK' -or $bStatus -ne 'OK') {
        throw 'FTDI A/B binding was not established cleanly.'
    }

    $proc = Start-Process -FilePath $cli -ArgumentList @('--cable-index', '1', '--frequency', '2.5MHz', '--scan') `
        -WindowStyle Hidden -PassThru -RedirectStandardOutput $scanOut -RedirectStandardError $scanErr
    if (!$proc.WaitForExit(8000)) {
        $proc.Kill()
        throw 'Gowin FT2CH read-only scan timed out after 8 seconds.'
    }
    $scan = Get-Content -LiteralPath $scanOut -Raw
    "Gowin scan exit=$($proc.ExitCode)"
    $scan
    if ($proc.ExitCode -ne 0 -or $scan -notmatch 'ID:\s*0x0000081B' -or $scan -notmatch '1 device\(s\) found!') {
        throw 'Gowin scan did not identify exactly one FPGA with ID 0x0000081B.'
    }
    'SUCCESS: A uses FTDI; Gowin Programmer read the expected FPGA ID. No Flash command was run.'
} catch {
    "Trial failed: $_"
    if ($driverChanged) {
        'Restoring WinUSB on A using the previously verified local installer.'
        try {
            & $installer --vid 0x0403 --pid 0x6010 --iid 0 --type 0 --name 'Tang Primer 20K JTAG A' `
                --manufacturer Sipeed --inf tang20k_jtag_a.inf --dest E:\gaoyun\tools\tang20k-winusb-a `
                --timeout 30000 --log 0
            "Rollback installer exit=$LASTEXITCODE"
            Get-PnpDeviceProperty -InstanceId $aId -KeyName DEVPKEY_Device_Service,DEVPKEY_Device_DriverInfPath |
                Format-List KeyName,Data
        } catch {
            "Rollback needs manual attention: $_"
        }
    }
    exit 1
} finally {
    Stop-Transcript
}
