`timescale 1ns / 1ps

module tb_rv32i ();
    logic clk;
    logic rst;

    rv32i_top dut (
        .clk(clk),
        .rst(rst)
    );

    always #5 clk = ~clk;

    always @(negedge clk) begin
        if (!rst) begin
            $display(
                "t=%0t pc=%h instr=%h dwe=%b f3=%03b daddr=%h d_wdata=%0d drdata=%h x1=%0d x2=%0d x5=%0d dmem4=%0d",
                $time,
                dut.instr_addr,
                dut.instr_data,
                dut.dwe,
                dut.funct3_out,
                dut.daddr,
                dut.d_wdata,
                dut.drdata,
                dut.U_RV32I.U_DATAPATH.U_REG_FILE.reg_file[1],
                dut.U_RV32I.U_DATAPATH.U_REG_FILE.reg_file[2],
                dut.U_RV32I.U_DATAPATH.U_REG_FILE.reg_file[5],
                dut.U_DATA_MEM.dmem[4]
            );
        end
    end

    initial begin
        clk = 0;
        rst = 1;

        @(negedge clk);
        @(negedge clk);

        rst = 0;

        repeat (80) @(negedge clk);

        $display("FINAL x1=%0d x2=%0d x5=%0d dmem4=%0d", dut.U_RV32I.U_DATAPATH.U_REG_FILE.reg_file[1], dut.U_RV32I.U_DATAPATH.U_REG_FILE.reg_file[2], dut.U_RV32I.U_DATAPATH.U_REG_FILE.reg_file[5], dut.U_DATA_MEM.dmem[4]);
        $stop;
    end

endmodule
