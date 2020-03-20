/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  sys_defs.vh                                         //
//                                                                     //
//  Description :  This file has the macro-defines for macros used in  //
//                 the pipeline design.                                //
//                                                                     //
/////////////////////////////////////////////////////////////////////////


`ifndef __SYS_DEFS_VH__
`define __SYS_DEFS_VH__
//////////////////////////////////////////////
//
// Memory/testbench attribute definitions
//
//////////////////////////////////////////////

`define NUM_MEM_TAGS           15
`define MEM_LATENCY_IN_CYCLES  10

`define MEM_SIZE_IN_BYTES      (64*1024)
`define MEM_64BIT_LINES        (`MEM_SIZE_IN_BYTES/8)

//you can change the clock period to whatever, 10 is just fine
`define VERILOG_CLOCK_PERIOD   10.0

typedef union packed {
    logic [7:0][7:0] byte_level;
    logic [3:0][15:0] half_level;
    logic [1:0][31:0] word_level;
} EXAMPLE_CACHE_BLOCK;

//////////////////////////////////////////////
// Exception codes
// This mostly follows the RISC-V Privileged spec
// except a few add-ons for our infrastructure
// The majority of them won't be used, but it's
// good to know whatr they are
//////////////////////////////////////////////

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
	NO_ERROR            = 4'ha, //a reserved code that we modified for our purpose
	ECALL_M_MODE        = 4'hb,
	INST_PAGE_FAULT     = 4'hc,
	LOAD_PAGE_FAULT     = 4'hd,
	HALTED_ON_WFI       = 4'he, //another reserved code that we used
	STORE_PAGE_FAULT    = 4'hf
} EXCEPTION_CODE;


//////////////////////////////////////////////
//
// Datapath control signals
//
//////////////////////////////////////////////

//
// ALU opA input mux selects
//
typedef enum logic [1:0] {
	OPA_IS_RS1  = 2'h0,
	OPA_IS_NPC  = 2'h1,
	OPA_IS_PC   = 2'h2,
	OPA_IS_ZERO = 2'h3
} ALU_OPA_SELECT;

//
// ALU opB input mux selects
//
typedef enum logic [3:0] {
	OPB_IS_RS2    = 4'h0,
	OPB_IS_I_IMM  = 4'h1,
	OPB_IS_S_IMM  = 4'h2,
	OPB_IS_B_IMM  = 4'h3,
	OPB_IS_U_IMM  = 4'h4,
	OPB_IS_J_IMM  = 4'h5
} ALU_OPB_SELECT;

//
// Destination register select
//
typedef enum logic [1:0] {
	DEST_RD = 2'h0,
	DEST_NONE  = 2'h1
} DEST_REG_SEL;

//
// ALU function code input
// probably want to leave these alone
//
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
	ALU_MUL     = 5'h0a,
	ALU_MULH    = 5'h0b,
	ALU_MULHSU  = 5'h0c,
	ALU_MULHU   = 5'h0d,
	ALU_DIV     = 5'h0e,
	ALU_DIVU    = 5'h0f,
	ALU_REM     = 5'h10,
	ALU_REMU    = 5'h11
} ALU_FUNC;

//////////////////////////////////////////////
//
// Assorted things it is not wise to change
//
//////////////////////////////////////////////

//
// actually, you might have to change this if you change VERILOG_CLOCK_PERIOD
// JK you don't ^^^
//
`define SD #1


// the RISCV register file zero register, any read of this register always
// returns a zero value, and any write to this register is thrown away
//
`define ZERO_REG 5'd0

//
// Memory bus commands control signals
//
typedef enum logic [1:0] {
	BUS_NONE     = 2'h0,
	BUS_LOAD     = 2'h1,
	BUS_STORE    = 2'h2
} BUS_COMMAND;

`ifndef CACHE_MODE
typedef enum logic [1:0] {
	BYTE = 2'h0,
	HALF = 2'h1,
	WORD = 2'h2,
	DOUBLE = 2'h3
} MEM_SIZE;
`endif
//
// useful boolean single-bit definitions
//
`define FALSE  1'h0
`define TRUE  1'h1

