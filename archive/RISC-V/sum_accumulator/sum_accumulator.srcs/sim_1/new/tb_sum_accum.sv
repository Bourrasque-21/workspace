`timescale 1ns / 1ps


module tb_sum_accum ();

    logic clk, rst;
    logic [7:0] out;

    sum_accumulator dut (
        .clk(clk),
        .rst(rst),
        .out(out)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;
        #20;
        rst = 0;

        #400;
        $stop;
    end
endmodule
