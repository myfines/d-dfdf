# Primer 20K Dock 外部 Flash 固化前置条件

状态：2026-09-30 用户已明确授权将当前音频码流写入外置 Flash 并验证，目标是证明 Flash 烧录流程可用；没有固定 JTAG 速度上限，硬件底线是不损坏板卡。两份只读备份仍不一致，因此没有可靠的整片恢复镜像。仅执行码流起始地址附近的扇区擦写，禁止 bulk erase；若写入校验失败，停止，不重复擦写。

## 现有证据

1. 板载 Flash 有内容：之前只保留了前 64 KiB 的本地备份 `E:/gaoyun/tools/tang20k-flash-first64k.bin`，整片尚无可靠备份；不能保证覆盖后可恢复出厂内容。
2. 同一 Flash 先后返回过 JEDEC `0B 40 17` 与 `0B 40 0F`，且 FTDI 曾出现无法打开/复位失败。这两种结果不能当作稳定容量识别。
3. 原 openFPGALoader v1.1.1 的 `Gowin::prepare_flash_access()` 内调用 `setClkFreq(10000000)`，命令行 `--freq 100000` 不约束此阶段。低频诊断版将其改为 2.5 MHz；工具报告实际约 2.0 MHz，但两次 64 KiB 读取仍有 268 字节差异，见 `logs/20260930-lowclock-read-*`。速度本身不是用户限制，读数差异仍需诚实记录。补丁见 `docs/openfpgaloader-v1.1.1-low-flash-clock.patch`。
4. [openFPGALoader 的 Gowin 说明](https://trabucayre.github.io/openFPGALoader/vendors/gowin.html)把直接 `-f` 的列表限定在其他板卡；Primer 20K 的外部 SPI Flash 要检查 BSCAN 路径 `--external-flash`，不能按普通内置 Flash 操作。
5. [高云 Tcl 文档](https://cdn.gowinsemi.com.cn/SUG1220E.pdf)支持 `-use_sspi_as_gpio`。新音频码流仅启用 SSPI/T10；JTAG、MSPI、RECONFIG_N 保持专用。但这并不能替代掉电启动测试。

### 重复读取异常

- 旧 64 KiB 备份：`E:/gaoyun/tools/tang20k-flash-first64k.bin`，SHA256 `EF09DAE103583F2F9AF766C6683679E8566663997619E862852A72C9A747BCFA`。
- 同一板本轮只读导出 A：`E:/gaoyun/tools/flash-backup/20260929/sample64k-a.bin`，SHA256 `3306FF6D3DB9E2442CF4D0363DE36469A46BA89440BC14A4D3DAC4457CF8C3E5`。
- 不写入、不改线后再次只读导出 B：`E:/gaoyun/tools/flash-backup/20260929/sample64k-b.bin`，SHA256 `DCE65A79ECCA5A7033722A2CCE49F5390BA8DC0E26A5D529A6FB035C39694BF0`。
- 三份均 65,536 字节。旧版与 A 相差 268 字节；A 与 B 相差 **277 字节、321 个比特**；旧版与 B 相差 242 字节。两次新读分别都返回 JEDEC `0B 40 17` 和进程 exit 0，但内容不一致；“读取完成”不能视为可靠备份。
- 两次读取都清除了 SRAM 运行配置；随后已重新下载 SHA256 `2D155BB754EC8C6238C57320220F5EE24E029907742F575C61FB7C61D5B4162E` 的音频码流到 SRAM，工具 `DONE / exit 0`。本轮未尝试整片备份或写 Flash。原始标准输出/错误与差异报告在 `logs/20260929-flash-read64k*`。

- 2026-09-30 以同一源码的低频诊断版重复读取，ID 仍为 `0x81B`、Flash ID `0B 40 17`，两次均 65,536 字节且 exit 0；但 A/B 相差 268 字节、316 比特，SHA256 分别为 `f9192ee7ed6fe4356429ba9b6599eec8c5a126f527e6703ba274500bed07f721` 与 `0ecc5d47d16a6d5f34fbc6dd7d939726f53bdb1c255d66d0e29d5f923ea7a34a`。实际 JTAG 频率 2.0 MHz。不能称为可靠备份。
- 官方 Sipeed Primer 20K 资料标注板载 NOR Flash 32 Mbit（4 MiB）；本次 .fs 为 Gowin ASCII 位流，码流数据按 openFPGALoader 解析约 577,178 字节（文本文件 4,617,942 字节），目标起始地址 0。按 64 KiB 擦除块向上取整，预计擦除 589,824 字节（0x00000–0x8FFFF），远小于板载标称容量。文件 SHA256 `2D155BB754EC8C6238C57320220F5EE24E029907742F575C61FB7C61D5B4162E`，器件 GW2A-LV18PG256C8/I7。SecurityBit=ON 会阻止配置数据回读；外部 Flash 写入校验仍需看工具实际校验结果，不能用 FPGA SRAM 回读代替。

## 要达到的顺序

1. 用户已授权本次以当前音频码流尝试外部 Flash 写入并验证。限定地址 0，使用明确标注外置 Flash 的 BSCAN 路径，启用校验，不发出 bulk erase 命令；若设备/容量/范围检查不通过或保护位阻止写入，立即停止。
2. 写后以 Flash 数据逐字节校验结果判断命令是否成功。因为此前只读结果不一致，单独的进度 100% 或 exit 0 不够；如校验失败，记日志并停止重试，重新加载 SRAM 音频码流。
3. 若写入和校验通过，再由用户物理断电重上电，确认配置从 Flash 启动及 S0–S3 发声。RCFG 行为单独记录。不要将掉电启动前的 SRAM 发声当成 Flash 成功证据。

当前原 Flash 的完整内容没有可靠备份；写入会覆盖地址 0 起约 0.56 MiB 的旧配置区域，之后无法凭当前导出保证恢复原样。其他区域不会被本命令主动擦除。按 RCFG 后 LED 仍有反应不等于音频仍在 SRAM。

高云 Programmer CLI 的 operation 13 是 exFlash erase/program/verify in bscan；开源工具则在 Gowin 外部 Flash 实现中执行相同的编程和读回比较。本次使用已从源码编译并验证 USB 枚举的低频 openFPGALoader 诊断版，具体操作与结果见 `docs/operations.md` 和对应 logs。
