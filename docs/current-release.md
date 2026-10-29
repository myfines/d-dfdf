# 当前发布与部署状态

更新：2026-10-29。**Flash保留E031；当前SRAM为E033**，临时E03A自动音频探针已结束并恢复E033，独立读回E033/0x6020。E033尚未写Flash；断电后恢复E031。完整功能版恢复后需重新启用外设，探针测试不会替代启用操作。

本轮通过弯音、延迟干声增益及效果尾音的部分实录验证；低电平四音和弦无近满幅样本，32声部仍有少量近满幅录音样本待定位。完整E033时序余量很小，OLED/输入启用/网络及端到端延迟仍待验收。[详细证据](../firmware/e028-extension/docs/e033-regression/README.md)。

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
