`timescale 1ns / 1ps

module demo_i2c_slave (
    input  logic       clk,
    input  logic       rst,
    input  logic [7:0] data_sw,
    input  logic       scl,
    inout  wire        sda,
    output logic [7:0] led
);

    logic [7:0] slave_rx_data;
    logic       slave_valid;

    I2C_Slave u_i2c_slave (
        .clk    (clk),
        .rst    (rst),
        .tx_data(data_sw),
        .rx_data(slave_rx_data),
        .busy   (),
        .valid  (slave_valid),
        .scl    (scl),
        .sda    (sda)
    );

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            led <= 8'h00;
        end else if (slave_valid) begin
            led <= slave_rx_data;
        end
    end

endmodule