//////////////////////////////////////////////////////////////////////////
//                                                                      //
//   Modulename :  rs_mul.v                                             //
//                                                                      //
//  Description :  reservation station for instrs that perform          //
//                 multiplication                                       // 
//                                                                      //
//                                                                      //
//////////////////////////////////////////////////////////////////////////
`ifndef DEBUG
`define DEBUG
`ifndef __RS_MUL_V__
`define __RS_MUL_V__

`timescale 1ns/100ps

module rs_mul(
    input                   clock,
    input                   reset,
    input [`XLEN-1:0]       PC,
    input [`XLEN-1:0]       NPC,
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
    // cdb broadcast
    input                   cdb_broadcast_valid,
    input [`PRF_LEN-1:0]    cdb_dest_preg_idx,
    input [`XLEN-1:0]       cdb_value, 
    // OUTPUTS
    output RS_MUL_PACKET    rs_mul_packet,        // overwrite opa and opb value, if needed
    output logic            rs_mul_out_valid,
    output logic            rs_mul_full            // sent rs_full signal to if stage     
`ifdef DEBUG
    , output RS_MUL_PACKET [`RS_MUL_SIZE-1:0] rs_mul_packets
    , output logic [`RS_MUL_LEN:0] rs_mul_counter
    , output logic [`RS_MUL_SIZE-1:0] rs_mul_ex     // goes to priority selector (data ready && FU free)
    , output logic [`RS_MUL_SIZE-1:0] rs_mul_free
    , output logic [`RS_MUL_LEN-1:0] rs_mul_free_idx // the rs idx that is selected for the dispatched instr
    , output logic [`RS_MUL_LEN-1:0] rs_mul_ex_idx
`endif           
);

    `ifndef DEBUG
    RS_MUL_PACKET [`RS_MUL_SIZE-1:0] rs_mul_packets;
    logic [`RS_MUL_LEN:0] rs_mul_counter;
    logic [`RS_MUL_SIZE-1:0] rs_mul_ex;     // goes to priority selector (data ready && FU free)
    logic [`RS_MUL_SIZE-1:0] rs_mul_free;
    logic [`RS_MUL_LEN-1:0] rs_mul_free_idx; // the rs idx that is selected for the dispatched instr
    logic [`RS_MUL_LEN-1:0] rs_mul_ex_idx;
    `endif

    
    logic [`RS_MUL_SIZE-1:0] psel_gnt;  // output of the priority selector 

    // 'issue' : either in the initial state (never issue a RS_MUL_PACKET)
    //           or CDB has broadcast a Mul result such that a new packet can be issued 

    assign rs_mul_full = (rs_mul_counter == `RS_MUL_SIZE);

    // find out the smallest index that corresponds to a free rs entry
    int i;
    always_comb begin
        rs_mul_free_idx = `RS_MUL_LEN'h0; // avoid additional latch, not very important
        for (i=`RS_MUL_SIZE-1; i>=0; i--) begin
            if (rs_mul_free[i]) rs_mul_free_idx = i;
        end
    end

    // generate the status of each rs entry, find out those that are waken up
    int k;
    always_comb begin
        rs_mul_ex = `RS_MUL_SIZE'h0;
        for (k = 0; k<`RS_MUL_SIZE; k++) begin
            rs_mul_ex[k] = (~rs_mul_free[k])&&(rs_mul_packets[k].opa_ready)&&(rs_mul_packets[k].opb_ready);
        end
    end

    // priority selector
    logic no_rs_selected;
    logic [`RS_MUL_SIZE-1:0] gnt_bus;
    psel_gen #(.WIDTH(`RS_MUL_SIZE), .REQS(1)) psel (
        .req(rs_mul_ex),
        .gnt(psel_gnt),
        .gnt_bus(gnt_bus),
        .empty(no_rs_selected)
    );

    // find out the rs entry that is selected to execute
    int j;
    always_comb begin
        rs_mul_ex_idx = `RS_MUL_LEN'h0; // avoid additional latching
        for (j=0; j<`RS_MUL_SIZE; j++) begin
            if (psel_gnt[j]) rs_mul_ex_idx = j; 
        end
    end

    int t;
    always_ff @(posedge clock) begin
        if (reset || commit_mis_pred) begin
            rs_mul_free      <= `SD ~`RS_MUL_SIZE'h0;
            rs_mul_counter   <= `SD `RS_MUL_LEN'h0;
            rs_mul_out_valid <= `SD 1'b0; 
        end 
        else begin
            rs_mul_counter <= `SD rs_mul_counter + enable - (!no_rs_selected);
            // dispatch 
            if (enable) begin// instr can be dispatched
                rs_mul_packets[rs_mul_free_idx].PC       <= `SD PC;
                rs_mul_packets[rs_mul_free_idx].NPC      <= `SD NPC;
                rs_mul_packets[rs_mul_free_idx].opa_ready <= `SD opa_ready;
                rs_mul_packets[rs_mul_free_idx].opb_ready <= `SD opb_ready;
                
                if (opa_ready)  rs_mul_packets[rs_mul_free_idx].opa_value  <= `SD opa_value;
                else rs_mul_packets[rs_mul_free_idx].opa_value             <= `SD opa_preg_idx;
                if (opb_ready)  rs_mul_packets[rs_mul_free_idx].opb_value  <= `SD opb_value;
                else rs_mul_packets[rs_mul_free_idx].opb_value             <= `SD opb_preg_idx;
                rs_mul_packets[rs_mul_free_idx].dest_preg_idx              <= `SD dest_preg_idx;
                rs_mul_packets[rs_mul_free_idx].rob_idx                    <= `SD rob_idx;
                rs_mul_packets[rs_mul_free_idx].mul_func                   <= `SD mul_func;

                rs_mul_free[rs_mul_free_idx] <= `SD 1'b0;
            end
            
            // issue
            if (!no_rs_selected) begin
                rs_mul_packet <= `SD rs_mul_packets[rs_mul_ex_idx];
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
endmodule
`endif