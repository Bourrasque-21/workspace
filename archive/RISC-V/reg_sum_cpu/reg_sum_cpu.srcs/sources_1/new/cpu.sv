`timescale 1ns / 1ps

module reg_sum_cpu (
    input        clk,
    input        rst,
    output [7:0] out
);

    logic rfsrcsel, rf_we, outsel, alt10;
    logic [1:0] rf_ra0, rf_ra1, rf_wa;

    control_unit U_CONTROL_UNIT (.*);

    datapath U_DATAPATH (.*);

endmodule


module control_unit (
    input              clk,
    input              rst,
    input              alt10,
    output logic       rfsrcsel,
    output logic [1:0] rf_ra0,
    output logic [1:0] rf_ra1,
    output logic [1:0] rf_wa,
    output logic       rf_we,
    output logic       outsel
);

    typedef enum logic [2:0] {
        S0 = 3'd0,
        S1 = 3'd1,
        S2 = 3'd2,
        S3 = 3'd3,
        S4 = 3'd4
    } state_t;

    state_t c_state, n_state;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) c_state <= S0;
        else c_state <= n_state;
    end

    always_comb begin
        n_state  = c_state;
        rfsrcsel = 1'b1;
        rf_ra0   = 2'd0;
        rf_ra1   = 2'd0;
        rf_wa    = 2'd0;
        rf_we    = 1'b0;
        outsel   = 1'b0;

        case (c_state)
            S0: begin
                rfsrcsel = 1'b1;
                rf_ra0   = 2'd0;
                rf_ra1   = 2'd0;
                rf_wa    = 2'd0;
                rf_we    = 1'b0;
                n_state = S1;
            end

            S1: begin
                rf_ra0 = 2'd1;
                rf_ra1 = 2'd0;
                rf_we  = 1'b0;
                outsel = 1'b0;

                if (alt10) n_state = S2;
                else n_state = S4;
            end

            S2: begin
                rfsrcsel = 1'b1;
                rf_ra0   = 2'd1;
                rf_ra1   = 2'd2;
                rf_wa    = 2'd2;
                rf_we    = 1'b1;
                outsel   = 1'b0;
                n_state  = S3;
            end

            S3: begin
                rfsrcsel = 1'b1;
                rf_ra0   = 2'd1;
                rf_ra1   = 2'd3;
                rf_wa    = 2'd1;
                rf_we    = 1'b1;
                outsel   = 1'b0;
                n_state  = S1;
            end

            S4: begin
                rf_ra0  = 2'd2;
                rf_ra1  = 2'd0;
                rf_wa   = 2'd1;
                rf_we   = 1'b0;
                outsel  = 1'b1;
                n_state = S4;
            end
        endcase
    end

endmodule


module datapath (
    input              clk,
    input              rst,
    input              rfsrcsel,
    input              rf_we,
    input        [1:0] rf_ra0,
    input        [1:0] rf_ra1,
    input        [1:0] rf_wa,
    input              outsel,
    output             alt10,
    output logic [7:0] out
);

    logic [7:0] rf_wdata, rf_rd0, rf_rd1;
    logic [7:0] w_aluout;

    assign out = (outsel) ? rf_rd0 : 8'd0;

    register_file U_REGISTER_FILE (
        .clk  (clk),
        .rst  (rst),
        .we   (rf_we),
        .ra0  (rf_ra0),
        .ra1  (rf_ra1),
        .wa   (rf_wa),
        .wdata(rf_wdata),
        .rd0  (rf_rd0),
        .rd1  (rf_rd1)
    );

    alu U_ALU (
        .a      (rf_rd0),
        .b      (rf_rd1),
        .alu_out(w_aluout)
    );

    mux_2x1 U_MUX_RF_SEL (
        .a(8'd0),
        .b(w_aluout),
        .rfsrcsel(rfsrcsel),
        .mux_out(rf_wdata)
    );

    alt10_comp U_ALT10 (
        .in_data(rf_rd0),
        .alt10  (alt10)
    );

endmodule

//=========================================
//  REGISTER FILE
//=========================================
module register_file (
    input              clk,
    input              rst,
    input              we,
    input        [1:0] ra0,
    input        [1:0] ra1,
    input        [1:0] wa,
    input        [7:0] wdata,
    output logic [7:0] rd0,
    output logic [7:0] rd1
);

    logic [7:0] register_file[0:3];

    assign rd0 = register_file[ra0];
    assign rd1 = register_file[ra1];

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            register_file[0] <= 8'd0;
            register_file[1] <= 8'd0;
            register_file[2] <= 8'd0;
            register_file[3] <= 8'd1;
        end else begin
            if (we && (wa != 2'd0)) begin
                register_file[wa] <= wdata;
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
    input        rfsrcsel,
    output [7:0] mux_out
);

    assign mux_out = (rfsrcsel) ? b : a;

endmodule


module alt10_comp (
    input  [7:0] in_data,
    output       alt10
);

    assign alt10 = (in_data <= 8'd10);

endmodule
