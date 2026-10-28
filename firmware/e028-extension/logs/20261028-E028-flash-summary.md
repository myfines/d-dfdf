# E028 烧录记录（2026-10-28）

## 板卡与码流核对

- 下载器：FTDI `USB\VID_0403&PID_6010`，`FactoryAIOT_Pro`，A/B 两个接口均已枚举。
- JTAG 扫描：`GW2A-18C(0x0000081B)`，1 个器件。
- 码流：`dist/firmware/instrument_e028.fs`
- SHA256：`E7DC8D6A33C65894620F609D047582248FCFB6F6F4A0E95614ECE0436CF11278`
- 文件内 UserCode：`0xE028`
- 电缆：cable-index 1，2.5 MHz。

## 1. SRAM 验证（可逆）

命令：

```text
programmer_cli --device GW2A-18C --cable-index 1 --frequency 2.5MHz \
  --operation_index 2 --fsFile dist/firmware/instrument_e028.fs
```

结果：

```text
Programming 100%
User Code is: 0x0000E028
Status Code is: 0x00006020
Finished. Cost 6.39 s
exit 0
```

工具同时打印 `User code mismatch`（E027 时代已存在的已知告警），但独立只读回读：

```text
op73: User Code 0x0000E028, exit 0
op74: Status 0x00006020, exit 0
```

日志：

- `logs/20261028-E028-SRAM.log`
- `logs/20261028-E028-SRAM-read73.log`
- `logs/20261028-E028-SRAM-read74.log`

## 2. 外部 Flash 写入（持久化）

命令：

```text
programmer_cli --device GW2A-18C --cable-index 1 --frequency 2.5MHz \
  --operation_index 37 --spiaddr 0x000000 \
  --fsFile dist/firmware/instrument_e028.fs
```

结果：

```text
Gao-Bridge User Code: 0x0000B8DF
Status Code: 0x00006020
Try to program spi-flash: 0xB4017
Erasing 222 sectors from 0x000000 to 0x0de000
Programming Flash 100%
Program and Verify flash successfully.
Finished. Cost 27.73 s
exit 0
```

说明：

- 使用 operation 37（exFlash Erase,Program,Verify thru GAO-Bridge）。
- **没有使用 bulk erase**（operation 10/14），没有 OTP、下载器固件或驱动修改。
- operation 37 自带 Program and Verify，工具明确返回 `Program and Verify flash successfully`。
- 另尝试独立 operation 15 只读校验，因速度过慢在 13% 主动终止；该次不计作完整独立校验，最终以 operation 37 的内建 Verify 为准。

日志：

- `logs/20261028-E028-Flash.log`
- `logs/20261028-E028-Flash-verify15.log`（未完成，仅存档）

## 3. 待确认

- 需要**整板 USB 断电 10 秒后重新上电**，让 FPGA 从外部 Flash 冷启动。
- 冷启动后只读 `op73/op74` 应分别为 `0xE028` / `0x6020`。
- 需实物确认：OLED 是否亮、四颗 LED、按键有声、PCM 输出、无异常发热。
- 在冷启动确认前，不把本次写成“冷启动验收通过”。
