`ifndef COVERAGE_SV
`define COVERAGE_SV

// `include "uvm_macros.svh"
// import uvm_pkg::*;

class apb_coverage extends uvm_subscriber;
    `uvm_component_utils(apb_coverage)

    apb_seq_item tx;

    covergroup apb_cg;

        cp_addr: coverpoint tx.paddr {
            bins addr_low = {[8'h00 : 8'h3c]};
            bins adder_mid1 = {[8'h40 : 8'h7c]};
            bins adder_mid2 = {[8'h80 : 8'hbc]};
            bins adder_high = {[8'hc0 : 8'hfc]};
        }
        cp_rw: coverpoint tx.pwrite {
            bins write_op = {1'b1}; bins read_op = {1'b0};
        }
        cp_wdata: coverpoint tx.pwdata {
            bins all_zeros = {32'h0000_0000};
            bins all_ones = {32'hffff_ffff};
            bins all_a = {32'haaaa_aaaa};
            bins all_5 = {32'h5555_5555};
            bins other = default;
        }
        cp_rdata: coverpoint tx.prdata {
            bins all_zeros = {32'h0000_0000};
            bins all_ones = {32'hffff_ffff};
            bins all_a = {32'haaaa_aaaa};
            bins all_5 = {32'h5555_5555};
            bins other = default;
        }

        cx_addr_rw: cross cp_addr, cp_rw;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        apb_cg = new();
    endfunction  //new()

    function void write(apb_seq_item t);
        tx = t;
        apb_cg.sample();
    endfunction

    virtual function void report_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "===== Coverage Summary =====", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf(
                  "cp_addr     : %.1f%%", apb_cg.cp_addr.get_coverage()),
                  UVM_LOW)
        `uvm_info(get_type_name(), $sformatf(
                  "cp_rw       : %.1f%%", apb_cg.cp_rw.get_coverage()), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf(
                  "cp_wdata    : %.1f%%", apb_cg.cp_wdata.get_coverage()),
                  UVM_LOW)
        `uvm_info(get_type_name(), $sformatf(
                  "cp_rdata    : %.1f%%", apb_cg.cp_rdata.get_coverage()),
                  UVM_LOW)
        `uvm_info(get_type_name(), $sformatf(
                  "cx_addr_rw  : %.1f%%", apb_cg.cx_addr_rw.get_coverage()),
                  UVM_LOW)
        `uvm_info(get_type_name(), $sformatf(
                  "Total       : %.1f%%", apb_cg.get_coverage()), UVM_LOW)
    endfunction
endclass  //component 

`endif
