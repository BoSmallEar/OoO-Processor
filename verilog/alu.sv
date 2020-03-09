module alu(
	// input [`XLEN-1:0] opa,
	// input [`XLEN-1:0] opb,
	// ALU_FUNC     func,
    input RS_FU_PACKET           rs_fu_packet,
    input                        alu_enable,
	input                        cdb_broadcast_alu,

	output logic [`XLEN-1:0]     alu_value,
    output logic                 alu_valid,
    output logic [`PRF_LEN-1:0]  alu_prf_entry,
    output logic [`ROB_LEN-1:0]  alu_rob_entry,
);
	wire signed [`XLEN-1:0] signed_opa, signed_opb;
	logic [`XLEN-1:0] opa_mux_out, opb_mux_out;
	
	always_comb begin
		case (rs_fu_packet.alu_func)
			ALU_ADD:      alu_value = opa_mux_out + opb_mux_out;
			ALU_SUB:      alu_value = opa_mux_out - opb_mux_out;
			ALU_AND:      alu_value = opa_mux_out & opb_mux_out;
			ALU_SLT:      alu_value = signed_opa < signed_opb;
			ALU_SLTU:     alu_value = opa_mux_out < opb_mux_out;
			ALU_OR:       alu_value = opa_mux_out | opb_mux_out;
			ALU_XOR:      alu_value = opa_mux_out ^ opb_mux_out;
			ALU_SRL:      alu_value = opa_mux_out >> opb_mux_out[4:0];
			ALU_SLL:      alu_value = opa_mux_out << opb_mux_out[4:0];
			ALU_SRA:      alu_value = signed_opa >>> opb_mux_out[4:0]; // arithmetic from logical shift
			// ALU_MUL:      alu_value = signed_mul[`XLEN-1:0];
			// ALU_MULH:     alu_value = signed_mul[2*`XLEN-1:`XLEN];
			// ALU_MULHSU:   alu_value = mixed_mul[2*`XLEN-1:`XLEN];
			// ALU_MULHU:    alu_value = unsigned_mul[2*`XLEN-1:`XLEN];

			default:      alu_value = `XLEN'hfacebeec;  // here to prevent latches
		endcase
	end

	always_ff @(posedge clock) begin
		if (reset)
			alu_valid <= `SD 1'b0;
		else if (alu_enable)
			alu_valid <= `SD 1'b1;
		else if (cdb_broadcast_alu)
			alu_valid <= `SD 1'b0;
	end
endmodule // alu