# 开源 FPGA 调试方法与本工程应用

研究日期：2026-10-30。对象：Tang Primer 20K / GW2A-LV18PG256C8/I7、E049、App 0.12。本轮为资料研究和本机工具只读检查，没有编译、下载、烧录或改变电脑网络。

## 结论

现有“仿真—诊断码流—SRAM试运行—正式Flash”的方向合理。下一步最有价值的改进，是在真实手机、光键、手势共同工作时留下内部事件记录，并用固定刺激和参考结果复现故障。无需为交付临时更换工具链，也不能用注入测试替代真实输入链路验收。

## 阅读的开源方案

| 来源 | 实际学习内容 | 对我们适用的部分与限制 |
|---|---|---|
| [Sipeed Primer20K examples](https://github.com/sipeed/TangPrimer-20K-example) | README、DDR-test README、PT8211驱动 | 分模块测试、串口报告；同开发板有参考价值。PT8211协议与引脚不能照搬到PCM5102A标准I2S。 |
| [noaidi-fpga-synth](https://github.com/Thorwegian/noaidi-fpga-synth) | README、tools/lab/README.md、docs/gowin_oss_notes.md、baseline_check.py、chip_check.py | 最接近的音乐合成案例：参考录音、频谱/包络比较、芯片状态回读、带随机种子和时间抖动的控制压力测试。它用Nano20K/GW2AR、不同控制器和采样时钟，不能直接搬架构或参数。 |
| [ZipCPU wbscope](https://github.com/ZipCPU/wbscope) | README | 触发式环形采样，保留故障前后数据、主机导出VCD。它依赖Wishbone/AXI，不是可直接接入本工程UART的模块。 |
| [cocotb](https://github.com/cocotb/cocotb) / [SymbiYosys](https://github.com/YosysHQ/sby) | 各README | 独立参考模型、随机测试；FIFO、调度期限、控制权等局部不变量适合形式验证。当前Icarus回归仍可继续使用，本轮未运行新形式证明。 |
| [libsigrokdecode I2S](https://github.com/sigrokproject/libsigrokdecode/blob/master/decoders/i2s/pd.py) | 解码器源码 | 在实际BCK/WS/DATA线上核对边沿、字宽和帧。数字解码不能证明DAC模拟延迟。 |
| [openFPGALoader](https://github.com/trabucayre/openFPGALoader) | README、本机帮助及板型列表 | 区分SRAM和Flash操作；本机v1.1.1列出tangprimer20k。交付继续用已经验证的官方Programmer，不更换驱动。 |
| [Apicula](https://github.com/YosysHQ/apicula/blob/master/readme.md) / [nextpnr](https://github.com/YosysHQ/nextpnr) | README | 开源流程明确支持本板芯片，需匹配gw2a及C器件family/打包参数。支持器件不等于本工程已经完成等价性、时序与实物验证。 |

只学习方法，未移植第三方源码。noaidi采用CERN-OHL-S v2，sigrok为GPL体系；将来导入代码需逐文件核对许可。来源快照索引见同目录source-manifest文件；本地原文在忽略的.headroom-cache中。

## 优先应用方案

### 1. 真实控制链的触发记录（建议，尚未实现）

在保留正常输入的正式顶层中，记录：命令序号/连接代次、remote_active、控制源接管与超时、捏合值及有效标志、高度/摇杆、最终expression和volume、note gate、包络状态、I2C错误与missed-frame计数。故障触发后冻结窗口再导出，避免实时打印扰动音频。

可评估64 bit × 512项约4 KiB缓存，先核对BRAM与时序预算。示例格式24位clk27周期时间戳、8位事件、32位数据；时间戳约0.621秒回绕，分析器必须处理回绕。该格式仅是设计建议。

当前UART_TX是ESP_RX回复旁路，不能向电脑COM口发送命令后就认为命令进入了FPGA。新增导出必须先设计明确路径。115200 8N1最多约11520字节/秒，而46875Hz单声道16位PCM需93750字节/秒，不能直接连续全速传音频；事件和计数优先，音频短采集或降采样。

E050曾替代命令源、关闭光键/手势：能验证模块联动，不能排除手机连接与手势同时使用的问题。新诊断若要复现这类问题，必须保留原始控制链。

### 2. 可重复刺激与参考结果

每次固定音色、音符/和弦、力度、ADSR、效果开关和音量，保存输入序列、随机种子、码流hash、工具版本和状态回读。再加入连接/断连、超时、捏合中接管、快速note-on/off、曲谱换页的时间抖动。失败时保留完整序列及波形，用同一种子回放。

测试分开报告：纯RTL参考模型、注入诊断、真实ESP/App传输、真实光键/手势、模拟DAC录音。每次只改一个因素，修复必须先能重现失败，再在同输入下通过。音色比较看基频/谐波、包络、峰值/RMS和削波；颤音则查看基频是否随时间周期变化，不能把音色差别直接叫颤音。

### 3. 时序与硬件证据

E049已有27MHz下Fmax 27.190MHz、最差setup slack 0.259ns证据，余量不大。加探针会改变布局和扇出，必须另行编译、STA和标识，不能继承原码流结论。

现有SDC只有clk27的37.037ns主时钟约束。因此当前时序报告不能宣称外部I/O和全部CDC都已覆盖。应逐接口根据实际实现和器件资料审查同步器、生成时钟及I/O关系；不能为消除告警随意添加false-path/multicycle或编造延迟。

数字音频可在PCM_BCK R8、PCM_LRCK P8、PCM_DATA P6接逻辑分析仪，核对MSB在WS变化后一个BCLK、16位左右声道及完整LRCK周期。当前设计值BCLK 1.5MHz、每完整立体声帧32个BCLK、LRCK 46875Hz；两种WS边沿不能当作两帧。电脑48kHz录音不证明DAC以48kHz输出。

延迟应同步观测真实输入触发与目标输出，明确起止点；数字输入到I2S、输入到DAC模拟输出是不同指标。电脑主机时间戳只用于追溯。模拟录音先验证接线、声卡处理和有效信号，避免断线或AGC造成假结论。FAQ103正文未取得，不能代官方推断口径。

### 4. 修改与恢复流程

保存当前E049正式码流及hash → 用最小可复现输入建立失败证据 → 修改RTL并跑相关回归 → 核对引脚/资源/STA → SRAM试运行并读取身份 → 真实路径复测 → 仅对验证后的正式版本写Flash。临时诊断结束恢复E049并回读。电脑仍不加入ESP热点。

本机已确认Icarus/vvp存在于tools/iverilog/ucrt64/bin。发现官方GAO可执行文件只代表工具存在，没有验证许可证、捕获或命令行用法；它也不是开源方案。

## 本轮完成与后续边界

完成资料对照、工具只读核对和应用计划。没有新增环形探针、没有迁移开源综合流程、没有产生新的实物验收结果。板卡维持此前E049状态。完整功能检查仍按[e049-function-test-guide.md](e049-function-test-guide.md)，上述方法服务于调试，不能代替赛题逐项核对。
