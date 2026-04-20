`timescale 1ns / 1ps

module tb_spi_full_duplex ();

    logic       clk;
    logic       rst;
    logic       start;
    logic [7:0] master_tx_data;
    logic [7:0] master_rx_data;
    logic [7:0] slave_tx_data;
    logic [7:0] slave_rx_data;
    logic [7:0] clk_div;
    logic       busy;
    logic       done;
    logic       slave_valid;
    logic       slave_valid_seen;

    logic sclk;
    logic mosi;
    logic miso;
    logic cs_n;

    spi_master u_spi_master (
        .clk    (clk),
        .rst    (rst),
        .start  (start),
        .tx_data(master_tx_data),
        .clk_div(clk_div),
        .rx_data(master_rx_data),
        .busy   (busy),
        .done   (done),
        .cpol   (1'b0),
        .cpha   (1'b0),
        .sclk   (sclk),
        .mosi   (mosi),
        .miso   (miso),
        .cs_n   (cs_n)
    );

    spi_slave u_spi_slave (
        .clk    (clk),
        .rst    (rst),
        .tx_data(slave_tx_data),
        .rx_data(slave_rx_data),
        .valid  (slave_valid),
        .sclk   (sclk),
        .mosi   (mosi),
        .miso   (miso),
        .cs_n   (cs_n)
    );

    always #5 clk = ~clk;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            slave_valid_seen <= 1'b0;
        end else begin
            if (start) begin
                slave_valid_seen <= 1'b0;
            end else if (slave_valid) begin
                slave_valid_seen <= 1'b1;
            end
        end
    end

    task automatic spi_xfer(
        input logic [7:0] master_data,
        input logic [7:0] slave_data,
        input logic [7:0] exp_master_rx,
        input logic [7:0] exp_slave_rx
    );
        begin
            master_tx_data = master_data;
            slave_tx_data  = slave_data;

            @(posedge clk);
            start = 1'b1;
            @(posedge clk);
            start = 1'b0;

            wait (done == 1'b1);
            @(posedge clk);

            if (master_rx_data !== exp_master_rx) begin
                $error("Master read mismatch. expected=%02h actual=%02h", exp_master_rx, master_rx_data);
            end

            if (slave_rx_data !== exp_slave_rx) begin
                $error("Slave write mismatch. expected=%02h actual=%02h", exp_slave_rx, slave_rx_data);
            end

            if (!slave_valid_seen) begin
                $error("Slave valid pulse was not observed at transaction end");
            end
        end
    endtask

    initial begin
        clk            = 1'b0;
        rst            = 1'b1;
        start          = 1'b0;
        master_tx_data = 8'h00;
        slave_tx_data  = 8'h00;
        clk_div        = 8'd4;

        repeat (3) @(posedge clk);
        rst = 1'b0;
        repeat (2) @(posedge clk);

        spi_xfer(8'h3c, 8'ha5, 8'ha5, 8'h3c);
        spi_xfer(8'hc3, 8'h5a, 8'h5a, 8'hc3);

        $display("SPI full-duplex read/write test passed");
        #20;
        $finish;
    end

endmodule
