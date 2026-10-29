# E039: restore local ESP AP control

User authorized restoring local ESP Wi-Fi and using probes for future debugging. FPGA AP top disables ENABLE_WEB_RELAY while preserving E038 audio changes. ESP itself is not reflashed. AT sequence: CWMODE_CUR=2; CWSAP_CUR public demo AP; CIPMUX=1; CIPSERVER=1,9000. No host network switch.

Build: 28.117 MHz Fmax against 27 MHz, setup/hold TNS zero. Focused simulations tb_esp_at, tb_core, tb_control_wiring, tb_performance_controls passed.

Official operation37 at 2.5 MHz, SPI address0: Program and Verify flash successfully, 100%. Immediate independent op73 returned0000 and nonzero exit. No E039 boot claim; full coldboot and AP discovery remain pending. No repeated Flash writes. Raw logs retained. Companion 0.8 uses actual reference UI and direct TCP protocol, stores local settings.
