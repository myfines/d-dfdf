# E045 Flash写入与校验

2026-10-29用户明确要求先烧录Flash。识别单设备0x81B、预读E045，无其他烧录器进程；核对既有约束及原E045码流SHA256。沿用此前成功的官方GAO-Bridge operation37（exFlash Erase,Program,Verify），GW2A-18C/cable-index1/2.5MHz，spiaddr0x000000。不是bulk erase。

工具exit0，明确Program and Verify flash successfully，约28.765秒。独立operation73/74读回E045/6020。未追加SRAM下载、未写ESP/OTP/下载器固件。完整冷启动由用户执行，当前尚未确认。写后读回不能替代断电自启动验收。
