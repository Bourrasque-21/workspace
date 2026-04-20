/*
[MODULE_INFO_START]
Name: HazardDecode
Role: Decode-stage hazard metadata generator
Summary:
  - Maps the current opcode to source-register usage flags for hazard detection
  - Tracks whether the current decode result writes a non-zero destination register
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module HazardDecode (
  input  logic        [6:0] iOpcode,
  input  logic              iRegWrite,
  input  logic        [4:0] iRdAddr,

  output logic              oUseRs1,
  output logic              oUseRs2,
  output logic              oRdValid
);

  import rv32i_pkg::*;

  // Decode-local operand usage drives downstream hazard detection only.
  always_comb begin
    oUseRs1 = 1'b0;
    oUseRs2 = 1'b0;

    unique case (iOpcode)
      LP_OPCODE_RTYPE,
      LP_OPCODE_STORE,
      LP_OPCODE_BRANCH: begin
        oUseRs1 = 1'b1;
        oUseRs2 = 1'b1;
      end

      LP_OPCODE_OPIMM,
      LP_OPCODE_LOAD,
      LP_OPCODE_JALR: begin
        oUseRs1 = 1'b1;
      end

      default: begin
      end
    endcase
  end

  assign oRdValid = iRegWrite && (iRdAddr != '0);

endmodule
