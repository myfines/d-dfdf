create_project -name instrument_e028_ble -dir "E:/DS working space/E027_Ext/proj_ble" -pn GW2A-LV18PG256C8/I7 -device_version C -force
add_file "E:/DS working space/E027_Ext/src/wave_source.v"
add_file "E:/DS working space/E027_Ext/src/synth32.v"
add_file "E:/DS working space/E027_Ext/src/fx_engine.v"
add_file "E:/DS working space/E027_Ext/src/spectrum16.v"
add_file "E:/DS working space/E027_Ext/src/note_router.v"
add_file "E:/DS working space/E027_Ext/src/song_player.v"
add_file "E:/DS working space/E027_Ext/src/led_guide.v"
add_file "E:/DS working space/E027_Ext/src/panel_ctrl.v"
add_file "E:/DS working space/E027_Ext/src/esp_command_parser.v"
add_file "E:/DS working space/E027_Ext/src/oled_i2c_stream.v"
add_file "E:/DS working space/E027_Ext/src/oled_ui.v"
add_file "E:/DS working space/E027_Ext/src/i2s_tx16.v"
add_file "E:/DS working space/E027_Ext/src/ads1015_reader.v"
add_file "E:/DS working space/E027_Ext/src/i2c_register_bus.v"
add_file "E:/DS working space/E027_Ext/src/optical_keys_reader.v"
add_file "E:/DS working space/E027_Ext/src/io_arm_control.v"
add_file "E:/DS working space/E027_Ext/src/gesture_uart_rx.v"
add_file "E:/DS working space/E027_Ext/src/gesture_packet_rx.v"
add_file "E:/DS working space/E027_Ext/src/gesture_expression.v"
add_file "E:/DS working space/E027_Ext/src/uart8n1.v"
add_file "E:/DS working space/E027_Ext/src/uart_status.v"
add_file "E:/DS working space/E027_Ext/src/esp_volume_parser.v"
add_file "E:/DS working space/E027_Ext/src/esp_at_control.v"
add_file "E:/DS working space/E027_Ext/src/wifi_telemetry.v"
add_file "E:/DS working space/E027_Ext/src/instrument_core.v"
add_file "E:/DS working space/E027_Ext/src/instrument_e027_top.v"
add_file "E:/DS working space/E027_Ext/src/instrument_e028_ble_top.v"
add_file "E:/DS working space/E027_Ext/constraints/instrument_e027_ext.cst"
add_file "E:/DS working space/E027_Ext/constraints/instrument.sdc"
set_option -top_module instrument_e028_ble_top
set_option -use_sspi_as_gpio 1
set_option -use_jtag_as_gpio 0
set_option -use_mspi_as_gpio 0
set_option -use_reconfign_as_gpio 0
set_option -user_code 0xE029
run all
