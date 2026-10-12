# ADS1015、PS2 摇杆与 PCM5102A 接线（2026-10-11）

依据用户四张模块照片、`E:/gaoyun/75107/资料/ADS1015/` 和 Sipeed 官方 Dock-3713/SOM-3961 原理图。下列信号已用于 2026-10-12 编译成功的 [instrument_io 程序](../instrument_io/README.md)，但尚未下载/实测。现在 Flash 的四键程序只驱动板载 PT8211，不会自动驱动 ADS1015 或外接 PCM5102A。

## 接口选择

使用 Dock 的 **PMOD0**（MIC ARRAY 附近），按板背面的 FPGA 球位丝印找孔，不按未经核对的左右顺序插入。官方背面图：<https://wiki.sipeed.com/hardware/zh/tang/tang-primer-20k/assets/dock-back.png>。

PMOD0 的两组信号为 T6/T7/T8/T9 和 P6/R8/P8/P9，另有真实 GND、3V3。所选信号属于 bank 3；SOM-3961 原理图显示 bank 3 电源直接接 +3V3。PMOD0 必须没有其他已连接模块，尤其麦克风阵列。

## 可以先接的 ADC 与摇杆

所有接线先断开 Dock 及模块供电。

| 模块引脚（按丝印） | 接到 |
|---|---|
| ADS1015 VDD | Dock PMOD0 的 3V3 电源 |
| ADS1015 GND | Dock PMOD0 的 GND |
| ADS1015 SCL | Dock PMOD0 的 T6 |
| ADS1015 SDA | Dock PMOD0 的 T7 |
| ADS1015 ADDR | GND，选择 7 位 I²C 地址 0x48 |
| ADS1015 A0 | 摇杆 VRX |
| ADS1015 A1 | 摇杆 VRY |
| ADS1015 ALRT、A2、A3 | 第一阶段不接 |
| 摇杆 GND | 同一 GND |
| 摇杆 +5V | **同一 3V3 电源**；本电位器模块用 3.3 V 激励，让 VRX/VRY 范围约为 0–3.3 V |
| 摇杆 SW | Dock PMOD0 的 T8；下一版程序将其设为带上拉输入，按下接地 |

不要给摇杆 +5V 脚接 5 V，同时让 ADS1015 用 3.3 V。ADC 的可测模拟电压受实际供电约束，PGA 的 ±6.144 V 量程不代表输入脚可超过电源电压。模块照片中可见上拉电阻，但其实际电阻值和走线尚未实测；首次通电先测 VDD 及空闲 SCL/SDA 对地约 3.3 V。

资料说明：本地 Adafruit PDF 给出 VDD/GND/SCL/SDA/ADDR 接法，ADDR 接 GND 为 0x48。`ads1115.pdf` 是 ADS1115 数据手册；本模块丝印 ADS1015，软件须采用 12 位数据格式。ADS1015 最高转换率为总计 3300 SPS，不能实现旧采购计划中的每轴 2 kSPS；两轴将先按较低速率轮流采样。

## PCM5102A 信号规划与同布局模块供电资料

用户照片 3 背面五针丝印顺序为 DATA、BCK、LRCK、+3.3V、GND。信号规划：

| PCM5102A 引脚 | 接到 |
|---|---|
| DATA | Dock PMOD0 的 P6（I²S 串行数据） |
| BCK | Dock PMOD0 的 R8（I²S 位时钟） |
| LRCK | Dock PMOD0 的 P8（左右声道时钟） |
| GND | Dock GND，共地 |
| +3.3V | **Dock PMOD0 真实 3V3 电源**；2026-10-12 用户提供同款商家客服确认可从该脚输入3.3V。采用此方式时 DAC USB-C 不连接电源 |

