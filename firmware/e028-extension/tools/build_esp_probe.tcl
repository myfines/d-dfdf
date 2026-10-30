set root [file normalize [file join [file dirname [info script]] ..]]
create_project -name esp_diagnostic_e052 -dir "$::env(FPGA_WEB_PRIVATE)/build" -pn GW2A-LV18PG256C8/I7 -device_version C -force
foreach f {uart8n1.v diagnostic_oled_uart.v esp_at_control.v esp_volume_parser.v esp_http_request.v} {add_file "$root/src/$f"}
add_file "$::env(FPGA_WEB_PRIVATE)/esp_probe_top.v"
add_file "$root/constraints/instrument_e027_ext.cst"
add_file "$root/constraints/instrument.sdc"
set_option -top_module esp_probe_top
set_option -use_sspi_as_gpio 1
set_option -use_jtag_as_gpio 0
set_option -use_mspi_as_gpio 0
set_option -use_reconfign_as_gpio 0
set_option -user_code 0xE053
run all
