//////////////////////////////////////////////////////////////////////////
//                                                                      //
//   Modulename :  rs.v                                                 //
//                                                                      //
//  Description :  reservation station                                  //
//                                                                      // 
//                                                                      //
//                                                                      //
//////////////////////////////////////////////////////////////////////////

`ifndef __RS_V__
`define __RS_V__

`timescale 1ns/100ps

module rs_mul(
    input clock,
    input reset,
    input [`PRF_LEN-1:0]  opa_preg_idx,
    input [`PRF_LEN-1:0]  opb_preg_idx,
    input [`PRF_LEN-1:0]  dest_preg_idx,
	input 				  opa_ready,
	input 				  opb_ready,
	input [`XLEN-1:0]	  opa_value,
	input [`XLEN-1:0] 	  opb_value,
    input                 commit_mis_pred,
    input [`ROB_LEN-1:0]  rob_idx,
    input [`PRF_LEN-1:0]  cdb_dest_preg_idx,
    input                 cdb_broadcast_valid,
    input [`XLEN-1:0]     cdb_value,
    input  ALU_FUNC       alu_func,     // packet from id 
    input                 enable, 



    output RS_ALU_PACKET  rs_alu_packet,     // overwrite opa and opb value, if needed
    output                rs_ready_out,
    output                rs_full           // sent rs_full signal to if stage
    `ifdef DEBUG
    , output RS_FU_PACKET [`RS_SIZE-1:0] rs_packets
    , output logic [`RS_LEN:0] rs_counter
    , output logic [`RS_SIZE-1:0] rs_ex
    , output logic [`RS_SIZE-1:0] psel_gnt    
    , output logic [`RS_SIZE-1:0] rs_free
    , output logic [`RS_LEN-1:0] rs_free_idx
    , output logic [`RS_LEN-1:0] rs_ex_idx
    `endif
);

`ifndef DEBUG
RS_ALU_PACKET [`RS_SIZE-1:0] rs_packets;
logic [`RS_LEN:0] rs_counter;
logic [`RS_SIZE-1:0] rs_ex;     // goes to priority selector (data ready && FU free)
logic [`RS_SIZE-1:0] psel_gnt;  // output of the priority selector
logic [`RS_SIZE-1:0] rs_free;
logic [`RS_LEN-1:0] rs_free_idx; // the rs idx that is selected for the dispatched instr
logic [`RS_LEN-1:0] rs_ex_idx;
`endif

assign rs_full = (rs_counter == `RS_SIZE);

wan_sel psel(parameter = `RS_SIZE;)(
    .req(rs_ex);
    .gnt(psel_gnt);
) 

genvar i;
always_comb begin
    rs_free_idx = `RS_LEN'h0; // avoid additional latch, not very important
    for (i=`RS_SIZE-1; i>=0; i--) begin
        if (rs_free[i]) rs_free_idx = i;
    end
end

genvar j;
always_comb begin
    rs_ex_idx = `RS_LEN'h0; // avoid additional latching
    for (j=0; j<`RS_SIZE; j++) begin
        if (psel_gnt[j]) rs_ex_idx = j; 
    end
end

// rs_ex
genvar k;
always_comb begin
    rs_ex = `RS_SIZE'h0;
    for (k = 0; k<`RS_SIZE; k++) begin
        rs_ex[k] = (~rs_free[k])&&(rs_packets[k].opa_ready)&&(rs_packets[k].opb_ready);
    end
end

genvar t;
always_ff @(posedge clock) begin
    if (reset) begin
        rs_free      <= `SD ~`RS_SIZE'h0;
        // rs_ex        <= `SD `RS_SIZE'h0;
        rs_counter   <= `SD `RS_LEN'h0;
        rs_ready_out <= `SD 1'b0;
    end 
    else if (commit_mis_pred) begin
        rs_free      <= `SD ~`RS_SIZE'h0;
        // rs_ex        <= `SD `RS_SIZE'h0;
        rs_counter   <= `SD `RS_LEN'h0;
        rs_ready_out <= `SD 1'b0;
    end  
    else begin
        rs_counter <= `SD rs_counter + id_packet_in.valid - rs_ex[rs_ex_idx];
        // dispatch 
        if (id_packet_in.valid) begin// instr can be dispatched
            rs_packets[rs_free_idx].opa_ready <= `SD opa_ready;
            rs_packets[rs_free_idx].opb_ready <= `SD opb_ready;
            
            if (opa_ready)  rs_packets[rs_free_idx].opa_value <= `SD opa_value;
            else rs_packets[rs_free_idx].opa_value <= `SD opa_preg_idx;
            if (opb_ready)  rs_packets[rs_free_idx].opb_value <= `SD opb_value;
            else rs_packets[rs_free_idx].opb_value <= `SD opb_preg_idx;
            rs_packets[rs_free_idx].alu_func <= `SD id_packet_in.alu_func;

            rs_free[rs_free_idx] <= `SD 1'b0;
        end
        
        // issue
        if (rs_ex[rs_ex_idx]) begin
            rs_fu_packet <= `SD rs_packets[rs_ex_idx];
            rs_ready_out <= `SD 1'b1;
            rs_free[rs_ex_idx] <= `SD 1'b1;
        end
        else
            rs_ready_out <= `SD 1'b0;
        
        // cdb broadcast
        if (cdb_broadcast_valid) begin
            for (t=0; t<`RS_SIZE; t++) begin
                if (~rs_packets[t].opa_ready && (rs_packets[t].opa_value==cdb_dest_preg_idx)) begin
                    rs_packets[t].opa_ready <= `SD 1'b1;
                    rs_packets[t].opa_value <= `SD cdb_value;
                end
                if (~rs_packets[t].opb_ready && (rs_packets[t].opb_value==cdb_dest_preg_idx)) begin
                    rs_packets[t].opb_ready <= `SD 1'b1;
                    rs_packets[t].opb_value <= `SD cdb_value;
                end
            end
        end  
    end    
end




endmodule
`endif // __RS_V__