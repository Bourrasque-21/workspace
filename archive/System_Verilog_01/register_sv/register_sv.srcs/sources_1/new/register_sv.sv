`timescale 1ns / 1ps

module register_sv (
    input clk,
    input rst,
    input logic [7:0] wdata,
    output logic [7:0] rdata
);

always_ff @(posedge clk, posedge rst) begin
    if (rst) begin
        rdata <= 0;
    end else begin
        rdata <= wdata;
    end
end

endmodule