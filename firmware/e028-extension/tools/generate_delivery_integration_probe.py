from pathlib import Path
import re,json,hashlib
root=Path(__file__).resolve().parents[1];private=Path('E:/gaoyun/private/esp-web')
s=(root/'src/instrument_core.v').read_text().replace('module instrument_core #','module instrument_core_integration_probe #',1)
a=s.index('    assign cmd_valid=raw_cmd_valid|http_command;');b=s.index('    esp_command_parser',a)
s=s[:a]+'    integration_sequence stimulus(clk,io_reset_n,frame_tick,cmd_valid,cmd_kind,cmd_value);\n'+s[b:]
s=s.replace("        assign telemetry_capture = 1'b0;",'')
a=s.index('    uart_status monitor(');b=s.index('endmodule',a)
s=s[:a]+'    diagnostic_packet_uart export_uart(clk,io_reset_n,telemetry_byte,telemetry_index,telemetry_capture,UART_TX);\n\n'+s[b:]
(private/'instrument_core_integration_probe.v').write_text(s)
s=(root/'src/instrument_ap_top.v').read_text().replace('module instrument_ap_top','module integration_probe_top').replace('    assign UART_TX=ESP_RX;','').replace('    instrument_core #','    instrument_core_integration_probe #').replace('.SAFE_STARTUP(1)','.SAFE_STARTUP(0)').replace('.ENABLE_OPTICAL(1)','.ENABLE_OPTICAL(0)').replace('.ENABLE_GESTURE(1)','.ENABLE_GESTURE(0)').replace('.LINK_MODE(LINK_MODE)','.LINK_MODE(1)').replace('.UART_TX(status_tx_unused)','.UART_TX(UART_TX)').replace('.btn_n(btn_n)','.btn_n(4\'hf)').replace('.JOY_SW_N(JOY_SW_N)',".JOY_SW_N(1'b1)")
for port in ['ADC_SCL','ADC_SDA','OPTICAL_SCL','OPTICAL_SDA','OLED_SCL','OLED_SDA']:
 s=s.replace(f'.{port}({port})',f'.{port}()');s=s.replace('endmodule',f"assign {port}=1'bz;\nendmodule")
(private/'integration_probe_top.v').write_text(s)
s=(private/'integration_probe_top.v').read_text().replace('.ESP_TX(ESP_TX)','.ESP_TX()').replace('endmodule',"assign ESP_TX=1'bz;\nendmodule")
(private/'integration_probe_top.v').write_text(s)
print('Generated private probe; sources:',hashlib.sha256((root/'src/instrument_core.v').read_bytes()).hexdigest())
