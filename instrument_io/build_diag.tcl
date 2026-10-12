create_project -name instrument_diag -dir E:/gaoyun/projects/instrument_diag -pn GW2A-LV18PG256C8/I7 -device_version C -force
add_file E:/gaoyun/d-dfdf/instrument_io/instrument_diag.v
add_file E:/gaoyun/d-dfdf/instrument_io/uart_status.v
add_file E:/gaoyun/d-dfdf/instrument_io/i2s_tx16.v
add_file E:/gaoyun/d-dfdf/instrument_io/ads1015_reader.v
add_file E:/gaoyun/d-dfdf/instrument_io/i2c_register_bus.v
add_file E:/gaoyun/d-dfdf/audio_keys/audio_keys.v
add_file E:/gaoyun/d-dfdf/instrument_io/diag.cst
add_file E:/gaoyun/d-dfdf/instrument_io/instrument.sdc
set_option -top_module instrument_diag
set_option -use_sspi_as_gpio 1
set_option -use_jtag_as_gpio 0
set_option -use_mspi_as_gpio 0
set_option -use_reconfign_as_gpio 0
run all
