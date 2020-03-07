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
	// ALU opA mux
	//
	always_comb begin
		opa_mux_out = `XLEN'hdeadfbac;
		case (rs_fu_packet.opa_select)
			OPA_IS_RS1:  opa_mux_out = rs_fu_packet.opa_value;
			OPA_IS_NPC:  opa_mux_out = rs_fu_packet.NPC;
			OPA_IS_PC:   opa_mux_out = rs_fu_packet.PC;
			OPA_IS_ZERO: opa_mux_out = 0;
		endcase
	end
	 // ALU opB mux
	 //
	always_comb begin
		// Default value, Set only because the case isnt full.  If you see this
		// value on the output of the mux you have an invalid opb_select
		opb_mux_out = `XLEN'hfacefeed;
		case (rs_fu_packet.opb_select)
			OPB_IS_RS2:   opb_mux_out = rs_fu_packet.opb_value;
			OPB_IS_I_IMM: opb_mux_out = `RV32_signext_Iimm(rs_fu_packet.inst);
			OPB_IS_S_IMM: opb_mux_out = `RV32_signext_Simm(rs_fu_packet.inst);
			OPB_IS_B_IMM: opb_mux_out = `RV32_signext_Bimm(rs_fu_packet.inst);
			OPB_IS_U_IMM: opb_mux_out = `RV32_signext_Uimm(rs_fu_packet.inst);
			OPB_IS_J_IMM: opb_mux_out = `RV32_signext_Jimm(rs_fu_packet.inst);
		endcase 
	end
	assign signed_opa = opa_mux_out;
	assign signed_opb = opb_mux_out;

    
    assign alu_prf_entry = rs_fu_packet.dest_preg_idx;
    assign alu_rob_entry = rs_fu_packet.rob_index;

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