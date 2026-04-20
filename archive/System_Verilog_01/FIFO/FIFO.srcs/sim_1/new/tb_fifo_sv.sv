`timescale 1ns / 1ps


interface fifo_interface (
    input logic clk
);
    logic rst;
    logic we;
    logic re;
    logic [7:0]wdata;

    logic [7:0]rdata;
    logic full;
    logic empty;

endinterface  //fifo_interface


class transaction;
    rand bit       we;
    rand bit       re;
    rand bit [7:0] wdata;

    logic          rst;
    logic          full;
    logic    [7:0] rdata;
    logic          empty;

    function void display(string name);
        $display(
            "%t : [%s] push = %2h, wdata = %2h, full = %2h, pop = %2h, rdata = %2h, empty = %h",
            $time, name, we, wdata, full, re, rdata, empty);
    endfunction  //new()
endclass  //transaction


class generator;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    event gen_next_ev;

    function new(mailbox#(transaction) gen2drv_mbox, event gen_next_ev);
        this.gen2drv_mbox = gen2drv_mbox;
        this.gen_next_ev  = gen_next_ev;
    endfunction  //new()

    task run(int run_count);
        repeat (run_count) begin
            tr = new;
            tr.randomize();
            gen2drv_mbox.put(tr);
            tr.display("gen");
            @(gen_next_ev);
        end
    endtask  //run
endclass  //generator


class driver;  // capture posedge + 1ns
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual fifo_interface fifo_if;

    function new(mailbox#(transaction) gen2drv_mbox,
                 virtual fifo_interface fifo_if);
        this.gen2drv_mbox = gen2drv_mbox;
        this.fifo_if = fifo_if;
    endfunction  //new()

    task preset();
        fifo_if.rst = 1;
        fifo_if.wdata = 0;
        fifo_if.we = 0;
        fifo_if.re = 0;
        @(negedge fifo_if.clk);
        @(negedge fifo_if.clk);
        fifo_if.rst = 0;
        @(negedge fifo_if.clk);
        // add assertion
    endtask  //preset

    task push();
        fifo_if.we    = tr.we;
        fifo_if.wdata = tr.wdata;
        fifo_if.re    = tr.re;
    endtask  //push

    task pop();
        fifo_if.we    = tr.we;
        fifo_if.wdata = tr.wdata;
        fifo_if.re    = tr.re;
    endtask  //pop

    task run();
        forever begin
            gen2drv_mbox.get(tr);
            @(posedge fifo_if.clk);
            #1;
            if (tr.we) push();
            else fifo_if.we = 0;
            if (tr.re) pop();
            else fifo_if.re = 0;
        end
    endtask  //run
endclass  //driver


class monitor;  // capture negedge output
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    virtual fifo_interface fifo_if;

    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual fifo_interface fifo_if);
        this.mon2scb_mbox = mon2scb_mbox;
        this.fifo_if = fifo_if;
    endfunction  //new()

    task run();
        forever begin
            tr = new;
            @(negedge fifo_if.clk);
            tr.we    = fifo_if.we;
            tr.re    = fifo_if.re;
            tr.wdata = fifo_if.wdata;
            tr.rdata = fifo_if.rdata;
            tr.full  = fifo_if.full;
            tr.empty = fifo_if.empty;
            tr.display("mon");
            mon2scb_mbox.put(tr);
        end
    endtask  //run
endclass  //monitor


class scoreboard;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    event gen_next_ev;

    // queue
    logic [7:0] fifo_queue[$:16];
    logic [7:0] compare_data;

    function new(mailbox#(transaction) mon2scb_mbox, event gen_next_ev);
        this.mon2scb_mbox = mon2scb_mbox;
        this.gen_next_ev  = gen_next_ev;
    endfunction  //new()

    task run();
        forever begin
            mon2scb_mbox.get(tr);
            tr.display("scb");
            // push
            if (tr.we & (!tr.full)) begin
                fifo_queue.push_front(tr.wdata);
            end
            // pop
            if (tr.re & (!tr.empty)) begin
                // pass/fail
                compare_data = fifo_queue.pop_back();
                if (compare_data == tr.rdata) begin
                    $display("pass");
                end else begin
                    $display("fail");
                end
            end
            ->gen_next_ev;
        end
    endtask  //run
endclass  //scoreboard


class environment;
    generator              gen;
    driver                 drv;
    monitor                mon;
    scoreboard             scb;

    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;

    event                  gen_next_ev;

    function new(virtual fifo_interface fifo_if);
        gen2drv_mbox = new;
        mon2scb_mbox = new;
        gen = new(gen2drv_mbox, gen_next_ev);
        drv = new(gen2drv_mbox, fifo_if);
        mon = new(mon2scb_mbox, fifo_if);
        scb = new(mon2scb_mbox, gen_next_ev);
    endfunction  //new()

    task run();
        drv.preset();
        fork
            gen.run(10);
            drv.run();
            mon.run();
            scb.run();
        join_any
        #10;
        $stop;
    endtask  //run

endclass  //environment


module tb_fifo_sv ();

    logic clk;
    fifo_interface fifo_if (clk);
    environment env;

    fifo_sv dut (
        .clk  (clk),
        .rst  (fifo_if.rst),
        .we   (fifo_if.we),
        .re   (fifo_if.re),
        .wdata(fifo_if.wdata),
        .rdata(fifo_if.rdata),
        .full (fifo_if.full),
        .empty(fifo_if.empty)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        env = new(fifo_if);
        env.run();
    end

endmodule
