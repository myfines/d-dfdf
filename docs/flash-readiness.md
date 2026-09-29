# Primer 20K Dock 外部 Flash 固化前置条件

状态：2026-09-29 尚未满足；**没有写入或擦除 Flash**。用户已明确澄清没有固定 JTAG 速度上限，要求是不损坏板卡；现用 SRAM 音频码流已验证 S0–S3 发声。本文是后续可执行的技术门槛，不把当前 CLI 的 `-f` 当成安全命令。

## 现有证据

1. 板载 Flash 有内容：之前只保留了前 64 KiB 的本地备份 `E:/gaoyun/tools/tang20k-flash-first64k.bin`，整片尚无可靠备份；不能保证覆盖后可恢复出厂内容。
2. 同一 Flash 先后返回过 JEDEC `0B 40 17` 与 `0B 40 0F`，且 FTDI 曾出现无法打开/复位失败。这两种结果不能当作稳定容量识别。
3. 当前 openFPGALoader v1.1.1 的 `Gowin::prepare_flash_access()` 内调用 `setClkFreq(10000000)`。即使命令行传 `--freq 100000`，Flash 访问仍会主动调高 JTAG 时钟；本板工具输出实际约 6 MHz。速度本身不再是授权障碍，但此时实测读取不可靠。源码在本机 `E:/gaoyun/tools/openfpgaloader/gowin-v1.1.1.cpp` 的该函数内，可对照[上游源码](https://github.com/trabucayre/openFPGALoader/blob/v1.1.1/src/gowin.cpp)。
4. [openFPGALoader 的 Gowin 说明](https://trabucayre.github.io/openFPGALoader/vendors/gowin.html)把直接 `-f` 的列表限定在其他板卡；Primer 20K 的外部 SPI Flash 要检查 BSCAN 路径 `--external-flash`，不能按普通内置 Flash 操作。
5. [高云 Tcl 文档](https://cdn.gowinsemi.com.cn/SUG1220E.pdf)支持 `-use_sspi_as_gpio`。新音频码流仅启用 SSPI/T10；JTAG、MSPI、RECONFIG_N 保持专用。但这并不能替代掉电启动测试。

### 2026-09-29 的实测否决证据

- 旧 64 KiB 备份：`E:/gaoyun/tools/tang20k-flash-first64k.bin`，SHA256 `EF09DAE103583F2F9AF766C6683679E8566663997619E862852A72C9A747BCFA`。
- 同一板本轮只读导出 A：`E:/gaoyun/tools/flash-backup/20260929/sample64k-a.bin`，SHA256 `3306FF6D3DB9E2442CF4D0363DE36469A46BA89440BC14A4D3DAC4457CF8C3E5`。
- 不写入、不改线后再次只读导出 B：`E:/gaoyun/tools/flash-backup/20260929/sample64k-b.bin`，SHA256 `DCE65A79ECCA5A7033722A2CCE49F5390BA8DC0E26A5D529A6FB035C39694BF0`。
- 三份均 65,536 字节。旧版与 A 相差 268 字节；A 与 B 相差 **277 字节、321 个比特**；旧版与 B 相差 242 字节。两次新读分别都返回 JEDEC `0B 40 17` 和进程 exit 0，但内容不一致；“读取完成”不能视为可靠备份。
- 两次读取都清除了 SRAM 运行配置；随后已重新下载 SHA256 `2D155BB754EC8C6238C57320220F5EE24E029907742F575C61FB7C61D5B4162E` 的音频码流到 SRAM，工具 `DONE / exit 0`。本轮未尝试整片备份或写 Flash。原始标准输出/错误与差异报告在 `logs/20260929-flash-read64k*`。

## 要达到的顺序

1. 先定位当前读数失真的原因。可在本地使用可验证源码的低速 Flash 工具、可靠的厂商路径或独立 3.3 V SPI 读出器作只读交叉验证；任何工具都须记录版本、实际时钟和传输错误。仅调高或调低命令行 `--freq` 不保证 Flash 路径时钟会跟着改变。
2. 在不写 Flash 的前提下，连续识别同一 JEDEC ID/容量，并让**至少两次独立读取的相同 64 KiB 逐字节一致**。若又出现 USB 异常或内容差异，立即停止，不升级到整片备份。
3. 在 64 KiB 重复读取可靠之后，对识别出的 **完整容量**做两次独立二进制导出，记录每次命令、请求/实际频率、长度、SHA256，并逐字节比较。导出副作用可能清除当前 SRAM 音频配置，事后按已核对的哈希重载 SRAM。原始备份保留本地，不入 Git 仓库；仓库只记录哈希和存放位置。
4. 备份可靠后，确认待写 `.fs` 的芯片/版本、JTAG 和 MSPI 保留专用、启动 SPI 地址及大小与外部 Flash 相容。先定恢复方法，再选择**外部 Flash**写入并启用读取校验；禁止整片盲擦。
5. 写入成功并校验后，由用户按实际接线完成一次断电上电测试，确认四键音频能自动恢复；再测试 RCFG 行为。所有结果与不可恢复的异常均逐步记录。

满足前四项之前，继续仅用 SRAM。原 Flash 很可能有出厂演示内容；按 RCFG 后 LED 仍有反应不等于音频设计仍在 SRAM，具体运行版本未回读确认。

高云独立 Programmer 支持外部 Flash 写入/校验，但当前命令行未确认可靠地导出整片原始数据，且 A 通道现为 openFPGALoader 所需的 WinUSB 驱动。不能为了绕开备份门槛而直接执行 `operation_index 9/13`。
