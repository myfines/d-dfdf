# OLED + ESP-01S 候选版本（2026-10-21）

本版仅完成离线实现、仿真和构建，未下载到板上，未验证实物显示、Wi-Fi 接入或音量变化。K230 不参与本版。现有 Flash 与部署保护文件保持原样。

## 实现

- 保留八路光键、四板载键、摇杆、包络、音色、混音、延时和32声部测试路径。
- SSD1306 128×64 I²C（7位地址0x3C）：顶行八个键框；第二行八个状态标记；下方显示效果器及音量之后的128点波形。显示由FPGA RTL生成，不依赖ESP绘图。
- 状态标记从左至右：已启用、光键在线、ADC在线、编辑模式、32声部测试模式、延时开启、ESP配置完成、远程音量租约有效。
- OLED使用100kHz I²C，逐帧更新约2–3帧/秒；不宣称满足题目≤5ms可视化要求。它不阻塞音频流水线。无应答/总线超时后自动重试。
- ESP-01S使用原AT固件、115200 8N1。FPGA依次配置AP和TCP服务器，每一步等OK，超时重新初始化。检测ESP重新启动后重配。
- 远程音量0–255，只衰减、不放大，逐音频帧平滑变化；5秒没有有效命令恢复原音量。该功能不是蓝牙、音频无线传输或已完成的手机APP。
- 上电默认未启用，I²S、OLED总线及ESP TX释放；安全启用组合不变。高阻控制不等于硬件隔离，不能据此保证两板断电时绝无回灌。

## 接线约定

| 模块引脚 | Dock FPGA管脚 |
|---|---|
| OLED SCL | T11 |
| OLED SDA | P11 |
| ESP TX | T12（FPGA接收） |
| ESP RX | R11（FPGA发送） |

以上均为Bank2、3.3V逻辑。OLED接真实3V3和GND；其余现有接线见[接线图](oled-esp-wiring-20261020.md)。ESP与大ESP测试板之间的旧串口线应断开，不能两个发送端并接。

**ESP供电仍待核验**：用户目前拟从Dock 3V3取电，但本轮没有证明该电源可承担Wi-Fi峰值电流。历史核心芯片异常发热原因仍未查明，不把“线已插完”视为供电验证通过，不安排本版上电/烧录。

## 后续实物验收时的操作

以下为验收计划，不代表现在已允许上电。

1. 供电与历史发热问题核查完成后，先下载候选版到SRAM，保留旧Flash作为回退。
2. 按住S1+S2，按下并松开摇杆按钮，再松开两键；只做一次。原光键启动等待约20秒。
3. 核验本地键和摇杆，再观察OLED键框、状态点与波形。OLED/ESP缺失不能使本地演奏失效。
4. ESP配置成功后，电脑连接Wi-Fi `FPGA-Instrument`，演示密码 `fpga-demo-2026`。系统若提示无互联网，保持该连接。
5. 电脑执行 `python scripts/esp-volume-client.py --volume 128 --seconds 15`，目标 `192.168.4.1:9000`。测试静音用0、原音量用255。结束后约5秒恢复本地音量。
6. TCP负载为ASCII `Vhh\n`，如 `V80\n`；支持同客户端跨TCP包拼接和多条命令合包。客户端定期续租。没有应用层ACK，TCP连接成功不能代替音频实测。此为局域网演示协议，同一AP上的客户端均可控制音量。

## 复现与边界

- 顶层：`instrument_io/instrument_extension_top.v`；约束：`instrument_io/instrument_extension.cst`；UserCode：`0xE021`。
- 构建：用Gowin `gw_sh.exe instrument_io/build_extension_candidate.tcl`，输出独立目录 `E:/gaoyun/projects/instrument_extension_candidate`。
- 仿真：`powershell -File instrument_io/run_tests.ps1`，25项测试；新增UART、AT握手/重试/重启、分包解析、音量限幅/平滑、OLED实际I²C数据及像素、扩展安全启动6项。
- 原工程默认`ENABLE_UI=0`，新增接口默认关闭；旧顶层和原19项回归覆盖保留。
- 构建/时序/哈希记录见 `logs/20261021-extension-verification.json`。27MHz内部时序通过不等于已经验证板级I²S/I²C信号完整性、供电、温度或端到端延迟。
- 初版OLED快照旋转产生过多组合MUX导致资源超限，已改为固定快照+单读地址旋转；一次输入端口DRIVE约束错误已移除。失败原始日志保留。
