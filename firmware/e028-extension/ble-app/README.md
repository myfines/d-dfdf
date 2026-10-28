# FPGA BLE companion (E027/E028)

Minimal, self-contained Android app for controlling the E027/E028 FPGA
instrument over a transparent BLE-UART module. It is a single Activity plus a
small BLE controller, a custom multi-touch piano view, and a pure-Java command
builder. No Gradle, no AndroidX, no third-party libraries.

**Status: build and signature verification only. Hardware BLE testing was not
performed.** No E027/E028 board, BLE module, or Android device was available in
the build environment. Do not read the build result as a hardware validation.

## Contents

- `AndroidManifest.xml` - package `com.fpga.instrument.ble`, minSdk 26, targetSdk 32
- `src/com/fpga/instrument/ble/Protocol.java` - ASCII command formatting
- `src/com/fpga/instrument/ble/BleController.java` - scan, connect, GATT, write queue
- `src/com/fpga/instrument/ble/PianoView.java` - 8-key multi-touch view
- `src/com/fpga/instrument/ble/MainActivity.java` - dark single-screen UI
- `tests/ProtocolTest.java` - desktop-JVM protocol tests
- `res/` - dark theme, colors, launcher icon
- `build.ps1` - offline aapt/d8/zipalign/apksigner build
- `dist/FPGA-BLE.apk` - debug APK (produced by `build.ps1`)
- `debug.keystore` - local debug key generated on first build

## Build

The build uses the same offline toolchain as
`E:\DS working space\fpga-instrument-app\build.ps1`:

- JDK 17: `D:\MCLDownload\ext\jre-v64-220420\jdk17`
- Android SDK: `E:\DS working space\android-sdk`
- build-tools 34.0.0, platform android-34

From this directory:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1
```

If the toolchain is somewhere else, pass it explicitly:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 `
  -Jdk "D:\path\to\jdk17" -Sdk "D:\path\to\android-sdk"
