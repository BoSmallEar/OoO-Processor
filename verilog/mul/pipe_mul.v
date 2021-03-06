`define STAGE 8
`define DOUBLE_XLEN 2*`XLEN
// Negative numbers are represented in 2's complement form


typedef struct packed {
	logic [`XLEN-1:0]       PC;
	logic [`PRF_LEN-1:0]    dest_preg_idx;
	logic [`ROB_LEN-1:0]    rob_idx;
	logic					a_sign;
	logic					b_sign;
	ALU_FUNC                mul_func;
} MUL_PACKET;


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
		.product_in({internal_products,{`DOUBLE_XLEN{1'b0}}}),
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
	input                        reset,
	input RS_MUL_PACKET          rs_mul_packet,
	input                        mul_enable,
	
	output logic [`XLEN-1:0]     mul_value,
	output logic                 mul_valid,
	output logic				 mul_free,
	output logic [`PRF_LEN-1:0]  mul_prf_idx,
	output logic [`ROB_LEN-1:0]  mul_rob_idx,
	output logic [`XLEN-1:0]     mul_PC
);
	
	logic		[`DOUBLE_XLEN-1:0] 	unsigned_opa, unsigned_opb;
	logic		[`DOUBLE_XLEN-1:0] 	absolute_opa, absolute_opb;
	logic							a_sign, b_sign;
	logic 			 				a_sign_latch, b_sign_latch;
	logic 		[`DOUBLE_XLEN-1:0] 	product;
	logic 		[`DOUBLE_XLEN-1:0] 	product_inv;
	ALU_FUNC 						mul_func;
	logic                           done;

	MUL_PACKET  [`STAGE-1:0]		mul_packets;
	MUL_PACKET						mul_packet_in;

  	assign unsigned_opa = {{`XLEN{1'b0}}, rs_mul_packet.opa_value};
  	assign unsigned_opb = {{`XLEN{1'b0}}, rs_mul_packet.opb_value};
	assign a_sign =  (rs_mul_packet.mul_func == ALU_MULHU || rs_mul_packet.mul_func == ALU_MULHSU) ? 0 : rs_mul_packet.opa_value[`XLEN-1];
	assign b_sign =  (rs_mul_packet.mul_func == ALU_MULHU || rs_mul_packet.mul_func == ALU_MULHSU) ? 0 : rs_mul_packet.opb_value[`XLEN-1];
	assign absolute_opa = a_sign == 0 ? unsigned_opa : 1 + ~{{`XLEN{1'b1}}, rs_mul_packet.opa_value};
	assign absolute_opb = b_sign == 0 ? unsigned_opb : 1 + ~{{`XLEN{1'b1}}, rs_mul_packet.opb_value};
	
	mult mult0 (
		.mcand(absolute_opa),
		.mplier(absolute_opb),
		.clock(clock),
		.reset(reset),
		.start(mul_enable), 
		.product(product),
		.done(done)
  );

	assign mul_valid = done;
	assign product_inv = 1 + ~product;

	assign mul_PC = mul_packets[`STAGE-1].PC;
	assign mul_prf_idx = mul_packets[`STAGE-1].dest_preg_idx;
	assign mul_rob_idx = mul_packets[`STAGE-1].rob_idx;
	assign a_sign_latch = mul_packets[`STAGE-1].a_sign;
	assign b_sign_latch = mul_packets[`STAGE-1].b_sign;
	assign mul_func = mul_packets[`STAGE-1].mul_func;

	assign mul_packet_in = {rs_mul_packet.PC, rs_mul_packet.dest_preg_idx, rs_mul_packet.rob_idx, a_sign, b_sign, rs_mul_packet.mul_func};

	always_comb begin
		case (mul_func)
			ALU_MUL:    mul_value = (a_sign_latch == b_sign_latch) ? product[`XLEN-1:0] : product_inv[`XLEN-1:0];
			ALU_MULH:   mul_value = (a_sign_latch == b_sign_latch) ? product[`DOUBLE_XLEN-1:`XLEN] : product_inv[`DOUBLE_XLEN-1:`XLEN];
			ALU_MULHSU:	mul_value = product[`DOUBLE_XLEN-1:`XLEN];
			ALU_MULHU:  mul_value = product[`DOUBLE_XLEN-1:`XLEN];
			default:    mul_value = `XLEN'hfacebeec;  // here to prevent latches
		endcase
	end

	// always_ff @(posedge clock) begin
	// 	if (mul_enable) begin
	//     	mul_prf_idx  <= `SD rs_mul_packet.dest_preg_idx;
	// 		mul_rob_idx  <= `SD rs_mul_packet.rob_idx;
	// 		mul_PC	     <= `SD rs_mul_packet.PC;
	// 		a_sign_latch <= `SD a_sign;
	// 		b_sign_latch <= `SD b_sign;
	// 	end
	// end

    // synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset) begin 
			mul_free <= `SD 1'b1;
			mul_packets <= `SD 0;
		end
		else begin
			mul_free <= `SD 1'b1;
			mul_packets[`STAGE-1:1] <= `SD mul_packets[`STAGE-2:0];
			if (mul_enable) begin
				mul_packets[0] <= `SD mul_packet_in;
			end
			else begin
				mul_packets[0] <= `SD 0;
			end
		end
	end
endmodule