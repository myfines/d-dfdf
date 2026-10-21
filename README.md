# Tang Primer 20K · FPGA 电子乐器

2026 高云 FPGA 创新设计赛道“实时多音色合成电子乐器引擎”。主工程为 `instrument_io/`，主板 Tang Primer 20K + Dock，外设包括 PCM5102A、ADS1015、摇杆、八路光键、OLED 和 ESP-01S。

## 当前版本与下载

**当前已写入 Flash：E023（2026-10-21）**。官方 Programmer 写入＋校验成功，用时31.57秒；E023冷启动、安卓安装及真实Wi-Fi双向联调仍待验收。之前版本的实测结果不自动等于E023验收通过。

- **[安卓 APK 下载入口](mobile-companion/apk/instrument-companion-debug.apk)**：打开后点 Download raw file；仓库为私密，需登录获授权的 GitHub 账号。应用版本0.2-wifi，最低Android8。
- [当前版本清单](docs/current-release.md)：身份、哈希、验证范围与回退版本。
- [E023 Wi-Fi 操作与协议](docs/wifi-app-E023-20261021.md)：手机四键、音量、音色、延时、实际状态和波形监看、事件CSV。
- [全部接线](docs/wiring-all-current.md) · [OLED/ESP接线](docs/oled-esp-wiring-20261020.md)
- [完整操作记录](docs/operations.md) · [Flash流程](docs/flash-programming-procedure.md)

## 功能与验收边界

HDL音频合成、包络、复音/32声部路径、硬件延时、摇杆参数控制、八路光键与OLED；安卓Wi-Fi页新增四触屏键及状态回传。30项RTL回归、Java协议/TCP/合成测试和Gowin构建已通过，27MHz约束下Fmax33.632MHz，setup/hold违例0。

手机键按住时优先手机，松开恢复光键。Wi-Fi波形是低速监看，事件CSV不是音频录音。尚未完成蓝牙、在线曲谱下载、离线LED曲谱引导、音频录音回传，也没有完成全部题目指标的实测验收。旧[差距核对](docs/competition-gap-20261012.md)按日期查阅，不当作最新验收表。

历史核心板异常发热根因和ESP供电余量未测清；硬件hold保留，不能把仿真通过视为供电安全证明。PCM USB供电时其3V3排针不接。发生异常发热立即全部断电。

## 目录与复现

| 目录 | 用途 |
|---|---|
| `instrument_io/` | 当前主RTL、仿真与Gowin构建入口 |
| `mobile-companion/` | 安卓源码、测试、构建脚本和APK |
| `k230/` | K230扩展工作，独立于本次Wi-Fi验收 |
| `docs/` | 接线、版本、操作说明与题目核对 |
| `logs/` | 原始测试/烧录日志，保留时间戳 |
| `scripts/` | 有哈希校验与限定授权的烧录辅助脚本 |
| `led/`、`audio_probe/`、`audio_keys/`、`s0_probe/` | 历史诊断/早期工程，不是当前发布入口 |

PowerShell构建入口：`instrument_io/run_tests.ps1`、`instrument_io/build_extension_candidate.tcl`（Gowin gw_sh）、`mobile-companion/build.ps1`。本机工具路径见脚本，其他电脑需先配置依赖。码流不入Git，归档路径与哈希见版本清单。

版本规则：代码与测试日志提交后创建候选标签；写入成功单独记录部署提交；冷启动/功能验证另记实测结果。已归档E021/E022/E023不覆盖，故障回退依据固定哈希，不使用“最近生成的文件”猜版本。APK随对应源码提交，哈希见版本清单。

旧首页已移至[历史首页](docs/history/readme-before-E023.md)，保留早期点灯、单音、驱动和Flash排查记录。
