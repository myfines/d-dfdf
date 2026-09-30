# Tang Primer 20K 开发与操作记录

设备：Sipeed Tang Primer 20K + Dock。目标：2026 高云赛道电子乐器。

当前阶段：**S0–S3 四个实体键均已确认能发声**。2026-09-29 23:11 将 T10 的 SSPI 双用途配置为普通输入后，用户逐键试听确认 S0、S1、S2、S3 正常。`audio_keys` 仍按最低键优先发**单音**；四复音尚未实现。左侧底部 RCFG 是重配置键，不能当演奏键。

当前音频码流 `E:\gaoyun\projects\audio_keys\audio_keys\impl\pnr\audio_keys.fs` 的 SHA256 为 `2D155BB754EC8C6238C57320220F5EE24E029907742F575C61FB7C61D5B4162E`。旧码流备份在 `E:\gaoyun\tools\audio_keys-pre-s0-7C1B92AD.fs`，未入库。新版仿真和综合布线通过，100 kHz 仅 SRAM 下载 `DONE / exit 0`。JTAG、MSPI、RECONFIG_N 未复用作普通 IO。

2026-09-30 两次 openFPGALoader 外部 Flash 写入曾分别停在 40.58% 和 35.13%。中途 USB-JTAG 出现过 Windows Code 43；换到另一个电脑直连 USB 口后恢复。音频码流重新装入 SRAM，用户确认 S0–S3 四键都有声。随后将 JTAG A 切回 FTDI 驱动，高云官方 Programmer 识别唯一 FPGA ID `0x81B`，确认旧 Flash 内容校验失败；**官方外部 Flash 擦写/编程到 100%，结束地址 `0x08CE00`，退出码 0**。现正安排独立只读校验和掉电启动测试，完成前不能称 Flash 固化成功。旧出厂内容没有可靠的整片备份。详见 [Flash 前置条件](docs/flash-readiness.md) 和 [操作记录](docs/operations.md)。

同日 22:53，用户确认误按的“S4”是实物丝印 **RCFG**。该键后音频失声；以 100 kHz 再次装入上述 `audio_keys.fs`，工具 `DONE / exit 0`，用户确认 S1–S3 三键都恢复发声。请勿把重配置后的灯光反应当作原 SRAM 音频程序仍在运行的证明。

- [操作记录](docs/operations.md)
- [2026 电子乐器设计与采购建议](docs/instrument-plan-2026.md)
- [用户资料核对与板卡资格依据](docs/reference-review-2026.md)
- [板载按键映射与芯片到货前的音频工作](docs/button-audio-next.md)
- [外部 Flash 固化前置条件](docs/flash-readiness.md)
- `logs/`：带时间戳的原始结果
- `led/`：已编译过的最小点灯源文件与约束
- `audio_probe/`：板载 PT8211 音频通路探针（440 Hz 三角波，响 1 秒/停 1 秒）
- `audio_keys/`：四键演奏（即按即响、松开消抖、1 ms/5 ms 包络、耳放门控、心跳灯）

音频键控进展：仿真 PASS（`logs/20260929-audio-keys-sim.log`：空闲无声、按键 0 半周期实测 957,654 ns 对理论 955,700 ns、按住时 1 ms 抖动不断音、松开后静音），综合布线 0 错 0 警（`logs/20260929-audio-keys-build*.log`）。码流 SHA256 `2D155BB754EC8C6238C57320220F5EE24E029907742F575C61FB7C61D5B4162E`；用户此前确认 SRAM 下 S0–S3 均可发声。

已知限制（详见 `docs/operations.md` 2026-09-29 一节）：

- **Flash 状态未确认**：本次 Flash 擦写中断，地址 0–0x8FFFF 区域可能只有部分码流；JTAG 需恢复后重新装入 SRAM。完整原厂内容没有可靠备份。不能断电重启来验证启动，直到工具连接恢复并核对状态。
- **S0 已可用**：T10 需将 SSPI 双用途配置为普通 IO；当前配置只打开 SSPI，四个实体键已试听通过。RCFG 仍不能当演奏键；详见 `docs/button-audio-next.md`。
- 4 个按键位于 **1.5 V bank**，约束用 `LVCMOS15`；音频与 LED 引脚为 3.3 V。
- 构建注意：`.sdc` 必须保存为 **CRLF** 行尾，否则高云解析器报 `syntax error near token 'clk]'`（已用 `.gitattributes` 固定）。

开源下载工具：openFPGALoader v1.1.1，来源 https://github.com/trabucayre/openFPGALoader/releases/tag/v1.1.1 。已成功识别 0x0000081B 并完成 SRAM 配置；该版本对 GW2A 跳过软件 checksum 比较，不应描述为完整回读校验通过。

成功时环境：USB-JTAG 直连电脑，A/MI_00 = WinUSB/oem180.inf，B/MI_01 = FTDIBUS/oem178.inf 且启用，两者 ProblemCode 均为 0。命令：

```powershell
& 'E:\gaoyun\tools\openfpgaloader\ucrt64\bin\openFPGALoader.exe' -b tangprimer20k --freq 2500000 --write-sram -v <经核验的码流.fs>
```

点灯码流 SHA256：`0375DCA1C9D62BD721FEC38F076C811FAC9294CDDFD2D1253AB3FAC33F7D355F`（`logs/20260926-direct-sram-100k.*`）。工具报告频率为请求值，未做物理时钟测量，状态寄存器最终为 `0x00006020 / Done Final`。SRAM 断电失效。

用户没有规定固定 JTAG 速度上限，底线是不损坏板卡；用户已授权将当前音频码流写入外置 Flash 并校验。最近一次尝试卡住且中断，尚无成功证据。OTP、bulk erase 和下载器固件更新未获授权。不要把“写入到 100%”或退出码单独当成实物成功。

注意：`openFPGALoader --detect -f` 与 `--dump-flash` 会先 `Erase SRAM`，会清掉正在运行的 SRAM 配置。

不提交安装包、厂商二进制、个人照片或大体积构建文件。

