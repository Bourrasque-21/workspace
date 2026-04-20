`timescale 1ns / 1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

`uvm_analysis_imp_decl(_exp)
`uvm_analysis_imp_decl(_act)

interface i2c_top_if;
    logic        clk;
    logic        rst;
    logic        mode_sw;
    logic [15:0] data_sw;
    logic        start_btn;
    logic [15:0] led;

    localparam int unsigned TXN_WAIT_CYCLES = 30000;

    task automatic init_signals();
        mode_sw   = 1'b0;
        data_sw   = 16'h0000;
        start_btn = 1'b0;
    endtask

    task automatic pulse_start();
        @(negedge clk);
        start_btn = 1'b1;
        @(negedge clk);
        start_btn = 1'b0;
    endtask

    task automatic wait_cycles(input int unsigned cycles);
        repeat (cycles) @(posedge clk);
    endtask

    task automatic wait_transaction();
        wait_cycles(TXN_WAIT_CYCLES);
    endtask
endinterface

class i2c_top_seq_item extends uvm_sequence_item;
    rand bit        op;
    rand bit [ 7:0] write_data;
    rand bit [ 7:0] read_data;
    bit      [15:0] observed_led;

    `uvm_object_utils_begin(i2c_top_seq_item)
        `uvm_field_int(op, UVM_DEFAULT)
        `uvm_field_int(write_data, UVM_DEFAULT)
        `uvm_field_int(read_data, UVM_DEFAULT)
        `uvm_field_int(observed_led, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "i2c_top_seq_item");
        super.new(name);
    endfunction
endclass

