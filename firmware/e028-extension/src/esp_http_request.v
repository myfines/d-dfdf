`timescale 1ns/1ps
// Parse bounded HTTP GET request lines inside ESP AT +IPD frames.
// One browser serializes requests; line parsing survives split TCP payloads.
module esp_http_request(input wire clk,reset_n,valid,input wire[7:0] data,
 output reg request,output reg[2:0] client,output reg[1:0] route,
 output reg command,output reg[7:0] kind,output reg[31:0] value);
 reg[3:0] state;reg[2:0] incoming;reg[15:0] length,left;
 reg[7:0] line[0:63];reg[6:0] count;reg overflow;
 reg[2:0] line_client;integer i,n,expected;reg good;reg[31:0] decoded;
 function ishex;input[7:0] c;begin ishex=(c>="0"&&c<="9")||(c>="A"&&c<="F")||(c>="a"&&c<="f");end endfunction
 function[3:0] nibble;input[7:0] c;begin nibble=c<="9"?c-"0":(c<="F"?c-"A"+10:c-"a"+10);end endfunction
 always @(posedge clk)begin
 if(!reset_n)begin state<=0;incoming<=0;length<=0;left<=0;count<=0;overflow<=0;line_client<=0;request<=0;command<=0;client<=0;route<=0;kind<=0;value<=0;end
 else begin request<=0;command<=0;
 if(valid)case(state)
 0:if(data=="+")state<=1;
 1:state<=data=="I"?2:0;
 2:state<=data=="P"?3:0;
 3:state<=data=="D"?4:0;
 4:state<=data==","?5:0;
 5:if(data>="0"&&data<="4")begin incoming<=data[2:0];state<=6;end else state<=0;
 6:if(data==",")begin length<=0;state<=7;end else state<=0;
 7:if(data>="0"&&data<="9"&&length<6500)length<=length*10+data-"0";
   else if(data==":"&&length!=0)begin left<=length;state<=8;if(line_client!=incoming)begin count<=0;overflow<=0;line_client<=incoming;end end else state<=0;
 8:begin
   left<=left-1'b1;if(left==1)state<=0;
   if(data==10)begin
    if(!overflow && count>=14 && line[0]=="G"&&line[1]=="E"&&line[2]=="T"&&line[3]==" "&&line[4]=="/")begin
     request<=1;client<=incoming;route<=0;
     if(line[5]=="c"&&line[6]=="/")begin
      route<=1;expected=2;
      case(line[7]) "M":expected=8;"B":expected=4;"V","T","E","K","P","Q","L","X","Y","F","S","R","H","D":expected=2;default:expected=0;endcase
      decoded=0;good=expected!=0;
      for(i=0;i<8;i=i+1)if(i<expected)begin if(!ishex(line[8+i]))good=0;decoded=(decoded<<4)|nibble(line[8+i]);end
      if(line[8+expected]!=" ")good=0;
      if(good)begin command<=1;kind<=line[7];value<=decoded;end else route<=3;
     end else if(line[5]=="s")route<=2;
     else if(line[5]!=" ")route<=3;
    end
    count<=0;overflow<=0;
   end else if(data!=13)begin if(count<64)begin line[count]<=data;count<=count+1'b1;end else overflow<=1;end
  end
 default:state<=0;
 endcase
 end end
endmodule
