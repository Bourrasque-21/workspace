/*
[MODULE_INFO_START]
Name: TOP
Role: Top-level wrapper for the RV32I 5-stage pipeline CPU
Summary:
  - Arranges Fetch, Decode, Execute, Memory, and WriteBack stage wrappers with explicit IF/ID, ID/EX, EX/MEM, and MEM/WB registers
  - Centralizes pipeline control in PipelineControl while preserving the precise-halt timing behavior
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module TOP (
  input  logic iClk,
  input  logic iRstn,
  
  output logic oTimingProbe
);

  import rv32i_pkg::*;

  // ==== 1. Global Interconnects & Pipeline Signals ====
  
  logic [31:0] Pc;
  logic        PcWe;
  logic        TrapRedirectValid;
  logic [31:0] TrapRedirectPc;

  // IF -> ID
  IFID_t IFID;
  IFID_t IFIDNext;
  logic   IFIDFlush;
  logic   IFIDHold;
  
  // ID -> EX 
  IDEX_t IDEX;
  IDEX_t IDEXNext;
  logic   IDEXFlush;
  
  // EX -> MEM
  EXMEM_t EXMEM;
  EXMEM_t EXMEMNext;
  logic    EXMEMFlush;
  
  // MEM -> WB
  MEMWB_t MEMWB;
  MEMWB_t MEMWBNext;

  // ==== 2. Control Flow & Hazards ====
  
  // Exception handling
  logic        HaltPending;
  logic        HaltPendingD;
  logic [31:0] HaltPc;
  logic [31:0] HaltPcD;
  TrapCauseE HaltCause;
  TrapCauseE HaltCauseD;

  // Pipeline Redirects
  logic        IdTrapValid;
  logic        LoadUseStall;
  logic        IdRedirectValid;
  logic [31:0] IdRedirectPc;
  TrapCauseE IdTrapCause;
  
  logic [31:0] ExRedirectPc;
  logic        ExRedirectValid;
  TrapCauseE ExTrapCause;
  logic        ExTrapValid;

  TrapCauseE MemTrapCause;
  logic        MemTrapValid;

  // Retire / WB signals
  logic        FetchValid;
  logic        RetireValid;
  logic [31:0] RetirePc;
  logic [4:0]  RetireRdAddr;
  logic [31:0] RetireWrData;
  logic        RetireRegWrite;
  logic        PipelineEmpty;
  logic        WbWriteEn;
  logic [31:0] WbWriteData;

  // Synthesis dummy port to retain logic
  (* DONT_TOUCH = "TRUE", KEEP = "TRUE" *) logic TimingSinkReg;

  // ==== 3. Top-Level Core Stages ====

  PipelineControl uPipelineControl (
    .iHaltPending       (HaltPending),
    .iHaltPc            (HaltPc),
    .iHaltCause         (HaltCause),
    .iLoadUseStall      (LoadUseStall),
    .iIFID              (IFID),
    .iIDEX              (IDEX),
    .iEXMEM             (EXMEM),
    .iMEMWB             (MEMWB),
    .iIdTrapValid       (IdTrapValid),
    .iIdTrapCause       (IdTrapCause),
    .iIdRedirectValid   (IdRedirectValid),
    .iExTrapValid       (ExTrapValid),
    .iExTrapCause       (ExTrapCause),
    .iExRedirectValid   (ExRedirectValid),
    .iMemTrapValid      (MemTrapValid),
    .iMemTrapCause      (MemTrapCause),

    .oPcWe              (PcWe),
    .oIFIDHold          (IFIDHold),
    .oIFIDFlush         (IFIDFlush),
    .oIDEXFlush         (IDEXFlush),
    .oEXMEMFlush        (EXMEMFlush),
    .oFetchValid        (FetchValid),
    .oPipelineEmpty     (PipelineEmpty),
    .oTrapRedirectValid (TrapRedirectValid),
    .oTrapRedirectPc    (TrapRedirectPc),
    .oHaltPending_d     (HaltPendingD),
    .oHaltPc_d          (HaltPcD),
    .oHaltCause_d       (HaltCauseD)
  );

  // Instruction Fetch Stage
  FetchStage uFetchStage (
    .iClk                 (iClk),
    .iRstn                (iRstn),
    .iPcWe                (PcWe),
    .iFetchValid          (FetchValid),
    .iTrapRedirectValid   (TrapRedirectValid),
    .iTrapRedirectPc      (TrapRedirectPc),
    .iIdRedirectValid     (IdRedirectValid),
    .iIdRedirectPc        (IdRedirectPc),
    .iExRedirectValid     (ExRedirectValid),
    .iExRedirectPc        (ExRedirectPc),

    .oPc                  (Pc),
    .oIFIDData            (IFIDNext)
  );

  // IF/ID Pipeline Register
  IfIdReg uIfIdReg (
    .iClk   (iClk),
    .iRstn  (iRstn),
    .iFlush (IFIDFlush),
    .iHold  (IFIDHold),
    .iData  (IFIDNext),
    
    .oData  (IFID)
  );

  // Instruction Decode Stage
  DecodeStage uDecodeStage (
    .iClk              (iClk),
    .iRstn             (iRstn),
    .iIFID             (IFID),
    .iIDEX             (IDEX),
    .iWbWriteEn        (WbWriteEn),
    .iWbRdAddr         (MEMWB.RdAddr),
    .iWbWriteData      (WbWriteData),
    
    .oLoadUseStall     (LoadUseStall),
    .oRedirectValid    (IdRedirectValid),
    .oRedirectPc       (IdRedirectPc),
    .oTrapValid        (IdTrapValid),
    .oTrapCause        (IdTrapCause),
    .oIDEXData         (IDEXNext)
  );

  // ID/EX Pipeline Register
  IdExReg uIdExReg (
    .iClk   (iClk),
    .iRstn  (iRstn),
    .iFlush (IDEXFlush),
    .iData  (IDEXNext),
    
    .oData  (IDEX)
  );

  // Execute Stage
  ExecuteStage uExecuteStage (
    .iHaltPending    (HaltPending),
    .iIDEX           (IDEX),
    .iEXMEM          (EXMEM),
    .iWbWriteEn      (WbWriteEn),
    .iWbRdAddr       (MEMWB.RdAddr),
    .iWbWriteData    (WbWriteData),
    
    .oRedirectValid  (ExRedirectValid),
    .oRedirectPc     (ExRedirectPc),
    .oTrapValid      (ExTrapValid),
    .oTrapCause      (ExTrapCause),
    .oEXMEMData      (EXMEMNext)
  );

  // EX/MEM Pipeline Register
  ExMemReg uExMemReg (
    .iClk   (iClk),
    .iRstn  (iRstn),
    .iFlush (EXMEMFlush),
    .iData  (EXMEMNext),
    
    .oData  (EXMEM)
  );

  // Memory Access Stage
  MemoryStage uMemoryStage (
    .iClk            (iClk),
    .iEXMEM          (EXMEM),
    
    .oTrapValid      (MemTrapValid),
    .oTrapCause      (MemTrapCause),
    .oMEMWBData      (MEMWBNext)
  );

  // MEM/WB Pipeline Register
  MemWbReg uMemWbReg (
    .iClk   (iClk),
    .iRstn  (iRstn),
    .iData  (MEMWBNext),
    
    .oData  (MEMWB)
  );

  // Register Writeback Stage
  WriteBackStage uWriteBackStage (
    .iMEMWB          (MEMWB),
    
    .oWbWriteData    (WbWriteData),
    .oWbWriteEn      (WbWriteEn),
    .oRetireValid    (RetireValid),
    .oRetirePc       (RetirePc),
    .oRetireRdAddr   (RetireRdAddr),
    .oRetireWrData   (RetireWrData),
    .oRetireRegWrite (RetireRegWrite)
  );

  // ==== 4. Retained Architectural Pipeline State ====

  always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
      HaltPending   <= 1'b0;
      HaltPc        <= '0;
      HaltCause     <= TRAP_NONE;
      TimingSinkReg <= 1'b0;
    end else begin
      HaltPending   <= HaltPendingD;
      HaltPc        <= HaltPcD;
      HaltCause     <= HaltCauseD;
      
      // Preserve the pipeline outcomes for timing measurements in synthesis
      TimingSinkReg <= ^{RetireValid, RetireRegWrite, RetireRdAddr, RetireWrData, RetirePc};
    end
  end

  assign oTimingProbe = TimingSinkReg;

endmodule