// RISCV ISA SPEC
`define XLEN 32
typedef union packed {
	logic [31:0] inst;
	struct packed {
		logic [6:0] funct7;
		logic [4:0] rs2;
		logic [4:0] rs1;
		logic [2:0] funct3;
		logic [4:0] rd;
		logic [6:0] opcode;
	} r; //register to register instructions
	struct packed {
		logic [11:0] imm;
		logic [4:0]  rs1; //base
		logic [2:0]  funct3;
		logic [4:0]  rd;  //dest
		logic [6:0]  opcode;
	} i; //immediate or load instructions
	struct packed {
		logic [6:0] off; //offset[11:5] for calculating address
		logic [4:0] rs2; //source
		logic [4:0] rs1; //base
		logic [2:0] funct3;
		logic [4:0] set; //offset[4:0] for calculating address
		logic [6:0] opcode;
	} s; //store instructions
	struct packed {
		logic       of; //offset[12]
		logic [5:0] s;   //offset[10:5]
		logic [4:0] rs2;//source 2
		logic [4:0] rs1;//source 1
		logic [2:0] funct3;
		logic [3:0] et; //offset[4:1]
		logic       f;  //offset[11]
		logic [6:0] opcode;
	} b; //branch instructions
	struct packed {
		logic [19:0] imm;
		logic [4:0]  rd;
		logic [6:0]  opcode;
	} u; //upper immediate instructions
	struct packed {
		logic       of; //offset[20]
		logic [9:0] et; //offset[10:1]
		logic       s;  //offset[11]
		logic [7:0] f;	//offset[19:12]
		logic [4:0] rd; //dest
		logic [6:0] opcode;
	} j;  //jump instructions
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
	} a; //atomic instructions
`endif
`ifdef SYSTEM_EXT
	struct packed {
		logic [11:0] csr;
		logic [4:0]  rs1;
		logic [2:0]  funct3;
		logic [4:0]  rd;
		logic [6:0]  opcode;
	} sys; //system call instructions
`endif

} INST; //instruction typedef, this should cover all types of instructions

