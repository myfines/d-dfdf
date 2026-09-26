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
