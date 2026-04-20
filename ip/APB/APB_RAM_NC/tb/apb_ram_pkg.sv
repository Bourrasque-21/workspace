`ifndef APB_RAM_PKG_SV
`define APB_RAM_PKG_SV

package apb_ram_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    `include "apb_ram_seq_item.sv"
    `include "apb_ram_sequence.sv"
    `include "apb_ram_coverage.sv"
    `include "apb_ram_driver.sv"
    `include "apb_ram_monitor.sv"
    `include "apb_ram_agent.sv"
    `include "apb_ram_scoreboard.sv"
    `include "apb_ram_env.sv"
    `include "apb_ram_test.sv"

endpackage

`endif