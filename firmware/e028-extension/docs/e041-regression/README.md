# E041 SRAM / Android0.10 direct extensions — 2026-10-29

Hardware is E041 SRAM, Flash remains E039. User was invited to test and replied that they would test now; no physical result has yet been received. Do not interrupt that test with another download.

## Control repair

Phone volume is a ceiling multiplied by effective pinch gain with rounded division by255. Exhaustive65536 input combinations match `(ceiling*pinch+127)/255`; no-phone, full-pinch and hand-loss endpoints pass. The original phone lease priority masked pinch entirely.

Brightness and bend now require an explicit Y/B command to own their dimension. A Q lease or the normal phone V/T/E/P/K/Q heartbeat preserves gesture brightness and joystick bend. Ownership clears on L or lease expiry. New production-core test reproduced the original failure before repair and passes after it. Explicit phone B/Y retain precedence until release/expiry.

E041 build:27MHz constraint, Fmax27.449MHz, setup/hold TNS0. SHA256 `3a04ebf31481448a80d9cda9edb49b67720ce48f326ec605a17ae652686f7961`.

Official programmer scan found device0x81B. Operation2 reached100%, returned E041/status6020, exit0, but also printed `User code mismatch`; retain this diagnostic. Separate operation73 and74 returned E041 and6020. This verifies deployment identity, not audio, temperature, phone interaction or cold boot. No Flash operation was performed.

Full default31 RTL tests passed after E041 changes; ownership test passed separately. See retained logs. No computer Wi-Fi change or ESP firmware write.

## APK0.10

Package `cn.myfines.instrument`, versionCode10/versionName0.10-e041-direct, existing local companion signing key. Original `InstrumentView.java` is unchanged. Extensions are accessible from its existing settings entry.

APK SHA256 `cfe1a666307c74c4f6886cfdd1c9c3ac6747822852ad4f1a50fc95a6753b597f`.

- W: submit score, wait for old-ready cleared and committed event count read back, support play/stop. Score persists in phone preferences; device RAM score survives disconnect but not power loss.
- U: set any of32 slots and wait for mapped note readback. Readback is configuration evidence; acoustic pitch still requires testing.
- C: start a new recording ID, wait for ready, request128 ordered32-byte chunks, require recording ID/chunk/flags/checksum, then export4096 signed8 PCM samples as unsigned8 mono RIFF/WAV. Nominal rate46875/8 rounds to5859Hz in the integer WAV header. This is about0.699s, not continuous high-fidelity capture or electrical sample-rate measurement.
- Uses the existing bound Wi-Fi TCP socket, bounded96-command queue and a single background operation worker. Supports S/G/A frames without replacing the original UI; cancellation/disconnection stops the operation. Recording dismisses settings so phone pads remain usable; file export uses the Android document picker.

Build/signature, real View constructor/layout/32-point drawing/four timbres, packet validation, TCP fragmentation and S/G/A multiplexing passed. Direct transaction tests cover score commit, map readback, all128 recording chunks, WAV conversion/checksum rejection and cancellation. No attached Android device; lifecycle, picker, UI appearance and real FPGA round trip remain unaccepted.

**Important integration boundary:** E041 still disables the recorder in hotspot mode. APK0.10 extension readbacks require E042, whose RTL now enables the recorder independently of cloud relay and freezes A/G selection for a complete frame. See the E042 evidence before deploying it. Do not claim this APK plus E041 completes W/U/C acceptance.

## Remaining acceptance

Actual note-on/envelope RTL calibration at C3/C4/C5, velocity159, expression160 and brightness128 is in `timbre-levels.csv`. C4 settled RMS: piano175.93, organ1221.19, strings867.17, Bass858.10. Bass differs from strings by about-0.09dB and organ by-3.06dB in this single-note dry scenario. C4 attack peaks2064/2268/1631/2217 respectively. All12 measured note/timbre combinations had zero full-scale samples. The existing Bass unity-expression regression also passes. These measurements describe digital PCM, not matched perceived loudness, acoustic frequency response, speaker loudness, multi-note full-volume clipping or physical DAC sample-rate measurement. The earlier Bass hold18000→36000 remains the only timbre gain change.

Phone pinch/height/joystick and subjective Bass feedback; E042 SRAM deployment and real round trip; actual Android W/U/C/export; physical input-to-analog-output latency/jitter,32 simultaneous audible frequency peaks with electrically measured DAC rate, OLED refresh rate and physical visual evidence; final Flash and cold boot. FAQ73 points to missing103, so the input-chain scope is not relaxed. FAQ77 permits independent phase/FCW/ADSR TDM voices; Wi-Fi has no documented official Bluetooth equivalence.
