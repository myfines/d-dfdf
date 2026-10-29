param([string[]]$Tests=@('tb_keymap','tb_keymap_transport','tb_adsr_long_release','tb_adsr_core','tb_custom_adsr','tb_envelope_control','tb_adsr_transport','tb_voice_gain','tb_audio_fix','tb_fx_stability','tb_fx_gain','tb_mix_headroom','tb_pitch_frame','tb_audio_regression_top','tb_quality','tb_panel_quality','tb_synth32','tb_features','tb_fx','tb_spectrum','tb_oled_ui','tb_song_led','tb_command','tb_core'))
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$env:PATH='E:\gaoyun\tools\openfpgaloader\ucrt64\bin;E:\gaoyun\tools\iverilog\ucrt64\bin;'+$env:PATH
$out=Join-Path $root 'sim/quality-results'
New-Item -ItemType Directory -Force $out | Out-Null
$rtl=@(Get-ChildItem "$root/src/*.v" | Select-Object -ExpandProperty FullName)
foreach($test in $Tests){
 & iverilog -g2012 -s $test -o "$out/$test.vvp" @rtl "$root/sim/ads1015_model.sv" "$root/sim/$test.sv" *> "$out/$test.compile.log"
 if($LASTEXITCODE -ne 0){Get-Content "$out/$test.compile.log";throw "compile $test"}
 & vvp "$out/$test.vvp" *> "$out/$test.log"
 if($LASTEXITCODE -ne 0 -or (Get-Content "$out/$test.log" -Raw) -notmatch 'PASS'){Get-Content "$out/$test.log";throw "test $test"}
 Write-Output "PASS $test"
}
