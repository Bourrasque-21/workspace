`ifndef SEQUENCE_SV
`define SEQUENCE_SV

// `include "uvm_macros.svh"
// import uvm_pkg::*;



// === sequence 0 (base)
class apb_base_seq extends uvm_sequence #(apb_seq_item);
    `uvm_object_utils(apb_base_seq)

    int num_loop = 0;

    function new(string name = "apb_base_seq");
        super.new(name);
    endfunction  //new()

    task do_write(bit [7:0] addr, output bit [31:0] data);
        apb_seq_item item;
        item = apb_seq_item::type_id::create("item");
        start_item(item);
        if (!item.randomize() with {
                pwrite == 1'b1;
                paddr == addr;
                pwdata == data;
            })
            `uvm_fatal(get_type_name(), "Randomization Failed!")
        finish_item(item);
        `uvm_info(get_type_name(),
                  $sformatf("do write complete : addr 0x%02h data = 0x%08h",
                            addr, data), UVM_MEDIUM)
    endtask  //body

    task do_read(bit [7:0] addr, output bit [31:0] data);
        apb_seq_item item;
        item = apb_seq_item::type_id::create("item");
        start_item(item);
        if (!item.randomize() with {
                pwrite == 1'b1;
                paddr == addr;
            })
            `uvm_fatal(get_type_name(), "Randomization Failed!")
        finish_item(item);
        rdata = item.prdata;
        `uvm_info(get_type_name(),
                  $sformatf("do read complete : addr 0x%02h data = 0x%08h",
                            addr, data), UVM_MEDIUM)
    endtask  //body
endclass  //ram_seq extends uvm_sequence



// === sequence 1
class apb_rw_seq extends apb_base_seq;
    `uvm_object_utils(apb_rw_seq)

    int num_loop = 0;
    bit [7:0] addr;
    bit [31:0] wdata, rdata;

    function new(string name = "apb_rw_seq");
        super.new(name);
    endfunction  //new()

    virtual task body();
        for (int i = 0; i < num_loop; i++) begin
            apb_seq_item item = apb_seq_item::type_id::create("item");
            addr  = (i % 64) * 4;
            wdata = $urandom();
            do_write(addr, wdata);
            do_read(addr, rdata);
        end
    endtask  //body
endclass  //ram_seq extends uvm_sequence


// === sequence 1
class apb_rand_seq extends apb_base_seq;
    `uvm_object_utils(apb_rand_seq)

    int num_loop = 0;
    bit [7:0] addr;
    bit [31:0] wdata, rdata;

    function new(string name = "apb_rand_seq");
        super.new(name);
    endfunction  //new()

    virtual task body();
        repeat (num_loop) begin
            apb_seq_item item = apb_seq_item::type_id::create("item");
            start_item(item);
            if (!item.randomize())
                `uvm_fatal(get_type_name(), "Randomize() Fail!")
            finish_item(item);
        end
    endtask  //body
endclass  //ram_seq extends uvm_sequence



`endif
