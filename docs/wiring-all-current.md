# 全部接线总表（当前模块方案）

更新：2026-10-12。硬件：Tang Primer 20K + Dock、PCM5102A、ADS1015、PS2摇杆、亚博YB-MX04-1.0八路巡线模块、照片中的红壳ST-Link V2。

**状态：原PCM/ADS/摇杆已用于现有7799固件；八路模块T9/P9是新增接线方案，7799尚无其驱动，未确认实际接线和运行。此前核心板快速发热的原因仍待查。这份表记录连接，不代表解除热故障或指示带电插拔。**

## 1. USB与供电

| 起点 | 终点 | 作用 |
|---|---|---|
| 电脑USB | Dock USB-JTAG | Dock供电和下载；1号核心板使能拨码ON |
| 普通USB 5V电源/电脑USB | PCM5102A USB-C | PCM供电 |
| 电脑USB | ST-Link USB-A | 供给巡线模块的5V来源 |
| ST-Link **9脚，5.0V** | 八路模块 **5V** | 模块电源，按照片壳标编号找脚 |
| ST-Link **5脚，GND** | 八路模块 **GND** | 模块电源地 |
| ST-Link **6脚，GND** | Dock **真实GND** | 用第二个GND直接完成共地，不需地线分叉 |

ST-Link 5/6为同一GND网络的两个接点，按其标注分别接模块和Dock。10脚虽同标5.0V，本方案不使用；7/8的3.3V及所有调试脚不接。照片能核对标注，未测定该具体ST-Link的输出电压或带载能力。

**所有GND共参考；ST-Link的5V不接Dock的3V3、GPIO或核心板。PCM使用USB供电时，其+3.3V排针保持悬空。**

## 2. PCM5102A

| PCM丝印 | Dock接点 |
|---|---|
| DATA | **P6** |
| BCK | **R8** |
| LRCK | **P8** |
| GND | **真实GND** |
| +3.3V | **不接**（已由USB-C供电） |
| 3.5mm音频输出 | 有源音箱AUX/LINE IN |

音箱自身正常供电；不用Dock旧耳机口代替外接PCM输出。

## 3. ADS1015与摇杆

| 起点 | 终点 |
|---|---|
| ADS **VDD** | Dock **真实3V3** |
| ADS **GND** | Dock **真实GND** |
| ADS **SCL** | Dock **T6** |
| ADS **SDA** | Dock **T7** |
| ADS **ADDR** | GND，选择地址0x48 |
| 摇杆 **GND** | Dock真实GND |
| 摇杆标 **+5V** 的供电脚 | **Dock真实3V3**（本方案用3.3V激励） |
| 摇杆 **VRX** | ADS **A0** |
| 摇杆 **VRY** | ADS **A1** |
| 摇杆 **SW** | Dock **T8** |

ADS的ALRT、A2、A3不接。摇杆VRX/VRY不直接接FPGA GPIO。多个3V3/GND接点不够时可用面包板电源轨分配，不能拿GPIO当电源。

## 4. 八路巡线模块新增接口

电源已列在第1表：**ST-Link9→模块5V；ST-Link5→模块GND；ST-Link6→Dock GND。**再接两根信号：

| 八路模块丝印 | Dock接点 |
|---|---|
| **SCL** | **T9** |
| **SDA** | **P9** |

用底部排针上5V/GND/SCL/SDA对应脚，或右侧白色I2C座。专用PDF图正面KEY在左、白座在右时，右座四位丝印为GND/SDA/SCL/5V；左座RX/TX/GND/5V是串口，不选它。排线可能反向，按两端丝印逐线核对。

其KEY、RESET、X1–X8、TX、RX、背面3.3V/SWIM调试焊盘不接FPGA。厂家对应款确认5V供电、3.3V通信： https://category.yahboom.net/products/8-lp 。5V供电不意味着SCL/SDA是5V；若实物空闲通信电平为5V，不得硬接，要先使用双向I2C电平转换。

独立I2C7位地址0x12、状态寄存器0x30，与ADS总线T6/T7分开。T9/P9经SOM和Pnr核对为bank3/3.3V、未用于其他当前模块；新程序需实现对应开漏接口。当前7799接上线也不会识别八路键。

首次校准先只给巡线模块接5V/GND，FPGA断电、SCL/SDA悬空。上电等至少20秒；在实际使用高度对黑/白面各静止3秒再短按模块KEY采样，成功红灯熄灭。校准值断电保存。详见[eightway-wiring.md](eightway-wiring.md)。

## 5. Dock PMOD0占用一览

按PCB背面球位丝印找孔，不用图片左右顺序猜；背面与正面视角可能镜像。

| Dock接点 | 已分配功能 |
|---|---|
| T6 | ADS SCL |
| T7 | ADS SDA |
| T8 | 摇杆SW |
| T9 | 八路模块SCL（新增、待固件） |
| P6 | PCM DATA |
| R8 | PCM BCK |
| P8 | PCM LRCK |
| P9 | 八路模块SDA（新增、待固件） |
| 3V3 | ADS与摇杆电源 |
| GND | 所有模块共地 |

PMOD0不能同时再插其他麦克风阵列或扩展板。

## 6. 板载信号，不需外接杜邦线

S0/T10、S1/T3、S2/T2、S3/D7；27MHz时钟/H11；心跳/N16；ADC有效指示/N14。RCFG为硬件重配置键，不是第五个演奏键。

## 核对依据

用户模块照片、专用八路模块使用PDF、MSPM0八路示例的接线/协议、Sipeed Dock-3713/SOM-3961原理图及当前Pnr引脚表。以本总表为当前汇总，历史方案或操作日志中的早期接法不替代本表。

2026-10-12更新：八路接口候选固件已离线实现、18组回归和编译通过，尚未部署，当前7799仍不识别新模块；见[候选程序说明](optical-program-candidate.md)。
