# Tang Primer 20K 开发与操作记录

设备：Sipeed Tang Primer 20K + Dock。目标：2026 高云赛道电子乐器。

当前阶段：**音频码流已固化到外置 Flash，掉电上电及 RCFG 后 S0–S3 四键均已确认发声**。`audio_keys` 仍按最低键优先发**单音**；四复音尚未实现。左侧底部 RCFG 是重配置键，不能当演奏键。

当前音频码流 `E:\gaoyun\projects\audio_keys\audio_keys\impl\pnr\audio_keys.fs` 的 SHA256 为 `2D155BB754EC8C6238C57320220F5EE24E029907742F575C61FB7C61D5B4162E`。旧码流备份在 `E:\gaoyun\tools\audio_keys-pre-s0-7C1B92AD.fs`，未入库。新版仿真和综合布线通过；JTAG、MSPI、RECONFIG_N 未复用作普通 IO。

2026-09-30 两次 openFPGALoader 外部 Flash 写入中途停住；把 JTAG A 切回 FTDI 后，高云官方 Programmer 正确识别 FPGA ID `0x81B` 与 Flash ID `0x0B4017`，执行外部 Flash BSCAN 擦写/编程到 100%，结束地址 `0x08CE00`，退出码 0。用户随后全板断电 10 秒再上电、没有下载 SRAM，确认 S0–S3 四键都有声；按 RCFG 后四键仍有声。最后只读 JTAG 扫描仍读到一个 `0x81B`。**Flash 自启动和重配置功能已实物验证。**原出厂内容没有可靠的整片备份；本次未单独运行写后的逐字节 Flash 比较。详见 [成功烧录流程](docs/flash-programming-procedure.md) 和 [操作记录](docs/operations.md)。

此前用户误按的“S4”是实物丝印 **RCFG**；仅在 SRAM 运行时，按它会重新配置并使音频失声。现在 Flash 已装入相同音频程序，按 RCFG 后四键仍能发声。

- [操作记录](docs/operations.md)
- [2026 电子乐器设计与采购建议](docs/instrument-plan-2026.md)
- [用户资料核对与板卡资格依据](docs/reference-review-2026.md)
- [板载按键映射与芯片到货前的音频工作](docs/button-audio-next.md)
- [外部 Flash 成功烧录流程](docs/flash-programming-procedure.md)
- [Flash 早期诊断与技术限制](docs/flash-readiness.md)
- `logs/`：带时间戳的原始结果
- `led/`：已编译过的最小点灯源文件与约束
- `audio_probe/`：板载 PT8211 音频通路探针（440 Hz 三角波，响 1 秒/停 1 秒）
- `audio_keys/`：四键演奏（即按即响、松开消抖、1 ms/5 ms 包络、耳放门控、心跳灯）

音频键控进展：仿真 PASS（`logs/20260929-audio-keys-sim.log`：空闲无声、按键 0 半周期实测 957,654 ns 对理论 955,700 ns、按住时 1 ms 抖动不断音、松开后静音），综合布线 0 错 0 警（`logs/20260929-audio-keys-build*.log`）。码流 SHA256 `2D155BB754EC8C6238C57320220F5EE24E029907742F575C61FB7C61D5B4162E`；用户此前确认 SRAM 下 S0–S3 均可发声。

已知限制（详见 `docs/operations.md` 2026-09-29 一节）：

- **原厂 Flash 内容未完整备份**：早期只读文件两次不一致，不能恢复出厂镜像；现在已由本项目的音频程序取代。写后没有另跑独立的逐字节 Flash 比较，功能验证依据是全板断电上电和 RCFG 后四键仍有声。
- **S0 已可用**：T10 需将 SSPI 双用途配置为普通 IO；当前配置只打开 SSPI，四个实体键已试听通过。RCFG 仍不能当演奏键；详见 `docs/button-audio-next.md`。
- S0/T10 使用 `LVCMOS33`；S1–S3/T3/T2/D7 使用 `LVCMOS15`。音频与 LED 引脚为 3.3 V。
- 构建注意：`.sdc` 必须保存为 **CRLF** 行尾，否则高云解析器报 `syntax error near token 'clk]'`（已用 `.gitattributes` 固定）。

开源下载工具：openFPGALoader v1.1.1，来源 https://github.com/trabucayre/openFPGALoader/releases/tag/v1.1.1 。已成功识别 0x0000081B 并完成 SRAM 配置；该版本对 GW2A 跳过软件 checksum 比较，不应描述为完整回读校验通过。

此前 SRAM 下载成功时：USB-JTAG 直连电脑，A/MI_00 = WinUSB/oem180.inf，B/MI_01 = FTDIBUS/oem178.inf；使用：

```powershell
& 'E:\gaoyun\tools\openfpgaloader\ucrt64\bin\openFPGALoader.exe' -b tangprimer20k --freq 2500000 --write-sram -v <经核验的码流.fs>
```

点灯码流 SHA256：`0375DCA1C9D62BD721FEC38F076C811FAC9294CDDFD2D1253AB3FAC33F7D355F`（`logs/20260926-direct-sram-100k.*`）。工具报告频率为请求值，未做物理时钟测量，状态寄存器最终为 `0x00006020 / Done Final`。SRAM 断电失效。

当前 Flash 烧录成功时 A、B 都使用 FTDI/oem178.inf，高云官方 Programmer 2.5 MHz。用户没有规定固定 JTAG 速度上限，底线是不损坏板卡；OTP、bulk erase 和下载器固件更新未获授权。新码流若要再次固化，应按[成功烧录流程](docs/flash-programming-procedure.md)核对文件身份、扫描 ID 并做掉电启动验证。

注意：`openFPGALoader --detect -f` 与 `--dump-flash` 会先 `Erase SRAM`，会清掉正在运行的 SRAM 配置。

不提交安装包、厂商二进制、个人照片或大体积构建文件。

