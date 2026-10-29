# E047 Flash固化

用户确认E047电钢琴/Bass“两种音色现在都够响”，按此前“Flash先烧录”授权固化同一候选。识别0x81B、预读E047，核对fd2123078ac23a0c2941a477c8c407e015ce7f2eace8f7a1eb3c5b053567a05d；官方GAO-Bridge operation37、GW2A-18C、cable1、2.5MHz、spiaddr0x000000，exit0、明确Program and Verify flash successfully、28.781秒。

首次写后operation73为0000，原始日志保留；随后只读operation74=6020、operation73=E047，无重刷、无追加SRAM下载。最终独立版本成功不替代完整断电自启动。冷启动由用户做，其他功能未收到明确验收反馈。
