module alu(
	// input [`XLEN-1:0] opa,
	// input [`XLEN-1:0] opb,
	// ALU_FUNC     func,
    input RS_FU_PACKET           rs_fu_packet,
    input                        alu_enable,

	output logic [`XLEN-1:0]     alu_value,
    output logic                 alu_valid,
    output logic [`PRF_LEN-1:0]  alu_prf_entry,
    output logic [`ROB_LEN-1:0]  alu_rob_entry,
);
	wire signed [`XLEN-1:0] signed_opa, signed_opb;
	// wire signed [2*`XLEN-1:0] signed_mul, mixed_mul;
	// wire        [2*`XLEN-1:0] unsigned_mul;
	assign signed_opa = rs_fu_packet.opa_value;
	assign signed_opb = rs_fu_packet.opb_value;
	// assign signed_mul = signed_opa * signed_opb;
	// assign unsigned_mul = rs_fu_packet.opa_value * rs_fu_packet.opa_value;
	// assign mixed_mul = signed_opa * rs_fu_packet.opb_value;

    assign alu_valid = alu_enable;
    assign alu_prf_entry = rs_fu_packet.dest_preg_idx;
    assign alu_rob_entry = rs_fu_packet.rob_index;

	always_comb begin
		case (rs_fu_packet.alu_func)
			ALU_ADD:      alu_value = rs_fu_packet.opa_value + rs_fu_packet.opb_value;
			ALU_SUB:      alu_value = rs_fu_packet.opa_value - rs_fu_packet.opb_value;
			ALU_AND:      alu_value = rs_fu_packet.opa_value & rs_fu_packet.opb_value;
			ALU_SLT:      alu_value = signed_opa < signed_opb;
			ALU_SLTU:     alu_value = rs_fu_packet.opa_value < rs_fu_packet.opb_value;
			ALU_OR:       alu_value = rs_fu_packet.opa_value | rs_fu_packet.opb_value;
			ALU_XOR:      alu_value = rs_fu_packet.opa_value ^ rs_fu_packet.opb_value;
			ALU_SRL:      alu_value = rs_fu_packet.opa_value >> rs_fu_packet.opb_value[4:0];
			ALU_SLL:      alu_value = rs_fu_packet.opa_value << rs_fu_packet.opb_value[4:0];
			ALU_SRA:      alu_value = signed_opa >>> rs_fu_packet.opb_value[4:0]; // arithmetic from logical shift
			// ALU_MUL:      alu_value = signed_mul[`XLEN-1:0];
			// ALU_MULH:     alu_value = signed_mul[2*`XLEN-1:`XLEN];
			// ALU_MULHSU:   alu_value = mixed_mul[2*`XLEN-1:`XLEN];
			// ALU_MULHU:    alu_value = unsigned_mul[2*`XLEN-1:`XLEN];

			default:      alu_value = `XLEN'hfacebeec;  // here to prevent latches
		endcase
	end
endmodule // alu