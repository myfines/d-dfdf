# APK0.11直连解析与真实板包回放

修复A帧键位元数据边界校验：前32块音符限定0..31，后96块必须为HDL输出的FF占位。先运行回归测试复现“out-of-range mapped note32 accepted”，再修复。原版InstrumentView.java未改，versionCode11，签名与0.10一致。

完整构建含协议、TCP分片/断连、直连事务、WAV、实际View绘制路径测试均通过。将E046板上采集的416个真实A帧回放进生产DirectExtension.parse，128块完整，Android导出WAV SHA256与板上工具一致。它是USB诊断数据回放，不是手机/ESP/Wi-Fi验收。

复现：先运行mobile-companion/build.ps1，再用同一JDK编译tests/DirectBoardReplayTest.java，类路径build/tests；执行cn.myfines.instrument.DirectBoardReplayTest，参数为本目录board-A-packets.txt及输出WAV路径。不要把手机麦克风录音与这里的FPGA数字PCM混淆。
