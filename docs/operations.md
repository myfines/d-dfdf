# 操作记录

## 历史回顾（根据会话记录补录，非完整逐命令日志）

- 安装高云教育版 V1.9.11.03，软件 MD5 已对照官网下载页核验。
- 点灯工程已通过综合和布局布线。芯片 GW2A-LV18PG256C8/I7、C 版本；27 MHz 时钟 H11；LED2 N16；LVCMOS33，LED 驱动 4 mA。
- JTAG 曾成功读到 0x0000081B。该 ID 为 GW2A/GW2AR-18C 共用，具体型号依据板卡资料。
- 高云命令行曾完成 SRAM 写入 100%，随后回读校验停在 1%，未返回成功。用户反馈没有灯闪烁。进程最终被结束。
- 其他尝试出现打开下载器后停滞；物理重连后可重新识别。确切根因尚未证明。
- 码流 CRCCheck=ON、SecurityBit=ON、JTAGAsRegularIO=OFF。读回保护需纳入校验兼容性判断，但不能据此断言它就是挂起根因。
- 全部硬件写入尝试均针对 SRAM；没有执行 Flash 擦写、OTP 写入或下载器固件更新。
- Windows FTDI B 接口曾出现 Code 10。未确认串口可用。
- 用户担心发热：没有实测温度，不能凭通信结果保证热状态。

## 2026-09-26T18:58:01.412228+08:00：建立仓库并重查连接

1. `git ls-remote git@github.com:myfines/d-dfdf.git HEAD`：SSH publickey 认证失败。
2. 改用 HTTPS 克隆同一仓库成功；远端为空仓库，分支 main。
3. Windows 枚举没有 VID_0403/PID_6010 板载下载器；openFPGALoader `--scan-usb` 没有列出探针。
4. 仅执行 USB 枚举；未执行 FPGA JTAG 扫描、SRAM 下载或任何 Flash 操作。
5. 已请求用户连接 USB-JTAG。等待设备出现后，先检查驱动及只读识别，再判断是否可下载。
6. 原始工具结果：`logs/20260926-185801-usb-scan.json`。

开源命令计划（尚未执行）：

```text
openFPGALoader -b tangprimer20k --freq 2500000 --detect -v
openFPGALoader -b tangprimer20k --freq 2500000 --write-sram -v <经核验的码流.fs>
```

当前码流 SHA256：0375DCA1C9D62BD721FEC38F076C811FAC9294CDDFD2D1253AB3FAC33F7D355F。

7. 首次提交因本机没有 Git 作者信息而失败；仅为本仓库设置作者 Codex <codex@localhost>，随后重试提交与推送。

## 2026-09-26：重连后点灯尝试及驱动定位

- Windows 显示 FTDI A/B 两通道均 OK。
- openFPGALoader --scan-usb 返回 libusb error -5 Entity not found，说明现有 FTDIBUS 接口未能被该工具打开；没有开始 FPGA 写入。
- 尝试独立版 Gowin Programmer 2536：USB Debugger A、2.5MHz、operation_index=2（SRAM Program），码流 SHA256 核验通过。程序未输出进度且进程计数停滞，已结束；没有成功返回。详见 logs/20260926-185912-sram-program.log 及同名 JSON。
- 已停止相关命令行烧录器。
- 查阅 openFPGALoader Windows 使用资料及 libwdi 文档，准备将 JTAG 接口 A/MI_00 改为 WinUSB，保留 B/MI_01 的串口驱动。
- 从 pbatard/libwdi 官方 release 下载 Zadig 2.9，Authenticode 签名 Valid，签名者 Akeo Consulting。配置显示全部子设备但隐藏复合父设备，默认驱动 WinUSB。
- 已请求打开 Zadig。当前进程为 Windows 中等完整性权限，安装驱动需要用户管理员确认；助手不操作屏幕。驱动尚未确认安装，点灯尚未成功。
- 用户操作目标：USB Serial Converter A / Interface 0，USB ID 0403:6010:00，替换为 WinUSB；不选择 B 或 USB Composite Device。

## 2026-09-26T19:05:17.8011914+08:00：接手后只读核验

- 目的：确认驱动替换是否完成及是否存在占用，不重复 SRAM 下载。
- 命令：Get-PnpDevice / Get-PnpDeviceProperty；Get-Process programmer_cli,openFPGALoader,programmer；WindowsPrincipal.IsInRole(Administrator)；openFPGALoader --scan-usb（15 秒超时）。
- A/MI_00 与 B/MI_01 均为 OK，仍绑定 FTDIBUS / oem178.inf；父设备为 usbccgp / usb.inf。WinUSB 替换未完成。
- 无残留烧录进程；当前命令行未提升管理员权限。
- USB 扫描结果见本阶段原始日志；现有 FTDIBUS 绑定仍不能证明 openFPGALoader 可以打开接口。
- 本阶段没有改驱动、执行 JTAG 下载或写 Flash/OTP/下载器固件。点灯仍未确认成功。
- 下一步需在管理员上下文中解决 A/MI_00 驱动绑定，保留 B 通道；当前只具备 Zadig GUI，尚未准备并验证命令行驱动安装包。遵守不点击屏幕要求。

- 扫描实际返回 empty、退出码 0（没有列出探针），与前次 error -5 不同；紧接着重新枚举，当前匹配 USB 设备数量为 3。不得将空列表当作打开成功。

## 2026-09-26：命令行切换 JTAG A 至 WinUSB

