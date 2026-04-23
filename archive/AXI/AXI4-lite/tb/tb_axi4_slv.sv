`timescale 1ns / 1ps

module axi_slave_check_tb;
    logic        ACLK;
    logic        ARESETn;
    logic [31:0] AWADDR;
    logic        AWVALID;
    logic        AWREADY;
    logic [31:0] WDATA;
    logic        WVALID;
    logic        WREADY;
    logic [1:0]  BRESP;
    logic        BVALID;
    logic        BREADY;
    logic [31:0] ARADDR;
    logic        ARVALID;
    logic        ARREADY;
    logic [31:0] RDATA;
    logic        RVALID;
    logic        RREADY;
    logic [1:0]  RRESP;

    axi_slave dut (
        .ACLK    (ACLK),
        .ARESETn (ARESETn),
        .AWADDR  (AWADDR),
        .AWVALID (AWVALID),
        .AWREADY (AWREADY),
        .WDATA   (WDATA),
        .WVALID  (WVALID),
        .WREADY  (WREADY),
        .BRESP   (BRESP),
        .BVALID  (BVALID),
        .BREADY  (BREADY),
        .ARADDR  (ARADDR),
        .ARVALID (ARVALID),
        .ARREADY (ARREADY),
        .RDATA   (RDATA),
        .RVALID  (RVALID),
        .RREADY  (RREADY),
        .RRESP   (RRESP)
    );

    always #5 ACLK = ~ACLK;

    task automatic wait_cycles(input int cycles);
        repeat (cycles) @(posedge ACLK);
    endtask

    task automatic drive_aw(input logic [31:0] addr);
        AWADDR  <= addr;
        AWVALID <= 1'b1;
        do @(posedge ACLK); while (!AWREADY);
        AWVALID <= 1'b0;
    endtask

    task automatic drive_w(input logic [31:0] data);
        WDATA  <= data;
        WVALID <= 1'b1;
        do @(posedge ACLK); while (!WREADY);
        WVALID <= 1'b0;
    endtask

    task automatic wait_for_b;
        BREADY <= 1'b1;
        do @(posedge ACLK); while (!BVALID);
        @(posedge ACLK);
        BREADY <= 1'b0;
    endtask

    task automatic write_addr_first(
        input logic [31:0] addr,
        input logic [31:0] data,
        input int          delay_cycles
    );
        fork
            begin
                drive_aw(addr);
            end
            begin
                wait_cycles(delay_cycles);
                drive_w(data);
            end
        join
        wait_for_b();
    endtask

    task automatic write_data_first(
        input logic [31:0] addr,
        input logic [31:0] data,
        input int          delay_cycles
    );
        fork
            begin
                drive_w(data);
            end
            begin
                wait_cycles(delay_cycles);
                drive_aw(addr);
            end
        join
        wait_for_b();
    endtask

    task automatic read_and_check(
        input logic [31:0] addr,
        input logic [31:0] exp_data,
        input int          ready_delay
    );
        ARADDR  <= addr;
        ARVALID <= 1'b1;
        do @(posedge ACLK); while (!ARREADY);
        ARVALID <= 1'b0;

        wait_cycles(ready_delay);
        if (!RVALID) begin
            do @(posedge ACLK); while (!RVALID);
        end

        if (RDATA !== exp_data) begin
            $error("READ mismatch addr=%h exp=%h got=%h", addr, exp_data, RDATA);
        end

        RREADY <= 1'b1;
        @(posedge ACLK);
        RREADY <= 1'b0;
    endtask

    initial begin
        ACLK    = 1'b0;
        ARESETn = 1'b0;
        AWADDR  = 32'h0;
        AWVALID = 1'b0;
        WDATA   = 32'h0;
        WVALID  = 1'b0;
        BREADY  = 1'b0;
        ARADDR  = 32'h0;
        ARVALID = 1'b0;
        RREADY  = 1'b0;

        wait_cycles(4);
        ARESETn = 1'b1;
        wait_cycles(2);

        write_addr_first(32'h0000_0000, 32'h1111_1111, 3);
        write_data_first(32'h0000_0004, 32'h2222_2222, 3);
        write_addr_first(32'h0000_000C, 32'h4444_4444, 1);

        read_and_check(32'h0000_0000, 32'h1111_1111, 2);
        read_and_check(32'h0000_0004, 32'h2222_2222, 1);
        read_and_check(32'h0000_000C, 32'h4444_4444, 4);

        wait_cycles(5);
        $display("axi_slave_check_tb PASS");
        $finish;
    end
endmodule