//
// Basic NOP instruction.  Allows pipline registers to clearly be reset with
// an instruction that does nothing instead of Zero which is really an ADDI x0, x0, 0
//
`define NOP 32'h00000013

//////////////////////////////////////////////
//
// IF Packets:
// Data that is exchanged between the IF and the ID stages  
//
//////////////////////////////////////////////

typedef struct packed {
	logic valid; // If low, the data in this struct is garbage
    INST  inst;  // fetched instruction out
	logic [`XLEN-1:0] NPC; // PC + 4
	logic [`XLEN-1:0] PC;  // PC 
} IF_ID_PACKET;

//////////////////////////////////////////////
//
// ID Packets:
// Data that is exchanged from ID to EX stage
//
//////////////////////////////////////////////

typedef struct packed {
	logic [`XLEN-1:0] NPC;   // PC + 4
	logic [`XLEN-1:0] PC;    // PC

	logic [`XLEN-1:0] rs1_value;    // reg A value                                  
	logic [`XLEN-1:0] rs2_value;    // reg B value                                                                                                 
	ALU_OPA_SELECT opa_select; // ALU opa mux select (ALU_OPA_xxx *)
	ALU_OPB_SELECT opb_select; // ALU opb mux select (ALU_OPB_xxx *)
	INST inst;                 // instruction
	
	logic [4:0] dest_reg_idx;  // destination (writeback) register index      
	ALU_FUNC    alu_func;      // ALU function select (ALU_xxx *)
	logic       rd_mem;        // does inst read memory?
	logic       wr_mem;        // does inst write memory?
	logic       cond_branch;   // is inst a conditional branch?
	logic       uncond_branch; // is inst an unconditional branch?
	logic       halt;          // is this a halt?
	logic       illegal;       // is this instruction illegal?
	logic       csr_op;        // is this a CSR operation? (we only used this as a cheap way to get return code)
	logic       valid;         // is inst a valid instruction to be counted for CPI calculations?
} ID_EX_PACKET;
 

//////////////////////////////////////////////
//
// Some macros of size and length.
//
//////////////////////////////////////////////

`define PRF_SIZE      16	// number of entries
`define PRF_LEN		  4		// length in bits == log(PRF_SIZE)
`define ROB_SIZE      8		// number of entries
`define ROB_LEN       3		// length in bits == log(ROB_SIZE)
`define RS_ALU_SIZE		  8		// number of entries: RS ALU module
`define RS_MUL_SIZE       4     // number of entries: RS MUL module
`define RS_MEM_SIZE       4     // number of entries: RS MEM module
`define RS_BR_SIZE        4     	// number of entries: RS BRANCH module
`define RS_ALU_LEN		  3		// length in bits == log(RS_LEN)
`define RS_MUL_LEN		  2
`define RS_MEM_LEN		  2
`define RS_BR_LEN		  2
`define RAT_SIZE      32	// number of entries == number of arch reg



`define XLENFU		  4		// number of function units

// Python: "".join([hex(i)[2:].zfill(2) for i in range(256)])
`define INIT_FREE_PREG_QUEUE	2048'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9fa0a1a2a3a4a5a6a7a8a9aaabacadaeafb0b1b2b3b4b5b6b7b8b9babbbcbdbebfc0c1c2c3c4c5c6c7c8c9cacbcccdcecfd0d1d2d3d4d5d6d7d8d9dadbdcdddedfe0e1e2e3e4e5e6e7e8e9eaebecedeeeff0f1f2f3f4f5f6f7f8f9fafbfcfdfeff

typedef enum logic [1:0] {
	ALU        = 2'h0,
	MUL        = 2'h1,
	MEM        = 2'h2,
	BRANCH     = 2'h3
} FU_TYPE;

//////////////////////////////////////////////
//
// ID Packets:
// Data from ID stage to top_level
//
//////////////////////////////////////////////

typedef struct packed {
	logic [`XLEN-1:0] NPC;  
	logic [`XLEN-1:0] PC;    	// PC

	FU_TYPE     fu_type;        // select function unit                      

	logic [4:0]  opa_areg_idx;
	logic [4:0]  opb_areg_idx;
	ALU_OPA_SELECT opa_select;    // ALU opa mux select (ALU_OPA_xxx *)
	ALU_OPB_SELECT opb_select;    // ALU opb mux select (ALU_OPB_xxx *)
	INST inst;                    // instruction
	
	logic [4:0] dest_areg_idx;    // destination (writeback) arch register index      
	ALU_FUNC    alu_func;         // ALU function select (ALU_xxx *)
	logic       rd_mem;           // does inst read memory?
	logic       wr_mem;           // does inst write memory?
	logic       cond_branch;      // is inst a conditional branch?
	logic       uncond_branch;    // is inst an unconditional branch?

	logic       halt;             // is this a halt?
	logic       illegal;          // is this instruction illegal?
	logic       csr_op;           // is this a CSR operation? (we only used this as a cheap way to get return code)
	logic       valid;            // is inst a valid instruction to be counted for CPI calculations?
	logic       branch_prediction;// is the branch predict taken or not taken  
	logic		local_taken;
	logic		global_taken;

} ID_PACKET;

typedef struct packed {
	logic [`XLEN-1:0] NPC;                // NPC
	logic [`XLEN-1:0] PC;                 // PC
	logic             opa_ready;
	logic             opb_ready;
	logic [`XLEN-1:0] opa_value;          // reg A value                                  
	logic [`XLEN-1:0] opb_value;          // reg B value 

	logic [`ROB_LEN-1:0] rob_idx;          // the rob index of the instr that is sent to FU
	logic [`PRF_LEN-1:0] dest_preg_idx;    // the destination preg index
	                     
	                                                                                
	ALU_OPA_SELECT opa_select;             // ALU opa mux select (ALU_OPA_xxx *)
	ALU_OPB_SELECT opb_select;             // ALU opb mux select (ALU_OPB_xxx *)
	INST inst;                             // instruction
	  
	ALU_FUNC    alu_func;                  // ALU function select (ALU_xxx *)
	logic       rd_mem;                    // does inst read memory?
	logic       wr_mem;                    // does inst write memory?
	logic       cond_branch;               // is inst a conditional branch?
	logic       uncond_branch;             // is inst an unconditional branch?
	logic       halt;             	       // is this a halt?
	logic       illegal;                   // is this instruction illegal?
	logic       csr_op;           		   // is this a CSR operation? (we only used this as a cheap way to get return code)
	logic       valid;                     // is inst a valid instruction to be counted for CPI calculations?
	logic       branch_prediction;         // is the branch predict taken or not taken
} RS_FU_PACKET;

//////////////////////////////////////////////
//
// ROB Packets:
// Data stored in ROB.
//
//////////////////////////////////////////////

typedef struct packed {
	logic [`XLEN-1:0]    PC;			// alu_result
	logic                executed;		// is this ROB executed ??
	logic [`PRF_LEN-1:0] dest_preg_idx;	// dest physcial reg index
	logic [4:0]          dest_areg_idx;	// dest arch reg index
	logic                rob_mis_pred;  // whether this is a mispredicted branch
	logic                cond_branch;
	logic                uncond_branch;
	logic [`XLEN-1:0]    target_PC;     // branch target PC
	logic                local_pred_direction;
	logic                global_pred_direction;
	logic                branch_direction;
	logic                branch_mis_pred;
	logic				 halt;
	logic				 illegal;
} ROB_PACKET;

//////////////////////////////////////////////
//
// RS ALU Packets:
// Data stored in RS for ALU instr.
//
//////////////////////////////////////////////

typedef struct packed {
	logic [`XLEN-1:0] 	    NPC;                // NPC
	logic [`XLEN-1:0] 	    PC;                 // PC
	
	logic             	    opa_ready;
	logic             	    opb_ready;
	
	logic [`XLEN-1:0] 	    opa_value;          // reg A value                                  
	logic [`XLEN-1:0] 	    opb_value;          // reg B value

	logic [`PRF_LEN-1:0]    dest_preg_idx; 
	logic [`ROB_LEN-1:0]    rob_idx;

	ALU_FUNC                alu_func;           // ALU function select (ALU_xxx *)
	
} RS_ALU_PACKET;

//////////////////////////////////////////////
//
// RS Multiplier Packets:
// Data stored in RS for multiplier instr.
//
//////////////////////////////////////////////

typedef struct packed {
	logic [`XLEN-1:0]       NPC;                // NPC
	logic [`XLEN-1:0]       PC;                 // PC
	
	logic                   opa_ready;
	logic                   opb_ready;
	
	logic [`XLEN-1:0]       opa_value;          // reg A value                                  
	logic [`XLEN-1:0]       opb_value;          // reg B value

	logic [`PRF_LEN-1:0]    dest_preg_idx;
	logic [`ROB_LEN-1:0]    rob_idx;
	
	ALU_FUNC                mul_func;
	
} RS_MUL_PACKET;


//////////////////////////////////////////////
//
// RS Memory Packets:
// Data stored in RS for memory instr.
//
//////////////////////////////////////////////

typedef struct packed {
	logic [`XLEN-1:0]       NPC;                // NPC
	logic [`XLEN-1:0]       PC;                 // PC
	
	logic 					opa_ready;
	logic 	[`XLEN-1:0] 	opa_value;   
	logic 					opb_ready;
	logic 	[`XLEN-1:0] 	opb_value; 
	 
	logic 					offset;
	logic 	[`PRF_LEN-1:0] 	dest_preg_idx;  
	logic 	[`ROB_LEN-1:0] 	rob_idx;
} RS_MEM_PACKET;


//////////////////////////////////////////////
//
// RS Branch Packets:
// Data stored in RS for branch instr.
//
//////////////////////////////////////////////

typedef struct packed {
	logic	[`XLEN-1:0]		NPC;
	logic	[`XLEN-1:0]		PC;
	logic					opa_ready;		// only need for cond
	logic	[`XLEN-1:0]		opa_value;
	logic					opb_ready;		// only need for cond
	logic	[`XLEN-1:0]		opb_value;
	logic	[11:0]			offset;
	logic	[`PRF_LEN-1:0]	dest_preg_idx;
	logic	[`ROB_LEN-1:0]	rob_idx;
	logic   [2:0]           branch_func;
	logic                   cond_branch;
	logic                   uncond_branch;
	logic                   br_pred_direction;
	logic                   br_pred_target_PC;
	logic                   local_pred_direction;   
	logic                   global_pred_direction;

} RS_BRANCH_PACKET;

`endif // __SYS_DEFS_VH__
