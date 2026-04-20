`timescale 1ns / 1ps

module tb_spi_top ();

    logic        clk;
    logic        rst;
    logic        start;
    logic [15:0] sw;
    logic [15:0] led;

    top_spi dut (.*);

    always #5 clk = ~clk;

    task automatic spi_send_data(
        input logic [7:0] master_data,
        input logic [7:0] slave_data
    );
        begin
            sw[7:0]  = master_data;
            sw[15:8] = slave_data;
            @(posedge clk);
            start = 1'b1;
            @(posedge clk);
            start = 1'b0;

            wait (dut.U_SPI_MASTER.done == 1'b1);
            @(posedge clk);

            if (led[7:0] !== master_data) begin
                $error("Lower LEDs mismatch. expected=%02h actual=%02h", master_data, led[7:0]);
            end

            if (led[15:8] !== slave_data) begin
                $error("Upper LEDs mismatch. expected=%02h actual=%02h", slave_data, led[15:8]);
            end
        end
    endtask

    initial begin
        clk   = 1'b0;
        rst   = 1'b1;
        start = 1'b0;
        sw    = 16'h0000;

        repeat (3) @(posedge clk);
        rst = 1'b0;
        @(posedge clk);

        sw = 16'h3CAA;
        repeat (5) @(posedge clk);
        if (led !== 16'h0000) begin
            $error("LEDs changed before start. expected=0000 actual=%04h", led);
        end

        spi_send_data(8'haa, 8'h3c);
        spi_send_data(8'h55, 8'hc3);

        $display("top_spi LED mapping test passed");
        #20;
        $finish;
    end

endmodule
