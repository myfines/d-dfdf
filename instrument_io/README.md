# 外接 PCM5102A + ADS1015 摇杆首版程序

2026-10-12 状态：源码、独立协议仿真、整机仿真以及高云综合/布局布线已完成。已通过高云官方 Programmer 下载到 **SRAM**，退出码0，状态0x00006020 / Done Final；上一版外部ADC/DAC已获用户整体通过反馈。现有Flash四键程序未改写。现升级为四键独立复音，尚非赛事最终多音色引擎；新版实物反馈待确认。

## 接线

使用 Dock PMOD0，没有其他模块占用该接口；按 PCB 背面丝印定位，正反面位置互为镜像。

| 功能 | 模块引脚 | FPGA/Dock 接点 |
|---|---|---|
| I²C 时钟 | ADS1015 SCL | T6 |
| I²C 数据 | ADS1015 SDA | T7 |
| 摇杆按键 | 摇杆 SW | T8 |
| I²S 数据 | PCM5102A DATA | P6 |
| I²S 位时钟 | PCM5102A BCK | R8 |
| I²S 声道时钟 | PCM5102A LRCK | P8 |
| 电源 | ADS1015 VDD、摇杆标 +5V 的供电脚 | Dock 真正 3V3 电源，不是 GPIO |
| 共地 | 全部模块 GND、ADS1015 ADDR | Dock GND |
| 摇杆两轴 | VRX、VRY | ADS1015 A0、A1 |

ADS1015 ALRT/A2/A3 首版不接，ADDR 接地，地址 0x48。PCM 使用 USB-C 入口供电，+3.3V 排针悬空；实物对照中排针供电无声，USB供电成功。完整电源核对见 [模块接线表](../docs/module-wiring-20261011.md)。上电前核对真实3.3V和极性。

## 行为

- S0/S1/S2/S3 分别为 C5/D5/E5/G5；四键各有独立振荡器和包络，可同时发声；总和固定除以4，单键约为上一版四分之一音量。按下立即开始约1ms起音，松开有约5ms释放消抖和约5.5ms音量淡出。
- 摇杆 X 默认中点为 ADC 825 码，有 ±25 码死区；左右连续弯音约 ±10%，不是精确半音刻度。该中点来自3.3V激励、±4.096V量程，实物偏差后续校准。
- 摇杆 Y 将三角波与锯齿波混合。它们都来自连续相位；锯齿波首版没有做抗混叠处理。
- 按住摇杆按键降低一个八度，松开恢复，按键稳定约5ms才改变。
- N16/LED2 为心跳；N14/LED3 常亮表示已成功获取一对 ADC 两轴数据。ADC 不接、不应答或总线故障时，控制失效后退回中性音高和三角波，四键仍可发声；LED3 熄灭并定时重试。
- 输出为相同的左右声道、16位二补码标准 I²S：WS 提前一位，BCLK 1.5MHz，LRCK 46.875kHz，32 BCLK/立体声帧。不是48kHz；这是27MHz整数分频的接口联调设置。TI PCM5102A 数据手册第15/25页支持16位、32fs三线I²S模式；本模块PLL是否锁定必须实测。
- 输出限制到四分之一数字满幅，仍是线路输出。使用有源音箱/耳放；代码关闭板载 PT8211 时钟/数据与 LPA4809 耳放，所以装入此版后 Dock 原耳机口不作为测试输出。

## ADC 实现

I²C 约100kHz，SCL/SDA只输出0或高阻，允许时钟拉伸。配置写入 0xC383/0xD383：单次转换、A0/A1对地、±4.096V、1600SPS、比较器关闭。每次配置后等待1ms再读转换寄存器；两轴交替，整对数据发布。实际每轴更新只有数百次/秒，不能把芯片1600SPS配置值当作每轴软件更新率。

NACK 会停止交易并回到中性控制；SCL被拉低约10ms则释放总线并报错；空闲时SDA低会执行9个恢复时钟和STOP，交易失败后等待约10ms重试。硬件测试前必须确认模块供电，不在模块未供电时只给FPGA启用接口。

## 复现

仿真：

```powershell
pwsh -NoProfile -File E:\gaoyun\d-dfdf\instrument_io\run_tests.ps1
```

