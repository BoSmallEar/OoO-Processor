//////////////////////////////////////////////////////////////////////////
//                                                                      //
//   Modulename :  rob.v                                                //
//                                                                      //
//  Description :  reorder buffer                                      //
//                                                                      // 
//                                                                      //
//                                                                      //
//////////////////////////////////////////////////////////////////////////
`define DEBUG
`ifndef __ROB_V__
`define __ROB_V__

`timescale 1ns/100ps

module rob(
    input                       clock,
    input                       reset,
    input [`XLEN-1:0]           PC,
    input                       dispatch_enable,        // not only depend on rob_full, (e.g. invalid instr)
    input                       execution_finished,     // make executed_rob_entry valid
    input [4:0]                 dest_areg_idx,
    input [`PRF_LEN-1:0]        prf_free_preg_idx,
    input [`ROB_LEN-1:0]        executed_rob_entry,
    input                       cdb_mis_pred,

    output logic [4:0]          rob_commit_dest_areg_idx,
    output logic [`PRF_LEN-1:0] rob_commit_dest_preg_idx,
    output logic [`ROB_LEN-1:0] rob_tail,
    output logic                rob_full,
    output logic                commit_valid,           // tell RRAT rob_commit_dest_(p|a)reg_idx is valid
    output logic                mis_pred_is_head
    `ifdef DEBUG
        , output logic [`ROB_LEN-1:0]       rob_head
        , output logic                      rob_empty
        , output ROB_PACKET [`ROB_SIZE-1:0] rob_packets
    `endif
);
    `ifndef DEBUG
        logic [`ROB_LEN-1:0]       rob_head;
        logic                      rob_empty;
        ROB_PACKET [`ROB_SIZE-1:0] rob_packets ;
    `endif

    assign commit_valid = (rob_packets[rob_head].executed) && (~rob_empty);
    assign rob_commit_dest_areg_idx = rob_packets[rob_head].dest_areg_idx;
    assign rob_commit_dest_preg_idx = rob_packets[rob_head].dest_preg_idx;
    assign mis_pred_is_head         = rob_packets[rob_head].rob_mis_pred && commit_valid;

    always_ff @(posedge clock) begin
        if (reset) begin
            rob_head  <= `SD `ROB_LEN'b0;
            rob_tail  <= `SD `ROB_LEN'b0;
            rob_empty <= `SD 1'b1;
            rob_full  <= `SD 1'b0; 
        end
        else if (mis_pred_is_head) begin
            // mispredict
            rob_head  <= `SD rob_tail;
            rob_empty <= `SD 1'b1;
            rob_full  <= `SD 1'b0;
        end
        else begin
            rob_full  <= `SD (rob_head==rob_tail) && (~rob_empty);
            rob_empty <= `SD (rob_head==rob_tail) && (~rob_full);
            if (dispatch_enable) begin
                // dispatch
                rob_packets[rob_tail].PC            <= `SD PC;
                rob_packets[rob_tail].executed      <= `SD 1'b0;
                rob_packets[rob_tail].dest_preg_idx <= `SD prf_free_preg_idx;
                rob_packets[rob_tail].dest_areg_idx <= `SD dest_areg_idx;
                rob_packets[rob_tail].rob_mis_pred  <= `SD 1'b0;
                rob_tail                            <= `SD (rob_tail == `ROB_SIZE-1) ? 0 : rob_tail+1;
            end
            if (commit_valid) begin
                // commit
                rob_head <= `SD (rob_head == `ROB_SIZE-1) ? 0 : rob_head+1;
            end
            if (execution_finished) begin
                rob_packets[executed_rob_entry].executed     <= `SD 1'b1;
                rob_packets[executed_rob_entry].rob_mis_pred <= `SD cdb_mis_pred;
            end
        end  
    end

endmodule
`endif // `__ROB_V__