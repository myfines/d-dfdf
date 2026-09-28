create_project -name audio_keys -dir E:/gaoyun/projects/audio_keys -pn GW2A-LV18PG256C8/I7 -device_version C -force
add_file E:/gaoyun/d-dfdf/audio_keys/audio_keys.v
add_file E:/gaoyun/d-dfdf/audio_keys/keys.cst
add_file E:/gaoyun/d-dfdf/audio_keys/keys.sdc
set_option -top_module audio_keys
run all
