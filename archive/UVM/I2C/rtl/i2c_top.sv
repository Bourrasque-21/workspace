`timescale 1ns / 1ps

module I2C_TOP #(
    parameter logic [6:0] SLAVE_ADDR = 7'h60
) (
    input  logic       clk,
    input  logic       rst,
    input  logic       mode_sw,
    input  logic [15:0] data_sw,
    input  logic       start_btn,
    output logic [15:0] led
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
    logic       scl_int;

    logic [7:0] master_led;
    logic [7:0] slave_led;
    logic [7:0] slave_rx_data;
    logic       slave_valid;

    // Internal open-drain bus resolution.
    // 1 = release, 0 = drive low, so wired-AND models the bus.
    logic master_sda_o;
    logic master_sda_i;
    logic slave_sda_o;
    logic slave_sda_i;
    logic sda_bus;

    assign sda_bus      = master_sda_o & slave_sda_o;
    assign master_sda_i = sda_bus;
    assign slave_sda_i  = sda_bus;
    assign led[7:0]     = master_led;
    assign led[15:8]    = slave_led;

    i2c_master u_i2c_master (
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
        .scl      (scl_int),
        .sda_o    (master_sda_o),
        .sda_i    (master_sda_i)
    );

    i2c_slave u_i2c_slave (
        .clk    (clk),
        .rst    (rst),
        .tx_data(data_sw[15:8]),   // Slave returns upper switch byte on READ
        .rx_data(slave_rx_data),
        .busy   (),
        .valid  (slave_valid),
        .scl    (scl_int),
        .sda_o  (slave_sda_o),
        .sda_i  (slave_sda_i)
    );

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            slave_led <= 8'h00;
        end else if (slave_valid) begin
            slave_led <= slave_rx_data;
        end
    end

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
            master_led     <= 8'h00;
        end else begin
            cmd_start <= 1'b0;
            cmd_write <= 1'b0;
            cmd_read  <= 1'b0;
            cmd_stop  <= 1'b0;

            case (state)
                IDLE: begin
                    if (start_btn) begin
                        mode_latched <= mode_sw;
                        data_latched <= data_sw[7:0];
                        cmd_sent     <= 1'b0;
                        state        <= START;
                    end
                end

                START: begin
                    if (!cmd_sent) begin
                        cmd_start <= 1'b1;
                        cmd_sent  <= 1'b1;
                    end else if (master_done) begin
                        cmd_sent <= 1'b0;
                        state    <= ADDR;
                    end
                end

                ADDR: begin
                    if (!cmd_sent) begin
                        cmd_write      <= 1'b1;
                        master_tx_data <= {SLAVE_ADDR, mode_latched};
                        cmd_sent       <= 1'b1;
                    end else if (master_done) begin
                        cmd_sent <= 1'b0;
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
                        cmd_sent <= 1'b0;
                        state    <= STOP;
                    end
                end

                READ: begin
                    if (!cmd_sent) begin
                        cmd_read <= 1'b1;
                        cmd_sent <= 1'b1;
                    end else if (master_done) begin
                        master_led <= master_rx_data;
                        cmd_sent   <= 1'b0;
                        state      <= STOP;
                    end
                end

                STOP: begin
                    if (!cmd_sent) begin
                        cmd_stop <= 1'b1;
                        cmd_sent <= 1'b1;
                    end else if (master_done) begin
                        cmd_sent <= 1'b0;
                        state    <= IDLE;
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
