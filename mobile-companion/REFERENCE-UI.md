# Reference UI restoration (0.8)

User supplied base(2).apk.1, SHA256: 02c07734556b00bf38946c2c3c0bddd64414ad485387ce017d0155b731985ea7. Its com.fpga.instrument.InstrumentView was recovered locally using JADX 1.5.6 with --no-replace-consts. The recovered drawing and touch layout is adapted in src/cn/myfines/instrument/reference/InstrumentView.java. It replaces the generic launcher as the default landscape performance screen. Footer control flow was reconstructed because decompilation produced duplicated ambiguous branches. Four timbre chips, current chromatic note labels, and shared-pointer release handling are adapted for current hardware.

The original supplied APK remains untouched. This APK uses cn.myfines.instrument and the existing companion signing key; it updates the companion, not the separate com.fpga.instrument installation. Original APK is not committed.

ReferenceActivity binds the recovered UI to WifiSession and stores host/port/volume/timbre/page/echo locally. Held notes and live connection status are intentionally not restored. Commands support K00..KFF and four timbres/pages. Touch is released when leaving the app. Waveform/gesture data comes from real snapshots.

Build and existing core/protocol/socket/extension tests pass, with a regression case for Bass/page3/eight-key mask. Signature verified by build.ps1. No Android device was attached, so live rendering, persistence on a phone, and ESP connectivity have not been verified.

The current E038/E037 cloud firmware uses station mode. Direct operation requires the AP firmware, not only this APK. E039 AP sources/build have been prepared and compiled, but have NOT been downloaded or written to Flash. No hardware change during this UI restoration.
