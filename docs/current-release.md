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
