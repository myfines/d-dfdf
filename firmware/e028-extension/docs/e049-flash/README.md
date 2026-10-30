# E049 Flash部署：2026-10-30

设备重新识别为单颗GW2A-18C，JTAG ID `0x0000081B`；写入前读回E047/6020。沿用已核对的GW2A-LV18PG256C8/I7与既有CST，引脚/电平没有变更。

已核对E049 fs SHA256 `e9148e835c0dc08b764a16039bb6696e025b285967bbf6f4129d96d5175a6790`。官方Programmer cable-index1、2.5MHz、operation37、SPI起址0x000000执行GAO-Bridge擦除/编程/校验，明确返回 `Program and Verify flash successfully`，耗时28.37秒。没有bulk erase、OTP、下载器固件或ESP固件操作。

写后独立读取E049/6020。随后使用临时E050 SRAM探针做同源集成测试，再恢复正式E049 SRAM，独立读取再次为E049/6020；Flash仍为E049。详见相邻 `../e050-integration/report.json`。这不等于完整断电冷启动测试。

当前正式固件恢复后需要按原流程启用外设：按住S1+S2，按下并松开摇杆，再松开S1/S2；等待保护和初始化。只做一次，重复组合会关闭外设。
