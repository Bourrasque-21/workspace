`timescale 1ns / 1ps

module demo_i2c_master #(
    parameter logic [6:0] SLAVE_ADDR = 7'h60,
    parameter logic [6:0] MPU6050_ADDR = 7'h68,
    parameter logic [7:0] WHO_AM_I_REG = 8'h75,
    parameter int unsigned STARTUP_DELAY_CYCLES = 2_000_000,
    parameter int unsigned DEBOUNCE_WAIT_TIME = 500_000
) (
    input  logic       clk,
    input  logic       rst,
    input  logic       mode_sw,
    input  logic [7:0] data_sw,
    input  logic       start_btn,
    input  logic       mpu6050_btn,
    output logic [7:0] led,
    output logic       scl,
    output logic       mode_led,
    inout  wire        sda
);

    localparam int unsigned STARTUP_CNT_W = (STARTUP_DELAY_CYCLES > 0) ?
        $clog2(STARTUP_DELAY_CYCLES + 1) : 1;

    typedef enum logic [3:0] {
        BOOT_WAIT,
        IDLE_WAIT,
        NORMAL_START_CMD,
        NORMAL_ADDR,
        NORMAL_WRITE,
        NORMAL_READ,
        MPU_START_WRITE_CMD,
        MPU_ADDR_WRITE,
        MPU_REG_ADDR_WRITE,
        MPU_STOP_AFTER_REG,
        MPU_START_READ_CMD,
        MPU_ADDR_READ,
        MPU_READ,
        STOP_CMD
    } state_e;

    state_e state;

    logic [STARTUP_CNT_W-1:0] startup_cnt;

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

    logic       sda_o;
    logic       sda_raw;
    logic       sda_meta;
    logic       sda_sync;

    logic       start_btn_pulse;
    logic       mpu6050_btn_pulse;
    logic       start_btn_pending;
    logic       mpu6050_btn_pending;

    logic       mode_latched;
    logic [7:0] data_latched;

    assign mode_led = mode_sw;
    assign sda_raw  = sda;
    assign sda      = sda_o ? 1'bz : 1'b0;

    btn_debouncer #(
        .WAIT_TIME(DEBOUNCE_WAIT_TIME)
    ) u_start_btn_debouncer (
        .clk         (clk),
        .rst         (rst),
        .button_in   (start_btn),
        .button_pulse(start_btn_pulse)
    );

    btn_debouncer #(
        .WAIT_TIME(DEBOUNCE_WAIT_TIME)
    ) u_mpu6050_btn_debouncer (
        .clk         (clk),
        .rst         (rst),
        .button_in   (mpu6050_btn),
        .button_pulse(mpu6050_btn_pulse)
    );

    i2c_master u_i2c_master (
        .clk      (clk),
        .rst      (rst),
        .cmd_start(cmd_start),
        .cmd_write(cmd_write),
        .cmd_read (cmd_read),
        .cmd_stop (cmd_stop),
        .tx_data  (master_tx_data),
        .ack_in   (1'b1),
        .busy     (master_busy),
        .done     (master_done),
        .ack_out  (ack_out),
        .rx_data  (master_rx_data),
        .scl      (scl),
        .sda_o    (sda_o),
        .sda_i    (sda_sync)
    );

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state               <= BOOT_WAIT;
            startup_cnt         <= '0;
            cmd_start           <= 1'b0;
            cmd_write           <= 1'b0;
            cmd_read            <= 1'b0;
            cmd_stop            <= 1'b0;
            master_tx_data      <= 8'h00;
            cmd_sent            <= 1'b0;
            led                 <= 8'h00;
            sda_meta            <= 1'b1;
            sda_sync            <= 1'b1;
            start_btn_pending   <= 1'b0;
            mpu6050_btn_pending <= 1'b0;
            mode_latched        <= 1'b0;
            data_latched        <= 8'h00;
        end else begin
            cmd_start <= 1'b0;
            cmd_write <= 1'b0;
            cmd_read  <= 1'b0;
            cmd_stop  <= 1'b0;

            sda_meta <= sda_raw;
            sda_sync <= sda_meta;

            if (start_btn_pulse) begin
                start_btn_pending <= 1'b1;
            end

            if (mpu6050_btn_pulse) begin
                mpu6050_btn_pending <= 1'b1;
            end

            case (state)
                BOOT_WAIT: begin
                    cmd_sent <= 1'b0;
                    if (STARTUP_DELAY_CYCLES == 0) begin
                        state <= IDLE_WAIT;
                    end else if (startup_cnt == STARTUP_DELAY_CYCLES - 1) begin
                        startup_cnt <= '0;
                        state       <= IDLE_WAIT;
                    end else begin
                        startup_cnt <= startup_cnt + 1'b1;
                    end
                end

                IDLE_WAIT: begin
                    cmd_sent <= 1'b0;
                    if (mpu6050_btn_pending) begin
                        mpu6050_btn_pending <= 1'b0;
                        state               <= MPU_START_WRITE_CMD;
                    end else if (start_btn_pending) begin
                        start_btn_pending <= 1'b0;
                        mode_latched      <= mode_sw;
                        data_latched      <= data_sw;
                        state             <= NORMAL_START_CMD;
                    end
                end

                NORMAL_START_CMD: begin
                    if (!cmd_sent) begin
                        cmd_start <= 1'b1;
                        cmd_sent  <= 1'b1;
                    end else if (master_done) begin
                        cmd_sent <= 1'b0;
                        state    <= NORMAL_ADDR;
                    end
                end

                NORMAL_ADDR: begin
                    if (!cmd_sent) begin
                        cmd_write      <= 1'b1;
                        master_tx_data <= {SLAVE_ADDR, mode_latched};
                        cmd_sent       <= 1'b1;
                    end else if (master_done) begin
                        cmd_sent <= 1'b0;
                        if (ack_out == 1'b0) begin
                            state <= mode_latched ? NORMAL_READ : NORMAL_WRITE;
                        end else begin
                            state <= STOP_CMD;
                        end
                    end
                end

                NORMAL_WRITE: begin
                    if (!cmd_sent) begin
                        cmd_write      <= 1'b1;
                        master_tx_data <= data_latched;
                        cmd_sent       <= 1'b1;
                    end else if (master_done) begin
                        cmd_sent <= 1'b0;
                        state    <= STOP_CMD;
                    end
                end

                NORMAL_READ: begin
                    if (!cmd_sent) begin
                        cmd_read <= 1'b1;
                        cmd_sent <= 1'b1;
                    end else if (master_done) begin
                        led      <= master_rx_data;
                        cmd_sent <= 1'b0;
                        state    <= STOP_CMD;
                    end
                end

                MPU_START_WRITE_CMD: begin
                    if (!cmd_sent) begin
                        cmd_start <= 1'b1;
                        cmd_sent  <= 1'b1;
                    end else if (master_done) begin
                        cmd_sent <= 1'b0;
                        state    <= MPU_ADDR_WRITE;
                    end
                end

                MPU_ADDR_WRITE: begin
                    if (!cmd_sent) begin
                        cmd_write      <= 1'b1;
                        master_tx_data <= {MPU6050_ADDR, 1'b0};
                        cmd_sent       <= 1'b1;
                    end else if (master_done) begin
                        cmd_sent <= 1'b0;
                        if (ack_out == 1'b0) begin
                            state <= MPU_REG_ADDR_WRITE;
                        end else begin
                            state <= STOP_CMD;
                        end
                    end
                end

                MPU_REG_ADDR_WRITE: begin
                    if (!cmd_sent) begin
                        cmd_write      <= 1'b1;
                        master_tx_data <= WHO_AM_I_REG;
                        cmd_sent       <= 1'b1;
                    end else if (master_done) begin
                        cmd_sent <= 1'b0;
                        if (ack_out == 1'b0) begin
                            state <= MPU_STOP_AFTER_REG;
                        end else begin
                            state <= STOP_CMD;
                        end
                    end
                end

                MPU_STOP_AFTER_REG: begin
                    if (!cmd_sent) begin
                        cmd_stop <= 1'b1;
                        cmd_sent <= 1'b1;
                    end else if (master_done) begin
                        cmd_sent <= 1'b0;
                        state    <= MPU_START_READ_CMD;
                    end
                end

                MPU_START_READ_CMD: begin
                    if (!cmd_sent) begin
                        cmd_start <= 1'b1;
                        cmd_sent  <= 1'b1;
                    end else if (master_done) begin
                        cmd_sent <= 1'b0;
                        state    <= MPU_ADDR_READ;
                    end
                end

                MPU_ADDR_READ: begin
                    if (!cmd_sent) begin
                        cmd_write      <= 1'b1;
                        master_tx_data <= {MPU6050_ADDR, 1'b1};
                        cmd_sent       <= 1'b1;
                    end else if (master_done) begin
                        cmd_sent <= 1'b0;
                        if (ack_out == 1'b0) begin
                            state <= MPU_READ;
                        end else begin
                            state <= STOP_CMD;
                        end
                    end
                end

                MPU_READ: begin
                    if (!cmd_sent) begin
                        cmd_read <= 1'b1;
                        cmd_sent <= 1'b1;
                    end else if (master_done) begin
                        led      <= {2'b00, master_rx_data[6:1]};
                        cmd_sent <= 1'b0;
                        state    <= STOP_CMD;
                    end
                end

                STOP_CMD: begin
                    if (!cmd_sent) begin
                        cmd_stop <= 1'b1;
                        cmd_sent <= 1'b1;
                    end else if (master_done) begin
                        cmd_sent <= 1'b0;
                        state    <= IDLE_WAIT;
                    end
                end

                default: begin
                    state <= BOOT_WAIT;
                end
            endcase
        end
    end

endmodule
