# Flash成功与失败对比（2026-10-12）

| 项目 | 2026-09-30成功 | 2026-10-12修正版失败 |
|---|---|---|
| 实际工具路径 | IDE内置Programmer CLI | 同一路径 |
| 操作 | 13 / exFlash Erase,Program,Verify in bscan | 相同 |
| 通道/频率 | FT2CH / cable-index1 / 2.5MHz | 相同 |
| FPGA/Flash ID | 0x81B / 0x0B4017 | 相同 |
| 地址范围 | 0x000000至0x08CE00 | 相同 |
| 写入结果 | 100%、exit0、321.31秒 | 100%、exit0、324.31秒 |
| 写后独立比较 | 未做 | operation15在70%失败、exit67、844.23秒 |
| 冷启动与RCFG | 用户实测四键有声 | 用户重启无响应，串口无新数据 |
| 下载器前序状态 | 刚恢复FTDI连接，未记录COM13音频遥测 | 写入/校验前有多轮COM13遥测，关闭端口但未每次重新插拔USB |
| 码流/设计 | 已验证单音audio_keys | 已验证SRAM的修正版复音instrument_io |

旧码流仍在本地，SHA256 2D155BB754EC8C6238C57320220F5EE24E029907742F575C61FB7C61D5B4162E，与当年记录一致。当前目标SHA256 9DA141FDAF59E24E1FE10ED352389D8B3D8CE2DC0B1283A2B4A3B317FB99E561。文本文件大小均4620698字节；型号C、LoadingRate2.5MHz、CRC ON、Compress OFF、Encryption OFF、Security ON、SecureMode OFF、JTAG IO OFF、MultiBoot地址0等头配置逐项相同。硬件设计/配置载荷不同，不能宣称二者启动等效。

最值得先排除的变量是BL702下载器串口使用后的状态。Sipeed官方FAQ明确提示使用串口时JTAG不可用，并建议拔插USB恢复：https://wiki.sipeed.com/hardware/zh/tang/Tang-Nano-Doc/questions.html 。这与两次流程差异有联系，但不是已证实的根因；不能将bscan比较失败直接解释为Flash写入坏数据或芯片损坏。

接下来应先确认使能拨码ON并恢复干净USB连接，关闭所有串口、不打开COM13，进行JTAG检测。用仍有正确hash的历史成功码流做受控持久化对照（会暂时替换Flash应用，需明确告知），以独立校验和无SRAM下载的冷启动为成功标准。旧设计成功而新设计失败，才能更有力地定位新码流/启动配置；两者均失败，则优先下载器/连接/Flash访问路径。官方GAO-Bridge是之后的可选路径，不能提前当作已证明的解决方案。

本次仅读取日志/码流/工具帮助，没有烧录或驱动修改。当前USB未枚举下载器，尚未开展上述硬件对照。
