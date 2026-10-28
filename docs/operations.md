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

- 用户拔掉 Dock 全部 USB 供电并等待 10 秒后重新连接。USB 设备描述符恢复为 FactoryAIOT Pro，JTAG 只读识别 ID 0x81B / GW2A(R)-18(C)。原版工具 SRAM 上传虽到 100%，但状态寄存器出现 CRC Error/Timeout/Bad Command，不计为成功；随后本地低频诊断版完成相同 SRAM 码流加载，最终状态 0x00006020（Done Final / Security Final）、exit 0。码流 SHA256 2D155BB754EC8C6238C57320220F5EE24E029907742F575C61FB7C61D5B4162E。用户尚未复听确认。Flash 仍可能部分写入，尚未再次尝试擦写。

- 2026-09-30 第二次 Flash 写入尝试仍停在 35.13%，数分钟未推进百分比。Windows Other I/O 计数缓慢变化，但没有更多写入进度；为避免无限等待，结束进程。擦除命令范围仍为 `0x000000`–`0x090000`，码流 SHA256 与前次相同。写后校验未开始，不能算烧录成功。
- 结束后设备 USB 描述符可重新枚举，但 JTAG detect 再次报 `usb bulk read failed` / `low level FTDI init failed`；libusb device reset 和 FTDI A reset 均未修复。没有再次恢复 SRAM。最后确认正常的是此前全板 USB 断电重连后 SRAM 的 Done Final 状态；目前需全板断电重连后再恢复 SRAM。没有物理损坏的证据；Flash 内容仍为部分写入/未知状态，不做第三次 Flash 写入。

## 2026-09-30T12:37–12:47+08:00：换电脑 USB 口恢复下载器与 SRAM；官方通道只读检查

