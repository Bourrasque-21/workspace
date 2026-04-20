`include "uvm_macros.svh"
import uvm_pkg::*;

interface counter_if (
    input logic clk
);
    logic       rst_n;
    logic       enable;
    logic [3:0] count;

    clocking drv_cb @(posedge clk);
        default input #1step output #0; // input: pre time slot sampling / output: immmediately
        output rst_n;
        output enable;
    endclocking

    clocking mon_cb @(posedge clk);
        default input #1step output #0;
        input rst_n;
        input enable;
        input count;
    endclocking
endinterface  //counter_if


class counter_seq_item extends uvm_sequence_item;
    rand bit       rst_n;
    rand bit       enable;
    rand int       cycles;
    logic    [3:0] count;

    constraint c_cycle {cycles inside {[1 : 20]};}

    `uvm_object_utils_begin(counter_seq_item)
        `uvm_field_int(rst_n, UVM_ALL_ON)
        `uvm_field_int(enable, UVM_ALL_ON)
        `uvm_field_int(cycles, UVM_ALL_ON)
        `uvm_field_int(count, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "counter_seq_item");
        super.new(name);
    endfunction  //new()

    function string convert2string();
        return $sformatf(
            "rst_n = %0b enable = %0b cycles = %0d count = %0h",
            rst_n,
            enable,
            cycles,
            count
        );
    endfunction
endclass  //counter_sequence_item extends uvm_sequence_item


class counter_reset_seq extends uvm_sequence #(counter_seq_item);
    `uvm_object_utils(counter_reset_seq)

    function new(string name = "counter_reset_seq");
        super.new(name);
    endfunction  //new()

    virtual task body();
        counter_seq_item item;
        item = counter_seq_item::type_id::create("item");

        start_item(item);
        item.rst_n  = 0;
        item.enable = 0;
        item.cycles = 2;
        finish_item(item);
        `uvm_info(get_type_name(), "Reset Done", UVM_MEDIUM)
    endtask  //body
endclass  //counter_reset_seq extends uvm_sequence


