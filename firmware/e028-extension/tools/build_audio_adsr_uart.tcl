set root [file normalize [file join [file dirname [info script]] ..]]
set private $::env(FPGA_WEB_PRIVATE)
create_project -name audio_adsr_uart -dir "$private/build" -pn GW2A-LV18PG256C8/I7 -device_version C -force
foreach f {wave_source.v fx_engine.v i2s_tx16.v uart8n1.v envelope_telemetry.v} {add_file "$root/src/$f"}
add_file "$private/synth32_envelope_probe.v"
add_file "$private/audio_adsr_uart_top.v"
add_file "$root/constraints/instrument_e027_ext.cst"
add_file "$root/constraints/instrument.sdc"
set_option -top_module audio_adsr_uart_top
set_option -use_sspi_as_gpio 1
set_option -use_jtag_as_gpio 0
set_option -use_mspi_as_gpio 0
set_option -use_reconfign_as_gpio 0
set_option -user_code 0xE03C
run all