后续检索找到[同布局旧版模块商品说明](https://www.ruten.com.tw/item/22201678843542/)，图中同样有三颗稳压器、大电解电容、3.5 mm 插座和五针接口。旧版为绿色 PCB/Micro-USB，页面说明 2021-03-03 将 USB 改为 Type-C；五针顺序为 DATA/BCK/LRCK/3.3V 输出/GND，USB 供电为直流 5V。与用户黑色 SLK AUDIO 板照片高度相似，但未取得黑板的完整原理图，不能断言所有版本电路完全相同。

2026-10-12 用户提供“声洛科音频”客服截图，客服明确回答该脚可供电输入，前端USB5V经LDO转换3.3V，输入该脚不能超压。这是比同布局旧版说明更直接的同款模块信息。因此首选五根杜邦线接 DATA/P6、BCK/R8、LRCK/P8、+3.3V/PMOD0真实3V3、GND/GND，DAC USB-C保持不接，不需从Dock OTG取5V。先断电接线，核对极性，用标称稳定3.3V电源，禁止5V接此脚。客服确认是接法依据，尚无本模块上电/音频实测。

另一种独立供电方式仍可用USB-C普通5V电源，但那时+3.3V引脚不接Dock，避免电源并接。USB-C在此用于供电，不是USB音频数据输入。未确认型号的PAM功放不沿用此供电结论。

开源参考（不同电路板，不能作为本模块实际走线证据）：[PCM5102A 信号发生器](https://github.com/igor-gia/audio-signal-generator)提供硬件原理图与代码；[PCM5102A 蓝牙接收器](https://github.com/uhucrew/bt-receiver-pcm5102a)提供三线 I²S 应用。这些可参考协议、时钟与音频实现，不能据此修改本板供电脚接法。

PCM5102A 芯片为线路输出，不能凭 3.5 mm 插座判断有耳机放大器。接有源音箱/耳放的线路输入；未确认该模块有耳放时不直接接低阻耳机。

## 整块直插方案

三块模块排针顺序与 PMOD 不一致，不能裸插 Dock，也不能用 GPIO 高低电平代替电源和地。可用洞洞板或小 PCB 做 PMOD0 转接板：底部 2×6 PMOD 接口，上面分别放匹配 ADC、DAC 和摇杆排针的连接器，供电与信号在板上走线。先按本表验证模块，再固定连接器和机械方向。背面引脚图与正面观察互为镜像，最终按丝印核对。

参考：
- Sipeed 原理图目录：<https://dl.sipeed.com/shareURL/TANG/Primer_20K/02_Schematic>
- Adafruit 接线说明：<https://learn.adafruit.com/adafruit-4-channel-adc-breakouts/assembly-and-wiring>
- TI ADS1015：<https://www.ti.com/product/ADS1015>
- TI PCM5102A：<https://www.ti.com/lit/ds/symlink/pcm5102a.pdf>

## 减少 USB 供电线：Dock OTG 与杜邦供电

供电措辞更正：TI 数据手册第5页引脚表与第28页电源章节明确 AVDD（8脚）和 CPVDD（1脚）使用3.3V，DVDD（20脚）可使用1.8V或3.3V；芯片本体不要求USB/5V。模块USB5V是稳压器前端供电。不能断言所有标为3.3V输出的模块都不能由外部3.3V供电：若该脚连通全部所需电源轨、稳压器和其他电路允许旁路/反向电流，可能可行。仅芯片数据手册不能批准模块排针供电；2026-10-12商家随后明确确认该模块3.3V排针可作为供电输入，故按上面的五根杜邦线方案采用Dock真实3V3供电、DAC USB不接。板级原理图及实测电压仍未取得。照片USB附近两孔也只是候选，未确认是5V/GND，不应直接接入电源。

TI原始数据手册已保存 `E:/gaoyun/75107/资料/PCM5102A/pcm5102a-ti.pdf`。来源：<https://www.ti.com/lit/ds/symlink/pcm5102a.pdf>。

Dock-3713 原理图 P002_USB PHY（PDF 第5页）显示 J8 VBUS 直接连接板上 +5V，而 CC1/CC2 经 R38/R39 5.1k 下拉到 GND；SW2 改变 USB_ID，不切换 CC 为供电端上拉。故有板上5V电源不等于标准 Type-C source，普通 C-to-C 直接连同样为受电端的 DAC 不能保证供电。DAC 的 USB 接口用于供电，不承担USB音频解码。

若只用杜邦线供 DAC，需要找到 DAC 真正的5V输入：照片USB附近两个空焊孔可能是预留电源口，但正负及其用途未确认。断电用万用表确认与 USB VBUS/GND 的连通关系，核实5V输入后才焊接排针；接 Dock 真正+5V电源和GND，不接GPIO或PMOD3V3，且不再接另一USB电源。不要把5V送入DAC标为+3.3V的输出脚。也可用已明确引出VBUS/GND的USB-C供电转接板接DAC USB口；它需要按供电端用途选型，并确认5V电源总电流足够，不能把两个独立5V源并接。
