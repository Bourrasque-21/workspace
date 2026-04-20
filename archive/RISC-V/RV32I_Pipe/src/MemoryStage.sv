/*
[MODULE_INFO_START]
Name: MemoryStage
Role: Memory-stage wrapper for the RV32I 5-stage pipeline CPU
Summary:
  - Owns data-memory access orchestration for the MEM stage
  - Keeps trap classification and MEM/WB bundle assembly inside the stage
[MODULE_INFO_END]
*/

`timescale 1ns / 1ps

module MemoryStage (
  input  logic                  iClk,
  input  rv32i_pkg::EXMEM_t     iEXMEM,
  
  output logic                  oTrapValid,
  output rv32i_pkg::TrapCauseE  oTrapCause,
  output rv32i_pkg::MEMWB_t     oMEMWBData
);

  import rv32i_pkg::*;

  // ==== 1. Memory Access Signals ====
  
  logic [31:0] RdData;
  logic [31:0] MemAddr;
  logic        MemReadEn;
  logic        MemWriteEn;
  logic [3:0]  ByteEn;
  logic [31:0] WrData;
  logic [31:0] MemLoadData;
  logic [31:0] MemRdData;
  logic        LoadMisalign;
  logic        StoreMisalign;
  logic        MemTrapValid;
  logic        TrapActive;
  TrapCauseE MemTrapCause;

  // Verify memory accesses are only triggered by non-killed valid instructions
  assign MemReadEn          = iEXMEM.Valid && !iEXMEM.Kill && iEXMEM.MemRead;
  assign MemWriteEn         = iEXMEM.Valid && !iEXMEM.Kill && iEXMEM.MemWrite;
  assign MemAddr            = iEXMEM.AluResult;
  
  assign MemRdData          = MemLoadData;

  // ==== 2. Store Data Formatting ====

  StoreFormatter uStoreFormatter (
    .iMemWrite   (MemWriteEn),
    .iMemSize    (iEXMEM.MemSize),
    .iAddr       (MemAddr),
    .iStoreData  (iEXMEM.StoreData),

    .oByteEn     (ByteEn),
    .oWrData     (WrData),
    .oMisalign   (StoreMisalign)
  );

  // ==== 3. Data Memory Target ====

  DataRam uDataRam (
    .iClk          (iClk),
    .iWrEn         (MemWriteEn && !StoreMisalign),
    .iByteEn       (ByteEn),
    .iAddr         (MemAddr),
    .iWrData       (WrData),
    
    .oRdWord       (RdData)
  );

  // ==== 4. Load Data Formatting ====

  LoadFormatter uLoadFormatter (
    .iMemRead      (MemReadEn),
    .iMemSize      (iEXMEM.MemSize),
    .iLoadUnsigned (iEXMEM.LoadUnsigned),
    .iAddr         (MemAddr),
    .iRdData       (RdData),

    .oLoadData     (MemLoadData),
    .oMisalign     (LoadMisalign)
  );

  // ==== 5. Trap Classification ====

  always_comb begin
    MemTrapCause = TRAP_NONE;

    if (iEXMEM.TrapCause != TRAP_NONE) begin
      MemTrapCause = iEXMEM.TrapCause;
    end else if (LoadMisalign) begin
      MemTrapCause = TRAP_LOAD_MISALIGNED;
    end else if (StoreMisalign) begin
      MemTrapCause = TRAP_STORE_MISALIGNED;
    end
  end

  assign MemTrapValid = iEXMEM.Valid
                     && !iEXMEM.Kill
                     && (MemTrapCause != TRAP_NONE);
  assign TrapActive   = (MemTrapCause != TRAP_NONE);

  // ==== 6. Pipeline Payload Builder ====

  always_comb begin
    oMEMWBData                    = '0;
    oMEMWBData.Valid              = iEXMEM.Valid;
    oMEMWBData.Kill               = iEXMEM.Kill || TrapActive;
    oMEMWBData.RdValid            = iEXMEM.RdValid;
    oMEMWBData.Pc                 = iEXMEM.Pc;
    oMEMWBData.RdAddr             = iEXMEM.RdAddr;
    oMEMWBData.AluResult          = iEXMEM.AluResult;
    oMEMWBData.MemRdData          = MemRdData;
    oMEMWBData.PcPlus4            = iEXMEM.PcPlus4;
    oMEMWBData.WbSel              = iEXMEM.WbSel;
    oMEMWBData.RegWrite           = iEXMEM.RegWrite && !TrapActive;
    oMEMWBData.TrapCause          = MemTrapCause;
  end

  assign oTrapValid = MemTrapValid;
  assign oTrapCause = MemTrapCause;

endmodule