- 用户明确授权自行处理权限和命令行排查，仅协助接线；延续 SRAM / 2.5 MHz 限制。
- 重连枚举：A 正常，B 为 Code 10，均原为 FTDIBUS。记录 logs/20260926-reconnected-devices.json。
- 从官方 pbatard/libwdi v1.5.1 克隆源码（9b23b82a2dd1cbffc16d46c212f92c6bf8c0c602），使用本机 MinGW 构建 wdi-simple。旧 SDK 缺少 SYSTEM_CODEINTEGRITY_INFORMATION，按 Microsoft 文档补充同布局声明后构建成功；没有修改 libwdi 逻辑。config 与兼容头保存 scripts/。
- WinUSB coinstaller 取自本机 DriverStore android_general.inf 的 amd64 目录，两份 DLL Authenticode 均 Valid；仅用于本机，不上传二进制。
- 非管理员 --extract 成功生成仅匹配 VID_0403&PID_6010&MI_00 的 INF；未生成 CAT（缺少提升权限），符合工具日志。
- 通过 Start-Process powershell.exe -Verb RunAs 正常提权成功，执行 scripts/install-jtag-a.ps1。先导出 oem178.inf 到 E:/gaoyun/tools/ftdi-driver-backup，然后限定 VID/PID/MI=0 安装 WinUSB。
- 安装成功：A=WinUSB/oem180.inf/ProblemCode 0；B 保持 FTDIBUS，原 Code 10 未消失。原始安装日志 logs/20260926-winusb-install.txt。
- openFPGALoader --scan-usb 能列出 FTDI2232 0403:6010（描述字符串为 none）。随后 -b tangprimer20k --freq 2500000 --detect -v 返回 exit 1：unable to open ftdi device: -6 (ftdi_usb_reset failed)。未开始 SRAM 下载。
- 已核对原 LED 工程芯片、H11/N16、LVCMOS33/4mA，led.fs SHA256 与交接一致。仍未确认点灯成功。

## 2026-09-26：USB 软件恢复、JTAG 成功与 SRAM 失败

- 使用管理员 pnputil /restart-device，仅重启 USB\VID_0403&PID_6010\FACTORYAIOT_PRO。首次 19:12:45 完成，A=WinUSB、B=FTDIBUS，均 OK。
- -b tangprimer20k --freq 2500000 --detect -v 成功退出（0），读到 0x0000081b，实际时钟 2 MHz；日志 20260926-jtag-detect-after-restart.*。
- 核对上游 v1.1.1 Gowin SRAM 路径不会进入 Flash 访问的 10 MHz 设置，保持请求频率限制。
- 19:13:56 使用 --write-sram -v E:/gaoyun/led.fs。起始状态 0x6020；SRAM erase 阶段先读到 0x60a0，随后异常值 0x7f000000，接着 usb bulk write failed。未进入正常 Load SRAM 完成流程。
- 45 秒超时结束该下载进程，明确不计为成功。原始标准输出、全部错误和命令/哈希/进程状态见 20260926-sram-winusb.*。
- 19:15:13 再次软件重启成功，随后计划以 100 kHz 检测降低速率的影响；检测返回 device not found，没有再次写入。Windows 枚举也变成 0 个匹配设备，已请求用户物理重插 USB-JTAG 并尽量直连电脑。
- scripts/restart-dock-usb.ps1 当前日志为第二次重启（首轮结果时间由本节补录）。未操作 Flash、OTP 或下载器固件。

## 2026-09-26：通道隔离试验、直连后 SRAM 成功

- 前一阶段后续：100 kHz 检测在设备重新出现后返回 ftdi_usb_reset failed。临时禁用 B（Code 22，保留 FTDIBUS）并重启父设备后，检测可读 ID；后续下载在 USB 初始化失败，未进入 SRAM 写入。
- 再次重启后直接低速下载返回 device not found，同时 libusb 记录另一个 VID_0000/PID_0002 无效描述符；不能仅凭该行认定其就是此板。没有借此认定板损坏。
- 用户明确报告已直连，要求避免损坏并参考既有案例。19:20 枚举记录在 direct-connection-state.json；没有残留烧录器。
- 首次状态查询命令有 PowerShell foreach 管道语法错误，未执行设备操作；改成先收集结果再输出后成功。
- 执行 scripts/restore-uart-b.ps1 正常提权恢复 B，确认 FTDIBUS、ProblemCode 0。通道隔离试验已结束，不能证明 B 是根因。
- 参考上游 issue #250（https://github.com/trabucayre/openFPGALoader/issues/250）及 troubleshooting：同型号存在历史 SRAM/下载器问题讨论，但没有证据证明当前根因相同；其中其他型号 Flash 擦除建议不适用本授权范围，未执行。
- 直连后两次连续 100 kHz --detect 均成功（0x0000081B，exit 0），见 direct-detect 与 direct-detect-repeat 日志。
- 19:21:43 核对原码流 SHA256、无残留烧录器后，执行 openFPGALoader -b tangprimer20k --freq 100000 --write-sram -v E:/gaoyun/led.fs。预设最多 120 秒、出现 USB 通信错误即停止；实际 19:21:46 正常完成。
- 结果：SRAM erase 成功，Load SRAM 100%，DONE，after program sram=0x00006020（Memory Erase / Done Final / Security Final），exit 0，stderr 为空。工具报告请求/实际 100 kHz；没有物理测量时钟，主机耗时也不能当硬件速率证据。
- 验证边界：上游 v1.1.1 gowin.cpp detectFamily 对 0x0000081B 设置 skip_checksum=true，因此没有进行独立软件 checksum 比较或完整 SRAM 回读验证。确认的是工具完成配置且 DONE 置位，不把它写成实物点灯已成功。
- 成功后只读 Windows 枚举：A=WinUSB/oem180.inf/0，B=FTDIBUS/oem178.inf/0，均 OK；没有残留烧录器。停止进一步硬件操作，等待用户确认 LED2 是否闪烁。
- 本轮所有 FPGA 写入均为 SRAM；无 Flash、OTP、下载器固件更新。无法仅凭日志保证温度或硬件完好。

