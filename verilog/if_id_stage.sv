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

module if_id_stage(
	input         			 clock,                  // system clock
	input         			 reset,                  // system reset
	input					 rob_full,
	input	[3:0]			 rs_full,
	input  	[`XLEN-1:0] 	 Icache2proc_data,       // Data coming back from instruction-memory
	input					 Icache2proc_valid,
	input	[`XLEN-1:0]	  	 result_PC,
	input		  			 result_cond_branch,
	input		  			 result_uncond_branch,
	input	[`XLEN-1:0]	  	 result_target_PC,
	input         			 result_local_taken,   // result_local_taken
    input         			 result_global_taken,  // result_global_taken
	input                    result_taken,        // result_taken
	input					 result_mis_pred,

	output logic [`XLEN-1:0] proc2Icache_addr,     // Address sent to Instruction memory
	output ID_PACKET         id_packet_out         // Output data packet from IF going to ID, see sys_defs for signal information 
);

	logic    [`XLEN-1:0] PC_reg;               // PC we are currently fetching
	logic    [`XLEN-1:0] PC_plus_4;
	logic    [`XLEN-1:0] btb_target_PC;
	logic    [`XLEN-1:0] next_PC;  
	 
	logic			     btb_taken;
	logic                tournament_taken;
	logic				 decoder_valid;
	DEST_REG_SEL 		 dest_reg_select; 


	predictor predictor0(
		// current instruction
		.clock(clock),                  // system clock
		.reset(reset),                  // system reset 
		.PC(PC_reg),                    // PC of branch to be predicted
		
		// resolved branch: updates on history tables
		.result_taken(result_taken),     // branch is actually taken or not 
		.result_local_taken(result_local_taken),
    	.result_global_taken(result_global_taken),
		.result_PC(result_PC),           // resolved branch's own PC 
		.result_cond_branch(result_cond_branch),        // if the result instr is a cond branch for updating the history table
		
		// output 
		.tournament_taken(tournament_taken),              // result of the predictor : whether taken or not 
		.local_taken(id_packet_out.local_taken),
    	.global_taken(id_packet_out.global_taken)
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

	decoder decoder_0 (  
		.inst(id_packet_out.inst), 
		// Outputs
		.opa_select(id_packet_out.opa_select),
		.opb_select(id_packet_out.opb_select),
		.alu_func(id_packet_out.alu_func),
		.fu_type(id_packet_out.fu_type),
		.dest_reg(dest_reg_select),
		.rd_mem(id_packet_out.rd_mem),
		.wr_mem(id_packet_out.wr_mem),
		.cond_branch(id_packet_out.cond_branch),
		.uncond_branch(id_packet_out.uncond_branch),
		.csr_op(id_packet_out.csr_op),
		.halt(id_packet_out.halt),
		.illegal(id_packet_out.illegal),
		.valid_inst(decoder_valid)
	);

	assign next_PC =  ((id_packet_out.cond_branch && tournament_taken) || id_packet_out.uncond_branch) ? btb_target_PC : PC_plus_4;

	assign proc2Icache_addr = {PC_reg[`XLEN-1:2], 2'b0};
	
	// this mux is because the Imem gives us 64 bits not 32 bits
	assign id_packet_out.inst = Icache2proc_data;
	assign id_packet_out.valid = Icache2proc_valid && !result_mis_pred && !rob_full && !rs_full[id_packet_out.fu_type]; 

	assign id_packet_out.NPC = next_PC;
	assign id_packet_out.PC  = PC_reg;
	
	assign id_packet_out.opa_areg_idx =  id_packet_out.inst.r.rs1;
	assign id_packet_out.opb_areg_idx =  id_packet_out.inst.r.rs2;

	assign id_packet_out.branch_prediction =  btb_taken & tournament_taken;// is the branch predict taken or not taken  
	always_comb begin
		case (dest_reg_select)
			DEST_RD:    id_packet_out.dest_areg_idx =  id_packet_out.inst.r.rd;
			DEST_NONE:  id_packet_out.dest_areg_idx = `ZERO_REG;
			default:    id_packet_out.dest_areg_idx = `ZERO_REG; 
		endcase
	end

	
	// default next PC value
	assign PC_plus_4 = PC_reg + 4; 
 
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