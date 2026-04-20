`timescale 1ns / 1ps

interface stopwatch_interface (
    input logic clk
);
    logic        reset;
    logic        cnt_mode;
    logic        sw_time_set;
    logic        btn_run_stop;
    logic        btn_clear;
    logic        btn_up;
    logic        btn_down;
    logic        btn_next;

    logic [25:0] stopwatch_time;
    logic [23:0] clock_time;
    wire         mon_clk_tick_100hz;
    wire         mon_sw_tick_100hz;

endinterface

class transaction;
    bit reset;
    bit cnt_mode;
    bit sw_time_set;
    rand bit btn_run_stop;
    rand bit btn_clear;
    rand bit btn_up;
    rand bit btn_down;
    rand bit btn_next;

    logic [25:0] stopwatch_time;
    logic [23:0] clock_time;
    bit mon_btn_evt;
    bit mon_sw_evt;
    bit mon_clk_tick_evt;
    bit mon_sw_tick_evt;


    constraint c_btn_by_mode {
        if (sw_time_set) {
            btn_run_stop dist {
                1 := 10,
                0 := 90
            };
            btn_clear dist {
                1 := 10,
                0 := 90
            };
            btn_up dist {
                1 := 20,
                0 := 80
            };
            btn_down dist {
                1 := 20,
                0 := 80
            };
            btn_next dist {
                1 := 30,
                0 := 70
            };
        } else {
            btn_run_stop dist {
                1 := 10,
                0 := 90
            };
            btn_clear dist {
                1 := 5,
                0 := 95
            };
            btn_up dist {
                1 := 7,
                0 := 93
            };
            btn_down dist {
                1 := 7,
                0 := 93
            };
            btn_next dist {
                1 := 5,
                0 := 95
            };
        }
    }
endclass

class generator;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    bit cur_cnt_mode;
    bit cur_sw_time_set;
    int btn_gap_min_ms;
    int btn_gap_max_ms;
    int cnt_gap_min_ms;
    int cnt_gap_max_ms;
    int clk_gap_0_min_ms;
    int clk_gap_0_max_ms;
    int clk_gap_1_min_ms;
    int clk_gap_1_max_ms;

    function new(mailbox#(transaction) gen2drv_mbox);
        this.gen2drv_mbox = gen2drv_mbox;
        cur_cnt_mode      = 0;
        cur_sw_time_set   = 1;
        btn_gap_min_ms    = 20;
        btn_gap_max_ms    = 50;
        cnt_gap_min_ms    = 100;
        cnt_gap_max_ms    = 500;
        clk_gap_0_min_ms  = 1000;
        clk_gap_0_max_ms  = 2000;
        clk_gap_1_min_ms  = 100;
        clk_gap_1_max_ms  = 500;
    endfunction

    function int get_next_clk_toggle_gap_ms();
        if (cur_sw_time_set == 1'b0) begin
            return $urandom_range(clk_gap_0_max_ms, clk_gap_0_min_ms);
        end
        return $urandom_range(clk_gap_1_max_ms, clk_gap_1_min_ms);
    endfunction

    task run(int run_count);
        int next_btn_gap_ms;
        int next_cnt_gap_ms;
        int next_clk_gap_ms;
        int step_ms;
        bit btn_evt_due;
        bit cnt_evt_due;
        bit clk_evt_due;

        next_btn_gap_ms = $urandom_range(btn_gap_max_ms, btn_gap_min_ms);
        next_cnt_gap_ms = $urandom_range(cnt_gap_max_ms, cnt_gap_min_ms);
        next_clk_gap_ms = get_next_clk_toggle_gap_ms();

        repeat (run_count) begin
            step_ms = (next_btn_gap_ms <= next_cnt_gap_ms) ?
                      next_btn_gap_ms : next_cnt_gap_ms;
            if (next_clk_gap_ms < step_ms) begin
                step_ms = next_clk_gap_ms;
            end
            #(step_ms * 1ms);

            next_btn_gap_ms -= step_ms;
            next_cnt_gap_ms -= step_ms;
            next_clk_gap_ms -= step_ms;
            btn_evt_due = (next_btn_gap_ms == 0);
            cnt_evt_due = (next_cnt_gap_ms == 0);
            clk_evt_due = (next_clk_gap_ms == 0);

            if (cnt_evt_due) begin
                cur_cnt_mode = ~cur_cnt_mode;
                next_cnt_gap_ms =
                    $urandom_range(cnt_gap_max_ms, cnt_gap_min_ms);
            end

            if (clk_evt_due) begin
                cur_sw_time_set = ~cur_sw_time_set;
                next_clk_gap_ms = get_next_clk_toggle_gap_ms();
            end

            tr = new;
            tr.cnt_mode    = cur_cnt_mode;
            tr.sw_time_set = cur_sw_time_set;

            if (btn_evt_due) begin
                assert (tr.randomize());
                next_btn_gap_ms =
                    $urandom_range(btn_gap_max_ms, btn_gap_min_ms);
            end else begin
                tr.btn_run_stop = 0;
                tr.btn_clear    = 0;
                tr.btn_up       = 0;
                tr.btn_down     = 0;
                tr.btn_next     = 0;
            end

            gen2drv_mbox.put(tr);
        end
    endtask
endclass

class driver;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual stopwatch_interface stopwatch_if;

    function new(mailbox#(transaction) gen2drv_mbox,
                 virtual stopwatch_interface stopwatch_if);
        this.gen2drv_mbox = gen2drv_mbox;
        this.stopwatch_if = stopwatch_if;
    endfunction

    task clear_buttons();
        stopwatch_if.btn_run_stop = 0;
        stopwatch_if.btn_clear    = 0;
        stopwatch_if.btn_up       = 0;
        stopwatch_if.btn_down     = 0;
        stopwatch_if.btn_next     = 0;
    endtask

    task preset();
        stopwatch_if.reset = 1;
        stopwatch_if.cnt_mode = 0;
        stopwatch_if.sw_time_set = 0;
        clear_buttons();
        @(posedge stopwatch_if.clk);
        @(posedge stopwatch_if.clk);
        stopwatch_if.reset = 0;
    endtask

    task run();
        forever begin
            gen2drv_mbox.get(tr);
            @(negedge stopwatch_if.clk);
            stopwatch_if.cnt_mode     = tr.cnt_mode;
            stopwatch_if.sw_time_set  = tr.sw_time_set;
            stopwatch_if.btn_run_stop = tr.btn_run_stop;
            stopwatch_if.btn_clear    = tr.btn_clear;
            stopwatch_if.btn_up       = tr.btn_up;
            stopwatch_if.btn_down     = tr.btn_down;
            stopwatch_if.btn_next     = tr.btn_next;
            @(negedge stopwatch_if.clk);
            clear_buttons();
        end
    endtask
endclass


class monitor;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    virtual stopwatch_interface stopwatch_if;
    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual stopwatch_interface stopwatch_if);
        this.mon2scb_mbox = mon2scb_mbox;
        this.stopwatch_if = stopwatch_if;
    endfunction

    task run();
        bit prev_cnt_mode, prev_tset, prev_reset;
        bit prev_clk_tick, prev_sw_tick;
        bit btn_evt, sw_evt, post_evt_sample, reset_evt;
        bit clk_tick_evt, sw_tick_evt;

        prev_cnt_mode   = stopwatch_if.cnt_mode;
        prev_tset       = stopwatch_if.sw_time_set;
        prev_reset      = stopwatch_if.reset;
        prev_clk_tick   = stopwatch_if.mon_clk_tick_100hz;
        prev_sw_tick    = stopwatch_if.mon_sw_tick_100hz;
        post_evt_sample = 0;

        forever begin
            @(posedge stopwatch_if.clk);
            #1;

            btn_evt = stopwatch_if.btn_run_stop | stopwatch_if.btn_clear |
                      stopwatch_if.btn_up | stopwatch_if.btn_down |
                      stopwatch_if.btn_next;

            sw_evt  = (stopwatch_if.cnt_mode != prev_cnt_mode) ||
                      (stopwatch_if.sw_time_set != prev_tset);

            reset_evt = (stopwatch_if.reset != prev_reset);

            clk_tick_evt = prev_clk_tick && !stopwatch_if.mon_clk_tick_100hz;
            sw_tick_evt = prev_sw_tick && !stopwatch_if.mon_sw_tick_100hz;

            if (btn_evt || sw_evt || clk_tick_evt || sw_tick_evt ||
                post_evt_sample || reset_evt) begin
                tr                  = new;
                tr.reset            = stopwatch_if.reset;
                tr.cnt_mode         = stopwatch_if.cnt_mode;
                tr.sw_time_set      = stopwatch_if.sw_time_set;
                tr.btn_run_stop     = stopwatch_if.btn_run_stop;
                tr.btn_clear        = stopwatch_if.btn_clear;
                tr.btn_up           = stopwatch_if.btn_up;
                tr.btn_down         = stopwatch_if.btn_down;
                tr.btn_next         = stopwatch_if.btn_next;
                tr.stopwatch_time   = stopwatch_if.stopwatch_time;
                tr.clock_time       = stopwatch_if.clock_time;
                tr.mon_btn_evt      = btn_evt;
                tr.mon_sw_evt       = sw_evt;
                tr.mon_clk_tick_evt = clk_tick_evt;
                tr.mon_sw_tick_evt  = sw_tick_evt;
                mon2scb_mbox.put(tr);
            end

            post_evt_sample = btn_evt || sw_evt;

            prev_cnt_mode   = stopwatch_if.cnt_mode;
            prev_tset       = stopwatch_if.sw_time_set;
            prev_reset      = stopwatch_if.reset;
            prev_clk_tick   = stopwatch_if.mon_clk_tick_100hz;
            prev_sw_tick    = stopwatch_if.mon_sw_tick_100hz;
        end
    endtask


endclass


class scoreboard;
    transaction                   tr;
    mailbox #(transaction)        mon2scb_mbox;

    bit                           ref_running;
    bit                    [ 1:0] ref_sel;
    bit                           prev_btn_run_stop;
    bit                           prev_btn_next;
    bit                           prev_sw_time_set;
    bit                           prev_cnt_mode;

    logic                  [25:0] ref_stopwatch_time;
    logic                  [23:0] ref_clock_time;

    int                           sw_pass_cnt;
    int                           sw_fail_cnt;
    int                           clk_pass_cnt;
    int                           clk_fail_cnt;
    int                           btn_run_stop_cnt;
    int                           btn_clear_cnt;
    int                           btn_up_cnt;
    int                           btn_down_cnt;
    int                           btn_next_cnt;
    int                           cnt_mode_toggle_cnt;
    int                           sw_time_set_toggle_cnt;
    int                           run_scenario_cnt;
    int                           stop_scenario_cnt;
    int                           clear_scenario_cnt;
    int                           timeset_scenario_cnt;
    int                           rollover_scenario_cnt;
    bit                           scenario_run_hit;
    bit                           scenario_stop_hit;
    bit                           scenario_clear_hit;
    bit                           scenario_timeset_hit;
    bit                           scenario_rollover_hit;

    covergroup cg_inputs;
        option.per_instance = 1;
        cp_btn_run_stop: coverpoint tr.btn_run_stop {bins pressed = {1};}
        cp_btn_clear: coverpoint tr.btn_clear {bins pressed = {1};}
        cp_btn_up: coverpoint tr.btn_up {bins pressed = {1};}
        cp_btn_down: coverpoint tr.btn_down {bins pressed = {1};}
        cp_btn_next: coverpoint tr.btn_next {bins pressed = {1};}
        cp_cnt_mode: coverpoint tr.cnt_mode {bins low = {0}; bins high = {1};}
        cp_sw_time_set: coverpoint tr.sw_time_set {
            bins low = {0}; bins high = {1};
        }
        x_mode_tset: cross cp_cnt_mode, cp_sw_time_set;
    endgroup

    covergroup cg_scenarios;
        option.per_instance = 1;
        cp_run: coverpoint scenario_run_hit {bins hit = {1};}
        cp_stop: coverpoint scenario_stop_hit {bins hit = {1};}
        cp_clear: coverpoint scenario_clear_hit {bins hit = {1};}
        cp_timeset: coverpoint scenario_timeset_hit {bins hit = {1};}
        cp_rollover: coverpoint scenario_rollover_hit {bins hit = {1};}
    endgroup

    function new(mailbox#(transaction) mon2scb_mbox);
        this.mon2scb_mbox           = mon2scb_mbox;
        this.ref_running            = 0;
        this.ref_sel                = 2'b00;
        this.prev_btn_run_stop      = 0;
        this.prev_btn_next          = 0;
        this.prev_sw_time_set       = 0;
        this.prev_cnt_mode          = 0;
        this.ref_stopwatch_time     = 0;
        this.ref_clock_time         = 0;
        this.sw_pass_cnt            = 0;
        this.sw_fail_cnt            = 0;
        this.clk_pass_cnt           = 0;
        this.clk_fail_cnt           = 0;
        this.btn_run_stop_cnt       = 0;
        this.btn_clear_cnt          = 0;
        this.btn_up_cnt             = 0;
        this.btn_down_cnt           = 0;
        this.btn_next_cnt           = 0;
        this.cnt_mode_toggle_cnt    = 0;
        this.sw_time_set_toggle_cnt = 0;
        this.run_scenario_cnt       = 0;
        this.stop_scenario_cnt      = 0;
        this.clear_scenario_cnt     = 0;
        this.timeset_scenario_cnt   = 0;
        this.rollover_scenario_cnt  = 0;
        this.scenario_run_hit       = 0;
        this.scenario_stop_hit      = 0;
        this.scenario_clear_hit     = 0;
        this.scenario_timeset_hit   = 0;
        this.scenario_rollover_hit  = 0;
        this.cg_inputs              = new;
        this.cg_scenarios           = new;
    endfunction

    task run();
        logic [25:0] exp_sw;
        logic [23:0] exp_clk;
        bit rs_rise;
        bit nx_rise;
        bit sw_checked;
        bit clk_checked;
        bit sw_ok;
        bit clk_ok;
        bit clear_valid;
        bit evt_sw_btn;
        bit evt_clk_btn;
        bit sw_tick_evt;
        bit clk_tick_evt;
        bit run_scenario_evt;
        bit stop_scenario_evt;
        bit clear_scenario_evt;
        bit timeset_scenario_evt;
        bit rollover_scenario_evt;
        logic [25:0] sw_log_ref;
        logic [23:0] clk_log_ref;

        forever begin
            mon2scb_mbox.get(tr);

            if (tr.reset) begin
                ref_stopwatch_time = 0;
                ref_clock_time     = 0;
                ref_running        = 0;
                ref_sel            = 0;
                prev_sw_time_set   = 0;
                prev_cnt_mode      = 0;
                continue;
            end

            rs_rise = tr.btn_run_stop && !prev_btn_run_stop;
            nx_rise = tr.btn_next && !prev_btn_next;
            evt_sw_btn = tr.btn_run_stop || tr.btn_clear;
            evt_clk_btn = tr.sw_time_set && (tr.btn_up || tr.btn_down || tr.btn_next);
            sw_tick_evt = tr.mon_sw_tick_evt;
            clk_tick_evt = tr.mon_clk_tick_evt;
            clear_valid = tr.btn_clear && !tr.btn_run_stop && !ref_running;
            run_scenario_evt = rs_rise && !ref_running;
            stop_scenario_evt = rs_rise && ref_running;
            clear_scenario_evt = clear_valid;
            timeset_scenario_evt = evt_clk_btn;
            rollover_scenario_evt =
                ((sw_tick_evt && ref_running) &&
                 will_sw_rollover(ref_stopwatch_time, tr.cnt_mode)) ||
                ((clk_tick_evt && !tr.sw_time_set) &&
                 will_clk_rollover(ref_clock_time));

            if (tr.btn_run_stop) btn_run_stop_cnt++;
            if (tr.btn_clear) btn_clear_cnt++;
            if (tr.btn_up) btn_up_cnt++;
            if (tr.btn_down) btn_down_cnt++;
            if (tr.btn_next) btn_next_cnt++;
            if (tr.cnt_mode != prev_cnt_mode) cnt_mode_toggle_cnt++;
            if (tr.sw_time_set != prev_sw_time_set) sw_time_set_toggle_cnt++;
            if (run_scenario_evt) run_scenario_cnt++;
            if (stop_scenario_evt) stop_scenario_cnt++;
            if (clear_scenario_evt) clear_scenario_cnt++;
            if (timeset_scenario_evt) timeset_scenario_cnt++;
            if (rollover_scenario_evt) rollover_scenario_cnt++;
            scenario_run_hit = run_scenario_evt;
            scenario_stop_hit = stop_scenario_evt;
            scenario_clear_hit = clear_scenario_evt;
            scenario_timeset_hit = timeset_scenario_evt;
            scenario_rollover_hit = rollover_scenario_evt;
            if (tr.mon_btn_evt || tr.mon_sw_evt) cg_inputs.sample();
            if (run_scenario_evt || stop_scenario_evt || clear_scenario_evt ||
                timeset_scenario_evt || rollover_scenario_evt) begin
                cg_scenarios.sample();
            end

            exp_sw = ref_stopwatch_time;
            exp_clk = ref_clock_time;
            sw_checked = 0;
            clk_checked = 0;
            sw_ok = 1;
            clk_ok = 1;
            sw_log_ref = ref_stopwatch_time;
            clk_log_ref = ref_clock_time;

            if (evt_sw_btn || (tr.cnt_mode != prev_cnt_mode) || sw_tick_evt) begin
                sw_checked = 1;
                if (clear_valid) begin
                    exp_sw = 26'd0;
                end
                if (sw_tick_evt && ref_running) begin
                    ref_sw_tick(exp_sw, tr.cnt_mode);
                end
            end

            if (evt_clk_btn || (tr.sw_time_set != prev_sw_time_set) || clk_tick_evt) begin
                clk_checked = 1;
                if (tr.sw_time_set && (tr.btn_up || tr.btn_down)) begin
                    ref_clock_set_step(exp_clk, tr.btn_up, tr.btn_down);
                end
                if (clk_tick_evt && !tr.sw_time_set) begin
                    ref_clock_tick(exp_clk);
                end
            end

            if (sw_checked) begin
                sw_ok = (tr.stopwatch_time === exp_sw);
                sw_log_ref = exp_sw;

                if (sw_ok) begin
                    sw_pass_cnt++;
                    ref_stopwatch_time = sw_log_ref;
                end else begin
                    sw_fail_cnt++;
                end
            end

            if (clk_checked) begin
                clk_ok = (tr.clock_time === exp_clk);
                clk_log_ref = exp_clk;

                if (clk_ok) begin
                    clk_pass_cnt++;
                    ref_clock_time = clk_log_ref;
                end else begin
                    clk_fail_cnt++;
                end
            end

            if (clear_valid) begin
                ref_stopwatch_time = 26'd0;
            end

            if (tr.mon_btn_evt || tr.mon_sw_evt) begin
                if (!sw_checked) begin
                    sw_ok = 1;
                    sw_log_ref = tr.stopwatch_time;
                end
                if (!clk_checked) begin
                    clk_ok = 1;
                    clk_log_ref = tr.clock_time;
                end

                $display(
                    "%t : [SW][%s] ref=%h dut=%h [CLK][%s] ref=%h dut=%h\n%22s mode=%0b tset=%0b rs=%0b clr=%0b up=%0b down=%0b next=%0b",
                    $time, (sw_ok ? "PASS" : "FAIL"), sw_log_ref,
                    tr.stopwatch_time, (clk_ok ? "PASS" : "FAIL"), clk_log_ref,
                    tr.clock_time, "", tr.cnt_mode, tr.sw_time_set,
                    tr.btn_run_stop, tr.btn_clear, tr.btn_up, tr.btn_down,
                    tr.btn_next);

            end

            if (rs_rise) begin
                ref_running = ~ref_running;
            end
            if (tr.sw_time_set && nx_rise) begin
                ref_sel = ref_sel + 2'b01;
            end

            prev_sw_time_set  = tr.sw_time_set;
            prev_cnt_mode     = tr.cnt_mode;
            prev_btn_run_stop = tr.btn_run_stop;
            prev_btn_next     = tr.btn_next;
        end
    endtask

    task ref_sw_tick(inout logic [25:0] sw_ref, input bit mode);
        logic [6:0] msec;
        logic [5:0] sec, min;
        logic [6:0] hour;

        msec = sw_ref[6:0];
        sec  = sw_ref[12:7];
        min  = sw_ref[18:13];
        hour = sw_ref[25:19];

        if (mode) begin
            if (msec == 0) begin
                msec = 7'd99;
                if (sec == 0) begin
                    sec = 6'd59;
                    if (min == 0) begin
                        min = 6'd59;
                        if (hour == 0) hour = 7'd99;
                        else hour = hour - 1'b1;
                    end else min = min - 1'b1;
                end else sec = sec - 1'b1;
            end else msec = msec - 1'b1;
        end else begin
            if (msec == 7'd99) begin
                msec = 0;
                if (sec == 6'd59) begin
                    sec = 0;
                    if (min == 6'd59) begin
                        min = 0;
                        if (hour == 7'd99) hour = 0;
                        else hour = hour + 1'b1;
                    end else min = min + 1'b1;
                end else sec = sec + 1'b1;
            end else msec = msec + 1'b1;
        end

        sw_ref = {hour, min, sec, msec};
    endtask

    function bit will_sw_rollover(input logic [25:0] sw_ref, input bit mode);
        if (mode) begin
            return 1'b0;
        end
        return (sw_ref == {7'd99, 6'd59, 6'd59, 7'd99});
    endfunction

    task ref_clock_tick(inout logic [23:0] clk_ref);
        logic [6:0] msec;
        logic [5:0] sec, min;
        logic [4:0] hour;

        msec = clk_ref[6:0];
        sec  = clk_ref[12:7];
        min  = clk_ref[18:13];
        hour = clk_ref[23:19];

        if (msec == 7'd99) begin
            msec = 0;
            if (sec == 6'd59) begin
                sec = 0;
                if (min == 6'd59) begin
                    min = 0;
                    if (hour == 5'd23) hour = 0;
                    else hour = hour + 1'b1;
                end else min = min + 1'b1;
            end else sec = sec + 1'b1;
        end else msec = msec + 1'b1;

        clk_ref = {hour, min, sec, msec};
    endtask

    function bit will_clk_rollover(input logic [23:0] clk_ref);
        return (clk_ref == {5'd23, 6'd59, 6'd59, 7'd99});
    endfunction

    task ref_clock_set_step(inout logic [23:0] clk_ref, input bit up,
                            input bit down);
        logic [6:0] msec;
        logic [5:0] sec, min;
        logic [4:0] hour;

        msec = clk_ref[6:0];
        sec  = clk_ref[12:7];
        min  = clk_ref[18:13];
        hour = clk_ref[23:19];

        if (up && !down) begin
            case (ref_sel)
                2'b00: msec = (msec == 7'd99) ? 0 : (msec + 1);
                2'b01: sec = (sec == 6'd59) ? 0 : (sec + 1);
                2'b10: min = (min == 6'd59) ? 0 : (min + 1);
                2'b11: hour = (hour == 5'd23) ? 0 : (hour + 1);
            endcase
        end else if (down && !up) begin
            case (ref_sel)
                2'b00: msec = (msec == 0) ? 7'd99 : (msec - 1);
                2'b01: sec = (sec == 0) ? 6'd59 : (sec - 1);
                2'b10: min = (min == 0) ? 6'd59 : (min - 1);
                2'b11: hour = (hour == 0) ? 5'd23 : (hour - 1);
            endcase
        end

        clk_ref = {hour, min, sec, msec};
    endtask

    task report_summary();
        int miss_scn_cnt;
        miss_scn_cnt = 0;
        $display("========== SUMMARY ==========");
        $display("STOPWATCH: PASS=%0d  FAIL=%0d", sw_pass_cnt, sw_fail_cnt);
        $display("CLOCK    : PASS=%0d  FAIL=%0d", clk_pass_cnt, clk_fail_cnt);
        $display(
            "BTN COUNT: run_stop=%0d  clear=%0d  up=%0d  down=%0d  next=%0d",
            btn_run_stop_cnt, btn_clear_cnt, btn_up_cnt, btn_down_cnt,
            btn_next_cnt);
        $display("SW TOGGLE: cnt_mode=%0d  sw_time_set=%0d",
                 cnt_mode_toggle_cnt, sw_time_set_toggle_cnt);
        $display(
            "SCENARIO  : run=%0d stop=%0d clear=%0d timeset=%0d rollover=%0d",
            run_scenario_cnt, stop_scenario_cnt, clear_scenario_cnt,
            timeset_scenario_cnt, rollover_scenario_cnt);
        if (run_scenario_cnt == 0) begin
            $display("SCENARIO MISS: Run scenario");
            miss_scn_cnt++;
        end
        if (stop_scenario_cnt == 0) begin
            $display("SCENARIO MISS: Stop scenario");
            miss_scn_cnt++;
        end
        if (clear_scenario_cnt == 0) begin
            $display("SCENARIO MISS: Clear scenario");
            miss_scn_cnt++;
        end
        if (timeset_scenario_cnt == 0) begin
            $display("SCENARIO MISS: Time-set scenario");
            miss_scn_cnt++;
        end
        if (rollover_scenario_cnt == 0) begin
            $display("SCENARIO MISS: Counter rollover");
            miss_scn_cnt++;
        end
        $display("BTN COVERAGE : %0.2f%%", cg_inputs.get_coverage());
        $display("SCN COVERAGE : %0.2f%%", cg_scenarios.get_coverage());
    endtask


endclass

class environment;
    generator              gen;
    driver                 drv;
    monitor                mon;
    scoreboard             scb;

    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;
    function new(virtual stopwatch_interface stopwatch_if);
        gen2drv_mbox = new;
        mon2scb_mbox = new;
        gen = new(gen2drv_mbox);
        drv = new(gen2drv_mbox, stopwatch_if);
        mon = new(mon2scb_mbox, stopwatch_if);
        scb = new(mon2scb_mbox);
    endfunction

    task run(int run_count);
        drv.preset();
        fork
            gen.run(run_count);
            drv.run();
            mon.run();
            scb.run();
        join_any
        #100;
        disable fork;
    endtask
endclass

module tb_sv_zeit ();

    logic clk;
    stopwatch_interface stopwatch_if (clk);
    environment env;

    stopwatch_clock dut (
        .clk           (stopwatch_if.clk),
        .reset         (stopwatch_if.reset),
        .cnt_mode      (stopwatch_if.cnt_mode),
        .sw_time_set   (stopwatch_if.sw_time_set),
        .btn_run_stop  (stopwatch_if.btn_run_stop),
        .btn_clear     (stopwatch_if.btn_clear),
        .btn_up        (stopwatch_if.btn_up),
        .btn_down      (stopwatch_if.btn_down),
        .btn_next      (stopwatch_if.btn_next),
        .stopwatch_time(stopwatch_if.stopwatch_time),
        .clock_time    (stopwatch_if.clock_time)
    );

    assign stopwatch_if.mon_clk_tick_100hz = dut.U_CLOCK_DATAPATH.tick_100hz;
    assign stopwatch_if.mon_sw_tick_100hz  = dut.U_STOPWATCH_DATAPATH.w_tick_100hz;

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        env = new(stopwatch_if);
        env.run(200);
        env.scb.report_summary();

        #100;
        $finish;
    end

endmodule
