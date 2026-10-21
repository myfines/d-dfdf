`timescale 1ns/1ps
// AT +IPD,<0..4>,<1..4096>: payload. Each client has independent Vhh\n
// assembly, so normal TCP fragmentation/coalescing is supported.
module esp_volume_parser #(parameter integer IDLE_TICKS=27000000)(
 input wire clk,reset_n,valid,input wire [7:0] data,output reg update,output reg [7:0] volume);
 reg [3:0] state;reg [2:0] client;reg [12:0] length,left;
 reg [2:0] command[0:4];reg [7:0] value[0:4];reg [31:0] idle;integer i;
 wire digit=data>=48 && data<=57;
 wire hex_digit=digit || (data>=65 && data<=70) || (data>=97 && data<=102);
 wire [3:0] nibble=digit?data[3:0]:data[3:0]+4'd9;
 wire [16:0] next_length=length*17'd10+{13'd0,data[3:0]};
 always @(posedge clk)begin
  if(!reset_n)begin state<=0;client<=0;length<=0;left<=0;idle<=0;update<=0;volume<=255;
   for(i=0;i<5;i=i+1)begin command[i]<=0;value[i]<=0;end end
  else begin
   update<=0;
   if(idle==IDLE_TICKS-1)begin state<=0;idle<=0;for(i=0;i<5;i=i+1)command[i]<=0;end
   else idle<=idle+1'b1;
   if(valid)begin idle<=0;
    case(state)
     0:if(data==43)state<=1;
     1:state<=data==73?2:0;
     2:state<=data==80?3:0;
     3:state<=data==68?4:0;
     4:state<=data==44?5:0;
     5:if(data>=48&&data<=52)begin client<=data[2:0];state<=6;end else state<=0;
     6:if(data==44)begin length<=0;state<=7;end else state<=0;
     7:if(digit && next_length<=4096)length<=next_length[12:0];
       else if(data==58 && length!=0)begin left<=length;state<=8;end
       else begin state<=0;for(i=0;i<5;i=i+1)command[i]<=0;end
     8:begin
      left<=left-1'b1;if(left==1)state<=0;
      case(command[client])
       0:if(data==86)command[client]<=1;else if(data!=10)command[client]<=4;
       1:if(hex_digit)begin value[client]<={nibble,4'd0};command[client]<=2;end else command[client]<=data==10?0:4;
       2:if(hex_digit)begin value[client][3:0]<=nibble;command[client]<=3;end else command[client]<=data==10?0:4;
       3:begin if(data==10)begin volume<=value[client];update<=1;command[client]<=0;end else command[client]<=4;end
       default:if(data==10)command[client]<=0;
      endcase
     end
     default:state<=0;
    endcase
   end
  end
 end
endmodule
