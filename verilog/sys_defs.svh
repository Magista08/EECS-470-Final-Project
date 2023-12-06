/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  sys_defs.svh                                        //
//                                                                     //
//  Description :  This file has the macro-defines for macros used in  //
//                 the pipeline design.                                //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __SYS_DEFS_SVH__
`define __SYS_DEFS_SVH__

// all files should `include "sys_defs.svh" to at least define the timescale
`timescale 1ns/100ps

///////////////////////////////////
// ---- Starting Parameters ---- //
///////////////////////////////////

// some starting parameters that you should set
// this is *your* processor, you decide these values (try analyzing which is best!)

// superscalar width
`define N 3

// sizes
`define ROBLEN 32
`define RSLEN 16
`define SQ_SIZE 8
//`define PHYS_REG_SZ (32 + `ROB_SZ)

// Internal macros, no other file should need these
`define CACHE_LINES 32
`define CACHE_LINE_BITS $clog2(`CACHE_LINES)

//BTB
`define BTBSIZE 256
`define TAGSIZE 10
`define VALSIZE 12

// PHT
`define PHTLEN 256
`define PHTWIDTH 8

// BHT
`define BHTLEN 256
`define BHTWIDTH $clog2(`PHTWIDTH)

//RAS
`define RAS_SIZE 8


//To avoid the clock problem, we define a small delay which can not be synthesized
`define SD #1

// worry about these later
`define BRANCH_PRED_SZ xx
`define LSQ_SZ xx

// functional units (you should decide if you want more or fewer types of FUs)
`define NUM_FU_ALU 3
`define NUM_FU_MULT 3
`define NUM_FU_LOAD xx
`define NUM_FU_STORE xx
`define NUM_FU_MEM 3
`define CompBuff_SIZE (`NUM_FU_ALU + `NUM_FU_MULT +`NUM_FU_MEM + 1)

// number of mult stages (2, 4, or 8)
`define MULT_STAGES 4

///////////////////////////////
// ---- Basic Constants ---- //
///////////////////////////////

// NOTE: the global CLOCK_PERIOD is defined in the Makefile

// useful boolean single-bit definitions
`define FALSE 1'h0
`define TRUE  1'h1

// data length
`define XLEN 32

// the zero register
// In RISC-V, any read of this register returns zero and any writes are thrown away
`define ZERO_REG 5'd0

// Basic NOP instruction. Allows pipline registers to clearly be reset with
// an instruction that does nothing instead of Zero which is really an ADDI x0, x0, 0
`define NOP 32'h00000013

//////////////////////////////////
// ---- Memory Definitions ---- //
//////////////////////////////////

// Cache mode removes the byte-level interface from memory, so it always returns
// a double word. The original processor won't work with this defined. Your new
// processor will have to account for this effect on mem.
// Notably, you can no longer write data without first reading.
`define CACHE_MODE

// you are not allowed to change this definition for your final processor
// the project 3 processor has a massive boost in performance just from having no mem latency
// see if you can beat it's CPI in project 4 even with a 100ns latency!
// `define MEM_LATENCY_IN_CYCLES  0
`define MEM_LATENCY_IN_CYCLES (100.0/`CLOCK_PERIOD+0.49999)
// the 0.49999 is to force ceiling(100/period). The default behavior for
// float to integer conversion is rounding to nearest

