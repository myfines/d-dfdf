from pathlib import Path
import re,json,hashlib
root=Path(__file__).resolve().parents[1];private=Path('E:/gaoyun/private/esp-web')
s=(root/'src/instrument_core.v').read_text(encoding='utf-8').replace('module instrument_core #','module instrument_core_integration_probe #',1)
a=s.index('    assign cmd_valid=raw_cmd_valid|http_command;');b=s.index('    esp_command_parser',a)
s=s[:a]+'    integration_sequence stimulus(clk,io_reset_n,frame_tick,cmd_valid,cmd_kind,cmd_value);\n'+s[b:]
s=s.replace("        assign telemetry_capture = 1'b0;",'')
a=s.index('    uart_status monitor(');b=s.index('endmodule',a)
s=s[:a]+'    wire[63:0] oled_probe_state={8\'h50,7\'d0,oled_online,5\'d0,screen,6\'d0,song_gate[guide_note],song_playing,3\'d0,guide_note,6\'d0,page,ui.screen_ui.guide_target,6\'d0,ui.screen_ui.guide_bank};\n    e050_packet_uart export_uart(clk,io_reset_n,telemetry_byte,oled_probe_state,telemetry_index,telemetry_capture,UART_TX);\n\n'+s[b:]
(private/'instrument_core_integration_probe.v').write_text(s,encoding='utf-8')
s=(root/'src/instrument_ap_top.v').read_text(encoding='utf-8').replace('module instrument_ap_top','module integration_probe_top').replace('    assign UART_TX=ESP_RX;','').replace('    instrument_core #','    instrument_core_integration_probe #').replace('.SAFE_STARTUP(1)','.SAFE_STARTUP(0)').replace('.ENABLE_OPTICAL(1)','.ENABLE_OPTICAL(0)').replace('.ENABLE_GESTURE(1)','.ENABLE_GESTURE(0)').replace('.LINK_MODE(LINK_MODE)','.LINK_MODE(1)').replace('.UART_TX(status_tx_unused)','.UART_TX(UART_TX)').replace('.btn_n(btn_n)','.btn_n(4\'hf)').replace('.JOY_SW_N(JOY_SW_N)',".JOY_SW_N(1'b1)")
for port in ['ADC_SCL','ADC_SDA','OPTICAL_SCL','OPTICAL_SDA']:
 s=s.replace(f'.{port}({port})',f'.{port}()');s=s.replace('endmodule',f"assign {port}=1'bz;\nendmodule")
(private/'integration_probe_top.v').write_text(s,encoding='utf-8')
s=(private/'integration_probe_top.v').read_text(encoding='utf-8').replace('.ESP_TX(ESP_TX)','.ESP_TX()').replace('endmodule',"assign ESP_TX=1'bz;\nendmodule")
(private/'integration_probe_top.v').write_text(s,encoding='utf-8')
print('Generated private probe; sources:',hashlib.sha256((root/'src/instrument_core.v').read_bytes()).hexdigest())

s=(root/'src/integration_sequence.v').read_text(encoding='utf-8').replace(' 16:begin valid<=1;kind<=',' 15:begin valid<=1;kind<="S";value<=3;end\n 45000:begin valid<=1;kind<="P";value<=1;end\n 90000:begin valid<=1;kind<="P";value<=0;end\n 16:begin valid<=1;kind<=')
(private/'integration_sequence_e050.v').write_text(s,encoding='utf-8')
