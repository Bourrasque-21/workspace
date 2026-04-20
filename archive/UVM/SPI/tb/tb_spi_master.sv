`timescale 1ns / 1ps

module tb_spi_master ();
    logic       clk;
    logic       rst;
    logic       start;
    logic [7:0] tx_data;
    logic [7:0] clk_div;

    logic [7:0] rx_data;
    logic       done;
    logic       busy;

    logic       cpol;
    logic       cpha;

    logic       sclk;
    logic       mosi;
    logic       miso;
    logic       cs_n;

    spi_master dut (.*);

    always #5 clk = ~clk;

    assign miso = mosi;

    task spi_set_mode(logic [1:0] mode);
        {cpol, cpha} = mode;
        @(posedge clk);
    endtask  //spi_set_mode

    task spi_send_data(logic [7:0] data);
        tx_data = data;
        start   = 1'b1;
        @(posedge clk);
        start = 1'b0;
        @(posedge clk);
        wait (done);
        @(posedge clk);
    endtask  //spi_send

    initial begin
        clk = 0;
        rst = 1;
        repeat (3) @(posedge clk);
        rst = 0;
        @(posedge clk);
        clk_div = 4;  // sclk = 10MHz : (100MHz / (10MHz * 2)) - 1
        //miso = 1'b0;
        @(posedge clk);

        spi_set_mode(0);
        spi_send_data(8'haa);

        spi_set_mode(1);
        spi_send_data(8'haa);

        spi_set_mode(2);
        spi_send_data(8'haa);

        spi_set_mode(3);
        spi_send_data(8'haa);

        @(posedge clk);
        #20;
        $stop;
    end
endmodule