// How many memory requests can be waiting at once
`define NUM_MEM_TAGS 15
//modify is_buffer
`define MEM_SIZE_IN_BYTES (64*1024)
`define MEM_64BIT_LINES   (`MEM_SIZE_IN_BYTES/8)
`define DCACHE_SET_NUM   16

typedef union packed {
    logic [7:0][7:0]  byte_level;
    logic [3:0][15:0] half_level;
    logic [1:0][31:0] word_level;
} EXAMPLE_CACHE_BLOCK;

typedef enum logic [1:0] {
    BYTE   = 2'h0,
    HALF   = 2'h1,
    WORD   = 2'h2,
    DOUBLE = 2'h3
} MEM_SIZE;

// Memory bus commands
typedef enum logic [1:0] {
    BUS_NONE   = 2'h0,
    BUS_LOAD   = 2'h1,
    BUS_STORE  = 2'h2
} BUS_COMMAND;

typedef enum logic [1:0] {
	FUNC_NOP    = 2'h0,    // no instruction free, DO NOT USE THIS AS DEFAULT CASE!
	FUNC_ALU    = 2'h1,    // all of the instruction  except mult and load and store
	FUNC_MUL   = 2'h2,    // mult 
	FUNC_MEM    = 2'h3     // load and store
}FUNC_UNIT;


///////////////////////////////
// ---- Exception Codes ---- //
///////////////////////////////

/**
 * Exception codes for when something goes wrong in the processor.
 * Note that we use HALTED_ON_WFI to signify the end of computation.
 * It's original meaning is to 'Wait For an Interrupt', but we generally
 * ignore interrupts in 470
 *
 * This mostly follows the RISC-V Privileged spec
 * except a few add-ons for our infrastructure
 * The majority of them won't be used, but it's good to know what they are
 */

typedef enum logic [3:0] {
    INST_ADDR_MISALIGN  = 4'h0,
    INST_ACCESS_FAULT   = 4'h1,
    ILLEGAL_INST        = 4'h2,
    BREAKPOINT          = 4'h3,
    LOAD_ADDR_MISALIGN  = 4'h4,
    LOAD_ACCESS_FAULT   = 4'h5,
    STORE_ADDR_MISALIGN = 4'h6,
    STORE_ACCESS_FAULT  = 4'h7,
    ECALL_U_MODE        = 4'h8,
    ECALL_S_MODE        = 4'h9,
    NO_ERROR            = 4'ha, // a reserved code that we use to signal no errors
    ECALL_M_MODE        = 4'hb,
    INST_PAGE_FAULT     = 4'hc,
    LOAD_PAGE_FAULT     = 4'hd,
    HALTED_ON_WFI       = 4'he, // 'Wait For Interrupt'. In 470, signifies the end of computation
    STORE_PAGE_FAULT    = 4'hf
} EXCEPTION_CODE;

///////////////////////////////////
// ---- Instruction Typedef ---- //
///////////////////////////////////

// from the RISC-V ISA spec
typedef union packed {
    logic [31:0] inst;
    struct packed {
        logic [6:0] funct7;
        logic [4:0] rs2; // source register 2
        logic [4:0] rs1; // source register 1
        logic [2:0] funct3;
        logic [4:0] rd; // destination register
        logic [6:0] opcode;
    } r; // register-to-register instructions
    struct packed {
        logic [11:0] imm; // immediate value for calculating address
        logic [4:0]  rs1; // source register 1 (used as address base)
        logic [2:0]  funct3;
        logic [4:0]  rd;  // destination register
        logic [6:0]  opcode;
    } i; // immediate or load instructions
    struct packed {
        logic [6:0] off; // offset[11:5] for calculating address
        logic [4:0] rs2; // source register 2
        logic [4:0] rs1; // source register 1 (used as address base)
        logic [2:0] funct3;
        logic [4:0] set; // offset[4:0] for calculating address
        logic [6:0] opcode;
    } s; // store instructions
    struct packed {
        logic       of;  // offset[12]
        logic [5:0] s;   // offset[10:5]
        logic [4:0] rs2; // source register 2
        logic [4:0] rs1; // source register 1
        logic [2:0] funct3;
        logic [3:0] et;  // offset[4:1]
        logic       f;   // offset[11]
        logic [6:0] opcode;
    } b; // branch instructions
    struct packed {
        logic [19:0] imm; // immediate value
        logic [4:0]  rd; // destination register
        logic [6:0]  opcode;
    } u; // upper-immediate instructions
    struct packed {
        logic       of; // offset[20]
        logic [9:0] et; // offset[10:1]
        logic       s;  // offset[11]
        logic [7:0] f;  // offset[19:12]
        logic [4:0] rd; // destination register
        logic [6:0] opcode;
    } j;  // jump instructions

// extensions for other instruction types
`ifdef ATOMIC_EXT
    struct packed {
        logic [4:0] funct5;
        logic       aq;
        logic       rl;
        logic [4:0] rs2;
        logic [4:0] rs1;
        logic [2:0] funct3;
        logic [4:0] rd;
        logic [6:0] opcode;
    } a; // atomic instructions
