module alu(
	// input [`XLEN-1:0] opa,
	// input [`XLEN-1:0] opb,
	// ALU_FUNC     func,
	input 						 clock,
	input                        reset,
    input RS_ALU_PACKET          rs_alu_packet,
    input                        alu_enable,
	input                        cdb_broadcast_is_alu,

	output logic [`XLEN-1:0]     alu_value,
    output logic                 alu_valid,
    output logic [`PRF_LEN-1:0]  alu_prf_idx,
    output logic [`ROB_LEN-1:0]  alu_rob_idx,
	output logic [`XLEN-1:0]     alu_PC
);
	wire signed [`XLEN-1:0] signed_opa, signed_opb;
	assign signed_opa = rs_alu_packet.opa_value;
	assign signed_opb = rs_alu_packet.opb_value;
	assign alu_prf_idx = rs_alu_packet.dest_preg_idx;
	assign alu_rob_idx = rs_alu_packet.rob_idx;
	assign alu_PC	   = rs_alu_packet.PC;
	
	always_comb begin
		case (rs_alu_packet.alu_func)
			ALU_ADD:      alu_value = rs_alu_packet.opa_value + rs_alu_packet.opb_value;
			ALU_SUB:      alu_value = rs_alu_packet.opa_value - rs_alu_packet.opb_value;
			ALU_AND:      alu_value = rs_alu_packet.opa_value & rs_alu_packet.opb_value;
			ALU_SLT:      alu_value = signed_opa < signed_opb;
			ALU_SLTU:     alu_value = rs_alu_packet.opa_value < rs_alu_packet.opb_value;
			ALU_OR:       alu_value = rs_alu_packet.opa_value | rs_alu_packet.opb_value;
			ALU_XOR:      alu_value = rs_alu_packet.opa_value ^ rs_alu_packet.opb_value;
			ALU_SRL:      alu_value = rs_alu_packet.opa_value >> rs_alu_packet.opb_value[4:0];
			ALU_SLL:      alu_value = rs_alu_packet.opa_value << rs_alu_packet.opb_value[4:0];
			ALU_SRA:      alu_value = rs_alu_packet.opa_value >>> rs_alu_packet.opb_value[4:0]; // arithmetic from logical shift
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
		else if (cdb_broadcast_is_alu)
			alu_valid <= `SD 1'b0;
	end
endmodule // alu