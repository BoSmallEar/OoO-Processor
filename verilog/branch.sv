module brcond(// Inputs
	input [`XLEN-1:0]  rs1,    // Value to check against condition
	input [`XLEN-1:0]  rs2,

	output logic       cond,            // 0/1 condition result (False/True)
);

	logic signed [`XLEN-1:0] signed_rs1, signed_rs2;
	assign signed_rs1 = rs_branch_packet.opa_value;
	assign signed_rs2 = rs_branch_packet.opb_value;
	always_comb begin
		cond = 0;
		case (func)
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
	input                        cdb_broadcast_alu,

	output logic                 br_direction, // branch direction 0 NT 1 T
	output logic [`XLEN-1:0]     br_target_PC, // branch target PC = PC+offset
    output logic                 br_valid,
    output logic [`PRF_LEN-1:0]  br_prf_idx,
    output logic [`ROB_LEN-1:0]  br_rob_idx,
	output logic                 br_mis_pred,
	output logic                 br_local_pred_direction,     // direction predicted by local predictor
	output logic                 br_global_pred_direction     // direction predicted by global predictor
)

	logic br_cond;

	brcond brcond0(
		.rs1(rs_branch_packet.opa_value),
		.rs2(rs_branch_packet.opb_value),
		.cond(br_cond)
	)
	assign br_target_PC = rs_branch_packet.PC + rs_branch_packet.offset;
	assign br_prf_idx = rs_branch_packet.dest_preg_idx; 
	assign br_rob_idx = rs_branch_packet.rob_idx;
	assign br_direction = rs_branch_packet.cond_branch ? br_cond : 1;
	assign br_mis_pred = (rs_branch_packet.br_pred_direction != br_direction) || (rs_branch_packet.cond_branch && (rs_branch_packet.br_pred_target_PC != br_target_PC));
	assign br_local_pred_direction = rs_branch_packet.local_pred_direction;
	assign br_global_pred_direction = rs_branch_packet.global_pred_direction;
	always_ff @(posedge clock) begin
		if (reset)
			br_valid <= `SD 1'b0;
		else if (branch_enable)
			br_valid <= `SD 1'b1;
		else if (cdb_broadcast_alu)
			br_valid <= `SD 1'b0;
	end

endmodule

