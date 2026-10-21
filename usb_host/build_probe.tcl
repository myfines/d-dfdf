create_project -name k230_usb_host_probe -dir E:/gaoyun/projects/k230_usb_host_probe -pn GW2A-LV18PG256C8/I7 -device_version C -force
add_file E:/gaoyun/tools/smoke/k230_usb_host_generated.v
add_file E:/gaoyun/d-dfdf/usb_host/host_probe_top.v
add_file E:/gaoyun/d-dfdf/instrument_io/gesture_packet_rx.v
add_file E:/gaoyun/d-dfdf/instrument_io/uart8n1.v
add_file E:/gaoyun/d-dfdf/usb_host/host_probe.cst
add_file E:/gaoyun/d-dfdf/usb_host/host_probe.sdc
set_option -top_module host_probe_top
set_option -use_jtag_as_gpio 0
set_option -use_mspi_as_gpio 0
set_option -use_reconfign_as_gpio 0
set_option -user_code 0xE024
run all
