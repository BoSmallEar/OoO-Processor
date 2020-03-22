module brcond(// Inputs
	input [`XLEN-1:0]  rs1,    // Value to check against condition
	input [`XLEN-1:0]  rs2,
	input [2:0]        branch_func,

	output logic       cond            // 0/1 condition result (False/True)
);

	logic signed [`XLEN-1:0] signed_rs1, signed_rs2;
	assign signed_rs1 = rs1;
	assign signed_rs2 = rs2;
	always_comb begin
		cond = 0;
		case (branch_func)
			3'b000: cond = signed_rs1 == signed_rs2;  // BEQ
			3'b001: cond = signed_rs1 != signed_rs2;  // BNE
			3'b100: cond = signed_rs1 < signed_rs2;   // BLT
			3'b101: cond = signed_rs1 >= signed_rs2;  // BGE
			3'b110: cond = rs1 < rs2;                 // BLTU
			3'b111: cond = rs1 >= rs2;                // BGEU
		endcase
	end
	
endmodule // brcond

module branch(
	input                        clock,
	input                        reset,
	input                        branch_enable,
	input  RS_BRANCH_PACKET      rs_branch_packet,

	output logic                 br_direction, // branch direction 0 NT 1 T
	output logic [`XLEN-1:0]     br_target_PC, // branch target PC = PC+offset
    output logic                 br_valid, 
	output logic [`PRF_LEN-1:0]  br_prf_idx,
	output logic [`XLEN-1:0]     br_value,
    output logic [`ROB_LEN-1:0]  br_rob_idx,
	output logic                 br_mis_pred,
	output logic                 br_cond_branch,
	output logic                 br_uncond_branch,
	output logic                 br_local_pred_direction,     // direction predicted by local predictor
	output logic                 br_global_pred_direction,    // direction predicted by global predictor
	output logic [`XLEN-1:0]     br_PC
);

	logic br_cond;
	logic [`XLEN-1:0] br_offset;
	
	brcond brcond0(
		.rs1(rs_branch_packet.opa_value),
		.rs2(rs_branch_packet.opb_value),
		.branch_func(rs_branch_packet.branch_func),
		.cond(br_cond)
	);

	assign br_offset                = rs_branch_packet.offset;
	assign br_target_PC             = (br_direction == 0) ? (rs_branch_packet.PC + 4) :
	                                  (rs_branch_packet.is_jalr) ? (rs_branch_packet.opa_value + br_offset) :
									                               (rs_branch_packet.PC + br_offset); 
	assign br_prf_idx				= rs_branch_packet.dest_preg_idx;
	assign br_value                 = (br_uncond_branch) ? (rs_branch_packet.PC + 4) : 0;
	assign br_rob_idx               = rs_branch_packet.rob_idx;
	assign br_direction             = rs_branch_packet.cond_branch ? br_cond : 1;
	assign br_mis_pred              = rs_branch_packet.br_pred_target_PC != br_target_PC;
	assign br_cond_branch           = rs_branch_packet.cond_branch;
	assign br_uncond_branch         = rs_branch_packet.uncond_branch;
	assign br_local_pred_direction  = rs_branch_packet.local_pred_direction;
	assign br_global_pred_direction = rs_branch_packet.global_pred_direction;
	assign br_PC                    = rs_branch_packet.PC;

	assign br_valid                 = branch_enable;

	// always_ff @(posedge clock) begin
	// 	if (reset)
	// 		br_valid <= `SD 1'b0;
	// 	else
	// 		br_valid <= `SD branch_enable;
	// end

endmodule

