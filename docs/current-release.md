> 最新逐项结论：[E045赛题对照](competition-final-crosscheck-20261029.md) · [使用教程](e045-user-guide.md) · [延迟口径/测量](latency-measurement-20261029.md) · [最后拍摄清单](e045-video-guide.md)。E045仍为SRAM、Flash E039，冷启动由用户在最终固化后执行。

# 最新状态：E045 SRAM，Flash仍E039

本轮已完成RAW音频与板上集成诊断，修复重连复活旧颤音。完整状态、结论与未验收项见[E045交付证据](e045-delivery-evidence.md)。以下为历史记录。

---

# 当前：E041 SRAM，Flash仍E039；APK0.10直连扩展待实机

2026-10-29：E041已下载SRAM，独立读回E041/6020。修复手机连接屏蔽捏合；亮度和弯音仅收到显式命令才接管，断开/到期恢复本地。27MHz时序通过，捏合65536组合及完整RTL回归通过。手机实际捏合/Bass反馈尚待，未写Flash。

[APK0.10](../mobile-companion/apk/instrument-companion-0.10-e041-direct.apk)保留原版自绘主界面，新增设置内直连W/U/C、配置回读和WAV导出。热点录音RTL原先被公网开关禁用，E042已补齐并通过33项RTL、27MHz时序，尚未下载，板卡保留E041供用户测试；**E041不能据此宣称扩展已联通**。手机实体操作与文件导出待验收。[E041与APK证据](../firmware/e028-extension/docs/e041-regression/README.md) · [E042候选](../firmware/e028-extension/docs/e042-regression/README.md)。

---

# 历史：新增候选与APK修复（当时未改板卡）

APK0.9修复原版界面收到32点帧后的越界，新增实际View绘制路径测试。E040候选提高Bass保持电平，RTL测试与时序通过，未下载。当前Flash仍为E039，冷启动结果待实体确认。[严格赛题对照](requirements-e040-audit.md) · [修复证据](../firmware/e028-extension/docs/e040-regression/README.md)。

---

# 当前状态：E039 热点直连版 Flash 已写入校验，待冷启动确认

2026-10-29：用户要求恢复 ESP 本地热点、以后使用探针调试。E039 保留 E038 音频修正，关闭公网中继，恢复 `FPGA-Instrument` 热点和 TCP 9000。ESP-01S 自身固件未重刷。官方写入和校验通过；写后立即版本读回0000，冷启动与实际热点尚未确认，不重复擦写。[证据](../firmware/e028-extension/docs/e039-regression/README.md)。

搭配 [0.8 原版界面 APK](../mobile-companion/apk/instrument-companion-0.8-reference-ui.apk)，地址192.168.4.1:9000，热点密码fpga-demo-2026。电脑保持原网络，不加入设备热点。以后使用临时SRAM探针，结束恢复已验证正式版本。

---

## 历史状态

# 当前试听版本（E038 SRAM）

E038已下载SRAM、独立读回E038/6020；Flash仍是已冷启动验证的E037，断电会恢复E037。E038修正力度范围、手势亮度截断回绕，并取消捏合隐式叠加颤音/振幅调制；试听结果尚待确认。[证据](../firmware/e028-extension/docs/e038-regression/README.md)。这不是重新设计全部音色或限幅器。

---

# 当前部署状态（2026-10-29 E037）

E037 Flash已经官方GAO-Bridge写入并校验成功（28.46秒），并在用户完全断电重连后、未下载SRAM的情况下独立读回E037/6020，Flash自启动已确认。写后立即0000的记录仍保留，不能据此认定启动失败或芯片损坏。详见[部署证据](../firmware/e028-extension/docs/e037-regression/README.md)与flash-result.json。此前E035/E031说明为历史记录，不再代表当前Flash内容。

E037新增32位置映射、64事件下载曲谱、约0.7秒数字短录音分块回传、设备配置回读、未启用心跳与Android伴侣0.5。真实公网与实体手机运行、实体延迟/视觉等严格验收尚未完成，不能宣称所有赛题项目通过。[操作手册](e037-user-guide.md)。

---

# 当前发布与部署状态

