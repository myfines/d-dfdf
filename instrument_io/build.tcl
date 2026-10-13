create_project -name instrument_io -dir E:/gaoyun/projects/instrument_io -pn GW2A-LV18PG256C8/I7 -device_version C -force
add_file E:/gaoyun/d-dfdf/instrument_io/instrument_io.v
add_file E:/gaoyun/d-dfdf/instrument_io/voice_engine.v
add_file E:/gaoyun/d-dfdf/instrument_io/i2s_tx16.v
add_file E:/gaoyun/d-dfdf/instrument_io/ads1015_reader.v
add_file E:/gaoyun/d-dfdf/instrument_io/i2c_register_bus.v
add_file E:/gaoyun/d-dfdf/instrument_io/instrument.cst
add_file E:/gaoyun/d-dfdf/instrument_io/instrument.sdc
set_option -top_module instrument_io
set_option -use_sspi_as_gpio 1
set_option -use_jtag_as_gpio 0
set_option -use_mspi_as_gpio 0
set_option -use_reconfign_as_gpio 0
add_file E:/gaoyun/d-dfdf/instrument_io/uart_status.v
add_file E:/gaoyun/d-dfdf/instrument_io/adsr_envelope.v
add_file E:/gaoyun/d-dfdf/instrument_io/adsr_runtime.v
add_file E:/gaoyun/d-dfdf/instrument_io/instrument_panel.v
add_file E:/gaoyun/d-dfdf/instrument_io/wave_source.v
add_file E:/gaoyun/d-dfdf/instrument_io/short_delay.v
add_file E:/gaoyun/d-dfdf/instrument_io/spectrum_bank.v
add_file E:/gaoyun/d-dfdf/instrument_io/mode_router.v
add_file E:/gaoyun/d-dfdf/instrument_io/optical_keys_reader.v
add_file E:/gaoyun/d-dfdf/instrument_io/optical_key_allocator.v
add_file E:/gaoyun/d-dfdf/instrument_io/io_arm_control.v
run all
