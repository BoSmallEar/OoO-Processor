//////////////////////////////////////////////////////////////////////////
//                                                                      //
//   Modulename :  rs_mul.v                                             //
//                                                                      //
//  Description :  reservation station for instrs that perform          //
//                 multiplication                                       // 
//                                                                      //
//                                                                      //
//////////////////////////////////////////////////////////////////////////

`ifndef __RS_MUL_V__
`define __RS_MUL_V__

`timescale 1ns/100ps

module rs_mul(
    input                   clock,
    input                   reset,
    input [`XLEN-1:0]       PC,
    input                   enable,
    input [`PRF_LEN-1:0]    opa_preg_idx,
    input [`PRF_LEN-1:0]    opb_preg_idx,
    input 				    opa_ready,
    input [`XLEN-1:0]	    opa_value,
    input 				    opb_ready,
    input [`XLEN-1:0]	    opb_value,
    input [`PRF_LEN-1:0]    dest_preg_idx,
    input [`ROB_LEN-1:0]    rob_idx,
    input ALU_FUNC          mul_func,
    input                   commit_mis_pred,
    input [`PRF_LEN-1:0]    cdb_dest_preg_idx,
    input                   cdb_broadcast_valid,
    input [`XLEN-1:0]       cdb_value,

    output RS_MUL_PACKET    rs_mul_packet,     // overwrite opa and opb value, if needed
    output logic            rs_mul_out_valid,
    output logic            rs_mul_full,           // sent rs_full signal to if stage                
    

    `ifdef DEBUG
        , output RS_FU_PACKET [`RS_MUL_SIZE-1:0] rs_mul_packets
        , output logic [`RS_MUL_LEN:0] rs_mul_counter
        , output logic [`RS_MUL_SIZE-1:0] rs_mul_ex
        , output logic [`RS_MUL_SIZE-1:0] psel_gnt    
        , output logic [`RS_MUL_SIZE-1:0] rs_mul_free
        , output logic [`RS_MUL_LEN-1:0] rs_mul_free_idx
        , output logic [`RS_MUL_LEN-1:0] rs_mul_ex_idx
    `endif
);

    `ifndef DEBUG
        RS_ALU_PACKET [`RS_MUL_SIZE-1:0] rs_mul_packets;
        logic [`RS_MUL_LEN:0] rs_mul_counter;
        logic [`RS_MUL_SIZE-1:0] rs_mul_ex;     // goes to priority selector (data ready && FU free)
        logic [`RS_MUL_SIZE-1:0] psel_gnt;  // output of the priority selector
        logic [`RS_MUL_SIZE-1:0] rs_mul_free;
        logic [`RS_MUL_LEN-1:0] rs_mul_free_idx; // the rs idx that is selected for the dispatched instr
        logic [`RS_MUL_LEN-1:0] rs_mul_ex_idx;
    `endif

    assign rs_full = (rs_mul_counter == `RS_MUL_SIZE);

    // priority selector
    wan_sel #(.WIDTH(`RS_ALU_SIZE)) psel (
        .req(rs_mul_ex);
        .gnt(psel_gnt);
    ) 

    // find out the smallest index that corresponds to a free rob entry
    genvar i;
    always_comb begin
        rs_mul_free_idx = `RS_MUL_LEN'h0; // avoid additional latch, not very important
        for (i=`RS_MUL_SIZE-1; i>=0; i--) begin
            if (rs_mul_free[i]) rs_mul_free_idx = i;
        end
    end
    // find out the rs entry that is selected to execute
    genvar j;
    always_comb begin
        rs_mul_ex_idx = `RS_MUL_LEN'h0; // avoid additional latching
        for (j=0; j<`RS_MUL_SIZE; j++) begin
            if (psel_gnt[j]) rs_mul_ex_idx = j; 
        end
    end

    // generate the status of each rs entry, find out those that are waken up
    genvar k;
    always_comb begin
        rs_mul_ex = `RS_MUL_SIZE'h0;
        for (k = 0; k<`RS_MUL_SIZE; k++) begin
            rs_mul_ex[k] = (~rs_mul_free[k])&&(rs_mul_packets[k].opa_ready)&&(rs_mul_packets[k].opb_ready);
        end
    end

    genvar t;
    always_ff @(posedge clock) begin
        if (reset) begin
            rs_mul_free      <= `SD ~`RS_MUL_SIZE'h0;
            // rs_mul_ex        <= `SD `RS_MUL_SIZE'h0;
            rs_mul_counter   <= `SD `RS_MUL_LEN'h0;
            rs_mul_out_valid <= `SD 1'b0;
        end 
        else if (commit_mis_pred) begin
            rs_mul_free      <= `SD ~`RS_MUL_SIZE'h0;
            // rs_mul_ex        <= `SD `RS_MUL_SIZE'h0;
            rs_mul_counter   <= `SD `RS_MUL_LEN'h0;
            rs_mul_out_valid <= `SD 1'b0;
        end  
        else begin
            rs_mul_counter <= `SD rs_mul_counter + id_packet_in.valid - rs_mul_ex[rs_mul_ex_idx];
            // dispatch 
            if (id_packet_in.valid) begin// instr can be dispatched
                rs_mul_packets[rs_mul_free_idx].opa_ready <= `SD opa_ready;
                rs_mul_packets[rs_mul_free_idx].opb_ready <= `SD opb_ready;
                
                if (opa_ready)  rs_mul_packets[rs_mul_free_idx].opa_value <= `SD opa_value;
                else rs_mul_packets[rs_mul_free_idx].opa_value <= `SD opa_preg_idx;
                if (opb_ready)  rs_mul_packets[rs_mul_free_idx].opb_value <= `SD opb_value;
                else rs_mul_packets[rs_mul_free_idx].opb_value <= `SD opb_preg_idx;
                rs_mul_packets[rs_mul_free_idx].mul_func <= `SD mul_func;

                rs_mul_free[rs_mul_free_idx] <= `SD 1'b0;
            end
            
            // issue
            if (rs_mul_ex[rs_mul_ex_idx]) begin
                rs_fu_packet <= `SD rs_mul_packets[rs_mul_ex_idx];
                rs_mul_out_valid <= `SD 1'b1;
                rs_mul_free[rs_mul_ex_idx] <= `SD 1'b1;
            end
            else
                rs_mul_out_valid <= `SD 1'b0;
            
            // cdb broadcast
            if (cdb_broadcast_valid) begin
            // broadcast values on cdb to relative RS entries
                for (t=0; t<`RS_MUL_SIZE; t++) begin
                    if (~rs_mul_packets[t].opa_ready && (rs_mul_packets[t].opa_value==cdb_dest_preg_idx)) begin
                        rs_mul_packets[t].opa_ready <= `SD 1'b1;
                        rs_mul_packets[t].opa_value <= `SD cdb_value;
                    end
                    if (~rs_mul_packets[t].opb_ready && (rs_mul_packets[t].opb_value==cdb_dest_preg_idx)) begin
                        rs_mul_packets[t].opb_ready <= `SD 1'b1;
                        rs_mul_packets[t].opb_value <= `SD cdb_value;
                    end
                end
            end  
        end    
    end
