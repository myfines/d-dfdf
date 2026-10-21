# K230 USB HS host diagnostic — not an instrument release

Independent host diagnostic, usercode E024. Current instrument Flash E023 is untouched.
2026-10-22: timing closure reached with USB3317 I/O delays, setup/hold violations
both zero (minimum slack 1.481ns/0.325ns). Seven tests pass, plus report RTL and
vendor PLL model. An SRAM-only diagnostic trial runs on the board; Flash is unchanged.
K230 has not yet been attached; real enumeration and instrument integration remain unverified.

## Reproduce on this workstation

PowerShell from E:/gaoyun/d-dfdf:

```powershell
$env:PYTHONPATH='E:/gaoyun/tools/guh-host-reference;E:/gaoyun/d-dfdf/usb_host'
& E:/gaoyun/tools/usb-host-venv/Scripts/python.exe -m unittest discover -s usb_host -p test_cdc_host.py -v
& E:/gaoyun/tools/usb-host-venv/Scripts/python.exe usb_host/export_host.py
```

Run the RTL report test after the Python suite: it consumes the final test's captured
24-byte hex fixture in E:/gaoyun/tools/smoke. Add both Icarus and openFPGALoader
ucrt64/bin directories to PATH for their runtime DLLs, then:

```powershell
iverilog -g2012 -DPROBE_SIM -s tb_probe_report -o E:/gaoyun/tools/smoke/usb-probe-report.vvp usb_host/tb_probe_report.sv usb_host/host_probe_top.v instrument_io/gesture_packet_rx.v instrument_io/uart8n1.v
vvp E:/gaoyun/tools/smoke/usb-probe-report.vvp
```

Build with the existing Gowin gw_sh.exe and usb_host/build_probe.tcl. Inspect the
timing report, not just the command exit code. All paths are currently workstation specific.

## Pinned external dependencies

- apfaudio/guh commit 9aa0fd3511490674bdd038760abc8729f9e0b023 (external checkout).
- greatscottgadgets/luna commit 82a8f733296603b70ba56755206e13092609c6f0.
- amaranth[builtin-yosys] 0.5.8, parameterized 0.9.0; resolved versions in
  logs/20261021-usb-host-dependencies.log.
- Included licenses cover external core provenance; source repositories retain copyright.

guh is an experimental USB host. This prototype is for a directly attached K230,
not hubs or general USB devices. Enumeration selects CDC data IN endpoint; no
VID/PID whitelist is implemented. The upstream IN path lacks complete receive
DATA PID duplicate validation. Gesture sequence and CRC checks are additional
application protections, not a replacement for USB compliance.

The LUNA fake device reproduces the captured K230 descriptors and CDC endpoints.
It is not K230 firmware, a YOLO model, a physical ULPI model, or proof of live interoperability.
The minimal CDC class request sequence still needs real-device confirmation.
The diagnostic mutes all audio outputs and reports valid gestures over UART;
it is not integrated into the instrument.

The local luna_ulpi_timing.py copy retains LUNA's BSD notice. Only command-data
decode is changed: data_idle keeps control-register ownership but omits DIR;
physical data is tri-stated while DIR is high. Whole-translator equivalence tests
compare every driven data cycle, STP/OE, receive outputs and handshake signals.
The TX queue stores explicit end-of-packet words and removes the combinational
PHY-NXT-to-SIE-ready path, including under long stalls.

Hardware uses rPLL CLKOUTP=315 degrees (PSDA14), duty8. Positive-phase timing
labels wrap after clock-tree insertion: pin outputs use paired setup2/hold1 cycle
assignment to the next physical PHY edge, not an internal multicycle exception.
Input and combinational DIR-to-pin paths remain single-cycle. See the timing note.

Diagnostic UART: 115200 8N1, 9 bytes A6 seq flags confidence pinchBE16 yBE16 XOR8.
flags bit0=active, bit1=CDC ready; remaining bits zero. Periodic health reports
every 2^24 / 60MHz seconds. Consume nonoverlapping 9-byte frames (the final XOR
can also equal A6). Do not write commands to the diagnostic UART.

K230 must run an exclusive binary CDC sender (12-byte A5 5A frames), with IDE
USBDBG/REPL text disabled. The current preview/print program is not that sender.
Confidence threshold remains 60; live low-confidence detections must be corrected
at the vision side rather than inflated or silently accepted.
