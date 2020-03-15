/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  if_stage.v                                          //
//                                                                     //
//  Description :  instruction fetch (IF) stage of the pipeline;       // 
//                 fetch instruction, compute next PC location, and    //
//                 send them down the pipeline.                        //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`timescale 1ns/100ps

module if_stage(
	input         			 clock,                  // system clock
	input         			 reset,                  // system reset
	input  	[`XLEN-1:0] 	 Icache2proc_data,       // Data coming back from instruction-memory
	input					 Icache2proc_valid,
	input	[`XLEN-1:0]	  	 result_PC,
	input		  			 result_cond_branch,
	input		  			 result_uncond_branch,
	input	[`XLEN-1:0]	  	 result_target_PC,
	input         			 result_local_taken,
    input         			 result_global_taken,
	input		  			 result_taken,
	input					 result_mis_pred,

	output logic [`XLEN-1:0] proc2Icache_addr,     // Address sent to Instruction memory
	output IF_ID_PACKET      if_packet_out         // Output data packet from IF going to ID, see sys_defs for signal information 
);

	predictor predictor0(
		// current instruction
		.clock(clock),                  // system clock
		.reset(reset),                  // system reset
		.cond_branch(cond_branch),      // if the branch is a conditional branch to store the tounament history
		.PC(PC_reg),                    // PC of branch to be predicted
		
		// resolved branch: updates on history tables
		.result_taken(result_taken),     // branch is actually taken or not 
		.result_local_taken(result_local_taken),
    	.result_global_taken(result_global_taken),
		.result_PC(result_PC),           // resolved branch's own PC 
		.result_cond_branch(result_cond_branch),        // if the result instr is a cond branch for updating the history table
		
		// output 
		.tournament_taken(tournament_taken)              // result of the predictor : whether taken or not 
	);  

	btb btb0(
		//inputs
		.clock(clock),                  // system clock
		.reset(reset),                  // system reset
		.PC(PC_reg), 
		
		.result_taken(result_taken),           // branch is actually taken or not
		.result_branch(result_cond_branch || result_uncond_branch),     // result is a branch or not
		.result_PC(result_PC),                 // resolved branch's own PC
		.result_target_PC(result_target_PC),   // resolved branch target address

		//outputs
		.btb_target_PC(btb_target_PC),
		.btb_taken(btb_taken) 
	);

	logic    [`XLEN-1:0] PC_reg;               // PC we are currently fetching
	logic    [`XLEN-1:0] PC_plus_4;
	logic    [`XLEN-1:0] btb_target_PC;
	logic    [`XLEN-1:0] next_PC; 
	
	logic				 taken;
	logic			     btb_taken;
	logic                tournament_taken;

	assign next_PC = ((cond_branch && tournament_taken) || uncond_branch) ? btb_target_PC : PC_plus_4;
	assign taken = btb_taken && tournament_taken;

	assign proc2Icache_addr = {PC_reg[`XLEN-1:2], 2'b0};
	
	// this mux is because the Imem gives us 64 bits not 32 bits
	assign if_packet_out.inst = Icache2proc_data;
	assign if_packet_out.valid = Icache2proc_valid && !result_mis_pred;
	
	// default next PC value
	assign PC_plus_4 = PC_reg + 4; 
 
	// Pass PC+4 down pipeline w/instruction
	assign if_packet_out.NPC = PC_plus_4;
	assign if_packet_out.PC  = PC_reg;
	// This register holds the PC value
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if(reset)
			PC_reg <= `SD 0;                // initial PC value is 0
		else if (result_mis_pred) begin
			PC_reg <= `SD result_target_PC; // if mispredict, jump to the target PC
		end
		else if (!Icache2proc_valid) begin
			PC_reg <= `SD PC_reg;           // if not valid, hold the current PC
		end
		else
			PC_reg <= `SD next_PC;          // transition to next PC
	end  // always
	
	 
endmodule  // module if_stage
