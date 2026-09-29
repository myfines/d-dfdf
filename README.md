# Tang Primer 20K 开发与操作记录

设备：Sipeed Tang Primer 20K + Dock。目标：2026 高云赛道电子乐器。

当前阶段：**S1–S3 三个实体键已确认能发声**。`audio_keys` 具有四路逻辑输入、按最低键优先发单音，不能据此称“四个实体演奏键可用”或“四复音”。左侧底部的 RCFG 是重配置键，用户按下后原音频程序失声；再以 100 kHz 把同一码流装入 SRAM，S1–S3 恢复有音。S0 尚未发声。下一步是在现有耳机口实现并验证四个独立声部，第四个实体演奏键待补齐。

2026-09-29 22:43 已重新以请求 100 kHz 将同一 SHA256 的 `audio_keys.fs` 下载到 SRAM，工具报告 `DONE / Done Final / exit 0`；本次耳机结果待用户反馈。Flash 未写入；目前只有前 64 KB 备份，历史读数不一致，且此版 openFPGALoader 的 Flash 路径会把 JTAG 设置到 10 MHz，超过当前 2.5 MHz 限制。

同日 22:53，用户确认误按的“S4”是实物丝印 **RCFG**。该键后音频失声；以 100 kHz 再次装入上述 `audio_keys.fs`，工具 `DONE / exit 0`，用户确认 S1–S3 三键都恢复发声。请勿把重配置后的灯光反应当作原 SRAM 音频程序仍在运行的证明。

- [操作记录](docs/operations.md)
- [2026 电子乐器设计与采购建议](docs/instrument-plan-2026.md)
- [用户资料核对与板卡资格依据](docs/reference-review-2026.md)
- [板载按键映射与芯片到货前的音频工作](docs/button-audio-next.md)
- `logs/`：带时间戳的原始结果
- `led/`：已编译过的最小点灯源文件与约束
- `audio_probe/`：板载 PT8211 音频通路探针（440 Hz 三角波，响 1 秒/停 1 秒）
- `audio_keys/`：四键演奏（即按即响、松开消抖、1 ms/5 ms 包络、耳放门控、心跳灯）

音频键控进展：仿真 PASS（`logs/20260929-audio-keys-sim.log`：空闲无声、按键 0 半周期实测 957,654 ns 对理论 955,700 ns、按住时 1 ms 抖动不断音、松开后静音），综合布线 0 错 0 警（`logs/20260929-audio-keys-build*.log`），2.5 MHz 仅 SRAM 下载成功（`Load SRAM 100%`、`DONE`、exit 0）。码流 SHA256 `7C1B92AD60D2238C504A5DC255B4BDD014C4FFD1783F5AEB6E90DCB226CBADA9`。

已知限制（详见 `docs/operations.md` 2026-09-29 一节）：

- **只写 SRAM**：断电、复位、或调试器/USB 抖动都会让板子变空，恢复方式是重烧一次（约 5 秒）。板载 Flash 未写入；出厂内容已备份前 64 KB 到 `tools/tang20k-flash-first64k.bin`（未入库）。
- **实体键与逻辑管脚尚未完全对上**：当前工程未使用 T10；用户确认 S1–S3 有音、S0 尚无音。RCFG 不能当第四个普通按键；详见 `docs/button-audio-next.md`。
- 4 个按键位于 **1.5 V bank**，约束用 `LVCMOS15`；音频与 LED 引脚为 3.3 V。
- 构建注意：`.sdc` 必须保存为 **CRLF** 行尾，否则高云解析器报 `syntax error near token 'clk]'`（已用 `.gitattributes` 固定）。

开源下载工具：openFPGALoader v1.1.1，来源 https://github.com/trabucayre/openFPGALoader/releases/tag/v1.1.1 。已成功识别 0x0000081B 并完成 SRAM 配置；该版本对 GW2A 跳过软件 checksum 比较，不应描述为完整回读校验通过。

成功时环境：USB-JTAG 直连电脑，A/MI_00 = WinUSB/oem180.inf，B/MI_01 = FTDIBUS/oem178.inf 且启用，两者 ProblemCode 均为 0。命令：

```powershell
& 'E:\gaoyun\tools\openfpgaloader\ucrt64\bin\openFPGALoader.exe' -b tangprimer20k --freq 2500000 --write-sram -v <经核验的码流.fs>
```

点灯码流 SHA256：`0375DCA1C9D62BD721FEC38F076C811FAC9294CDDFD2D1253AB3FAC33F7D355F`（`logs/20260926-direct-sram-100k.*`）。工具报告频率为请求值，未做物理时钟测量，状态寄存器最终为 `0x00006020 / Done Final`。SRAM 断电失效。

JTAG 请求频率上限 2.5 MHz；Flash、OTP、下载器固件更新仍不在授权范围。禁止把“写入到 100%”或命令退出码单独当成实物成功。

注意：`openFPGALoader --detect -f` 与 `--dump-flash` 会先 `Erase SRAM`，会清掉正在运行的 SRAM 配置。

不提交安装包、厂商二进制、个人照片或大体积构建文件。
