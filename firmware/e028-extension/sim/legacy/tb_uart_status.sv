`timescale 1ns/1ps
module tb_uart_status;
    reg clk=0,reset_n=0;always #5 clk=~clk;
    reg valid=1,error=0,scl=1,sda=1;
    reg [11:0] x=12'h339,y=12'habc;
    reg [3:0] keys=4'he;
    wire tx;
    uart_status #(.BAUD_TICKS(4),.PERIOD_TICKS(200)) dut(clk,reset_n,valid,error,x,y,keys,scl,sda,tx);
    reg [7:0] got;
    reg [215:0] expected={"IO V1 E0 X339 YABC KE S11",8'h0d,8'h0a};
    integer i,n;
    task byte_read;
        begin
            @(negedge tx);#60; // 1.5 bit periods, center of data bit 0.
            for(i=0;i<8;i=i+1)begin got[i]=tx;#40;end
            if(tx!==1)$fatal(1,"UART stop bit invalid");
        end
    endtask
    initial begin
        repeat(5)@(negedge clk);reset_n=1;
        for(n=0;n<27;n=n+1)begin
            byte_read();if(got!==expected[215-n*8 -: 8])$fatal(1,"UART byte %0d mismatch: %02x",n,got);
            if(n==2)begin valid=0;error=1;x=0;y=0;keys=15;scl=0;sda=0;end
        end
        $display("PASS UART: baud/framing and coherent readable snapshot");$finish;
    end
    initial begin #100000;$fatal(1,"UART timeout");end
endmodule