- 上次部分 Flash 写入后无残留烧录进程，Windows 原端口上先识别到 0403:6010，但产品字符串为空、FTDI reset 报 -6；用户全板断电重连后，原电脑 USB 口变为 `USB\\VID_0000&PID_0002`、Code 43（设备描述符请求失败），与此前下载器在同一主机 USB HS12 端口。此时没有执行写入。
- 用户保持板上供电、把 USB-JTAG 线的电脑端换到另一个直连 USB 口。Windows 重新识别 0403:6010，A（JTAG Debugger/WinUSB/oem180.inf）和 B（FTDIBUS/oem178.inf）均 OK。openFPGALoader 只读识别 FPGA ID `0x81B` / GW2A(R)-18(C)，exit 0。
- 本地低频诊断版 openFPGALoader 使用 `-b tangprimer20k --freq 100000 --write-sram -v` 重新装入 SHA256 `2D155BB754EC8C6238C57320220F5EE24E029907742F575C61FB7C61D5B4162E` 的四键音频码流；最终寄存器 `0x00006020 / Done Final`、exit 0。用户逐键试听确认 S0–S3 都有声。原始日志 `logs/20260930-new-usb-port-sram-restore.log`。
- 高云 Programmer CLI 的 FT2CH（`--cable-index 1 --frequency 2.5MHz --scan`）只读扫描 8 秒无返回，已结束该扫描进程；WinUSB（`--cable-index 5 --frequency 2.5MHz --scan`）返回 `0x60010000` 和 16 个 General/JTAG_NOP 设备，并非真实 `0x81B` 链。未让高云工具执行写 Flash。当前驱动绑定保持不变。
- 发现 [openFPGALoader 上游同型号 issue #573](https://github.com/trabucayre/openFPGALoader/issues/573)：报告者在 Tang Primer 20K 上也遇到开源工具 Flash 写入中途停住，并称高云官方工具可完成；这是相似案例，不等于证明本板根因。接下来优先试官方 FTDI 驱动/Programmer 只读链路，只有正确识别一个 `0x81B` 设备才考虑 Flash 写入。

## 2026-09-30T12:50+08:00：准备官方 FTDI 驱动只读试验（尚未切换驱动）

- 目前 JTAG A = WinUSB / oem180.inf，B = FTDIBUS / oem178.inf，均 OK；板上四键音频仍由 SRAM 运行。高云官方 CLI 的 FT2CH 只读扫描在当前绑定下超时，WinUSB 通道返回假 ID 与 16 个虚假设备。
- 已把 A 通道目前的 WinUSB 驱动从 Windows 驱动仓库导出到 `E:/gaoyun/tools/driver-switch/backup-winusb-20260930/`；INF SHA256 `17B84FCE55421DBC1092A6F3808C3B4F97935969BC5DF3967FBDA60468392469`。FTDI 备份已存在于 `E:/gaoyun/tools/ftdi-driver-backup/`；原 WinUSB 安装器 `wdi-simple.exe` SHA256 `5B96731BFBDBA2E1EF5BA5AA02963AB365A1A9DDE187A9FC343F2B1F5B31CFF9`。
- `scripts/try-gowin-ftdi-a.ps1` 先核对唯一 A/B 实例及备份哈希，再仅卸载 A 的 oem180.inf，使已存在的 FTDI 驱动绑定 A；之后高云官方 CLI `--cable-index 1` 只读扫描。仅当看到一个 ID `0x0000081B` 才保留 FTDI；否则自动调用已验证的 WinUSB 安装器恢复 A。脚本不包含 Flash 写入。语法解析 0 错；非管理员预检按预期拒绝运行，未更改驱动，见 `logs/20260930-125042-gowin-ftdi-driver-trial.txt`。
- 系统当前令牌非管理员，实际驱动切换需要 Windows UAC；已询问用户是否能用键盘 Alt+Y 确认。未得到回复前不运行提权脚本。

## 2026-09-30T12:53+08:00：JTAG A 切回 FTDI；高云官方 Programmer 只读扫描成功

- 用户确认可用键盘 Alt+Y 完成 Windows UAC；运行已推送的 `scripts/try-gowin-ftdi-a.ps1`，先核对目标 A/B、无烧录器进程和 WinUSB 导出文件哈希，再卸载仅供 JTAG A 使用的 `oem180.inf`。Windows 将 A 绑定到已有的 `oem178.inf` / FTDIBUS；B 仍为 FTDIBUS。A、B 状态均 OK / ProblemCode 0。Windows 管理员脚本退出码 0。
- 脚本仅用 IDE 内置的 Gowin Programmer CLI（V1.9.11.03 Education build 2536）执行 `--cable-index 1 --frequency 2.5MHz --scan`。输出：唯一一个 GW2A/GW2AR-18C、ID `0x0000081B`、`1 device(s) found!`、exit 0，见 `logs/20260930-125300-gowin-ftdi-driver-trial.txt` 与 `.out.txt`。这解决了原 WinUSB 绑定下官方扫描错误/超时的问题。尚未执行任何新 Flash 擦写。
- 当前 JTAG A/B 均为 FTDI，openFPGALoader 的 WinUSB 路径暂时不可用；若官方 Flash 路径失败，可用已保存的 `scripts/install-jtag-a.ps1` 和导出的 WinUSB INF 恢复 A。恢复前先记录官方工具返回和 FPGA 状态。

## 2026-09-30T13:02+08:00：高云官方工具只读校验确认 Flash 内容不匹配

- FTDI A/B 均 OK，JTAG 扫描确认唯一 ID `0x0000081B` 后，IDE 内置 Programmer CLI build 2536 执行 `--device GW2A-18C --cable-index 1 --frequency 2.5MHz --operation_index 15 --fsFile E:/gaoyun/projects/audio_keys/audio_keys/impl/pnr/audio_keys.fs --spiaddr 0x000000`。operation 15 是 **exFlash Verify in bscan**，不擦除/写入。
- 命令识别 Target Device GW2A-18C、Flash ID `0x0B4017`，持续逐块校验至 44%，报告 `Error: SPI Verify failed!`，进程退出码 67，耗时 526.8 秒。原始输出 `logs/20260930-gowin-exflash-bscan-verify-before-write.out.txt`。该结果符合此前两次被中断写入后 Flash 与当前 .fs 不一致的状态；不能据此判断 Flash 芯片损坏。
- 命令退出后无残留烧录器，A 驱动仍 FTDIBUS、ProblemCode 0。下一步才考虑同一官方通道 operation 13（限定外部 Flash 的 erase/program/verify in bscan），不使用 bulk erase。

## 2026-09-30T13:11+08:00：高云官方工具完成外部 Flash 擦写和编程；独立校验待做

- 在 A/B 均 FTDIBUS、唯一 JTAG ID `0x0000081B`、外部 Flash ID `0x0B4017` 已确认后，IDE 内置 Programmer CLI build 2536 执行 `--device GW2A-18C --cable-index 1 --frequency 2.5MHz --operation_index 13 --fsFile E:/gaoyun/projects/audio_keys/audio_keys/impl/pnr/audio_keys.fs --spiaddr 0x000000`。操作名称为 `exFlash Erase,Program,Verify in bscan`，并非 bulk erase。
- 工具从 `SPI start of address: 0x000000` 连续推进 Programming 至 100%，报告 `SPI end of address: 0x08CE00`、`Finished!`、耗时 321.31 秒、进程 exit 0。原始输出 `logs/20260930-gowin-exflash-bscan-program-verify.out.txt`。A/B 仍为 FTDIBUS、ProblemCode 0，没有残留烧录器。
- 日志仅显示 Programming 进度，没有单列只读 Verifying 阶段。不能只因操作名称含 Verify 或退出码 0 就宣称 Flash 字节校验和掉电启动已经通过。下一步独立执行 operation 15（exFlash Verify in bscan），再由用户物理掉电上电观察 S0–S3 是否自动发声。

## 2026-09-30T13:12+08:00：Flash 自启动与 RCFG 实物验证成功

- 官方 Programmer operation 13 完成后，**未运行任何 SRAM 下载**。用户拔掉板卡全部供电 USB，等待 10 秒，再插回此前正常的电脑直连 USB 口；上电后用户逐键试听，确认 S0、S1、S2、S3 从耳机都有声音。该观察支持 FPGA 从外部 Flash 自动配置为当前音频设计，不能由断电前的 SRAM 程序解释。
- 用户随后按一次板上丝印 `RCFG` 的重配置键，等待约 2 秒，重新测试 S0–S3；用户报告四键均有声。这解决了此前仅装 SRAM 时按 RCFG 后音频失声的现象。
- 最后高云 Programmer CLI 只读 `--cable-index 1 --frequency 2.5MHz --scan` 返回唯一设备、ID `0x0000081B`、exit 0；A/B 仍为 FTDIBUS/oem178.inf、ProblemCode 0。JTAG 入口在 Flash 自启动后保持可用。原始输出 `logs/20260930-post-flash-boot-jtag-scan.out.txt`。
- 本次结论是**当前码流的 Flash 自启动与 RCFG 功能性成功**。operation 13 虽名为 Erase,Program,Verify，日志仅列 Programming 进度；写后未额外运行 operation 15 的独立逐字节比较，因此不声称该项已通过。原厂 Flash 内容没有可靠整片备份。复现步骤见 `docs/flash-programming-procedure.md`。

## 2026-10-11：核对新模块照片、ADS1015 资料并确定接线规划

- 用户提供 ADS1015、SLK AUDIO PCM5102A 与 PS2 摇杆四张照片，以及 E:/gaoyun/75107。目录仅包含 ADS1015/ADS1115 共用的 Adafruit 说明、ADS1115 PDF 和库压缩包；没有 PCM5102A 实际模块原理图。淘宝短链未取得可读取的模块说明。
- 核对 Sipeed 官方 Dock-3713 背面图与 Dock/SOM 原理图：选 PMOD0，I2C 使用 T6/T7，摇杆按键 T8，I2S 使用 P6/R8/P8。这些信号属 bank 3，SOM 原理图接 +3V3；现有音频 CST 未使用这些信号。供电必须使用真实 3V3/GND。
- 摇杆与 ADS1015 统一用 3.3 V；VRX/VRY 接 A0/A1，ADDR 接 GND 地址 0x48。ADS1015 的转换率为总计 3300 SPS，因此旧 SPI ADC 采购计划的每轴 2kSPS 不能直接沿用。
- DAC 五针按照片确认为 DATA/BCK/LRCK/+3.3V/GND；其 +3.3V 与 USB-C 的供电关系尚无卖家原理图或实测，不凭丝印将两路供电并接。已请求用户仅 USB-C 普通 5V 供电时测 +3.3V 对 GND；用户说明只有 ADS 资料，尚未提供读数。供电验证仍待完成。
- 接线表与直插转接方案见 docs/module-wiring-20261011.md。未执行 JTAG、SRAM、Flash、驱动切换或模块上电；此记录仅为资料核对与接线规划，不声称新 ADC/DAC 已实测。

## 2026-10-11：检索 PCM5102A 同布局模块与开源参考

- 按用户长黑板/SLK AUDIO/USB-C/三稳压器/五针特征检索。找到 https://www.ruten.com.tw/item/22201678843542/ ，商品图为同布局绿色 Micro-USB 旧版（实际查看图片，对照三颗稳压器、大电解、插座、五针和元件布局），页面记载 2021-03-03 改 Type-C，USB 5V 供电，五针 DATA/BCK/LRCK/3.3V输出/GND。不将同布局旧版说明冒充黑板原理图或实测。
- 更新 docs/module-wiring-20261011.md：采用 DAC USB-C 普通5V供电、+3.3V留空、DATA/P6、BCK/R8、LRCK/P8、GND共地，避免两路3.3V电源并接。黑板实际电压仍未测量，完整黑板原理图未找到。
- 找到开源应用 https://github.com/igor-gia/audio-signal-generator 与 https://github.com/uhucrew/bt-receiver-pcm5102a ，仅作三线I2S/音频代码和原理图参考；它们不是本模块的板级设计文件。本阶段未接线、上电或烧录。

- 2026-10-11 用户询问从Dock OTG口供DAC或只用杜邦线。检查Dock-3713 USB PHY原理图：J8 VBUS直接+5V，CC1/CC2为5.1k下拉，SW2仅改变USB_ID，不能当作标准Type-C source模式切换。记录C-to-C供电不保证；DAC未确认的两孔须先通断确认后才能作为5V/GND输入，不推断孔的极性。不执行硬件操作。

- 2026-10-11 用户要求复核芯片供电。核对TI PCM5102A数据手册（https://www.ti.com/lit/ds/symlink/pcm5102a.pdf）引脚表与电源章节：AVDD/CPVDD为3.3V，DVDD可1.8/3.3V，芯片不要求5V或USB。更正此前“3.3V输出不能反向供电”的过强表述：能否外部供3.3V取决于模块各电源轨连接及稳压器反向电流限制；此黑板拓扑未证实，不允许据芯片规格直接指定从输出脚给整板供电。USB旁两孔也未证实为供电口。无硬件操作。

## 2026-10-12：商家确认 PCM5102A 3.3V 排针可作为输入

- 用户提供声洛科音频客服截图：明确允许从模块3.3V脚输入供电，说明USB5V经LDO转换3.3V，强调该排针输入不能超压。这补充了同款模块供电信息，支持五根杜邦线供电/信号方案。
- 更新接线表：DATA/P6、BCK/R8、LRCK/P8、GND/DockGND、+3.3V/Dock PMOD0真实3V3；采用此方式时DAC USB-C不接，避免两路3.3V源并接。不需要OTG5V取电，不给GPIO承担供电。尚未接线/上电/测量；未确认型号的PAM功放不套用此方案。

## 2026-10-12：完成 PCM5102A / ADS1015 摇杆接口程序，未烧录

- 用户要求先写好程序。建立独立 instrument_io 工程，原 audio_keys 源码及已验证Flash程序不改动。保持S0-S3单音优先级，外接PCM5102A为标准16位I2S、BCLK1.5MHz、LRCK46.875kHz、32fs；同样音频送左右声道。TI原始手册第15/25页支持该16位/32fs三线模式，但实际模块PLL锁定未测。
- ADC地址0x48，开漏SCL/T6、SDA/T7，A0/A1配置0xC383/0xD383（单次、±4.096V、1600SPS），每次转换等1ms，再读2字节；两轴成对发布，更新率为每轴数百次/秒，不把配置值当更新率。NACK/clock stretch/卡线超时有界恢复，缺ADC时退回中性控制仍可四键发声。
- 摇杆X约±10%弯音、Y三角波/锯齿波混合、SW/T8稳定5ms后按住降低一个八度。默认中点825、死区±25码待实物校准；输出1/4数字满幅，保持线路输出限制，板载耳放与PT8211接口禁用。N16心跳，N14为ADC双轴数据有效指示。
- 先写独立I2S/ADC/声音测试。测试抓到9时钟恢复计数器3位装不下8造成无限循环，扩成4位后通过。ADC测试包括地址/config/字节/首ACK末NACK、两轴、负数/超量程钳位、拉伸、设备NACK、SCL超时、SDA低与重新上线。声音测试独立测音高过零、优先级、弯音、音色、八度、幅度和静音。整机从串行引脚解码，验证BCLK频率、同帧声道、缺ADC退回、释放静音和板载耳放关闭。
- 仿真运行库需在PATH把已有openfpgaloader UCRT库放在旧MinGW GCC8之前；未修改系统驱动。一次测试脚本生成时PowerShell误处理timescale反引号造成语法错误，已修正；一次整机测试用组合frame_tick边沿计数产生零时刻伪边沿，改为观察真实WS边沿后通过。原始失败日志保留，最终四组PASS见 logs/20261012-102916-instrument-sim.log。
- 综合中的算术缩位告警改为有界显式位选，最终build exit0，无WARN/ERROR；pnr setup/hold违反端点均0，27MHz目标、报告Fmax64.695MHz。这仅是FPGA内部时序，外部ADC/DAC/线缆时序待测。6个PMOD0信号均bank3/LVCMOS33/3.3V，旧按键电平保留；JTAG/MSPI/RECONFIG_N专用、仅SSPI复用。证据 logs/20261012-instrument-checks.json、build.log、pnr.rpt.txt、review.md。
- 最终码流 E:/gaoyun/projects/instrument_io/instrument_io/impl/pnr/instrument_io.fs，便捷副本 E:/gaoyun/instrument_io.fs；SHA256 666B33A15B2939D7FB1AA2B4E5254C4D5B6786F064BBA31226096FF8D9FB04CB。码流不提交Git，源码/build/test脚本与所有日志上传。下次接线核对后先测SRAM，不自动写Flash。
- 本阶段没有JTAG扫描、硬件上电、SRAM/Flash下载或驱动操作，不能称模块已实测发声。首版单音、非标准48kHz、锯齿未抗混叠，不宣称已完成赛事最终多复音乐器。

## 2026-10-12：用户确认接线与供电后，instrument_io 下载到 SRAM

- 用户明确要求下载，并确认PCM DATA/P6、BCK/R8、LRCK/P8；ADS SCL/T6、SDA/T7；摇杆SW/T8；所有模块由Dock真实3V3共地供电、PCM USB-C不接另一路电源。未取得电压/温度实测数据，不声称电气状态已测量。
- 核对 E:/gaoyun/instrument_io.fs SHA256为666B33A15B2939D7FB1AA2B4E5254C4D5B6786F064BBA31226096FF8D9FB04CB。初次Windows尚无下载器，官方扫描exit49/No Gowin devices；用户连接USB-JTAG后，设备稍后才枚举，A/B均FTDI状态OK。重新只读扫描得到唯一ID0x0000081B、exit0。
- 使用已验证官方Programmer路径，命令：programmer_cli.exe --device GW2A-18C --cable-index 1 --frequency 2.5MHz --operation_index 2 --fsFile E:/gaoyun/instrument_io.fs。Operation为SRAM Program，编程100%，UserCode0x0000D932，StatusCode0x00006020（Done Final），Finished，耗时4.65秒，exit0。原始日志 logs/20261012-instrument-sram-program.out.txt 与扫描日志。
- 本次没有Flash擦写、OTP、下载器固件或驱动修改。SRAM掉电/RCFG回到旧Flash音频。已请求用户观察N16心跳/N14 ADC有效灯，以及外接PCM线路设备的四键声音/摇杆变化；反馈尚待确认，不将工具成功当成外部ADC/DAC实物成功。

- instrument_io SRAM实物首次反馈：用户报告N16闪烁、N14不亮，外接PCM接音箱无声，摇杆无变化。仅确认FPGA心跳；未确认ADS有效读取和DAC音频成功。核对码流UserCode为0xD932，与官方Programmer返回一致，生成引脚报告ADC/T6/T7、PCM/P6/R8/P8均bank3/LVCMOS33，未发现码流文件拿错。已请求模块各自VDD-GND电压、ADDR接地和音箱AUX供电确认；未得到测量前不重复烧录，当前Flash不变。

## 2026-10-12 新接口无声：隔离诊断准备（尚未下载）

用户确认旧 Flash 程序仍能运行；外接 PCM 无声、ADC LED 不亮，暂时不能测电压。不能因此认定接线错误或硬件损坏，也不能排除新 RTL 的问题。

新增 instrument_diag：复用已经实测正常的 audio_keys 板载输出；外接 PCM 连续输出约 440 Hz、四分之一幅度的 I2S 测试音，不由按键或 ADC 门控；ADC 保持读取并在 M11 板载 UART TX 输出 115200/8N1 状态行（V有效、E错误、X/Y值、K按键、S两线电平）。不改变模块接线，不写 Flash。

UART 测试先因模块不存在失败；实现后逐字节采样正确（末尾 0D/0A），但 Icarus 对字符串换行比较出现不一致。混合字符串拼接比较进一步触发 ivl_expr_value 编译器断言和 vvp syntax error。改为固定宽度字节期望值比较后通过；该问题属于诊断测试工具/表达式问题，尚未证明是实物无声根因。

Gowin 构建完成，无 WARN/ERROR。诊断码流 SHA256：FD39A08328F6DE08107700D04741DA3710C866E3B7D43EB8ABA79A7BD70E9F4F。现有 I2S/ADC RTL 未修改。程序未下载、外接声音及 UART 通道未验证。当前 Windows 未枚举到 0403:6010，已请用户接回 USB-JTAG。原有 Flash 保留。

### 诊断 SRAM 已下载，ADC 实物通信成功

用户接回 USB-JTAG 后，两通道 OK，COM13 出现。2.5MHz 只读扫描得到 ID 0x0000081B，exit 0。校验诊断码流 SHA256 后，官方 CLI operation_index 2 完成 SRAM 下载：100%，UserCode F871，Status 6020，exit 0，4.74秒。未写 Flash。

COM13 115200/8N1、DTR/RTS关闭，读取3秒得到12条状态行，均 V1 E0；X=34D/34E（845/846），Y=33B（827），K=F（无键按下）。ADS 寄存器事务已正常应答并产出连续有效数据；尚未测试移动摇杆，也未通过电压测量验证供电。两线瞬时S状态随事务变化属正常采样现象。前一版 LED 不亮的根因尚未确认，不能将此次通过推断为其无软件缺陷。

已请用户分别听外接PCM持续测试音、原Dock四键音频。外接PCM实物出声尚未确认。UART原始字节保存bin，文本为显示副本。

### 用户确认诊断声音结果；下一步单变量供电对照

用户反馈：外接PCM持续测试音仍无声，Dock原3.5mm口S0–S3四键都有声。ADC串口有效数据此前已实测。无证据证明外接PCM输出正常，也不能排除程序/引脚/模块电源问题。

重新核对TI PCM5102A数据手册：https://www.ti.com/lit/ds/symlink/pcm5102a.pdf 。16bit I2S及32fs BCK是支持的格式；当前46.875kHz非表列标准48kHz，PLL实物锁定未证明。芯片AVDD/DVDD/CPVDD需分别供电；照片模块有三颗LDO，排针3.3V是否同时连通三轨无该板原理图/测量证据，不能从LED亮或客服“可以3.3V输入”证明完整供电。

已请求用户断电后移除PCM的+3.3V供电线（两端悬空），保留DATA/BCK/LRCK/GND四线，改用电脑普通USB-A到USB-C给PCM原USB入口供电。不得并接排针3.3V和USB供电。保持同一诊断码流，下一次仅SRAM重装作单变量对照。尚未收到接线完成反馈，尚未进行下一次下载。未写Flash。

### PCM 改 USB 供电后，重装同一诊断程序

用户回复已完成此前要求的供电切换：PCM 排针3.3V供电线移除，保留三路I2S与共地，USB入口单独供电。此为用户接线确认，非电压实测。
2.5MHz JTAG扫描ID 0x0000081B、exit0；核验同一FD39A08328F6DE08107700D04741DA3710C866E3B7D43EB8ABA79A7BD70E9F4F码流后，官方operation_index2下载SRAM完成100%，UserCode F871，Status6020，exit0，4.64秒。未改变程序、未写Flash。已请求用户听外接PCM持续固定音，结果待反馈。

### 单变量供电对照成功：USB供电固定音可听见

用户确认：同一诊断程序在PCM改USB供电后“持续有声”。前后码流相同、I2S信号接线相同，仅改变供电方式。证据支持此前PCM无声与排针3.3V供电方式有关；尚无该模块原理图/电压实测，不能断言具体缺失哪条供电轨。排针3.3V作为本模块完整供电的先前建议未得到实物验证，现修正为USB供电，排针3.3V保持断开。此次结果同时实测证明该诊断I2S码流可令该PCM模块出声，46.875kHz在当前组合可工作，但不是标准48kHz设计验证。

随后只读扫描成功，核验生产instrument_io码流SHA256 666B33A15B2939D7FB1AA2B4E5254C4D5B6786F064BBA31226096FF8D9FB04CB后，官方SRAM operation_index2下载100%、UserCodeD932、Status6020、exit0、4.68秒。未写Flash。已请求用户测试四键、摇杆音高/音色、N14 ADC灯。功能结果待反馈。

### 四键＋摇杆程序测试反馈

用户对“四键发声、摇杆音高/音色变化、LED3状态”的组合测试回复“ok”。按本轮整体功能测试通过记录；用户未分别描述三个项目，不将该反馈扩展为量化音高、音色或LED测量结果。当前为UserCode D932的instrument_io SRAM程序，PCM USB供电、排针3.3V断开。原Flash未更新，断电后仍加载此前audio_keys程序。排针3.3V供电导致无声的具体内部电源原因仍未实测确认。

## 2026-10-12 四键独立复音升级，SRAM已加载

用户要求继续。将已验证单音lane复用为四个独立相位/包络，每个lane只接收自己的键；保留C5/D5/E5/G5、摇杆弯音/三角到锯齿音色渐变、摇杆按下低八度和ADC失效中性回退。四路用18bit有符号求和固定除4，最坏总输出不超过四分之一满幅；单键比单音版本小四倍。尚未增加更多音色、抗混叠或标准48kHz；不声称完成赛事全部要求。

先加入独立C+G叠加/单独松键/四键幅度/全松静音测试，旧优先级引擎失败：Chord lost a held voice got778 expected -5816。实现后五组仿真全通过（I2S、ADS、单音控制、复音、整机）。Gowin构建exit0、无WARN/ERROR，setup/hold违反端点均0，27MHz约束下Fmax43.572MHz。手动审查确认四个键mask保留原键索引，符号扩展18bit求和，输出固定缩放无溢出，协议/供电/引脚未改变。README主接线表修正PCM为USB供电，避免与末尾修正文互相矛盾。

SHA256 ADE8A08C908A4B7B0380E28856E07E627B258CDB513D51E176E542F845BA8A4F；只读扫描成功后，官方2.5MHz operation2 SRAM下载100%、UserCode3A2A、Status6020、exit0、4.67秒。Flash保留。已请求用户验证两键叠加、单独松键以及摇杆。新版声音实测结果待反馈。

## 2026-10-12 当前复音版写入Flash

用户反馈复音似乎正常但S3可能无声、音调感觉下降，随后表示音量降低并明确要求写入Flash。未将这些现象判为测试全部通过；单键幅度下降与四路混音固定除4一致，S3/音调反馈仍待查。按用户要求原样持久化当前复音码流，未另做音量或频率修改。

写前只读扫描唯一ID0x0000081B、exit0，核验码流SHA256 ADE8A08C908A4B7B0380E28856E07E627B258CDB513D51E176E542F845BA8A4F。使用此前成功的官方Programmer FTDI通道、2.5MHz、operation_index13、spiaddr0x000000，未用整片bulk erase/OTP/下载器固件更新。写入进度持续推进，100%，SPI结束地址0x08CE00，Finished，退出码0，324.13秒。日志未单列逐字节校验阶段，不宣称额外独立回读比较已通过。

当前Flash已替换为instrument_io复音版，不再是旧audio_keys。已请求用户断开Dock与PCM USB供电10秒、先PCM后Dock恢复供电，不再下载SRAM，测试发声/摇杆和S3。自动启动功能验证待反馈。

## 2026-10-12 Flash自启动反馈与S3异常定位

用户确认Flash自动启动正常、其他混音和摇杆正常；反馈一个音持续响，按S3可关掉。此前未查明S3的反常表现，不能算新版全部通过。现象类似极性反转，但官方Dock-3713原理图按键页画普通键上拉、按下接地，且历史诊断空闲K=F；不能仅凭听感直接反相。

只读JTAG扫描成功，校验FD39...9F4F诊断码流后临时SRAM下载operation2成功exit0，Flash复音内容未修改。COM13实际读取2秒，连续V1 E0、K=F，四路输入当前均高。已请用户仅按住S3后回复，以读取对应输入位及极性。诊断外接固定音属于预期，非复音程序持续音缺陷的复现。S3根因仍待定位。

### S3按住采样未见输入变化

用户回复S3“按住了”后读取COM13。状态仍K=F、V1 E0，未见预期S3按下的K=7。不能凭此确认S3极性反转，也不能断言按键坏了；按住时间是否覆盖采样及具体物理键映射待确认。已请求保持正常S1按住做串口读键对照，未更改RTL或Flash。原始串口日志保留。

### 串口积压修正，S3并非反相

S1保持按住时首次采样读到混合K7/KF/KD，说明此前COM13/FTDI积压了历史状态，reset_input_buffer不足以清除设备队列。此前S3按住实际产生K7（bit3低），S1按住产生KD（bit1低），两者符合低有效。排空2314字节并等待短暂无字节后，再采样1秒连续4条KD，确认当前S1低有效。不能用此前旧KF采样判为S3映射不响应；未实施错误反相。

官方operation2恢复复音SRAM，100%、UserCode3A2A、Status6020、exit0、4.62秒；Flash保持复音版本。已告知可以松开S1，请求全松静音及S3按/松试听，持续音根因尚未确认。串口历史与新鲜采样原始日志保存。

## 2026-10-12 实物复现空闲声部活动并修正

用户再次确认开机持续纯音、S3按下静音。未直接反相。旧掩码复音RTL加入UART实物监测，下载SRAM UserCode97E6后排空历史数据：连续K=F（四键松开）、Y001（note_active为1）。该硬件状态与RTL仿真全松静音不一致，支持复音实际实现内部声部使能异常；不是正常效果，也不能解释为仅主观混音听感。综合网表受Gowin加密，无法据此精确归因到具体综合优化。

将voice_lane改为单个key_n输入和参数化固定NOTE_INCREMENT，删除四键掩码、优先级选择和held音符；四个声部直接连btn_n[n]。保留所有波形、混音缩放、音高控制。UART当前Y字段为包络活动标志而非轴Y，K为物理键电平。五组仿真全通过；编译exit0，无WARN/ERROR；setup/hold违反端点0，Fmax43.689MHz。手动检查固定音符值、单键同步、包络衰减、求和位宽及引脚未改变（仅增加板载UART M11）。

修正版SHA256 9DA141FDAF59E24E1FE10ED352389D8B3D8CE2DC0B1283A2B4A3B317FB99E561；官方operation2下载SRAM成功100%、UserCode3CB9、Status6020、exit0、4.71秒。实物清队列后连续K=F、Y000，空闲声部活动矛盾已消除。尚待用户确认实际静音/S3按松/混音/摇杆。Flash仍是此前ADE8...8A4F版本，尚未更新，不声称Flash缺陷已修复。

### 直接单键声部修正版试听反馈

用户对全松静音、S3按松、混音和摇杆组合测试反馈：“可以量算是 额 但是输出的音响都不大好 应该对了。”仅记录为用户初步认为行为已纠正，未分项明确确认、未确认音质通过。已请求区分声音偏小、杂音/破音/刺耳、音箱本身影响判断。当前运行UserCode3CB9修正版SRAM，Flash仍为含此前问题的ADE8...8A4F版本；未再次写Flash。

## 2026-10-12 修正版复音Flash持久化完成

用户说明音箱本身不好，暂时无法判断音质；不据此调整音量或波形。依据此前明确写Flash的持续授权，将实物空闲活动已纠正、用户初步认可行为的直接单键声部版持久化，替换旧问题复音版。

写前校验SHA256 9DA141FDAF59E24E1FE10ED352389D8B3D8CE2DC0B1283A2B4A3B317FB99E561，只读JTAG扫描exit0。官方2.5MHz operation13、地址0x000000，进度持续推进至100%、SPI结束地址0x08CE00、Finished、exit0、324.31秒。未bulk erase/OTP/下载器固件更新；日志未单列逐字节独立校验，未声称该项通过。

Flash现在为直接单键声部修正版（SRAM标识3CB9），不是之前ADE8版。已请求全断电10秒、先PCM后Dock上电、不下载SRAM，验证空闲静音和S3按松。修正版Flash自启动功能验证待反馈；音质仍无法判断。

### 修正版Flash写入后无响应，先只读检查

用户报告“都没反应，LED0/1都亮”，未明确确认此前要求的完整断电步骤是否完成。只读JTAG扫描成功exit0，唯一ID0x0000081B；排空串口历史数据后1.5秒无新UART字节。仅证明JTAG通路当前正常，应用运行尚未确认；不能据LED断言硬件损坏。Flash编程结束可能仍停留烧录临时配置，此为待验证解释。

已请求Dock与PCM全部USB断电10秒，先PCM后Dock上电，先不下载SRAM，检查Flash启动。未新增Flash擦写、驱动修改或SRAM操作。

## 2026-10-12 修正版Flash冷启动未响应，独立校验失败；SRAM恢复

用户确认全断电重启后，COM13排空后无新UART字节；未下载SRAM前，修正版Flash自动启动仍未证实。JTAG仍可读ID81B。将同一9DA141FDAF59E24E1FE10ED352389D8B3D8CE2DC0B1283A2B4A3B317FB99E561修正版装SRAM后，UserCode3CB9/Status6020/exit0，新鲜UART连续V1 E0、K=F、Y000，证明FPGA运行此设计及ADC通信仍正常。

随后执行官方只读operation_index15、2.5MHz、spiaddr0x000000，与同一码流独立比较。进度从1%持续到70%，报Error: SPI Verify failed，退出码67，耗时844.23秒。此前operation13“100%/exit0”不能代替独立校验成功；Flash内容或读取链路存在不一致，具体失败地址未由CLI列出。该失败不单独证明Flash芯片损坏。新旧码流头的设备C、起始地址0、2.5MHz加载速率、CRC/Security/JTAG设置相同，未发现明显启动头差异。

比较结束立即恢复同一码流SRAM：100%、UserCode3CB9、Status6020、exit0、4.64秒。新鲜UART再次V1 E0、Y000、K=F。当前应用在SRAM恢复，未再擦写Flash，Flash启动仍有问题，不将本次持久化标记成功。

## 2026-10-12 官方Flash流程与故障排查核对

用户询问官方解决方案。核对官方Sipeed Primer20K LED教程：https://wiki.sipeed.com/hardware/zh/tang/tang-primer-20k/examples/led.html ，要求先使能核心板，使用官方教育版Programmer，External Flash Mode、Generic Flash和.fs文件。官方FAQ https://wiki.sipeed.com/hardware/zh/tang/Tang-Nano-Doc/questions.html 明确：未使能核心板时0、1号LED一直亮且核心板不正常启动；板载下载器JTAG/串口占用可通过重新插拔USB恢复；下载频率建议2.5MHz或以下。这是官方建议，不是此前用户自行约定的固定频率上限。

用户此前“LED0/1都亮”与官方未使能提示吻合，优先核实1号使能拨码，不把此线索直接当根因。JTAG可扫描、SRAM可运行也不取代此物理设置核查。已给官方图片 https://wiki.sipeed.com/hardware/zh/tang/tang-primer-20k/assets/start/switch_1_on.png 并询问ON/OFF。未执行新擦写。

高云现行SUG502-2.5.2E https://cdn.gowinsemi.com.cn/SUG502E.pdf 的GW2A(R)外部Flash章节说明bscan13/15，以及GAO-Bridge36（擦写）/37（擦写校验）。本机CLI帮助亦确认37名称匹配。GAO-Bridge是官方支持的另一路径，非已证实本故障修复方法；目前不能承诺换模式即可成功。接下来顺序应为核实使能与连接，复位下载器并避免串口占用，再视证据采用官方Flash模式且校验通过+冷启动验证；此前70%校验失败不能忽略或归为芯片损坏。

## 2026-10-12 成功/失败Flash流程对比
已保存 docs/flash-success-failure-comparison-20261012.md 和码流头JSON。旧成功文件hash仍匹配；型号/启动头/地址/工具路径/2.5MHz操作13均一致，文件大小相同。重要差异为此前刚恢复FTDI连接，而本次多轮COM13后未重新插拔下载器。官方FAQ提示串口/JTAG占用，列为优先排除的链路状态假设，不宣称已证明根因。旧版无写后独立比较但有冷启动/RCFG实测；本次校验失败并启动无响应。仅分析，未操作Flash。

## 2026-10-12 用户纠正烧录目标为修正版复音

此前按历史成功码流对照计划扫描成功并启动旧audio_keys operation13，用户在工具运行期间明确要求“烧录复音的，原版本来也在”。该纠正成为当前目标：只烧9DA141...E561修正版复音。旧任务运行约一分钟仅1%（结束前日志最终出现2%），未确认成功；结束指定programmer_cli PID28536。Flash可能部分擦写，不将旧版任务计成功。

为恢复正常运行状态，尝试同一修正版SRAM operation2；CLI无输出、未完成，结束指定PID11152。当前无残留programmer_cli。未启动新的复音Flash写入，也未打开COM13。已请求全USB断电10秒/重连及使能1号ON，恢复下载器后只写用户要求的修正版复音。用户明确不需要旧版对照，不再推进该计划。

## 2026-10-12 干净USB连接＋官方GAO-Bridge修正版复音Flash写入校验成功

用户确认已重连，目标仍是修正版复音。全程未打开COM13。只读扫描成功；核验9DA141FDAF59E24E1FE10ED352389D8B3D8CE2DC0B1283A2B4A3B317FB99E561后SRAM恢复UserCode3CB9、Status6020、exit0、5.05秒。

由于此前bscan独立校验失败，改用高云手册及本机帮助确认支持的operation_index37（exFlash Erase,Program,Verify thru GAO-Bridge），仍为GW2A-18C、2.5MHz、地址0x000000和同一复音码流；不使用bulk erase/OTP/下载器固件更新。日志独立显示Programming Flash进度100%，明确Program and Verify flash successfully、Finished、exit0、20.19秒。这次有工具明确写入＋校验成功证据，尚不代替冷启动功能验证。

同时改变了下载器干净连接和Flash访问路径，因此不能仅凭此次成功断言先前唯一根因是串口占用或bscan缺陷。可复现成功路径现为干净USB状态、不打开COM13、官方GAO-Bridge37。已请求全断电10秒、先PCM后Dock，用户确认使能1号ON，不下载SRAM，验证全松静音、四键和混音。Flash当前为3CB9修正版复音，冷启动反馈待确认。

### GAO-Bridge烧录后冷启动测试通过

用户对全断电10秒、先PCM后Dock供电、不下载SRAM、不按RCFG条件下的全松静音、S0–S3按松和混音测试回复“ok了”。记录为本轮整体冷启动功能测试通过，未扩展为量化音质测量。结合operation37明确Program and Verify flash successfully、exit0，当前9DA141FDAF59E24E1FE10ED352389D8B3D8CE2DC0B1283A2B4A3B317FB99E561修正版复音Flash持久化完成。

后续采用此次已验证路径：干净USB连接、不打开COM13，官方GAO-Bridge operation37、GW2A-18C、2.5MHz、spiaddr0x000000；核验目标码流hash；工具写入校验成功后，再全断电验证应用。PCM维持USB供电、排针3.3V不并接、与Dock共地。此前bscan失败单一根因仍未隔离证明；音质受音箱限制尚无法判断。

## 2026-10-12 官方赛题差距核对
重读高云官方2026选题二，生成docs/competition-gap-20261012.md。关键未完成基础是完整可调ADSR、端到端<=10ms实测及多频测试/频谱证据。已实现4声部/双轴/实时HDL/I2S/Flash自启动；当前46.875kHz，48kHz是工程改进而非该页强制要求。32复音、第三维表情、乐器音色预设、效果器、视听反馈及脱机指引等为拓展。未烧录或改变接线。

## 2026-10-12 完整四阶段ADSR实现、仿真鉴定及SRAM验证

用户要求继续编程并自行鉴定。本轮增加adsr_envelope模块，0..256包络，Attack/Decay/Sustain/Release四阶段；重触发从当前幅度爬升避免跳变。A速度、D间隔、S电平、R间隔均可在HDL参数配置；目前没有现场运行时调参界面，不宣称“实时参数调控”已完成。原四声部直接单键映射、混音缩放、摇杆、I2S/ADC不改变；Flash保留已通过冷启动的9DA141...E561版本。

RED为缺adsr_envelope模块；实现后包络单独测试覆盖起音峰值、单调衰减、稳定保持、释放、重触发及静音，声音/复音/协议测试通过。整机最初触发原30ms测试窗口超时，因为新释放变长；保留失败日志，延长到60ms后实际33.81ms完成。六组仿真全部通过。手动审查包络有界0..256、各阶段计数归零、释放饱和到0、声部独立、混音位宽；Gowin构建exit0、无WARN/ERROR、setup/hold违反端点0、Fmax42.330MHz满足27MHz内部约束。

默认A步长6，约43帧0.92ms；D从256到160每16帧下降1，约32.77ms；S=160/256=62.5%；R每4帧下降1，从S释放约13.65ms（从峰值释放约21.85ms），另有约5ms松键消抖。该包络参数不等于控制到DAC总延迟实测。

码流SHA256 DAFA35F4987F93AFC58BA0BA73E5ED09DF398CCA8F0296CF8BE5B67EE310FDDC。只读扫描通过后operation2 SRAM下载100%、UserCode2014、Status6020、exit0、4.66秒。排空历史串口后新鲜状态V1 E0、KF、Y000，确认ADC通信、空闲声部关闭。音质、实物每段包络以及<=10ms总延迟尚未测量。未写Flash、未改接线。打开COM13后，未来Flash操作需重新拔插USB恢复干净下载器状态。

## 2026-10-12 当前模块完整功能工程完成并写入Flash

用户要求不扩展按键，用当前模块完成可实现的工程。完成四键演奏、三音色预设、三音符分组覆盖12半音、低八度、摇杆弯音/亮度、现场ADSR编辑与每音符参数锁存、43.69ms无反馈延迟效果、模式淡出切换、32声部纯HDL频谱测试模式、模式LED与UART状态解析。普通演奏仍为4复音；32声部是独立状态/分时算术的测试引擎，未冒称32条物理流水线或四键独立操控32音符。

13组自动测试全部通过，包括新增组合操作整机验证和12音频率检查。32测试仿真8192样本独立FFT检出32基频，格点误差最大2.811Hz。最终Gowin构建exit0，无WARN/ERROR，setup/hold违反端点0，27MHz下Fmax34.104MHz。具体审查与原始失败/修复过程见complete系列日志，不删除途中错误。用户指南与CLI烧录/串口脚本齐备；串口解析自测通过。

最终码流SHA256 436F86922855BD02BA6A10E8649C8483C04D627FE12B7AA00F5C90263617381A、UserCode7799。用户确认USB重连、未再打开COM13，使用新脚本hash/ID检查后官方operation37写入100%，明确Program and Verify flash successfully、exit0、28.12秒，无bulk erase/OTP。用户全断电重启后对心跳慢闪、全松静音、S0–S3按松发声回复“是的”。未再下载SRAM，官方只读operation73读UserCode0x7799、operation74读Status0x6020，退出码均0，确认冷启动确为新版。

更早的C2F9临时整合版曾SRAM加载并UART读到V1 E0/KF/Y000，后补全音符分组与UART位宽后才生成/部署最终7799。不将临时hash当当前Flash。旧已验证3CB9码流已备份E:/gaoyun/releases/instrument-verified-3CB9.fs。新的模式逐项实物试听、DAC模拟32谱峰、真实总延迟、音质仍未测；第三连续表情传感、压力、蓝牙/App不在本硬件实现。没有宣称赛事全部指标已达标。

## 2026-10-12 快速发热与失声：暂停上电，离线活动修正

用户报告完整7799版切换音色/按键后失声，LED仍亮；GW2A大芯片烫到无法正常触碰，从冷机到烫手估计30秒以内，PCM排针3.3V完全断开。用户曾断电重接后声音恢复。未测温度、输入电流或电源轨，不将“恢复”认定安全，也不认定芯片已损坏。已明确要求Dock/PCM全部断电，不继续复现。

失声需与热故障分开：长按SW会进入静音编辑模式，拨弦预设S=0会自然衰减，重启会复位这些设置；这些只是失声候选解释，未读到故障时状态，不能认定。本次代码检查发现测试bank在gates=0时仍每帧更新32相位，普通闲置声部相位仍走、关闭效果时RAM仍写，属不必要活动，不能直接证明它们导致30秒烫手。

先写空闲活动测试，旧实现确实失败“Inactive 32-voice bank still switching”；修正bank仅在gates或包络active时启动一帧、声部仅在门控/包络活动时推进相位、效果关闭时停止RAM访问并清空有效计数防旧回声。14组回归通过，额外聚焦测试确认bank/keyboard/effect空闲状态冻结。独立项目instrument_idle_candidate离线编译exit0、无WARN/ERROR、setup/hold违反端点0，Fmax36.799MHz；候选SHA256 DB898AEC5C0EF8494A1D7A1B645D1D718CBD99840DFF478903B9B3DEDB24DF02。未上板、未写Flash、未改变板卡连接或驱动。

保存旧7799功耗报告：默认toggle0.125、无VCD/SAIF、环境25°C/无板热模型，估计141.892mW/Tj29.543°C；这些都是模型估计，不是实际功耗或温度，不能用来否定用户触感或确认热安全。参考高云官方功耗分析说明 https://cdn.gowinsemi.com.cn/SUG282E.pdf 与GW2A数据手册 https://www.gowinsemi.com/upload/database_doc/1830/document/6831328fb9769.pdf ，器件供电/结温需在规定条件内，不能把结温限值等同可触摸表面温度。

硬件根因仍未知：需在限流/测温与电源测量条件下核实供电、电流和实际温度，排查异常供电、过流/接触及运行负载，不能凭未动排线排除硬件。无这些条件时保持断电，向厂商/具备条件的硬件人员排查。当前Flash仍7799，软件候选不是已验证热修复。新增hardware-hold.json，并让烧录/串口脚本在未解除实际热故障记录时停止访问硬件；DryRun和解析自测仍可离线使用。该限制源于实际报告的过热，不是权限或自动审批拒绝。

## 2026-10-12 同型号发热公开记录检索

用户问社区是否有类似案例。公开检索Tang Primer20K hot/overheating/temperature/发烫/发热、GitHub/Reddit等，尚未找到与“自定义音频7799、30秒内GW2A烫手、失声、重插恢复”完全一致且已确认根因的社区记录。不把搜索无结果当作不存在。

找到最直接的官方说明：Sipeed Primer20K Lite Blink教程 https://wiki.sipeed.com/hardware/en/tang/tang-primer-20k/examples/lite/blink.html ，明确出厂固件有DDR测试和GPIO翻转，DDR测试会使核心板很热。该记录属于默认固件/Lite教程，与本Dock自定义音频无DDR控制器不能直接等同，尤其不能据此把当前快速烫手认定正常或建议直接继续上电擦除。官方板卡资料 https://dl.sipeed.com/fileList/TANG/Primer_20K/01_Specification/Sipeed%20Tang%20Primer%2020K%20Datasheet%20V1.0.pdf 列温升<30K，但不能用未说明负载条件的指标代替当前实测。

检索到社区作者关于BL702编程后需断电恢复的经历 https://stardance.hackclub.com/projects/9491 ，描述下载器锁住，不是GW2A热故障，不能当同一原因。Habr板卡评测及Sipeed Wiki issue542未找到直接热故障定位内容。结论：存在负载使此核心板明显发热的官方记录，当前热故障仍未定位，保持hardware-hold，不访问设备。

## 2026-10-12 相近发热/可恢复社区与官方记录调查

用户询问社区是否有发热后可恢复的案例。找到Sipeed官方Primer20K Lite教程 https://wiki.sipeed.com/hardware/en/tang/tang-primer-20k/examples/lite/blink.html ，明确默认DDR测试会使核心板很热，并建议不需要时擦除该默认固件。它支持“高活动负载可导致很热”的解释，但不是30秒烫手失声后已维修无损的病例；当前本工程未使用DDR测试，不能套用同一根因，也不据该网页立即擦Flash。

社区原作者项目 https://github.com/juj/gowin_flipflop_drainer （2023/01/03及2023/01/06更新）及讨论 https://www.reddit.com/r/GowinFPGA/comments/101p9yd/ ：Nano4K/9K/Primer20K在添加许多无用途运算时视频不稳定；缩小负载或停止加法链活动可改善/恢复输出。README仍说根因未知，电源/内部干扰猜测并非证实，不能称为已确认的过热救活或可靠维修方案。

本轮未找到与用户“GW2A在30秒内烫手、音频失效、重接恢复”完全相同且明确确认长期无损修复的完整记录。用户重启后发声只说明当时功能恢复，支持不必立即认定永久烧毁；不证明热安全。继续保留热故障暂停，待供电/电流/温度检查后才做受控低活动固件对照。未访问板卡、未烧录。

## 2026-10-12 八路巡线作为琴键评估
读取用户三页PDF并视觉核对，SHA256 E3F2675278E8B6982F6F37A1794178487279A5F69611B2287C1C81A02715974E；方案见docs/line8-optical-keys-assessment.md。可评估光电反射键，优先考虑I2C减少接线；文档缺电气电平和响应率规格且位序示例矛盾，未承诺可直接接FPGA或满足延迟。FPGA热故障暂停仍保留，未上电/烧录。

## 2026-10-12 八路巡线光电键方案核对

用户反馈现有功能包括包络短时全正常，仍不把它作为间歇热故障排除。按用户路径读取八路模块PDF、接线、源代码，确认亚博I2C设备0x12、状态寄存器0x30、x1 bit7/x8 bit0、5V供电。厂家产品页2026-08-30明确对应款通信逻辑3.3V。形成docs/eightway-optical-keys-plan.md，判断可用作8反射式光电触发输入，但须确认实物型号/引脚顺序、触发校准，并扩展现4键程序。尚未给未经验证的板卡针位，未接线或访问硬件。

PDF文字已提取，首次控制台输出遇GBK不能编码NBSP的UnicodeEncodeError，切换UTF8后成功，未改动用户参考文件。参考C源码只读取协议部分，不复制或修改MSPM0小车工程。

## 2026-10-12 专用八路模块说明与接线表

读取用户新PDF（3页）并查看正面插座/排针图片，确认图示YB-MX04-1.0、右白座I2C GND/SDA/SCL/5V，左白座为串口。核对SOM及已归档Pnr，预定独立I2C SCL=T9、SDA=P9，均bank3/3.3V且无现有工程占用；原理图连接LVDS_IOR38_P/N，不是实际Flash网络。形成docs/eightway-wiring.md，保留ADS/PCM/摇杆接线。5V源单独确认，不能接3.3V/GPIO/12V。

说明要求每次模块上电稳定至少20秒，实际工作高度黑/白各静止3秒校准并短按KEY采样，校准值断电保存。建议先单独模块5V/GND校准，FPGA保持断电、两信号悬空。记录PDF中01111111->0x8F笔误应为0x7F/127。当前7799没有该接口驱动，未接线、未上电或烧录，热问题待查状态不因说明正常而解除。

## 2026-10-12 八路模块5V供电来源与ST-Link用途澄清

用户没有现成5V排针，询问能否用ST-Link作供电。查ST官方UM1075 https://www.st.com/resource/en/user_manual/um1075-stsw-link007.pdf ：VAPP是目标板电压参考/检测，标准V2接口的VDD条目标3.3V，不能把这些直接当模块所需5V输出。用户ST-Link具体型号/克隆脚位未知，需照片与输出供电能力确认，不直接授权任意VCC脚供电。

建议明确的USB-A 5V/GND取电转接板，或已确认USB供电开发板的5V输出；无需把5V送入FPGA GPIO或3.3V轨。若现有ST-Link实际提供USB5V电源输出且能力确认，可仅其5V/GND供巡线模块，SWDIO/SWCLK不接本模块/FPGA，通信保持3.3V与共地。未改接线、未访问板卡或烧录。核心热问题仍不以短时功能正常解除。

## 2026-10-12 用户ST-Link实物标注与共地

用户照片为Zave ST-LINK V2金属壳，外壳针脚图标注：1RST、2SWCLK、3SWIM、4SWDIO、5/6GND、7/8 3.3V、9/10 5.0V。依据照片可规划9或10接八路模块5V，5或6接模块GND；模块GND再接Dock真实GND，使ST-Link供电域/模块/FPGA通信参考一致。SCL=T9、SDA=P9预定独立I2C，其余调试脚和ST-Link3.3V不用；不把5V并到Dock3.3V轨，不把ST-LinkVAPP泛称供电。

照片仅证明外壳标注，不证明实际空载电压或供电额定电流；不能套用原厂20pin接口编号到该10pin款，按本机实物编号核对，尚未实测。未操作板卡/接线/烧录；八路驱动未部署，热故障检查仍未完成。

## 2026-10-12 泽而/Zave ST-Link照片供电接线

用户提供红壳Zave/泽而ST-LINK V2照片。外壳明确标1RST/2SWCLK、3SWIM/4SWDIO、5/6GND、7/8 3.3V、9/10 5.0V。可按该实物标注将9或10作为八路模块5V供电候选、5或6作GND；照片并未证明实际电压/额定输出电流，不扩展成供电能力已测。外壳二维图不能直接当插针端面左右顺序，需实物编号/丝印定位。

接线：ST-Link9(5V)->模块5V；ST-Link5(GND)->模块GND；ST-Link6(GND)->Dock真实GND，共地；模块SCL->T9、SDA->P9独立I2C。9/10选一供电，不接3.3V、SWDIO/SWCLK/RESET/SWIM；5V不送Dock3.3V/GPIO。校准单独模块时SDA/SCL悬空、FPGA断电，联调时两端电源一起准备，避免模块独立上电却向未供电FPGA信号口送高电平。当前7799未包含八路驱动且热故障未排除，本轮仅给接线方案，不访问板卡/烧录。

## 2026-10-12 用户ST-Link照片与5V供电/3.3V I2C分离说明

用户照片为Zave/微雪标识红壳ST-LINK V2，壳上功能表标9/10=5.0V、5/6=GND、7/8=3.3V，其余RST/SWCLK/SWIM/SWDIO。不套用ST原厂20pin定义。照片只确认标注，未实测5V或输出负载能力，不能保证该具体克隆器内部实现。

拟接ST-Link标9或10的5.0V至八路模块5V，标5或6的GND至模块GND，再与Dock GND共地；模块SCL至T9、SDA至P9。ST-Link3.3V与调试脚不接；5V绝不接Dock3.3V/GPIO。按实际丝印/编号定位，不能把照片上下左右当插针编号。

厂家对应YB-MX04/8-LP款明确5V供电、通信3.3V；I2C高电平取决于上拉所接电源，不能仅从模块VCC5V推断SCL/SDA5V。若实物电平未确认，先仅模块5V/GND供电，SDA/SCL不接FPGA；测量空闲电平后再连接。如果实际为5V，需真正双向开漏I2C转换，不能用单纯串联电阻当电平转换。

此为接线计划，未连接或通电操作、未烧录，热故障仍待查；新模块驱动尚未部署。用户询问共地，已明确所有供电/通信GND共参考，供电正极不同电压不并接。

## 2026-10-12 用户要求上传全部接线
整理docs/wiring-all-current.md，包括全部USB/电源、ST-Link9供巡线5V、5接巡线GND、6接Dock GND的双地接法、PCM四信号/USB供电/3.3V悬空、ADS与摇杆、八路独立T9/P9、空置脚、PMOD0占用和板载信号。明确7799暂无八路驱动、实物连接未确认及热故障未解除。更新现有手册入口；未改变接线或访问板卡。

## 2026-10-12 八路光键程序离线完成

用户要求写程序。实现optical_keys_reader独立0x12/0x30总线、20s稳定等待、指针写STOP后直接读、单字节NACK、逐位二样滤波、失败全松与重试；泛用i2c_register_bus新增payload_count0直接读路径，ADS原路径回归通过。optical_key_allocator保留已按声部并从8输入填满4个槽；复用现有四个voice_lane，增加缓存外部音符频率与重触发，不复制8个DSP引擎。板载组合控制保持，模块未就绪/断连回退原演奏；GPIO独立T9/P9、全开漏。默认低有效与可选高有效均验证。

新增4组加原14组共18组测试通过，包含8音符音高、四复音限幅、主控制键在线静音、双I2C+PCM串行输出、失效释放与恢复。第一次编译因声明在使用之后被Icarus拒绝，保存失败日志后调整顺序通过。额外极性测试/串口新字段解析自测通过。UART Y bit11在线；在线X为8光键掩码，不在线X仍ADC数值，K仍板载4键。

独立instrument_optical_candidate项目构建exit0，无WARN/ERROR；setup/hold端点违反0，Fmax33.020MHz，DSP54%。码流SHA256 634F999761F85049B0EF3EEB473D53CB972A2B71EE08795B4DDD97C76B7FB234。未读取设备、未上电操作、未烧录，当前Flash仍7799、热故障未解除。详细接口与组音说明在docs/optical-program-candidate.md。不能宣称8复音、实物已达标或热故障已修复。

## 2026-10-12 上下电顺序与课题适配澄清
用户杜邦线已接好，询问烧录试玩、USB插拔顺序及题目合规。新增docs/power-and-calibration.md，明确独立USB信号上拉有反向供电可能，不能凭固定顺序作热安全保证；当前只建议全断电后断开巡线SCL/SDA，ST-Link单供模块完成校准，断电后接回，不对未知热故障做长期试玩。所有USB先断、杜邦信号后拆、地线最后。重读官方2026选题二，光电选音+双轴表达/纯HDL音频/4声部符合设计方向；<=10ms等实物证据仍未完成。未访问设备或烧录。

## 2026-10-13 八路模块改为 Dock 3V3 后的分阶段 SRAM 检查

- 用户确认八路模块标5V输入现接Dock真实3V3，ST-Link供电完全移除；已通电且目前不烫。厂家资料只明确5V供电、3.3V通信，不能把本次选择记作额定支持3.3V供电。
- 只读JTAG：UserCode 0x7799，Status 0x6020，均正常返回；未改Flash。
- 用户授权继续后，下载已离线验证的safe optical候选到SRAM：operation 2，2.5MHz，exit0，UserCode 0x311F，Status 0x6020，耗时6.51秒。原始日志20261013-safe-optical-sram.log。
- 候选SHA256：5EC92CC9C7C0CB7E5739A03109ED61F9B7634246449809AE983AE9856D2E9BFF。默认未启用，外设控制器保持复位、I2S输出高阻；S1+S2保持并短按/松开摇杆按钮切换启用状态。此软件措施不等于断电隔离或热安全证明。
- 用户确认下载后未启用状态：静音、心跳闪烁、没有明显发烫。正在等待启用后的实际传感器/音频结果，未宣称3.3V传感器已可用。
- 原热事件根因仍未知，无实测温度、电压或电流；hardware-hold保留，Flash仍为旧版7799，本次为有限SRAM诊断，非解除热安全问题。

### 2026-10-13 启用组合排查
- 用户反馈LED3常亮、LED2闪、不发烫、无声音。
- 在用户已确认通电不烫的条件下短时只读COM13，清空设备旧数据后采样：3条均IO V0 E0 XFFF Y000 KF S11，表明当前外设未启用；不能据无声判断八路3.3V供电失败。原始与解码日志已保存。
- 用户保持S1/S2，第二次只读采样确认pressed_keys=[1,2]，仍io_armed=false。已要求保持两键、摇杆向下按压并松开一次后再松开两键；待确认。串口已关闭，未执行新下载或Flash操作。

### 2026-10-13 手动启用成功，八路模块回应
- 用户完成保持S1/S2、按压并松开摇杆、再松开两键后，只读新UART状态4条：io_armed=true、adc_ok=true、optical_online=true、play模式、envelope_active=true、板载键全松开。
- 光键内部序号[1,2,3,4,5,6]即物理X2–X7当前触发。尚未知实际背景、安装距离和校准，不能把此状态当作人为六键操作。
- 证明此刻八路模块在用户选择的Dock3V3供电下已回应I2C；不构成额定供电兼容、长期稳定或热安全证明。实际声音和当前温升等待用户反馈。
- 串口已关闭；没有新增下载、Flash写入或驱动操作。日志20261013-after-arm-uart.txt及decoded.json。

### 2026-10-13 高有效光键修正：离线通过，首次SRAM写入失败
- 用户确认旧低有效八光键可演奏、一直响、遮挡改变声音、不烫；按实际用途将optical top ACTIVE_LOW改为0，保留手动启用与低活动控制。
- 19组回归全通过，含高有效极性与安全启停；UART解析自测通过。构建exit0，无WARN/ERROR，Fmax33.173MHz，setup/hold违反端点0。
- 新码流SHA256 B6A4D22C1EEB8343C0C97870C45059BAA3F1198F758271A82BFA0C09FA07E547。
- SRAM operation2/2.5MHz到100%后报Error found，exit254。不得宣称成功，不继续自动重试，已要求仅重新插拔Dock USB-JTAG后恢复。之前已关闭串口，但BL702可能仍需物理重连；本次具体失败原因未确定。
- Flash未改，热故障标记保留。代码人工复核：极性只改变归一化映射；关闭状态复位外设并释放I2S；已有状态不代表实测热安全。高有效空闲背景及实机恢复结果待验证。

### 2026-10-13 重连后高有效SRAM下载成功
- 用户报告已重连USB-JTAG。扫描发现一个设备ID0x0000081B。
- 同一高有效候选再次SRAM operation2下载成功：exit0，UserCode0xCF73、Status0x6020，6.41秒。此次成功与物理重连相关，但不足以单独证明之前错误254根因。
- 未写Flash。已要求重新手动启用、等待20秒并反馈空闲静音/靠近发声/移开停止及发热，实机极性验收仍待用户结果。

### 2026-10-13 高有效八光键实机验收
- 用户对重新启用后的检查回复“可以 没问题”：确认本次测试空闲安静、靠近探头发声、移开停止且没有明显发烫。
- 当前SRAM为高有效安全启用候选，UserCode0xCF73。八路输入最多分配4个同时声部，保留原摇杆与音色/包络控制。此回复不代表所有功能或长期温升完成验证。
- 本轮持续响的问题由触发极性反转后解决。之前快速发热事件仍无确定根因，不能由短时通过宣称热故障已修复。
- Flash仍为旧7799；断电/重配置会恢复旧Flash。未授权本轮新Flash写入，未执行Flash操作。保持PCM独立USB供电、PCM3.3V排针悬空、共地；八路3.3V供电仍属用户选择而非厂家额定支持证明。

### 2026-10-13 用户明确要求后写入八光键Flash
- 用户在实机正常后明确要求“烧录进去吧 暂时没问题”。此次授权仅用于已验收候选，未把此前热故障宣称修复，也未解除默认自动部署暂停。
- 写前核对SHA256=B6A4D22C1EEB8343C0C97870C45059BAA3F1198F758271A82BFA0C09FA07E547，与成功SRAM版一致；上次USB重连后未再打开串口。
- 使用已验证的Gowin GAO-Bridge operation37、SPI地址0、2.5MHz。结果exit0，明确“Program and Verify flash successfully”，耗时27.89秒。原始日志20261013-high-active-flash.log。
- Flash现为高有效八光键安全启用版（构建/此前SRAM标识0xCF73）。已要求全断电10秒、PCM先/Dock后、手动启用后等20秒验收。冷启动结果尚待用户确认。
- 自动部署暂停标记保留，更新其Flash标识及实机部署事实。无OTP、批量擦除、驱动或下载器固件操作。

### 2026-10-13 新无声反馈的只读定位
- 用户报告“这次怎么不响了”。未下载、未改接线、未操作Flash。
- 清空旧串口数据后短时采样3条：io_armed=true、adc_ok=true、optical_online=false、play模式、全键松开、envelope_active=false。当前无声不能归因为未启用或编辑模式；八路模块此刻未在线。
- 已要求保持接线、按板载S1验证回退音频，并确认温升、模块电源灯及音频线位置。3.3V供电稳定性、接触、启动等待等尚未排除，不据一次掉线认定损坏。

### 2026-10-13 S1保持检查纠正定位
- 用户确认PCM LED亮，音频线接音箱AUX，PCM3.3V排针悬空。只读UserCode为CF73。
- S1保持时采集3条新状态：armed=true、ADC正常、optical_online=true、光键全松、pressed_keys=[1]、envelope_active=false。八路已恢复在线；此时板载键用于功能控制，S1不直接演奏，因此这次S1无声不能证明DAC故障。
- 前一次八路offline与本次online表明状态有变化，启动等待或间歇通信尚未区分。已要求持续触发一路光键再读包络，未重启或重烧。

### 2026-10-13 用户改接电脑麦克风后的音频采集
- 用户说明音频已从音箱改接电脑麦克风口，因此此前音箱无声不可据此认定PCM故障。Realtek WASAPI输入device18，48kHz双通道；安装sounddevice供本地录音，未改FPGA程序。
- 空闲2秒录音峰值0.000672、RMS0.0000916，无满幅削波；用户持续触发后2秒峰值0.760585、RMS0.265484，无abs>=0.999样本。
- 窗函数FFT主要峰523、587.5、659、784Hz，及相应谐波，证明此次有音调到达电脑输入，提供四基频初步证据。未单独验证各光键对应音高，非32路容量、端到端延迟或THD正式验收。
- 录音左右通道几乎相同，不据此证明真正独立立体声。麦克风模拟输入额定范围/增益/自动处理未确认；无数字削波不等于模拟链路无失真或输入电压额定兼容。
- 用户已被告知可以移开。保留两份原始WAV与分析JSON供复核；未写Flash或改变电源接线。

### 2026-10-15 空闲音频基线
- 用户确认空闲，Realtek WASAPI输入录取3秒，48kHz双通道；未改FPGA程序或接线。
- 峰值约0.000478，RMS约-84.45dBFS，无数字满幅削波。本段未见明显持续音，作为本次录音链路空闲基线；不能仅凭低底噪证明设备已启用或连接正常，需下一步已知触发对照。
- 原始数据logs/20261015-idle-audio.wav及json。未测绝对电压、模拟THD、端到端延迟或温度。

### 2026-10-15 X1对照发现当前未启用
- 用户回复ok后进行3秒音频与短时新UART采样。UART armed=false、V0/XFFF、optical_offline、无包络；故不能将此次录音当作X1音高验收，FFT低电平峰不认定乐器音高。
- 峰值0.001694、RMS -73.21dBFS，无满幅削波。先前空闲基线仅说明录音低底噪，不证明已启用工作态。
- 已告知松开X1，要求执行一次S1+S2/摇杆启用并等待20秒，再只读确认。未下载、未写Flash。原始音频、UART、JSON均保留。

### 2026-10-15 启用后的空闲基线
- 用户执行一次启用组合后确认。新UART：armed=true、ADC正常、八路在线、光键/板载键全松开、play模式、无包络。
- 随后录3秒48kHz：峰值0.001936、RMS -71.62dBFS，无满幅削波。此为已启用空闲基线，比先前未启用基线高约12.8dB；未标定麦克风增益/处理，不将差值直接归因DAC噪声。
- 下一步X1单通道与音高对应验收；本轮未改程序或Flash。原始数据20261015-armed-idle.*。

### 2026-10-15 X1单键音高验收
- 用户保持X1；新UART确认armed=true、八路在线、仅内部光键0（X1）触发、包络active、play/page0/timbre0。
- 同期3秒48kHz录音主峰523.333Hz，对应预期C5约523.251Hz（FFT栅格0.333Hz，未校准声卡时钟，不将该差值作为精密音准结果）。峰值0.289858、RMS -18.40dBFS、无满幅削波。
- 此次通过X1通道识别及C5发声检查；释放停声仍需移开后对照。原始WAV/UART/JSON为20261015-x1-armed.*。

### 2026-10-15 X2操作采样实际为X1+X2
- 用户按提示从X1切至X2后回复ok。新UART确认光键[0,1]同时触发（X1+X2），非X2单键。
- 录音含523.333Hz及587.333Hz，对应C5+D5，峰值0.421825、RMS -16.97dBFS，无满幅削波。能佐证本段两个音同时存在，但X2独立通道/邻键误触与X1释放仍未验收。
- 不将相邻触发直接认定软件故障或传感器串扰；要求移开X1并缩小遮挡范围，仅保持X2后重测。原始数据20261015-x2-armed.*。

### 2026-10-15 X2单键复测通过
- 新UART确认仅光键[1]即X2触发，八路/ADC在线、armed、play/page0/timbre0、包络active。
- 3秒录音主峰587.333Hz，符合D5约587.330Hz（未校准声卡时钟）；峰值0.122585、RMS -25.42dBFS，无满幅削波。X1已不再触发。
- 与X1录音幅度不同，未经录音增益/自动处理核实，不据此判定声部增益故障。原始数据20261015-x2-retest.*；未改变程序。

### 2026-10-15 连续扫键自动验收
- 用户同意一次来回扫键，采集60秒48kHz双通道WAV与238条带主机相对时间的UART状态。所有状态armed且八路在线，零掉线样本；峰值约0.65665，无满幅削波。
- 按连续相同单键状态>=0.45秒挑稳定片段，音频中点近似对齐（主机UART时间非严格同步，不能用于延迟验收）。X1到X7分别有5/4/4/3/2/3/1段，主峰约523/587.5/659/698.5/784/880/988Hz，均匹配默认C5/D5/E5/F5/G5/A5/B5。
- X8有4条独立触发样本，但没有足够长的稳定单键片段，尚未计为单键音高通过；多次与X7一起触发，需只补测X8，无需重做全部。
- 状态中114条为全松开。当前分析未逐段验收释放时间、模拟失真、四音同时或32声部容量。原始WAV、UART、时间状态与分析JSON已保留。

### 2026-10-15 X8补测完成八键默认音高验收
- 用户保持X8，新UART确认仅[7]触发，armed/ADC/八路在线，play/page0/timbre0、包络active。
- 同期3秒录音主峰1046.333Hz，对应C6约1046.502Hz（FFT间距0.333Hz，未作声卡时钟标定）。峰值0.244690、RMS -18.58dBFS，无满幅削波。
- 合并本次与连续扫键证据，默认分组X1–X8对应C5 D5 E5 F5 G5 A5 B5 C6的通道/音高检查完成。不是所有模式/延迟/长期热稳定/32复音验收通过。
- 数据20261015-x8.*，无程序或Flash变更。

### 2026-10-15 相邻四光键和弦实测通过
- 用户白纸覆盖X1–X4并保持。新UART确认且仅光键[0,1,2,3]同时触发，armed/八路/ADC正常，play/page0/timbre0，包络active。
- 同期3秒48kHz录音含523.333、587.333、659.333、698.333Hz四基频，对应C5/D5/E5/F5，不把谐波当额外声部。峰值0.720322、RMS -13.13dBFS，无数字满幅削波。
- 结合已逐键验证，可佐证实际DAC输出的4音并发；尚非32声部、释放独立性、模拟THD、<=10ms端到端或热安全验收。
- 原始数据20261015-chord-x1x4.*。无程序/Flash更改。已通知可移开，后续录移开后静音。

### 2026-10-15 四音移开后的静音验收
- 用户全部移开，新UART确认光键全松、包络inactive，armed/八路/ADC仍在线，play模式。
- 3秒48kHz录音峰值0.000493、RMS -84.15dBFS，无满幅削波，回到低底噪；支持本次四音释放后无持续卡音。
- 录音发生在用户反馈之后，仅验证最终停声状态，不声称已量出Release曲线、释放时间或<=10ms响应。
- 原始数据20261015-chord-released.*；未改程序或Flash。下一步可一次连续采集摇杆X/Y表现，不需逐动作回复。

### 2026-10-15 摇杆连续音频检查
- 用户保持X1并按提示左右/上下移动，采集30秒48kHz音频及119条UART；全部只X1触发、play/timbre0、ADC正常、八路在线。
- PCM录音峰值0.32867，无满幅削波。结合RTL弯音范围对X1基频搜索限制460–590Hz，检测470.5–576Hz连续范围；最初宽带最大峰会选中约1047Hz强二次谐波，已修正分析方法，未把强谐波误判升八度。
- 基频/谐波能量比例明显变化，符合操作中音色变化；当前UART在线时不传摇杆原始X/Y，无法精确逐轴对齐或由此证明线性、中心精度及单轴解耦。Windows录音增强/增益未标定，不把谐波比例当模拟THD。
- 本轮支持摇杆弯音及波形变化功能工作，未测动作端到端延迟。数据20261015-joystick.wav、uart、telemetry、analysis JSON。未更改程序或Flash。

### 2026-10-15 三音色一次连续实测
- 用户按X1保持/移开、摇杆短按两次流程操作，40秒48kHz音频+159条UART。编号按0→1→2切换，均play模式，八路零离线样本。
- 三段稳定X1录音均检出约523.1–523.3Hz（C5）。preset2高次谐波更强且按住过程中衰减到底噪，符合锯齿拨弦S=0预设；不是因此认定卡音或失声。
- preset0/1本次频谱差异较小，不能将此轮扩展为两种逼真乐器音色验收。三个预设切换/发声已验证；音色可辨识度、音量一致性和Windows增益/增强影响仍需改善或核实。
- 整段峰值0.58136、无满幅削波。分段按主机UART粗略对齐，边界可能混入松键释放，不将分析early/late RMS当作精确ADSR时间或端到端延迟。
- 数据20261015-timbres.wav、uart、telemetry、analysis JSON。未改程序/Flash。前轮摇杆日志推送曾HTTP408，本次与后续push一并恢复。

### 2026-10-15 首轮32路入口操作未进入测试
- 已说明S0+S3保持、摇杆长按约1.5秒进入、测试约3秒后同动作退出，并采集30秒音频/119UART。
- 实际全部119条mode=play，最终note_page=1、timbre2，无test32样本。分组变化支持至少识别过S0组合短按，但未证明具体操作时间/顺序。
- 不将本次音频当作32路验收，尚未分析/声称32谱峰。峰值0.51431，无满幅削波，末状态armed/ADC/八路正常、光键松开、包络inactive。
- 提示需要正确保持长按，待用户再次配合；无下载或Flash更改。数据20261015-spectrum32.*。

### 2026-10-15 32路多频实物录音验收通过
- 用户明确已开启32路，立即采集3秒48kHz音频并读取新UART；mode=test32、armed/ADC/八路在线、包络active、光键松开。
- 对129+31*n Hz（n=0..31，即129–1090Hz）每个预期频点检查±3Hz邻域，要求频差<2Hz且比6–13Hz邻域中值高>15dB；32/32均满足。日志保留逐峰测量值和判据。
- 音频峰值0.881609，无abs>=0.999数字满幅削波。结合RTL独立相位/包络状态及该模式标识，可提供实际DAC混合输出含32个预期独立基频的证据；不把谐波计数当复音，也不宣称32路自由演奏/可控完整ADSR都已完成。
- 已立即通知退出32路并确认温升；退出与温升结果待用户确认。未改程序或Flash。本次频谱不证明<=10ms端到端延迟或热安全。
- 原始数据20261015-spectrum32-active.wav、uart、json。

### 2026-10-15 剩余项目连续综合采集
- 120秒48kHz双通道、475条UART；armed/ADC/八路全程正常，无test32状态；72条edit、403条play。峰值0.60663，无满幅削波，最终光键全松、包络inactive。
- X1到X4依次加入再依次释放，状态均记录到；但本次仍是preset2、Sustain=0拨弦预设，按住时包络已自行归零。因此本段不能证明“释放一路时其他持续声部仍响”，该项目需换持续音预设再测。
- 延迟由false切到true，记录到三次X1触发；未记录到关闭，最后仍true。只能确认控制与开启状态、实际有音频，不凭当前混合录音宣称已精确验收约43.7ms延迟分量。
- 编辑依次选择A/D/S/R均成功，随后退出edit并两次触发X1有声、移开静音。可验证编辑流程及修改后发声；UART未报告参数实际值，多个参数连续修改且延迟开启，不足以独立量化四参数响应。
- 最终play/page1/preset2/echo=true、光键全松。热状态未实测，不能由通信正常宣称温升正常。无程序/Flash修改。
- WAV转为16bit无损FLAC并逐样本校验完全相等，保存20261015-combined.flac、uart、telemetry、analysis JSON。此轮未完成的项目明确保留，不标为全项通过。

### 2026-10-15 独立释放补测暂停并上传
- 准备状态只读确认timbre0、delay=false、play、page1、八路/ADC正常。
- 随后40秒采集158条均光键全松、无包络，录音峰值0.001724，因此本次未采到四键操作，不算独立释放通过。保留原始FLAC/UART/状态。
- 用户随后报告已覆盖X1–X4，但在下一次确认/采集前要求先上传；已暂停测试，未再访问板卡。用户可移开白纸；该次覆盖未录取，不标成功。
- 当前最新综合测试记录此前push遇HTTP408；此次补齐上传。未改程序或Flash。

## 2026-10-18 手机伴侣首版
- 用户要求同时实现手机触控演奏和外接音频转手机扬声器；本轮 FPGA 不在场，未修改 RTL、引脚或 Flash。
- 新增原生 Android 应用：8触键/4复音本地预览、三预设、弯音、明亮度、紧急停止；可向电脑开发桥发送协议事件。开发桥仅记录，明确返回 fpga_connected=false，实际 FPGA 控制接收端尚未实现。
- 外部输入监听默认关闭，只接受外部耳麦/USB输入，拒绝内置麦克风；路由变化、离开页面/应用停止。普通 AUX 线不能直接作为手机输入，模拟接线与延迟未验收。
- Redmi K30 Android12 已识别。ADB 安装返回 INSTALL_FAILED_USER_RESTRICTED: Install canceled by user；用户表示无法开启USB安装，未绕过系统限制。
- 改用 adb push 成功复制 APK 到手机 Download/FPGA-Instrument-Companion.apk，待用户通过文件管理器正常安装；尚无手机界面、实际发声或监听成功证据。
- JDK17 构建、签名验证及 SynthCore 检查通过；Python 协议4测试通过。保留布尔键值校验缺陷的红/绿日志。javac 有 source8 bootstrapclasspath 警告，无构建错误。
- APK SHA256: BD11D80BC7A06528C6ACDF2B796E82EF20D72868D2DA0F449D286922F527B44C。仓库副本 mobile-companion/apk/instrument-companion-debug.apk，调试签名私钥不入库。

## 2026-10-18 官方赛题与GitHub复核
- fetch确认最新main为a74517a，阅读57d8ba3交接文档与原始操作记录，并核对官方选题二当日页面。
- 新增docs/competition-audit-20261018.md：主线未偏，基础≤10ms尚缺同步实测；4音/32谱峰已有实录，ADSR独立参数、释放独立性、效果器和温升尚有缺口。
- 明确Primer20K题目适配资格需官方确认，32测试库不等于32自由演奏，手机软件合成不算FPGA核心成果。暂停优先扩展App，不访问板卡或改Flash。

### 2026-10-18 FAQ补充修正
- 读取用户粘贴FAQ，A1/66允许其他高云主芯片板卡，77承认独立状态TDM的32voice统计；已修正审查文档，不再把推荐清单缺Primer20K作为当前阻碍。
- 当前32测试库仍是固定频率/AR，不夸大为完整32voice。FAQ73指向的技术103未包含，延迟起算口径仍待核对。无硬件操作。

## 2026-10-20 外部FPGA审阅交接与仓库邀请
- 按用户授权，通过GitHub API向Shengzj2026发出myfines/d-dfdf的write邀请；HTTP201，邀请ID338694468，等待对方接受，未授予admin权限。
- 新增docs/fpga-review-brief-20261020.md，按官方基础/拓展/现场要求区分实现、实测及缺口，标明旧README快照、温升未决、32测试库限制和无硬件操作边界。
- 本轮未访问FPGA、未编译更改RTL或写Flash；简介与权限邀请不构成功能验收。

### 2026-10-20 ESP/OLED/K230预核
- 根据用户要求检索官方赛题、模块规格、亚博K230资料并检查本地目录；新增extension-architecture-20261020.md。
- 已找到亚博专用镜像、手部关键点/手势与串口例程；磁盘仅见系统NVMe，未发现64GB卡，未写盘或访问FPGA。
- 方案为ESP网络透传、FPGA直接HDL驱OLED、K230可选视觉表达输入；WiFi不冒称蓝牙，32规模/延迟等原缺口不因增加模块自动达标。最低蓝牙成交价未核验，不报虚假精确价。

### 2026-10-20 仓库改为私有
- 按用户明确要求将myfines/d-dfdf设置为private；GitHub API重新读取确认private=true、visibility=private。
- 未修改协作者权限、源码或硬件。

### 2026-10-20 接收外部实测报告
- 原样收录用户提供report-20261020.md至docs/external-reviews；新增external-report-review-20261020.md，列出本仓库测试路径、手工交付办法及待证据支撑的延迟/时钟/零点结论。
- 对方报告引用的延迟RTL、分析脚本、原始录音尚未收到，不将该报告升级为本机全项验收。未修改RTL、未访问设备或烧录。

### 2026-10-20 协作者提权尝试及SD用途核对
- 用户要求提高Shengzj2026权限。GitHub API对permission=maintain和admin均返回422 Validation Failed；未成功提权，不能声称管理员已授予。个人仓库通常仅有所有者/协作者两级，需组织仓库才能使用细分角色；本轮未转移仓库所有权。
- 核对instrument_io源码和当前光键顶层，无SD接口或存储读卡逻辑。现有演奏程序由板载Flash启动，64GB TF卡非当前工程依赖；断电取卡可供K230使用，但写镜像前应备份卡内未知数据。

### 2026-10-20 OLED与ESP接线规划
- 用户确认OLED四针GND/VCC/SCL/SDA；核查本地SSD1306 IIC资料、官方Dock背面图和SOM/GowinBank2引脚信息，分配PMOD1 T11/P11给OLED、T12/R11给ESP RX/TX。
- 按用户授权询问同项目ESP任务，收到handoff：大板ESP8266EX而非ESP32，小ESP AT/WiFi扫描通过，3V3供电来源待核实。未访问串口、未改HDL/Flash、未给新接线通电。
- 新增docs/oled-esp-wiring-20261020.md，包含背面/正面镜像定位、旧接线表过时提示与候选功能，等待供电确认。

## 2026-10-20 K230独立资料预检
- 目的：为亚博K230标准版手势扩展确认官方依赖；与OLED/ESP任务分开。
- 操作：Get-Content读取AGENTS与扩展/审阅文档；rg --files及定向读取08.Body/06.hand_keypoint_detection.py、固件目录。无硬件命令，未产生硬件日志。
- 结果：手检测512x512 + 关键点256x256，两独立模型未在资料目录按扩展名检出；镜像内部及nncase匹配尚未验证。详情见docs/k230-bringup-20261020.md。
- 新增k230/preflight.py，只做板上依赖/文件只读预检，尚未板测。未改RTL/Flash，未识别/写入TF卡，未给外设上电。

## 2026-10-20 K230 USB连接初检
- 用户反馈：仍为电赛程序，已插USB，委托检查。
- 命令：Get-CimInstance Win32_SerialPort、Get-Disk、Get-PnpDevice及Get-PnpDeviceProperty；.NET SerialPort COM9/115200，DTR/RTS关闭，先被动读取4秒，再发送两次Ctrl-C及换行尝试控制台。
- 结果：COM9，USB VID_1209 PID_ABD1，设备总线描述CanMV；Windows仅见系统NVMe，无TF卡磁盘。被动读取无字节；Ctrl-C/换行后无控制台提示，未发送Python语句。不能据此确定固件版本、摄像头状态或故障原因。
- 实际影响：打开并关闭COM9，Ctrl-C可能中断原程序，未确认是否生效；未写文件、复位、写卡或烧录。待用户说明屏幕状态与USB接口标识，再选择CanMV调试协议或控制台路径。

## 2026-10-20 K230官方关键点写入与黑屏待查
- 获用户明确授权使用官方例程写入。核对官方CanMV IDE k230分支源码协议：USBDBG 0x30，12Mbps、DTR使能；COM9版本请求返回(0,4,0)，Python回读为CanMV v1.8-24-g46d59a8，2026-07-30，k230_canmv_yahboom，sys.version 3.4.0。协议版本不可冒作nncase版本。
- 原main.py(31805字节)和boot.py(73字节)已通过USB回读至E:/gaoyun/k230-private-backup-20261020，不上传含隐私可能的原程序。main SHA256 76baacde214193a1bc1c586145dd5eb4aaf0788831280fd169294f78f1284972；boot SHA256 7d0a9a5a9f58fd73def81c97b47d2d6450cfd8b99c75036e2287d76e93572282。
- 板上两个手模型均存在。官方05手检测、06关键点各运行约8秒，无异常栈；GC2093摄像头已枚举，检测循环约35ms、关键点约40–70ms。含deprecated function提示。此为循环日志，不是完整视觉或端到端验收。
- 将官方06写至/sdcard/k230_hand_keypoint_official.py，24235字节，逐字节回读一致，SHA256 b8ab965366346f9749682a516514a29d9d7f42cc036fc30391532852c0b3a6c1。原main重命名为/sdcard/main_electronic_contest_backup_20261020.py；新main为加载官方文件的启动器。boot、固件、模型不变。主机命令脚本E:/gaoyun/k230_host_probe.py通过USBDBG停止/执行，上传通过临时Python逐块写入并读回；未重刷卡或FPGA。
- 新main已手动启动，但未断电验证自动启动。用户反馈仍黑屏，不能称完整成功；已暂停推理检查显示库。板上/sdcard/libs/PipeLine.py所有非virt模式都初始化ST7701；原电赛程序有显示自动尝试逻辑，但该库实际忽略模式差异。待确认用户说的屏幕是物理LCD还是IDE窗口，再定位显示配置。当前运行的是只读显示库检查脚本，摄像头循环已停止。
- logs/20261020-k230保留本阶段运行原始日志（不含原程序）。恢复原程序可在停止运行后保留新main另名，再将备份main恢复；尚未执行恢复。

## 2026-10-20 K230标准版显示与快照核验
- 用户不知预览窗口位置，称板上不亮；本地供电说明明确标准版不带屏幕，豪华版带屏。尚未确认用户是否额外接LCD，不把板上不亮直接判为故障。
- 实际将官方关键点例程display_mode临时改为virt运行；IDE帧请求0x81持续返回0尺寸，旧/新FB_ENABLE请求均未取得预览帧，未宣称IDE预览已通。
- 使用sensor.snapshot(chn=1).compress(quality=75).save保存单张摄像头JPEG，经串口十六进制回读至E:/gaoyun/k230-live-preview.jpg，31382字节；实际查看为桌面、线缆与旁边物体，确认摄像头真实出图。图片含用户环境，留本机、不入Git；该快照不是带关键点叠加的画面。
- main启动器已改为在内存将官方源display_mode lcd替换为virt后执行，官方源文件不变。写入前临时文件回读一致；前一LCD启动器另存/sdcard/main_lcd_launcher_backup_20261020.py，原电赛备份仍保留。新启动器已执行；未断电验收，未得到用户手势识别确认。
- 首次启动器更新在发送Python前串口WriteFile失败(PermissionError13，设备不识别命令)。重新只读查询协议版本成功后重试一次并成功。最新循环约93–150ms，比早前40–70ms更慢；原因尚未分析，不能拿早前速度当最终性能。原始日志logs/20261020-k230/k230-virtual-activation.txt。下一步确认显示硬件、建立可见预览并以手验证关键点，再做连续参数。

## 2026-10-21 恢复LCD并协助IDE预览
- 用户反馈IDE无画面。串口COM9可由主机打开；确认IDE窗口helloworld_1.py - CanMV IDE K230，进程canmvide，E:/yolo/bin/canmvide.exe。未操作IDE界面。
- 使用E:/gaoyun/k230_host_probe.py通过USBDBG，将main.py恢复为执行保留的官方关键点源（默认LCD），写后回读启动器一致，打印LCD_MAIN_VERIFIED并运行约6秒。摄像头GC2093、循环约40–69ms，未见异常栈，含deprecated function提示。板上显示与IDE画面仍待用户确认。
- 现有PipeLine的LCD Display.init已带to_ide=True，无需再次改库。串口已关闭释放，指导用户IDE连接COM9、启用帧缓冲区；避免运行默认helloworld覆盖当前例程。未动原电赛备份、boot、固件、模型或FPGA。日志logs/20261020-k230/k230-lcd-restored-20261021.txt。

## 2026-10-21 IDE连接后画面停止排查
- 用户截图反馈一连接就卡死。进程canmvide 39120检查Responding=True；COM9尝试打开返回PermissionError13拒绝访问，说明串口已被占用，不再抢占。配置DisableFrameBufferState=false、LastSerialPortState=COM9。以上不等于已证明IDE无卡顿或画面正常。
- 假设：IDE连接会停止脚本，需加载正确例程后运行；尚未经用户操作复现确认，不认定根因已解决。之前要求不要运行helloworld但未提供IDE正确运行文件，流程缺少步骤。
- 新增k230/run_hand_keypoints.py，仅执行板上保留的官方关键点源，不写main、不动备份。Start-Process E:/yolo/bin/canmvide.exe E:/gaoyun/d-dfdf/k230/run_hand_keypoints.py，已确认同一IDE窗口标题切为run_hand_keypoints.py。待用户点击运行验证LCD及帧缓冲区；若真实无响应仍需继续排查。


## 2026-10-21 K230与Dock USB/UART连接预核
- 只读查询Dock官方原理图与Sipeed产品页，并查看USB PHY页。结论与修订版不确定性见docs/k230-fpga-link-20261021.md。推荐独立5V供电、经电平/管脚核验的TTL UART共地。没有接线、上电、烧录或改RTL。


## 2026-10-21 K230-Dock OTG供电/UART资料预核
- 读取本地Dock3713 Rev1.1官方PDF，渲染/查看USB PHY与BL702电源页；读取亚博供电说明、标准版接口图片与UART例程、原电赛UART引脚配置。无硬件命令，无电源/接线/RTL改动。
- J8 VBUS直连+5V、CC1/2下拉、数据接USB3317，不是可直接输出UART的USB转串口；不能据共享5V网保证给K230供电。建议K230独立5V、两板UART+GND，待3.3V Bank/实际电平及空闲GPIO核对。详见docs/k230-fpga-link-20261021.md；不执行共享USB供电，保持现有Flash。

## 2026-10-21 用户要求单电源与顺序无关设计
- 修正成品目标：一个足额5V电源分路供Dock/K230/PCM，一个总开关；不要求用户记忆开关顺序，不从3V3或Dock OTG串接转供。仍须确认实际模块与负载峰值，尚未实装。
- 直接请求TI官方TXU0101及SN74LVC1G125数据手册并读取：前者任一电源<100mV或断开输出高阻，支持Ioff，可作双板UART隔离候选。现有I2S同样须检查，避免仅修新增UART。首次PDF输出遇控制台gbk UnicodeEncodeError，改UTF8后读取成功；不涉及硬件。
- 外部搜索工具报错、Sipeed wiki超时，未获得他人同款实装案例。详见docs/k230-system-power-20261021.md。仅资料核对，无接线、供电或FPGA修改。

## 2026-10-21 OTG官方及第三方实现查询
- requests读取Sipeed官方wiki、官方TangPrimer-20K-example/USB与第三方kami4ka/tang_computer README/docs/usb3317.md，核对设备端例程与键盘主机先例的差别。详情和URL追加docs/k230-fpga-link-20261021.md。
- 单根USB连接K230有工程实现方向但当前未实现/验收，不能按已有串口程序插线即用；第三方键盘结果未本地复现。无供电、烧录、接线或RTL更改。

## 2026-10-21 K230捏合量IDE预览V1
- 用户要求实际编写并在IDE看到数据。新增k230/pinch_preview.py单文件：复用SD官方类，LCD与IDE显示，点4/8距离除以点5/17掌宽，检测置信度0.35、掌宽>=20px、3稳定帧、120ms时间平滑、捏合滞回、丢手/多手无效、位置大跳变重新稳定。0.15~1.30为待校准百分比映射，不输出UART/音符，不替换main或备份。
- TDD：先运行python -m unittest discover -s k230 -p test_pinch_preview.py，因模块未实现ModuleNotFoundError失败；实现后5项通过，原始最终输出logs/20261021-k230-pinch/unittest.txt。覆盖缩放归一化、丢手重获、多手/低置信度/退化、滤波滞回、位置跳变。
- COM9空闲后使用E:/gaoyun/k230_host_probe.py对新文件试运行8秒。首次停止旧官方循环触发IDE interrupt与MPY soft reboot，新程序未成功启动；返回控制台后第二次7秒成功，出现PINCH TRACK/WARMUP/NO HAND等日志，无新异常。原始两次日志均保留logs/20261021-k230-pinch。只证明板上接口/计算输出兼容，未声称已确认用户动作对应性/最终精度。
- Start-Process E:/yolo/bin/canmvide.exe -ArgumentList E:/gaoyun/d-dfdf/k230/pinch_preview.py，窗口标题已确认pinch_preview.py。用户在IDE连接后运行此文件，在帧缓冲区看进度条，在串行终端看限速约5Hz日志。说明与列定义见k230/README.md。
- 当前并发任务修改instrument_io、scripts及其他logs，本次不触碰、不暂存这些文件；无FPGA接线、供电、烧录或固件更改。
## 2026-10-21 OLED与ESP-01S离线扩展候选 E021

- 用户确认除K230外接线完成并要求写程序。本轮不访问硬件、不下载SRAM、不写Flash；保留hardware-hold和旧构建入口。ESP从Dock3V3取电的峰值预算及历史发热原因仍未核实。
- 新增独立extension顶层/约束/构建脚本：FPGA生成SSD1306波形及键/状态图；ESP原AT固件配置局域网AP/TCP，Vhh换行控制音量，支持分包、客户端隔离、超时回退、重启重配。K230未接入。使用说明docs/extension-candidate-20261021.md。
- 25项RTL仿真通过（原19+新增6），日志20261021-extension-suite-verified.log；Python客户端本机TCP内容/续租/越界拒绝通过，未连接实际ESP。客户端首次测试对调度次数断言过严，修正测试后通过，保留说明。
- 首次OLED快照旋转资源超限59083/20736，改为固定快照+单读地址；第二次输入端口ESP_RX非法DRIVE约束已删除。两次失败原始日志保留。最终Gowin构建成功，逻辑7995/20736（39%），寄存器3454/16173，BSRAM5/46，DSP13.25/24；27MHz约束实际Fmax32.283MHz，setup/hold违例端点均0。
- 候选UserCode0xE021，FS SHA256 6D89D33520697199C489A78BA5FEB17C31F13B1D3CC9D1A175C7B2718CC42C5D。机器记录logs/20261021-extension-verification.json，最终构建及PnR/时序报告同时保存。OLED约2–3帧/秒，不宣称题目≤5ms可视化或实物端到端验收。


## 2026-10-21 按用户要求直接配置电脑预览，禁用computer-use
- 未使用computer-use/CUA/桌面截图/模拟鼠标键盘工具。命令行读取CanMV配置及官方源openmvplugin.cpp/openmvpluginconnect.cpp，确认-auto_connect/-auto_run受支持，连接完成后autoRun调用startClicked。
- 原配置OutputPanePlaceHolder Height=0，串行终端虽visible但高度为零；StopScriptConnectDisconnect=true。先用进程正常关闭请求CloseMainWindow并等其退出，未强制终止；备份INI到E:/gaoyun/CanMVIDEK230-before-pinch-autoview-20261021.ini，未上传用户全量配置。
- INI保持DisableFrameBufferState=false、LastSerialPortState=COM9，改ZoomState=true、终端Height=260。通过Start-Process E:/yolo/bin/canmvide.exe -auto_connect -auto_run E:/gaoyun/d-dfdf/k230/pinch_preview.py启动。
- 确认新IDE进程32044 Responding=True、窗口pinch_preview.py，COM9打开返回拒绝访问，未抢占。此为自动启动配置和进程/端口证据，未目视确认当前实时画面/数据。无改板上main、固件或FPGA。
- 增加k230/open_pinch_ide.cmd供后续从IDE已退出状态一键启动，说明追加k230/README.md。其他并发文件不暂存。

## 2026-10-21 E021受监督SRAM下载与版本保存
- 用户要求版本管理并开始烧录，随后确认当前温度正常、ESP仍接Dock3V3。本次授权仅用于受监督E021 SRAM试载，不解决/清除历史热故障与ESP电源预算问题，Flash未写。
- 已推送注释标签candidate-E021-20261021，指向源码e095204；候选码流和manifest另存E:/gaoyun/releases/instrument-E021-20261021，写入前SHA256匹配6D89D33520697199C489A78BA5FEB17C31F13B1D3CC9D1A175C7B2718CC42C5D。
- 下载器A/B均OK，无残留烧录进程。JTAG 2.5MHz扫描ID81B；operation2写入100%、UserCodeE021、Status6020、exit0、6.63秒，但工具同时打印User code mismatch，不能只凭exit0声称通过。
- 随后独立只读operation73读回E021、operation74读回6020；异常提示根因未确定，不宣称已做SRAM逐位回读校验。用户现场心跳/温度确认仍待回复。未按启用组合，不启动ESP Wi-Fi。
- 脚本新增仅限显式SupervisedSram+SRAM+E021固定哈希的受监督入口，默认热保护保留、Flash仍禁止；增加100%/6020与不匹配提示检查，防止exit0掩盖故障。

## 2026-10-21 18:25 用户再次要求开始烧录
- 重复下载同一固定哈希E021至SRAM，Flash未改、未启用外设。operation2写入100%、exit0、6.47秒，仍有User code mismatch提示。独立operation73读回E021，operation74读回6020。功能/温度现场确认仍待用户，不宣称回读校验或验收完成。日志前缀20261021-182530。


## 2026-10-21 18:34 E021 Flash持久化
- 用户澄清Wi-Fi是在断电后才测试，明确要求重烧Flash；故不能将先前搜不到AP归因于AT/接线故障。选用已归档E021，不使用工作区尚未验证的OLED/ESP诊断修改。
- 固定哈希6D89D33520697199C489A78BA5FEB17C31F13B1D3CC9D1A175C7B2718CC42C5D，2.5MHz operation37（GAO-Bridge）写入并校验成功，exit0、28.18秒，明确Program and Verify flash successfully。日志20261021-183440-instrument-Flash.log。未执行OTP或下载器固件更新。
- 已确认旧CF73本地候选哈希B6A4D22C1EEB8343C0C97870C45059BAA3F1198F758271A82BFA0C09FA07E547并复制到E:/gaoyun/releases/instrument-E021-20261021/fallback-CF73.fs；它是已知构建备份，不是本次Flash实物回读。
- 用户本轮已确认SRAM心跳、静音、不烫及启用后OLED响应。Flash冷启动和Wi-Fi待实物确认；历史热故障/ESP3V3预算仍未解决。新增固定E021哈希专用Flash显式授权入口，默认hold未清除。


## 2026-10-21 E022高帧率OLED候选
- 用户确认E021可用后要求借鉴开源波形方案。查阅Adafruit SSD1306、huseyink/ssd1306、FPGA示例及Solomon SSD1306原厂手册表13-6，参考批量传输/非阻塞思路，独立编写RTL，未拷入第三方代码。资料与取舍docs/oled-E022-20261021.md。
- 显存改为地址+0x40+1024字节一笔开漏事务；命令亦使用有界开漏发送。参数36，数据保持≥9个27MHz周期；无应答、时钟卡住、重置释放均有测试。过零触发、4倍抽取、完整捕获冻结、双快照、连线、峰值条、音色/音量/AT步骤及RX标记。ESP诊断仅可见状态，不把RX字节等同AT成功。
- 首次RED缺少stream模块和diagnostic端口，原始日志保留；测试适配连续写屏后通过。曾因PowerShell未给-P参数加引号导致iverilog参数解析失败，改引号后编译通过，未使用失败编译的旧产物。27项回归通过，最终幅度微调后采集/实际像素/默认时序分别重测通过。
- 默认参数仿真周期697743时钟、约38.696fps；非实物光学刷新率，未宣称≤5ms可视化延迟。原始显存hex和PNG仿真预览保存，scripts/render-oled-frame.py可重建预览。
- 最终Gowin构建成功：逻辑9052/20736，寄存器3597/16173，DSP13.5/24；27MHz约束Fmax30.432MHz，setup/hold违例0。E022 SHA256 64974593B5DEB2F9262E6B074678E77DFA10D7E580B6DE586391EB2E50AEDDCE，归档E:/gaoyun/releases/instrument-E022-20261021。未接触下载器、未写SRAM/Flash；板上E021及CF73备份保留。


## 2026-10-21 E023 Android / FPGA Wi-Fi双向扩展候选
- 用户要求结合题目完成安卓Wi-Fi附加功能；复核高云官方match2026题2扩展描述，明确Wi-Fi并非已实现蓝牙，事件CSV并非音频录音回传。新增docs/wifi-app-E023-20261021.md操作与边界。
- RTL扩展分客户端有界命令解析V/T/E/K/P/Q/L，5秒租约，ESP重启清键，CIPSEND提示符/发送确认超时；85字节实际状态快照含32点最终输出波形。手机键优先于光键，释放恢复光键，编辑/测试模式不进入手机键演奏。保留安全启动和硬件hold。
- 安卓0.2-wifi原生页面通过Wi-Fi专属socket连接ESP，支持四触屏键、多指、四声部重排、三音色、延时、音量、板载键音区、实际状态/波形、最多5000条事件CSV。页面退出断开，3秒无状态断开，FPGA5秒租约释放。保留旧预览/模拟输入页面并澄清历史说明。
- RED记录：新协议/遥测尚未实现时测试编译失败，日志wifi-*-red保留；实现中曾出现Verilog保留字sequence、endelse拼写错误，均修正。ESP模拟测试CR使用八进制转义以与真实AT字节13/10一致，未改实际协议去迎合错误mock。
- 最终30项RTL回归全部通过（20261021-E023-regression.log及191059原始转录）；新增范围/分片命令、85字节遥测、真实AT命令字节与CIPSEND提示/发送/失联租约测试；旧音频、32声部、ADC、光键、OLED、启动测试通过。Java合成测试、协议测试与本地TCP分片接收测试通过，APK签名构建通过。编译器有Java旧目标/弃用API警告，未当作零警告宣称。
- Gowin E023布局布线成功：27MHz约束，Fmax33.632MHz，setup/hold违例0，逻辑10250/20736、寄存器4303/16173、DSP13.5/24。归档E:/gaoyun/releases/instrument-E023-20261021；哈希见docs/wifi-E023-build-manifest.json。
- 未安装手机、未下载SRAM/Flash、未读取硬件；板上E021保持。离线测试不等于真实ESP旧AT固件、安卓界面/多指、Wi-Fi延迟和实机声音已验收。异常发热根因与供电余量尚未解决，不清除deployment_blocked。

## 2026-10-21 E023 Flash实物写入
- 用户明确要求写入Flash，并对全部断电重连及温度正常确认回复ok。只为已构建归档E023增加AuthorizedE023Flash独立固定SHA256入口，默认thermal hold保留；未改OTP、下载器固件或接线。
- SHA256 B1226DD66F187B7A562C62DC88FE4813B9FA3E87BAAD86FCAA21A5BB06F95684复核通过。官方Programmer，GW2A-18C、cable-index1、2.5MHz、operation37、地址0；扫描读到0x0000081B。
- 20261021-192044-instrument-Flash.log明确Program and Verify flash successfully，exit0，31.57秒。扫描日志同时间戳。写入校验成功不等于已完成冷启动和安卓Wi-Fi验收，待用户断电自启动确认；历史热故障根因仍未解决。

## 2026-10-21 仓库入口整理
- 按用户要求提供APK并整理仓库。旧首页仍写早期单音/SRAM状态，已原样移至docs/history/readme-before-E023.md。新首页明确主工程、E023 Flash校验状态、APK、接线、协议、验收边界和目录用途。新增docs/current-release.md固定版本/哈希/回退索引；不把待实测项目标为完成。未移动工程目录或修改硬件。
- 本机gh不在PATH，未创建GitHub Release；使用已跟踪APK文件页提供下载，不宣称已创建Release。

## 2026-10-21 手势V2、赛题映射与开源模型调查
- 用户反馈间歇丢手，要求查仓库/高star适配模型并写新程序。读取赛题审阅与旧run：V1一帧无效清空+3帧重获，官方run过滤靠边小框，属于可能放大掉线的代码因素，尚未证明模型漏检根因。
- 新增k230/pinch_preview_v2.py单文件：新目标0.30/续跟0.18、3稳定帧、弱候选限定已锁定手附近；HOLD旧值<=200ms且valid=0、超时/长帧停顿重获、多手/非法几何无效；去旧边缘宽度过滤，保留框尺寸24x36与边界，掌宽16px。追加raw_boxes/box_reject/age_ms/raw_peak诊断，未换模型、未启UART、未改main/固件/FPGA。
- 测试先缺模块RED；又新增长停顿用例重现FAIL后修复。最终python -m unittest discover -s k230 -p test_pinch*.py，12项通过，日志logs/20261021-k230-v2/unittest.txt。选择器测试确保弱背景框不能首次取得控制、不能遮蔽强框、多强手不随便切换。
- 初版V2（尚未弱候选筛选）板上运行出现4–6原始候选而持续MULTI HAND；已据此收紧取得控制权/空间关联，最终版尚未板测。第一次停止旧程序出现IDE interrupt/soft reboot，第二次初版成功；两次原始日志保留logs/20261021-k230-v2。
- 后续停止初版尝试读取分数时E:/gaoyun/k230_host_probe.py报告RuntimeError: short debug length；COM9仍在但版本请求无回包。一次USBDBG_SYS_RESET已发送，之后仍无回包；921600官方备用速率也无响应。仅针对USB VID1209 PIDABD1的pnputil /restart-device被Access is denied拒绝，未改驱动、未禁用设备、未强制提权。恢复需要实体USB重新连接，未虚构已恢复。
- 正常关闭IDE首次5秒未完成（未强杀），随后自行退出，未用computer-use工具。最终命令启动IDE -auto_connect -auto_run pinch_preview_v2.py，窗口已确认且Responding=True；不等于USB已连接或程序已启动。open_pinch_ide.cmd已改V2，V1保留。
- GitHub API实际查询：ultralytics62713/AGPL3，mediapipe37358/Apache2，PINTO_model_zoo4629/仓库MIT，nncase899/Apache2，k230_canmv109/未识别许可。具体hand-keypoints搜索YOLO11n-pose-hands99/未识别许可。未找到已确认适配此亚博固件且许可明确的高star替代kmodel，未下载新权重。用途/来源/转换条件/验收边界见docs/k230-gesture-v2-models-20261021.md。不把框架stars当模型精度。
- 赛题建议：捏合连续映射表达音量或硬件效果强度作为第三维候选；光键触发、摇杆维持原功能；不把离散换音色当第三表情、不称<=10ms。待实物精度对比和UART/FPGA联调才计完成。仅暂存本任务文件，保留其他日志。

## 2026-10-21 OTG同口供电与通信的再次案例核验
- requests查询官方/第三方README、第三方usb_host.py及GitHub仓库搜索；确认同款Dock USB键盘作者报告同时由VBUS供电并传按键。强调FS/LS、Linux/OHCI及K230协议/功耗差异，并记录原型局限。来源与结论追加docs/k230-fpga-link-20261021.md。
- 本阶段无硬件、驱动或RTL操作；未查到已验证的Dock-K230同线案例，不宣称插线即用。

## 2026-10-21 21:30:39 K230 单源 OTG 接法确认
- 用户确认：Dock 自身 USB 供电，K230 只连接 Dock OTG，没有第二路 USB/5V；用户报告可启动并识别手势。
- 判断：可继续当前供电联调；未测负载瞬态电压、电流及温升，不作长期供电验收。USB 数据 host/协议尚未实现。
- 命令：Get-CimInstance Win32_SerialPort；Get-Process canmvide。结果：COM9 列出，IDE PID 30784；没有打开串口、停止程序或烧写板卡。
- 已按用户授权通知“排查 Tang Primer 20K JTAG下载”，说明上述范围，要求 FPGA/Flash 保持不动。
- V2 最终版板上验证及 main.py 持久安装仍未完成；需暂时将 K230 从 Dock OTG 移接电脑直连 USB 才能下载。

## 2026-10-21 21:33:56 K230 V2 直连上传与板上试运行
- 用户已改为电脑直连；COM9 / VID1209 PIDABD1，固件调试版本0.4.0，MicroPython身份 k230_canmv_yahboom with K230。
- 12项主机测试通过；待安装文件 /sdcard/pinch_preview_v2_pending.py 逐字节回读一致，10474字节，SHA256 ae9593ed7a9e610cd1f121d6f825f03e0797fed995b6e73bad259ab8f94371d2。
- python E:/gaoyun/k230_deploy_v2_host.py trial：实板18秒，GC2093初始化成功，产生TRACK/有效百分比/HOLD/NO HAND；没有摄像头画面与动作的人工对应验收。
- 停止后读调试输出报 RuntimeError: short debug length；等待后固件查询仍空回复。没有执行activate，main.py仍为官方例程入口；已请求用户重插USB恢复。
- FPGA、固件、模型、boot.py及电赛备份均未改动。日志见logs/20261021-k230-v2/。

## 2026-10-21 21:37:13 K230 V2 开机入口安装完成
- 用户重插后COM9恢复，首次停止官方脚本后等待回到REPL，再次身份探测成功。
- 创建并回读旧入口备份 main_before_pinch_v2_20261021.py（119字节）；原电赛备份31805字节保留。
- 安装异常：覆盖rename报OSError:16，直接写main报EPERM。未释放的临时文件句柄经gc.collect后，旧main改名及pending改main成功。随后os.sync报AttributeError（此固件无该API）；后续独立回读验证安装已成功，未重试覆盖。
- 最终 /sdcard/main.py 指向 /sdcard/pinch_preview_v2.py；10474字节，SHA256 ae9593ed7a9e610cd1f121d6f825f03e0797fed995b6e73bad259ab8f94371d2，逐字节与仓库一致。
- 从main入口执行18秒：摄像头初始化、持续PINCH2日志，无运行异常。本轮主要NO HAND/BAD GEOMETRY/MULTI HAND，未取得有效TRACK；上轮试运行有TRACK，不能因此宣称实际手势效果验收通过。待用户观察单手正对镜头效果；真实断电开机尚未验收。
- 结束主机采集时不发送停止命令，板上程序保持运行。FPGA、固件、模型及boot.py未改动。
- 日志：activation.txt、activation-finished.txt、installed-readback.txt、main-launcher-trial.txt。

## 2026-10-21 K230→FPGA手势协议V1仿真候选
- 用户要求无论串口或其他方式先完成协议仿真。使用TDD：Python测试先因缺gesture_protocol模块失败；串行RTL测试先因缺gesture_uart_rx失败。原始日志gesture-python-red/gesture-rtl-red保留。首次调用iverilog未配UCRT PATH未运行；补齐既有工具路径后取得真实RED，不以空输出当通过。
- 新增独立12字节二进制协议、MicroPython兼容编码/解码、CRC16-CCITT-FALSE、字节流解析器和UART包装。版本/范围/保留位/CRC校验，模256序号前向窗口，重复旧包不续租，250ms失联释放、20ms半包超时、低置信度/丢手释放。未直接连接音频或触发音符。
- 开发编译异常：无空格的Verilog十六进制常量紧接问号被词法解析为常量，及UART位置端口个数错误；已分别加空格/改命名端口修复。前者日志gesture-rtl-green保留，最终日志明确通过，未运行失败编译的旧产物。
- 15项Python测试通过（含原跟踪测试，标准CRC29B1及96个单bit损坏拒绝）；31项完整RTL回归通过。串行仿真使用Python生成包，覆盖噪声、CRC、重复/旧包、回绕、版本、越界、保留位、半包、丢手、低置信度、重复流不得续租、超时恢复、坏停止位与重置。附加接收234/发送235时钟bit约0.43%偏差测试通过。
- 评审检查输出仅完整包提交、无效包不刷新租期、解析器内存固定、USB与字节协议分层。当前仿真缩短时间计数，非物理电气/手势总延迟实测。文档docs/k230-gesture-protocol-v1.md注明剩余集成边界。
- 本轮无串口打开、无上电、无引脚修改、无FPGA构建/下载、无K230实板写入。E023 Flash和K230当前开机程序保持；USB主机/CanMV传输接口仍未实现，手势数据尚未接入音频。

## 2026-10-21 23:10:37 K230 USB只读能力探测及RAM端点发送验证
- 用户限定：单USB供电+通信；不增UART，不改FPGA/Flash/固件，先读取描述符再验证真实数据。协议基线d453ae2未改。
- scripts/k230-usb-descriptors.py通过Windows Hub查询IOCTL读取真实描述符：1209:ABD1，当前High-Speed，配置1；CDC控制接口0/数据接口1，81 IN和01 OUT Bulk512，82通知8；接口2 Still Image/MTP。无第二CDC/HID。设备限定描述符配置数0，Other-Speed查询WinError31，FS未验。
- COM9首次打开拒绝访问，确认IDE占用后正常CloseMainWindow退出；随后读取运行时usb.Serial及/dev/ttyGS0。没有混入二进制至USBDBG会话。经真实文本执行确认普通REPL，再进入原生raw REPL有界加载RAM代码。
- 固定参数40包480字节CRC全过；识别无效结果300包3600字节全零且序号回绕通过；用户放手后的完整120包中86个有效，CRC/范围/序号0错误，无效字段全零。实际有效手势发送约7.49Hz，不是稳定20Hz；仅1个有效包置信度>=60。
- 重开COM并改115200/8N1得到40包480字节CRC全过（合成测试）。最初采样标记处理漏掉无前导换行的标记，已修复并离线复核原始捕获；没有据此改写设备。
- 中间friendly REPL长源码输入未执行；改用raw REPL分块。有手300包目标一轮24秒超时，仅189包未结束，明确不计为完整通过。失败原始捕获全部保留。
- 21项Python测试通过；主机验证用独立binascii.crc_hqx，按17字节分片输入字节流解析；新流解析和新鲜度映射先红后绿测试。编译检查通过。最终调度sleep避免负数的小改动仅经静态检查，未重复实板测试，实测数据对应此前等价正常路径。
- 没有USB总线控制抓包；Windows串口逻辑参数已知，EP0最小SET_LINE_CODING/CONTROL_LINE_STATE序列只能给候选映射，未冒充逐请求验证。USB bus reset/FS/FPGA host未验。
- 恢复既有main屏幕预览：回读main、V2、boot、电赛和旧入口备份、两模型SHA256，详见契约。初始7秒窗口不足以等模型哈希及推理初始化，随后被动9秒读到33行PINCH2含TRACK，无Traceback，确认运行恢复；未写SD任何文件。
- 文档docs/k230-usb-interface-contract-20261021.md；原始描述符、CDC二进制捕获、API输出、接收校验、测试记录在logs/20261021-k230-usb/。没有持久部署USB发送，FPGA及Flash全程不动。
# 2026-10-21 USB HS host prototype (offline only)

- Added independent K230 CDC host, captured-descriptor fake device, four packet-level tests and RTL gesture/UART diagnostic. Four USB tests pass (113.6s); actual parser/report test passes. External guh/LUNA commits pinned in usb_host/README.md; licenses retained.
- Earlier simulation failures (EnumView handling, interface-class type, enum assertion) retained in logs/20261021-usb-cdc-{first,second,third}.log. Shared fixture race was resolved by running RTL after the host suite. RESETB polarity caught and fixed before hardware use.
- Real USB3317 I/O constraints exposed timing failures masked by clock-only builds. Pipeline reduces setup failures from139 to9; latest remains setup9/hold17, worst setup -6.312ns. Inverted generated-clock experiment was rejected by Gowin and reverted. No constraint waiver applied.
- This is NOT a deployable E024 instrument image. No programmer/serial/USB device access, no SRAM or Flash writes this phase. E023 remains unchanged. Detailed evidence and next gates: docs/k230-usb-host-probe-20261021.md.

## 2026-10-21 用户接入 FPGA：只读 JTAG 连接检查

- 用户确认可开始；K230 保持未连接。Windows 0403:6010 A/B 均 OK，无残留 programmer/openFPGALoader 进程。
- 官方 Programmer 在2.5MHz只读扫描，15秒进程超时保护，0.59秒成功找到1个设备，ID 0x0000081B。该ID不能区分GW2A/GW2AR，也不能证明USB PHY或所有功能正常。
- 未打开串口，未写SRAM/Flash。USB主机候选仍有时序违例，禁止部署；E023未改。原始日志：logs/20261021-usb-host-readonly-scan.log。
## 2026-10-22 USB HS 主机时序修复及授权 SRAM 诊断

- 用户要求直接修复，且在下载前确认“核心板不烫，K230未接”。保持Flash与默认热故障hold不变，仅做固定E024独立诊断SRAM试验。
- PLL相位/UTMI显式EOP缓冲/ULPI命令译码优化后，最终真实I/O约束setup0/hold0，余量1.481/0.325ns。315度PLL输出对应的PHY输出采样使用setup2/hold1配对周期约束；输入、组合DIR输出、内部路径没有多周期放宽。详见docs/k230-usb-host-timing-fix-20261022.md。
- 7项回归120.582秒通过，另外UART周期健康/PLL失锁复位RTL通过；高云官方rPLL模型周期16.667ns、相位14.585ns、high8.334ns。完整总线等价测试先发现寄存器优先级错误，修正后通过；全部失败证据保留。
- SRAM操作index2，2.5MHz，两次各6.41秒，退出0并读回E024，但均有User code mismatch警告，不记作无警告校验通过，不曾执行位流回读验证。最终哈希7B763C07E3DCDD738B7781AB0D2F9F2706E1192DC1A46450FC6F17B91B2687B5。
- COM13只读，DTR/RTS关闭，未发送字节；清缓存新窗口3秒99字节，11帧精确匹配空闲A600000000000000A6。中间缓存采集含旧数据且帧头/XOR可能混淆，计数不作健康证明；最终日志ready-uart-fresh为准。
- K230仍未连接，硬件枚举/CDC/手势未验证。诊断版暂不发声，E023 Flash未写，掉电或RCFG会恢复E023。没有宣称过去的发热根因已排除。

## 2026-10-22 K230 USB发送候选准备（仅主机文件）
- 根据既有USB联调目标和FPGA侧“只准备/检查”同步，读取f3a1e2f接口约定；没有打开串口、执行K230脚本、写SD卡或下载任何硬件。
- 新增usb_gesture_sender.py及单文件构建器、未安装的启动入口示例。候选在build/k230/，7619字节，SHA256 18da9ffff3506edfdf45b7dda3d6f6f955c45deb1daa7289bf3666972774df8d。
- 原始检测分数<0.60发valid=0及零参数，绝不按四舍五入放行；过期/HOLD等无效也清零。沿用协议及既有映射，不改FPGA60门限。
- 新候选静默Python输出、无探针标记，部分写入/EAGAIN/超时处理，失败停止发送并静默停驻。原生C诊断可能绕过静默流，IOBase兼容性、线程、重连和常驻运行未板测，未声称20Hz或联调完成。
- 新增6项测试先出现缺模块红测，完成实现后全套27项通过；单文件可离线编译及非main加载。原始结果logs/20261022-k230-sender/。
- 重要运行前提：单USB换线会断电，RAM发送器不能跨换线保存；当前原main仍是文本预览。下一步需按单独部署阶段先电脑验包、备份并验证开机入口，之后才能换Dock实测。本阶段未执行这些动作。
- 其他聊天正在修改usb_host文件及硬件日志；本提交不包含那些文件。详情docs/k230-usb-sender-candidate-20261022.md。

## 2026-10-22 K230 UART候选准备（未部署）
- 按用户在FPGA聊天中“先写用串口的程序、计划gpio、回去插线”的授权，仅准备主机文件；未访问或写入K230、FPGA、Android或Flash。
- 确认亚博标准板EXPORT IO9为TX1/UART1_TXD，IO10为RX1；候选仅复用IO9，115200 8N1，数据加GND，OTG继续供电。具体IO9信号电压未获得原理图或实测确认，不能以3V3电源脚说明替代。
- 新增UART候选、单文件构建器、未安装的启动入口示例、4项测试。延用12字节CRC协议、原始置信度>=0.60和过期/HOLD清零；保留LCD/模型。目标20Hz未板测，不宣称已达到。
- 命令：python -m unittest discover -s k230 -p "test_*.py" -v；31项通过。构建及py_compile通过，原始日志logs/20261022-k230-uart/。
- 候选7743字节，SHA256 6c5a3ea5cddc2a4369124c142e6ad05f6848bc8f1aa132eb2097a569bd8272d7。备份、分阶段验证、恢复步骤见docs/k230-uart-sender-20261022.md。


## 2026-10-22 17:18:20 +08:00 E025 UART手势与安卓0.3完整工程候选（未部署）
- 用户授权先完成UART工程、规划GPIO并协调K230聊天，同时完成APK；当前只做文件、仿真与构建，没有打开串口或下载硬件。
- K230聊天按授权完成TX-only UART候选7a4af32，31项主机测试通过；EXPORT IO9/TX1→FPGA M14，GND→GND，IO10/5V/3V3不互连，OTG保留既有供电。IO9输出电平尚无实测/明确板级原理图，未把3.3V电源脚当作TX证据。FPGA M14经PNR确认Bank1/LVCMOS33，PMOD1背面外排第3信号孔，不占用OLED/ESP。
- instrument_extension_top启用gesture_uart_rx；1152008N1，234周期/bit@27MHz；复用CRC/序号/60%门限/250ms失联释放。手势不产生音符，只控制捏合音量和高度明亮度，丢手恢复本地。保留八路/四键/包络/复音/32声部/OLED/Wi-Fi。
- APK0.3新增手势状态、序号、置信度、捏合/高度条、帮助及CSV字段；兼容E023 85字节S帧，E025为96字节G帧，FPGA CIPSEND长度同步。没有新增Wi-Fi音频或声称赛题所有扩展已完成。
- 测试先红后绿：新表达模块缺失、Java手势字段缺失；新旧TCP双帧测试发现旧84字符上限漏改，修复到95后通过。保留失败日志。一次Python源码读取用默认GBK遇到UnicodeDecodeError，后续显式UTF-8重做并重新构建。一次PowerShell未引用Icarus -P参数导致编译失败，引用完整参数后通过，未涉及硬件。
- 命令：instrument_io/run_tests.ps1；gw_sh.exe instrument_io/build_extension_candidate.tcl；mobile-companion/build.ps1；python -m unittest discover -s mobile-companion/tests -v。最终34组RTL、Java协议/TCP/合成、4项Python测试通过；234/235周期实际波特率偏差回归通过。
- Gowin 27MHz约束setup/hold违例0，Fmax27.927MHz。接收器未使用TX输出及已有模32索引截断警告保留，无编译错误；不把时序报告当作实板验证。
- 码流用户码E025，本机E:/gaoyun/releases/instrument-E025-20261022/instrument-E025.fs；APK版本与旧0.2归档在mobile-companion/apk/。哈希与状态logs/20261022-E025-manifest.json；原始测试、构建、引脚和时序报告为同前缀日志。
- 自查代码的协议长度、边界、丢手、无自主音符、GPIO占用和应用兼容性；未写Flash/SRAM、未安装手机或K230程序。E023 Flash/旧归档未改，历史热故障根因未解除。下一步是IO电平核实、K230开机部署、用户接线后SRAM联调；不能称整机完成验收。


## 2026-10-22 K230实物丝印与PDF核对（只读资料）
- 用户要求按板上丝印定位。使用PDF技能读取并渲染本地FPIOA引脚分配.pdf第2–3页，对照标准版说明书第3图。首次控制台打印遇GBK无法编码NBSP，改UTF-8后读取成功；无硬件操作。
- 明确双排12针IO32/IO33是UART3 TX/RX；当前UART候选使用四针EXPORT的IO9/UART1_TXD，不能混用。补充双排丝印表和EXPORT定位到E025接线文档；不改程序、不下载。UART3控制台占用和IO9实测电平仍未确认。


## 2026-10-22 M14物理定位更正（用户要求图示）
- 重新逐项核对官方Dock背面照片docs/images/dock-back-official.png，并读取Dock-3713原理图M14/M15对应IOT40A/B。发现之前PMOD1排针坐标表有误：M14实际为靠板中心内排第3孔，外排第3孔为M15。之前“外排第3孔”表述撤回；用户尚未报告连接，已立即告知先不要按旧位置接。
- 正确背面视角、USB在下：外排P11/R11/M15/L13/GND/3V3，内排T12/T11/M14/M13/GND/3V3。OLED T11内排第2、ESP T12内排第1，原表这两个位置也同步更正，信号球位不变。
- 新建确定坐标的示意图images/m14-location-diagram.png，未修改官方原图。更正E025接线文档、旧OLED/ESP坐标和manifest位置，通知K230聊天。码流CST仍为M14，FS/APK内容未变；没有设备操作。


## 2026-10-22T18:58:33+08:00 E025接线后连接检查
- 用户报告USB和两根串口线已接。只读Get-PnpDevice -PresentOnly查询：当前本电脑未列出0403:6010、1209:ABD1或COM13；不能下载或读取板上状态，未开串口/烧录。
- 读取最新18977e4位置更正：M14是PMOD1内排第3信号孔，外排对应M15；已明确向用户纠正此前口误并请求核对。K230 UART发送程序是否已部署尚待确认。IO9电平没有新增实测证据。
- 等待用户确认准确接点及USB-JTAG连至本机，再继续；未更改GPIO、电源、驱动或Flash。原始摘要logs/20261022-E025-connection-check.json。


## 2026-10-22 K230 UART persistent script deployment

- COM9 / VID1209:PIDABD1 identified; original main SHA256 cc8e17d9e95a03340a4fbcc895f0740cab4d1b051227b749e002da92ca2b5375. Original models and V2 source hashes checked. No firmware image or FPGA Flash written.
- Backed up original entry to `/sdcard/main_before_uart_E025_20261022_190536.py` and host `logs/20261022-k230-uart-deploy/main-original.py`; main replaced with UART launcher, read back verified SHA256 511777bd5dc930001bd6d938c0511a6ed94a5e5197955350743fb462ae78235b. This FAT implementation cannot rename over existing main; backup verified before remove+rename (not an atomic overwrite).
- Actual CanMV firmware rejected TX-only mux with `UART(1) rx not configured, see machine.FPIOA`. Fixed UART1 RX mux on IO10 as input (ie=1,oe=0), physically unwired; TX remains IO9, 115200 8N1. Regression test checks both mux directions. Initial candidate saved on SD as `uart_gesture_sender_before_rx_fix.py`.
- Retained errors: os.sync unavailable, FAT rename EEXIST, first trial camera already initialized, RX mux assertion, stage retry ENOENT after successful rename. Final candidate bytes were hash-checked before rename; installed main successfully executed final candidate. Camera ownership cleared with machine.reset; software reset landed at REPL, so it does NOT establish autonomous cold-boot success.
- Final stored-main runtime: 14 UART reports; accepted packet count 21 ->216, 64 PINCH2 lines, no Traceback/stopped. Reports valid=0/confidence=0: no valid hand demonstrated. Accepted writes are not physical line capture or FPGA CRC acceptance. Rate during observed AI workload below target20Hz.
- FPGA USB-JTAG absent, E025 FPGA download and end-to-end gesture test still pending; old FPGA Flash unchanged. Next: verify K230 power-on startup, then connect Dock USB-JTAG and test E025 in SRAM before Flash.


## 2026-10-22 E025 supervised SRAM installation

User connected FPGA only and requested continuing. FTDI A/B enumerated OK; scan found one 0x0000081B device. No residual programmer process. Archived E025 bitstream SHA256 D74ADA653E4F3BF3D6B4713E69FBD3908A398E3421B5F20A0813510F96177C4E verified before operation2 SRAM program at2.5MHz. Bounded CLI returned exit0,100%,usercode E025,status0x6020; retained User code mismatch warning. Independent operation73 read User Code E025; operation74 read status0x6020. Flash unchanged. Thermal incident unresolved; no hold file edits. Existing fixed E021/E023 helper does not cover E025; directly invoked official CLI under current explicit supervised SRAM authorization with fixed hash and bounded timeout. Physical heartbeat/silence/temperature confirmation requested; K230 disconnected, no physical gesture integration claimed. Evidence logs/20261022-E025-{device-scan,SRAM,read-73,read-74}*.log.


## 2026-10-22 User reports intermittent pinch validity with skeleton retained

User reports hand skeleton persists while pinch value is usually invalid. Static code confirms V2 acquisition .30 / tracking .18, but PacketState applies raw score >=.60 and FPGA parser independently requires60. Thus visible tracking and control validity differ by design; sample freshness150ms adds an independent release condition. No live K230 USB console is present, so dominant runtime rejection reason remains unmeasured. No threshold changed or confidence altered. Requested K230 chat diagnose visible raw score/rejection reason and bounded hysteresis policy before coordinating both endpoints.

## 2026-10-22 UART同步逐帧候选修正（离线）
- 按用户在FPGA侧要求恢复单机识别行为的同步，UART仅每次tracker.update后同步发送，不再启用后台线程或150ms旧状态重复发送；真实TRACK/有效几何/原始分数>=.18，获取.30由V2负责。HOLD/无效立即清零。保留IO10输入兼容，不改V2慢帧和屏幕状态。
- 先测试出现缺少FrameSender红测；实现后python -m unittest discover -s k230 -p "test_*.py" -v全套32项通过，构建及py_compile通过。日志logs/20261022-k230-uart-sync/。
- 新候选6319字节，SHA256 de7aefb6406658549538fe1d7f51b903aa48451dc729356eb245d564d7a5ff0f。详见docs/k230-uart-sync-20261022.md。FPGA18门限需由对方协调，本轮未改FPGA、Android或设备；未声称实机修复通过。


## 2026-10-22 Pinch regression repair: synchronous UART + E026 receiver

Replaced installed K230 sender after inspecting existing SHA e88ea108a08d80d27c64377d0a92eacf9a189d4d62c723fb9abf039846615e91, backed old sender to /sdcard/uart_gesture_sender_before_sync_fix.py. New6319byte sender readback SHA de7aefb6406658549538fe1d7f51b903aa48451dc729356eb245d564d7a5ff0f. main.py unchanged; V2/models unchanged. No background thread, each real tracker update sends once; genuine tracker TRACK/valid with raw>=.18 only, preserving original .30 acquisition/.18 retention. Invalid/HOLD releases immediately, no confidence substitution. UART IO10 remains input/unwired.

Initial explicit re-execution after reset hit camera already initialized (auto-entry had started); retained error capture. Subsequent machine.reset plus passive capture proved saved entry runs:19 reports, accepted1->358, no traceback/stopped. Observed invalid NO HAND/MULTI HAND/BAD GEOMETRY, loop samples37..91ms. No valid-hand continuity result claimed. Soft-reset startup observed; physical power-cycle still pending.

FPGA E026 compiled to local releases/instrument-E026-20261022/instrument-E026.fs, SHA6b73a937b3b2cc03060b6b64b143b13854d9723abaf7ee554832bdde3fceb2a7. Extension top sets receiver floor18; generic parser/default60 retained for other designs. Lease250ms/CRC/replay/range checks unchanged. 34 RTL groups passed; additional real serial baud234/235 test verifies17 rejection/18 acceptance and59 acceptance in matched configuration. Fmax27.116MHz vs27MHz constraint, setup/hold TNS0 endpoints0; narrow margin recorded. Build warnings retained. FPGA not yet deployed, user asked to reconnect it. Full physical gesture validation remains pending. Flash unchanged.


## 2026-10-22 E026 SRAM installed after user reconnect

User confirmed requested reconnect and no abnormal heat. Verified fixed archived SHA6b73a937b3b2cc03060b6b64b143b13854d9723abaf7ee554832bdde3fceb2a7, FTDI A/B OK and singleJTAG ID0x0000081B. Official CLI operation2 at2.5MHz completed100%,exit0,usercodeE026,status0x6020; retained User code mismatch warning. Independent op73 readsE026 and op74 reads0x6020. Flash unchanged; thermal hold remains. Both K230 synchronous sender and FPGA18 receiver now installed; user physical continuous-pinch/audio/lost-hand test requested, not yet confirmed. Evidence logs/20261022-E026-{scan,SRAM,read-73,read-74}*.log.


## 2026-10-22 User accepts E026 gesture repair; reports old APK frame error

User confirms requested E026 pinch continuity/audio/release test works. Reports one phone with old APK now rejects frames, another phone reportedly using same APK works. E026 sends G95-character status line (96 includingLF), while pre0.3 client expects S84-character line. Current0.3 parser supports both; old-client incompatibility explains frame errors but does not by itself explain phone-to-phone difference. Installed APK hashes/versions and actual TCP stream on phones not inspected; do not attribute to phone hardware or cache without evidence. Recommend current archived0.3 APK, then reproduce if still failing.


## 2026-10-22 Competition closeout and Android0.4 usability

User confirms E026 gesture and current APK work. Re-read official topic2, reviewed FPGA-Music and tiny-synth project descriptions (no external code copied). Updated requirement gap checklist and copy-ready truthful introduction. Android0.4 launches WifiActivity directly, clear connection action labels, named presets, inline guide, local preview moved to auxiliary tools. Java synth/protocol/TCP tests, APK build/sign verify passed; phone UI not inspected. E026/Flash unchanged. Artifacts docs/competition-closeout-20261022.md, docs/work-introduction-20261022.md, apk0.4, logs/20261022-app-0.4-*.


## 2026-10-23 Gesture inactive after power-cycle: old Flash E023 running

User reports camera works but no FPGA expression change. FTDI A/B present. Read-only official op73 reports E023, proving current FPGA lacks E026 UART integration: E026 was only installed in volatile SRAM. Attempted fixed-hash E026 SRAM restoration at2.5MHz; programmer stalled6%, terminated after25s bounded wait. No successful restoration claimed, Flash untouched. Requested all-board USB power cycle before retry; do not test audio meanwhile. Retained logs/20261023-gesture-read-usercode* and 20261023-E026-SRAM-restore*. Root of loss across power-cycle is version persistence, not demonstrated camera/model failure.


## 2026-10-23 E026 SRAM recovery after reconnect

User completed requested all-board reconnect. Fixed archived hash verified, scan ID0x0000081B. Official2.5MHz operation2 SRAM retry completed100% in6.46s,exit0,usercodeE026,status0x6020; retained usercode mismatch warning. Independent op73 E026/op74 0x6020 confirm version/configuration. Flash unchanged. Requested physical pinch/audio/no-abnormal-heat confirmation before persistence; previous6% failed attempt retained separately. Evidence logs/20261023-E026-{retry-scan,SRAM-retry,retry-read-73,retry-read-74}*.log.


## 2026-10-23 E026 Flash program and verify success

After successful SRAM restoration user confirmed gesture/audio normal and explicitly requested Flash. No UART opened since all-board reconnect. Fixed E026 SHA6b73a937b3b2cc03060b6b64b143b13854d9723abaf7ee554832bdde3fceb2a7 verified, scan ID0x0000081B. Official GW2A-18C cable1 2.5MHz operation37 GAO-Bridge, SPI address0x000000, completed100%,exit0, explicit Program and Verify flash successfully,28.4s. No OTP/download-cable firmware operation. Historical thermal hold not altered; scoped user authorization used directly with fixed image/bounded timeout. Requested complete USB power-cycle, no further SRAM downloads, local+gesture functional check and subsequent read-only boot usercode. Flash content verified; cold boot still pending. Logs/20261023-E026-{flash-scan,Flash}*.log.


## 2026-10-23 E026 Flash cold-boot acceptance

User completed requested full power-cycle without SRAM download and confirmed local optical/joystick, K230 pinch control and no abnormal heat. Subsequent read-only official op73 returnsE026 and op74 0x6020; no configuration writes this turn. E026 Flash programming, verification, cold-boot identity and user functional acceptance now complete. Evidence logs/20261023-E026-coldboot-read-{73,74}*.log. Short functional acceptance does not provide a measured thermal-root-cause result.


## 2026-10-23 Wi-Fi SSID missing diagnosis

User reports missing network after E026 cold-boot acceptance. Read-only COM13 capture:12 decoded samples, armed=true ADC_OK=true optical_online=true play mode, keys released. Thus not merely unarmed startup. PC WLAN scan did not list FPGA-Instrument in current results (snapshot only, no inference of ESP damage). OLED already exposes ready ON vs AT command index, RX Y/N and timeout !; requested exact display and ESP LED state before power-cycle or wiring changes. No FPGA/ESP writes. Raw serial capture logs/20261023-wifi-state.bin retained; surrounding WLAN identifiers kept local, not uploaded.


## 2026-10-23 ESP display AT0 RX:Y

User observes AT0 RX:Y and ESP LED on. This proves RX activity was latched, not a valid AT reply, correct baud or healthy supply. RTL resets command_index to0 on any configuration timeout, so AT0 snapshot cannot distinguish initial handshake failure from later-command retry. Requested ten-second stage progression and timeout ! observation before selecting recovery; no hardware writes.


## 2026-10-23 User-selected piano APK and ESP diagnosis stopped

User attributed missing SSID to RCFG(S4) reconfiguration without matched peripheral restart, explicitly requested no protocol/handshake modifications. Diagnosis stopped; previous turn only read sources, no diagnostic bitstream built or deployed. Received FPGA乐器.apk.1,90921bytes,SHA25602c07734556b00bf38946c2c3c0bddd64414ad485387ce017d0155b731985ea7; archived exact bytes as instrument-user-preferred-20261023.apk. aapt identifies com.fpga.instrument,versionCode3/versionName1.2-piano; apksigner verify succeeds, certSHA256bcbf5d4a3669f9140dd9af56df329bcb162c680669c3c28c5a826cce975678df. Original nonASCII-path aapt call failed, retried on ASCII archive; JAVA_HOME configured for verifier. User selected as preferred; matching sources absent, previous cn.myfines.instrument builds preserved. Updated root/mobile README and current release to actual accepted E026 Flash status. No hardware writes.


### 2026-10-28 E031互联网网页控制与Flash部署

用户要求电脑不连接ESP热点，已恢复并保持ahu.dot1x。ESP连接用户提供的2.4GHz热点。AT实读版本1.2.0.0/SDK1.5.4.1；TLS未互通。配置生成器曾未真正切换TCP，新增失败测试复现并修复。最终TCP/80主动轮询版上传96字节真实遥测；公网HTTPS网页API设置V40/T01/M00001000，实录261.5Hz，停音后RMS约-50.82dBFS。

核对ID0x0000081B、GW2A-18C和哈希F3443A81EBA8FE8B4CD6E920F81E358E96B77D327D41E17894837A58EB5B15D6后，官方Programmer --operation_index 37 --spiaddr 0x000000 --frequency 2.5MHz成功写入校验Flash，27.92秒；独立op73 E031、op74 6020。用户断电重启并启用，未重新下载SRAM；重新上线并回报网页T02设置，冷启动控制通过。原始日志与验收JSON见firmware/e028-extension/docs/e031-regression，部署说明见e031-internet-control.md。

无bulk erase、OTP或下载器/ESP固件更新。Wi-Fi密码、令牌、配置ROM、真实FS仅保存在E:/gaoyun/private/esp-web，不入Git。当前为临时隧道/本机中转，设备HTTP非端到端加密。


## 2026-10-28 E031 strict acceptance round
Read official topic2 again; WebMCP and the same authenticated relay backend drove actual DAC/Realtek recordings. Four independent notes/release, 32-frequency no-clip lower-level repeat, four timbres, bend, volume/brightness/vibrato, effects and envelope release were measured. Bend interval precision and delay-effect clipping failed; physical latency/display/offline/mobile items remain unverified. No FPGA/Flash write or computer Wi-Fi switch. User reported no overheating and no physical-input activity. Full evidence and limits: firmware/e028-extension/docs/e031-acceptance/README.md. Raw audio stays private with SHA256 index. Final idle -59.95dBFS; remote controls released.

## 2026-10-28 K230-covered retest
User covered K230 and confirmed no physical activity/no overheating. Recorded gesture_active=0 and remote_active=1 throughout. Bend261.5/296/227.5/261.5Hz repeated; delay clipping/strong zero-input residual repeated. Old failed cases also had inactive gesture. No RTL/Flash change; controls stopped and effects disabled. Evidence: firmware/e028-extension/docs/e031-retest-k230-covered/README.md.


## 2026-10-28 E032 candidate audio corrections
Read tiny-synth and Freeverb designs; no external source copied. Negative-feedback signedness reproduced (negative8000 incorrectly became positive29768); added failing regression, fixed signed arithmetic and hardware RAM scrub. Exponential pitch lookup reduces sweep error43.5358 to0.044854cents in simulation. Twelve tests pass; Gowin candidate builds at27MHz with setup/hold TNS0,15/46BSRAM,8.5/24DSP. No SRAM/Flash download; physical board remains E031. Evidence firmware/e028-extension/docs/e032-regression/. Private FS never uploaded.
