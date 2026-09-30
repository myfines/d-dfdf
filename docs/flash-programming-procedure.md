# Tang Primer 20K Dock 外置 Flash 烧录实测流程

状态：2026-09-30 已完成功能验证。高云官方 Programmer 将四键音频码流写到外置 Flash；用户将全板供电拔掉 10 秒再上电、**没有重新下载 SRAM**，确认 S0–S3 都有声；按 RCFG 后四键仍有声。最后只读 JTAG 扫描仍识别一个 ID `0x0000081B` 的设备。

## 本次使用的文件和设备

- 板卡：Sipeed Tang Primer 20K + Dock，USB-JTAG 直连电脑。FPGA 实物资料为 `GW2A-LV18PG256C8/I7`；高云软件选择 `GW2A-18C`。
- JTAG A/MI_00 和 B/MI_01 当前都用 FTDI `FTDIBUS` 驱动，Windows 驱动包 `oem178.inf`，两者 ProblemCode 0。此前 A 用 WinUSB 时高云工具未能正确扫描；驱动切换记录见 `docs/operations.md`。
- 工具：`E:/gaoyun/tools/gowin/Gowin_V1.9.11.03_Education/Gowin_V1.9.11.03_Education_x64/Programmer/bin/programmer_cli.exe`，V1.9.11.03 Education build 2536。
- 码流：`E:/gaoyun/projects/audio_keys/audio_keys/impl/pnr/audio_keys.fs`，SHA256 `2D155BB754EC8C6238C57320220F5EE24E029907742F575C61FB7C61D5B4162E`。文件头为 GW2A-18C、`JTAGAsRegularIO: OFF`、`MultiBootSPIAddr: 0x00000000`、`Encryption: OFF`。用户此前已在 SRAM 下逐键试听通过。
- Flash JEDEC ID：`0x0B4017`。先前开源工具对原 Flash 的 64 KiB 重复读取不一致，因此**没有可靠的旧出厂内容整片备份**。

## 命令和确认点

在 PowerShell 中设置路径、核对码流和只读扫描：

```powershell
$cli = 'E:\gaoyun\tools\gowin\Gowin_V1.9.11.03_Education\Gowin_V1.9.11.03_Education_x64\Programmer\bin\programmer_cli.exe'
$fs = 'E:\gaoyun\projects\audio_keys\audio_keys\impl\pnr\audio_keys.fs'
(Get-FileHash $fs -Algorithm SHA256).Hash
& $cli --cable-index 1 --frequency 2.5MHz --scan
```

本次只读扫描返回 **1 device(s) found**、ID `0x0000081B`。若扫描未得到这一个 ID，不执行写入。

写入命令只选 **operation 13：exFlash Erase,Program,Verify in bscan**；`14` 是整片 Bulk Erase，未使用：

```powershell
& $cli --device GW2A-18C --cable-index 1 --frequency 2.5MHz `
  --operation_index 13 --fsFile $fs --spiaddr 0x000000
```

本次返回 `Programming 100%`、`SPI end of address: 0x08CE00`、`Finished!`、退出码 0，耗时 321.31 秒，原始输出见 `logs/20260930-gowin-exflash-bscan-program-verify.out.txt`。命令日志只显示 Programming 进度，没有单列的逐字节 Verifying 阶段；因此我们还用下面的掉电及重配置结果验证实际启动。

写入后用户拔掉板卡所有供电 USB，等待 10 秒，重新插入此前可正常识别的电脑 USB 口。期间**没有执行 SRAM 下载**。上电后 S0–S3 均能从耳机听到音；再按一次丝印 `RCFG` 并逐键测试，四键仍有声。随后只读扫描 JTAG，仍识别唯一 ID `0x0000081B`，见 `logs/20260930-post-flash-boot-jtag-scan.out.txt`。这证明当前音频程序能从 Flash 自动启动并在 RCFG 后恢复，同时保留 JTAG 入口。

## 范围和后续注意

- 写入地址从 0 开始，工具报告的数据结束地址为 `0x08CE00`；本次没有执行整片 Bulk Erase、OTP 或下载器固件更新。原厂 Flash 内容无法凭当前不一致的旧读取文件完整恢复。
- 写入后没有再单独运行 operation 15 的整片字节比较。写入前该只读操作在 44% 报 `SPI Verify failed`、退出码 67，确认旧 Flash 内容与目标码流不符。若以后需要逐字节归档验证，可在不改写 Flash 的前提下运行 operation 15，并记录全部输出；这不是本次功能性自启动结论的依据。
- 之前使用 openFPGALoader v1.1.1 的两次 Flash 写入中途停住；[上游同型号问题报告](https://github.com/trabucayre/openFPGALoader/issues/573)也描述过相似现象。当前可复现的成功路径是 **FTDI 驱动 A + 高云官方 Programmer 操作 13**。
