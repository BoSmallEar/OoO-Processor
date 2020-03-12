module cdb(
    //inputs
    input clock,
    input reset,
    /* ------------ Who is coming ? for all Execution units [To be edited]---------- */
    input br_valid,
    input alu_valid,
    input mul_valid,
    // ............
    /* -------------------- Ports for Incoming packets ------------------- */
    input  logic [`XLEN-1:0]     value_to_CDB,
    input  logic [`PRF_LEN-1:0]  prf_entry,
    input  logic [`ROB_LEN-1:0]  rob_entry,
    /* ... */
    //outputs
    output  logic [`PRF_LEN-1:0] cdb_dest_preg_idx,
    output  logic                cdb_broadcast_valid,
    output  logic [`XLEN-1:0]    value_from_CDB, 
);
    
    always_ff @(posedge clock) begin
		if (reset)
			mul_valid <= `SD 1'b0;
		else if (mul_enable)
			mul_valid <= `SD 1'b1;
		else if (cdb_broadcast_mul)
			mul_valid <= `SD 1'b0;
	end
