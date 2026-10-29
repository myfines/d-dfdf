# E035 ADSR control (2026-10-29)

Official topic2 basic requirement3 explicitly includes ADSR envelope control: https://www.gowinsemi.com.cn/university/match2026 . This increment adds parameter operation beyond the prior fixed timbre presets. It does not constitute acceptance of all official requirements.

## End-to-end implementation
New optional synth control; A/D/R each16-step rate index, S8-bit level. Frame-boundary snapshot, then each newly triggered voice latches its own21-bit custom configuration. Held/releasing voices retain their configuration when the next note's parameters change. Gate-off releases from current level; pervoice release does not cut other notes. G00000000 restores existing timbre presets for subsequent note-ons. Config is volatile; disable/re-enable peripherals or reconfiguration resets it. Lease expiry releases remote notes but does not erase local envelope configuration.

WebMCP adds instrument_adsr (enabled,attack,decay,sustain,release), range validation and checksum generation. Relay validates and retains G packet. Both raw/IPD payload and local HTTP parser accept it; FPGA bank validates version and checksum again. Existing APK commands unchanged. Receipt still says appliedConfirmed:false; no actual device-applied ADSR telemetry has been implemented. Updating source does not imply the stopped public relay has restarted.

## Rate units and protocol
A/D/R index i yields unsigned Q16 step32768>>i per46.875kHz audio sample. Full-scale traverse length ceil(65535/step), roughly0.043..1398ms. Actual D duration depends on65535-S and R on level at release; indexes are NOT arbitrary millisecond values. Sustain byte s maps to16-bit s*257.

Gxxxxxxxx:32-bit packet [31:28]version1,[27:24]A,[23:20]D,[19:16]R,[15:8]S,[7:0]XOR of first3 bytes. Example G19CDA074: A9,D12,R13,S160. Defaults in WebMCP use these values. G00000000 restores presets. Bad version/checksum leaves current config unchanged.

## Verification and limitations
21 RTL tests pass including A3 reaches32768 after8frames, D4 reaches S64=16448, second voice keeps a different sustain, selective R5 completes without cutting the held voice, preset restore, both payload/HTTP eighthex parsing, version/checksum rejection and command-bank-frame-voice wiring. Core wiring test skips the physical one-second arming guard; it is not a physical arming or latency test. Existing20-test suite plus the added core wiring test pass; WebMCP tests and5 relay tests pass, agent controls and webpage tests pass.

Full Gowin build27MHz constraint, Fmax27.209MHz, min setup slack0.285ns, setup/hold TNS0,15/46BSRAM,10/24DSP. Margin remains small. Raw cloud-enabled bitstream private. Acoustic envelope curves via DAC and actual network application remain pending. Prior E034 acoustic validation does not prove this new custom ADSR feature.

## SRAM deployment
Fixed manifest hash verified; official operation2 at2.5MHz completed100% in6.43s,exit0. User code mismatch warning retained. Independent op73 E035,op74 0x6020. Flash remains E031. No custom ADSR acoustic or live Wi-Fi command application is claimed from deployment/readback. Full instrument starts unarmed after reconfiguration.

## 2026-10-29 autonomous DAC envelope experiment
SRAM-only E03B probe uses the production synth/fx/I2S with one C4 voice and paired 2-second held/released slots. All external control buses are high impedance. The capture completed and full E035 was restored; independent reads return E035/6020. Flash remains E031. Private raw WAV SHA256: b0be262fe400882c4fcfd0de882474a73ef35949eb31dca4d6dd76f0d9bb3c5a.

Observed 20ms-bin RMS transitions: slow attack 0.52s versus expected 0.559s; slow decay 0.38s versus expected 0.419s. Long release measured 0.02s versus expected 0.281s, and high/low sustain ratio 4.103 versus expected 3. These last two are UNRESOLVED, not acceptance passes. Microphone AGC/noise suppression is a hypothesis, not an established cause. This acoustic measurement is neither physical input latency nor actual device-applied network configuration verification.

New full-engine RTL regression tb_adsr_long_release checks every one of 8224 release frames from S64 with R14: decrement exactly 2, completion after 175.445ms at design sample rate, other held voice unaffected, sustain levels16448/49344 exactly3:1. It passes. This validates simulation state evolution; synthesized-board envelope telemetry is still needed to localize the acoustic discrepancy. Analyzer unit tests cover transition extraction and absent transitions. The probe/test/analysis sources and summarized capture evidence are versioned; private audio and cloud credentials are excluded.