## 2026-09-26T19:23:58+08:00：用户确认实物点灯成功

- 用户先反馈：“有个灯在闪 不清楚哪个”。此时仅记录有闪烁现象，未提前认定目标 LED。
- 随后用户反馈：“没问题了 看到丝印了 可以了 记录推到github上去”。结合此前 LED2 确认问题，记录为用户已查看丝印并确认目标 LED2 闪烁，点灯成功。
- 最终证据：原码流身份核验通过；openFPGALoader SRAM 写入 100%、DONE、exit 0；用户实物确认。独立软件 checksum/完整回读验证仍未执行，不扩大验证结论。
- 保留成功配置：USB-JTAG 直连电脑；A 为 WinUSB，B 为 FTDIBUS 且已恢复启用；下载命令请求 100 kHz，仅 SRAM。
- 本次仅更新 README 与操作记录并提交推送，没有再次烧录、重启 USB 或修改驱动。SRAM 配置断电失效。
- USB 直连、驱动绑定和低速设置共同构成此次成功条件；尚未通过受控对照确定此前失败的唯一根因。

## 2026-09-26：核对官方题目并制定设计与采购方案

- 用户确认已报名 2026 高云选题二；已有 DS100 MINI、面包板，可借万用表，无耳机/音箱。新增预算由方案合理规划，未代为下单。
- 查阅高云 2026 官方页面、Sipeed Primer 20K 资料及 PT8211 示例、PT8211 原厂手册、TI PCM5102A、Microchip MCP3008、DFRobot 摇杆规格、正点原子 DS100 产品资料。
- 比赛站 fpgachina.cn 访问超时；本轮赛题依据为高云官方网站，不用 2024/2025 规则替代 2026 资格结论。
- 新增 docs/instrument-plan-2026.md：建议 8 键加双轴摇杆，先 4 复音后 32 声部，标准 I²S DAC、准确采样时钟方案、延迟与频谱验收、分批采购及时间安排。价格为预算估计，未核对具体店铺成交价。
- 发现两项应保留的边界：官方适配名单未明确列出 Primer 20K，正式参赛资格需赛方确认；板载 PT8211 为 LSBJ 格式，建议外接标准 I²S DAC 以匹配题意。现有 Dock 有 5 个用户按键，前期不必另买按键。
- 本阶段仅查询资料和更新文档，没有执行硬件扫描、下载、驱动变更或采购交易。

## 2026-09-26：审阅用户提供的三组资料并修正板卡资格结论

- 清点 20 个文件，生成 logs/20260926-reference-inventory.json；检查 ZIP 清单但不解压执行工程，不下载任何码流到板上。
- 在“2019-2021往年板卡资料”目录发现真正的 2026 选题指南（22 页）。文本提取首次因终端 GBK 输出特殊符号失败；改为 UTF-8 后成功。使用 Poppler 渲染并目视核对 PDF 第 13、15、16 页。
- 第 13 页（印刷 11）明确允许自备第三方高云 FPGA 板，故 Primer 20K 符合平台条件；修正此前仅凭官网推荐名单产生的待确认项。电子乐器要求与官网一致。
- 审阅学习资料索引及 2025 宣讲相关章节；两个目录的宣讲 PDF SHA256 相同。历史建议和其他赛题评分未作为 2026 电子乐器规则。
- 新增 docs/reference-review-2026.md，更新设计方案与 README。原 PDF、完整文本及预览仅保留本地；仓库保存结论、资源候选链接和哈希。
- 本阶段没有改变板卡、驱动、烧录状态或采购任何物品。

## 2026-09-29T00:53+08:00：修复 audio_probe 构建失败并下载案例到 SRAM

