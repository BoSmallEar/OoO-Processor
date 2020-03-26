//////////////////////////////////////////////////////////////////////////
//                                                                      //
//   Modulename :  rob.v                                                //                                                                     //
//  Description :  reorder buffer                                       //
//                                                                      // 
//////////////////////////////////////////////////////////////////////////

`ifndef DEBUG
`define DEBUG
`endif
`ifndef __ROB_V__
`define __ROB_V__

`timescale 1ns/100ps

module rob(
    input                       clock,
    input                       reset,
    input [`XLEN-1:0]           PC,
    // dispatch
    input                       dispatch_enable,
    input                       illegal,        
    input                       halt,

    input [4:0]                 dest_areg_idx,
    input [`PRF_LEN-1:0]        dest_preg_idx,
    input                       cond_branch,
    input                       uncond_branch,
    input                       local_pred_direction,
    input                       global_pred_direction,
    // cdb broadcast
    input                       cdb_broadcast_valid,     // make executed_rob_idx valid
    input [`ROB_LEN-1:0]        executed_rob_idx,                      
    input                       cdb_br_prediction,
    input [`XLEN-1:0]           cdb_br_target_PC,
    input                       cdb_mis_pred,

    //Outputs
    output logic [4:0]          rob_commit_dest_areg_idx,
    output logic [`PRF_LEN-1:0] rob_commit_dest_preg_idx,
    output logic [`ROB_LEN-1:0] rob_tail,
    output logic                rob_full,
    output logic                commit_valid,           // tell RRAT rob_commit_dest_(p|a)reg_idx is valid
    output logic [`XLEN-1:0]    result_PC,
    output logic                result_cond_branch,
    output logic                result_uncond_branch,
    output logic [`XLEN-1:0]    result_target_PC,
    output logic                result_local_pred_direction,
    output logic                result_global_pred_direction,
    output logic                result_branch_direction,
    output logic                commit_illegal,
    output logic                commit_halt,
    output logic                mis_pred_is_head

`ifdef DEBUG
    , output ROB_PACKET [`ROB_SIZE-1:0]    rob_packets
    , output logic [`ROB_LEN-1:0]          rob_head
`endif
);

    
`ifndef DEBUG
    ROB_PACKET [`ROB_SIZE-1:0]    rob_packets;    
    logic [`ROB_LEN-1:0]          rob_head;
`endif
    logic                         rob_empty;
    logic [`ROB_LEN:0]            rob_counter;

    assign rob_empty                    = (rob_counter == 0);
    assign commit_valid                 = (rob_packets[rob_head].executed) && (~rob_empty);
    assign rob_commit_dest_areg_idx     = rob_packets[rob_head].dest_areg_idx;
    assign rob_commit_dest_preg_idx     = rob_packets[rob_head].dest_preg_idx;
    assign rob_full                     = (rob_head == rob_tail) & (rob_counter != 0);
    assign result_PC                    = rob_packets[rob_head].PC;
    assign result_cond_branch           = rob_packets[rob_head].cond_branch;
    assign result_uncond_branch         = rob_packets[rob_head].uncond_branch;
    assign result_target_PC             = rob_packets[rob_head].target_PC;
    assign result_local_pred_direction  = rob_packets[rob_head].local_pred_direction;
    assign result_global_pred_direction = rob_packets[rob_head].global_pred_direction;
    assign result_branch_direction      = rob_packets[rob_head].branch_direction;
    assign mis_pred_is_head             = rob_packets[rob_head].branch_mis_pred && commit_valid;

    assign commit_illegal               = rob_packets[rob_head].illegal && commit_valid;
    assign commit_halt                  = rob_packets[rob_head].halt && commit_valid;
    

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            rob_head    <= `SD `ROB_LEN'b0;
            rob_tail    <= `SD `ROB_LEN'b0; 
            rob_counter <= `SD `ROB_LEN'h0;
        end
        else if (mis_pred_is_head) begin
            rob_head    <= `SD rob_tail;
            rob_counter <= `SD `ROB_LEN'h0;
        end
        else begin 
            if (dispatch_enable) begin
                // dispatch
                rob_packets[rob_tail].PC                    <= `SD PC;
                rob_packets[rob_tail].executed              <= `SD (illegal||halt) ? 1'b1 : 1'b0;
                rob_packets[rob_tail].dest_preg_idx         <= `SD dest_preg_idx;
                rob_packets[rob_tail].dest_areg_idx         <= `SD dest_areg_idx;
                rob_packets[rob_tail].halt                  <= `SD halt;
                rob_packets[rob_tail].illegal               <= `SD illegal;
                rob_packets[rob_tail].cond_branch           <= `SD cond_branch;
                rob_packets[rob_tail].uncond_branch         <= `SD uncond_branch;
                rob_packets[rob_tail].target_PC             <= `SD `XLEN'hfacefeed; //come from cdb broadcast, no meaning at initialization
                rob_packets[rob_tail].local_pred_direction  <= `SD local_pred_direction;
                rob_packets[rob_tail].global_pred_direction <= `SD global_pred_direction;
                rob_packets[rob_tail].branch_direction      <= `SD 1'b0;
                rob_packets[rob_tail].branch_mis_pred       <= `SD cdb_mis_pred;
                rob_tail                                    <= `SD (rob_tail == `ROB_SIZE-1)? 0: rob_tail + 1;
            end  
            if(commit_valid) begin
                rob_head                            <= `SD (rob_head == `ROB_SIZE-1)? 0: rob_head + 1;
            end 
            if (cdb_broadcast_valid) begin
                //execute
                rob_packets[executed_rob_idx].executed         <= `SD 1'b1;
                rob_packets[executed_rob_idx].branch_direction <= `SD cdb_br_prediction;
                rob_packets[executed_rob_idx].target_PC        <= `SD cdb_br_target_PC;
                rob_packets[executed_rob_idx].branch_mis_pred  <= `SD cdb_mis_pred;
            end
            rob_counter <= `SD (dispatch_enable && ~commit_valid) ? rob_counter+1 :
                               (~dispatch_enable && commit_valid) ? rob_counter-1 : rob_counter;

        end  
    end

endmodule
`endif // `__ROB_V__

