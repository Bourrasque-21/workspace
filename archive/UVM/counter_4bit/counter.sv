module counter (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       enable,
    output logic [3:0] count
);

    always_ff @(posedge clk, posedge rst_n) begin
        if (!rst_n) begin
            count <= 0;
        end else begin
            if (enable) begin
                count <= count + 1;
            end
        end
    end
endmodule