- 用户要求“单纯跑一下案例”，即不改设计、把已有 audio_probe 案例跑起来试听。本阶段只修构建环境，未改动任何 RTL 逻辑。
- 复现 9/29 凌晨的失败：`logs/20260929-audio-build.stdout.log` 报 `ERROR (TA2000) : "audio.sdc":1 | 'syntax error' near token 'clk]'`；直接重跑报 `Project already exists on disk, please use '-force' option to overwrite`。
- 定位方法：逐字节比对 `audio_probe/audio.sdc` 与已成功的 `led/led.sdc`。两者内容完全相同，唯一差别是行尾——audio.sdc 只有 LF，led.sdc 是 CRLF。因此判定为高云 SDC 解析器对裸 LF 行尾的兼容问题，不是约束内容或 RTL 错误。
- 处理：audio.sdc 以 ASCII + CRLF 重写（59 字节，尾部 `0D 0A`）；`build.tcl` 的 `create_project` 增加 `-force`，避免残留工程目录导致重跑失败。RTL 与约束内容均未改动。
- 重新编译：`logs/20260929-audio-build-fixed.*`，命令为 `gw_sh.exe E:/gaoyun/d-dfdf/audio_probe/build.tcl`，Exit=0；日志含 `Placement and routing completed`、`Bitstream generation completed`，0 个 ERROR/WARN。
- 产物：`E:\gaoyun\projects\audio_probe\audio_probe\impl\pnr\audio_probe.fs`，4,620,698 字节，SHA256 `F45AEE6BD4EA92BA6C940CFD812FBF754D774719DE44EEFEE4A6CCBD61D5963A`；头部 Part Number `GW2A-LV18PG256C8/I7`、LoadingRate 2.500MHz、CRCCheck ON、SecurityBit ON、Encryption OFF。
- 引脚复核：与 Sipeed 官方 Dock 约束一致（README「Audio DAC」表）：PA_EN R16、HP_DIN P15、HP_WS P16、HP_BCK N15、clk H11、rst_n T3。未改动约束。
- 只读识别：`openFPGALoader --scan-usb` 列出 `001/007 0x0403:0x6010 FTDI2232 SIPEED FactoryAIOT Pro JTAG Debugger`；`-b tangprimer20k --freq 100000 --detect -v` 读到 idcode `0x81b`，exit 0，stderr 空。见 `logs/20260929-audio-probe-detect.*`。
- 00:54:41–00:54:44 下载：`openFPGALoader -b tangprimer20k --freq 100000 --write-sram -v <audio_probe.fs>`。下载前确认无 programmer_cli/openFPGALoader/Programmer 进程占用，码流 SHA256 再次核对一致。
- 结果：SRAM erase 成功、`Load SRAM 100.00%`、`DONE`、`displayReadReg 00006020`（Memory Erase / Done Final / Security Final）、exit 0、stderr 空。见 `logs/20260929-audio-probe-sram-100k.*`。仅写 SRAM；未执行 Flash 擦写、OTP 或下载器固件更新。
- 预期可听现象：Dock 板载 3.5 mm 耳机孔（LPA4809MSF 耳放，由 PA_EN 使能）输出 440 Hz 三角波，响 1 秒、停 1 秒；幅度约满量程 1.6%，是刻意压低的结果，试听需提高音量。
- 验证边界：本阶段只证明工具完成 SRAM 配置（工具自报 100 kHz，未做物理时钟测量）。**听力结果待用户反馈，尚未判定“已发声”**；上游 v1.1.1 对 idcode `0x0000081B` 设置 skip_checksum，不做完整回读校验。
- 备用对照（尚未下载）：Sipeed 官方预编译 `tools/sipeed-example/PT8211/pt8211.fs`（连续正弦、官方提示声音大，同芯片同引脚），可用于区分“板载音频通路问题”与“本设计问题”。
- 00:5x 用户反馈“怎么还没烧进去”，并授权更快的 JTAG 速度。在此之前已完成的一次 100 kHz 下载是成功的（见上），但本设计**不驱动任何 LED**，板面看起来“没反应”属正常，容易与“没烧进去”混淆。
- 提速复烧：`--freq 2500000 --write-sram`，结果同样是 `Load SRAM 100.00%`、`DONE`、`displayReadReg 00006020`（Done Final）、exit 0、stderr 空，见 `logs/20260929-audio-probe-sram-2500k.*`。2.5 MHz 本次可用；此前 9/26 在 2.5 MHz 失败是当时驱动/通道异常状态下的现象，不能推广为“2.5 MHz 不可用”。
- 已知未决：可听现象只有耳机孔里的 440 Hz 轻音（约满量程 1.6%），听力反馈仍未取得。
- 推送状态（必须如实记录）：本阶段提交 `5a8f250` 已建立于本地，`git push origin main` **失败**。原因不是仓库权限，而是本机当前无法与 GitHub 建连：沙箱内 schannel 报 `SEC_E_NO_CREDENTIALS`、openssl 后端报连接被重置，完全权限下报 `Failed to connect to github.com:443`。因此 `main` 领先 `origin/main` 1 个提交，**未同步**，待网络恢复后重推。

## 2026-09-29：音频探针修复、升级为四键演奏，以及“突然失灵”与 Flash 调研

### 音频探针（audio_probe）修复

- 构建失败根因确认：`audio.sdc` 行尾是 LF，高云 SDC 解析器报 `ERROR (TA2000) : "audio.sdc":1 | 'syntax error' near token 'clk]'`。与已通过的 `led/led.sdc` 逐字节比对，两者内容完全相同，唯一差别是行尾（LF 对 CRLF）。改为 CRLF 后 `Exit=0`、0 错 0 警。
- 防复发：新增 `.gitattributes` 固定 `*.sdc text eol=crlf`；`build.tcl` 的 `create_project` 加 `-force`（否则重跑报 `Project already exists on disk`）。
- 引脚报告暴露真实缺陷：`audio.cst` 未写 `IO_TYPE`，工具按默认 **LVCMOS18 / 1.8 V** 配，而板子这些脚在 **3.3 V** bank（对比：能点灯的 `led.cst` 用的是 LVCMOS33/3.3）。已补 `IO_TYPE=LVCMOS33`。
- 音量与听感：首版幅度仅满量程 1.6%（约 -36 dB），用户要求加大，改为满量程并加 5 ms 淡入淡出（避免满音量下的开关爆音）。用户反馈“只能听到噪音”，诊断出另一原因：`PA_EN` 常开时会一直放大耳放本底噪声；新版本改为**仅发声时使能耳放**。
- 另发现该设计**不驱动任何 LED**（引脚表只有 6 个音频脚，N16/N14/L16 都是未使用的输入脚），所以“没有灯闪”曾被误判为烧录失败；后续版本加了心跳灯。
- 码流与验证：`audio_probe`（满量程 + 淡入淡出）SHA256 `C9BBF8F4F0CFDD33128C0827FBF29238EF539DD224EA2C6548C243D07211C5BA`；仿真 `logs/20260929-audio-probe-v3-sim.log` PASS；2.5 MHz 仅 SRAM 下载 `Load SRAM 100%` / `DONE` / `00006020` / exit 0。

