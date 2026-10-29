> 最新部署：E045已写入Flash并校验成功，独立读回E045/0x6020；完整断电冷启动与实体功能待用户测试。见[烧录证据](../firmware/e028-extension/docs/e045-flash/README.md)和[测试清单](e045-user-checklist.md)。以下旧E039部署描述为历史状态。

# E045当前状态与板上音频证据（2026-10-29）

当前完整功能版为E045 SRAM，独立读回E045/0x6020；Flash仍E039，断电不会保留E045。本轮没有写Flash或ESP固件，没有让电脑加入ESP热点。APK0.10保留原版自绘主界面；真实手机闭环尚未验收。

## 已测与修复

- 生产控制核心修复旧remote_vibrato在释放/租约到期后残留、重连复活的问题。先复现失败，再修复；33项RTL通过，27MHz约束下Fmax27.219MHz，setup/hold TNS为0。详见[manifest](../firmware/e028-extension/docs/e045-regression/manifest.json)。
- 同一E044探针与模拟连接，普通MME录音的半音量衰减为25.76dB；真实WASAPI RAW为5.95dB，四分之一为11.71dB，恢复误差0.013dB，接近理论6.02/12.04dB。不能为电脑录音处理造成的衰减盲目提高生产增益。
- 四段干声均关闭颤音、振幅调制与效果：电钢琴1/2/3次谐波并衰减，风琴1/2/4次，弦乐1/3/5次慢起音，Bass以基波为主。属于不同简化合成音色；弦乐没有失谐双振荡器，不声称逼真采样音色。
- RAW同为C4：四音色基频约261.63Hz；Bass保持段比弦乐低0.17dB。风琴/弦乐/Bass干声音高5–95百分位约261.45–261.79Hz，显式颤音80后为259.13–264.08Hz。不能将C4对比当作低音域Bass验收。
- 32预期频点均有局部峰，最低局部SNR18.77dB；UART确认32→上16→下16切换。见[RAW分析](../firmware/e028-extension/docs/e044-wasapi-raw/analysis-summary.json)和[频点表](../firmware/e028-extension/docs/e044-wasapi-raw/frequency-peaks.csv)。探针使用降低输出增益，不能冒充正式最大音量验收。
- E046从当前生产核心派生并内部注入命令：416有效包、0错误录音包、128块完整，曲谱3事件ready、slot0映射31、ADSR配置9CDA0、PCM非零。见[板上集成报告](../firmware/e028-extension/docs/e046-integration/report.json)。结束恢复完整E045，独立读版本和状态。

## 仍缺的交付证据

1. 实体手机连接时捏合/高度/摇杆组合、断连重连；原版UI曲谱下载、映射、录音导出回放。没有ADB设备，内部注入不替代ESP/Wi-Fi/Android验收。
2. 真实控制输入至DAC模拟输出的≤10ms基础延迟，以及≤5ms拓展和抖动；电测LRCK实际采样率。PC以48kHz录音不能证明DAC采样率。
3. 最终版OLED/LED与脱机曲谱视频、连续运行、最终Flash写入校验与完整断电自启动。当前Flash仍旧版。
4. 最终交付唯一版本/hash、脱敏可复现构建和视频/接线/报告索引。详细赛题逐项对应仍见[差距审计](delivery-gap-audit-20261029.md)。

RAW采集记录一次discontinuity警告，尚未定位发生位置，不据此宣称无丢帧或低抖动。WDM-KS没有收到样本，判无效；临时Disable_SysFx测试未解决，属性已恢复。保留失败及恢复记录。

原始WAV保留私有本机目录，公开报告不包含真实凭据或码流。四干声试听为private/esp-web/e044-wasapi-raw/four-dry-timbres.wav，依次电钢琴、风琴、弦乐、Bass，同为C4、无逐段归一化。