class i2c_top_sequencer extends uvm_sequencer #(i2c_top_seq_item);
    `uvm_component_utils(i2c_top_sequencer)

    function new(string name = "i2c_top_sequencer",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass

class i2c_top_driver extends uvm_driver #(i2c_top_seq_item);
    virtual i2c_top_if vif;
    uvm_analysis_port #(i2c_top_seq_item) exp_ap;

    `uvm_component_utils(i2c_top_driver)

    function new(string name = "i2c_top_driver", uvm_component parent = null);
        super.new(name, parent);
        exp_ap = new("exp_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual i2c_top_if)::get(
                this, "", "vif", vif
            )) begin
            `uvm_fatal("TOP_DRV",
                       "virtual interface i2c_top_if was not provided")
        end
    endfunction

    task run_phase(uvm_phase phase);
        i2c_top_seq_item tr;
        i2c_top_seq_item exp_tr;

        vif.init_signals();
        wait (vif.rst === 1'b0);

        forever begin
            seq_item_port.get_next_item(tr);

            case (tr.op)
                1'b0: begin
                    vif.mode_sw = 1'b0;
                    vif.data_sw = {8'h00, tr.write_data};
                    `uvm_info("TOP_DRV", $sformatf("WRITE 0x%02h", tr.write_data
                              ), UVM_MEDIUM)
                end

                1'b1: begin
                    vif.mode_sw = 1'b1;
                    vif.data_sw = {tr.read_data, 8'h00};
                    `uvm_info("TOP_DRV", $sformatf(
                              "READ expect 0x%02h", tr.read_data), UVM_MEDIUM)
                end
            endcase

            vif.pulse_start();

            exp_tr            = i2c_top_seq_item::type_id::create("exp_tr");
            exp_tr.op         = tr.op;
            exp_tr.write_data = tr.write_data;
            exp_tr.read_data  = tr.read_data;
            exp_ap.write(exp_tr);

            vif.wait_transaction();
            seq_item_port.item_done();
        end
    endtask
endclass

class i2c_top_monitor extends uvm_monitor;
    virtual i2c_top_if vif;
    uvm_analysis_port #(i2c_top_seq_item) item_ap;

    `uvm_component_utils(i2c_top_monitor)

    function new(string name = "i2c_top_monitor", uvm_component parent = null);
        super.new(name, parent);
        item_ap = new("item_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual i2c_top_if)::get(
                this, "", "vif", vif
            )) begin
            `uvm_fatal("TOP_MON",
                       "virtual interface i2c_top_if was not provided")
        end
    endfunction

    task run_phase(uvm_phase phase);
        i2c_top_seq_item       tr;
        bit                    sampled_op;
        bit              [7:0] sampled_write_data;
        bit              [7:0] sampled_read_data;

        wait (vif.rst === 1'b0);

        forever begin
            @(posedge vif.start_btn);
            if (vif.rst) begin
                continue;
            end

            tr                 = i2c_top_seq_item::type_id::create("mon_tr");
            sampled_op         = vif.mode_sw;
            sampled_write_data = vif.data_sw[7:0];
            sampled_read_data  = vif.data_sw[15:8];

            vif.wait_transaction();
            tr.op           = sampled_op;
            tr.write_data   = sampled_write_data;
            tr.read_data    = sampled_read_data;
            tr.observed_led = vif.led;
            item_ap.write(tr);
        end
    endtask
endclass

class i2c_top_coverage extends uvm_subscriber #(i2c_top_seq_item);
    bit cov_op;
    bit [7:0] cov_data;

    covergroup txn_cg;
        option.per_instance = 1;

        cp_op: coverpoint cov_op {bins write = {1'b0}; bins read = {1'b1};}

        cp_data: coverpoint cov_data {
            bins zero = {8'h00};
            bins one = {8'h01};
            bins all_ones = {8'hFF};
            bins pattern = {8'h55, 8'hAA};
            bins low = {[8'h01 : 8'h1F]};
            bins mid = {[8'h20 : 8'hDF]};
            bins high = {[8'hE0 : 8'hFE]};
        }

        op_x_data: cross cp_op, cp_data;
    endgroup

    `uvm_component_utils(i2c_top_coverage)

    function new(string name = "i2c_top_coverage", uvm_component parent = null);
        super.new(name, parent);
        txn_cg = new();
    endfunction

    function void write(i2c_top_seq_item t);
        cov_op   = t.op;
        cov_data = t.op ? t.read_data : t.write_data;
        txn_cg.sample();
    endfunction

    function void report_phase(uvm_phase phase);
        real cp_cov;
        real data_cov;
        real cross_cov;
        real total_cov;

        super.report_phase(phase);
        cp_cov    = txn_cg.cp_op.get_coverage();
        data_cov  = txn_cg.cp_data.get_coverage();
        cross_cov = txn_cg.op_x_data.get_coverage();
        total_cov = txn_cg.get_coverage();
        `uvm_info("TOP_COV", $sformatf(
                  {
                      "======I2C coverage summary=====\n",
                      "  cp                : %0.2f%%\n",
                      "  data              : %0.2f%%\n",
                      "  X data            : %0.2f%%\n",
                      "  total             : %0.2f%%"
                  },
                  cp_cov,
                  data_cov,
                  cross_cov,
                  total_cov
                  ), UVM_LOW)
    endfunction
endclass

class i2c_top_scoreboard extends uvm_component;
    uvm_analysis_imp_exp #(i2c_top_seq_item, i2c_top_scoreboard) exp_imp;
    uvm_analysis_imp_act #(i2c_top_seq_item, i2c_top_scoreboard) act_imp;

    i2c_top_seq_item pending_exp;
    bit pending_exp_valid;

    int unsigned compare_count;
    int unsigned pass_count;
    int unsigned error_count;

    `uvm_component_utils(i2c_top_scoreboard)

    function new(string name = "i2c_top_scoreboard",
                 uvm_component parent = null);
        super.new(name, parent);
        exp_imp = new("exp_imp", this);
        act_imp = new("act_imp", this);
    endfunction

    function automatic i2c_top_seq_item copy_item(input i2c_top_seq_item src,
                                                  input string name);
        i2c_top_seq_item item;

        item              = i2c_top_seq_item::type_id::create(name);
        item.op           = src.op;
        item.write_data   = src.write_data;
        item.read_data    = src.read_data;
        item.observed_led = src.observed_led;
        return item;
    endfunction

    function void write_exp(i2c_top_seq_item tr);
        if (pending_exp_valid) begin
            error_count++;
            `uvm_error(
                "TOP_SCB",
                "Received new expected item before previous compare completed")
        end

        pending_exp       = copy_item(tr, "exp_item");
        pending_exp_valid = 1'b1;
    endfunction

    function void write_act(i2c_top_seq_item tr);
        i2c_top_seq_item act_tr;

        if (!pending_exp_valid) begin
            error_count++;
            `uvm_error("TOP_SCB",
                       "Received actual item without a pending expected item")
            return;
        end

        act_tr = copy_item(tr, "act_item");
        compare_count++;

        if (pending_exp.op != act_tr.op) begin
            error_count++;
            `uvm_error("TOP_SCB", "Operation mismatch")
        end else begin
            case (pending_exp.op)
                1'b0: begin
                    if (act_tr.observed_led[15:8] !== pending_exp.write_data) begin
                        error_count++;
                        `uvm_error(
                            "TOP_SCB",
                            $sformatf(
                                "WRITE mismatch led[15:8]=0x%02h expected=0x%02h",
                                act_tr.observed_led[15:8],
                                pending_exp.write_data))
                    end else begin
                        pass_count++;
                    end
                end

                1'b1: begin
                    if (act_tr.observed_led[7:0] !== pending_exp.read_data) begin
                        error_count++;
                        `uvm_error(
                            "TOP_SCB",
                            $sformatf(
                                "READ mismatch led[7:0]=0x%02h expected=0x%02h",
                                act_tr.observed_led[7:0],
                                pending_exp.read_data))
                    end else begin
                        pass_count++;
                    end
                end
            endcase
        end

        pending_exp       = null;
        pending_exp_valid = 1'b0;
    endfunction

    function void report_phase(uvm_phase phase);
        int unsigned total_count;

        super.report_phase(phase);
        total_count = pass_count + error_count;
        `uvm_info("TOP_SCB", $sformatf(
                  {
                      "==== summary===\n",
                      "total: %0d\n",
                      "pass: %0d\n",
                      "fail: %0d"
                  },
                  total_count,
                  pass_count,
                  error_count
                  ), UVM_LOW)
    endfunction