### 四键演奏（audio_keys）

- 引脚来源：官方仓库 Litex 版 Dock 约束 `Litex/sipeed_tang_primer_20k/src/sipeed_tang_primer_20k.cst`。5 个用户按键 = `T10 T3 T2 D7 C7`（低有效）；LED0..5 = `L16 L14 N14 N16 A13 C13`；音频 = `N15 P16 P15 R16`；`clk` = H11。与本机已知的官方 PT8211 例程（`rst_n`=T3）交叉验证一致。
- `T10` 在 Gowin 里是 **SSPI 专用脚**：约束到它报 `ERROR (PR2017) : 'btn_n[0]' cannot be placed according to constraint, for the location is a dedicated pin (SSPI)`。因此本版只用 4 个键 `T3 T2 D7 C7`。**用户按丝印反馈：不发声的那颗是 S0**，即 T10；这与 Sipeed 资料中“The reset pin on primer 20K is T10”一致。要启用 S0 需把工程的双用途脚设成“SSPI 作普通 IO”（官方 PT8211 工程即为 `SSPI: true`），**本阶段未修改**，列为已知限制。
- 电平：4 个按键位于 **1.5 V bank**（DDR3 bank），故声明 `IO_TYPE=LVCMOS15`；其余 3.3 V。布局报告逐条核对通过：`T3/T2/D7/C7 = LVCMOS15 / 1.5 V`，`N15/P16/P15/R16/N16/N14 = LVCMOS33 / 3.3 V`。
- 设计取舍（由仿真驱动）：最初“先消抖再起音”的写法经仿真算出**按下到出声需约 10.5 ms**（5 ms 消抖 + 5.5 ms 淡入），超过赛题端到端 ≤10 ms 的要求，改为**即按即响（仅两级同步器）+ 松开后才消抖 5 ms**；包络 1 ms 淡入 / 5 ms 淡出；单音（最低键优先）；`PA_EN` 仅发声时使能。
- 仿真（iverilog，`logs/20260929-audio-keys-sim.log`）：空闲无声且耳放关闭；按键 0 半周期实测 **957,654 ns**（理论 955,700，+0.2%）；按住时 1 ms 抖动**不会**切断声音；松开后 12 ms 内静音且耳放关闭；按键 3 半周期 **638,594 ns**（理论 637,800，+0.12%）。测试台按 `HP_WS` 分帧解码（早期用固定位计数会错开一位，属测试台缺陷，已修正）。
- 编译 `Exit=0`、0 错 0 警；2.5 MHz 仅 SRAM 下载成功。码流 SHA256 `7C1B92AD60D2238C504A5DC255B4BDD014C4FFD1783F5AEB6E90DCB226CBADA9`。原始日志 `logs/20260929-audio-keys-build*`、`-sram-2500k.*`、`-reflash.*`、`-restore.*`。

### “一开始好使、突然不好使”的排查

- 证据：FTDI 自 00:54:24 起**没有重新枚举**（未拔插、未断电）；JTAG 仍能读到 `0x81b`；无残留烧录进程。说明 FPGA 一直带电，程序消失只能来自**被重新配置**。
- 两个候选成因：(1) 用户按下了 S0/T10（Sipeed 把 T10 标为 reset pin）；(2) 调试器/USB 抖动——本阶段实际出现 `ftdi_usb_reset failed`、`--scan-usb` 中 manufacturer/serial/product 全变为 `none`、JEDEC 容量字节一次读成 `0x0F`（正常 `0x17`）。两者都会让 SRAM 配置丢失，因为 **Flash 是空的**。
- 处置：重烧 SRAM 恢复（`-reflash`；随后因 Flash 检测清空 SRAM，又执行一次 `-restore`，均 2.5 MHz 成功）。恢复成本 = 一条命令约 5 秒。
- 结论：**只写 SRAM 时，任何复位或配置抖动都会让板子变空**。这是是否固化 Flash 的核心权衡依据。

### Flash 固化调研（未执行任何写入）

