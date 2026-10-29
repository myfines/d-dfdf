"""Generate a private diagnostic copy; add read-only voice12 outputs only."""
from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parents[1]
private=Path('E:/gaoyun/private/esp-web')
s=(root/'src/synth32.v').read_text()
assert s.count('module synth32(')==1
s=s.replace('module synth32(','module synth32_envelope_probe(',1)
s=s.replace('input wire [19:0]        adsr_config','input wire [19:0]        adsr_config,\n    output wire [15:0] debug_level,\n    output wire [2:0] debug_state',1)
s=s.replace('endmodule','assign debug_level=env_level[12];\nassign debug_state=env_state[12];\nendmodule')
(private/'synth32_envelope_probe.v').write_text(s)
print(json.dumps({'source_sha256':hashlib.sha256((root/'src/synth32.v').read_bytes()).hexdigest(),'diagnostic_sha256':hashlib.sha256((private/'synth32_envelope_probe.v').read_bytes()).hexdigest()}))
top=(root/'src/audio_adsr_top.v').read_text().replace('module audio_adsr_top','module audio_adsr_uart_top').replace('E03B','E03C')
top=top.replace('synth32 synth','wire [15:0] debug_level; wire [2:0] debug_state;\n synth32_envelope_probe synth')
top=top.replace('.adsr_config(config_value));','.adsr_config(config_value),.debug_level(debug_level),.debug_state(debug_state));')
top=top.replace("assign ESP_TX=1'bz;assign UART_TX=1'b1;",'assign ESP_TX=1\'bz; envelope_telemetry telemetry(clk,reset_n,slot,debug_level,debug_state,UART_TX);')
(private/'audio_adsr_uart_top.v').write_text(top)
