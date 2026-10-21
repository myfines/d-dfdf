# 亚博 K230 当前固件 USB 接口契约与实测边界

2026-10-21；应用协议基线 `d453ae2`，见 [12字节协议](k230-gesture-protocol-v1.md)。本次没有修改 FPGA、Flash、USB 配置、固件、模型、SD 卡文件或开机入口。测试程序只在 MicroPython RAM 内执行。

**结论：当前固件可在独占的普通 CDC/REPL 会话中，由 `usb.Serial('/dev/ttyGS0').write(bytes)` 直接发送 CRC 正确的真实手势包，不必先刷固件。它没有独立于 IDE 的第二 CDC，不能边运行 USBDBG 边在同一端点插入手势二进制。**

电脑主机验证已通过：完整真实手势一轮120包，其中86包有效，CRC/范围/序号全部正确，无效包参数全部零。另有300包无效心跳验证序号255→0回绕。当前有手时约7.49Hz，不能宣称稳定20Hz；86个有效包仅1个达到FPGA现有60%门限。

这是一份**含明确未验项目的接口契约候选**。High-Speed描述符及数据通道已实测；最小EP0类控制序列、Full-Speed枚举、总线复位恢复和FPGA USB host尚未完成验收，不能把这些项目当作已验证。

## 1. 设备身份与实测方法

固件运行时身份：

- `CanMV v1.8-24-g46d59a8(based on Micropython e00a144) on 2026-07-30`
- `k230_canmv_yahboom with K230`，MicroPython 1.21.0；USBDBG版本回复0.4.0。
- 电脑当前COM9是Windows为这台设备的CDC功能分配的名称，不是USB协议中的固定端口号。

用Windows公开USB Hub IOCTL读取连接信息及实际设备/配置/字符串描述符，不替换驱动、不改变USB配置。脚本：[描述符采集](../scripts/k230-usb-descriptors.py)；完整原始字节：[descriptors.json](../logs/20261021-k230-usb/descriptors.json)。`GENERIC_WRITE`是打开Hub设备句柄供查询IOCTL使用的权限，不是对K230存储写入。

| 项目 | 实测值 |
|---|---|
| VID / PID | `1209 / ABD1` |
| 制造商 / 产品 / 序列号 | `Kendryte / CanMV / 001000000` |
| 当前速度 | **High-Speed，480Mbit/s信令**；不是吞吐量保证 |
| USB版本 / bcdDevice | `0200 / 0100` |
| 设备类/子类/协议 | `EF / 02 / 01`，复合设备 |
| EP0 | 双向控制，最大包长64 |
| bNumConfigurations | 1 |
| 当前配置 / bConfigurationValue | 1 / 1 |
| 配置总长 / 接口数量 | 105字节 / 3 |
| bmAttributes / bMaxPower | `80 / FA`：声明总线供电、500mA；这不是实测电流或供电余量证明 |
| 字符串语言 | `0409` |

设备描述符：`12010002ef0201400912d1ab000101020301`。

当前配置描述符：

```text
0902690003010080fa080b000202020100090400000102020102052400100105240100010424020205240600010705820308000a09040100020a00000007050102000200070581020002000904020003060101000705030200020007058302000200070584031c0006
```

## 2. 接口与端点：仅适用于本次High-Speed枚举

所有接口的备用设置都是0。地址的IN/OUT方向以USB主机视角解释。

| 接口 | 类/子类/协议 | 端点 | 类型 | 最大包长 | bInterval | 用途 |
|---|---|---|---|---:|---:|---|
| 0 | `02/02/01` | `82 IN` | Interrupt | 8 | 10 | CDC ACM控制/通知 |
| 1 | `0A/00/00` | `01 OUT` | Bulk | 512 | 0 | CDC主机→K230 |
| 1 | `0A/00/00` | `81 IN` | Bulk | 512 | 0 | CDC K230→主机；本次收到二进制包的通道 |
| 2 | `06/01/01` | `03 OUT` | Bulk | 512 | 0 | Still Image类；对应公开实现中的MTP |
| 2 | `06/01/01` | `83 IN` | Bulk | 512 | 0 | 同上；未作为应用自定义通道测试 |
| 2 | `06/01/01` | `84 IN` | Interrupt | 28 | 6 | 同上通知 |

IAD关联接口0和1；CDC Union指定主接口0、从接口1；ACM能力字节`02`。**不存在另一个CDC数据接口，也没有枚举出HID或通用Vendor接口。** `usb.Keyboard/Mouse/Touch`在模块中存在，不意味着当前描述符配置启用了它们。

