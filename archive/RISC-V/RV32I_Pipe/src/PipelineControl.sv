/*
[MODULE_INFO_START]
Name: PipelineControl
Role: Central pipeline-control arbiter for the RV32I 5-stage pipeline CPU
Summary:
  - Arbitrates trap capture, redirect priority, and front-end boundary flushes for the standard 5-stage shell
  - Produces flush/hold controls, a prioritized redirect event, fetch-valid observation, pipeline-empty status, and halt-state next values
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module PipelineControl (
  input  logic                     iHaltPending,
  input  logic [31:0]              iHaltPc,
  input  rv32i_pkg::TrapCauseE   iHaltCause,
  input  logic                     iLoadUseStall,

  input  rv32i_pkg::IFID_t         iIFID,
  input  rv32i_pkg::IDEX_t         iIDEX,
  input  rv32i_pkg::EXMEM_t        iEXMEM,
  input  rv32i_pkg::MEMWB_t        iMEMWB,

  input  logic                     iIdTrapValid,
  input  rv32i_pkg::TrapCauseE   iIdTrapCause,
  input  logic                     iIdRedirectValid,
  input  logic                     iExTrapValid,
  input  rv32i_pkg::TrapCauseE   iExTrapCause,
  input  logic                     iExRedirectValid,
  input  logic                     iMemTrapValid,
  input  rv32i_pkg::TrapCauseE   iMemTrapCause,

  output logic                     oPcWe,
  output logic                     oIFIDHold,
  output logic                     oIFIDFlush,
  output logic                     oIDEXFlush,
  output logic                     oEXMEMFlush,
  output logic                     oFetchValid,
  output logic                     oPipelineEmpty,
  output logic                     oTrapRedirectValid,
  output logic [31:0]              oTrapRedirectPc,
  output logic                     oHaltPending_d,
  output logic [31:0]              oHaltPc_d,
  output rv32i_pkg::TrapCauseE   oHaltCause_d
);

  import rv32i_pkg::*;

  logic        TrapCaptureValid;
  logic [31:0] TrapCapturePc;
  TrapCauseE TrapCaptureCause;
  logic        TrapFromEx;
  logic        TrapFromMem;
  logic        PcAdvance;
  logic        FrontFlush;
  logic        IdexFlushReq;
  logic        HaltPendingNext;

  always_comb begin
    TrapCaptureValid = 1'b0;
    TrapCapturePc    = iHaltPc;
    TrapCaptureCause = iHaltCause;
    TrapFromEx       = 1'b0;
    TrapFromMem      = 1'b0;

    if (!iHaltPending) begin
      if (iMemTrapValid) begin
        TrapCaptureValid = 1'b1;
        TrapCapturePc    = iEXMEM.Pc;
        TrapCaptureCause = iMemTrapCause;
        TrapFromMem      = 1'b1;
      end else if (iExTrapValid) begin
        TrapCaptureValid = 1'b1;
        TrapCapturePc    = iIDEX.Pc;
        TrapCaptureCause = iExTrapCause;
        TrapFromEx       = 1'b1;
      end else if (iIdTrapValid) begin
        TrapCaptureValid = 1'b1;
        TrapCapturePc    = iIFID.Pc;
        TrapCaptureCause = iIdTrapCause;
      end
    end
  end

  // Shared control qualification
  assign PcAdvance      = !iHaltPending && !iLoadUseStall;
  assign FrontFlush     = iHaltPending
                       || TrapCaptureValid
                       || iIdRedirectValid
                       || iExRedirectValid;
  assign IdexFlushReq   = TrapFromMem
                       || TrapFromEx
                       || iExRedirectValid
                       || iHaltPending
                       || iLoadUseStall;
  assign HaltPendingNext = iHaltPending || TrapCaptureValid;

  // Pipeline control outputs
  assign oPcWe          = TrapCaptureValid || PcAdvance;
  assign oIFIDHold      = iLoadUseStall;
  assign oIFIDFlush     = FrontFlush;
  assign oIDEXFlush     = IdexFlushReq;
  assign oEXMEMFlush    = TrapFromMem;
  assign oFetchValid    = !(FrontFlush || iLoadUseStall);
  assign oPipelineEmpty    = !(iIFID.Valid || iIDEX.Valid || iEXMEM.Valid || iMEMWB.Valid);
  assign oTrapRedirectValid = TrapCaptureValid;
  assign oTrapRedirectPc    = TrapCapturePc;
  assign oHaltPending_d     = HaltPendingNext;
  assign oHaltPc_d          = TrapCaptureValid ? TrapCapturePc : iHaltPc;
  assign oHaltCause_d       = TrapCaptureValid ? TrapCaptureCause : iHaltCause;

endmodule
