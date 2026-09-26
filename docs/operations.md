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
