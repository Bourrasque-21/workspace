
`timescale 1 ns / 1 ps

	module counter2_0 #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line


		// Parameters of Axi Slave Bus Interface S00_AXI
		parameter integer C_S00_AXI_DATA_WIDTH	= 32,
		parameter integer C_S00_AXI_ADDR_WIDTH	= 4
	)
	(
		// Users to add ports here
		output wire [3:0] fnd_digit,
		output wire [7:0] fnd_data,

		// User ports ends
		// Do not modify the ports beyond this line


		// Ports of Axi Slave Bus Interface S00_AXI
		input wire  s00_axi_aclk,
		input wire  s00_axi_aresetn,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
		input wire [2 : 0] s00_axi_awprot,
		input wire  s00_axi_awvalid,
		output wire  s00_axi_awready,
		input wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
		input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
		input wire  s00_axi_wvalid,
		output wire  s00_axi_wready,
		output wire [1 : 0] s00_axi_bresp,
		output wire  s00_axi_bvalid,
		input wire  s00_axi_bready,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
		input wire [2 : 0] s00_axi_arprot,
		input wire  s00_axi_arvalid,
		output wire  s00_axi_arready,
		output wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
		output wire [1 : 0] s00_axi_rresp,
		output wire  s00_axi_rvalid,
		input wire  s00_axi_rready
	);
	wire counter_run;
	wire counter_clear;
	wire [13:0] counter_value;

// Instantiation of Axi Bus Interface S00_AXI
	counter2_0_slave_lite_v2_0_S00_AXI # ( 
		.C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
		.C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
	) counter2_0_slave_lite_v2_0_S00_AXI_inst (
		.counter_run(counter_run),
		.counter_clear(counter_clear),
		.counter_value(counter_value),
		.S_AXI_ACLK(s00_axi_aclk),
		.S_AXI_ARESETN(s00_axi_aresetn),
		.S_AXI_AWADDR(s00_axi_awaddr),
		.S_AXI_AWPROT(s00_axi_awprot),
		.S_AXI_AWVALID(s00_axi_awvalid),
		.S_AXI_AWREADY(s00_axi_awready),
		.S_AXI_WDATA(s00_axi_wdata),
		.S_AXI_WSTRB(s00_axi_wstrb),
		.S_AXI_WVALID(s00_axi_wvalid),
		.S_AXI_WREADY(s00_axi_wready),
		.S_AXI_BRESP(s00_axi_bresp),
		.S_AXI_BVALID(s00_axi_bvalid),
		.S_AXI_BREADY(s00_axi_bready),
		.S_AXI_ARADDR(s00_axi_araddr),
		.S_AXI_ARPROT(s00_axi_arprot),
		.S_AXI_ARVALID(s00_axi_arvalid),
		.S_AXI_ARREADY(s00_axi_arready),
		.S_AXI_RDATA(s00_axi_rdata),
		.S_AXI_RRESP(s00_axi_rresp),
		.S_AXI_RVALID(s00_axi_rvalid),
		.S_AXI_RREADY(s00_axi_rready)
	);

	// Add user logic here
	wire counter_reset;
	wire counter_tick;

	assign counter_reset = ~s00_axi_aresetn | counter_clear;

	axi_counter_tick_gen U_COUNTER_TICK_GEN (
		.clk(s00_axi_aclk),
		.reset(counter_reset),
		.tick(counter_tick)
	);

	axi_counter_9999 U_COUNTER_9999 (
		.clk(s00_axi_aclk),
		.reset(counter_reset),
		.enable(counter_run),
		.tick(counter_tick),
		.count(counter_value)
	);

	axi_counter_fnd_controller U_COUNTER_FND_CONTROLLER (
		.clk(s00_axi_aclk),
		.reset(counter_reset),
		.value(counter_value),
		.fnd_digit(fnd_digit),
		.fnd_data(fnd_data)
	);

	// User logic ends

	endmodule

module axi_counter_tick_gen (
	input wire clk,
	input wire reset,
	output reg tick
);
	localparam integer TICK_COUNT = 10_000_000; // 100 MHz / 10 Hz
	reg [$clog2(TICK_COUNT)-1:0] tick_counter;

	always @(posedge clk) begin
		if (reset) begin
			tick_counter <= 0;
			tick <= 1'b0;
		end else begin
			if (tick_counter == TICK_COUNT - 1) begin
				tick_counter <= 0;
				tick <= 1'b1;
			end else begin
				tick_counter <= tick_counter + 1'b1;
				tick <= 1'b0;
			end
		end
	end
endmodule

module axi_counter_9999 (
	input wire clk,
	input wire reset,
	input wire enable,
	input wire tick,
	output reg [13:0] count
);
	always @(posedge clk) begin
		if (reset) begin
			count <= 14'd0;
		end else if (enable && tick) begin
			if (count == 14'd9999) begin
				count <= 14'd0;
			end else begin
				count <= count + 1'b1;
			end
		end
	end
endmodule

module axi_counter_fnd_controller (
	input wire clk,
	input wire reset,
	input wire [13:0] value,
	output reg [3:0] fnd_digit,
	output reg [7:0] fnd_data
);
	localparam integer REFRESH_COUNT = 100_000; // 100 MHz / 1 kHz

	reg [$clog2(REFRESH_COUNT)-1:0] refresh_counter;
	reg [1:0] digit_sel;
	reg [3:0] bcd_digit;

	wire [3:0] digit_1;
	wire [3:0] digit_10;
	wire [3:0] digit_100;
	wire [3:0] digit_1000;

	assign digit_1 = value % 10;
	assign digit_10 = (value / 10) % 10;
	assign digit_100 = (value / 100) % 10;
	assign digit_1000 = (value / 1000) % 10;

	always @(posedge clk) begin
		if (reset) begin
			refresh_counter <= 0;
			digit_sel <= 2'd0;
		end else begin
			if (refresh_counter == REFRESH_COUNT - 1) begin
				refresh_counter <= 0;
				digit_sel <= digit_sel + 1'b1;
			end else begin
				refresh_counter <= refresh_counter + 1'b1;
			end
		end
	end

	always @(*) begin
		case (digit_sel)
			2'd0: begin
				fnd_digit = 4'b1110;
				bcd_digit = digit_1;
			end
			2'd1: begin
				fnd_digit = 4'b1101;
				bcd_digit = digit_10;
			end
			2'd2: begin
				fnd_digit = 4'b1011;
				bcd_digit = digit_100;
			end
			2'd3: begin
				fnd_digit = 4'b0111;
				bcd_digit = digit_1000;
			end
			default: begin
				fnd_digit = 4'b1111;
				bcd_digit = 4'd0;
			end
		endcase

		case (bcd_digit)
			4'd0: fnd_data = 8'hc0;
			4'd1: fnd_data = 8'hf9;
			4'd2: fnd_data = 8'ha4;
			4'd3: fnd_data = 8'hb0;
			4'd4: fnd_data = 8'h99;
			4'd5: fnd_data = 8'h92;
			4'd6: fnd_data = 8'h82;
			4'd7: fnd_data = 8'hf8;
			4'd8: fnd_data = 8'h80;
			4'd9: fnd_data = 8'h90;
			default: fnd_data = 8'hff;
		endcase
	end
endmodule
