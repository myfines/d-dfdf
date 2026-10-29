`timescale 1ns/1ps
// Short mono monitoring recording of live post-FX PCM. No prerecorded playback.
// 4096 signed8 samples, boxcar8, rate46875/8Hz, ~699ms; A packet96bytes.
module pcm_record #(parameter integer LENGTH=4096,DECIMATE=8)(
 input wire clk,reset_n,frame_tick,input wire signed[15:0] sample,
 input wire cmd_valid,input wire[7:0] cmd_kind,input wire[31:0] cmd_value,
 input wire capture,input wire[6:0] index,output reg record_mode,output reg[7:0] data,
 input wire[6:0] score_length,input wire score_ready,adsr_enabled,input wire[19:0] adsr_config,input wire[159:0] key_mapping);
 reg signed[7:0] memory[0:LENGTH-1];
 reg[7:0] score_length_hold,map_note_hold;reg score_ready_hold,adsr_enabled_hold;reg[19:0]adsr_hold;
 reg busy,ready;reg[12:0] written;reg[3:0] divider;
 reg signed[19:0] accumulator;
 wire signed[19:0] combined=accumulator+{{4{sample[15]}},sample};
 reg[15:0] recording_id,id_hold,checksum;
 reg[6:0] selected_chunk,chunk_hold;reg[7:0]flags_hold;
 reg[7:0]snapshot[0:31];reg[11:0] read_address;reg[7:0]read_data;
 reg[1:0]fetch_state;reg[4:0]fetch_index;
 wire check_ok=cmd_value[7:0]==(cmd_value[31:24]^cmd_value[23:16]^cmd_value[15:8]);
 function[7:0] hexchar;input[3:0]v;begin hexchar=v<10?48+v:55+v;end endfunction
 integer k;
 always @*begin
 data="0";
 if(index==0)data="A";
 else if(index<5)data=hexchar(id_hold>>((4-index)*4));
 else if(index<7)data=hexchar(chunk_hold>>((6-index)*4));
 else if(index<9)data=hexchar(flags_hold>>((8-index)*4));
 else if(index<13)data=hexchar(LENGTH>>((12-index)*4));
 else if(index<15)data=hexchar(DECIMATE>>((14-index)*4));
 else if(index==15)data=hexchar(score_length_hold[7:4]);
 else if(index==16)data=hexchar(score_length_hold[3:0]);
 else if(index==17)data=score_ready_hold?"1":"0";
 else if(index==18)data=hexchar(map_note_hold[7:4]);
 else if(index==19)data=hexchar(map_note_hold[3:0]);
 else if(index>=20 && index<84)data=hexchar(index[0]?snapshot[(index-20)>>1][3:0]:snapshot[(index-20)>>1][7:4]);
 else if(index>=84 && index<88)data=hexchar(checksum>>((87-index)*4));
 else if(index==88)data=adsr_enabled_hold?"1":"0";
 else if(index>=89 && index<94)data=hexchar(adsr_hold>>((93-index)*4));
 else if(index==94)data="1"; // packet metadata version
 else if(index==95)data=10;
 end
 // Single synchronous read port allows recording memory to infer block RAM.
 always @(posedge clk)read_data<=memory[read_address];
 always @(posedge clk)begin
 if(!reset_n)begin
 score_length_hold<=0;map_note_hold<=0;score_ready_hold<=0;adsr_enabled_hold<=0;adsr_hold<=0;
 busy<=0;ready<=0;written<=0;divider<=0;accumulator<=0;recording_id<=0;record_mode<=0;
 selected_chunk<=0;chunk_hold<=0;flags_hold<=0;id_hold<=0;checksum<=0;read_address<=0;fetch_state<=0;fetch_index<=0;
 for(k=0;k<32;k=k+1)snapshot[k]<=0;
 end else begin
 if(cmd_valid && cmd_kind=="C")begin
 if(cmd_value==0)record_mode<=0;
 else if(cmd_value[31:24]==16 && check_ok)begin
 if(cmd_value[23:16]==1 && cmd_value[15:8]==0 && !busy)begin
 record_mode<=1;busy<=1;ready<=0;written<=0;divider<=0;accumulator<=0;recording_id<=recording_id+1'b1;selected_chunk<=0;
 end else if(cmd_value[23:16]==2 && cmd_value[15:8]<LENGTH/32)begin record_mode<=1;selected_chunk<=cmd_value[14:8];end
 end end
 if(frame_tick && busy)begin
 if(divider==DECIMATE-1)begin
 memory[written[11:0]]<=combined>>>($clog2(DECIMATE)+8);
 divider<=0;accumulator<=0;
 if(written==LENGTH-1)begin busy<=0;ready<=1;end else written<=written+1'b1;
 end else begin divider<=divider+1'b1;accumulator<=combined;end
 end
 if(capture && fetch_state==0)begin
 score_length_hold<={1'b0,score_length};score_ready_hold<=score_ready;adsr_enabled_hold<=adsr_enabled;adsr_hold<=adsr_config;
 map_note_hold<=selected_chunk<32?{3'd0,key_mapping[selected_chunk*5+:5]}:8'hff;
 id_hold<=recording_id;chunk_hold<=selected_chunk;flags_hold<=ready?2:(busy?1:0);
 checksum<=0;read_address<={selected_chunk,5'd0};fetch_index<=0;fetch_state<=1;
 end else case(fetch_state)
 1:fetch_state<=2;
 2:begin
 snapshot[fetch_index]<=flags_hold==2?read_data:0;
 checksum<=checksum+(flags_hold==2?{8'd0,read_data}:16'd0);
 if(fetch_index==31)fetch_state<=0;
 else begin fetch_index<=fetch_index+1'b1;read_address<=read_address+1'b1;fetch_state<=1;end
 end
 endcase
 end end
endmodule
