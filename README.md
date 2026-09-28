# Tang Primer 20K 开发与操作记录

设备：Sipeed Tang Primer 20K + Dock。目标：2026 高云赛道电子乐器。

当前阶段：点灯成功。2026-09-26 19:21，直连 USB 后完成 SRAM 下载（100%、DONE、退出码 0）；随后用户观察到灯闪烁，并查看丝印确认目标 LED2，明确表示“没问题了……可以了”。

- [操作记录](docs/operations.md)
- [2026 电子乐器设计与采购建议](docs/instrument-plan-2026.md)
- [用户资料核对与板卡资格依据](docs/reference-review-2026.md)
- `logs/`：带时间戳的原始结果
- `led/`：已编译过的最小点灯源文件与约束
- `audio_probe/`：板载 PT8211 音频通路探针（440 Hz 三角波，响 1 秒/停 1 秒）

音频探针进展：仿真通过（`logs/20260929-audio-test-sim.log`），综合布线通过（`logs/20260929-audio-build-fixed.*`，0 错误 0 警告），2026-09-29 00:54 以 100 kHz 仅 SRAM 下载完成（`Load SRAM 100%`、`DONE`、exit 0）。**是否真的发声仍待听力反馈**，未判定为已验收。构建需注意：`.sdc` 必须保存为 CRLF 行尾，否则高云解析器报 `syntax error near token 'clk]'`。

开源下载工具：openFPGALoader v1.1.1，来源 https://github.com/trabucayre/openFPGALoader/releases/tag/v1.1.1 。已成功识别 0x0000081B 并完成 SRAM 配置；该版本对 GW2A 跳过软件 checksum 比较，不应描述为完整回读校验通过。

成功时环境：USB-JTAG 直连电脑，A/MI_00 = WinUSB/oem180.inf，B/MI_01 = FTDIBUS/oem178.inf 且启用，两者 ProblemCode 均为 0。命令：

```powershell
& 'E:\gaoyun\tools\openfpgaloader\ucrt64\bin\openFPGALoader.exe' -b tangprimer20k --freq 100000 --write-sram -v E:\gaoyun\led.fs
```

码流 SHA256：`0375DCA1C9D62BD721FEC38F076C811FAC9294CDDFD2D1253AB3FAC33F7D355F`。工具报告 100 kHz（未做物理时钟测量），状态寄存器最终为 `0x00006020 / Done Final`。详见 `logs/20260926-direct-sram-100k.*`。SRAM 断电失效。

当前仅授权 SRAM 点灯下载，JTAG 请求频率上限 2.5 MHz。禁止把“写入到 100%”或命令退出码单独当成实物点灯成功。

不提交安装包、厂商二进制、个人照片或大体积构建文件。
