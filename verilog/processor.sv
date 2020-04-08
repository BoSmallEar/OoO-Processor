/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  processor.v                                          //
//                                                                     //
//  Description :  Top-level module of the OoP;        //
//                 This instantiates and connects all parts of the  //
//                 OoP togeather.                      //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////
`ifndef DEBUG
`define DEBUG
`endif
`ifndef __PROCESSOR_V__
`define __PROCESSOR_V__
`timescale 1ns/100ps

module processor (

	input         clock,                     // System clock
	input         reset,                     // System reset
	input [3:0]   mem2cache_response,         // Tag from memory about current request
	input [63:0]  mem2cache_data,             // Data coming back from memory
	input [3:0]   mem2cache_tag,              // Tag from memory about current reply
	
	output logic [1:0]  cache2mem_command,    // command sent to memory
	output logic [`XLEN-1:0] cache2mem_addr,  // Address sent to memory
	output logic [63:0] cache2mem_data,       // Data sent to memory
	output MEM_SIZE cache2mem_size,           // data size sent to memory

    output EXCEPTION_CODE processor_error_status
`ifdef DEBUG
    // from if_id_stage
	, output logic					btb_taken
	, output logic	[`XLEN-1:0]		btb_target_PC
	, output logic					tournament_taken
	, output logic					local_taken
	, output logic					global_taken

    , output logic                                 result_mis_pred
    , output logic [`PRF_SIZE-1:0] [`XLEN-1:0]     prf_values
    , output logic [`PRF_SIZE-1:0]                 prf_free
    , output logic [`PRF_SIZE-1:0]                 prf_valid
    , output logic [`PRF_SIZE-1:0] [`PRF_LEN-1:0]  free_preg_queue
    , output logic [`PRF_LEN-1:0]                  free_preg_queue_head
    , output logic [`PRF_LEN-1:0]                  free_preg_queue_tail
    , output ROB_PACKET [`ROB_SIZE-1:0]            rob_packets
    , output logic [`ROB_LEN-1:0]                  rob_head
    , output logic [`ROB_LEN-1:0]                  rob_tail
    , output logic [31:0] [`PRF_LEN-1:0]           rat_packets 
    , output logic [31:0] [`PRF_LEN-1:0]           rrat_packets 

    , output logic [`PRF_LEN-1:0]                  opa_preg_idx
    , output logic [`PRF_LEN-1:0]                  opb_preg_idx 

    , output logic                                 fu_opa_ready
    , output logic                                 fu_opb_ready
    , output logic [`XLEN-1:0]                     fu_opa_value
    , output logic [`XLEN-1:0]                     fu_opb_value
    , output logic [`XLEN-1:0]                     fu_offset

    ,output RS_ALU_PACKET [`RS_ALU_SIZE-1:0] rs_alu_packets
    ,output logic [`RS_ALU_LEN:0] rs_alu_counter
    ,output logic [`RS_ALU_SIZE-1:0] rs_alu_ex    // goes to priority selector (data ready && FU free) 
    ,output logic [`RS_ALU_SIZE-1:0] rs_alu_free
    ,output logic [`RS_ALU_LEN-1:0] rs_alu_free_idx // the rs idx that is selected for the dispatched instr
    ,output logic [`RS_ALU_LEN-1:0] rs_alu_ex_idx 

    , output RS_BRANCH_PACKET [`RS_BR_SIZE-1:0] rs_branch_packets
    , output logic [`RS_BR_LEN:0] rs_branch_counter
    , output logic [`RS_BR_SIZE-1:0] rs_branch_ex     // goes to priority selector (data ready && FU free) 
    , output logic [`RS_BR_SIZE-1:0] rs_branch_free
    , output logic [`RS_BR_LEN-1:0] rs_branch_free_idx // the rs idx that is selected for the dispatched instr
    , output logic [`RS_BR_LEN-1:0] rs_branch_ex_idx

    , output RS_MUL_PACKET [`RS_MUL_SIZE-1:0] rs_mul_packets
    , output logic [`RS_MUL_LEN:0] rs_mul_counter
    , output logic [`RS_MUL_SIZE-1:0] rs_mul_ex     // goes to priority selector (data ready && FU free)
    , output logic [`RS_MUL_SIZE-1:0] rs_mul_free
    , output logic [`RS_MUL_LEN-1:0] rs_mul_free_idx // the rs idx that is selected for the dispatched instr
    , output logic [`RS_MUL_LEN-1:0] rs_mul_ex_idx

    , output RS_LB_PACKET [`RS_LB_SIZE-1:0]     rs_lb_packets
    , output logic        [`RS_LB_LEN:0]        rs_lb_counter
    , output logic        [`RS_LB_SIZE-1:0]     rs_lb_ex
    , output logic        [`RS_LB_SIZE-1:0]     rs_lb_free
    , output logic        [`RS_LB_LEN-1:0]      rs_lb_free_idx
    , output logic        [`RS_LB_LEN-1:0]      rs_lb_ex_idx

    , output RS_SQ_PACKET [`RS_SQ_SIZE-1:0]     rs_sq_packets
    , output logic        [`RS_SQ_LEN:0]        rs_sq_counter
    , output logic        [`RS_SQ_SIZE-1:0]     rs_sq_ex
    , output logic        [`RS_SQ_SIZE-1:0]     rs_sq_free
    , output logic        [`RS_SQ_LEN-1:0]      rs_sq_free_idx
    , output logic        [`RS_SQ_LEN-1:0]      rs_sq_ex_idx

    // Outputs of cdb
    , output logic [4:0]           module_select
    , output logic                 cdb_broadcast_valid
    , output logic [`XLEN-1:0]     cdb_result
    , output logic [`PRF_LEN-1:0]  cdb_dest_preg_idx
    , output logic [`ROB_LEN-1:0]  cdb_rob_idx
    , output logic [`XLEN-1:0]     cdb_broadcast_inst_PC
    , output logic                 cdb_br_direction
    , output logic [`XLEN-1:0]     cdb_br_target_PC
    , output logic                 cdb_mis_pred
    , output logic                 cdb_local_pred_direction
    , output logic                 cdb_global_pred_direction

    // id packet
    , output ID_PACKET        id_packet_out

    // Outputs of prf
    , output logic [`PRF_LEN-1:0]    prf_free_preg_idx
    , output logic [`PRF_LEN-1:0]    dest_preg_idx
    , output logic                   opa_ready
    , output logic [`XLEN-1:0]       opa_value
    , output logic                   opb_ready
    , output logic [`XLEN-1:0]       opb_value

    // Outputs of load store queue
    , output STORE_QUEUE            SQ
    , output LOAD_BUFFER            LB 
    , output logic [`SQ_LEN-1:0]    sq_head 
    , output logic [`SQ_LEN-1:0]    sq_counter
    , output logic                  sq_empty  
    , output logic [`LB_LEN-1:0]    lq_free_idx 
    , output logic [`LB_LEN-1:0]    lq_issue_idx
    , output logic [`LB_LEN-1:0]    lq_forward_idx

    // Outputs of dcache
    , output DCACHE_BLOCK [`SET_SIZE-1:0][`WAY_SIZE-1:0] dcache_blocks
    , output LOAD_BUFFER_ENTRY [`LOAD_BUFFER_SIZE-1:0]   load_buffer
    , output logic result_valid
    , output    [`LOAD_BUFFER_LEN-1:0] load_buffer_head_ptr
    , output    [`LOAD_BUFFER_LEN-1:0] load_buffer_send_ptr
    , output    [`LOAD_BUFFER_LEN-1:0] load_buffer_tail_ptr
`endif
);

    //if stage outputs
	logic [`XLEN-1:0]	proc2Icache_addr;
`ifndef DEBUG
	ID_PACKET        id_packet_out;
    logic            result_valid;
    logic [`LOAD_BUFFER_LEN-1:0] load_buffer_head_ptr;
    logic [`LOAD_BUFFER_LEN-1:0] load_buffer_send_ptr;
    logic [`LOAD_BUFFER_LEN-1:0] load_buffer_tail_ptr;
`endif

    logic  	[`XLEN-1:0] 	 Icache2proc_data;
    logic                    Icache2proc_valid;
    BUS_COMMAND              Icache2mem_command;    // command sent to memory
	logic   [`XLEN-1:0]      Icache2mem_addr;  // Address sent to memory

    BUS_COMMAND              Dcache2mem_command;      // Issue a bus load
	logic    [`XLEN-1:0]     Dcache2mem_addr;         // Address sent to memory
    MEM_SIZE                 Dcache2mem_size;
    logic    [2*`XLEN-1:0]     Dcache2mem_data;

    
    logic          [3:0]           mem2Dcache_response;     // Tag from memory about current request
	logic          [63:0]          mem2Dcache_data;        // Data coming back from memory
	logic          [3:0]           mem2Dcache_tag;   
    logic                          mem2Dcache_response_valid;      
    logic          [3:0]           mem2Icache_response;     // Tag from memory about current request
	logic          [63:0]          mem2Icache_data;         // Data coming back from memory
	logic          [3:0]           mem2Icache_tag;        
    logic                          mem2Icache_response_valid;     


    //toplevel_outputs
	logic rob_full;
	logic rs_alu_full;
    logic rs_mul_full;
    logic rs_branch_full;
    logic rs_lb_full;
    logic lb_full;
    logic rs_sq_full;
    logic sq_full;
    logic [`XLEN-1:0] result_PC;
    logic result_cond_branch;
    logic result_uncond_branch;
    logic [`XLEN-1:0] result_target_PC;
    logic result_local_taken;
    logic result_global_taken;
    logic result_taken;
    // logic result_mis_pred;

    logic commit_illegal;
    logic commit_halt;


	assign processor_error_status = commit_illegal             ? ILLEGAL_INST :
	                                commit_halt                ? HALTED_ON_WFI :
	                                NO_ERROR;
    
	logic [4:0] rs_full;
    assign rs_full = {(rs_sq_full|sq_full), (rs_lb_full|lb_full), rs_branch_full, rs_mul_full, rs_alu_full};
//////////////////////////////////////////////////
//                                              //
//                  IF-ID Stage                 //
//                                              //
//////////////////////////////////////////////////
	
	if_id_stage if_id_stage_0 (
        //inputs
	    .clock(clock),                  // system clock
	    .reset(reset),                  // system reset
        .rob_full(rob_full),      
        .rs_full(rs_full),
	    .Icache2proc_data(Icache2proc_data),       // Data coming back from instruction-memory
        .Icache2proc_valid(Icache2proc_valid),
	    .result_PC(result_PC),
		.result_cond_branch(result_cond_branch),
		.result_uncond_branch(result_uncond_branch),
		.result_target_PC(result_target_PC),
		.result_local_taken(result_local_taken),   // result_local_taken
    	.result_global_taken(result_global_taken),  // result_global_taken
		.result_taken(result_taken),        // result_taken
		.result_mis_pred(result_mis_pred),
        .result_valid(result_valid),
        
        //outputs
        .proc2Icache_addr(proc2Icache_addr),     // Address sent to Instruction memory
	    .id_packet_out(id_packet_out)     

    `ifdef DEBUG
        , .btb_taken(btb_taken)
        , .btb_target_PC(btb_target_PC)
        , .tournament_taken(tournament_taken)
        , .local_taken(local_taken)
        , .global_taken(global_taken)
    `endif
	);


//////////////////////////////////////////////////
//                                              //
//                   I-cache                    //
//                                              //
//////////////////////////////////////////////////

    //icache outputs
    icache icache0(
        // inputs
        .clock(clock),
        .reset(reset),
        .proc2Icache_addr(proc2Icache_addr),
        .mem2Icache_response(mem2Icache_response),         // Tag from memory about current request
        .mem2Icache_data(mem2Icache_data),             // Data coming back from memory
        .mem2Icache_tag(mem2Icache_tag),    
        .mem2Icache_response_valid(mem2Icache_response_valid),

        // outputs
        .Icache2proc_data(Icache2proc_data),
        .Icache2proc_valid(Icache2proc_valid),
        .Icache2mem_command(Icache2mem_command),    // command sent to memory
        .Icache2mem_addr(Icache2mem_addr)  // Address sent to memory
    );


//////////////////////////////////////////////////
//                                              //
//                 Cache Arbiter                //
//                                              //
//////////////////////////////////////////////////

    cache_arbiter cache_arbiter_0(
        // Main Memory
        .Dcache2mem_command(Dcache2mem_command),      // Issue a bus load
        .Dcache2mem_size(Dcache2mem_size),
        .Dcache2mem_addr(Dcache2mem_addr),         // Address sent to memory
        .Dcache2mem_data(Dcache2mem_data), 
        .Icache2mem_command(Icache2mem_command),    // command sent to memory
        .Icache2mem_addr(Icache2mem_addr),  // Address sent to memor 
        
        .mem2cache_response(mem2cache_response),     // Tag from memory about current request
        .mem2cache_data(mem2cache_data),         // Data coming back from memory
        .mem2cache_tag(mem2cache_tag), 
   
        // outputs
        .mem2Dcache_response(mem2Dcache_response),     // Tag from memory about current request
        .mem2Dcache_data(mem2Dcache_data),         // Data coming back from memory
        .mem2Dcache_tag(mem2Dcache_tag),    
        .mem2Dcache_response_valid(mem2Dcache_response_valid),      
        .mem2Icache_response(mem2Icache_response),     // Tag from memory about current request
        .mem2Icache_data(mem2Icache_data),         // Data coming back from memory
        .mem2Icache_tag(mem2Icache_tag),        
        .mem2Icache_response_valid(mem2Icache_response_valid),     
        .cache2mem_command(cache2mem_command),      // Issue a bus load
        .cache2mem_size(cache2mem_size),  

        .cache2mem_addr(cache2mem_addr),         // Address sent to memory
        .cache2mem_data(cache2mem_data)
    );



//////////////////////////////////////////////////
//                                              //
//                   top level                  //
//                                              //
//////////////////////////////////////////////////
    
    
    top_level top_level0(
        //inputs
        .clock(clock),        
        .reset(reset),    
        .mem2Dcache_data(mem2Dcache_data),
        .mem2Dcache_tag(mem2Dcache_tag),
        .mem2Dcache_response_valid(mem2Dcache_response_valid),
        .mem2Dcache_response(mem2Dcache_response),


        .id_packet(id_packet_out),              // Output of ID stage - decoded 
        // Outputs
        .rob_full(rob_full),     
        .rs_alu_full(rs_alu_full),
        .rs_mul_full(rs_mul_full),
        .rs_branch_full(rs_branch_full),
        .rs_lb_full(rs_lb_full),
        .lb_full(lb_full),
        .rs_sq_full(rs_sq_full),
        .sq_full(sq_full),
        .result_valid(result_valid),   //TODO: connect result_valid
        .result_PC(result_PC),
        .result_cond_branch(result_cond_branch),
	    .result_uncond_branch(result_uncond_branch),
	    .result_target_PC(result_target_PC),
	    .result_local_pred_direction(result_local_taken),
        .result_global_pred_direction(result_global_taken),
	    .result_branch_direction(result_taken),
	    .result_mis_pred(result_mis_pred),
        .commit_halt(commit_halt),
        .commit_illegal(commit_illegal),
        .Dcache2mem_command(Dcache2mem_command),      // Issue a bus load
	    .Dcache2mem_addr(Dcache2mem_addr),         // Address sent to memory
        .Dcache2mem_size(Dcache2mem_size),
        .Dcache2mem_data(Dcache2mem_data)

    `ifdef DEBUG
        , .prf_values(prf_values)
        , .prf_free(prf_free)
        , .prf_valid(prf_valid)
        , .free_preg_queue(free_preg_queue)
        , .free_preg_queue_head(free_preg_queue_head)
        , .free_preg_queue_tail(free_preg_queue_tail)
        , .rob_packets(rob_packets)
        , .rob_head(rob_head)
        , .rob_tail(rob_tail)
        , .rat_packets(rat_packets)
        , .rrat_packets(rrat_packets)

        , .opa_preg_idx(opa_preg_idx)                // to prf
        , .opb_preg_idx(opb_preg_idx)                 // to prf

        , .fu_opa_ready(fu_opa_ready)
        , .fu_opb_ready(fu_opb_ready)
        , .fu_opa_value(fu_opa_value)
        , .fu_opb_value(fu_opb_value)
        , .fu_offset(fu_offset)

        , .rs_alu_packets(rs_alu_packets)
        , .rs_alu_counter(rs_alu_counter)
        , .rs_alu_ex(rs_alu_ex)    // goes to priority selector (data ready && FU free) 
        , .rs_alu_free(rs_alu_free)
        , .rs_alu_free_idx(rs_alu_free_idx) // the rs idx that is selected for the dispatched instr
        , .rs_alu_ex_idx(rs_alu_ex_idx) 

        , .rs_mul_packets(rs_mul_packets)
        , .rs_mul_counter(rs_mul_counter)
        , .rs_mul_ex(rs_mul_ex) 
        , .rs_mul_free(rs_mul_free)
        , .rs_mul_free_idx(rs_mul_free_idx)
        , .rs_mul_ex_idx(rs_mul_ex_idx)

        , .rs_branch_packets(rs_branch_packets)
        , .rs_branch_counter(rs_branch_counter)
        , .rs_branch_ex(rs_branch_ex)    // goes to priority selector (data ready && FU free) 
        , .rs_branch_free(rs_branch_free)
        , .rs_branch_free_idx(rs_branch_free_idx) // the rs idx that is selected for the dispatched instr
        , .rs_branch_ex_idx(rs_branch_ex_idx)

        , .rs_lb_packets(rs_lb_packets)
        , .rs_lb_counter(rs_lb_counter)
        , .rs_lb_ex(rs_lb_ex)
        , .rs_lb_free(rs_lb_free)
        , .rs_lb_free_idx(rs_lb_free_idx)
        , .rs_lb_ex_idx(rs_lb_ex_idx)

        , .rs_sq_packets(rs_sq_packets)
        , .rs_sq_counter(rs_sq_counter)
        , .rs_sq_ex(rs_sq_ex)
        , .rs_sq_free(rs_sq_free)
        , .rs_sq_free_idx(rs_sq_free_idx)
        , .rs_sq_ex_idx(rs_sq_ex_idx)

        // output
        , .cdb_broadcast_valid(cdb_broadcast_valid)         
        , .module_select(module_select)               
        , .cdb_dest_preg_idx(cdb_dest_preg_idx)         
        , .cdb_rob_idx(cdb_rob_idx)
        , .cdb_result(cdb_result)
        , .cdb_broadcast_inst_PC(cdb_broadcast_inst_PC)       
        , .cdb_br_direction(cdb_br_direction)                 
        , .cdb_br_target_PC(cdb_br_target_PC)                 
        , .cdb_mis_pred(cdb_mis_pred)                         
        , .cdb_local_pred_direction(cdb_local_pred_direction)
        , .cdb_global_pred_direction(cdb_global_pred_direction)

        // Outputs of prf
        , .prf_free_preg_idx(prf_free_preg_idx)
        , .dest_preg_idx(dest_preg_idx)
        , .opa_ready(opa_ready)
        , .opa_value(opa_value)
        , .opb_ready(opb_ready)
        , .opb_value(opb_value)

        // Outputs of load store queue
        , .SQ(SQ)
        , .LB(LB)
        , .sq_head(sq_head)
        , .sq_counter(sq_counter)
        , .sq_empty(sq_empty)
        , .lq_free_idx(lq_free_idx) 
        , .lq_issue_idx(lq_issue_idx)
        , .lq_forward_idx(lq_forward_idx)

        // Outputs of dcache
        , .dcache_blocks(dcache_blocks)
        , .load_buffer(load_buffer)
        , .load_buffer_head_ptr(load_buffer_head_ptr)
        , .load_buffer_send_ptr(load_buffer_send_ptr)
        , .load_buffer_tail_ptr(load_buffer_tail_ptr)
    `endif
    );

endmodule  // module verisimple
`endif // __PROCESSOR_V__ 
