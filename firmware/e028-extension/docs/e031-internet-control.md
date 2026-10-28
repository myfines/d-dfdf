# E031 浏览器经互联网控制乐器

用户要求：电脑保持原网络，不连接ESP热点；华为服务器已关闭。当前实现为浏览器HTTPS → 本机鉴权中转/Cloudflare Tunnel → ESP主动HTTP轮询 → FPGA既有合成器。ESP连接用户指定的2.4GHz热点，电脑仍为ahu.dot1x。

## 保密与范围

Wi-Fi配置、设备令牌、网页会话令牌及配置ROM均在本机E:/gaoyun/private/esp-web，禁止提交Git。实际FS含联网配置，因此同样只保存在该私有目录；公开源码附构建工具与空配置方式。

当前ESP实读版本AT 1.2.0.0（2016-07-01）、SDK1.5.4.1。TLS连接返回ERROR/0,CLOSED，未能建立；只能判定该固件与当前入口没有成功TLS互通，尚未逐项隔离证书/SNI/密码套件。为验证功能，设备段使用普通HTTP，浏览器段仍为HTTPS；不可声称端到端加密。此接口只控制合成器参数，不能访问文件、烧录、执行系统命令。

## 使用方式

- 热点保持开启，Dock及PCM沿既有供电方式。电脑网络不改。
- 上电后按住S1+S2，按下松开摇杆，再松开两键，仅启用一次。
- 打开本机保存的私人网页入口；页面显示FPGA ONLINE后再测试音符。公开根页面不含控制凭据，不能直接操作。
- 页面提供八键和弦、四音色、音量、亮度、颤音、弯音、效果、OLED切页、曲目、32声部示范。声音仍由PCM输出。
- 控制超时约5秒时，中转返回L00释放远程控制；链路完全中断时另有FPGA约5秒租约释放。STOP清除网页音符/曲目/示范，不保证遮挡中的实体光键静音。
- 这是经互联网的演示控制，不能把网页往返延迟当成赛题要求的FPGA内部音频延迟。

## 运行依赖

本机web_relay.py及cloudflared进程需保持运行。当前使用临时隧道，重建隧道可能更换地址并要求重建联网配置；不是永久托管。华为机器无需开机。稳定域名/常驻服务器是后续部署项。

## 测试与已发生问题

- 新状态机仿真验证配置、建连命令、持续POST、遥测和完成标记；原10项回归不改变合成逻辑。
- 中转4项测试覆盖离线拒绝、合法指令、失联释放、非法掩码及chunked请求不污染复用连接。
- 配置生成器曾错误地保留SSL/443，已用失败测试复现并修复；新增测试核对TCP/80生成字节，避免把未实际切换的码流算成HTTP测试。
- 网页公开入口200，未鉴权状态接口401，鉴权状态接口200。实际结果见下。
- 排障候选只下载SRAM，公网闭环成功后才写入Flash。

## 最终验证

- 真实设备上传96字节遥测；电脑保持ahu.dot1x。
- 公网HTTPS网页API设置V40、T01、M00001000：遥测确认音量40、音色1；Realtek实际录到261.5Hz、峰值0.5470、RMS0.1890。初次波形快照早于音符应用而为零，不把它当发音证据。
- 停止后实录RMS约-50.82dBFS，峰值0.02155。录音受麦克风输入/环境影响，不是端到端延迟或全部音色失真测量。
- 最终FS SHA256 F3443A81EBA8FE8B4CD6E920F81E358E96B77D327D41E17894837A58EB5B15D6；Fmax30.813MHz，27MHz约束，setup/hold TNS均0。
- GAO-Bridge operation37、SPI起始0、2.5MHz，27.92秒，明确Program and Verify flash successfully；独立读回E031/6020。未执行bulk erase、OTP或ESP固件更新。
- 用户确认断电重启并启用，未重新下载SRAM；再次收到96字节遥测，公网接口切换T02后板载回报音色2，冷启动联网与控制通过。证据见e031-regression/cold-boot-test.json。

## 自审与使用限制

合成器、电平、引脚约束、安全启用沿用E029；core默认关闭新联网路径，仅cloud top启用。USB串口输出改为ESP接收流的只读诊断镜像，不通过该串口发送控制。公开页面不含控制令牌；设备令牌和浏览器令牌分离。配置ROM和真实FS含私有联网配置，只保留本机。浏览器HTTPS、设备HTTP，不声称端到端加密。中转依赖本机进程与临时隧道，关闭本机或更换隧道地址会影响远程功能，尚未部署到永久服务器。

## WebMCP automation (2026-10-28)
The HTTPS page registers four tools through document.modelContext (legacy navigator fallback): instrument_status, instrument_notes, instrument_parameter, instrument_stop. Agents discover current names through the browser WebMCP capability; generated name suffixes change on reload. No screenshot, selector, pointer hold or Wi-Fi switching is necessary. Authentication remains in the page session, never in tool arguments/results.

Notes use semitone indexes 0..31; C4=12, E4=16, G4=19. Replace the complete held set, use [] to release, and always call instrument_stop after testing. Parameters use decimal values and validate individual limits. Results distinguish relay acceptance from FPGA application; telemetry returned immediately can predate the command. The page must remain active for its existing heartbeat; loss of focus stops notes and relay lease expiration releases control.

Verified on hardware: tools discovered; T01 accepted and later telemetry indicated timbre1; WebMCP chord [12,16,19] recorded on Realtek input at 261.5/329.5/392Hz. Peak0.9932 is near the recording input full scale; lower test volume/gain before stronger mixed signals. First combined invocation produced an invocation error; isolated retry succeeded. Stop/L00 succeeded. See docs/e031-regression/webmcp-test.json. FPGA Flash unchanged.
