`timescale 1ns / 1ps

module demo_i2c_master #(
    parameter logic [6:0] SLAVE_ADDR = 7'h60
) (
    input  logic       clk,
    input  logic       rst,
    input  logic       mode_sw,    // 0: write, 1: read
    input  logic [7:0] data_sw,
    input  logic       start_btn,
    output logic [7:0] led,
    output logic       scl,
    output logic       mode_led,
    inout  wire        sda
);

    typedef enum logic [2:0] {
        IDLE,
        START,
        ADDR,
        WRITE,
        READ,
        STOP
    } i2c_state_e;

    i2c_state_e state;

    logic       cmd_start;
    logic       cmd_write;
    logic       cmd_read;
    logic       cmd_stop;
    logic [7:0] master_tx_data;
    logic [7:0] master_rx_data;
    logic       master_busy;
    logic       master_done;
    logic       ack_out;

    logic       cmd_sent;

    logic       mode_latched;
    logic [7:0] data_latched;

    I2C_Master u_i2c_master (
        .clk      (clk),
        .rst      (rst),
        .cmd_start(cmd_start),
        .cmd_write(cmd_write),
        .cmd_read (cmd_read),
        .cmd_stop (cmd_stop),
        .tx_data  (master_tx_data),
        .ack_in   (1'b1),          // Single-byte read ends with NACK.
        .busy     (master_busy),
        .done     (master_done),
        .ack_out  (ack_out),
        .rx_data  (master_rx_data),
        .scl      (scl),
        .sda      (sda)
    );

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            state          <= IDLE;
            cmd_start      <= 1'b0;
            cmd_write      <= 1'b0;
            cmd_read       <= 1'b0;
            cmd_stop       <= 1'b0;
            master_tx_data <= 8'h00;
            mode_latched   <= 1'b0;
            data_latched   <= 8'h00;
            cmd_sent       <= 1'b0;
            led            <= 8'h00;
        end else begin
            cmd_start <= 1'b0;
            cmd_write <= 1'b0;
            cmd_read  <= 1'b0;
            cmd_stop  <= 1'b0;

            case (state)
                IDLE: begin
                    if (start_btn) begin
                        mode_latched <= mode_sw;
                        data_latched <= data_sw;
                        cmd_sent     <= 1'b0;
                        state        <= START;
                    end
                end

                START: begin
                    if (!cmd_sent) begin
                        cmd_start  <= 1'b1;
                        cmd_sent   <= 1'b1;
                    end else if (master_done) begin
                        cmd_sent   <= 1'b0;
                        state      <= ADDR;
                    end
                end

                ADDR: begin
                    if (!cmd_sent) begin
                        cmd_write      <= 1'b1;
                        master_tx_data <= {SLAVE_ADDR, mode_latched};
                        cmd_sent       <= 1'b1;
                    end else if (master_done) begin
                        cmd_sent   <= 1'b0;
                        if (ack_out == 1'b0) begin
                            state <= mode_latched ? READ : WRITE;
                        end else begin
                            state <= STOP;
                        end
                    end
                end

                WRITE: begin
                    if (!cmd_sent) begin
                        cmd_write      <= 1'b1;
                        master_tx_data <= data_latched;
                        cmd_sent       <= 1'b1;
                    end else if (master_done) begin
                        cmd_sent   <= 1'b0;
                        state      <= STOP;
                    end
                end

                READ: begin
                    if (!cmd_sent) begin
                        cmd_read   <= 1'b1;
                        cmd_sent   <= 1'b1;
                    end else if (master_done) begin
                        led        <= master_rx_data;
                        cmd_sent   <= 1'b0;
                        state      <= STOP;
                    end
                end

                STOP: begin
                    if (!cmd_sent) begin
                        cmd_stop   <= 1'b1;
                        cmd_sent   <= 1'b1;
                    end else if (master_done) begin
                        cmd_sent   <= 1'b0;
                        state      <= IDLE;
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