```

The script:

1. compiles and runs `ProtocolTest` (57 checks) on the desktop JVM;
2. compiles the app with `javac -source 8 -target 8` against `android.jar`;
3. dexes with `d8 --min-api 26`;
4. packages with `aapt`, adds `classes.dex`;
5. aligns with `zipalign -f 4`;
6. signs with `apksigner` using `debug.keystore` (alias `androiddebugkey`,
   password `android`) and v1/v2/v3 flags;
7. runs `apksigner verify --verbose --print-certs`;
8. prints the APK path, byte size, and SHA-256.

Output filename is ASCII on purpose: `dist/FPGA-BLE.apk`.

## Install

```powershell
adb install -r "E:\DS working space\E027_Ext\ble-app\dist\FPGA-BLE.apk"
```

Or copy `FPGA-BLE.apk` to the phone and open it, allowing "install unknown
apps" for the file manager. The APK is debug-signed; it is not a Play Store
release and the debug key is not a secret.

Supported Android versions: 8.0 (API 26) and newer. targetSdk 32 is deliberate
and matches the existing instrument app.

## Pairing and module setup

1. Power the FPGA and the BLE-UART module. The FPGA must be built with
   `LINK_MODE=1` (transparent BLE-UART mode), not the ESP-01S AT/TCP mode.
2. Configure the module's UART side for **115200 8N1**, transparent
   transmission, no AT framing. This is done once with the module vendor's
   serial tool; the app cannot change it.
3. Do **not** pair the module in Android Settings first. This app scans and
   connects through GATT directly. Some modules show a PIN dialog only if the
   OS insists on pairing (HM-10 clones often use `123456`); most JDY/HM-10
   modules need no OS-level pairing.
4. Open the app, grant the requested permission, tap **SCAN**, wait for the
   module to appear, then tap its row.
5. The top chip changes to `READY` and the performance page appears. Use
   **DISCONNECT** before scanning for a different module.

Wiring is the existing E027 serial header: module TX to the FPGA RX pin, module
RX to the FPGA TX pin, common ground, module powered from the board's 3.3 V
rail as appropriate. The app only sends ASCII; it does not drive any GPIO.

Important: this is a **BLE GATT** app. A module that is operating in
classic-Bluetooth SPP-only mode (some HC-05/JDY-31 configurations) will not
appear as a GATT peripheral. Use its BLE mode or an HM-10/CC41/AT-09/NUS
module.

## Supported GATT UUIDs

The app checks the HM-10/JDY service first, then Nordic UART.

| Transport | Service | Write characteristic | Notify characteristic |
|---|---|---|---|
| HM-10 / JDY / CC41 / AT-09 | `0000ffe0-0000-1000-8000-00805f9b34fb` | `0000ffe1-0000-1000-8000-00805f9b34fb` | same FFE1 characteristic |
| Nordic UART (NUS) | `6e400001-b5a3-f393-e0a9-e50e24dcca9e` | `6e400002-b5a3-f393-e0a9-e50e24dcca9e` | `6e400003-b5a3-f393-e0a9-e50e24dcca9e` |

For FFE1, the characteristic is used for both writes and notifications when
the module exposes notify/indicate. For NUS, RX is written and TX is notified.
The standard CCCD `00002902-0000-1000-8000-00805f9b34fb` is enabled when
present. If notification setup fails, the app keeps working in write-only mode
and shows the failure in the status line. Received notification bytes are shown
as hex plus a printable-ASCII preview in the bottom-right `RX` line.

## Command protocol

All commands are ASCII, upper-case hex is used by the app, and every line ends
with exactly one LF (`0x0A`). The FPGA parser accepts only the expected number
of hex digits. The format below is the exact wire format.

| Command | Meaning | Value range / format | Example |
|---|---|---|---|
| `Vxx` | Master volume | `00`..`FF` (0..255) | `V80` |
| `Txx` | Timbre | `00` EPiano, `01` Organ, `02` Strings, `03` Bass | `T02` |
| `Kxx` | 8-bit key mask on current page; bit j = key j | `00`..`FF` | `K81` |
| `Pxx` | Page | `00`..`03` | `P02` |
| `Fxx` | FX bitmap | bit0 chorus, bit1 delay, bit2 reverb (`00`..`07`) | `F05` |
| `Mxxxxxxxx` | Direct 32-note mask | exactly 8 hex digits | `MFFFFFFFF` |
| `Bxxxx` | Pitch bend | `0000`..`3FFF`, `2000` = centre (8192 decimal) | `B2000` |
| `Xxx` | Vibrato depth | `00`..`FF` | `X40` |
| `Yxx` | Brightness | `00`..`FF` | `Y80` |
| `Sxx` | OLED screen | `00`..`04` | `S03` |
| `Rxx` | Offline song | `00` off, `01` on | `R01` |
| `Hxx` | Latch | `00` off, `01` on | `H01` |
| `Dxx` | 32-voice demonstration chord | `00` off, `01` on | `D01` |
| `Q00` | Keepalive (renews the remote-control lease) | fixed `00` | `Q00` |
| `L00` | Release remote control, clear remote state | fixed `00` | `L00` |
| `Exx` | Legacy E027 reverb alias (older firmware) | `00`/`01` | `E01` |

Notes:

- `F` bit order is the firmware order from `fx_engine.v`:
  `{reverb, delay, chorus}` describes the set, while the bitmap bits are
  `chorus=0`, `delay=1`, `reverb=2`. Thus `F01` is chorus only, `F04` is
  reverb only, `F07` is all three.
- `K` bit 0 is the left-most key (C5) and bit 7 is C6.
- The FPGA parser also accepts lower-case hex and ignores CR, but this app
  always sends upper case and LF.
- The firmware parser only commits a command when the digit count matches:
  2 digits for V/T/K/P/F/X/Y/S/R/H/D/E, 4 for B, 8 for M.

## UI controls

Performance page:

- **8 piano keys** C5, D5, E5, F5, G5, A5, B5, C6. Multi-touch is supported;
  pressing/releasing/sliding updates the bitmask and sends `Kxx`. Labels show
  the note and the key index (`K0`..`K7`).
- **VOL** seekbar 0..255 sends `Vxx` (throttled while dragging, final value on
  release).
- **TIMBRE** buttons EPiano / Organ / Strings / Bass send `T00`..`T03`.
- **FX** toggles Chorus / Delay / Reverb send the combined `Fxx` bitmap.
- **PAGE** buttons P0..P3 send `Pxx`; switching page also clears the key mask
  with `K00` before `Pxx`.
- **PLAY** row: `SONG` sends `R01`/`R00`, `LATCH` sends `H01`/`H00`,
  `STRESS` sends `MFFFFFFFF` and automatically sends `M00000000` after 2 s;
  pressing it again clears immediately. `MORE` opens the extra controls.
- **ALL NOTES OFF** sends `K00` and `M00000000`.
- Footer shows the last user command (`LAST`) and the last notification
  (`RX`). Keepalives do not overwrite `LAST`.
- Header shows the link chip (`IDLE`, `SCAN`, `LINK`, `READY`, `ERROR`), the
  connected device name/address, and a one-line error/status message.

More controls dialog (all send immediately, except sliders on release):

- Pitch bend `B0000`..`B3FFF` with a CENTRE button (`B2000`).
- Vibrato `X00`..`XFF`.
- Brightness `Y00`..`YFF`.
- OLED screen buttons `S00`..`S04`.
- `D01`/`D00` 32-voice demo toggle.

Controls are disabled until the GATT link is ready. Every command send is
checked; when disconnected the status line shows a visible error instead of
silently dropping the request.

## Android permissions

| Android version | Runtime permissions requested | Notes |
|---|---|---|
| 12+ (API 31+) | `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT` | `BLUETOOTH_SCAN` is declared with `neverForLocation`, so location is not requested. |
| 8.0..11 (API 26..30) | `ACCESS_FINE_LOCATION` | Required by Android for BLE scan results. System location must also be enabled; the app offers a Settings shortcut. |

`BLUETOOTH` and `BLUETOOTH_ADMIN` are declared with `maxSdkVersion=30` for the
legacy path. The app never uses location for anything except satisfying the
legacy scan requirement.

## BLE behavior and reliability

- Scan is unfiltered and runs for up to 20 seconds. Named UART-like modules are
  tagged `UART`; all BLE devices are still listed so an unusual module name
  can be selected.
- Services are resolved by the UUID pairs above. If neither is present, the
  app reports "No supported UART service" and closes the link.
- Writes are serialized through a small queue. The app uses write-with-response
  when the characteristic advertises `PROPERTY_WRITE`, otherwise write without
  response. A rejected write is retried up to three times.
- MTU is not changed; every command is at most 10 bytes including LF, well
  below the default 20-byte payload.
- A `Q00` keepalive is sent every 2 seconds while ready, matching the FPGA
  remote lease. `L00` is attempted on disconnect and on Activity shutdown.
- Disconnect, service-discovery failure, 133-style link loss, write timeout,
  write rejection, and CCCD failure are all surfaced in the status line/notice.
- The app does not auto-reconnect. This is deliberate: after a link loss, tap
  CONNECT and select the device again.

## Troubleshooting

- **No devices in the list**: grant Nearby devices (Android 12+) or Location
  (Android 11 and below); turn on Bluetooth and system location (legacy);
  make sure the module is advertising as BLE, not classic SPP.
- **Device appears but connect fails / status 133**: move closer, toggle the
  phone's Bluetooth, power-cycle the module, and retry. Avoid scanning while
  connected; disconnect first.
- **Connected but "No supported UART service"**: the module is not exposing
  FFE0/FFE1 or NUS. Confirm it is a BLE-UART module and that its BLE GATT
  profile is enabled.
- **READY but no sound**: the FPGA must be built with `LINK_MODE=1`; check
  module TX/RX crossover, common ground, 115200 8N1, and that the FPGA is in
  remote-control range (send any command, then `Q00` keeps the lease alive).
- **Keys stick**: tap ALL NOTES OFF (`K00` + `M00000000`), or disconnect and
  reconnect. The firmware also clears remote state on `L00`.
- **Notifications show but writes fail**: the module may still be in AT mode.
  Reset it to transparent mode; the app never sends AT commands.

## Verification

`build.ps1` fails the build if any step fails, including desktop protocol
tests, dexing, packaging, and `apksigner verify`. It prints the final size and
SHA-256. This checkout was built with:

- package `com.fpga.instrument.ble`, versionCode 1, versionName 1.0
- minSdk 26, targetSdk 32
- debug APK at `dist/FPGA-BLE.apk`
- `apksigner verify` passed with APK Signature Scheme v2 and v3

**Hardware BLE testing was not performed.** The app was not run on a phone and
was not connected to an E027/E028 board or a BLE module. The build and
signature checks are the only validation performed here.
