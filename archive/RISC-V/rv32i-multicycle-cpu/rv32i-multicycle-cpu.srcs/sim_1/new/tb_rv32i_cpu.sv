`timescale 1ns / 1ps

module tb_rv32i ();
    logic clk;
    logic rst;

    rv32i_top dut (
        .clk(clk),
        .rst(rst)
    );

    always #5 clk = ~clk;


    initial begin
        clk = 0;
        rst = 1;

        @(negedge clk);
        @(negedge clk);

        rst = 0;

        repeat (1200) @(negedge clk);

        $stop;
    end

endmodule