五组测试覆盖：I²S真实总线解码与帧一致性；ADS1015从机模型的配置、地址、字节、ACK/NACK、拉伸、断连及卡线恢复；声音的频率、弯音、音色、八度、幅度、静音；复音叠加、单独松键与四键混音幅度；整机实际BCLK频率和未接ADC时的声音输出。

构建（会重新生成独立工程，不操作板卡）：

```powershell
& 'E:\gaoyun\tools\gowin\Gowin_V1.9.11.03_Education\Gowin_V1.9.11.03_Education_x64\IDE\bin\gw_sh.exe' `
  E:\gaoyun\d-dfdf\instrument_io\build.tcl
```

芯片 GW2A-LV18PG256C8/I7、C版本；仅开启SSPI作为GPIO供S0使用，JTAG/MSPI/RECONFIG_N保持专用。SDC用CRLF。

码流在 `E:/gaoyun/projects/instrument_io/instrument_io/impl/pnr/instrument_io.fs`，便捷副本 `E:/gaoyun/instrument_io.fs`；最终身份和内部时序摘要见 `logs/20261012-instrument-checks.json`。FS按仓库约定不提交Git。编译成功不代表模块供电、ADC实测值、模拟声音或外部接口时序已经验证。

本次用户确认接线与供电后，使用高云官方 Programmer 的 **SRAM Program（operation 2）**，2.5MHz，完成该码流加载，见 `logs/20261012-instrument-sram-program.out.txt`。下一步观察N16心跳、N14 ADC有效灯，并用外部线路输入设备测试声音和摇杆控制。没有写Flash；掉电/RCFG将回到旧Flash四键程序。

实物供电修正（2026-10-12）：该 SLK PCM 模块用 USB-C 入口供电，排针 +3.3V 不连接 Dock。保留 DATA/BCK/LRCK/GND 四线。相同诊断码流由排针3.3V供电时无声，改USB供电后用户确认持续测试音。不得并接两路电源；具体内部供电轨尚未测量确认。

2026-10-12：四键＋摇杆 instrument_io SRAM 下载后，用户对四键声音、摇杆变化、ADC灯的组合测试反馈为“ok”（未分项描述）。当前 Flash 仍保留此前 audio_keys 程序。

2026-10-12 最新持久化状态：用户授权当前复音版写Flash，官方operation13完成100%、exit0（324.13秒）。当前Flash为instrument_io复音版，SHA256 ADE8A08C908A4B7B0380E28856E07E627B258CDB513D51E176E542F845BA8A4F，掉电自启动测试待用户反馈。S3/音调异常反馈未解决。此前“Flash仍为audio_keys”的记录属于旧状态。


S3持续音修正（2026-10-12）：实物复音监测发现旧掩码版本K=F而包络活动Y001；改为每声部一个按键输入和固定音符后，SRAM实测K=F、Y000。UART为COM13、115200/8N1；当前Y字段用于诊断包络是否活动，并非摇杆Y读数。此次修正版只载入SRAM，Flash仍是此前含问题的复音版，待试听后更新。

最新Flash状态（2026-10-12）：直接单键声部修正版已用官方operation13写入100%、exit0，耗时324.31秒；SHA256 9DA141FDAF59E24E1FE10ED352389D8B3D8CE2DC0B1283A2B4A3B317FB99E561。此前“Flash仍为问题版”现已过时。修正版掉电启动验证待反馈，音质因音箱限制尚无法判断。

重要状态修正（2026-10-12）：上述Flash写入虽然工具exit0，用户冷启动无响应；随后operation15独立比较到70%报SPI Verify failed、exit67。故当前Flash持久化未验证成功。现已恢复9DA141...E561修正版SRAM，UART/ADC正常；断电或RCFG可能再次无法启动。原因是Flash内容或读链路不一致，尚不能证明芯片损坏。

2026-10-12最新Flash状态：干净USB连接、全程不打开串口，官方operation37 GAO-Bridge将9DA141...E561修正版复音写入Flash并明确校验成功（Program and Verify flash successfully），exit0、20.19秒。冷启动功能验证待反馈。此成功取代此前bscan校验失败的烧录状态；不证明此前单一根因。

当前最终状态（2026-10-12）：官方GAO-Bridge operation37写入/校验通过后，用户按全断电重启、不下载SRAM的条件测试全松静音、S0–S3和混音，反馈“ok了”。修正版复音Flash自启动已通过；音质尚未量化验证。
