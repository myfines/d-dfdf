param(
    [string]$Modelsim = 'D:\Modelsim\modelsim_ase\win32aloem'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$work = Join-Path $PSScriptRoot 'ms'
$logs = Join-Path $PSScriptRoot 'logs'
New-Item -ItemType Directory -Force $work, $logs | Out-Null
Set-Location $work

$vlib = Join-Path $Modelsim 'vlib.exe'
$vlog = Join-Path $Modelsim 'vlog.exe'
$vsim = Join-Path $Modelsim 'vsim.exe'
foreach ($tool in @($vlib, $vlog, $vsim)) {
    if (!(Test-Path $tool)) { throw "ModelSim tool not found: $tool" }
}

if (!(Test-Path 'work')) { & $vlib work | Out-Null }

$rtl = @(
    'wave_source.v','synth32.v','fx_engine.v','spectrum16.v','note_router.v',
    'song_player.v','led_guide.v','panel_ctrl.v','esp_command_parser.v',
    'oled_i2c_stream.v','oled_ui.v','i2s_tx16.v','ads1015_reader.v',
    'i2c_register_bus.v','optical_keys_reader.v','io_arm_control.v',
    'gesture_uart_rx.v','gesture_packet_rx.v','gesture_expression.v',
    'uart8n1.v','uart_status.v','esp_volume_parser.v','esp_at_control.v',
    'wifi_telemetry.v','instrument_core.v','instrument_e027_top.v'
) | ForEach-Object { Join-Path $root "src\$_" }

$models = @(
    (Join-Path $PSScriptRoot 'ads1015_model.sv')
)

$tests = @(
    'tb_synth32','tb_features','tb_fx','tb_spectrum',
    'tb_oled_ui','tb_song_led','tb_command','tb_core'
)
$tbFiles = $tests | ForEach-Object { Join-Path $PSScriptRoot "$_.sv" }

& $vlog -sv @rtl @models @tbFiles 2>&1 | Tee-Object -FilePath (Join-Path $logs 'compile.log')
if ($LASTEXITCODE -ne 0) { throw "compile failed" }

$failed = @()
foreach ($tb in $tests) {
    $log = Join-Path $logs "$tb.log"
    & $vsim -c -do "run -all; quit -f" "work.$tb" 2>&1 | Tee-Object -FilePath $log
    $text = Get-Content -LiteralPath $log -Raw
    if ($text -notmatch 'PASS') {
        $failed += $tb
        Write-Host "FAIL $tb" -ForegroundColor Red
    } else {
        Write-Host "PASS $tb" -ForegroundColor Green
    }
}

if ($failed.Count -ne 0) {
    throw ("failed: " + ($failed -join ', '))
}
Write-Host "All E028 regressions passed."
