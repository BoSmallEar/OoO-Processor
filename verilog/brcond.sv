module brcond(// Inputs
	input RS_FU_PACKET rs_fu_packet,    // Value to check against condition
	input              brcond_enable,

	output logic       cond,            // 0/1 condition result (False/True)
	output logic       brcond_valid
);

	logic signed [`XLEN-1:0] signed_rs1, signed_rs2;
	assign signed_rs1 = rs_fu_packet.opa_value;
	assign signed_rs2 = rs_fu_packet.opb_value;
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