set root [file normalize [file join [file dirname [info script]] ..]]
set private $::env(FPGA_WEB_PRIVATE)
create_project -name instrument_e031 -dir "$private/build" -pn GW2A-LV18PG256C8/I7 -device_version C -force
add_file "$root/src/wave_source.v"
add_file "$root/src/synth32.v"
add_file "$root/src/fx_engine.v"
add_file "$root/src/spectrum16.v"
add_file "$root/src/note_router.v"
add_file "$root/src/song_player.v"
add_file "$root/src/led_guide.v"
add_file "$root/src/panel_ctrl.v"
add_file "$root/src/esp_command_parser.v"
add_file "$root/src/oled_i2c_stream.v"
add_file "$root/src/oled_ui.v"
add_file "$root/src/i2s_tx16.v"
add_file "$root/src/ads1015_reader.v"
add_file "$root/src/i2c_register_bus.v"
add_file "$root/src/optical_keys_reader.v"
add_file "$root/src/io_arm_control.v"
add_file "$root/src/gesture_uart_rx.v"
add_file "$root/src/gesture_packet_rx.v"
add_file "$root/src/gesture_expression.v"
add_file "$root/src/uart8n1.v"
add_file "$root/src/uart_status.v"
add_file "$root/src/esp_volume_parser.v"
add_file "$root/src/esp_at_control.v"
add_file "$root/src/esp_http_request.v"
add_file "$root/src/esp_http_rom.v"
add_file "$root/src/wifi_telemetry.v"
add_file "$root/src/instrument_core.v"
add_file "$root/src/instrument_cloud_top.v"
add_file "$root/src/esp_cloud_control.v"
add_file "$private/cloud_config.v"
add_file "$root/constraints/instrument_e027_ext.cst"
add_file "$root/constraints/instrument.sdc"
set_option -top_module instrument_cloud_top
set_option -use_sspi_as_gpio 1
set_option -use_jtag_as_gpio 0
set_option -use_mspi_as_gpio 0
set_option -use_reconfign_as_gpio 0
set_option -user_code 0xE031
run all
