`timescale 1ns / 1ps


module sum_accumulator (
    input        clk,
    input        rst,
    output [7:0] out
);

    logic asrcsel, aload, outsel, alt10;

    control_unit U_CONTROL_UNIT (.*);

    datapath U_DATAPATH (.*);

endmodule


module control_unit (
    input        clk,
    input        rst,
    input        alt10,
    output logic asrcsel,
    output logic aload,
    output logic outsel
);

    typedef enum logic [2:0] {
        S0 = 0,
        S1 = 1,
        S2 = 2,
        S3 = 3,
        S4 = 4
    } state_t;  // typedef 재정의, enum 문자를 숫자화
    state_t c_state, n_state;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= S0;
        end else begin
            c_state <= n_state;
        end
    end

    always_comb begin
        n_state = c_state;
        asrcsel = 0;
        aload   = 0;
        outsel  = 1;
        case (c_state)
            S0: begin
                asrcsel = 0;
                aload   = 1;
                outsel  = 0;
                n_state = S1;
            end

            S1: begin

                // asrcsel = ; dont care
                aload  = 0;
                outsel = 0;
                if (alt10) begin
                    n_state = S2;
                end else begin
                    n_state = S4;
                end
            end
 
            S2: begin
                // asrcsel = ; dont care
                aload   = 0;
                outsel  = 0;
                n_state = S3;
            end

            S3: begin
                asrcsel = 1;
                aload   = 1;
                outsel  = 0;
                n_state = S1;
            end

            S4: begin
                // asrcsel = ; dont care
                aload   = 0;
                outsel  = 1;
                n_state = S4;
            end
        endcase
    end
endmodule


module datapath (
    input              clk,
    input              rst,
    input              asrcsel,
    input              aload,
    input              outsel,
    output             alt10,
    output logic [7:0] out
);

    logic [7:0] w_aluout, w_muxout, w_regout, w_sum_out, w_sum_1to10;
    assign out = (outsel) ? w_sum_out : 8'hz;

    mux_2x1 U_ASRCMUX (
        .a(0),
        .b(w_aluout),
        .asrcsel(asrcsel),
        .mux_out(w_muxout)
    );
    areg U_AREG (
        .clk(clk),
        .rst(rst),
        .reg_in(w_muxout),
        .aload(aload),
        .reg_out(w_regout)
    );
        areg U_BREG (
        .clk(clk),
        .rst(rst),
        .reg_in(w_sum_1to10),
        .aload(aload),
        .reg_out(w_sum_out)
    );
    alu U_ALU (
        .a(w_regout),
        .b(8'h1),
        .alu_out(w_aluout)
    );
    alu U_ALU_SUM (
        .a(w_regout),
        .b(w_sum_out),
        .alu_out(w_sum_1to10)
    );
    alt10_comp U_ALT10 (
        .in_data(w_regout),
        .alt10  (alt10)
    );

endmodule


module areg (
    input        clk,
    input        rst,
    input  [7:0] reg_in,
    input        aload,
    output [7:0] reg_out
);

    logic [7:0] areg;

    assign reg_out = areg;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            areg <= 0;
        end else begin
            if (aload) begin
                areg <= reg_in;
            end
        end
    end

endmodule


module alu (
    input  [7:0] a,
    input  [7:0] b,
    output [7:0] alu_out
);

    assign alu_out = a + b;

endmodule


module mux_2x1 (
    input  [7:0] a,
    input  [7:0] b,
    input        asrcsel,
    output [7:0] mux_out
);

    assign mux_out = (asrcsel) ? b : a;

endmodule


module alt10_comp (
    input [7:0] in_data,
    output alt10
);

    assign alt10 = (in_data < 11);

endmodule
