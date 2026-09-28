create_project -name audio_probe -dir E:/gaoyun/projects/audio_probe -pn GW2A-LV18PG256C8/I7 -device_version C -force
add_file E:/gaoyun/d-dfdf/audio_probe/audio_probe.v
add_file E:/gaoyun/d-dfdf/audio_probe/audio.cst
add_file E:/gaoyun/d-dfdf/audio_probe/audio.sdc
set_option -top_module audio_probe
run all
