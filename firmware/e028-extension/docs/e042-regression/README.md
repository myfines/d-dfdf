# E042 hotspot recording candidate — 2026-10-29

**Compiled and simulated, not downloaded. Board remains E041 SRAM for the user's ongoing phone test; Flash remains E039.**

Cross-layer review found that E041's `ENABLE_WEB_RELAY=0` disabled the `pcm_record` instance and telemetry mux. Therefore phone-only unit/socket tests did not prove W/U/C device round trips. Added `tb_direct_record_wiring` against production `instrument_core` in hotspot mode; it first failed with `AP direct recording telemetry disabled`.

E042 instantiates the recorder whenever UI/telemetry is enabled, independent of public cloud relay. Both normal G telemetry and A recording frames use96 bytes including LF. Frame-kind selection is captured at the telemetry snapshot boundary, so a C command cannot tear an in-flight G/A frame. The test verifies hotspot A selection, start/busy metadata and return to G at the next capture. Its first busy-metadata check incorrectly attempted another capture before the recorder's96-clock memory snapshot fetch completed; spacing captures realistically fixed the test fixture, not the recorder.

Default RTL suite now includes both new production-wiring tests:33/33 PASS. Record checksum/content/transport tests remain included. `build.txt`, `rtl-full.txt`, `direct-record-wiring.txt` preserve raw evidence.

Build27MHz constraint: Fmax27.052MHz; setup/hold TNS0, violating endpoints0. Setup margin is only about0.071ns; passing static timing does not establish measured jitter or electrical end-to-end latency. Resources: logic13115/20736, registers6423/16173, CLS8994/10368, BSRAM19/46, DSP11/24.

Private artifact: `E:/gaoyun/private/esp-web/build/instrument_e042_ap/impl/pnr/instrument_e042_ap.fs`.
SHA256 `9467a8c838ceed70f36ca167fae44491664598a3faaff9d57bf2d69327af30f1`.

Next: after E041 phone test finishes, validate E042 SRAM identity and actual phone score/map/record/WAV flows. APK0.10 does not use public relay. Do not write final Flash before these physical results and cold-boot planning are recorded.

Remaining official acceptance gaps are unchanged: total input-to-analog latency and jitter;32 audible simultaneous peaks together with electrical DAC sample rate; physical OLED refresh and display evidence; subjective Bass/effect comparison; actual Android lifecycle/picker/export. FAQ73 references missing103; no relaxed input-chain interpretation or Bluetooth equivalence has been assumed.
