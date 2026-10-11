# ADS1015、PS2 摇杆与 PCM5102A 接线（2026-10-11）

依据用户四张模块照片、`E:/gaoyun/75107/资料/ADS1015/` 和 Sipeed 官方 Dock-3713/SOM-3961 原理图。没有执行硬件下载或改写 Flash。下列信号位置是下一版程序的计划约束；现在 Flash 的四键程序只驱动板载 PT8211，不会自动驱动 ADS1015 或外接 PCM5102A。

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

## PCM5102A 信号规划与待确认供电

用户照片 3 背面五针丝印顺序为 DATA、BCK、LRCK、+3.3V、GND。信号规划：

| PCM5102A 引脚 | 接到 |
|---|---|
| DATA | Dock PMOD0 的 P6（I²S 串行数据） |
| BCK | Dock PMOD0 的 R8（I²S 位时钟） |
| LRCK | Dock PMOD0 的 P8（左右声道时钟） |
| GND | Dock GND，共地 |
| +3.3V | **暂不接 Dock**，不能仅凭丝印确定它是供电输入还是 USB 供电后的电源引出 |

该 SLK AUDIO 模块有 USB-C 和多颗稳压器，卖家模块原理图未提供，三个淘宝短链也未能读取到说明。先让五针全部悬空，使用普通 USB 5 V 电源给 USB-C 单独供电，测 +3.3V 对 GND 的实际电压；确认电源状态后才连接信号与共地。USB-C 与 Dock 3V3 不同时并接。没有供电验证前，不宣称这块模块已经具备完整、安全的上电接法。

PCM5102A 芯片为线路输出，不能凭 3.5 mm 插座判断有耳机放大器。接有源音箱/耳放的线路输入；未确认该模块有耳放时不直接接低阻耳机。

## 整块直插方案

三块模块排针顺序与 PMOD 不一致，不能裸插 Dock，也不能用 GPIO 高低电平代替电源和地。可用洞洞板或小 PCB 做 PMOD0 转接板：底部 2×6 PMOD 接口，上面分别放匹配 ADC、DAC 和摇杆排针的连接器，供电与信号在板上走线。先按本表验证模块，再固定连接器和机械方向。背面引脚图与正面观察互为镜像，最终按丝印核对。

参考：
- Sipeed 原理图目录：<https://dl.sipeed.com/shareURL/TANG/Primer_20K/02_Schematic>
- Adafruit 接线说明：<https://learn.adafruit.com/adafruit-4-channel-adc-breakouts/assembly-and-wiring>
- TI ADS1015：<https://www.ti.com/product/ADS1015>
- TI PCM5102A：<https://www.ti.com/lit/ds/symlink/pcm5102a.pdf>