`endif
`ifdef SYSTEM_EXT
    struct packed {
        logic [11:0] csr;
        logic [4:0]  rs1;
        logic [2:0]  funct3;
        logic [4:0]  rd;
        logic [6:0]  opcode;
    } sys; // system call instructions
`endif

} INST; // instruction typedef, this should cover all types of instructions

////////////////////////////////////////
// ---- Datapath Control Signals ---- //
////////////////////////////////////////

// ALU opA input mux selects
typedef enum logic [1:0] {
    OPA_IS_RS1  = 2'h0,
    OPA_IS_NPC  = 2'h1,
    OPA_IS_PC   = 2'h2,
    OPA_IS_ZERO = 2'h3
} ALU_OPA_SELECT;

// ALU opB input mux selects
typedef enum logic [3:0] {
    OPB_IS_RS2    = 4'h0,
    OPB_IS_I_IMM  = 4'h1,
    OPB_IS_S_IMM  = 4'h2,
    OPB_IS_B_IMM  = 4'h3,
    OPB_IS_U_IMM  = 4'h4,
    OPB_IS_J_IMM  = 4'h5
} ALU_OPB_SELECT;

// ALU function code input
// probably want to leave these alone
typedef enum logic [4:0] {
    ALU_ADD     = 5'h00,
    ALU_SUB     = 5'h01,
    ALU_SLT     = 5'h02,
    ALU_SLTU    = 5'h03,
    ALU_AND     = 5'h04,
    ALU_OR      = 5'h05,
    ALU_XOR     = 5'h06,
    ALU_SLL     = 5'h07,
    ALU_SRL     = 5'h08,
    ALU_SRA     = 5'h09,
    ALU_MUL     = 5'h0a, // Mult FU
    ALU_MULH    = 5'h0b, // Mult FU
    ALU_MULHSU  = 5'h0c, // Mult FU
    ALU_MULHU   = 5'h0d, // Mult FU
    ALU_DIV     = 5'h0e, // unused
    ALU_DIVU    = 5'h0f, // unused
    ALU_REM     = 5'h10, // unused
    ALU_REMU    = 5'h11  // unused
} ALU_FUNC;

typedef enum logic [1:0]{
	N_STRONG  = 2'h0,    // assume branch taken strong
	N_WEAK    = 2'h1,    // assume branch taken weak
	T_WEAK     = 2'h2,
	T_STRONG   = 2'h3    // assume branch no taken
}PHT_STATE;

////////////////////////////////
// ---- Datapath Packets ---- //
////////////////////////////////

/**
 * Packets are used to move many variables between modules with
 * just one datatype, but can be cumbersome in some circumstances.
 *
 * Define new ones in project 4 at your own discretion
 */
 /**
  * ICache_IF Packet:
 * Data exchanged from the ICache to the IF stage
 */

typedef struct packed{
	logic [31:0]   inst;
	logic          valid;

}ICACHE_IF_PACKET;

typedef struct packed{
	logic [63:0] data;
	logic            valid;

}ICACHE_PACKET;

 typedef struct packed {
    logic [63:0]                  data;
    // (13 bits) since only need 16 bits to access all memory and 3 are the offset
    logic [12-`CACHE_LINE_BITS:0] tags;
    logic                         valid;
} ICACHE_ENTRY;

