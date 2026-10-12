create_project -name instrument_idle_candidate -dir E:/gaoyun/projects/instrument_idle_candidate -pn GW2A-LV18PG256C8/I7 -device_version C -force
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
run all
