# K230 connected: live USB enumeration diagnosis

User confirmed both OTG ports connected and K230 booted. Current SRAM is E024 debug1; instrument E023 Flash was not modified.

## Observations
- SRAM programming operation 2 completed; UART A7 reports prove diagnostic logic is running. Programmer reports User code mismatch / status 0x6020, so exit zero is not represented as bitwise verification.
- Real I/O constrained build has zero setup and hold violated endpoints. Report RTL test passed.
- Timestamped fresh COM13 read (4 seconds) contains 15 periodic reports at about 0.28 second intervals. CDC ready remains zero throughout.
- Observed 0x404d/0x004d: J line state, unknown speed, reset active (with/without upstream TX valid).
- Observed 0x0c04: full speed, transfer response TIMEOUT, idle; enumeration and endpoint parser valid are both zero.
- 0x0800 has high-speed status and idle, but no enumeration; it must not alone be interpreted as successful high-speed negotiation.
- Earlier untimestamped captures contain buffered historical frames; do not infer realtime report rate from their frame counts.

## Conclusion and next boundary
Connection-related line activity is observed, but host has not enumerated the device. Reset/chirp, physical ULPI transactions and speed negotiation require further investigation. These data do not identify a single proven root cause; do not blame application CRC/confidence or declare the USB host functional.

K230 chat committed candidate 642fac4: persistent binary sender is prepared but not deployed. Current boot program remains text preview. That is a separate later application issue; it does not explain failure to enumerate standard device descriptors.

No Flash write, firmware write, SD change or power rewiring was performed in this diagnostic stage. Historical overheating root cause remains unresolved.

Raw evidence: logs/20261022-k230-debug-uart-timed.json; build/download/test logs with the same date and debug prefix. Debug bitstream SHA256 is recorded in logs/20261022-k230-debug-sha256.txt.
