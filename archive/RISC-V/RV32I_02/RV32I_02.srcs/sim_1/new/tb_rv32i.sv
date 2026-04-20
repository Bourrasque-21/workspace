`timescale 1ns / 1ps
// `include "_define.vh"

module tb_rv32i ();
    logic clk;
    logic rst;

    rv32i_top dut (
        .clk(clk),
        .rst(rst)
    );

    always #5 clk = ~clk;

    function automatic string decode_op(input logic [31:0] instr);
        begin
            unique case (instr[6:0])
                `R_TYPE: begin
                    unique case ({instr[31:25], instr[14:12]})
                        {7'b0000000, 3'b000}: decode_op = "add";
                        {7'b0100000, 3'b000}: decode_op = "sub";
                        {7'b0000000, 3'b001}: decode_op = "sll";
                        {7'b0000000, 3'b010}: decode_op = "slt";
                        {7'b0000000, 3'b011}: decode_op = "sltu";
                        {7'b0000000, 3'b100}: decode_op = "xor";
                        {7'b0000000, 3'b101}: decode_op = "srl";
                        {7'b0100000, 3'b101}: decode_op = "sra";
                        {7'b0000000, 3'b110}: decode_op = "or";
                        {7'b0000000, 3'b111}: decode_op = "and";
                        default: decode_op = "r-unk";
                    endcase
                end
                `S_TYPE: begin
                    unique case (instr[14:12])
                        `SB:   decode_op = "sb";
                        `SH:   decode_op = "sh";
                        `SW:   decode_op = "sw";
                        default: decode_op = "s-unk";
                    endcase
                end
                `B_TYPE: begin
                    unique case (instr[14:12])
                        3'b000:  decode_op = "beq";
                        3'b001:  decode_op = "bne";
                        3'b100:  decode_op = "blt";
                        3'b101:  decode_op = "bge";
                        3'b110:  decode_op = "bltu";
                        3'b111:  decode_op = "bgeu";
                        default: decode_op = "b-unk";
                    endcase
                end
                `JAL_TYPE:  decode_op = "jal";
                `JALR_TYPE: decode_op = "jalr";
                `LUI_TYPE: decode_op = "lui";
                `AUIPC_TYPE: decode_op = "auipc";
                `I_TYPE: begin
                    unique case (instr[14:12])
                        3'b000:  decode_op = "addi";
                        3'b001:  decode_op = "slli";
                        3'b010:  decode_op = "slti";
                        3'b011:  decode_op = "sltiu";
                        3'b100:  decode_op = "xori";
                        3'b101:  decode_op = (instr[30]) ? "srai" : "srli";
                        3'b110:  decode_op = "ori";
                        3'b111:  decode_op = "andi";
                        default: decode_op = "i-unk";
                    endcase
                end
                `IL_TYPE: begin
                    unique case (instr[14:12])
                        `LB:   decode_op = "lb";
                        `LH:   decode_op = "lh";
                        `LW:   decode_op = "lw";
                        `LBU:  decode_op = "lbu";
                        `LHU:  decode_op = "lhu";
                        default: decode_op = "il-unk";
                    endcase
                end
                default: decode_op = "other";
            endcase
        end
    endfunction

    function automatic logic [31:0] rf_value(input logic [4:0] idx);
        begin
            if (idx == 5'd0) rf_value = 32'd0;
            else rf_value = dut.U_RV32I.U_DATAPATH.U_REG_FILE.reg_file[idx];
        end
    endfunction

    function automatic logic signed [31:0] imm_i_value(input logic [31:0] instr);
        begin
            imm_i_value = {{20{instr[31]}}, instr[31:20]};
        end
    endfunction

    function automatic logic signed [31:0] imm_s_value(input logic [31:0] instr);
        begin
            imm_s_value = {{20{instr[31]}}, instr[31:25], instr[11:7]};
        end
    endfunction

    function automatic logic signed [31:0] imm_b_value(input logic [31:0] instr);
        begin
            imm_b_value = {
                {19{instr[31]}},
                instr[31],
                instr[7],
                instr[30:25],
                instr[11:8],
                1'b0
            };
        end
    endfunction

    function automatic logic [31:0] imm_u_value(input logic [31:0] instr);
        begin
            imm_u_value = {instr[31:12], 12'b0};
        end
    endfunction

    function automatic logic signed [31:0] imm_j_value(input logic [31:0] instr);
        begin
            imm_j_value = {
                {11{instr[31]}},
                instr[31],
                instr[19:12],
                instr[20],
                instr[30:21],
                1'b0
            };
        end
    endfunction

    always @(posedge clk) begin
        if (!rst) begin
            logic [31:0] instr_now;
            logic [31:0] rs1_val;
            logic [31:0] rs2_val;
            logic [31:0] wb_val;
            logic signed [31:0] imm_i_val;
            logic signed [31:0] imm_s_val;
            logic signed [31:0] imm_b_val;
            logic [31:0] imm_u_val;
            logic signed [31:0] imm_j_val;
            logic [ 4:0] rs1_idx;
            logic [ 4:0] rs2_idx;
            logic [ 4:0] rd_idx;
            logic [ 4:0] shamt_val;
            logic [31:0] next_pc_val;
            logic branch_taken;

            instr_now = dut.instr_data;
            rs1_idx   = instr_now[19:15];
            rs2_idx   = instr_now[24:20];
            rd_idx    = instr_now[11:7];
            rs1_val   = rf_value(rs1_idx);
            rs2_val   = rf_value(rs2_idx);
            wb_val    = dut.U_RV32I.U_DATAPATH.dmem_data_result;
            imm_i_val = imm_i_value(instr_now);
            imm_s_val = imm_s_value(instr_now);
            imm_b_val = imm_b_value(instr_now);
            imm_u_val = imm_u_value(instr_now);
            imm_j_val = imm_j_value(instr_now);
            shamt_val = instr_now[24:20];
            next_pc_val = dut.U_RV32I.U_DATAPATH.pc_final_addr;
            branch_taken = (next_pc_val != (dut.instr_addr + 32'd4));

            unique case (instr_now[6:0])
                `R_TYPE: begin
                    unique case ({instr_now[31:25], instr_now[14:12]})
                        {7'b0000000, 3'b000}: begin
                            $display(
                                "add x%0d, x%0d, x%0d -> %0d + %0d = %0d",
                                rd_idx,
                                rs1_idx,
                                rs2_idx,
                                $signed(rs1_val),
                                $signed(rs2_val),
                                $signed(wb_val)
                            );
                        end
                        {7'b0100000, 3'b000}: begin
                            $display(
                                "sub x%0d, x%0d, x%0d -> %0d - %0d = %0d",
                                rd_idx,
                                rs1_idx,
                                rs2_idx,
                                $signed(rs1_val),
                                $signed(rs2_val),
                                $signed(wb_val)
                            );
                        end
                        {7'b0000000, 3'b001}: begin
                            $display(
                                "sll x%0d, x%0d, x%0d -> %0d << %0d = %0d",
                                rd_idx,
                                rs1_idx,
                                rs2_idx,
                                $signed(rs1_val),
                                rs2_val[4:0],
                                $signed(wb_val)
                            );
                        end
                        {7'b0000000, 3'b010}: begin
                            $display(
                                "slt x%0d, x%0d, x%0d -> %0d < %0d = %0d",
                                rd_idx,
                                rs1_idx,
                                rs2_idx,
                                $signed(rs1_val),
                                $signed(rs2_val),
                                $signed(wb_val)
                            );
                        end
                        {7'b0000000, 3'b011}: begin
                            $display(
                                "sltu x%0d, x%0d, x%0d -> 0x%08h < 0x%08h (unsigned) = %0d",
                                rd_idx,
                                rs1_idx,
                                rs2_idx,
                                rs1_val,
                                rs2_val,
                                $signed(wb_val)
                            );
                        end
                        {7'b0000000, 3'b100}: begin
                            $display(
                                "xor x%0d, x%0d, x%0d -> %0d ^ %0d = %0d",
                                rd_idx,
                                rs1_idx,
                                rs2_idx,
                                $signed(rs1_val),
                                $signed(rs2_val),
                                $signed(wb_val)
                            );
                        end
                        {7'b0000000, 3'b101}: begin
                            $display(
                                "srl x%0d, x%0d, x%0d -> %0d >> %0d = %0d",
                                rd_idx,
                                rs1_idx,
                                rs2_idx,
                                $signed(rs1_val),
                                rs2_val[4:0],
                                $signed(wb_val)
                            );
                        end
                        {7'b0100000, 3'b101}: begin
                            $display(
                                "sra x%0d, x%0d, x%0d -> %0d >>> %0d = %0d",
                                rd_idx,
                                rs1_idx,
                                rs2_idx,
                                $signed(rs1_val),
                                rs2_val[4:0],
                                $signed(wb_val)
                            );
                        end
                        {7'b0000000, 3'b110}: begin
                            $display(
                                "or x%0d, x%0d, x%0d -> %0d | %0d = %0d",
                                rd_idx,
                                rs1_idx,
                                rs2_idx,
                                $signed(rs1_val),
                                $signed(rs2_val),
                                $signed(wb_val)
                            );
                        end
                        {7'b0000000, 3'b111}: begin
                            $display(
                                "and x%0d, x%0d, x%0d -> %0d & %0d = %0d",
                                rd_idx,
                                rs1_idx,
                                rs2_idx,
                                $signed(rs1_val),
                                $signed(rs2_val),
                                $signed(wb_val)
                            );
                        end
                        default: begin
                            $display(
                                "%s x%0d, x%0d, x%0d",
                                decode_op(instr_now),
                                rd_idx,
                                rs1_idx,
                                rs2_idx
                            );
                        end
                    endcase
                end
                `S_TYPE: begin
                    unique case (instr_now[14:12])
                        `SB: begin
                            $display(
                                "sb x%0d, %0d(x%0d) -> mem[0x%08h] <= 0x%02h",
                                rs2_idx,
                                imm_s_val,
                                rs1_idx,
                                dut.daddr,
                                dut.d_wdata[7:0]
                            );
                        end
                        `SH: begin
                            $display(
                                "sh x%0d, %0d(x%0d) -> mem[0x%08h] <= 0x%04h",
                                rs2_idx,
                                imm_s_val,
                                rs1_idx,
                                dut.daddr,
                                dut.d_wdata[15:0]
                            );
                        end
                        `SW: begin
                            $display(
                                "sw x%0d, %0d(x%0d) -> mem[0x%08h] <= 0x%08h",
                                rs2_idx,
                                imm_s_val,
                                rs1_idx,
                                dut.daddr,
                                dut.d_wdata
                            );
                        end
                        default: begin
                            $display(
                                "%s x%0d, %0d(x%0d)",
                                decode_op(instr_now),
                                rs2_idx,
                                imm_s_val,
                                rs1_idx
                            );
                        end
                    endcase
                end
                `B_TYPE: begin
                    unique case (instr_now[14:12])
                        3'b000: begin
                            $display(
                                "beq x%0d, x%0d, %0d -> %0d == %0d, %s",
                                rs1_idx,
                                rs2_idx,
                                imm_b_val,
                                $signed(rs1_val),
                                $signed(rs2_val),
                                branch_taken ? "taken" : "not taken"
                            );
                        end
                        3'b001: begin
                            $display(
                                "bne x%0d, x%0d, %0d -> %0d != %0d, %s",
                                rs1_idx,
                                rs2_idx,
                                imm_b_val,
                                $signed(rs1_val),
                                $signed(rs2_val),
                                branch_taken ? "taken" : "not taken"
                            );
                        end
                        3'b100: begin
                            $display(
                                "blt x%0d, x%0d, %0d -> %0d < %0d, %s",
                                rs1_idx,
                                rs2_idx,
                                imm_b_val,
                                $signed(rs1_val),
                                $signed(rs2_val),
                                branch_taken ? "taken" : "not taken"
                            );
                        end
                        3'b101: begin
                            $display(
                                "bge x%0d, x%0d, %0d -> %0d >= %0d, %s",
                                rs1_idx,
                                rs2_idx,
                                imm_b_val,
                                $signed(rs1_val),
                                $signed(rs2_val),
                                branch_taken ? "taken" : "not taken"
                            );
                        end
                        3'b110: begin
                            $display(
                                "bltu x%0d, x%0d, %0d -> 0x%08h < 0x%08h (unsigned), %s",
                                rs1_idx,
                                rs2_idx,
                                imm_b_val,
                                rs1_val,
                                rs2_val,
                                branch_taken ? "taken" : "not taken"
                            );
                        end
                        3'b111: begin
                            $display(
                                "bgeu x%0d, x%0d, %0d -> 0x%08h >= 0x%08h (unsigned), %s",
                                rs1_idx,
                                rs2_idx,
                                imm_b_val,
                                rs1_val,
                                rs2_val,
                                branch_taken ? "taken" : "not taken"
                            );
                        end
                        default: begin
                            $display(
                                "%s x%0d, x%0d, %0d",
                                decode_op(instr_now),
                                rs1_idx,
                                rs2_idx,
                                imm_b_val
                            );
                        end
                    endcase
                end
                `JAL_TYPE: begin
                    if (!(rd_idx == 5'd0 && imm_j_val == 32'sd0)) begin
                        $display(
                            "jal x%0d, %0d -> link=0x%08h, target=0x%08h",
                            rd_idx,
                            imm_j_val,
                            wb_val,
                            next_pc_val
                        );
                    end
                end
                `JALR_TYPE: begin
                    $display(
                        "jalr x%0d, %0d(x%0d) -> target=(%0d + %0d) & ~1 = 0x%08h, link=0x%08h",
                        rd_idx,
                        imm_i_val,
                        rs1_idx,
                        $signed(rs1_val),
                        imm_i_val,
                        next_pc_val,
                        wb_val
                    );
                end
                `LUI_TYPE: begin
                    $display(
                        "lui x%0d, 0x%05h -> 0x%08h",
                        rd_idx,
                        instr_now[31:12],
                        wb_val
                    );
                end
                `AUIPC_TYPE: begin
                    $display(
                        "auipc x%0d, 0x%05h -> 0x%08h + pc(0x%08h) = 0x%08h",
                        rd_idx,
                        instr_now[31:12],
                        imm_u_val,
                        dut.instr_addr,
                        wb_val
                    );
                end
                `I_TYPE: begin
                    if (instr_now != 32'h00000013) begin
                        unique case (instr_now[14:12])
                            3'b000: begin
                                $display(
                                    "addi x%0d, x%0d, %0d -> %0d + %0d = %0d",
                                    rd_idx,
                                    rs1_idx,
                                    imm_i_val,
                                    $signed(rs1_val),
                                    imm_i_val,
                                    $signed(wb_val)
                                );
                            end
                            3'b001: begin
                                $display(
                                    "slli x%0d, x%0d, %0d -> %0d << %0d = %0d",
                                    rd_idx,
                                    rs1_idx,
                                    shamt_val,
                                    $signed(rs1_val),
                                    shamt_val,
                                    $signed(wb_val)
                                );
                            end
                            3'b010: begin
                                $display(
                                    "slti x%0d, x%0d, %0d -> %0d < %0d = %0d",
                                    rd_idx,
                                    rs1_idx,
                                    imm_i_val,
                                    $signed(rs1_val),
                                    imm_i_val,
                                    $signed(wb_val)
                                );
                            end
                            3'b011: begin
                                $display(
                                    "sltiu x%0d, x%0d, %0d -> 0x%08h < 0x%08h (unsigned) = %0d",
                                    rd_idx,
                                    rs1_idx,
                                    imm_i_val,
                                    rs1_val,
                                    imm_i_val,
                                    $signed(wb_val)
                                );
                            end
                            3'b100: begin
                                $display(
                                    "xori x%0d, x%0d, %0d -> %0d ^ %0d = %0d",
                                    rd_idx,
                                    rs1_idx,
                                    imm_i_val,
                                    $signed(rs1_val),
                                    imm_i_val,
                                    $signed(wb_val)
                                );
                            end
                            3'b101: begin
                                if (instr_now[30]) begin
                                    $display(
                                        "srai x%0d, x%0d, %0d -> %0d >>> %0d = %0d",
                                        rd_idx,
                                        rs1_idx,
                                        shamt_val,
                                        $signed(rs1_val),
                                        shamt_val,
                                        $signed(wb_val)
                                    );
                                end else begin
                                    $display(
                                        "srli x%0d, x%0d, %0d -> %0d >> %0d = %0d",
                                        rd_idx,
                                        rs1_idx,
                                        shamt_val,
                                        $signed(rs1_val),
                                        shamt_val,
                                        $signed(wb_val)
                                    );
                                end
                            end
                            3'b110: begin
                                $display(
                                    "ori x%0d, x%0d, %0d -> %0d | %0d = %0d",
                                    rd_idx,
                                    rs1_idx,
                                    imm_i_val,
                                    $signed(rs1_val),
                                    imm_i_val,
                                    $signed(wb_val)
                                );
                            end
                            3'b111: begin
                                $display(
                                    "andi x%0d, x%0d, %0d -> %0d & %0d = %0d",
                                    rd_idx,
                                    rs1_idx,
                                    imm_i_val,
                                    $signed(rs1_val),
                                    imm_i_val,
                                    $signed(wb_val)
                                );
                            end
                            default: begin
                                $display(
                                    "%s x%0d, x%0d, %0d",
                                    decode_op(instr_now),
                                    rd_idx,
                                    rs1_idx,
                                    imm_i_val
                                );
                            end
                        endcase
                    end
                end
                `IL_TYPE: begin
                    unique case (instr_now[14:12])
                        `LB: begin
                            $display(
                                "lb x%0d, %0d(x%0d) -> mem[0x%08h] = 0x%08h (%0d)",
                                rd_idx,
                                imm_i_val,
                                rs1_idx,
                                dut.daddr,
                                wb_val,
                                $signed(wb_val)
                            );
                        end
                        `LH: begin
                            $display(
                                "lh x%0d, %0d(x%0d) -> mem[0x%08h] = 0x%08h (%0d)",
                                rd_idx,
                                imm_i_val,
                                rs1_idx,
                                dut.daddr,
                                wb_val,
                                $signed(wb_val)
                            );
                        end
                        `LW: begin
                            $display(
                                "lw x%0d, %0d(x%0d) -> mem[0x%08h] = 0x%08h (%0d)",
                                rd_idx,
                                imm_i_val,
                                rs1_idx,
                                dut.daddr,
                                wb_val,
                                $signed(wb_val)
                            );
                        end
                        `LBU: begin
                            $display(
                                "lbu x%0d, %0d(x%0d) -> mem[0x%08h] = 0x%08h (%0d)",
                                rd_idx,
                                imm_i_val,
                                rs1_idx,
                                dut.daddr,
                                wb_val,
                                wb_val
                            );
                        end
                        `LHU: begin
                            $display(
                                "lhu x%0d, %0d(x%0d) -> mem[0x%08h] = 0x%08h (%0d)",
                                rd_idx,
                                imm_i_val,
                                rs1_idx,
                                dut.daddr,
                                wb_val,
                                wb_val
                            );
                        end
                        default: begin
                            $display(
                                "%s x%0d, %0d(x%0d)",
                                decode_op(instr_now),
                                rd_idx,
                                imm_i_val,
                                rs1_idx
                            );
                        end
                    endcase
                end
            endcase
        end
    end

    initial begin
        clk = 0;
        rst = 1;

        @(negedge clk);
        @(negedge clk);

        rst = 0;

        repeat (20) @(negedge clk);

        $stop;
    end

endmodule
