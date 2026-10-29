# E034 candidate: preserve mixer headroom, Q16 voice gain, coherent bend

2026-10-29. Not yet deployed. FlashE031, board last independently readE033/6020.

## Reproduced failures
- Mix saturation occurred before expression. 32 coherent full-level voices with expression8 should produce8159 after the specified lowpass first step, but old code produced1019. Red probe retained in mix-red.log.
- A bend change altered phase increment within the accepted sample frame. Red probe retained in pitch-red.log.
- Envelope peak65535 is Q16 but voice multiplication shifted15bits. Full positive wave32767, env65535, velocity255 should produce32638, but old signed16 narrowing wrapped to-259. Red probe retained in voice-red.log.

## Changes
Keep the mixer/filter/tremolo at24bits, intermediate products at explicitly sufficient signed widths, apply expression before the only16-bit output saturation. Fixed4x mixer headroom retained. This prevents earlier clipping from corrupting low-volume output; full-volume32voice sums can still saturate at final output and require appropriate performance gain.

Voice envelope/velocity scaling now divides by65536, eliminating doubled gain and16-bit wrap. Single-note level can be lower than the faulty baseline; no compensating hidden gain is added. Envelope preset shapes remain unchanged.

Frame-boundary ratio register commits bend/vibrato once per accepted audio frame and breaks the ADC lookup to phase multiplier combinational path. No additional voice-render state added; tested within576clock frame budget. Vibrato remains the existing additive ratio offset; cents-domain modulation still pending.

## Verification
17 RTL regressions pass. Expression test now checks measured64/255 scaling against full-expression output with3LSB allowance, replacing an arbitrary fixed500 minimum that depended on the erroneous voice gain. Red/green tests cover both signs, velocity/envelope endpoints, expression8/64/255/mute, overload saturation, shared frame ratio, independent voices, FX, OLED, song and core.

Timing/build and hardware acoustic results pending. No claim that this fixes physical thermal history, all instrument features, end-to-end latency or the PC microphone clipping path.

## Final build and real acoustic probe
Final full image built after ALL3 fixes:27MHz constraint,27.315MHz Fmax, setup/hold TNS0, minimum setup slack0.428ns (previous E0330.014ns),15/46BSRAM,10/24DSP. This improves margin but is not wide timing headroom. Earlier build before the Q16 fix was not deployed.

Temporary isolated probe E03A built from final sources: Fmax43.057MHz, setup/hold TNS0, bounded36s stimulus then automatic stop. Normal single/chord expression8;32note expression1 explicitly reserves PC mic headroom. Source-side gain normalization also halves nominal singlevoice level compared with the erroneous Q15 implementation; no hidden compensation was inserted.

Actual Realtek capture: center261.637Hz, up293.659Hz/down233.085Hz. Settled dry-48.828dBFS versus delay-48.942dBFS (difference-0.114dB). Effect release windows around-58.2dBFS. Four-note peak0.218;32note peak0.0767; neither window had samples above0.99. Final idle-58.03dBFS. These are input-capture dBFS values, not DAC volts or calibrated THD. A lower32voice test gain means this is not a same-level clipping improvement ratio. Final full-volume limiting can still occur.

Raw WAV stays private, SHA256 adcd4fa3953924edc21c1c72c929c3bdd5bbd1b398bf8aae8b53dda4fe19d88b; see autonomous-recording-lowgain.json. Sequence alignment uses acoustic onset; no physical input-to-audio latency claim. Full E034 restored in finally block and independently read E034/0x6020. Programming User code mismatch warnings retained. Flash E031 unchanged. User confirmed no abnormal heat before probe; this is not measured thermal-root-cause evidence.

Input arming, optical/joystick/K230, OLED, Wi-Fi and phone full-system tests remain separate from this isolated probe. After restoration the full instrument starts unarmed and requires one enable combination. All official requirements are not yet accepted.