class counter_count_seq extends uvm_sequence #(counter_seq_item);
    `uvm_object_utils(counter_count_seq)
    int num_transactions;

    function new(string name = "counter_count_seq");
        super.new(name);
        num_transactions = 0;
    endfunction  //new()

    virtual task body();
        counter_seq_item item;
        for (int i = 0; i < num_transactions; i++) begin
            item = counter_seq_item::type_id::create($sformatf("item_%0d", i));
            start_item(item);
            if (!item.randomize() with {
                    rst_n == 1;
                    enable == 1;
                    cycles inside {[1 : 20]};
                })
                `uvm_fatal(get_type_name(), "Randomization failed!!")
            finish_item(item);
            `uvm_info(
                get_type_name(), $sformatf(
                "[%0d/%0d] %s", i + 1, num_transactions, item.convert2string()),
                UVM_HIGH)
        end
    endtask  //body
endclass  //counter_count_seq extends uvm_sequence


class counter_master_seq extends uvm_sequence #(counter_seq_item);
    `uvm_object_utils(counter_master_seq)

    function new(string name = "counter_master_seq");
        super.new(name);
    endfunction  //new()

    virtual task body();
        counter_reset_seq reset_seq;
        counter_count_seq count_seq;

        `uvm_info(get_type_name(), "===== Phase 1: Reset =====", UVM_MEDIUM)
        reset_seq = counter_reset_seq::type_id::create("reset_seq");
        reset_seq.start(m_sequencer);

        `uvm_info(get_type_name(), "===== Phase 2: Count =====", UVM_MEDIUM)
        count_seq = counter_count_seq::type_id::create("count_seq");
        count_seq.num_transactions = 5;
        count_seq.start(m_sequencer);

        `uvm_info(get_type_name(), "===== Master Sequence done =====",
                  UVM_MEDIUM)
    endtask  //body
endclass  //counter_master_seq extends uvm_sequence


class counter_driver extends uvm_driver #(counter_seq_item);
    `uvm_component_utils(counter_driver)

    virtual counter_if c_if;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction  //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual counter_if)::get(this, "", "c_if", c_if))
            `uvm_fatal(get_type_name(), "cannot found c_if!")
        `uvm_info(get_type_name(), "build phase executed", UVM_HIGH);
    endfunction

    virtual task reset_dut();
        c_if.rst_n  = 0;
        c_if.enable = 0;
        repeat (2) @(posedge c_if.clk);
        c_if.rst_n = 1;
        @(posedge c_if.clk);
        `uvm_info(get_type_name(), "reset complete", UVM_HIGH);
    endtask  //reset_dut

    virtual task drive_item(counter_seq_item item);
        c_if.drv_cb.rst_n  <= item.rst_n;
        c_if.drv_cb.enable <= item.enable;
        // repeat (item.cycles)
        repeat (item.cycles) @(c_if.drv_cb);
        `uvm_info(get_type_name(), $sformatf("drive_cycles: %0d", item.cycles),
                  UVM_HIGH);
        `uvm_info(get_type_name(), item.convert2string(), UVM_MEDIUM);
    endtask  //drive_count

    virtual task run_phase(uvm_phase phase);
        counter_seq_item item;
        forever begin
            seq_item_port.get_next_item(item);
            drive_item(item);
            seq_item_port.item_done();
        end
    endtask
endclass  //counter_driver extends uvm_component


class counter_monitor extends uvm_monitor;
    `uvm_component_utils(counter_monitor)

    virtual counter_if c_if;
    uvm_analysis_port #(counter_seq_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction  //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual counter_if)::get(this, "", "c_if", c_if))
            `uvm_fatal(get_type_name(), "cannot found c_if!")
        `uvm_info(get_type_name(), "build phase executed", UVM_HIGH);
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            counter_seq_item item = counter_seq_item::type_id::create("item");
            // capture interface signals
            // @(posedge c_if.clk);
            // #1;
            @(c_if.mon_cb);
            #1;
            item.rst_n  = c_if.mon_cb.rst_n;
            item.enable = c_if.mon_cb.enable;
            item.count  = c_if.mon_cb.count;
            ap.write(item);
            `uvm_info(get_type_name(), item.convert2string(), UVM_MEDIUM);
        end
    endtask
endclass  //counter_monitor extends uvm_component


class counter_coverage extends uvm_subscriber #(counter_seq_item);
    `uvm_component_utils(counter_coverage)

    counter_seq_item item;

    covergroup counter_cg;
        cp_rst_n: coverpoint item.rst_n {
            bins active = {0}; bins inactive = {1};
        }
        cp_enable: coverpoint item.enable {bins on = {1}; bins off = {0};}
        cp_count: coverpoint item.count {
            bins zero = {0};
            bins low = {[1 : 7]};
            bins high = {[8 : 14]};
            bins max = {15};
        }
        // cross Coverage
        cx_rst_en: cross cp_rst_n, cp_enable;
        cx_en_count: cross cp_enable, cp_count;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        counter_cg = new();
    endfunction  //new()

    virtual function void write(counter_seq_item t);
        item = t;
        counter_cg.sample();
        `uvm_info(get_type_name(), $sformatf(
                  "counter_cg sampled: %s", item.convert2string()), UVM_MEDIUM)
    endfunction

    virtual function void report_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "==== Coverage Summary =====", UVM_LOW);
        `uvm_info(get_type_name(), $sformatf(
                  " Overall: %.1f%%", counter_cg.get_coverage()), UVM_LOW);
        `uvm_info(get_type_name(), $sformatf(
                  " rst_n: %.1f%%", counter_cg.cp_rst_n.get_coverage()),
                  UVM_LOW);
        `uvm_info(get_type_name(), $sformatf(
                  " enable: %.1f%%", counter_cg.cp_enable.get_coverage()),
                  UVM_LOW);
        `uvm_info(get_type_name(), $sformatf(
                  " count: %.1f%%", counter_cg.cp_count.get_coverage()),
                  UVM_LOW);
        `uvm_info(get_type_name(), $sformatf(
                  " cross(rst, en): %.1f%%", counter_cg.cx_rst_en.get_coverage()
                  ), UVM_LOW);
        `uvm_info(
            get_type_name(), $sformatf(
            " cross(en, count): %.1f%%", counter_cg.cx_en_count.get_coverage()),
            UVM_LOW);
    endfunction

endclass  //counter_coverage extends uvm_subscriber


class counter_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(counter_scoreboard)
    // declare analysis implementation, build write function
    uvm_analysis_imp #(counter_seq_item, counter_scoreboard) ap_imp;

    logic [3:0] expected;
    int error_count;
    int match_count;
    bit is_initialized;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap_imp = new("ap_imp", this);
        error_count = 0;
        match_count = 0;
        is_initialized = 0;
    endfunction  //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction

    virtual function void write(counter_seq_item item);
        `uvm_info(get_type_name(), $sformatf("Receive %s", item.convert2string()
                  ), UVM_MEDIUM);

        // verification logic
        if (!item.rst_n == 1) begin
            is_initialized = 1;
            expected = 0;
            return;
        end
        if (is_initialized) begin
            if (item.rst_n && item.enable) begin
                expected = expected + 1;
            end
            // 2. compare expected, dut
            if (expected !== item.count) begin
                `uvm_error(
                    get_type_name(),
                    $sformatf(
                        "Mismatch! exp = %0d, dut = %0d (rst_n = %0b, enable = %0b)",
                        expected, item.count, item.rst_n, item.enable))
                error_count++;
            end else begin
                `uvm_info(get_type_name(), $sformatf(
                          "Match! exp = %0d, dut = %0d (rst_n = %0b, enable = %0b)",
                          expected,
                          item.count,
                          item.rst_n,
                          item.enable
                          ), UVM_LOW)
                match_count++;
            end
        end
        // 1. reference model


    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info(get_type_name(), "===== Summary! =====", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf(
                  " Total transaction: %0d", match_count + error_count),
                  UVM_LOW)
        `uvm_info(get_type_name(), $sformatf(" Matches: %0d", match_count),
                  UVM_LOW)
        `uvm_info(get_type_name(), $sformatf(" Error: %0d", error_count),
                  UVM_LOW)
        if (error_count > 0) begin
            `uvm_error(get_type_name(),
                       $sformatf(" Test Failed: %0d mismatches detected",
                                 error_count))
        end else begin
            `uvm_info(get_type_name(), $sformatf(
                      " Test Passed: %0d all matches detected", match_count),
                      UVM_LOW)
        end
    endfunction
