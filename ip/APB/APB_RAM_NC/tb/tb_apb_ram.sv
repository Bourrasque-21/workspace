`timescale 1ns / 1ps
import uvm_pkg::*;
import apb_ram_pkg::*;

// === DUT
module tb_apb_ram ();
    logic pclk;
    logic presetn;

    always #5 pclk = ~pclk;

    apb_if vif (
        pclk,
        presetn
    );

    apb_ram dut (
        .PCLK   (pclk),
        .PRESET (presetn),
        .paddr  (vif.paddr),
        .pwrite (vif.pwrite),
        .penable(vif.penable),
        .pwdata (vif.pwdata),
        .psel   (vif.psel),
        .prdata (vif.prdata),
        .pready (vif.pready)
    );

    initial begin
        pclk = 0;
        presetn = 0;
        repeat(5);
        @(posedge pclk);
        presetn = 1;
    end

    initial begin
        uvm_config_db#(virtual apb_if)::set(null, "*", "vif", vif);
        run_test();
    end

    initial begin
        $fsdbDumpfile("novas.fsdb");
        $fsdbDumpvars(0, tb_apb_ram, "+all");
    end
endmodule