endclass

class i2c_top_env extends uvm_env;
    i2c_top_sequencer  sequencer;
    i2c_top_driver     driver;
    i2c_top_monitor    monitor;
    i2c_top_coverage   coverage;
    i2c_top_scoreboard scoreboard;

    `uvm_component_utils(i2c_top_env)

    function new(string name = "i2c_top_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sequencer  = i2c_top_sequencer::type_id::create("sequencer", this);
        driver     = i2c_top_driver::type_id::create("driver", this);
        monitor    = i2c_top_monitor::type_id::create("monitor", this);
        coverage   = i2c_top_coverage::type_id::create("coverage", this);
        scoreboard = i2c_top_scoreboard::type_id::create("scoreboard", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        driver.seq_item_port.connect(sequencer.seq_item_export);
        driver.exp_ap.connect(scoreboard.exp_imp);
        monitor.item_ap.connect(scoreboard.act_imp);
        monitor.item_ap.connect(coverage.analysis_export);
    endfunction
endclass

class i2c_top_sequence extends uvm_sequence #(i2c_top_seq_item);
    `uvm_object_utils(i2c_top_sequence)

    function new(string name = "i2c_top_sequence");
        super.new(name);
    endfunction

    task body();
        i2c_top_seq_item tr;

        repeat (100) begin
            tr = i2c_top_seq_item::type_id::create("rand_write_tr");
            start_item(tr);
            if (!tr.randomize() with {op == 1'b0;}) begin
                `uvm_fatal("TOP_SEQ", "Failed to randomize write item")
            end
            tr.read_data = 8'h00;
            finish_item(tr);
        end
    endtask
endclass

class i2c_top_read_sequence extends i2c_top_sequence;
    `uvm_object_utils(i2c_top_read_sequence)

    function new(string name = "i2c_top_read_sequence");
        super.new(name);
    endfunction

    task body();
        i2c_top_seq_item tr;

        repeat (100) begin
            tr = i2c_top_seq_item::type_id::create("rand_read_tr");
            start_item(tr);
            if (!tr.randomize() with {op == 1'b1;}) begin
                `uvm_fatal("TOP_SEQ", "Failed to randomize read item")
            end
            tr.write_data = 8'h00;
            finish_item(tr);
        end
    endtask
endclass

class i2c_top_random_rw_sequence extends i2c_top_sequence;
    `uvm_object_utils(i2c_top_random_rw_sequence)

    function new(string name = "i2c_top_random_rw_sequence");
        super.new(name);
    endfunction

    task body();
        i2c_top_seq_item tr;

        repeat (100) begin
            tr = i2c_top_seq_item::type_id::create("rand_rw_tr");
            start_item(tr);
            if (!tr.randomize()) begin
                `uvm_fatal("TOP_SEQ", "Failed to randomize read/write item")
            end

            if (tr.op == 1'b0) begin
                tr.read_data = 8'h00;
            end else begin
                tr.write_data = 8'h00;
            end

            finish_item(tr);
        end
    endtask
endclass

class i2c_top_test extends uvm_test;
    i2c_top_env        env;
    virtual i2c_top_if vif;

    `uvm_component_utils(i2c_top_test)

    function new(string name = "i2c_top_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = i2c_top_env::type_id::create("env", this);

        if (!uvm_config_db#(virtual i2c_top_if)::get(
                this, "", "vif", vif
            )) begin
            `uvm_fatal("TOP_TEST",
                       "virtual interface i2c_top_if was not provided")
        end
    endfunction

    task run_phase(uvm_phase phase);
        i2c_top_sequence seq;

        phase.raise_objection(this);
        seq = i2c_top_sequence::type_id::create("seq");
        seq.start(env.sequencer);
        vif.wait_cycles(1000);
        phase.drop_objection(this);
    endtask
endclass

class i2c_top_read_test extends i2c_top_test;
    `uvm_component_utils(i2c_top_read_test)

    function new(string name = "i2c_top_read_test",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        i2c_top_read_sequence seq;

        phase.raise_objection(this);
        seq = i2c_top_read_sequence::type_id::create("seq");
        seq.start(env.sequencer);
        vif.wait_cycles(1000);
        phase.drop_objection(this);
    endtask
endclass

class i2c_top_random_rw_test extends i2c_top_test;
    `uvm_component_utils(i2c_top_random_rw_test)

    function new(string name = "i2c_top_random_rw_test",
                 uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        i2c_top_random_rw_sequence seq;

        phase.raise_objection(this);
        seq = i2c_top_random_rw_sequence::type_id::create("seq");
        seq.start(env.sequencer);
        vif.wait_cycles(1000);
        phase.drop_objection(this);
    endtask
endclass

module tb_I2C_MASTER;
    i2c_top_if vif ();

    I2C_TOP dut (
        .clk      (vif.clk),
        .rst      (vif.rst),
        .mode_sw  (vif.mode_sw),
        .data_sw  (vif.data_sw),
        .start_btn(vif.start_btn),
        .led      (vif.led)
    );

    initial begin
        vif.clk = 1'b0;
        forever #5 vif.clk = ~vif.clk;
    end

    initial begin
        vif.rst = 1'b1;
        vif.init_signals();
        repeat (8) @(posedge vif.clk);
        vif.rst = 1'b0;
    end

    initial begin
        uvm_config_db#(virtual i2c_top_if)::set(null, "*", "vif", vif);
        run_test("i2c_top_test");
    end
endmodule