- `openFPGALoader --detect -f`：板载 NOR 识别为 JEDEC `0B 40 17`（8 MB），`RDSR = 0x00`（无块保护、非忙，可写）。
- Flash **不是空片**：dump 前 64 KB 中仅 942 字节为 `0xFF`；内容无高云码流 ASCII 头，判断为出厂演示/测试码流。前 64 KB 已备份到 `E:\gaoyun\tools\tang20k-flash-first64k.bin`（未入仓库，`*.bin` 已被忽略）。
- 副作用必须记录：`--detect -f` 与 `--dump-flash` 会先 **Erase SRAM**（输出 `Erase SRAM DONE`），会清掉正在运行的 SRAM 配置；本次因此多烧录了一次。
- 读取可靠性不足：同一芯片两次读出的 JEDEC 容量字节不一致（`0x17` / `0x0F`，相差 1 bit），随后 FTDI 链路直接无法打开（`unable to open ftdi device`、`ftdi_usb_reset failed`），拔插 USB 后恢复（总线设备号 007→008）。结论：该板 SPI/USB 链路余量不足，**写 Flash 之前必须先做整片双读一致性校验，写入时必须带 `--verify`**，并预留失败恢复办法。
- 未执行 Flash 擦写、OTP 或下载器固件更新；是否固化待用户决定。已向用户说明收益（复位/掉电/调试器抖动后自动回到本设计）与风险（覆盖出厂内容；若双用途脚配置不当会导致上电后 JTAG 失效，需短接 Flash 1、4 脚恢复）。

### 推送状态

- 以上所有源码与日志随本节一起提交并推送；此前因网络不可达而滞后的 `5a8f250`、`d2ff8dd` 也一并推送。若本次推送失败，以本节所述为准，不得声称已同步。

## 2026-09-29：S0/S4 按键核对与芯片到货前安排

- 用户反馈 S0 无法发音、S4“貌似重启”，新增 ADC/DAC 等芯片尚未到货。本阶段只读本地工程及 Sipeed 官方约束，不操作板卡。
- 官方示例的 btn_n0..btn_n4 分别映射 S0=T10、S1=T3、S2=T2、S3=D7、S4=C7；官方 README 又称 T10 为复位脚。当前 audio_keys 工程实际使用 S1–S4，S0 不在音频逻辑里，所以 S0 不发音是设计所致，暂不启用 T10 双用途。
- 官方资料把 S4/C7 列为普通输入；用户仍观察到疑似“重启”。当前不能仅凭该描述判定物理按键、板卡版本或复位原因；已询问按 S4 后无需重烧时 S1 是否仍能发声，以区分程序仍在与 SRAM 配置丢失。
- 新增 docs/button-audio-next.md，并修正 instrument-plan-2026.md 中“5 个用户按键”易误读之处。计划在现有 PT8211 与 S1–S4 上先实现并验证四个独立声部；若 S4 确有故障，再单独诊断或改外接键。
- 本阶段未执行 JTAG、Flash、OTP、固件更新、驱动修改或其他硬件操作。

### 用户对按键与断电状态的补充

- 用户说明板子在本轮问答前已经断过电，所以当前无法从“按 S1 是否还响”判断此前按 S4 后的情况；SRAM 内容在断电后本来就会丢失。
- 用户回忆 S0 起初无声而其他功能正常，后来出现失效。该现象与 S0/T10 的复位用途相容，但缺少当时的心跳 LED、其他按键和重烧状态证据，不能唯一确定原因，更不能把 S4 也判为复位键。
- 已更新 docs/button-audio-next.md：下次板上测试先重装已核对的 SRAM 码流，先验 S1–S3，再单次测试 S4，始终避开 S0；必要时使用仅 LED 状态指示的诊断码流。芯片到货前先做四声部软件仿真。
- 此次补录仅改文档，没有操作板卡。

## 2026-09-29T22:43+08:00：四键音频 SRAM 重载与 Flash 可行性核查

- 用户要求重新烧录，并询问能否写入 Flash，授权助手自行检查。沿用 JTAG 请求频率上限 2.5 MHz；本阶段没有按屏幕操作。
- Windows 当前可见 0403:6010：A=WinUSB、B=FTDIBUS、复合父设备 usbccgp，三者 ProblemCode 0。无残留 programmer_cli/openFPGALoader/Programmer 进程。
- 目标码流 E:/gaoyun/projects/audio_keys/audio_keys/impl/pnr/audio_keys.fs，SHA256 核验仍为 7C1B92AD60D2238C504A5DC255B4BDD014C4FFD1783F5AEB6E90DCB226CBADA9；头部 PN GW2A-LV18PG256C8/I7、C 版、Encryption OFF。没有改 RTL。
- Flash 暂不写入的具体依据：本地仅有前 64 KB 出厂内容备份，并无可靠整片双读一致性备份；上次 JEDEC 容量字节读数 0x17/0x0F 不一致，USB/FTDI 链路曾失败；本机 openFPGALoader v1.1.1 源码 Gowin::prepare_flash_access() 在 Flash 路径调用 setClkFreq(10000000)，不满足当前最高 2.5 MHz 的约定。官方 Gowin 说明也把直接 -f 的支持范围限定为其他几款板卡。基于现有证据，不能把“能执行 -f”当作可安全固化。
- 只读检测：openFPGALoader -b tangprimer20k --freq 100000 --detect -v 返回 idcode 0x0000081B、exit 0、stderr 空；见 logs/20260929-audio-keys-redetect.*。
- SRAM 重载：openFPGALoader -b tangprimer20k --freq 100000 --write-sram -v <上述 fs>，02.63 秒内正常返回，Load SRAM 100%、Done Final、exit 0、stderr 空；见 logs/20260929-audio-keys-sram-reload.*。没有写 Flash、OTP 或下载器固件，也没有读取或改写 Flash。
- 已请用户用耳机试 S1–S3 后单次试 S4，观察其是否影响其他键；避免按 S0/T10 复位键。实物发声结果待反馈，不能仅凭命令成功声称本次听到了音。

## 2026-09-29T22:53+08:00：纠正 RCFG 误认、恢复 SRAM 音频

