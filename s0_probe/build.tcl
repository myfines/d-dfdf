create_project -name s0_probe -dir E:/gaoyun/projects/s0_probe -pn GW2A-LV18PG256C8/I7 -device_version C -force
add_file E:/gaoyun/d-dfdf/s0_probe/s0_probe.v
add_file E:/gaoyun/d-dfdf/s0_probe/s0.cst
add_file E:/gaoyun/d-dfdf/s0_probe/s0.sdc
set_option -top_module s0_probe
set_option -use_sspi_as_gpio 1
set_option -use_jtag_as_gpio 0
set_option -use_mspi_as_gpio 0
set_option -use_reconfign_as_gpio 0
run all
