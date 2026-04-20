`timescale 1ns / 1ps

module fifo_sv (
    input  logic       clk,
    input  logic       rst,
    input  logic       we,
    input  logic       re,
    input  logic [7:0] wdata,
    output logic [7:0] rdata,
    output logic       full,
    output logic       empty
);

    logic [3:0] w_rptr, w_wptr;


    register_file_sv U_REGISTER (
        .clk   (clk),
        .r_addr(w_rptr),
        .w_addr(w_wptr),
        .wdata (wdata),
        .we    (we & (~full)),
        .rdata (rdata)
    );

    control_unit_sv U_CONTROL (
        .clk  (clk),
        .rst  (rst),
        .push (we),
        .pop  (re),
        .full (full),
        .empty(empty),
        .wptr (w_wptr),
        .rptr (w_rptr)
    );


endmodule


module control_unit_sv (
    input  logic       clk,
    input  logic       rst,
    input  logic       push,
    input  logic       pop,
    output logic       full,
    output logic       empty,
    output logic [3:0] wptr,
    output logic [3:0] rptr
);

    logic [3:0] rptr_r, rptr_n, wptr_r, wptr_n;
    logic full_r, full_n, empty_r, empty_n;

    assign full  = full_r;
    assign empty = empty_r;
    assign wptr  = wptr_r;
    assign rptr  = rptr_r;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            full_r  <= 0;
            empty_r <= 1;
            wptr_r  <= 4'd0;
            rptr_r  <= 4'd0;
        end else begin
            full_r  <= full_n;
            empty_r <= empty_n;
            wptr_r  <= wptr_n;
            rptr_r  <= rptr_n;
        end
    end

    always_comb begin
        full_n  = full_r;
        empty_n = empty_r;
        wptr_n  = wptr_r;
        rptr_n  = rptr_r;

        case ({
            push, pop
        })
            2'b10: begin  // Push
                if (!full_r) begin
                    wptr_n  = wptr_r + 4'd1;
                    empty_n = 0;
                    if (wptr_n == rptr_r) begin
                        full_n = 1;
                    end
                end
            end
            2'b01: begin  // Pop
                if (!empty_r) begin
                    rptr_n = rptr_r + 4'd1;
                    full_n = 0;
                    if (rptr_n == wptr_r) begin
                        empty_n = 1;
                    end
                end
            end
            2'b11: begin  // Push & Pop
                if (full_r) begin
                    rptr_n = rptr_r + 4'd1;
                    full_n = 0;
                end else if (empty_r) begin
                    wptr_n  = wptr_r + 4'd1;
                    empty_n = 0;
                end else begin
                    rptr_n = rptr_r + 4'd1;
                    wptr_n = wptr_r + 4'd1;
                end
            end
        endcase
    end
endmodule


module register_file_sv (
    input  logic       clk,
    input  logic [3:0] w_addr,
    input  logic [3:0] r_addr,
    input  logic [7:0] wdata,
    input  logic       we,
    output logic [7:0] rdata
);

    logic [7:0] register_file[0:15];

    always_ff @(posedge clk) begin
        if (we) begin
            register_file[w_addr] <= wdata;
        end
    end

    assign rdata = register_file[r_addr];

endmodule
