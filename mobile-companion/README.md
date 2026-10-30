> 2026-10-30：App0.12已补齐颤音、ADSR回读、效果器/OLED/32声部入口及在线文本曲谱下载，兼容E047；未手机实机验收。[操作和逐步验收](../docs/e047-app012-guide.md)。以下旧版本状态为历史。

# 当前推荐：FPGA乐器 1.2-piano（用户提供）

[下载推荐APK](apk/instrument-user-preferred-20261023.apk) · [身份与哈希](apk/preferred-release.json)

2026-10-23用户指定此版本作为更合适的演奏应用。包名 `com.fpga.instrument`，versionCode3，APK签名校验通过。它与仓库原伴侣应用 `cn.myfines.instrument` 包名不同，属于独立安装，不覆盖原应用。

本次仅收到APK，未找到同包名对应源码；本目录旧Java工程仍构建“乐器伴侣”，不能描述为推荐APK的可复现源码。0.3/0.4和原debug下载均保留，推荐入口以本页及根README为准。

用户报告Wi-Fi异常与按RCFG(S4)单独重配置时外设状态不同步有关；这是用户观察，尚无原始串口根因证据。按用户决定不修改ESP协议或增加握手。本轮不修改、不下载FPGA/ESP/K230程序。

以下为历史版本说明：

---

# 当前候选：0.3 UART手势演奏台（E025）

新增K230串口手势状态、两条参数条和CSV字段，兼容E023旧帧。功能、接线和验收见 [E025说明](../docs/k230-uart-E025-20261022.md)。APK离线构建不代表手机运行或整机验收通过。

# 当前新增：E023 Wi-Fi 演奏台（0.2-wifi）

新增真实 FPGA 双向控制页面，配套 E023 固件；支持四键、音量、音色、延时、状态波形和事件 CSV。操作、协议、题目边界及尚未实测事项见 [E023说明](../docs/wifi-app-E023-20261021.md)。APK 已构建不等于手机安装与 FPGA 联调已通过。旧手机本地预览和输入监听页面保留，以下为其历史说明；“仍缺接收链路”只描述旧原型，不描述新增 E023。

---

# 手机乐器伴侣（独立附加功能）

手机：本轮连接 Redmi K30 / Android 12（API 31）。不改 FPGA RTL、引脚或 Flash。

## 已实现的两条路径

1. **触屏演奏预览与控制命令**：8键/最多4复音，三预设、弯音、明亮度、紧急静音。声音在手机合成，明确不作为比赛 FPGA 实时合成证据。启用开发桥开关后发 JSON 控制事件，开发桥只记录，不驱动 FPGA。
2. **外接输入转手机扬声器**：AudioRecord → 音量缩放 → AudioTrack。仅允许耳麦外部输入或 USB 音频输入；拒绝内置麦克风，检查实际输入/输出路由。切页、后台、外设拔除自动停止。监听默认关，增益默认15%、最高60%。48kHz单声道，实际延迟未测，不保证≤10ms。

手机只有3.5mm口不等于具备立体声线路输入。普通TRS双公AUX接在手机上通常是输出对输出，不能作为本功能的输入。PCM5102A线电平需要正确CTIA耳麦输入转接及衰减/隔直与接口确认，或具有线路输入的USB音频设备。没有FPGA在场，本轮不接线、不做模拟输入验收。不能把电脑Realtek采集成功直接类推手机。

真实手机控制FPGA仍缺接收链路：当前板上固件以传感器为输入，不能因为手机发出JSON就控制FPGA。后续需选定USB/串口/网络桥，修改并验证FPGA命令接收、失联释放、音色/参数映射；本轮先验证界面、手机声音和命令协议。

## 操作

- 打开“FPGA 乐器伴侣”，触屏按住音符发声、松开释放；可多指，最多4声部。
- 切换三预设；滑动弯音/明亮度。最后一项是拨弦，按住也会衰减。
- 红外/摇杆硬件不在场，手机预览仅模拟其交互。紧急静音立即结束本地声音。
- “手机扬声器”页刷新设备；只有外部输入被系统识别后才允许开始。首次按开始申请麦克风权限，授权后需再次主动开始，不自动录音。
- 无外部输入时应显示拒绝提示；这是预期保护，不是故障。连接实际设备后仍需验证手机厂商路由是否支持同时外部输入和扬声器输出。

## 构建与开发桥

无需Gradle或额外第三方Android库：JDK17+、Android SDK build-tools36.0.0、platform android-37.0。

```powershell
./mobile-companion/build.ps1 -Jdk E:/gaoyun/tools/mobile-jdk/<jdk目录>
adb install -r mobile-companion/build/instrument-companion.apk
adb shell am start -n cn.myfines.instrument/.MainActivity
python -m unittest discover -s mobile-companion/tests -v
python mobile-companion/bridge.py --log logs/phone-events.jsonl
adb reverse tcp:8765 tcp:8765
```

桥仅绑定电脑127.0.0.1，手机USB开发连接通过adb reverse访问。手机端勾选开发桥，地址保留 `http://127.0.0.1:8765/event`。服务回复 `fpga_connected:false`，界面也明确FPGA未连接。退出开发调试时 `adb reverse --remove tcp:8765` 并结束服务。

协议v1：`note_on/note_off`，key为0..7；`preset`值0..2；`bend`值-2..2（半音）；`brightness`值0..1；`all_off`。另带手机单调时钟，不与电脑墙钟比较作精确延迟。桥验证字段/范围，限制请求长度，不写硬件。

签名为本地调试证书，密钥只保存在本机且不入Git。APK在build目录，源代码与构建脚本入Git。此预览不是正式发布包，安卓设备运行验证记录见docs/operations.md。

参考：
- Android耳麦接口：https://source.android.com/docs/core/interaction/accessories/headset/jack-headset-spec
- AudioRecord：https://developer.android.com/reference/android/media/AudioRecord
- 音频路由：https://developer.android.com/reference/android/media/AudioRouting

### 本次安装状态（2026-10-18）
构建和核心/协议测试通过。小米拒绝ADB安装（INSTALL_FAILED_USER_RESTRICTED）；已将APK复制到手机“下载/FPGA-Instrument-Companion.apk”，请从文件管理器手动安装。手机端运行和声音尚未验收。
仓库下载副本：`apk/instrument-companion-debug.apk`。手机系统若提示“允许此来源安装应用”，需用户自行确认正常安装；不绕过安装限制。