- 用户在第一次 22:43 重新下载后按其称作“S4”的按键，随后其他键也没声；用户又反馈“心跳灯仍闪、按键灯有反应”。此灯光现象只证明 FPGA 有逻辑在运行，不能证明仍是 audio_keys。此前将它解释为“audio_keys 仍在运行、仅音频通路故障”是错误推断。
- 回看用户此前提供的实物照片：左侧底部按键丝印为 RCFG。用户明确确认所谓“S4”就是这颗 RCFG。参考 Tang Primer 20K Dock 3713 原理图可见低有效 RECFG 信号；RCFG 不应视为普通演奏键。按下后原 SRAM 音频设计消失，可能转入 Flash 中的出厂设计；后者内容未回读确认，故只记为合理解释。
- 因这个按键误认，早期 README“4 个实体键可演奏”和 docs/button-audio-next.md 中“S4=C7 可演奏”均失去依据，现已纠正。现有 RTL 仍有 4 个逻辑输入 T3/T2/D7/C7，但只有实物 S1/S2/S3 已经逐个听到声音；S0 尚未发声，丝印到各逻辑脚的完整一一映射未实测。
- RCFG 后只读 JTAG 检测：`openFPGALoader -b tangprimer20k --freq 100000 --detect -v` 读到 0x0000081B、exit 0；USB 产品及序列号字符串读取为空，警告保留在 logs/20260929-post-rcfg-detect.out.txt。
- 再以请求 100 kHz、仅 `--write-sram` 重载 SHA256 7C1B92AD60D2238C504A5DC255B4BDD014C4FFD1783F5AEB6E90DCB226CBADA9 的 audio_keys.fs。Load SRAM 100%、Done Final、exit 0、stderr 空；logs/20260929-post-rcfg-sram-restore.*。用户随后确认左侧 S1/S2/S3 三键均有音。
- 不再按 RCFG 重复验证；未写 Flash、OTP、下载器固件，未重编译码流。Flash 备份不完整、既有读数不一致及工具内部 Flash 时钟超过 2.5 MHz 的限制仍在，暂不固化。

## 2026-09-29T23:07–23:12+08:00：S0/T10 修复已实物验证；Flash 继续只读评估

- 用户要求查明 S0 不发声并研究 Flash 处理。旧工程 audio_keys 不约束 T10，本地工程流程配置 SSPI=false；之前对 T10 约束时曾出现 PR2017（SSPI 专用脚）。官方 Gowin Tcl 文档支持 set_option -use_sspi_as_gpio 1，官方 Sipeed PT8211 示例也有 SSPI=true。
- 新建独立 `s0_probe`：T10=LVCMOS33 输入，N14 灯跟随按键，N16 心跳；只把 SSPI 设为 GPIO，JTAG/MSPI/RECONFIG_N 明确保留专用。构建 Exit=0，无 ERROR/WARN，码流 SHA256 9BA62ECFAD24A674BB90E0EB0F0A0D0D9B8632F170323A6A204143225A3CDD0D。
- 请求 100 kHz 只读扫描读到 0x0000081B、exit 0；FTDI 产品与序列字符串为空的警告保存在 logs/20260929-s0-detect.*。随后只写 SRAM，Load SRAM 100%、Done Final、exit 0，见 logs/20260929-s0-sram.*。用户确认左侧最上方 S0 按下时 LED3 跟随亮灭，心跳灯继续闪：T10 对应该键且输入有效。
- 原四键音频码流 SHA256 7C1B92AD... 已先单文件备份到 E:/gaoyun/tools/audio_keys-pre-s0-7C1B92AD.fs，未入库。audio_keys 的四路输入改为 S0/T10（3.3 V）、S1/T3、S2/T2、S3/D7（后三路 1.5 V）；RCFG 仍为重配置用途，不用 C7 当第四键。build_keys.tcl 仅启用 SSPI GPIO，JTAG/MSPI/RECONFIG_N=0。
- 现有音频仿真再次 PASS（空闲静音、按键 0/3 音高、短时弹跳、松开后静音）。高云构建 Exit=0，无 ERROR/WARN；引脚报告 T10/3=LVCMOS33/3.3 V、T3/T2/D7=LVCMOS15/1.5 V；流程配置 SSPI=true，其余三项=false。新码流 SHA256 2D155BB754EC8C6238C57320220F5EE24E029907742F575C61FB7C61D5B4162E。
- 请求 100 kHz 仅 SRAM 下载新音频：Load SRAM 100%、Done Final、exit 0、stderr 空；见 logs/20260929-audio-s0-sram.*。用户随后确认 S0 有音，S1/S2/S3 也都正常。当前仍是最低键优先单音，未达到四复音。
- Flash 研究：最新发布版 v1.1.1 与 master 的 Gowin::prepare_flash_access 均调用 setClkFreq(10000000)；公开问题 #472 的外部 Flash dump 也记录 10 MHz。此路径违背请求频率≤2.5 MHz，而且既往 JEDEC 字节不一致、只备份前 64 KiB。新增 docs/flash-readiness.md 列出低频工具、稳定识别、整片双读一致性备份、外部 Flash 写入校验及掉电恢复验证等门槛。高云 CLI 尚无已验证的整片原始导出路径。
- 本阶段未读、擦、写 Flash；未操作 OTP 或下载器固件。代码审查已核对修改仅涉及 SSPI 选项、四路引脚重排、说明注释；无新增输出驱动到 T10 或专用配置脚。

