`timescale 1ns / 1ps


module axi_slave (
    input  logic        ACLK,
    input  logic        ARESETn,
    // WRITE TRANSACTION
    // AW
    input  logic [31:0] AWADDR,
    input  logic        AWVALID,
    output logic        AWREADY,
    // W
    input  logic [31:0] WDATA,
    input  logic        WVALID,
    output logic        WREADY,
    // B
    output logic [ 1:0] BRESP,
    output logic        BVALID,
    input  logic        BREADY,
    // READ TRANSACTION
    // AR
    input  logic [31:0] ARADDR,
    input  logic        ARVALID,
    output logic        ARREADY,
    // R
    output logic [31:0] RDATA,
    output logic        RVALID,
    input  logic        RREADY,
    output logic [ 1:0] RRESP
);


    logic [31:0] slv_reg0, slv_reg1, slv_reg2, slv_reg3;
    logic [31:0] awaddr_reg, awaddr_reg_next;
    logic [31:0] wdata_reg, wdata_reg_next;
    logic [31:0] rdata_reg, rdata_reg_next;
    logic aw_pending, aw_pending_next;
    logic w_pending, w_pending_next;
    logic write_en;
    logic read_en;

    typedef enum logic {
        B_IDLE,
        B_VALID
    } b_state_e;
    b_state_e b_state, b_state_next;

    typedef enum logic {
        R_IDLE,
        R_VALID
    } r_state_e;
    r_state_e r_state, r_state_next;

    //---- AW ----
    typedef enum logic {
        AW_IDLE,
        AW_VALID
    } aw_state_e;
    aw_state_e aw_state, aw_state_next;


    always_ff @(posedge ACLK) begin
        if (!ARESETn) begin  // sync reset
            aw_state    <= AW_IDLE;
            awaddr_reg  <= 32'h00;
            aw_pending  <= 1'b0;
        end else begin
            aw_state   <= aw_state_next;
            awaddr_reg <= awaddr_reg_next;
            if (write_en) begin
                aw_pending <= 1'b0;
            end else begin
                aw_pending <= aw_pending_next;
            end
        end
    end


    always_comb begin
        aw_state_next   = aw_state;
        awaddr_reg_next = awaddr_reg;
        aw_pending_next = aw_pending;
        AWREADY         = 1'b0;
        case (aw_state)
            AW_IDLE: begin
                AWREADY = 1'b0;
                if (AWVALID && !aw_pending && (b_state == B_IDLE)) begin
                    aw_state_next = AW_VALID;
                end
            end

            AW_VALID: begin
                AWREADY = !aw_pending && (b_state == B_IDLE);
                if (AWVALID && AWREADY) begin
                    awaddr_reg_next = AWADDR;
                    aw_pending_next = 1'b1;
                    aw_state_next   = AW_IDLE;
                end
            end
        endcase
    end
    //------------

    //---- W  ----
    typedef enum logic {
        W_IDLE,
        W_VALID
    } w_state_e;
    w_state_e w_state, w_state_next;

    always_ff @(posedge ACLK) begin
        if (!ARESETn) begin
            w_state   <= W_IDLE;
            wdata_reg <= 32'h00;
            w_pending <= 1'b0;
            slv_reg0  <= 32'h00;
            slv_reg1  <= 32'h00;
            slv_reg2  <= 32'h00;
            slv_reg3  <= 32'h00;
        end else begin
            w_state   <= w_state_next;
            wdata_reg <= wdata_reg_next;
            if (write_en) begin
                w_pending <= 1'b0;
                case (awaddr_reg[3:2])
                    2'h0: slv_reg0 <= wdata_reg;
                    2'h1: slv_reg1 <= wdata_reg;
                    2'h2: slv_reg2 <= wdata_reg;
                    2'h3: slv_reg3 <= wdata_reg;
                endcase
            end else begin
                w_pending <= w_pending_next;
            end
        end
    end

    always_comb begin
        w_state_next   = w_state;
        wdata_reg_next = wdata_reg;
        w_pending_next = w_pending;
        WREADY         = 1'b0;
        case (w_state)
            W_IDLE: begin
                WREADY = 1'b0;
                if (WVALID && !w_pending && (b_state == B_IDLE)) begin
                    w_state_next = W_VALID;
                end
            end
            W_VALID: begin
                WREADY = !w_pending && (b_state == B_IDLE);
                if (WREADY && WVALID) begin
                    wdata_reg_next = WDATA;
                    w_pending_next = 1'b1;
                    w_state_next = W_IDLE;
                end
            end
        endcase
    end
    //------------


    //---- B  ----
    assign write_en = aw_pending && w_pending && (b_state == B_IDLE);

    always_ff @(posedge ACLK) begin
        if (!ARESETn) begin
            b_state <= B_IDLE;
        end else begin
            b_state <= b_state_next;
        end
    end

    always_comb begin
        b_state_next = b_state;
        BRESP        = 2'b00;
        BVALID       = 1'b0;
        case (b_state)
            B_IDLE: begin
                BRESP  = 2'b00;
                BVALID = 1'b0;
                if (write_en) begin
                    b_state_next = B_VALID;
                end
            end
            B_VALID: begin
                BVALID = 1'b1;
                if (BVALID && BREADY) begin
                    b_state_next = B_IDLE;
                end
            end
        endcase
    end
    //------------


    //---- AR ----
    typedef enum logic {
        AR_IDLE,
        AR_VALID
    } ar_state_e;
    ar_state_e ar_state, ar_state_next;


    always_ff @(posedge ACLK) begin
        if (!ARESETn) begin
            ar_state <= AR_IDLE;
        end else begin
            ar_state <= ar_state_next;
        end
    end

    always_comb begin
        ar_state_next = ar_state;
        ARREADY       = 1'b0;
        case (ar_state)
            AR_IDLE: begin
                ARREADY = 1'b0;
                if (ARVALID && (r_state == R_IDLE)) begin
                    ar_state_next = AR_VALID;
                end
            end
            AR_VALID: begin
                ARREADY = (r_state == R_IDLE);
                if (ARREADY && ARVALID) begin
                    ar_state_next = AR_IDLE;
                end
            end
        endcase
    end
    //------------


    //---- R  ----
    assign read_en = (ar_state == AR_VALID) && ARVALID && (r_state == R_IDLE);

    always_ff @(posedge ACLK) begin
        if (!ARESETn) begin
            r_state   <= R_IDLE;
            rdata_reg <= 32'h00;
        end else begin
            r_state   <= r_state_next;
            rdata_reg <= rdata_reg_next;
        end
    end

    always_comb begin
        r_state_next   = r_state;
        rdata_reg_next = rdata_reg;
        RDATA          = rdata_reg;
        RVALID         = 1'b0;
        RRESP          = 2'b00;
        case (r_state)
            R_IDLE: begin
                if (read_en) begin
                    case (ARADDR[3:2])
                        2'h0: begin
                            rdata_reg_next = slv_reg0;
                        end
                        2'h1: begin
                            rdata_reg_next = slv_reg1;
                        end
                        2'h2: begin
                            rdata_reg_next = slv_reg2;
                        end
                        2'h3: begin
                            rdata_reg_next = slv_reg3;
                        end
                    endcase
                    r_state_next = R_VALID;
                end
            end
            R_VALID: begin
                RVALID = 1'b1;
                if (RREADY) begin
                    r_state_next = R_IDLE;
                end
            end
        endcase
    end
    //------------
endmodule
