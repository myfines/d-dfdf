set root [file normalize [file join [file dirname [info script]] ..]]
set private $::env(FPGA_WEB_PRIVATE)
# Derive capture attenuation from the public probe source; production gain is unchanged.
set source_fd [open "$root/src/audio_delivery_probe.v" r]
set probe_source [read $source_fd]
close $source_fd
if {[string first "CAPTURE_SHIFT=4" $probe_source] < 0} { error "probe attenuation token missing" }
set target_fd [open "$private/audio_delivery_probe_e048.v" w]
puts -nonewline $target_fd [string map {CAPTURE_SHIFT=4 CAPTURE_SHIFT=2} $probe_source]
close $target_fd
create_project -name audio_delivery_probe_e048 -dir "$private/build" -pn GW2A-LV18PG256C8/I7 -device_version C -force
foreach f {wave_source.v synth32.v fx_engine.v i2s_tx16.v uart8n1.v} { add_file "$root/src/$f" }
add_file "$private/audio_delivery_probe_e048.v"
add_file "$root/constraints/instrument_e027_ext.cst"
add_file "$root/constraints/instrument.sdc"
set_option -top_module audio_delivery_probe
set_option -use_sspi_as_gpio 1
set_option -use_jtag_as_gpio 0
set_option -use_mspi_as_gpio 0
set_option -use_reconfign_as_gpio 0
set_option -user_code 0xE048
run all
