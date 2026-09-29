# Primer 20K Dock 外部 Flash 固化前置条件

状态：2026-09-29 尚未满足；**没有写入或擦除 Flash**。现用 SRAM 音频码流已验证 S0–S3 发声。本文是后续可执行的技术门槛，不把当前 CLI 的 `-f` 当成安全命令。

## 现有证据

1. 板载 Flash 有内容：之前只保留了前 64 KiB 的本地备份 `E:/gaoyun/tools/tang20k-flash-first64k.bin`，整片尚无可靠备份；不能保证覆盖后可恢复出厂内容。
2. 同一 Flash 先后返回过 JEDEC `0B 40 17` 与 `0B 40 0F`，且 FTDI 曾出现无法打开/复位失败。这两种结果不能当作稳定容量识别。
3. 当前 openFPGALoader v1.1.1 的 `Gowin::prepare_flash_access()` 内调用 `setClkFreq(10000000)`。即使命令行传 `--freq 100000`，Flash 访问仍会主动调高 JTAG 时钟，超过用户约定的 2.5 MHz。源码在本机 `E:/gaoyun/tools/openfpgaloader/gowin-v1.1.1.cpp` 的该函数内，可对照[上游源码](https://github.com/trabucayre/openFPGALoader/blob/v1.1.1/src/gowin.cpp)。
4. [openFPGALoader 的 Gowin 说明](https://trabucayre.github.io/openFPGALoader/vendors/gowin.html)把直接 `-f` 的列表限定在其他板卡；Primer 20K 的外部 SPI Flash 要检查 BSCAN 路径 `--external-flash`，不能按普通内置 Flash 操作。
5. [高云 Tcl 文档](https://cdn.gowinsemi.com.cn/SUG1220E.pdf)支持 `-use_sspi_as_gpio`。新音频码流仅启用 SSPI/T10；JTAG、MSPI、RECONFIG_N 保持专用。但这并不能替代掉电启动测试。

## 要达到的顺序

1. 在本地**独立构建或选用**能够把 Flash 全路径 JTAG 请求频率限制在 ≤2.5 MHz 的工具；先与原版比较只读 JTAG ID、SRAM 下载行为。不能仅改命令行 `--freq`，必须检查内部强制频率。工具、源码版本、改动与 SHA256 入日志。
2. 在不写 Flash 的前提下，连续两次识别同一 JEDEC ID 与容量。若再次不一致、USB 描述符异常或读传输出错，停止。
3. 对识别出的 **完整容量**做两次独立二进制导出，记录每次命令、请求/实际频率、长度、SHA256，并逐字节比较。导出副作用可能清除当前 SRAM 音频配置，事后按已核对的哈希重载 SRAM。原始备份保留本地，不入 Git 仓库；仓库只记录哈希和存放位置。
4. 备份可靠后，确认待写 `.fs` 的芯片/版本、JTAG 和 MSPI 保留专用、启动 SPI 地址及大小与外部 Flash 相容。先定恢复方法，再选择**外部 Flash**写入并启用读取校验；禁止整片盲擦。
5. 写入成功并校验后，由用户按实际接线完成一次断电上电测试，确认四键音频能自动恢复；再测试 RCFG 行为。所有结果与不可恢复的异常均逐步记录。

满足前四项之前，继续仅用 SRAM。原 Flash 很可能有出厂演示内容；按 RCFG 后 LED 仍有反应不等于音频设计仍在 SRAM，具体运行版本未回读确认。

高云独立 Programmer 支持外部 Flash 写入/校验，但当前命令行未确认可靠地导出整片原始数据，且 A 通道现为 openFPGALoader 所需的 WinUSB 驱动。不能为了绕开备份门槛而直接执行 `operation_index 9/13`。
