`timescale 1ns / 1ps

interface adder_interface;
    logic [31:0] a;
    logic [31:0] b;
    logic        mode;
    logic [31:0] s;
    logic        c;
endinterface

// stimulus(vector)
class transaction;
    rand bit [31:0] a;
    rand bit [31:0] b;
    rand bit        mode;
    logic    [31:0] s;
    logic           c;
endclass

//generator for randomize stimulus
class generator;
    // tr : transaction handler
    transaction tr;

    mailbox #(transaction) gen2drv_mbox;
    event gen_next_ev;

    function new(mailbox#(transaction) gen2drv_mbox, event gen_next_ev);
        this.gen2drv_mbox = gen2drv_mbox;
        this.gen_next_ev  = gen_next_ev;
    endfunction

    task run(int count);
        repeat (count) begin
            tr = new();
            tr.randomize();
            gen2drv_mbox.put(tr);
            @(gen_next_ev);
        end
    endtask

endclass  //generator

class driver;

    transaction tr;
    virtual adder_interface adder_if;

    mailbox #(transaction) gen2drv_mbox;

    event mon_next_ev;

    function new(mailbox#(transaction) gen2drv_mbox, event mon_next_ev,
                 virtual adder_interface adder_if);
        this.adder_if     = adder_if;
        this.mon_next_ev  = mon_next_ev;
        this.gen2drv_mbox = gen2drv_mbox;
    endfunction

    task run();
        forever begin
            gen2drv_mbox.get(tr);
            adder_if.a    = tr.a;
            adder_if.b    = tr.b;
            adder_if.mode = tr.mode;
            #10;
            // event generation
            ->mon_next_ev;
        end
    endtask

endclass  //driver

class monitor;
    transaction tr;
    virtual adder_interface adder_if;
    mailbox #(transaction) mon2scb_mbox;
    event mon_next_ev;


    function new(mailbox#(transaction) mon2scb_mbox, event mon_next_ev,
                 virtual adder_interface adder_if);

        this.mon2scb_mbox = mon2scb_mbox;
        this.mon_next_ev = mon_next_ev;
        this.adder_if = adder_if;

    endfunction  //new()

    task run();
        forever begin
            @(mon_next_ev);
            tr = new();
            tr.a = adder_if.a;
            tr.b = adder_if.b;
            tr.mode = adder_if.mode;
            tr.s = adder_if.s;
            tr.c = adder_if.c;
            mon2scb_mbox.put(tr);

        end
    endtask  //run
endclass  //monitor

class scoreboard;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    event gen_next_ev;
    function new(mailbox#(transaction) mon2scb_mbox, event gen_next_ev);
        this.mon2scb_mbox = mon2scb_mbox;
        this.gen_next_ev  = gen_next_ev;
    endfunction

    task run();
        forever begin
            mon2scb_mbox.get(tr);
            // compare, pass, fail
            $display("%t:a = %d, b = %d, mode = %d, s = %d, c = %d", $time,
                     tr.a, tr.b, tr.mode, tr.s, tr.c);
            ->gen_next_ev;
        end

    endtask  //run
endclass  //scoreboard

class environment;

    generator gen;
    driver    drv;
    monitor   mon;
    scoreboard scb;

    mailbox #(transaction) gen2drv_mbox; // gen -> drv
    mailbox #(transaction) mon2scb_mbox; // mon -> scb
    event gen_next_ev; // scb to gen
    event mon_next_ev; // drv to mon

    function new(virtual adder_interface adder_if);
        gen2drv_mbox = new();
        mon2scb_mbox = new();
        gen          = new(gen2drv_mbox, gen_next_ev);
        drv          = new(gen2drv_mbox, mon_next_ev, adder_if);
        mon          = new(mon2scb_mbox, mon_next_ev, adder_if);
        scb          = new(mon2scb_mbox, gen_next_ev);
    endfunction

    task run();
        fork
            gen.run(10);
            drv.run();
            mon.run();
            scb.run();
        join_any
        $stop;
    endtask  //run

endclass


module tb_adder_verification ();

    adder_interface adder_if ();
    environment env;

    adder dut (
        .a(adder_if.a),
        .b(adder_if.b),
        .mode(adder_if.mode),
        .s(adder_if.s),
        .c(adder_if.c)
    );

    initial begin
        // constructor
        env = new(adder_if);

        //exe
        env.run();
    end
endmodule
