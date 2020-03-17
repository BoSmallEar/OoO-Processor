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

`ifndef __PROCESSOR_V__
`define __PROCESSOR_V__

`timescale 1ns/100ps

module processor (

	input         clock,                     // System clock
	input         reset,                     // System reset
	input [3:0]   mem2proc_response,         // Tag from memory about current request
	input [63:0]  mem2proc_data,             // Data coming back from memory
	input [3:0]   mem2proc_tag,              // Tag from memory about current reply
	
	output logic [1:0]  proc2mem_command,    // command sent to memory
	output logic [`XLEN-1:0] proc2mem_addr,  // Address sent to memory
	output logic [63:0] proc2mem_data,       // Data sent to memory
	output MEM_SIZE proc2mem_size,           // data size sent to memory
 
);
 
	
	assign proc2mem_command = Icache2mem_command;
	assign proc2mem_addr = Icache2mem_addr; 
	assign proc2mem_size = DOUBLE;
	assign proc2mem_data = 64'b0;

    
	logic dispatch_enable;

//////////////////////////////////////////////////
//                                              //
//                  IF-ID Stage                 //
//                                              //
//////////////////////////////////////////////////

    //if stage outputs
	logic [`XLEN-1:0]	proc2Icache_addr;
	ID_PACKET        if_packet_out;
	
	if_id_stage if_id_stage_0 (
        //inputs
	    .clock(clock),                  // system clock
	    .reset(reset),                  // system reset
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
        
        //outputs
        .proc2Icache_addr(proc2Icache_addr),     // Address sent to Instruction memory
	    .if_packet_out(if_packet_out)     
	);


//////////////////////////////////////////////////
//                                              //
//                   I-cache                    //
//                                              //
//////////////////////////////////////////////////

    //icache outputs

    logic  	[`XLEN-1:0] 	Icache2proc_data,
    logic                    Icache2proc_valid,
    logic    [1:0]           Icache2mem_command,    // command sent to memory
	logic    [`XLEN-1:0]     Icache2mem_addr,  // Address sent to memory

    icache icache0(
        //inputs
        .proc2Icache_addr(proc2Icache_addr),
        .mem2Icache_response(mem2proc_response),         // Tag from memory about current request
        .mem2Icache_data(mem2proc_data),             // Data coming back from memory
        .mem2Icache_tag(mem2proc_tag),    

        //outputs
        .Icache2proc_data(Icache2proc_data),
        .Icache2proc_valid(Icache2proc_valid),
        .Icache2mem_command(Icache2mem_command),    // command sent to memory
        .Icache2mem_addr(Icache2mem_addr),  // Address sent to memory
    );

//////////////////////////////////////////////////
//                                              //
//                   top level                  //
//                                              //
//////////////////////////////////////////////////

    //toplevel_outputs
	logic rob_full;
	logic rs_alu_full;
    logic rs_mul_full;
    logic rs_mem_full;
    logic rs_branch_full;
    logic [`XLEN-1:0] result_PC;
    logic result_cond_branch;
    logic result_uncond_branch;
    logic [`XLEN-1:0] result_target_PC;
    logic result_local_taken;
    logic result_global_taken;
    logic result_taken;
    logic result_mis_pred;


	assign dispatch_enable = ~rob_full && ~rs_full && id_packet.valid; // ???
    top_level top_level0(
        //inputs
        .clock(clock),        
        .reset(reset),    
        .id_packet(id_packet),              // Output of ID stage - decoded
        .dispatch_enable(dispatch_enable),        // allow to handle the input decoded packet
        // Outputs
        .rob_full(rob_full),     
        .rs_alu_full(rs_alu_full),
        .rs_mul_full(rs_mul_full),
        .rs_mem_full(rs_mem_full),
        .rs_branch_full(rs_branch_full),
        .result_PC(result_PC),
        .result_cond_branch(result_cond_branch),
	    .result_uncond_branch(result_uncond_branch),
	    .result_target_PC(result_target_PC),
	    .result_local_taken(result_local_taken),
        .result_global_taken(result_global_taken),
	    .result_direction(result_taken),
	    .result_mis_pred(result_mis_pred),
    );

endmodule  // module verisimple
`endif // __PROCESSOR_V__
