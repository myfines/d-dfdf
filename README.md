# Tang Primer 20K · FPGA实时多音色电子乐器

2026高云FPGA创新设计赛道选题二。Tang Primer 20K＋Dock配合PCM5102A、ADS1015、摇杆、八路光键、K230手势、OLED和ESP-01S，实现FPGA实时合成与多维演奏控制。

## 当前版本（2026-10-31）

| 项目 | 最近确认状态 |
|---|---|
| FPGA正式固件 | **E049**，Flash已写入校验；临时SRAM探针结束后恢复E049，独立读回E049／`0x6020` |
| Android App | **0.13-e049-recovery**，versionCode 13，包名`cn.myfines.instrument`；最近已安装到测试手机，原自绘UI保留 |
| 最新App修复 | 新连接先退出遗留录音回传模式，修复录音中断后重连无普通状态 |
| 当前主工程 | **`firmware/e028-extension/`**，不是历史`instrument_io/`工程 |
| 拍摄状态 | 已有功能可拍；不等于全部性能验收完成。以上为最近部署记录，拍摄当日仍需核对设备 |

**[下载App0.13 APK](mobile-companion/apk/instrument-companion-0.13-e049-recovery.apk)** · [版本与哈希收据](firmware/e028-extension/docs/full-system-device-20261030/release.json) · [E049 Flash证据](firmware/e028-extension/docs/e049-flash/README.md)

手机连接`FPGA-Instrument`，密码`fpga-demo-2026`，App地址`192.168.4.1:9000`。电脑不要加入ESP热点。按住S1＋S2，按下并松开摇杆，再松开S1/S2，启用一次后等待约20秒；反复操作会关闭外设。

## 功能、测试与边界

音频由FPGA HDL逐音、逐样本合成，经I2S输出；K230仅做手势识别，App负责控制和记录。32份独立相位/频率/包络状态采用TDM共享运算，不能以普通谐波峰重复计声部。提供四音色、幅度/音高/亮度控制、ADSR、颤音、合唱/延迟/混响，以及OLED波形、16带频谱、XY、曲谱和声部状态。App支持文本曲谱下载与缓存下发、映射、短WAV回传导出。

- [完整功能操作指南](docs/e049-function-test-guide.md)：操作、参数回读与恢复方法。
- [完整测试结论](firmware/e028-extension/docs/full-system-test-20261030/FINAL.md)：50个RTL测试台、Python工具21项、K230单测32项、App7组，以及真实手机9组流程115个检查点（含重复连接前置检查）。
- [真实手机明细](firmware/e028-extension/docs/full-system-device-20261030/results.json) · [OLED五页实拍](firmware/e028-extension/docs/full-system-device-20261030/oled-camera-pages.jpg)。
- [赛题原文摘录](docs/competition-topic2-source-20261029.md) · [LED与32复音边界](docs/led-and-parallel-scope-20261030.md)。
- [Wi-Fi事件分析](docs/wifi-incident-analysis-20261030.md)：热点已恢复并完成手机测试，最初原因未锁定；主动健康检查仅为建议，**尚未加入固件**。

尚未证明：控制到DAC模拟输出≤10ms／≤5ms、确定性无抖动、实际LRCK采样率。设计采样率46,875Hz只报设计值；最终冷启动由用户拍摄确认。四路板载LED为分组曲谱指引，纸壳内实际可视性待拍，OLED不自动替代LED要求。短录音约0.7秒、8bit、单声道，不是整曲录音；下载谱当前断电丢失，不声称永久保存。

## 视频拍摄：队友和其他AI的接手入口

1. **先读[赛题逐项拍摄执行表](docs/video-requirement-evidence-20261031.md)**：基础三项、拓展四项及评分验证分别对应实际操作、可见/可听结果与证据边界。
2. 再读[分镜与时间预算](docs/video-shoot-plan-20261031.md)：先录完整证据，再剪约2分55秒主片；时长只是制作建议，最终以本届上传页面为准。
3. 查[操作指南](docs/e049-function-test-guide.md)确认按钮、参数和复位，不能凭旧版本猜操作。

