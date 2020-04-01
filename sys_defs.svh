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
		logic       of; //offset[12]s
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
`define SQ_LEN 		  3
`define LB_LEN 		  3
`define LB_CAPACITY   8
`define SQ_CAPACITY   8
`define RS_ALU_SIZE		  8		// number of entries: RS ALU module
`define RS_MUL_SIZE       4     // number of entries: RS MUL module
`define RS_SQ_SIZE       4     // number of entries: RS MEM module
`define RS_LB_SIZE       4
`define RS_BR_SIZE        4     	// number of entries: RS BRANCH module
`define RS_ALU_LEN		  3		// length in bits == log(RS_LEN)
`define RS_MUL_LEN		  2
`define RS_SQ_LEN		  2
`define RS_LB_LEN		  2
`define RS_BR_LEN		  2
`define RAT_SIZE      32	// number of entries == number of arch reg



`define XLENFU		  4		// number of function units

typedef enum logic [2:0] {
	ALU        = 3'h0,
	MUL        = 3'h1,
	BRANCH     = 3'h2,
	LOAD       = 3'h3,
	STORE      = 3'h4
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
	MEM_SIZE	mem_size; 		  //how many bytes would the instruction acees the memory?
	logic		load_signed;      //is the load signed or not?

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
	logic                cond_branch;
	logic                uncond_branch;
	logic [`XLEN-1:0]    target_PC;     // branch target PC
	logic                local_pred_direction;
	logic                global_pred_direction;
	logic                branch_direction;
	logic                branch_mis_pred;
	logic				 halt;
	logic				 illegal;
	logic                wr_mem;
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
	
	logic 					base_ready;
	logic 	[`XLEN-1:0] 	base_value;  
	logic 	[11:0]			offset;

	logic 					src_ready;
	logic 	[`XLEN-1:0] 	src_value; 

	logic   [`SQ_LEN-1:0]	sq_idx; 
	logic 	[`ROB_LEN-1:0] 	rob_idx;

	MEM_SIZE                mem_size;
} RS_SQ_PACKET;

typedef struct packed {
	logic [`XLEN-1:0]       NPC;                // NPC
	logic [`XLEN-1:0]       PC;                 // PC
	
	logic 					base_ready;
	logic 	[`XLEN-1:0] 	base_value;   
	logic 	 [11:0]			offset;

	logic 	[`LB_LEN]		lb_idx;
	logic 	[`PRF_LEN-1:0] 	dest_preg_idx;  
	logic 	[`ROB_LEN-1:0] 	rob_idx;
	
	MEM_SIZE                mem_size;
	logic                   load_signed;
} RS_LB_PACKET;


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
	logic	[`XLEN-1:0]		offset;
	logic                   is_jalr;
	logic 	[`PRF_LEN-1:0] 	dest_preg_idx;
	logic	[`ROB_LEN-1:0]	rob_idx;
	logic   [2:0]           branch_func;
	logic                   cond_branch;
	logic                   uncond_branch;
	logic                   br_pred_direction;
	logic   [`XLEN-1:0]     br_pred_target_PC;
	logic                   local_pred_direction;   
	logic                   global_pred_direction;

} RS_BRANCH_PACKET;

//////////////////////////////////////////////
//
// CDB FU Queue:
// FU result stored in CDB waiting for broadcast.
//
//////////////////////////////////////////////

`define ALU_QUEUE_SIZE 128
`define MUL_QUEUE_SIZE 128
`define SQ_QUEUE_SIZE 128
`define DCACHE_QUEUE_SIZE 128
`define BR_QUEUE_SIZE  128
`define ALU_QUEUE_LEN 7
`define MUL_QUEUE_LEN 7
`define SQ_QUEUE_LEN 7
`define BR_QUEUE_LEN  7
`define DCACHE_QUEUE_LEN  7


typedef struct packed {
	logic  [`XLEN-1:0]    alu_value;
	logic  [`PRF_LEN-1:0] alu_prf_idx;
	logic  [`ROB_LEN-1:0] alu_rob_idx;
	logic  [`XLEN-1:0]    alu_PC;

} CDB_ALU_PACKET;

typedef struct packed {
	logic  [`XLEN-1:0]    mul_value;
	logic  [`PRF_LEN-1:0] mul_prf_idx;
	logic  [`ROB_LEN-1:0] mul_rob_idx;
    logic  [`XLEN-1:0]    mul_PC;

} CDB_MUL_PACKET;

typedef struct packed {
	logic  [`XLEN-1:0]    dcache_value; 
	logic  [`PRF_LEN-1:0] dcache_prf_idx;
	logic  [`ROB_LEN-1:0] dcache_rob_idx;
	logic  [`XLEN-1:0]    dcache_PC;

} CDB_DCACHE_PACKET;

typedef struct packed {
	logic  [`XLEN-1:0]    sq_value; 
	logic  [`PRF_LEN-1:0] sq_prf_idx;
	logic  [`ROB_LEN-1:0] sq_rob_idx;
	logic  [`XLEN-1:0]    sq_PC;

} CDB_SQ_PACKET;

typedef struct packed { 
	logic  [`PRF_LEN-1:0] br_prf_idx;
	logic  [`XLEN-1:0]    br_value;
	logic  [`ROB_LEN-1:0] br_rob_idx;
    logic  [`XLEN-1:0]    br_PC;
	logic				  br_direction;
	logic  [`XLEN-1:0]	  br_target_PC;
	logic				  br_mis_pred;
	logic				  br_local_pred_direction;
	logic				  br_global_pred_direction;
} CDB_BR_PACKET;

