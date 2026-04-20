`timescale 1ns / 1ps

module instruction_mem (
    input  [31:0] instr_addr,
    output [31:0] instr_data
);

    logic [31:0] rom[0:63];

    initial begin
        // for (int i = 0; i < 32; i++) begin
        //     rom[i] = 32'h00000013;
        // end

        $readmemh(
            "C:/Users/sciab/Desktop/AS/RISC-V/rv32i-multicycle-cpu/rv32i-multicycle-cpu.srcs/sources_1/new/_riscv_rv32i_rom_data.mem",
            rom);

    end

    assign instr_data = rom[instr_addr[31:2]];

endmodule
