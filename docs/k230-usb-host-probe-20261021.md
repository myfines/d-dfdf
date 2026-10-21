# K230 OTG 主机阶段记录（2026-10-21）

## 结论

已经实际运行 USB High-Speed 主机与模拟 K230 的双向包级仿真，4 项通过；
诊断 RTL 对收到的手势进行 CRC 解析，再输出 UART 报文的测试也通过。
**尚未满足上板条件，没有下载 SRAM、没有改写 Flash、没有验证实物 OTG。**

## 已验证

- HS 枚举，实际采集的 105 字节配置描述符，选择 CDC 81 IN bulk512，避免误选 MTP。
- SET_LINE_CODING 115200/8N1 和 DTR/RTS 类请求。
- 正常有效/无手两帧、6+18 字节跨 USB 包、NAK 等待。
- 512+4 字节 bulk 传输、接收端背压；STALL 不向应用交付数据。
- 捕获的字节进入实际 gesture_packet_rx RTL，得到有效/失手 UART 报文及 XOR。

原始日志：logs/20261021-usb-cdc-final.log（4 项，113.6 秒）、
logs/20261021-usb-probe-report-pipeline.log；仿真包在 logs/20261021-usb-host-packets。

## 仍未通过

仅内部时钟约束时工具曾报告通过，加入 USB3317 数据手册的真实 I/O 要求后失败。
最新流水线优化结果仍为 **setup 9、hold 17**；最差 setup -6.312ns，
报告 Fmax 43.517MHz，不能满足 ULPI 60MHz。主要剩余路径在主机状态机到 ULPI 输出。
报告保存在 logs/20261021-usb-host-pipeline-timing.html。

约束采用 PHY 输出延迟 1.5–3.5ns、输入 setup5ns/hold0，并另预留0.5ns板级预算；
板级预算未实测。来源：[Microchip USB3317 DS00002366A，表4-3](https://ww1.microchip.com/downloads/aemDocuments/documents/UNG/ProductDocuments/DataSheets/00002366A.pdf)。
RESETB 低有效；原候选极性错误已在上板前发现并修正，RTL 测试覆盖。
尝试反相生成时钟被 Gowin 拒绝，已经撤回，当前仍采用标准上升沿 ULPI。
没有通过删约束、虚假路径或降低固定 ULPI 时钟掩盖问题。

## 下一步

1. 修复 ULPI 输出路径和输入 hold，实现真实 I/O 时序收敛，补物理接口仿真。
2. K230 准备独占 CDC 二进制发送程序；当前预览程序会打印文本，不能直接替代。
3. 再进行独立 SRAM 主机诊断，成功后才把手势接入乐器；E023 Flash 保留用于回退。

连接只在准备完成后进行：K230 OTG 接 Dock OTG，避免 K230 同时接另一路 USB/5V
形成双路供电。过去温升原因尚未查明，当前仿真不构成热故障已解决的证据。

源代码、依赖固定版本、复现命令与限制见 usb_host/README.md。
