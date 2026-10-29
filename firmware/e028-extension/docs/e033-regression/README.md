# E033 candidate: consistent dry gain (2026-10-29)

Not deployed. Board last independently read E032 / 0x6020; Flash remains E031.

## Confirmed defect and fix
With input +12000 and zero effect history, bypass produced12000 but chorus-only produced6000. The effect mixer applied a hidden 1/2 gain to the dry path. `gain-red.log` records the failing test. Both stereo mixers now retain unity dry gain, add the existing wet terms in signed18-bit arithmetic, and saturate at the16-bit output. Feedback gains and pins/protocols unchanged.

This fixes a6dB dry-level drop, not all timbre or loudness concerns. Coherent dry/wet peaks can still saturate at high input levels; saturation prevents wraparound but is not a transparent limiter. A physical comparison at controlled recording gain is still required. Effect-switch crossfade and cents-domain vibrato remain pending.

## Validation
13 RTL tests pass, including all8 effect combinations at both polarities, overload saturation, exponential bend mapping, startup RAM scrub, negative impulse decay, 32voices, features, effects, spectrum, OLED, song guide, command parser and core. WebMCP discovery/chord/bounds/stop and agent command encoding pass. Relay4 tests and private config generator1 test pass. No physical OLED frame-rate or end-to-end latency claim follows from these tests.

## Physical test blocker
Local relay refused connection. A prior command to start relay/tunnel was automatically rejected with `blocked by policy`; no alternate launch workaround attempted. Therefore no remote acoustic pass claimed. Realtek input captures samples but provenance of audio signal is not established by that alone. User reports OLED content and no abnormal heat, with no visible heartbeat; cause remains unresolved.
