`timescale 1ns / 1ps

module rv32i_top (
    input clk,
    input rst
);

    logic [31:0] instr_addr, instr_data, d_wdata, drdata, daddr;
    logic [2:0] funct3_out;
    logic dwe;

    instruction_mem U_INSTRUCTION_MEM (.*);
    rv32i_cpu U_RV32I (
        .*,
        .funct3_out(funct3_out)
    );
    data_mem U_DATA_MEM (
        .*,
        .funct3_in(funct3_out)
    );

endmodule