设备限定描述符实测为 `0a060002ef0201400000`，其中`bNumConfigurations=0`；另一速度配置查询返回WinError31。因此不能由本次读取推出Full-Speed端点最大包长，更不能把512直接硬编码到Full-Speed主机。需要实际Full-Speed主机枚举，或实现High-Speed host后继续核验。

## 3. MicroPython发送API与独占模式

运行时只读探测结果：`usb`含`Serial`，其方法包括`open/close/read/readinto/readline/write`；`machine`未列出`USB_VCP/USBDevice/usb_mode`，`pyb`导入失败；`/dev`只列出一个USB gadget串口节点`ttyGS0`，没有`ttyGS1`。

已实测的发送API：

```python
import usb
u = usb.Serial('/dev/ttyGS0')
if not u.open():
    raise RuntimeError('CDC open failed')
n = u.write(packet)  # bytes；真实USB数据，不是print(packet)
# 检查返回值；部分写入时发送剩余字节，不能假定一次调用总是完成12字节。
u.close()
```

源码中的默认路径是`/dev/ttyUSB1`，不能省略路径误用默认值。当前API会打开指定POSIX设备节点，不自动创建第二CDC，也不自动把IDE切换为手势模式。USB设备的write负责排队，实际线上传输仍需主机对`81 IN`发起IN事务。

本次隔离流程：正常关闭CanMV IDE → 结束USBDBG会话 → 只发送REPL控制/文本，确认实际执行`RAW_PROBE_OK`且返回提示符 → 进入原生raw REPL并确认握手 → 只加载RAM内的有界测试代码 → 测试区间不发任何USBDBG请求、不输出识别日志 → 独立校验接收字节。raw REPL是当前解释器已有的交互模式，不是USB描述符/固件配置改写。

测试区间起止标记和测试后的统计仅用于电脑定位采样窗口。窗口内已验证无文本混入，字节数恰为包数×12。**永久版本尚未部署**；当前开机V2仍会输出`PINCH2`文本，FPGA插上现状不会自动收到本次测试用的12字节流。

永久版本若采用此路径，必须独占CDC，并在启动初始化阶段处理好日志、异常输出与二进制流的隔离；IDE关闭时的设备自主发送、连接时机和重新附着仍需单独验收。不能让FPGA在手势采集期间发送CanMV调试命令，也不能用`USBDBG_TX_BUF`轮询日志冒充直接接收手势包。

## 4. 枚举后控制请求：已知配置与未验序列分开

本次使用Windows现有`usbser.sys`，应用调用串口打开、设置8N1、DTR=1，RTS使用pyserial默认值1；分别在12000000和115200 line-coding下收到40个完整测试包。两种line-coding都不代表USB实际比特率。本次没有安装USB抓包过滤驱动，**未逐URB记录EP0请求及其顺序，也未做省略单项控制请求的最小化实验**。

以下为标准请求映射及FPGA候选初始化值；不能把候选表说成“已逐请求硬件证明必须如此”：

| 请求 | bmRequestType / bRequest | wValue / wIndex / wLength | 数据 | 证据和边界 |
|---|---|---|---|---|
| SET_CONFIGURATION | `00 / 09` | `0001 / 0000 / 0000` | 无 | 真实设备当前配置确认为1；未抓到Windows的原始SETUP顺序 |
| SET_LINE_CODING | `21 / 20` | `0000 / 0000 / 0007` | 115200/8N1：`00 c2 01 00 00 00 08`；12000000/8N1：`00 1b b7 00 00 00 08` | 两种**串口设置**均实测可传数据；标准SETUP编码及公开处理器可核对，线上的实际请求顺序未捕获；不能断言它是最小必要项 |
| SET_CONTROL_LINE_STATE | `21 / 22` | 候选`0003 / 0000 / 0000` | 无；bit0 DTR=1，bit1 RTS=1 | 测试主机逻辑状态DTR/RTS均为1；公开驱动发送路径以DTR门控。DTR低时write可能仍报成功但丢弃数据；RTS是否必需未单独验证。Windows可能分多次改变状态，未捕获原始SETUP |
| GET_LINE_CODING | `A1 / 21` | `0000 / 0000 / 0007` | 设备返回7字节 | 公开处理器存在；本次未直接验证该请求，也未证明主机必须发 |
| SEND_BREAK / SET_COMM_FEATURE / SET_INTERFACE | — | — | — | 测试应用未显式调用；不能据此断言Windows内部没有发其他请求，不列为已验证必需步骤 |

