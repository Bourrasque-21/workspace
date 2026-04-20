`ifndef COMPONENT_SV
`define COMPONENT_SV

`include "uvm_macros.svh"
import uvm_pkg::*;

// typedef uvm_sequencer #(apb_seq_item) apb_seqence;

class apb_agent extends uvm_agent;
    `uvm_component_utils(apb_agent)

    apb_driver drv;
    apb_monitor mon;
    uvm_sequencer #(apb_seq_item) sqr;  // apb_sequencer sqr;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction  //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv = apb_driver::type_id::create("drv", this);
        mon = apb_monitor::type_id::create("mon", this);
        sqr = apb_sequener::type_id::create("sqr", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(sqr.seq_item.export);
    endfunction
endclass  //apb_agent 

`endif
