# E036 custom physical/phone key mapping

Official topic2 extension4 includes mobile score download, custom key mapping and recording return. This increment implements key mapping only. It does not complete score download or digital recording return. Core audio/visual computation remains FPGA HDL. Official source: https://www.gowinsemi.com.cn/university/match2026 . FAQ77 accepts independent TDM voices as voice count; FAQ73 refers to missing technical question103, so no relaxed latency interpretation is assumed. The linked Tencent sheet could not be retrieved; the user-supplied FAQ copy was used, without assuming Wi-Fi is formally equivalent to BLE.

## Protocol and behavior
Uxxxxxxxx (8 hex) carries bytes10,index,note,checksum. Index/note0..31; checksum XOR of preceding3bytes. Example U10001F0F maps optical/phone position0 to voice31. U00000000 restores identity. Position=page*8+physical key. Voice0=C3,12=C4,31=G5. Invalid version, range or checksum leaves table unchanged. Both raw/IPD and HTTP parse U. Table resets on peripheral reset/reconfiguration, and survives network lease expiry. Configurations are volatile, not stored in Flash. Mapping affects optical and remote K keys; board keys28..31, direct M mask and song masks keep their existing meaning. Duplicate targets share one voice, not extra independent voices. Change mapping with keys released; held remapping changes live routing, and latched notes should first be cleared by leaving latch mode.

WebMCP instrument_keymap accepts {slot,note} or {reset:true}. Existing APK not rebuilt. Relay retains up to32entries and round-robins at most4 per poll, keeping responses below256bytes with existing parameters. Restore-default is ordered before immediate subsequent remaps. Entire-map update is not atomic; receipt is relay acceptance, not FPGA applied confirmation. Network loss releases remote performance lease while physical mapping remains active. No public service restart or live Wi-Fi application is claimed.

## Verification
New RTL tests cover identity, optical/phone remapping, page selection, invalid checksum/index/note, default restoration, and U through both transports. Core tests pass. Six relay tests include32-entry replay and reset ordering. WebMCP command encoding/range checks pass. Full build/timing and full RTL regression status are recorded separately. Current hardware remains E035 SRAM until explicitly recorded otherwise; Flash E031 remains fallback. Prior acoustic discrepancy is deferred, not waived.

Full Gowin build completed:27MHz constraint,Fmax27.074MHz,setup/hold TNS0. Timing margin is small; candidate is built, not downloaded. Hardware remains E035 SRAM. The build hash is local-artifact manifest evidence, not readback acceptance.

Full default RTL suite:24 tests PASS, including new keymap and transport tests. See rtl-tests.log. No physical network keymap acceptance yet.
