$ErrorActionPreference = 'Stop'
$repoDir = Split-Path $PSScriptRoot -Parent
$iverilog = 'E:\gaoyun\tools\iverilog\ucrt64\bin\iverilog.exe'
$vvp = 'E:\gaoyun\tools\iverilog\ucrt64\bin\vvp.exe'
# The newer UCRT libstdc++ must precede the unrelated GCC 8 runtime in PATH.
$env:PATH = 'E:\gaoyun\tools\openfpgaloader\ucrt64\bin;E:\gaoyun\tools\iverilog\ucrt64\bin;' + $env:PATH
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logPath = Join-Path $repoDir "logs\$stamp-instrument-sim.log"
$outDir = 'E:\gaoyun\tools\smoke'
$rtl = @('i2s_tx16.v','i2c_register_bus.v','ads1015_reader.v','voice_engine.v','instrument_io.v','uart_status.v') |
    ForEach-Object { Join-Path $PSScriptRoot $_ }
Start-Transcript -Path $logPath
try {
    foreach ($name in @('i2s','ads1015','voice','poly','instrument')) {
        $top = "tb_$name"
        $tb = Join-Path $PSScriptRoot "$top.sv"
        $image = Join-Path $outDir "instrument-$name.vvp"
        & $iverilog -g2012 -Wall -s $top -o $image $tb (Join-Path $PSScriptRoot 'ads1015_model.sv') @rtl
        if ($LASTEXITCODE -ne 0) { throw "Compilation failed: $name" }
        & $vvp $image
        if ($LASTEXITCODE -ne 0) { throw "Simulation failed: $name" }
    }
    'ALL INSTRUMENT TESTS PASSED'
} finally { Stop-Transcript }
