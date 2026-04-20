`ifndef DRIVER_SV
`define DRIVER_SV

// `include "uvm_macros.svh"
// import uvm_pkg::*;

class apb_driver extends uvm_driver #(apb_seq_item);
    `uvm_component_utils(apb_driver)

    virtual apb_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction  //new()

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal(get_type_name(), "uvm_congig_db ERROR");
        end
    endfunction

    virtual function void run_phase(uvm_phase phase);
        apb_bus_init();
        wait (vif.presetn == 1);
        `uvm_info(get_type_name(), "Reset check", UVM_MEDIUM)

        forever begin
            apb_seq_item tx;
            seq_item_port.get_next_item(tx);
            drive_apb(tx);
            seq_item_port.item_done();
        end
    endfunction

    task apb_bus_init();
        vif.drv_cb.psel    <= 0;
        vif.drv_cb.penable <= 0;
        vif.drv_cb.pwrite  <= 0;
        vif.drv_cb.paddr   <= 0;
        vif.drv_cb.pwdata  <= 0;
    endtask  //apb_bus_init

    task drive_apb(apb_seq_item tx);
        // SETUP phase
        @(vif.drv_cb);
        vif.drv_cb.psel    <= 1;
        vif.drv_cb.penable <= 0;
        vif.drv_cb.pwrite  <= tx.pwrite;
        vif.drv_cb.paddr   <= tx.paddr;
        vif.drv_cb.pwdata  <= tx.pwrite ? tx.pwdata : 0;

        // ACCESS phase
        vif.drv_cb.penable    <= 1;
        while (!vif.drv_cb.pready) @(vif.drv_cb);
        if (!tx.pwrite) begin
            tx.prdata = vif.drv_cb.prdata;
            tx.pready = vif.drv_cb.pready;
        end

        //IDLE phase
        @(vif.drv_cb);
        vif.drv_cb.psel    <= 0;
        vif.drv_cb.penable <= 0;

        `uvm_info(get_type_name(), $sformatf("drv apb drive end: %s",
                                             tx.convert2string()), UVM_MEDIUM)
    endtask  //drive_apb
endclass  //apb_driver 

`endif