endclass  //counter_scoreboard extends uvm_scoreboard


class counter_agent extends uvm_agent;
    `uvm_component_utils(counter_agent)

    uvm_sequencer #(counter_seq_item) sqr;
    counter_driver drv;
    counter_monitor mon;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction  //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sqr = uvm_sequencer#(counter_seq_item)::type_id::create("sqr", this);
        drv = counter_driver::type_id::create("drv", this);
        mon = counter_monitor::type_id::create("mon", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction

endclass  //counter_agent extends uvm_component


class counter_environment extends uvm_env;
    `uvm_component_utils(counter_environment)

    counter_agent agt;
    counter_scoreboard scb;
    counter_coverage sbr;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction  //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt = counter_agent::type_id::create("agt", this);
        scb = counter_scoreboard::type_id::create("scb", this);
        sbr = counter_coverage::type_id::create("sbr", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agt.mon.ap.connect(scb.ap_imp);
        agt.mon.ap.connect(sbr.analysis_export);
    endfunction
endclass  //counter_agent extends uvm_component


class counter_test extends uvm_test;
    `uvm_component_utils(counter_test)

    counter_environment env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction  //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = counter_environment::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        counter_master_seq seq;

        phase.raise_objection(this);
        seq = counter_master_seq::type_id::create("seq");
        seq.start(env.agt.sqr);
        // #100;
        phase.drop_objection(this);
    endtask  //runphase

    virtual function void report_phase(uvm_phase phase);
        uvm_report_server svr = uvm_report_server::get_server();
        if (svr.get_severity_count(UVM_ERROR) == 0)
            `uvm_info(get_type_name(), "===== TEST PASS! =====", UVM_LOW)
        else `uvm_info(get_type_name(), "===== TEST FAIL! =====", UVM_LOW)
    endfunction
endclass  //counter_test extends uvm_component


module tb_counter ();
    logic clk;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    counter_if c_if (clk);

    counter dut (
        .clk   (clk),
        .rst_n (c_if.rst_n),
        .enable(c_if.enable),
        .count (c_if.count)
    );

    initial begin
        uvm_config_db#(virtual counter_if)::set(null, "*", "c_if", c_if);
        run_test("counter_test");
    end

endmodule
