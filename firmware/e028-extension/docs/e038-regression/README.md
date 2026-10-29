# E038 control correction and sound-quality triage

User reports E037 cold-boot controls generally work, but volume is too small, expression changes too weak, and some notes sound strange. This is not accepted sound-quality completion.

Identified causes:
1. Physical velocity path used axis_y>>6+40, then capped127 while synth gain divides by256. At axis825 actual velocity52; E038 maps0..1650 monotonically to64..255,center159. Design-level center gain difference+9.7dB, not an acoustic measurement. No master-mix headroom or saturation changes.
2. Gesture brightness selected gesture_color[9:2] from12-bit0..1650 and wrapped at1024. E038 scales/clamps the entire range to0..255; sweep regression checks every integer input0..1800 for monotonicity.
3. Pinch was also routed to vibrato and then tremolo, producing undocumented simultaneous pitch/amplitude modulation. E038 keeps pinch as volume, retains explicit remote vibrato X, and leaves implicit tremolo disabled. This reduces surprising tone changes; it does not prove all remaining artifacts solved.

References inspected, not copied wholesale:
- DaisySP limiter: https://github.com/electro-smith/DaisySP/blob/master/Source/Dynamics/limiter.cpp uses peak tracking with different rise/fall rates, controlled gain and soft limiting. Useful for a later measured loudness/headroom redesign; no limiter was inserted in this correction.
- DaisySP oscillator: https://github.com/electro-smith/DaisySP/blob/master/Source/Synthesis/oscillator.cpp provides normalized oscillator output and PolyBLEP variants. Current FPGA already uses bounded additive partials, so PolyBLEP is not automatically appropriate for its present oscillator.
- DaisySP ADSR: https://github.com/electro-smith/DaisySP/blob/master/Source/Control/adsr.cpp derives coefficients from stage times and sample rate. Current stage indexing remains documented separately; no envelope rewrite to compensate for microphone artifacts.

Focused control sweep, production wiring, ADSR wiring and core regression passed. Explicit remote controls remain available. Firmware build, board deployment and user listening are separate evidence, to be recorded as they complete. Flash remains E037 until documented otherwise. Historical acoustic capture chain issues and thermal uncertainty remain open.


## Deployment
Full build27MHz constraint,Fmax27.106MHz,setup/hold TNS0. Margin remains small. Fixed-hash official SRAM operation2 completed, independent operation73 E038 / operation74 6020. No Flash writes; E037 remains cold-boot fallback. User listening requested with no effects switching, same keys and centered joystick, then separate pinch/height comparison. No acoustic improvement or clipping absence is claimed until measured/listened.
