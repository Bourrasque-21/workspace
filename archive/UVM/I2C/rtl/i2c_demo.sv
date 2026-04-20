
// Simple I2C demo controller.
// When sw is high, it sends START -> address -> counter data -> STOP.
// After each completed transfer, counter increments by 1.

// 1. IDLE에서 sw가 1이 되면 시작
// 2. START에서 I2C Start 전송
// 3. ADDR에서 슬레이브 주소 7'h12 + Write 비트 0 전송
// 4. WRITE에서 counter 값 1바이트 전송
// 5. STOP에서 I2C Stop 전송 후 counter를 1 증가

`timescale 1ns / 1ps

module i2c_demo_top (
    input  logic clk,
    input  logic rst,
    input  logic sw,
    output logic scl,
    inout  wire  sda
);

    // State machine for one I2C write transaction.
    typedef enum logic [2:0] {
        IDLE,
        START,
        ADDR,
        WRITE,
        STOP
    } i2c_state_e;
    i2c_state_e state;

    // 7-bit slave address + write bit.
    localparam SLA_W = {7'h12, 1'b0};

    // Data byte that is sent and incremented after each transfer.
    logic [7:0] counter;
    logic [7:0] tx_data, rx_data;
    logic cmd_start, cmd_write, cmd_read, cmd_stop, ack_in, done, ack_out, busy;

    // Low-level I2C master handles SCL/SDA timing and bit transfers.
    I2C_Master U_I2C_MASTER (
        .clk      (clk),
        .rst      (rst),
        .cmd_start(cmd_start),
        .cmd_write(cmd_write),
        .cmd_read (cmd_read),
        .cmd_stop (cmd_stop),
        .tx_data  (tx_data),
        .ack_in   (ack_in),
        .rx_data  (rx_data),
        .done     (done),
        .ack_out  (ack_out),
        .busy     (busy),
        .scl      (scl),
        .sda      (sda)
    );

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            state     <= IDLE;
            counter   <= 8'h0;
            cmd_start <= 1'b0;
            cmd_write <= 1'b0;
            cmd_read  <= 1'b0;
            cmd_stop  <= 1'b0;
            tx_data   <= 8'h0;
        end else begin
            case (state)
                IDLE: begin
                    // Wait for the switch to request a transfer.
                    cmd_start <= 1'b0;
                    cmd_write <= 1'b0;
                    cmd_read  <= 1'b0;
                    cmd_stop  <= 1'b0;
                    if (sw) begin
                        state <= START;
                    end
                end
                START: begin
                    // Issue the I2C START condition.
                    cmd_start <= 1'b1;
                    cmd_write <= 1'b0;
                    cmd_read  <= 1'b0;
                    cmd_stop  <= 1'b0;
                    if (done) begin
                        state <= ADDR;
                    end
                end
                ADDR: begin
                    // Send slave address with write bit.
                    cmd_start <= 1'b0;
                    cmd_write <= 1'b1;
                    cmd_read  <= 1'b0;
                    cmd_stop  <= 1'b0;
                    tx_data   <= SLA_W;
                    if (done) begin
                        state <= WRITE;
                    end
                end
                WRITE: begin
                    // Send the current counter value as data.
                    cmd_start <= 1'b0;
                    cmd_write <= 1'b1;
                    cmd_read  <= 1'b0;
                    cmd_stop  <= 1'b0;
                    tx_data   <= counter;
                    if (done) begin
                        state <= STOP;
                    end
                end
                STOP: begin
                    // Finish the transfer, then prepare the next data byte.
                    cmd_start <= 1'b0;
                    cmd_write <= 1'b0;
                    cmd_read  <= 1'b0;
                    cmd_stop  <= 1'b1;
                    if (done) begin
                        state   <= IDLE;
                        counter <= counter + 1;
                    end
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
