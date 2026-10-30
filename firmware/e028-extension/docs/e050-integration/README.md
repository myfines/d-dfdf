# E050临时SRAM板上诊断

基于E049相同的instrument_core、OLED、合成/效果/I2S、曲谱/映射/包络/录音代码生成诊断派生顶层。内部注入命令，USB UART输出原A帧与冻结的Z诊断帧；没有通过手机/ESP发送这些命令。

OLED沿用原引脚和实际I2C连接；ADC/光键接口悬空高阻，手势关闭，ESP_TX高阻，不驱动传感器检测输出。自动启用仅用于SRAM探针，结束恢复SAFE_STARTUP正式版。Flash不写E050。

结果：393有效A帧、0错误、128块录音完整；曲谱3事件、slot0映射31、ADSR9CDA0回读一致，PCM非零。438个OLED状态帧中存在实际I2C ACK；所有目标键/建议音区状态与独立参考映射一致，含58个休止快照、32个音区2快照、14个非零目标快照。ACK说明设备响应，不等于照片或逐像素物理显示检查。数字PCM录音不等于本轮采集DAC模拟输出。

E050 Fmax27.065MHz满足27MHz约束，setup/hold TNS0。诊断UART经过实际RTL发送/接收回环测试；E049此前完整37项RTL及李萨如测试通过。本轮结束已恢复E049，独立读回E049/6020。

生成/构建：`python tools/generate_e050_probe.py`，设置FPGA_WEB_PRIVATE后 `gw_sh.exe tools/build_e050_probe.tcl`。运行：核对probe-build.json所记已编译hash后 `python tools/run_e050_probe.py`；工具finally恢复固定hash的E049。修改探针源码后须重建并更新构建清单，不能直接复用旧hash。诊断A/Z原帧与WAV留在E:/gaoyun/private/esp-web/e050-integration-*，不把原始音频提交仓库。

本轮ADB枚举为空，未安装或测试手机App。没有冷启动、手机控制/光键/手势实体闭环、模拟音频、LRCK或实体延迟结论。