## 2026-09-29T23:27–23:30+08:00：撤销过时频率上限后只读复查 Flash

- 用户明确澄清：“自行约定的要求只有不要烧掉板子，不包括速度限制”。该最新要求覆盖交接时的 2.5 MHz 上限；已更正 AGENTS.md、README 与 docs/flash-readiness.md。Flash 写入此前已被用户授权研究，但必须先证明备份与传输可靠。
- 在确认无残留烧录器、音频码流 SHA256 2D155BB7... 未变后，使用 openFPGALoader v1.1.1 的 `--external-flash --dump-flash --file-size 65536` 只读同一前 64 KiB。命令行初始 `--freq 100000`，工具 Flash 路径报告 requested 10 MHz / real 6 MHz；两次 JEDEC 均报告 `0B 40 17`、输出文件 65536 字节、exit 0。原始输出见 logs/20260929-flash-read64k.* 与 -repeat.*。
- 先前前 64 KiB 备份 SHA256 EF09DAE103583F2F9AF766C6683679E8566663997619E862852A72C9A747BCFA；本轮 A 为 3306FF6D3DB9E2442CF4D0363DE36469A46BA89440BC14A4D3DAC4457CF8C3E5；B 为 DCE65A79ECCA5A7033722A2CCE49F5390BA8DC0E26A5D529A6FB035C39694BF0。旧版/A 相差 268 字节；A/B 相差 277 字节、321 比特；旧版/B 相差 242 字节。差异记录见 logs/20260929-flash-read64k-compare.txt 与 -repeat-compare.txt。原始二进制留在 E:/gaoyun/tools/flash-backup/20260929/，不上传仓库。
- 结论：同一板在无写入、无换线的两次新读仍不一致，不能把退出码 0 和进度 100% 当成可靠 Flash 备份。立即停止整片读取及擦写；这个实测阻碍与用户是否设置速度上限无关。后续先用可信低速路径或独立 3.3 V SPI 读出路径让多次同一区域逐字节一致，再取得整片双份一致备份，之后才考虑写入并校验。
- Flash 读取清掉了当前 SRAM 配置；随即以请求 100 kHz 重新下载已核对 SHA256 的 S0–S3 音频码流，工具 Load SRAM 100%、Done Final、exit 0、stderr 空，见 logs/20260929-after-flash-read-sram-restore.*。用户确认四键耳机声音都正常。
- 本阶段没有擦写 Flash、OTP 或下载器固件，也没有驱动变更。

## 2026-09-30T00:04+08:00：低频外置 Flash 写入尝试卡住；尚未验证成功

- 依照用户明确要求，尝试将已在 SRAM 验证的 S0–S3 音频码流写到外置 SPI Flash，并启用写后校验。码流：`E:/gaoyun/projects/audio_keys/audio_keys/impl/pnr/audio_keys.fs`，SHA256 `2D155BB754EC8C6238C57320220F5EE24E029907742F575C61FB7C61D5B4162E`，解析出的配置数据 577,178 B，从地址 0；擦除日志显示 `0x000000`–`0x090000`（9×64 KiB），未发出 bulk erase。
- 命令：`openFPGALoader-lowclock/openFPGALoader.exe -b tangprimer20k --freq 100000 --external-flash --verify --write-flash -v <audio_keys.fs>`。该工具是基于上游 v1.1.1（源码 commit `85be4fa02b2dd6a83716d7dfac3d25bbd260ff7b`）本地构建的诊断版，Flash 访问 JTAG 请求 2.5 MHz、报告实际 2.0 MHz。
- 实际识别到 FPGA `0x81B` / GW2A(R)-18(C)，读到 Flash ID `0B 40 17`，保护位 BP=0。擦除报告完成；写入进度到 40.58% 后超过 60 秒无变化，进程读写计数不再增加。已结束卡住的 openFPGALoader 进程。**写入与校验均未完成，Flash 内容现在可能是部分写入状态，不能声称成功。**原始进程日志 `logs/20260930-audio-flash-program-verify.log` 截止于 40.58%。
- 结束进程后 USB 复合设备仍可枚举，但 JTAG A 通道 `low level FTDI init failed`，SRAM 恢复命令 exit 1。Windows `pnputil /restart-device` 对 MI_00 返回 Access is denied；没有变更驱动。正在等用户物理拔插 USB-JTAG 以复位下载器，然后只恢复 SRAM、读取 JTAG ID 并记录。当前还未重试 Flash 写入。
- 2026-09-30 低频诊断期间同一 64 KiB 读取仍相差 268 B/316 bit，意味着没有可靠的原厂 Flash 备份。用户最新目标授权了本次烧录验证，但未授权 OTP、bulk erase 或下载器固件更新。
- Software `libusb_reset_device(0403:6010)` returned success but did not restore JTAG. `--scan-usb` continued to enumerate the board; JTAG `--detect` still failed with bulk read / low level FTDI initialization error. No retry of Flash programming was made.

- 2026-09-30 follow-up recovery diagnostics: libusb device reset returned success; a temporary libftdi helper successfully opened/reset Interface A; neither operation restored JTAG. Gowin Programmer read-only scan exited 49 (`Cable failed to open via the channel`, `No Gowin devices found`); a lingering scan process was terminated. A cable-index 5 read-only scan did not yield a captured result. No second Flash operation was run. Physical USB-JTAG unplug/replug is still needed before SRAM recovery.
