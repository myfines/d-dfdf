# K230 USB HS host prototype — NOT a deployable instrument release

Independent host diagnostic, usercode E024. Current instrument Flash E023 is untouched.
The hardware build has **9 setup and 17 hold violations** with USB3317 I/O delays.
Do not program the generated bitstream or treat successful synthesis as timing closure.

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
iverilog -g2012 -s tb_probe_report -o E:/gaoyun/tools/smoke/usb-probe-report.vvp usb_host/tb_probe_report.sv usb_host/host_probe_top.v instrument_io/gesture_packet_rx.v instrument_io/uart8n1.v
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

K230 must run an exclusive binary CDC sender (12-byte A5 5A frames), with IDE
USBDBG/REPL text disabled. The current preview/print program is not that sender.
Confidence threshold remains 60; live low-confidence detections must be corrected
at the vision side rather than inflated or silently accepted.