标准枚举仍需主机处理复位、EP0地址0、GET_DESCRIPTOR、SET_ADDRESS及配置描述符解析；设备地址由主机分配，本轮地址32不是应写死的常量。没有证据要求额外vendor握手才能调用上述普通CDC发送API。通知端点82存在，但本轮没有逐端点URB抓取，因此未证明可永久忽略其事务。

**FPGA侧冻结控制序列前的验收缺口**：在可观察SETUP/状态阶段的主机上逐项验证SET_CONFIGURATION、SET_LINE_CODING及DTR置位；验证返回状态/STALL/超时；再确认最小序列和通知端点策略。本次没有绕过Windows驱动直接发未经验证的控制请求。

## 5. 应用流、有效性与速率

包格式保持提交`d453ae2`不变。使用仓库编码器；电脑用CPython独立`binascii.crc_hqx(...,0xffff)`校验，标准检查串结果29B1。接收器按17字节分块喂入，刻意不依赖USB/串口read/12字节边界。

临时实际手势映射：

- 只接受当前V2单手`TRACK`且`valid=True`的结果。NO HAND、MULTI HAND、BAD GEOMETRY、LOW CONF、WARMUP和任何HOLD均发`valid=0`、三个参数全零。
- sender快照超过150ms也发无效零值，不把过期旧结果当新识别。
- pinch取V2临时归一化值×1000并限幅；它仍未校准为实际张开量/音量。
- y定义为关键点5和17的平均纵坐标，基于当前640×480预览的0..479映射到0..1000并限幅。不是检测框中心，也不是镜头翻转前的另一个坐标系。
- confidence取原始检测置信度×100限幅；不把跟踪续持阈值修正后的值伪装成原始置信度。
- 独立MicroPython线程目标间隔50ms，检查部分写入并限制等待；过晚时重新安排，不突发补发历史包。实际受推理/解释器调度影响，20Hz未达成。

| 实测 | 包数 / 有效包 | CRC/范围/序号错误 | 结果 |
|---|---:|---:|---|
| 固定参数、12000000 line-coding | 40 / 40（合成） | 0 | 480字节，证明二进制API与数据完整性 |
| 识别运行但结果均无效 | 300 / 0 | 0 | 3600字节，验证无效零包、255→0回绕；约18.93Hz |
| 用户放手后的完整识别测试 | 120 / 86 | 0 | 1440字节；发送端15888ms，约7.49Hz，69次延迟重排 |
| 关闭重开COM后、115200 line-coding | 40 / 40（合成） | 0 | 480字节，验证普通会话重连及另一line-coding |

真实有效包pinch范围336..1000，y范围528..796，confidence范围24..60；86包中仅1包达到FPGA当前60门限。需要继续解决图像姿态/置信度和参数校准；这不是理由去悄悄降低FPGA门限或虚增发送置信度。

中间一轮因采集窗口短而只收到189包，虽有105个有效包且已收部分CRC正确，但没有结束标记，**不计为完整成功测试**。首次长源码通过friendly REPL输入也未执行成功，改为有握手的raw REPL分块加载。采样窗口标记解析器曾漏掉没有前置换行的标记，原始字节保留后离线复核通过，未因此重发或改板上数据。

## 6. 复位、重连和当前交付状态

- 已验证COM会话关闭/重开后可重新握手和传输；在raw会话中断/退出有界测试后能恢复原main预览。
- **未主动执行USB总线复位、拔插冷启动发送程序或永久发送程序部署**，不能保证它们的行为。公开RTOS参考实现会在USB reset/deinit时清连接/DTR状态，重新配置后重启接收；这是源码依据，不是本机逐项总线测试结果。
- FPGA host未来应在重新枚举后重新设置配置/控制线，清半包、重新找同步头；应用侧遵守250ms失联释放，不靠保存旧值续租。设备重启后序号可重新从0起，接收器按既有失联后重新同步规则处理。
- `u.write`返回12只能证明本地调用接受了长度，不能证明主机已收到。本次成功结论来自电脑实际读取和CRC校验。
- 现在已恢复原`main.py`指向的屏幕V2预览；随后被动读取到33行PINCH2且含TRACK，无Traceback。没有让临时二进制探针常驻，也没有修改原开机入口。

恢复时回读保留文件：