/**
 * IF_ID Packet:
 * Data exchanged from the IF to the ID stage
 */
typedef struct packed {
    INST              inst;
    logic [`XLEN-1:0] PC;
    logic [`XLEN-1:0] NPC; // PC + 4
    logic             valid;
} IF_ID_PACKET;

/**
 * ID_EX Packet:
 * Data exchanged from the ID to the EX stage
 */
typedef struct packed {
    // logic [$clog2(`ROBLEN)-1:0]	T; //ROBID

    INST              inst;
    logic [`XLEN-1:0] PC;
    logic [`XLEN-1:0] NPC; // PC + 4

    logic [`XLEN-1:0] rs1_value; // reg A value
    logic [`XLEN-1:0] rs2_value; // reg B value

    ALU_OPA_SELECT opa_select; // ALU opa mux select (ALU_OPA_xxx *)
    ALU_OPB_SELECT opb_select; // ALU opb mux select (ALU_OPB_xxx *)

    logic [4:0] dest_reg_idx;  // destination (writeback) register index
    ALU_FUNC    alu_func;      // ALU function select (ALU_xxx *)
    logic       rd_mem;        // Does inst read memory?
    logic       wr_mem;        // Does inst write memory?
    logic       cond_branch;   // Is inst a conditional branch?
    logic       uncond_branch; // Is inst an unconditional branch?
    logic       halt;          // Is this a halt?
    logic       illegal;       // Is this instruction illegal?
    logic       csr_op;        // Is this a CSR operation? (we use this to get return code)

    logic       valid;
    logic       rs1_instruction; // 1: RS1 is in use, 0: RS1 not in use
    logic       rs2_instruction;
    logic       dest_reg_valid; // 1: des_reg is in use, 0: des_reg not in use

   FUNC_UNIT   func_unit;
} DP_PACKET;

/**
 * EX_MEM Packet:
 * Data exchanged from the EX to the MEM stage
 */
typedef struct packed {
    logic [`XLEN-1:0] alu_result;
    logic [`XLEN-1:0] NPC;//modify is_buffer

    logic             take_branch; // Is this a taken branch?
    // Pass-through from decode stage
    logic [`XLEN-1:0] rs2_value;
    logic             rd_mem;
    logic             wr_mem;
    logic [4:0]       dest_reg_idx;
    logic             halt;
    logic             illegal;
    logic             csr_op;
    logic             rd_unsigned; // Whether proc2Dmem_data is signed or unsigned
    MEM_SIZE          mem_size;
    logic             valid;
} EX_MEM_PACKET;

/**
 * MEM_WB Packet:
 * Data exchanged from the MEM to the WB stage
 *
 * Does not include data sent from the MEM stage to memory
 */
typedef struct packed {
    logic [`XLEN-1:0] result;
    logic [`XLEN-1:0] NPC;
    logic [4:0]       dest_reg_idx; // writeback destination//modify is_buffer (ZERO_REG if no writeback)
    logic             take_branch;
    logic             halt;    // not used by wb stage
    logic             illegal; // not used by wb stage
    logic             valid;
} MEM_WB_PACKET;

/**
 * No WB output packet as it would be more cumbersome than useful
 */

/** 
 * RS Table 
 * Record the status of ROB and ready to transfer the inst into the issue
 */
typedef struct packed {
    // Characteristics for RS
    logic [$clog2(`RSLEN)-1:0]		RSID;

    INST  inst;
    logic busy; // 0: 
    
    logic [$clog2(`ROBLEN)-1:0]	T; //ROBID
    logic [$clog2(`ROBLEN)-1:0] T1;//ROBID    
    logic [$clog2(`ROBLEN)-1:0] T2;//ROBID
    logic                       valid1;
    logic                       valid2;

    logic [`XLEN-1:0]           V1;
    logic [`XLEN-1:0]			V2;

    // Characteristics for DR_PACKET
    /* This is mainly for the EX_PACKET */ 
    logic [`XLEN-1:0] PC;
    logic [`XLEN-1:0] NPC; // PC + 4

    ALU_OPA_SELECT opa_select; // ALU opa mux select (ALU_OPA_xxx *)
    ALU_OPB_SELECT opb_select; // ALU opb mux select (ALU_OPB_xxx *)

    logic [4:0] dest_reg_idx;  // destination (writeback) register index
    ALU_FUNC    alu_func;      // ALU function select (ALU_xxx *)
    logic       rd_mem;        // Does inst read memory?
    logic       wr_mem;        // Does inst write memory?
    logic       cond_branch;   // Is inst a conditional branch?
    logic       uncond_branch; // Is inst an unconditional branch?
    logic       halt;          // Is this a halt?
    logic       illegal;       // Is this instruction illegal?
    logic       csr_op;        // Is this a CSR operation? (we only used this as a cheap way to get return code)

    logic       valid;
    FUNC_UNIT   func_unit;
    logic [$clog2(`SQ_SIZE)-1:0] sq_position;
} RS_LINE;

