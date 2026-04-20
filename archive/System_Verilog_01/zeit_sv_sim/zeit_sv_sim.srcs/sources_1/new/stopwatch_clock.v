`timescale 1ns / 1ps

module stopwatch_clock (
    input clk,
    input reset,
    input cnt_mode,
    input sw_time_set,
    input btn_run_stop,
    input btn_clear,
    input btn_up,
    input btn_down,
    input btn_next,

    output [25:0] stopwatch_time,
    output [23:0] clock_time
);

    clk_datapath U_CLOCK_DATAPATH (
        .clk        (clk),
        .reset      (reset),
        .sw_time_set(sw_time_set),
        .btn_next   (btn_next),
        .up_count   (btn_up),
        .down_count (btn_down),
        .c_msec     (clock_time[6:0]),
        .c_sec      (clock_time[12:7]),
        .c_min      (clock_time[18:13]),
        .c_hour     (clock_time[23:19])
    );


    stopwatch_datapath U_STOPWATCH_DATAPATH (
        .clk          (clk),
        .reset        (reset),
        .count_mode_sw(cnt_mode),
        .clear        (btn_clear),
        .run_stop     (btn_run_stop),
        .msec         (stopwatch_time[6:0]),
        .sec          (stopwatch_time[12:7]),
        .min          (stopwatch_time[18:13]),
        .hour         (stopwatch_time[25:19])
    );

endmodule


//================================
//  Stopwatch
//================================
module stopwatch_datapath (
    input clk,
    input reset,
    input count_mode_sw,
    input clear,
    input run_stop,
    output [6:0] msec,
    output [5:0] sec,
    output [5:0] min,
    output [6:0] hour
);
    
    wire w_tick_100hz, w_sec_tick, w_min_tick, w_hour_tick;

    reg run_en;
    
    wire clear_en = clear & ~run_en & ~run_stop;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            run_en <= 1'b0;
        end else begin
            if (run_stop) begin
                run_en <= ~run_en;
            end
        end
    end

    tick_gen_100hz U_tick_gen (
        .clk(clk),
        .reset(reset),
        .i_run_stop(run_en),
        .o_tick_100hz(w_tick_100hz)
    );


    tick_counter #(
        .BIT_WIDTH(7),
        .TIMES(100)
    ) hour_counter (
        .clk(clk),
        .reset(reset),
        .mode(count_mode_sw),
        .clear(clear_en),
        .run_stop(run_en),
        .i_tick(w_hour_tick),
        .o_count(hour),
        .o_tick()
    );


    tick_counter #(
        .BIT_WIDTH(6),
        .TIMES(60)
    ) min_counter (
        .clk(clk),
        .reset(reset),
        .mode(count_mode_sw),
        .clear(clear_en),
        .run_stop(run_en),
        .i_tick(w_min_tick),
        .o_count(min),
        .o_tick(w_hour_tick)
    );


    tick_counter #(
        .BIT_WIDTH(6),
        .TIMES(60)
    ) sec_counter (
        .clk(clk),
        .reset(reset),
        .mode(count_mode_sw),
        .clear(clear_en),
        .run_stop(run_en),
        .i_tick(w_sec_tick),
        .o_count(sec),
        .o_tick(w_min_tick)
    );


    tick_counter #(
        .BIT_WIDTH(7),
        .TIMES(100)
    ) msec_counter (
        .clk(clk),
        .reset(reset),
        .i_tick(w_tick_100hz),
        .mode(count_mode_sw),
        .clear(clear_en),
        .run_stop(run_en),
        .o_count(msec),
        .o_tick(w_sec_tick)
    );

endmodule


module tick_counter #(
    parameter BIT_WIDTH = 7,
    parameter TIMES = 100
) (
    input clk,
    input reset,
    input i_tick,
    input mode,
    input clear,
    input run_stop,
    output [BIT_WIDTH-1 : 0] o_count,
    output reg o_tick
);
    reg [BIT_WIDTH-1:0] counter_reg, counter_next;

    assign o_count = counter_reg;

    always @(posedge clk, posedge reset) begin
        if (reset | clear) begin
            counter_reg <= 0;
        end else begin
            counter_reg <= counter_next;
        end
    end

    always @(*) begin
        counter_next = counter_reg;
        o_tick = 1'b0;
        if (i_tick & run_stop) begin
            //mode = 0 up count/ = 1 down count 
            if (mode == 1'b1) begin
                if (counter_reg == 0) begin
                    counter_next = TIMES - 1;
                    o_tick = 1'b1;
                end else begin
                    counter_next = counter_reg - 1;
                    o_tick = 1'b0;
                end
            end else begin
                if (counter_reg == (TIMES - 1)) begin
                    counter_next = 0;
                    o_tick = 1'b1;
                end else begin
                    counter_next = counter_reg + 1;
                    o_tick = 1'b0;
                end
            end
        end
    end
endmodule


//================================
//  Clock
//================================
module clk_datapath (
    input clk,
    input reset,
    input sw_time_set,
    input btn_next,
    input up_count,
    input down_count,

    output [6:0] c_msec,
    output [5:0] c_sec,
    output [5:0] c_min,
    output [4:0] c_hour
);
    wire tick_100hz;
    wire en_tick = !(sw_time_set);
    wire sec_tick, min_tick, hour_tick;

    tick_gen_100hz U_tick_gen (
        .clk(clk),
        .reset(reset),
        .i_run_stop(~sw_time_set),
        .o_tick_100hz(tick_100hz)
    );


    wire [1:0] sel;
    select_unit U_SEL (
        .clk(clk),
        .reset(reset),
        .en(sw_time_set),
        .btn_next(btn_next),
        .sel(sel)
    );


    wire [6:0] msec;
    set_counter #(
        .WIDTH(7),
        .MAX  (100)
    ) U_MSEC (
        .clk(clk),
        .reset(reset),
        .en_tick(en_tick),
        .i_tick(tick_100hz),
        .o_tick(sec_tick),
        .count(msec),
        .set_en(sw_time_set),
        .sel_me(sel == 2'b00),
        .up(up_count),
        .down(down_count)
    );


    wire [5:0] sec;
    set_counter #(
        .WIDTH(6),
        .MAX  (60)
    ) U_SEC (
        .clk(clk),
        .reset(reset),
        .en_tick(en_tick),
        .i_tick(sec_tick),
        .o_tick(min_tick),
        .count(sec),
        .set_en(sw_time_set),
        .sel_me(sel == 2'b01),
        .up(up_count),
        .down(down_count)
    );


    wire [5:0] min;
    set_counter #(
        .WIDTH(6),
        .MAX  (60)
    ) U_MIN (
        .clk(clk),
        .reset(reset),
        .en_tick(en_tick),
        .i_tick(min_tick),
        .o_tick(hour_tick),
        .count(min),
        .set_en(sw_time_set),
        .sel_me(sel == 2'b10),
        .up(up_count),
        .down(down_count)
    );


    wire [4:0] hour;
    set_counter #(
        .WIDTH(5),
        .MAX  (24)
    ) U_HOUR (
        .clk(clk),
        .reset(reset),
        .en_tick(en_tick),
        .i_tick(hour_tick),
        .o_tick(),
        .count(hour),
        .set_en(sw_time_set),
        .sel_me(sel == 2'b11),
        .up(up_count),
        .down(down_count)
    );

    assign c_msec = msec;
    assign c_sec  = sec;
    assign c_min  = min;
    assign c_hour = hour;

endmodule


module select_unit (
    input clk,
    input reset,
    input en,
    input btn_next,
    output reg [1:0] sel
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            sel <= 2'b00;
        end else if (en && btn_next) begin
            sel <= sel + 2'b01;
        end
    end
endmodule


module set_counter #(
    parameter WIDTH = 7,
    parameter MAX   = 100
) (
    input clk,
    input reset,

    input                  en_tick,
    input                  i_tick,
    output reg             o_tick,
    output     [WIDTH-1:0] count,

    input set_en,
    input sel_me,
    input up,
    input down
);

    reg [WIDTH-1:0] counter_reg, counter_next;
    assign count = counter_reg;

    always @(*) begin
        o_tick = 1'b0;
        if (en_tick && i_tick) begin
            if (counter_reg == (MAX - 1)) o_tick = 1'b1;
        end
    end

    always @(*) begin
        counter_next = counter_reg;

        // 1) time-set
        if (set_en && sel_me) begin
            if (up && !down) begin
                if (counter_reg == (MAX - 1)) counter_next = 0;
                else counter_next = counter_reg + 1'b1;
            end else if (down && !up) begin
                if (counter_reg == 0) counter_next = (MAX - 1);
                else counter_next = counter_reg - 1'b1;
            end
        end else if (en_tick && i_tick) begin
            if (counter_reg == (MAX - 1)) counter_next = 0;
            else counter_next = counter_reg + 1'b1;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) counter_reg <= 0;
        else counter_reg <= counter_next;
    end

endmodule


//===============================
// Tick generator 100hz
//===============================
module tick_gen_100hz (
    input clk,
    input reset,
    input i_run_stop,
    output reg o_tick_100hz
);
    parameter F_COUNT = 100_000_000 / 100;
    reg [$clog2(F_COUNT)-1:0] r_counter;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_counter <= 0;
            o_tick_100hz <= 1'b0;
        end else begin
            if (i_run_stop) begin
                r_counter <= r_counter + 1;
                if (r_counter == (F_COUNT - 1)) begin
                    r_counter <= 0;
                    o_tick_100hz <= 1'b1;
                end else begin
                    o_tick_100hz <= 1'b0;
                end
            end else begin
                o_tick_100hz <= 1'b0;
            end
        end
    end
endmodule
