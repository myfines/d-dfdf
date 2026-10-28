# E028 修正版 Flash 写入记录

2026-10-28，用户明确要求“烧录flash吧”。

- 源码提交：f54442c。
- 码流：instrument_e028.fs，SHA256 D398867DF47BCCA32EF454ABE500CD5BCD5FBFA7F10B72BC50FD41097B5D6C33。
- 扫描：一个设备，ID 0x0000081B。
- operation 37，GAO-Bridge，2.5MHz，SPI地址0；进程exit 0。
- 返回 Program and Verify flash successfully，100%，28.12秒。
- 写后独立读取：UserCode E028、Status 6020。
- 本次尚未实测断电冷启动，也未代替用户验收声音/OLED/温度。
- 原硬件温升记录保留，本次授权不代表温升根因已解决。
