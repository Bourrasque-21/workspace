`timescale 1ns / 1ps

module I2C_Slave (
    input logic clk,
    input logic rst,

    input  logic [7:0] tx_data,
    output logic [7:0] rx_data,
    output logic       busy,
    output logic       valid,

    input logic scl,
    inout logic sda
);

    logic sda_o, sda_i;

    assign sda_i = sda;
    assign sda   = sda_o ? 1'bz : 1'b0;

    i2c_slave U_I2C_SLAVE (
        .*,
        .sda_o(sda_o),
        .sda_i(sda_i)
    );

endmodule


module i2c_slave (
    input logic clk,
    input logic rst,

    input  logic [7:0] tx_data,
    output logic [7:0] rx_data,
    output logic       busy,
    output logic       valid,

    input  logic scl,
    output logic sda_o,
    input  logic sda_i
);

    typedef enum logic [3:0] {
        IDLE,
        ADDR_WAIT,
        ADDR_ACK,
        READ,
        READ_ACK,
        WRITE,
        WRITE_ACK,
        WAIT_NEXT,
        STOP
    } i2c_state_e;
    i2c_state_e state;

    // Internal SCL/SDA control registers
    logic sda_r;  // sda_r: 1 = release 'Z', 0 = drive low
    logic ack_out;  // for Write ACK

    logic [7:0] tx_shift_reg, rx_shift_reg;
    logic [2:0] bit_cnt;
    logic is_read, addr_ok;
    logic wait_next_seen_rise;

    logic scl_rise, scl_fall, scl_sync1, scl_sync2;
    logic sda_rise, sda_fall, sda_sync1, sda_sync2;

    assign ack_out  = 1'b0;  // always ACK
    assign sda_o    = sda_r;
    assign busy     = (state != IDLE);

    assign scl_rise = scl_sync1 & ~scl_sync2;
    assign scl_fall = ~scl_sync1 & scl_sync2;
    assign sda_rise = sda_sync1 & ~sda_sync2;
    assign sda_fall = ~sda_sync1 & sda_sync2;
    assign addr_ok  = (7'h60 == rx_shift_reg[7:1]) ? 1'b1 : 1'b0;
    assign is_read  = rx_shift_reg[0];

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            scl_sync1 <= 1'b1;
            scl_sync2 <= 1'b1;
            sda_sync1 <= 1'b1;
            sda_sync2 <= 1'b1;
        end else begin
            scl_sync1 <= scl;
            scl_sync2 <= scl_sync1;
            sda_sync1 <= sda_i;
            sda_sync2 <= sda_sync1;
        end
    end

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            state               <= IDLE;
            sda_r               <= 1'b1;
            tx_shift_reg        <= 8'h0;
            rx_shift_reg        <= 8'h0;
            bit_cnt             <= 3'd0;
            rx_data             <= 8'd0;
            valid               <= 1'b0;
            wait_next_seen_rise <= 1'b0;
        end else begin
            valid <= 1'b0;
            case (state)
                IDLE: begin
                    sda_r <= 1'b1;
                    if ((scl_sync2) && (sda_fall)) begin  // start
                        state        <= ADDR_WAIT;
                        rx_shift_reg <= 8'h00;
                        bit_cnt      <= 3'd0;
                    end
                end

                ADDR_WAIT: begin
                    if (scl_rise) begin
                        rx_shift_reg <= {rx_shift_reg[6:0], sda_sync2};
                        if (bit_cnt == 3'd7) begin
                            state   <= ADDR_ACK;
                            bit_cnt <= 3'd0;
                        end else begin
                            bit_cnt <= bit_cnt + 3'd1;
                        end
                    end
                end

                ADDR_ACK: begin
                    if (!addr_ok) begin
                        sda_r <= 1'b1;
                        state <= IDLE;
                    end else if (scl_fall) begin
                        if (sda_r) begin
                            sda_r <= 1'b0;
                        end else begin
                            if (is_read) begin  // READ
                                tx_shift_reg <= tx_data;
                                sda_r        <= tx_data[7];  // First Data 
                                bit_cnt      <= 3'd0;
                                state        <= READ;
                            end else begin  // WRITE
                                sda_r   <= 1'b1;  // release SDR
                                bit_cnt <= 3'd0;
                                state   <= WRITE;
                            end
                        end
                    end
                end

                READ: begin
                    if (scl_fall) begin
                        if (bit_cnt == 3'd7) begin
                            sda_r   <= 1'b1;  // release SDR
                            bit_cnt <= 3'd0;
                            state   <= READ_ACK;
                        end else begin
                            tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                            sda_r        <= tx_shift_reg[6];
                            bit_cnt      <= bit_cnt + 3'd1;
                        end
                    end
                end

                READ_ACK: begin
                    if (scl_fall) begin
                        if (sda_sync2) begin
                            wait_next_seen_rise <= 1'b0;
                            state               <= WAIT_NEXT;
                        end else begin
                            tx_shift_reg <= tx_data;
                            sda_r        <= tx_data[7];
                            bit_cnt      <= 3'd0;
                            state        <= READ;
                        end
                    end
                end

                WRITE: begin
                    if (scl_rise) begin
                        rx_shift_reg <= {rx_shift_reg[6:0], sda_sync2};
                        if (bit_cnt == 3'd7) begin
                            bit_cnt <= 3'd0;
                            state   <= WRITE_ACK;
                        end else begin
                            bit_cnt <= bit_cnt + 3'd1;
                        end
                    end
                end

                WRITE_ACK: begin
                    if (scl_fall) begin
                        if (sda_r) begin
                            sda_r <= ack_out;  // Drive ACK (0) or NACK (1)
                        end else begin
                            sda_r <= 1'b1;
                            rx_data <= rx_shift_reg;
                            valid <= 1'b1;
                            wait_next_seen_rise <= 1'b0;
                            state <= WAIT_NEXT;
                        end
                    end
                end

                WAIT_NEXT: begin
                    sda_r <= 1'b1;
                    if (scl_sync2 && sda_rise) begin
                        wait_next_seen_rise <= 1'b0;
                        state               <= STOP;  // STOP
                    end else if (scl_sync2 && sda_fall) begin
                        wait_next_seen_rise <= 1'b0;
                        bit_cnt             <= 3'd0;
                        rx_shift_reg        <= 8'h00;
                        state               <= ADDR_WAIT;  // repeated START
                    end else if (!wait_next_seen_rise && scl_rise) begin
                        rx_shift_reg <= {rx_shift_reg[6:0], sda_sync2};
                        bit_cnt <= 3'd1;  // first bit already captured
                        wait_next_seen_rise <= 1'b1;
                    end else if (wait_next_seen_rise && scl_fall) begin
                        wait_next_seen_rise <= 1'b0;
                        state <= WRITE;  // now continue remaining 7 bits
                    end
                end

                STOP: begin
                    sda_r               <= 1'b1;
                    bit_cnt             <= 3'd0;
                    rx_shift_reg        <= 8'h0;
                    wait_next_seen_rise <= 1'b0;
                    state               <= IDLE;
                end

            endcase
        end
    end

endmodule
