`timescale 1ns / 1ps

module top_spi (
    input  logic       clk,
    input  logic       rst,
    input  logic       start,
    input  logic [15:0] sw,
    output logic [15:0] led

);

    logic w_sclk, w_mosi, w_miso, w_cs;
    logic [7:0] master_rx_data;
    logic [7:0] slave_rx_data;

    spi_master U_SPI_MASTER (
        .clk(clk),
        .rst(rst),

        // Control
        .start  (start),
        .tx_data(sw[7:0]),
        .clk_div(8'h4),

        .rx_data(master_rx_data),
        .busy   (),
        .done   (),

        .cpol(1'b0),
        .cpha(1'b0),
        // SPI pins
        .sclk(w_sclk),
        .mosi(w_mosi),
        .miso(w_miso),
        .cs_n(w_cs)
    );

    spi_slave U_SPI_SLAVE (
        .clk(clk),
        .rst(rst),

        .tx_data(sw[15:8]),
        .rx_data(slave_rx_data),
        .valid  (),

        .sclk(w_sclk),
        .mosi(w_mosi),
        .miso(w_miso),
        .cs_n(w_cs)
    );

    assign led[7:0]  = slave_rx_data;
    assign led[15:8] = master_rx_data;

endmodule
