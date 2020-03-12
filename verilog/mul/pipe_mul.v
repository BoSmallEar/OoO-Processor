
`define STAGE 8

module mult_stage(
					input clock, reset, start,
					input [(`XLEN-1):0] product_in, mplier_in, mcand_in,

					output logic done,
					output logic [(`XLEN-1):0] product_out, mplier_out, mcand_out
				);


	
	logic [(`XLEN-1):0] prod_in_reg, partial_prod_reg;
	logic [(`XLEN-1):0] partial_product, next_mplier, next_mcand;

	assign product_out = prod_in_reg + partial_prod_reg;

	assign partial_product = mplier_in[(`XLEN/`STAGE)-1:0] * mcand_in;

	assign next_mplier = {{(`XLEN/`STAGE){1'b0}},mplier_in[(`XLEN-1):(`XLEN/`STAGE)]};
	assign next_mcand = {mcand_in[`XLEN-(`XLEN/`STAGE)-1:0],{(`XLEN/`STAGE){1'b0}}};

	//synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		prod_in_reg      <= #1 product_in;
		partial_prod_reg <= #1 partial_product;
		mplier_out       <= #1 next_mplier;
		mcand_out        <= #1 next_mcand;
	end

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if(reset)
			done <= #1 1'b0;
		else
			done <= #1 start;
	end

endmodule

/* -------------------------------  Multiplier  ---------------------------------*/
module mult(
				input clock, reset,
				input [`XLEN-1:0] mcand, mplier,
				input start,
				
				output [2*`XLEN-1:0] product,
				output done
			);

  logic [`XLEN-1:0] mcand_out, mplier_out;
  logic [((`STAGE-1)*`XLEN)-1:0] internal_products, internal_mcands, internal_mpliers;
  logic [(`STAGE-2):0] internal_dones;
  
	mult_stage mstage [(`STAGE-1):0]  (
		.clock(clock),
		.reset(reset),
		.product_in({internal_products,`XLEN'h0}),
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
	input                        cdb_broadcast_mul,

	output logic [`XLEN-1:0]     mul_value,
    output logic                 mul_valid,
    output logic [`PRF_LEN-1:0]  mul_prf_entry,
    output logic [`ROB_LEN-1:0]  mul_rob_entry
)
	/*
	MUL performs an XLEN-bit×XLEN-bit multiplication and places the lower XLEN bits in the destination register. 
	MULH, MULHU, and MULHSU perform the same multiplication 
	but return the upper XLEN bits of the full 2×XLEN-bit product, 
	for signed×signed,
	unsigned×unsigned,
	and signed×unsigned multiplication respectively. 
	*/

	wire 		[`XLEN-1:0]	  opa, opb;
	wire signed [`XLEN-1:0]   signed_opa, signed_opb;
	wire signed [2*`XLEN-1:0] signed_mul, mixed_mul;
	wire        [2*`XLEN-1:0] unsigned_mul;
    assign opa = rs_mul_packet.opa_value;
    assign opb = rs_mul_packet.opb_value;
	assign signed_opa = opa;
	assign signed_opb = opb;
    assign mul_prf_entry = rs_mul_packet.dest_preg_idx;
	assign mul_rob_entry = rs_mul_packet.rob_idx;
	
// assign signed_mul = signed_opa * signed_opb;		
mult mul_signed( .mcand(signed_opa), .mplier(signed_opb),
        .clock(clock),
        .reset(reset),
        .start(mul_enable), 
        .product(signed_mul),
        .done(mul_valid)
        );
// assign unsigned_mul = opa * opb;		
mult mul_unsigned( .mcand(opa), .mplier(opb),
        .clock(clock),
        .reset(reset),
        .start(mul_enable), 
        .product(unsigned_mul),
        .done(mul_valid)
        );
// assign mixed_mul = signed_opa * opb;
mult mul_mixed( .mcand(signed_opa), .mplier(opb),
        .clock(clock),
        .reset(reset),
        .start(mul_enable), 
        .product(mixed_mul),
        .done(mul_valid)
        );

	always_comb begin
		case (rs_fu_packet.alu_func)
			ALU_MUL:      mul_value = signed_mul[`XLEN-1:0];
			ALU_MULH:     mul_value = signed_mul[2*`XLEN-1:`XLEN];
			ALU_MULHSU:   mul_value = mixed_mul[2*`XLEN-1:`XLEN];
			ALU_MULHU:    mul_value = unsigned_mul[2*`XLEN-1:`XLEN];
			default:      mul_value = `XLEN'hfacebeec;  // here to prevent latches
		endcase
	end

	always_ff @(posedge clock) begin
		if (reset)
			mul_valid <= `SD 1'b0;
		else if (mul_enable)
			mul_valid <= `SD 1'b1;
		else if (cdb_broadcast_mul)
			mul_valid <= `SD 1'b0;
	end