typedef struct packed {
    RS_LINE [`RSLEN-1:0] 			line;
    logic full;
} RS_TABLE;

/** 
 * ROB Table 
 * Record the instruction that is already decoded
 */

typedef struct packed {
    // Characteristics for RS
    //logic [$clog2(`ROBLEN)-1:0]  id;
    logic             busy;//dp, rt
    logic             value_flag;//dp,cdb,rt


    logic [4:0]       reg_id;//dp
    logic [`XLEN-1:0] value;// cdb
    logic             take_branch;//cdb
    logic [`XLEN-1:0]             NPC;
    logic                              halt;
    logic                     rd_wr_mem;
} ROB_LINE;


/*
 * MapTable
 * Record the status of the reg
 */
typedef struct packed {
    logic [4:0]                 R; 
    logic [$clog2(`ROBLEN)-1:0] Tag;
    logic                       plus;
} MAP_TABLE;

/*
 * CDB
 * Record the finished instr from Complete stage
 */
typedef struct packed {
    logic [$clog2(`ROBLEN)-1:0] Tag;
    logic 	valid;
} CDB_MT_PACKET;

/*
 * Packet between ROB, RS, Maptable, CDB
 */

typedef struct packed {
    logic [`XLEN-1:0]            V1;
    logic [`XLEN-1:0]		     V2;
    logic [$clog2(`ROBLEN)-1:0]  T;
    //logic [$clog2(`ROBLEN)-1:0]  T1;//ROBID    
    //logic [$clog2(`ROBLEN)-1:0]  T2;//ROBID
    logic 					     valid1;
    logic 					     valid2;
} ROB_RS_PACKET;//

