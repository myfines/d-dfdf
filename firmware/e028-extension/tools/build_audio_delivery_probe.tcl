set root [file normalize [file join [file dirname [info script]] ..]]
set private $::env(FPGA_WEB_PRIVATE)
create_project -name audio_delivery_probe -dir "$private/build" -pn GW2A-LV18PG256C8/I7 -device_version C -force
foreach f {wave_source.v synth32.v fx_engine.v i2s_tx16.v uart8n1.v audio_delivery_probe.v} { add_file "$root/src/$f" }
add_file "$root/constraints/instrument_e027_ext.cst"
add_file "$root/constraints/instrument.sdc"
set_option -top_module audio_delivery_probe
set_option -use_sspi_as_gpio 1
set_option -use_jtag_as_gpio 0
set_option -use_mspi_as_gpio 0
set_option -use_reconfign_as_gpio 0
set_option -user_code 0xE043
run all
