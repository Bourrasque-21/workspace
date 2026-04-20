`ifndef SCOREBOARD_SV
`define SCOREBOARD_SV

// `include "uvm_macros.svh"
// import uvm_pkg::*;

class apb_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(apb_scoreboard)

    uvm_analysis_imp #(apb_seq_item, apb_scoreboard) ap_imp;

    logic [31:0] ref_mem[0:63];
    logic [31:0] expected;
    int num_writes = 0;
    int num_reads = 0;
    int num_errors = 0;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction  //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap_imp = new("ap_imp", this);
    endfunction

    function void write(apb_seq_item tx);
        if (tx.pwrite) begin
            ref_mem[tx.paddr>>2] = tx.pwdata;
            num_writes++;
        end else begin
            num_reads++;
            expected = ref_mem[tx.paddr>>2];
            if (expected !== tx.prdata) begin
                num_errors++;
                `uvm_error(
                    get_type_name(),
                    $sformatf(
                        "FAIL! paddr = 0x%02h, exp = 0x%08h, prdata = 0x%08h",
                        tx.paddr, expected, tx.prdata))
            end else begin
                `uvm_info(get_type_name(), $sformatf(
                          "PASS! paddr = 0x%02h, exp = 0x%08h, prdata = 0x%08h",
                          tx.paddr,
                          expected,
                          tx.prdata
                          ), UVM_MEDIUM)
            end
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        string result = (num_errors == 0) ? "** PASS **" : "** FAIL **";
        `uvm_info(get_type_name(), "************ SUMMARY REPORT ************",
                  UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("Result    : %s", result),
                  UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("Write num : %0d", num_writes),
                  UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("Read num  : %0d", num_reads),
                  UVM_MEDIUM)
        `uvm_info(get_type_name(), $sformatf("Error num : %0d", num_errors),
                  UVM_MEDIUM)
        `uvm_info(get_type_name(), "****************************************",
                  UVM_MEDIUM)
    endfunction
endclass  //apb_scoreboard 

`endif
