# Tang Primer 20K 开发与操作记录

设备：Sipeed Tang Primer 20K + Dock。目标：2026 高云赛道电子乐器。

当前阶段：点灯联调，尚未确认成功点灯。

- [操作记录](docs/operations.md)
- `logs/`：带时间戳的原始结果
- `led/`：已编译过的最小点灯源文件与约束

开源下载工具：openFPGALoader v1.1.1，来源 https://github.com/trabucayre/openFPGALoader/releases/tag/v1.1.1 。已验证本机启动和板卡列表支持；实物识别与下载尚未验证。

当前仅授权 SRAM 点灯下载，JTAG 请求频率上限 2.5 MHz。禁止把“写入到 100%”或命令退出码单独当成实物点灯成功。

不提交安装包、厂商二进制、个人照片或大体积构建文件。
