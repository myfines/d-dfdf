# 现有模块电子乐器工程

2026-10-12：完整功能版已通过十三组自动测试、32基频数字分析及Gowin构建，已用官方GAO-Bridge写入Flash并明确校验成功。用户确认完整断电后心跳、空闲静音和四键发声正常；只读JTAG读到UserCode `0x7799`、Status `0x6020`，确认启动的是新版。

## 功能

- 四个直接按键声部，各有独立相位与ADSR，不使用按键掩码选择器。
- 三组音符覆盖十二半音，正常/低八度切换。
- 三角合成音、正弦合成音、锯齿拨弦音三预设；摇杆控制弯音和适用预设的波形亮度。
- 使用现有按键和摇杆SW组合，可现场编辑A/D/S/R；参数在下一音符触发时锁存。
- 43.69ms短延迟效果，可旁路，混音预留幅度余量。
- 专门32声部测试模式，129Hz起、31Hz间隔至1090Hz。32个独立相位/包络分时共享算术单元，约97个27MHz周期完成一帧，适配576周期的音频帧预算。
- 模式切换淡出到零再淡入、LED模式指示、UART可读状态、ADC失效中性回退。
- 音频全部由HDL逐样本生成；正弦表是数学单周期，不是音乐录音。

普通键盘演奏仍为4复音；32声部用于容量/频谱测试，不宣称四键独立演奏32音符或有32条物理流水线。

## 操作与接线

详见 [用户操作说明](../docs/instrument-user-guide.md)。PCM使用USB-C供电，排针+3.3V不接，与Dock共地。RCFG不是演奏键。无需扩展按键或新增模块。

## 复现

- 仿真：`pwsh -NoProfile -File E:/gaoyun/d-dfdf/instrument_io/run_tests.ps1`。
- 数字频谱：`python E:/gaoyun/d-dfdf/scripts/verify_spectrum32.py E:/gaoyun/tools/smoke/spectrum32.csv --output E:/gaoyun/d-dfdf/logs/spectrum32-repeat.json`。
- 构建：IDE `gw_sh.exe E:/gaoyun/d-dfdf/instrument_io/build.tcl`。源码工具路径按本机E:/gaoyun配置，迁移时需统一修改。
- 烧录：`scripts/program-instrument.ps1 -Mode SRAM`；Flash需关闭串口、重新插拔USB后使用 `-Mode Flash -UsbReconnected`。脚本检查SHA256、JTAG、退出码与明确校验成功，采用官方operation37，无bulk erase/OTP。
- 读状态：`python scripts/read-instrument-status.py`；会打开COM13，之后若再烧录必须关闭并重新拔插USB。`--self-test`只检查解析，不访问板卡。

目标码流SHA256：`436F86922855BD02BA6A10E8649C8483C04D627FE12B7AA00F5C90263617381A`。主路径 `E:/gaoyun/projects/instrument_io/instrument_io/impl/pnr/instrument_io.fs`。审查/时序/资源/仿真/烧录和冷启动标识见logs的complete系列文件。

## 鉴定边界

输出16bit、46.875kHz I2S。模拟输出的32谱峰、<=10ms端到端延迟、真实音质及新组合操作的逐项实物验收仍待测量；数字频谱检查不是DAC测量。没有压力传感、第三个独立连续表情维度、手机App或蓝牙功能。编辑参数不跨断电保存，换音色会加载其预设包络。

稳定旧版本备份：`E:/gaoyun/releases/instrument-verified-3CB9.fs`，SHA256 `9DA141FDAF59E24E1FE10ED352389D8B3D8CE2DC0B1283A2B4A3B317FB99E561`。历史排查过程保留在operations.md，不用旧记录判断当前Flash状态。
