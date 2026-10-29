# E040 candidate / APK0.9 crash repair

APK crash reproduced before repair by executing the actual InstrumentView layout and connected32-point draw using test-only Android drawing stubs: ArrayIndexOutOfBoundsException index32 length32 at drawScope. Broad substitution had changed the32 loop to42. Fixed32. build.ps1 now runs this path test plus existing protocol/socket/core/extension tests; all passed. Stubs never enter production APK. No Android phone attached; real lifecycle/visual verification remains pending.

APK SHA256 17ec04f9a19a66e93c02f8b115adf8e9ce85f8580be2db1c6cb01e93448f125b.

Bass preset held level18000->36000, attack and spectral weights unchanged. Actual synthesis through note-on and settled C4 produced RMS1367.591763, peak1949 at velocity159 and unity expression; single voice dry PCM, not sound pressure. Test's first RMS accumulator had16-bit multiplication overflow; corrected to integer magnitude multiplication before final PASS. Preserve chosen four-voice mixer headroom. Human loudness matching remains pending.

Lissajous test checks true L/R frozen snapshot XY points for equal/opposite/quadrature/silence, and a nonmatching coordinate. Raster PNG is generated from actual RTL pixel output, not physical OLED evidence. tb_oled_ui, tb_mix_headroom, tb_synth32 also passed. No visual RTL change necessary from this evidence.

E040 candidate build passed27MHz at27.732MHz Fmax, setup/hold TNS0. Not downloaded or flashed; hardware remains E039. Formal requirements and pending evidence are listed in docs/requirements-e040-audit.md.
