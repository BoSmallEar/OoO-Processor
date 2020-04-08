//////////////////////////////////////////////////////////////////////////
//                                                                      //
//   Modulename :  rs_sq.v                                             //
//                                                                      //
//  Description :  reservation station for memory                       //
//                                                                      // 
//                                                                      //
//                                                                      //
//////////////////////////////////////////////////////////////////////////
`ifndef DEBUG
`define DEBUG    
`endif

`ifndef __RS_SQ_V__
`define __RS_SQ_V__

`timescale 1ns/100ps

module rs_sq(
    input                           clock,
    input                           reset,
    input   [`XLEN-1:0]             PC,
    input   [`XLEN-1:0]             NPC,
    input                           enable,
    // From ID_PACKET
    input   [`PRF_LEN-1:0]          base_preg_idx,
    input   [`PRF_LEN-1:0]          src_preg_idx,
    input   [`XLEN-1:0]             offset,
    input   MEM_SIZE                mem_size,
    // From PRF or CDB
	input 				            base_ready,
	input   [`XLEN-1:0]        	    base_value,
	input 				            src_ready,
	input   [`XLEN-1:0]         	src_value,

    input                           commit_mis_pred,
    input   [`ROB_LEN-1:0]          rob_idx,
    input   [`SQ_LEN-1:0]           sq_idx,
    input                           sq_full,
    input   [`PRF_LEN-1:0]          cdb_dest_preg_idx,
    input                           cdb_broadcast_valid,
    input   [`XLEN-1:0]             cdb_value,

    output RS_SQ_PACKET             rs_sq_packet,     // overwrite base and src value, if needed
    output  logic                        rs_sq_out_valid,
    output  logic                        rs_sq_full       // sent rs_sq_full signal to if stage

    `ifdef DEBUG
        , output RS_SQ_PACKET [`RS_SQ_SIZE-1:0] rs_sq_packets
        , output logic [`RS_SQ_LEN:0] rs_sq_counter
        , output logic [`RS_SQ_SIZE-1:0] rs_sq_ex     // goes to priority selector (data ready && FU free)
        , output logic [`RS_SQ_SIZE-1:0] rs_sq_free
        , output logic [`RS_SQ_LEN-1:0] rs_sq_free_idx // the rs idx that is selected for the dispatched instr
        , output logic [`RS_SQ_LEN-1:0] rs_sq_ex_idx
    `endif
);

    `ifndef DEBUG
        RS_SQ_PACKET [`RS_SQ_SIZE-1:0] rs_sq_packets;
        logic [`RS_SQ_LEN:0] rs_sq_counter;
        logic [`RS_SQ_SIZE-1:0] rs_sq_ex;     // goes to priority selector (data ready && FU free)
        logic [`RS_SQ_SIZE-1:0] rs_sq_free;
        logic [`RS_SQ_LEN-1:0] rs_sq_free_idx; // the rs idx that is selected for the dispatched instr
        logic [`RS_SQ_LEN-1:0] rs_sq_ex_idx;
    `endif
    
        logic [`RS_SQ_SIZE-1:0] psel_gnt;  // output of the priority selector 


    int i;
    always_comb begin
        rs_sq_free_idx = `RS_SQ_LEN'h0; // avoid additional latch, not very important
        for (i=`RS_SQ_SIZE-1; i>=0; i--) begin
            if (rs_sq_free[i]) rs_sq_free_idx = i;
        end
    end

    // rs_sq_ex
    int k;
    always_comb begin
        rs_sq_ex = `RS_SQ_SIZE'h0;
        for (k = 0; k<`RS_SQ_SIZE; k++) begin
            rs_sq_ex[k] = (~rs_sq_free[k])&&(rs_sq_packets[k].base_ready)&&(rs_sq_packets[k].src_ready) && (~sq_full);
        end
    end

    logic no_rs_selected;
    logic [`RS_SQ_SIZE-1:0] gnt_bus;
    psel_gen #(.WIDTH(`RS_SQ_SIZE), .REQS(1)) psel (
        .req(rs_sq_ex),
        .gnt(psel_gnt),
        .gnt_bus(gnt_bus),
        .empty(no_rs_selected)
    );

    int j;
    always_comb begin
        rs_sq_ex_idx = `RS_SQ_LEN'h0; // avoid additional latching
        for (j=0; j<`RS_SQ_SIZE; j++) begin
            if (psel_gnt[j]) rs_sq_ex_idx = j; 
        end
    end

    // 'issue' : either in the initial state (never issue a RS_MUL_PACKET)
    //           or CDB has broadcast a Mul result such that a new packet can be issued 

    assign rs_sq_full = (rs_sq_counter == `RS_SQ_SIZE);
    assign rs_sq_packet = rs_sq_packets[rs_sq_ex_idx];
    assign rs_sq_out_valid = !no_rs_selected;

    int t;
    always_ff @(posedge clock) begin
        if (reset || commit_mis_pred) begin
            rs_sq_free      <= `SD ~`RS_SQ_SIZE'h0;
            rs_sq_counter   <= `SD `RS_SQ_LEN'h0;
        end 
        else begin
            rs_sq_counter <= `SD rs_sq_counter + enable - (!no_rs_selected);
            // dispatch 
            if (enable) begin
                rs_sq_packets[rs_sq_free_idx].NPC           <= `SD NPC;
                rs_sq_packets[rs_sq_free_idx].PC            <= `SD PC;
                rs_sq_packets[rs_sq_free_idx].base_ready    <= `SD base_ready;
                rs_sq_packets[rs_sq_free_idx].base_value    <= `SD base_ready ? base_value : base_preg_idx; 
                rs_sq_packets[rs_sq_free_idx].offset        <= `SD offset;
                rs_sq_packets[rs_sq_free_idx].src_ready     <= `SD src_ready;
                rs_sq_packets[rs_sq_free_idx].src_value     <= `SD src_ready ? src_value : src_preg_idx; 
                rs_sq_packets[rs_sq_free_idx].sq_idx        <= `SD sq_idx; 
                rs_sq_packets[rs_sq_free_idx].rob_idx       <= `SD rob_idx;
                rs_sq_packets[rs_sq_free_idx].mem_size      <= `SD mem_size;

                rs_sq_free[rs_sq_free_idx]                  <= `SD 1'b0;
            end
            
            // issue
            if (!no_rs_selected) begin
                rs_sq_free[rs_sq_ex_idx] <= `SD 1'b1; 
            end 
            
            // cdb broadcast
            if (cdb_broadcast_valid) begin
                for (t=0; t<`RS_SQ_SIZE; t++) begin
                    if (!rs_sq_free[t]) begin
                        if (~rs_sq_packets[t].base_ready && (rs_sq_packets[t].base_value==cdb_dest_preg_idx)) begin
                            rs_sq_packets[t].base_ready <= `SD 1'b1;
                            rs_sq_packets[t].base_value <= `SD cdb_value;
                        end
                        if (~rs_sq_packets[t].src_ready && (rs_sq_packets[t].src_value==cdb_dest_preg_idx)) begin
                            rs_sq_packets[t].src_ready <= `SD 1'b1;
                            rs_sq_packets[t].src_value <= `SD cdb_value;
                        end
                    end
                end
            end  
        end    
    end

endmodule
`endif // __RS_SQ_V__