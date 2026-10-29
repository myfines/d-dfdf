# E033 candidate: consistent dry gain (2026-10-29)

Not deployed. Board last independently read E032 / 0x6020; Flash remains E031.

## Confirmed defect and fix
With input +12000 and zero effect history, bypass produced12000 but chorus-only produced6000. The effect mixer applied a hidden 1/2 gain to the dry path. `gain-red.log` records the failing test. Both stereo mixers now retain unity dry gain, add the existing wet terms in signed18-bit arithmetic, and saturate at the16-bit output. Feedback gains and pins/protocols unchanged.

This fixes a6dB dry-level drop, not all timbre or loudness concerns. Coherent dry/wet peaks can still saturate at high input levels; saturation prevents wraparound but is not a transparent limiter. A physical comparison at controlled recording gain is still required. Effect-switch crossfade and cents-domain vibrato remain pending.

## Validation
13 RTL tests pass, including all8 effect combinations at both polarities, overload saturation, exponential bend mapping, startup RAM scrub, negative impulse decay, 32voices, features, effects, spectrum, OLED, song guide, command parser and core. WebMCP discovery/chord/bounds/stop and agent command encoding pass. Relay4 tests and private config generator1 test pass. No physical OLED frame-rate or end-to-end latency claim follows from these tests.

## Physical test blocker
Local relay refused connection. A prior command to start relay/tunnel was automatically rejected with `blocked by policy`; no alternate launch workaround attempted. Therefore no remote acoustic pass claimed. Realtek input captures samples but provenance of audio signal is not established by that alone. User reports OLED content and no abnormal heat, with no visible heartbeat; cause remains unresolved.

## Build result
Gowin completed successfully:27MHz constraint,27.010MHz Fmax, setup/hold TNS0,15/46BSRAM,8.5/24DSP. Minimum reported setup slack0.014ns is very small; critical path runs from ADC axis to synth increment product. This candidate is not a robust final timing closure claim; pipeline review remains. FS stays private and no hardware deployment was performed.

## Autonomous acoustic probe (first physical capture)
Temporary E03A SRAM image uses the same synth32/fx_engine/i2s_tx16 sources, fixes gesture/ADC/optical/network inputs out of the experiment and automatically stops after36s. Sequence test passes; probe timing Fmax33.644MHz, setup/hold TNS0. Full instrument E033 was restored after recording and independently read E033/0x6020. This does not verify the full instrument control path.

Raw WAV stays private; hash70eb6ba7725db9eb7d284348aa374408d7a232a6c409e7c7ff61aba5a454ab68. First host-completion-aligned metrics were invalid because configuration release precedes CLI completion; retained INVALID-marked file for audit, superseded by acoustic-onset alignment in autonomous-recording.json. No electrical latency is inferred from acoustic alignment.

Matched pitches: C4 261.642Hz, bend up293.658Hz/down233.088Hz, repeat261.643Hz (candidate errors within0.12cents in these windows; mic/clock/FFT uncertainty not calibrated). Dry and each effect released to about-58dBFS. No persistent large tail observed in the sampled release windows. Four-note target peaks visible (minimum local spectral ratio47.3dB); all32 targets have peaks but minimum ratio9.35dB and harmonically related content cannot alone prove32 independent voices.

Four-note and32-note captures showed occasional near-full-scale samples. ADC mic AGC/boost and upstream clipping cannot be separated by these measurements alone. Delay-vs-dry level comparison also confounded by continued envelope evolution: repeat capture lowers output expression and inserts a settled dry slot before enabling delay. First probe is partial evidence, not complete sound-quality acceptance.

## Second capture: low level and settled dry reference
Probe expression8 (first probe24), stable dry slot after2s continuous note before delay. Build Fmax37.120MHz, setup/hold TNS0. Sequence simulation passes. Recorded via explicit Realtek input1,48kHz, raw WAV private, SHA in autonomous-recording-lowgain.json. Relative alignment uses sustained acoustic onset, not CLI completion.

- C4:261.646Hz; bend up293.658Hz/down233.081Hz. Candidates within0.2cents in measured windows; not calibrated metrology.
- Settled dry-43.152dBFS, delay-43.274dBFS: difference-0.122dB. Prior6dB dry-step not observed in this controlled pair; wet/dry phase response and PC capture path still affect magnitude.
- Delay/reverb/chorus release windows-57.21/-57.62/-57.50dBFS; no strong persistent tail in sampled windows.
- Four-note chord peak0.4336, clipped fraction0.32-note peak0.9916 and clipped fraction0.0000781 remain a concern. This fraction is an ADC near-full-scale threshold, not proof of exact digital clipping. Expression is applied after synth mix_sat; internal32voice limiting can therefore remain even when final output level is reduced. Further digital headroom and PC mic gain checks required.
- Final idle-57.10dBFS. Restored full E033 SRAM, independent op73 E033 / op74 6020. Flash E031 unchanged. Restored full instrument is safe-startup/unarmed; isolated probe does not test input arming, OLED responsiveness, network or K230 end-to-end.