typedef struct packed {          
	logic [`XLEN-1:0]       PC;       
    logic [`XLEN-1:0]       addr;
    logic [4:0]             rd_preg;
    logic                   rob_idx;
    logic [`SQ_LEN-1:0]     age;
    logic                   rsvd;   //  Load address is resolved
	MEM_SIZE                mem_size;
	logic                   load_signed;
} LB_ENTRY;

typedef struct packed {
    LB_ENTRY    [`LB_CAPACITY-1:0]   entries;       
    logic       [`LB_CAPACITY-1:0]   free_list;     // Unoccupied entries
    logic       [`LB_CAPACITY-1:0]   issue_list;   
} LOAD_BUFFER;

 


typedef struct packed {            
	logic [`XLEN-1:0]       PC;                
    logic [`XLEN-1:0]       addr;
    logic [`XLEN-1:0]                data;
    logic                   rob_idx;
    logic                   rsvd;
	MEM_SIZE                mem_size;
} SQ_ENTRY;

typedef struct packed {
    SQ_ENTRY    [`SQ_CAPACITY-1:0]   entries;
    logic       [`SQ_LEN-1:0]        head;
    logic       [`SQ_LEN-1:0]        tail;
} STORE_QUEUE;

typedef struct packed {            
	logic [`XLEN-1:0]       PC;       
    logic [`XLEN-1:0]       forward_data;
    logic [4:0]             rd_preg;
    logic                   rob_idx;    
} FORWARD_PACKET;


////////////////////////////////////////////////
//
// Dcache attribute definitions
//
////////////////////////////////////////////////

`define DCACHE_CAPACITY        32
`define SET_SIZE               8
`define SET_LEN                3
`define WAY_SIZE               4 
`define WAY_LEN                2

`define LOAD_BUFFER_SIZE       16
`define LOAD_BUFFER_LEN        4

typedef union packed {
    logic [63:0] double;
    logic [1:0][31:0] words;
    logic [3:0][15:0] halves;
    logic [7:0][7:0] bytes;
} CACHE_BLOCK;

typedef struct packed{
    logic [7:0]     tag;
    logic           valid;
    CACHE_BLOCK    data;  
} ICACHE_BLOCK;

typedef struct packed {
    logic [7:0] tag;
    logic [4:0] block_num;
    logic [2:0] block_offset;
} DMAP_ADDR; //address breakdown for a direct-mapped cache

typedef struct packed {
    logic [9:0] tag;
    logic [2:0] set_index;
    logic [2:0] block_offset;
} SASS_ADDR; //address breakdown for a set associative cache

typedef union packed {
    DMAP_ADDR d; //for direct mapped
    SASS_ADDR s; //for set associative
} ADDR; //now we can pass around a common data type

typedef struct packed {
    logic [9:0]     tag;
    logic           valid;
    CACHE_BLOCK     data;   // 8 Byte (64 bits) per block plus metadata
} DCACHE_BLOCK;

typedef struct packed {
    logic [63:0]    data1;
    logic [63:0]    data2;  
} VICTIM;

typedef struct packed {
    logic valid;
    logic [`XLEN-1:0] PC;
    logic [`PRF_LEN-1:0]  prf_idx;
    logic [`ROB_LEN-1:0]  rob_idx;  
    logic [`XLEN-1:0] address;
    MEM_SIZE mem_size;
    logic load_signed;
    logic [3:0] mem_tag;
    logic done;
    // logic [2*`XLEN-1:0] data; 
	CACHE_BLOCK data;
    logic [`SET_LEN-1:0] set_idx;
    logic [`WAY_LEN-1:0] way_idx;
} LOAD_BUFFER_ENTRY;

`endif // __SYS_DEFS_VH__
