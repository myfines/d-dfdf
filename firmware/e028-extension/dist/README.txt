E027_Ext / E028 candidate delivery
=================================

Firmware (not programmed):
  firmware/instrument_e028.fs       main, LINK_MODE=0 (ESP-01S Wi-Fi AT)
  firmware/instrument_e028.bin
  firmware/instrument_e028_ble.fs   BLE-UART, LINK_MODE=1 (top instrument_e028_ble_top)
  firmware/instrument_e028_ble.bin
  firmware/SHA256SUMS.txt

Main build:
  Fmax 32.265 MHz, setup/hold 0/0
  Logic 12845/20736 (62%), CLS 8005/10368 (78%), BSRAM 15/46, DSP 7.5/24

BLE build:
  Fmax 33.487 MHz, setup/hold 0/0

Sources:
  ../src/           current RTL
  ../constraints/   pins + 27 MHz SDC
  ../sim/           ModelSim regression (run_tests.ps1)
  ../docs/          acceptance, design, protocol, test report, board guide
  ../ble-app/       Android BLE controller source + APK

Important:
  * A13/C13 are dedicated READY/DONE on this package. The guide uses four
    on-board LEDs L16/L14/N14/N16, not six.
  * No board/Flash programming, no analog audio measurement, no BLE hardware
    pairing was performed for this candidate.
  * See docs/验收对照表.md for the exact "code/simulation/build/physical"
    status of every extension item.
