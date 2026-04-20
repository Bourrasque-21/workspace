class adder_tx extends uvm_sequence_item;
    rand bit a, b;
         bit y;

    `uvm_object_utils(adder_tx)

    function new(string name="adder_tx");
        super.new(name);
    endfunction
endclass


class adder_seq extends uvm_sequence #(adder_tx);
    `uvm_object_utils(adder_seq)

    function new(string name="adder_seq");
        super.new(name);
    endfunction

    virtual task body();
        adder_tx tx;
        repeat (10) begin
            tx = adder_tx::type_id::create("tx");
            assert(tx.randomize());
            start_item(tx);
            finish_item(tx);
        end
    endtask
endclass


interface adder_if;
    logic a, b, y;
endinterface


class adder_driver extends uvm_driver #(adder_tx);
    `uvm_component_utils(adder_driver)

    virtual adder_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual task run_phase(uvm_phase phase);
        adder_tx tx;
        forever begin
            seq_item_port.get_next_item(tx);

            vif.a = tx.a;
            vif.b = tx.b;

            seq_item_port.item_done();
        end
    endtask
endclass


class adder_monitor extends uvm_monitor;
    `uvm_component_utils(adder_monitor)

    virtual adder_if vif;
    uvm_analysis_port #(adder_tx) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        adder_tx tx;
        forever begin
            tx = adder_tx::type_id::create("tx");

            tx.a = vif.a;
            tx.b = vif.b;
            tx.y = vif.y;

            ap.write(tx);
            #1;
        end
    endtask
endclass


class adder_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(adder_scoreboard)

    uvm_analysis_imp #(adder_tx, adder_scoreboard) imp;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        imp = new("imp", this);
    endfunction

    virtual function void write(adder_tx tx);
        bit expected;
        expected = tx.a + tx.b;

        if (tx.y !== expected)
            `uvm_error("FAIL", $sformatf("a=%0d b=%0d y=%0d exp=%0d",
                                        tx.a, tx.b, tx.y, expected))
        else
            `uvm_info("PASS", "OK", UVM_LOW);
    endfunction
endclass


class adder_env extends uvm_env;
    `uvm_component_utils(adder_env)

    adder_driver drv;
    adder_monitor mon;
    adder_scoreboard scb;
    uvm_sequencer #(adder_tx) seqr;

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv  = adder_driver::type_id::create("drv", this);
        mon  = adder_monitor::type_id::create("mon", this);
        scb  = adder_scoreboard::type_id::create("scb", this);
        seqr = uvm_sequencer#(adder_tx)::type_id::create("seqr", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        drv.seq_item_port.connect(seqr.seq_item_export);
        mon.ap.connect(scb.imp);
    endfunction
endclass


class adder_test extends uvm_test;
    `uvm_component_utils(adder_test)

    adder_env env;

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = adder_env::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        adder_seq seq;
        phase.raise_objection(this);

        seq = adder_seq::type_id::create("seq");
        seq.start(env.seqr);

        #10;
        phase.drop_objection(this);
    endtask
endclass


module top;
    adder_if vif();

    adder dut (
        .a(vif.a),
        .b(vif.b),
        .y(vif.y)
    );

    initial begin
        uvm_config_db#(virtual adder_if)::set(null, "*", "vif", vif);
        run_test("adder_test");
    end
endmodule