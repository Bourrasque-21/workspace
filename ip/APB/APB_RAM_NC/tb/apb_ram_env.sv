`ifndef COMPONENT_SV
`define COMPONENT_SV

// `include "uvm_macros.svh"
// import uvm_pkg::*;

class apb_env extends uvm_env;
    `uvm_component_utils(apb_env)

    apb_agent agt;
    apb_scoreboard srb;
    apb_coverage cov;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction  //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt = apb_agent::type_id::create("agt", this);
        srb = apb_scoreboard::type_id::create("srb", this);
        cov = apb_coverage::type_id::create("cov", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        agt.mon.ap.connect(srb.ap_imp);
        agt.mon.ap.connect(cov.analysis_export);
    endfunction
endclass  //component 

`endif