typedef struct packed {
    logic [$clog2(`ROBLEN)-1:0]  T;
    logic   [4:0]                                                           R  ; 
    logic                                   valid;
} ROB_MT_PACKET;     //  删除了T1,T2,valid1,valid2


typedef struct packed {
    logic [`XLEN-1:0]           value;//modify is_buffer
    logic [$clog2(`ROBLEN)-1:0] tag;//ROBID
    logic 				 	    valid;
} CDB_RS_PACKET;

typedef struct packed {
    logic [`XLEN-1:0]           value;//modify is_buffer
    logic [$clog2(`ROBLEN)-1:0] tag;//ROBID
    logic 				 	    valid;
    logic                              take_branch;
    logic  [`XLEN-1:0]          NPC;
    logic                               halt;               
} CDB_ROB_PACKET;

typedef struct packed {
    logic  [$clog2(`ROBLEN)-1:0] T1;//ROBID
    logic  [$clog2(`ROBLEN)-1:0] T2;

    // T_pluse indicates 2 conditions: 
    //1.source register in MT is empty(usually for the 1st overall)
    //2.ROB# with + bit
    logic                        T1_plus; 
    logic                        T2_plus;

    logic					     valid1; //valid = 1 means there is inst. in the mt
    logic					     valid2;  
} MT_RS_PACKET;//

typedef struct packed {
    logic  [$clog2(`ROBLEN)-1:0] T1;//ROBID
    logic  [$clog2(`ROBLEN)-1:0] T2;

    // T_pluse indicates 2 conditions: 
    //1.source register in MT is empty(usually for the 1st overall)
    //2.ROB# with + bit
    logic                        T1_plus; 
    logic                        T2_plus;

    logic					     valid1; //valid = 1 means there is inst. in the mt
    logic					     valid2;  
} MT_ROB_PACKET;//

typedef struct packed {
    DP_PACKET [2:0] 			packet;
} DP_RS_PACKET;
/*
typedef struct packed {
    logic [2:0] 			excuted;
} IS_RS_PACKET;
*/
typedef struct packed {
    /*
    // Prev
    RS_LINE [2:0] lines;
    */
    logic [$clog2(`ROBLEN)-1:0]	T;

    INST              inst;
    logic [`XLEN-1:0] PC;
    logic [`XLEN-1:0] NPC; // PC + 4

    logic [`XLEN-1:0] rs1_value; // reg A value
    logic [`XLEN-1:0] rs2_value; // reg B value

    ALU_OPA_SELECT opa_select; // ALU opa mux select (ALU_OPA_xxx *)
    ALU_OPB_SELECT opb_select; // ALU opb mux select (ALU_OPB_xxx *)

    logic [4:0] dest_reg_idx;  // destination (writeback) register index
    ALU_FUNC    alu_func;      // ALU function select (ALU_xxx *)
    logic       rd_mem;        // Does inst read memory?
    logic       wr_mem;        // Does inst write memory?
    logic       cond_branch;   // Is inst a conditional branch?
    logic       uncond_branch; // Is inst an unconditional branch?
    logic       halt;          // Is this a halt?
    logic       illegal;       // Is this instruction illegal?
    logic       csr_op;        // Is this a CSR operation? (we only used this as a cheap way to get return code)

    logic       valid;
    FUNC_UNIT   func_unit;
    logic [$clog2(`SQ_SIZE)-1:0] sq_position;
} RS_IS_PACKET;

typedef struct packed {
    logic [$clog2(`ROBLEN)-1:0]    T;
    logic [`XLEN-1:0]              value; // also bp_pc
    logic                          valid;
    logic                          branch_taken;
    logic [`XLEN-1:0]              NPC; // required by them~
    logic                       halt;
} EX_PACKET;

typedef struct packed{
    logic branch_en;  // Check if this branch needs to branch
    logic cond_branch_en; // Check if this is a conditional branch (Get rid of JAL and JALR)
    logic cond_branch_taken; // Check if this branch is taken
    logic [`XLEN-1:0] PC;         // Supposed Instruction PC
    logic [`XLEN-1:0] target_PC;  // Target PC
} EX_BP_PACKET;




typedef struct packed {
    logic [`NUM_FU_ALU-1:0]        ALU_empty;
    logic [`NUM_FU_MULT-1:0]       MULT_empty;
    logic                          MEM_empty;
} FU_EMPTY_PACKET;


// SQ
// typedef struct packed {
//     logic                          valid;
//     logic                          load_1_store_0;
//     logic [2:0]                    mem_size;
// 	logic [`XLEN-1:2]              word_addr;
// 	logic [1:0]                    res_addr;
// 	logic [`XLEN-1:0]              value;
// 	logic [$clog2(`ROBLEN)-1:0]    T;
// } FU_SQ_PACKET;


typedef struct packed {
    logic                          valid;
    logic                          load_1_store_0;
    logic [2:0]                    mem_size;
logic [`XLEN-1:2]              word_addr;
	logic [1:0]                    res_addr;
	logic [`XLEN-1:0]              value;
	logic [$clog2(`ROBLEN)-1:0]    T;
    logic                          retire_valid;
    logic                          pre_store_done;
    logic                          sent_to_CompBuff;
    logic                          addr_cannot_to_DCache;
    logic                          load_sent_to_DCache;

    // just pass through
    logic [`XLEN-1:0]              NPC;
    logic                          halt;
} SQ_LINE;

typedef struct packed {
	logic [`SQ_SIZE-1:0]           psel_1;
    logic [`SQ_SIZE-1:0]           psel_2;
} PSEL_TABLE;

// typedef struct packed {
//     logic                          branch_taken;
//     logic [`XLEN-1:0]              bp_pc;
// } BRANCH_PACKET;

typedef struct packed {
    logic valid;
    logic [`XLEN-1:0] address;
    logic [`XLEN-1:0] value;//ST
    logic st_or_ld;//ST=0, LD=1
    MEM_SIZE          mem_size;
    logic [`XLEN-1:0] NPC;
} LSQ_DCACHE_PACKET;

typedef struct packed {
    logic busy;//cannot send packet to dcache
    //logic completed;//1: the value load for proc is ready/the value store to mem is completed
    logic valid;//load value is valid
    logic [`XLEN-1:0] value;//LD
    logic [`XLEN-1:0] address;
    logic [`XLEN-1:0] NPC;
    logic st_or_ld;
} DCACHE_LSQ_PACKET;

typedef struct packed {
    logic [63:0] value;
    logic [24:0] tag;
    logic valid;
} DCACHE_LINE;

typedef struct packed {
    logic last_ptr;
    DCACHE_LINE [1:0] line;
} DCACHE_SET;

typedef struct packed {
    //logic valid;
    //logic ready;
    logic [2:0] bo;
    logic [3:0] idx;
    logic [24:0] tag;
    logic st_or_ld;//ST=0, LD=1
    logic [63:0] value;
    MEM_SIZE          mem_size;  
    //logic [3:0] response;
    logic ptr;
    logic [`XLEN-1:0] NPC;
    logic [`XLEN-1:0] in_value;
} MSHR_LINE;

typedef enum logic [1:0] {
	INVALID    = 2'h0,   
	WAITING    = 2'h1,    
	COMPLETED   = 2'h2,    
	READY    = 2'h3     
}MSHR_STATE;

typedef struct packed {
    logic [1:0]				empty_num;//to DP
} RS_IF_PACKET;

typedef struct packed {
    logic [1:0]				empty_num;//to DP
} ROB_IF_PACKET;

typedef struct packed{
    logic [4:0] dest_reg_idx;
    logic [$clog2(`ROBLEN)-1:0] T;
} CURRENT_MT_TABLE;



typedef struct packed {
    logic [4:0]                   dest_reg_idx; // Retired register
    logic [`XLEN-1:0]             value;// Value for retired register
    logic [$clog2(`ROBLEN)-1:0]   tag;//ROBID 
    logic                         take_branch;
    logic [`XLEN-1:0]             NPC;
    logic                         valid;
    logic                         halt;
} ROB_RT_PACKET;

typedef struct packed {
    logic [4:0] 	  			  retire_reg; // Retired register
    logic [`XLEN-1:0] 			  value; // Value for retired register
    logic                                                  valid;
} RT_DP_PACKET;

typedef struct packed {
    logic [$clog2(`ROBLEN)-1:0]  retire_tag; // Retired tag
    logic                        valid;
} RT_MT_PACKET;

typedef struct packed {
    logic [$clog2(`ROBLEN)-1:0]  retire_tag; // Retired tag
    logic                        valid;
} RT_LSQ_PACKET;
`endif // __SYS_DEFS_SVH__