更新：2026-10-29。**Flash保留E031；当前SRAM为E035**，临时E03A自动音频探针已结束并恢复后已更新E035，独立读回E035/0x6020。E035尚未写Flash；断电后恢复E031。完整功能版恢复后需重新启用外设，探针测试不会替代启用操作。

E034修正混音提前截断、单声部Q16包络增益溢出和帧中弯音变化；17项RTL回归通过，27MHz时序最小余量0.428ns。隔离探针录音中弯音与效果释放正常，四音及降低电平的32音均无近满幅样本；不能据此宣称全音量不限幅。OLED/输入启用/网络及端到端延迟仍待验收。[详细证据](../firmware/e028-extension/docs/e034-regression/README.md)。

E035新增逐声部可调ADSR、带校验配置命令和WebMCP操作入口；21项RTL测试通过，已下载SRAM，实际联网设置与DAC包络曲线尚待验收。[E035证据](../firmware/e028-extension/docs/e035-regression/README.md)。

## 历史归档（以下不是当前部署版本）


更新：2026-10-23。FPGA E026 Flash已完成写入校验和断电自启动验收，用户确认光键、摇杆和K230捏合功能正常；只读用户码E026、状态0x6020。证据：logs/20261023-E026-Flash.log及20261023-E026-coldboot-read-*.log。

FPGA SHA256：`6b73a937b3b2cc03060b6b64b143b13854d9723abaf7ee554832bdde3fceb2a7`。本机归档：E:/gaoyun/releases/instrument-E026-20261022/instrument-E026.fs。

Android当前推荐：[FPGA乐器1.2-piano](../mobile-companion/apk/instrument-user-preferred-20261023.apk)，用户提供，包名com.fpga.instrument，versionCode3。签名验证通过，[SHA256及来源](../mobile-companion/apk/preferred-release.json)。它不是本目录旧Java工程的构建产物，对应源码未提供；不覆盖cn.myfines.instrument原伴侣应用。

本轮不修改ESP初始化/握手逻辑，未执行任何硬件写入。RCFG(S4)重配置与全系统断电不是相同操作；用户选择保留现有行为，Wi-Fi故障的串口原始根因未实测证实。

以下为旧版本归档记录，不代表当前部署：

---

# 当前发布与部署状态

更新：2026-10-21；主版本E023，配套Android0.2-wifi。候选标签candidate-E023-20261021，源码提交1a90c3c，Flash部署记录fb2809e。

| 项目 | 身份与状态 |
|---|---|
| FPGA | E023，已写入并校验Flash；冷启动与新功能尚待确认 |
| Android | 0.2-wifi / versionCode2，已构建签名；手机安装及联调待确认 |
| 离线验证 | 30项RTL测试、Java协议/TCP/合成测试通过 |
| 时序 | 27MHz约束，Fmax33.632MHz，setup/hold违例0 |
| APK | [下载入口](../mobile-companion/apk/instrument-companion-debug.apk) |
| 操作 | [Wi-Fi说明](wifi-app-E023-20261021.md) |
| 原始写入证据 | [Flash日志](../logs/20261021-192044-instrument-Flash.log) |

哈希（SHA256）：

```
FPGA E023: B1226DD66F187B7A562C62DC88FE4813B9FA3E87BAAD86FCAA21A5BB06F95684
Android APK: 6E2FB6A3E9DBD48C9E8652441A250729B9FD60884636118A66EEED895D9086CB
```

本机归档目录：`E:/gaoyun/releases/instrument-E023-20261021/`。构建原始清单的hardware_deployed=false描述构建时状态，后续实物部署以本页和操作记录为准。

回退归档：E021在`E:/gaoyun/releases/instrument-E021-20261021/`，已知SHA256 `6D89D33520697199C489A78BA5FEB17C31F13B1D3CC9D1A175C7B2718CC42C5D`；E022为OLED优化离线候选，不当作已验证Flash回退版。回退写入也需确认设备与版本，不自动执行。

私密仓库下载APK需GitHub访问权限；可从APK文件页选择Download raw file。不要使用未知重新打包的APK，安装前可核对以上哈希。
