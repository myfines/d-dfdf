"""Generate an SRAM observer without replacing any real input or core logic."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PRIVATE = Path('E:/gaoyun/private/esp-web')


def generate(destination):
    source = (ROOT / 'src/instrument_core.v').read_text(encoding='utf-8')
    start = source.index('    uart_status monitor(')
    core = source[:start].replace('module instrument_core #', 'module instrument_core_live_probe #', 1)
    core += """    // Live observer only: original control/audio logic above is unchanged.
    reg [25:0] observer_time = 0;
    reg [15:0] observer_commands = 0;
    always @(posedge clk) begin
        if(!reset_n) begin observer_time<=0; observer_commands<=0; end
        else begin observer_time<=observer_time+1'b1;
            if(cmd_valid) observer_commands<=observer_commands+1'b1;
        end
    end
    reg [63:0] observer_status;
    always @* case(observer_time[25:23])
        0: observer_status={8'he0,armed,remote_active,controls_valid,adc_error,optical_valid,optical_error,oled_online,gesture_active,4'd0,axis_x,4'd0,axis_y,optical_raw,4'd0,keys_sync};
        1: observer_status={8'he1,gesture_seq,gesture_confidence,6'd0,gesture_pinch,6'd0,gesture_y,gesture_gain};
        2: observer_status={8'he2,expression,brightness,remote_volume,vibrato,2'd0,bend,6'd0,remote_brightness_owned,remote_bend_owned};
        3: observer_status={8'he3,synth_gate,2'd0,voice_count,5'd0,screen,5'd0,fx_on};
        4: observer_status={8'he4,observer_commands,raw_cmd_kind,raw_cmd_value};
        5: observer_status={8'he5,final_l,final_r,2'd0,voice_count,6'd0,page,4'd0,led};
        6: observer_status={8'he6,3'd0,guide_note,2'd0,guide_step,6'd0,song_playing,song_on,6'd0,test_mode,latch_on,8'd0,8'd0,8'd0};
        default: observer_status={8'he7,8'd0,8'd0,4'd0,axis_x,4'd0,axis_y,8'd0};
    endcase
    wire [6:0] observer_index;
    wire observer_capture;
    e050_packet_uart observer_uart(clk, reset_n, 8'd32,
        observer_status,observer_index,observer_capture,UART_TX);
endmodule
"""
    top = (ROOT / 'src/instrument_ap_top.v').read_text(encoding='utf-8')
    top = top.replace('module instrument_ap_top', 'module live_probe_top').replace('    assign UART_TX=ESP_RX;', '').replace('    instrument_core #', '    instrument_core_live_probe #').replace('.UART_TX(status_tx_unused)', '.UART_TX(UART_TX)')
    destination.mkdir(parents=True, exist_ok=True)
    (destination / 'instrument_core_live_probe.v').write_text(core, encoding='utf-8')
    (destination / 'live_probe_top.v').write_text(top, encoding='utf-8')
    build = (ROOT / 'tools/build_e049_ap.tcl').read_text(encoding='utf-8')
    build = build.replace('instrument_e049_ap', 'live_observer_e051').replace('"$root/src/instrument_core.v"', '"$::env(FPGA_WEB_PRIVATE)/instrument_core_live_probe.v"').replace('"$root/src/instrument_ap_top.v"', '"$::env(FPGA_WEB_PRIVATE)/live_probe_top.v"').replace('-top_module instrument_ap_top', '-top_module live_probe_top').replace('0xE049', '0xE051')
    build = build.replace('run all', 'add_file "$root/src/diagnostic_oled_uart.v"\nrun all')
    (ROOT / 'tools/build_live_probe.tcl').write_text(build, encoding='utf-8')
    return {'source_core_sha256': hashlib.sha256((ROOT / 'src/instrument_core.v').read_bytes()).hexdigest()}


if __name__ == '__main__':
    print(json.dumps(generate(PRIVATE)))
