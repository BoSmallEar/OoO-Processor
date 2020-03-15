`define STAGE 8
`define DOUBLE_XLEN 2*`DOUBLE_XLEN
// Negative numbers are represented in 2's complement form

module mult_stage(
	input clock, reset, start,
	input [`DOUBLE_XLEN-1:0] product_in, mplier_in, mcand_in,

	output logic done,
	output logic [`DOUBLE_XLEN-1:0] product_out, mplier_out, mcand_out
);

	logic [`DOUBLE_XLEN-1:0] prod_in_reg, partial_prod_reg;
	logic [`DOUBLE_XLEN-1:0] partial_product, next_mplier, next_mcand;

	assign product_out = prod_in_reg + partial_prod_reg;

	assign partial_product = mplier_in[(`DOUBLE_XLEN/`STAGE)-1:0] * mcand_in;

	assign next_mplier = {{(`DOUBLE_XLEN/`STAGE){1'b0}},mplier_in[(`DOUBLE_XLEN-1):(`DOUBLE_XLEN/`STAGE)]};
	assign next_mcand = {mcand_in[`DOUBLE_XLEN-(`DOUBLE_XLEN/`STAGE)-1:0],{(`DOUBLE_XLEN/`STAGE){1'b0}}};

	//synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		prod_in_reg      <= `SD product_in;
		partial_prod_reg <= `SD partial_product;
		mplier_out       <= `SD next_mplier;
		mcand_out        <= `SD next_mcand;
	end

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if(reset)
			done <= `SD 1'b0;
		else
			done <= `SD start;
	end

endmodule

/* -------------------------------  Multiplier  ---------------------------------*/
module mult(
	input clock, reset,
	input [`DOUBLE_XLEN-1:0] mcand, mplier,
	input start,
				
	output logic [`DOUBLE_XLEN-1:0] product,
	output logic done
);

	logic [`DOUBLE_XLEN-1:0] mcand_out, mplier_out;
	logic [((`STAGE-1)*`DOUBLE_XLEN)-1:0] internal_products, internal_mcands, internal_mpliers;
	logic [(`STAGE-2):0] internal_dones;
  
	mult_stage mstage [(`STAGE-1):0] (
		.clock(clock),
		.reset(reset),
		.product_in({internal_products,`DOUBLE_XLEN'h0}),
		.mplier_in({internal_mpliers,mplier}),
		.mcand_in({internal_mcands,mcand}),
		.start({internal_dones,start}),
		.product_out({product,internal_products}),
		.mplier_out({mplier_out,internal_mpliers}),
		.mcand_out({mcand_out,internal_mcands}),
		.done({done,internal_dones})
	);

endmodule

/* -------------------------------  Modified Multiplier  ---------------------------------*/
module mult2cdb(
    input                        clock,
	input 						 reset,
    input RS_MUL_PACKET          rs_mul_packet,
    input                        mul_enable,
	input 						 cdb_broadcast_is_mul,
	output logic [`XLEN-1:0]     mul_value,
    output logic                 mul_valid,
    output logic [`PRF_LEN-1:0]  mul_prf_idx,
    output logic [`ROB_LEN-1:0]  mul_rob_idx,
	output logic [`XLEN-1:0]     mul_PC
);
	/*
	MUL performs an XLEN-bit×XLEN-bit multiplication and places the lower XLEN bits in the destination register. 
	MULH, MULHU, and MULHSU perform the same multiplication 
	but return the upper XLEN bits of the full 2×XLEN-bit product, 
	for
	signed×signed,
	unsigned×unsigned,
	and signed×unsigned multiplication respectively. 
	*/

	logic		 [`DOUBLE_XLEN-1:0] unsigned_opa, unsigned_opb;
	// logic signed [`DOUBLE_XLEN-1:0] signed_opa, signed_opb;
	logic		 [`DOUBLE_XLEN-1:0] absolute_opa, absolute_opb;
	logic 		 					a_sign, b_sign;

	assign a_sign = rs_mul_packet.opa_value[`XLEN-1];
	assign b_sign = rs_mul_packet.opb_value[`XLEN-1];

    assign unsigned_opa = {{`XLEN{1'b0}}, rs_mul_packet.opa_value};
    assign unsigned_opb = {{`XLEN{1'b0}}, rs_mul_packet.opb_value};
	// assign signed_opa   = a_sign == 0 ? unsigned_opa : {{`XLEN{1'b1}}, rs_mul_packet.opa_value};
	// assign signed_opb   = b_sign == 0 ? unsigned_opb : {{`XLEN{1'b1}}, rs_mul_packet.opb_value};

	assign absolute_opa   = a_sign == 0 ? unsigned_opa : 1 + ~{{`XLEN{1'b1}}, rs_mul_packet.opa_value};
	assign absolute_opb   = b_sign == 0 ? unsigned_opb : 1 + ~{{`XLEN{1'b1}}, rs_mul_packet.opb_value};

    assign mul_prf_idx = rs_mul_packet.dest_preg_idx;
	assign mul_rob_idx = rs_mul_packet.rob_idx;
	assign mul_PC	   = rs_mul_packet.PC;
	
	logic [`DOUBLE_XLEN-1:0] product;
	logic done;
	
	mult mult0 (
		.mcand(absolute_opa),
		.mplier(absolute_opb),
        .clock(clock),
        .reset(reset),
        .start(mul_enable), 
        .product(product),
        .done(done)
    );

	always_comb begin
		case (rs_fu_packet.alu_func)
			ALU_MUL:	mul_value = (a_sign==b_sign) ? product[`XLEN-1:0] : 1 + ~product[`XLEN-1:0];
			ALU_MULH:	mul_value = (a_sign==b_sign) ? product[`DOUBLE_XLEN-1:`XLEN] : 1 + ~product[`XLEN-1:0];
			ALU_MULHSU:	mul_value = (a_sign==b_sign) ? product[`DOUBLE_XLEN-1:`XLEN] : 1 + ~product[`DOUBLE_XLEN-1:`XLEN];
			ALU_MULHU:	mul_value = (a_sign==b_sign) ? product[`DOUBLE_XLEN-1:`XLEN] : 1 + ~product[`DOUBLE_XLEN-1:`XLEN];
			default:	mul_value = `XLEN'hfacebeec;  // here to prevent latches
		endcase
	end

	always_ff @(posedge clock) begin
		if (reset)
			mul_valid <= `SD 1'b0;
		else begin
			if (!mul_valid)
				mul_valid <= `SD done;
			else
				mul_valid <= `SD ~cdb_broadcast_is_mul;
		end 
	end
endmodule