| 文件 | 字节数 | SHA256 |
|---|---:|---|
| `/sdcard/main.py` | 97 | `cc8e17d9e95a03340a4fbcc895f0740cab4d1b051227b749e002da92ca2b5375` |
| `/sdcard/pinch_preview_v2.py` | 10474 | `ae9593ed7a9e610cd1f121d6f825f03e0797fed995b6e73bad259ab8f94371d2` |
| 电赛备份 `main_electronic_contest_backup_20261020.py` | 31805 | `76baacde214193a1bc1c586145dd5eb4aaf0788831280fd169294f78f1284972` |
| 旧入口 `main_before_pinch_v2_20261021.py` | 119 | `69d8d3fb72904b860ffe76e3c2ded454ebb4319aa8a12c287033c0dabf0d72d1` |
| `/sdcard/boot.py` | 73 | `7d0a9a5a9f58fd73def81c97b47d2d6450cfd8b99c75036e2287d76e93572282` |
| `hand_det.kmodel` | 5976920 | `b6047b8d5163347d79572f8c788d5a6bfdc352f8b9946e60495ccb0a83a328c5` |
| `handkp_det.kmodel` | 26863312 | `a3301e8956c6602e5f83111c9f9b8136d1ac120459506ff056677f880860c063` |

## 7. 是否需要改固件与恢复方案

仅发送手势且IDE退出的目标，目前不必先改固件。若要求独立CDC与IDE同时工作，当前枚举配置不满足；公开工程虽有dual-CDC构建选项，本机没有启用第二接口，也未验证其兼容性，不直接刷写。

如果后续选择改固件：先从原SD卡做完整只读镜像并核对SHA256，单独保留当前main/boot/libs/kmodel和全部备份；现有v1.4.3压缩镜像不是这张v1.8运行卡的等价备份。优先在备用SD卡写入匹配亚博板型、屏幕、传感器、nncase和模型的候选系统，原卡保持原样；先核验描述符，再验双CDC互不串数据、屏幕预览、复位和模型推理。失败直接换回原SD卡。当前没有制作整卡镜像，也没有执行此刷写方案。

## 8. 复现与证据

在仓库根目录，IDE退出且电脑直连K230时：

```powershell
python scripts/k230-usb-descriptors.py logs/20261021-k230-usb/descriptors.json
python -m unittest discover -s k230 -p "test_*.py"
python scripts/k230-usb-stream-probe.py --name synthetic --duration 7
python scripts/k230-usb-stream-probe.py --gesture --frames 120 --name live-hand-complete --duration 32
python scripts/k230-usb-restore-preview.py
python scripts/k230-usb-capture-summary.py
```

有界测试会暂停原预览、在RAM运行临时预览，并在结束时退出至REPL；不会自行持久部署。测试结束后需执行原main恢复预览，不能误以为临时程序已固化。长推理/USB异常时采集可能超时；缺少结束标记视为未完成。21项Python测试通过。

证据目录：[logs/20261021-k230-usb](../logs/20261021-k230-usb)。重点是`capture-summary.json`、`live-hand-complete-capture.bin`、`live-hand-complete-frames.json`、`runtime-api-after-ide-close.txt`、`restore-preview.bin`和`restored-preview-passive.bin`。原始捕获保留，可独立复核；不是摄像头照片。

参考实现仅用于解释，不替代实板证据：

- [与运行时g46d59a8匹配的Serial API源码](https://github.com/kendryte/canmv_k230/blob/46d59a8fbedeaa9361d754fb2d97347546c28476/port/modules/modusb.serial.c)
- [同版本REPL默认ttyGS0路径](https://github.com/kendryte/canmv_k230/blob/46d59a8fbedeaa9361d754fb2d97347546c28476/port/core/mphalport.c)
- [同版本IDE附着、DTR及stdout隔离逻辑](https://github.com/kendryte/canmv_k230/blob/46d59a8fbedeaa9361d754fb2d97347546c28476/port/omv/ide_dbg.c)
- [RTOS CDC参考实现：DTR门控及连接处理](https://github.com/canmv-k230/rtsmart/blob/819f3c78b24747cfeb2635f216367d34afff10c0/kernel/bsp/maix3/components/canmv_usb/usbd_cdc.c)。本机未导出整套RTOS构建提交，不能声称该内核二进制与此参考完全一致。

FPGA对接应以“HS描述符已测、独占CDC直接发送已测、类控制最小序列/FS/复位/20Hz未验、当前仍原预览”为交接基线；FPGA源码和Flash本次均不变。
