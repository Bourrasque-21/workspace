`ifndef TEST_SV
`define TEST_SV

// `include "uvm_macros.svh"
// import uvm_pkg::*;

//=== TEST 1
class apb_base_test extends uvm_test;
    `uvm_component_utils(apb_base_test)

    apb_env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction  //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = apb_env::type_id::create("env", this);
    endfunction

    virtual function void end_of_elaboration_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "===== UVM Structure=====", UVM_MEDIUM)
        uvm_top.print_topology();
    endfunction

endclass  //component 


//=== TEST 2
class apb_rw_test extends apb_base_test;
    `uvm_component_utils(apb_rw_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction  //new()

    virtual function void run_phase(uvm_phase phase);
        apb_rw_seq seq;
        phase.raise_objection(this);
        seq = apb_rw_seq::type_id::create("seq", this);
        seq.num_loop = 10;
        seq.start(env.agt.sqr);
        phase.drop_objection(this);
    endfunction

endclass  //component 


//=== TEST 3
class apb_rand_test extends apb_base_test;
    `uvm_component_utils(apb_rand_test)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction  //new()

    virtual function void run_phase(uvm_phase phase);
        apb_rand_seq seq;
        phase.raise_objection(this);
        seq = apb_rand_seq::type_id::create("seq", this);
        seq.num_loop = 10;
        seq.start(env.agt.sqr);
        phase.drop_objection(this);
    endfunction

endclass  //component 

`endif