| 顺序 | 镜头 | 核心结果 |
|---|---|---|
| 1–2 | 成品短句、硬件与合成路径 | 实物发声；K230识别与FPGA合成职责明确 |
| 3–6 | 八路光键、捏合、弯音、力度与高度 | 动作和声音对应；力度重新触发；亮度与音量分开 |
| 7–8 | 四音逐个释放、四种音色 | 剩余音持续；同短句音色可辨 |
| 9–11 | ADSR、显式颤音、三效果独立对比 | 包络四参数、颤音0→160→0、FX与干声对照 |
| 12–14 | OLED、32声部、频谱/RTL证据 | 动态视听；独立声部与数据来源清楚 |
| 15–18 | 脱机LED曲谱、下载/缓存、映射、录音保存播放 | 本地与手机扩展闭环；不能只拍菜单 |
| 19 | 正常参数下结束演奏 | 成品演奏体验；冷启动另录完整原片 |

### 复制给其他AI的拍摄交接提示

> 请在本仓库指导队员实时拍摄比赛视频。先读README.md、docs/video-requirement-evidence-20261031.md、docs/video-shoot-plan-20261031.md、docs/e049-function-test-guide.md和firmware/e028-extension/docs/full-system-test-20261030/FINAL.md。当前正式E049＋App0.13，音频在FPGA合成；不要按旧E026首页或旧APK规划。
>
> 严格覆盖赛题基础三项、拓展四项及核心评分标准。每次指导一个镜头：机位、设备初始状态、手的动作、参数、应看到/听到的结果、字幕和恢复步骤。用户确认拍完后再安排下一镜；依据实际反馈或素材记录“已录／待补／未测”，不能把功能存在或自动测试通过当作已经拍到。
>
> 四音逐放一镜到底；力度需重新触发；高度尽量固定捏合；显式颤音与合唱分开；三个FX分别对比干声；ADSR四参数完整录；LED必须是曲谱灯，不是巡线检测灯。32数字不能单独证明32可闻声部；既有E048频谱需标明历史诊断录音及衰减配置，不能假装当前镜头实时采集。
>
> 保留原自绘UI、接线和正式固件，不为拍摄擅自烧录或换线。电脑不加入ESP热点；公网下载与本地缓存下发分两阶段；冷启动由用户操作。演奏不加速、不后配替代声音、不逐音色归一化；画面不出现学校/老师信息。延迟、LRCK、抖动未实测不能写成达标。约3分钟是当前建议，不是已确认的2026硬规定，最终核对当届提交页面。

关键原片按执行表编号归档，用“赛题条目→片段编号→源码/数据”交叉索引。拍不到或不清楚的项目保留待补，不能用字幕代替结果。

## 目录与构建入口

| 路径 | 用途 |
|---|---|
| `firmware/e028-extension/src/` | 当前HDL音频、输入、显示与ESP控制 |
| `firmware/e028-extension/tools/build_e049_ap.tcl` | E049热点版Gowin构建入口 |
| `firmware/e028-extension/sim/run_icarus.ps1` | RTL回归入口 |
| `mobile-companion/` | Android源码、测试、构建与APK |
| `k230/` | 手势识别与发送代码 |
| `docs/`、`logs/` | 操作、测试、赛题、拍摄文档及记录 |
| `instrument_io/`等早期工程 | 历史参考，不是E049发布入口 |

Gowin按脚本设置`FPGA_WEB_PRIVATE`／`FPGA_BUILD_ROOT`；Android入口`mobile-companion/build.ps1`。其他电脑需配置工具路径/SDK，未宣称异机一键复现已验。部署按确定版本和哈希操作，不用“最近生成的文件”猜码流，不为确认版本重复擦写Flash。

[完整操作记录](docs/operations.md)。独立比赛源码快照目前仅在本地`E:/gaoyun/releases/fpga-instrument-competition`，尚未创建GitHub远端；本仓库仍用于队内开发交接。

旧首页保留于[历史首页](docs/history/readme-before-E049.md)，其中E026与旧功能缺口仅为历史，不作为当前结论。
