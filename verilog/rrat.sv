//////////////////////////////////////////////////////////////////////////
//                                                                      //
//   Modulename :  rrat.v                                               //
//                                                                      //
//  Description :  retire register allocation table                     //
//                                                                      // 
//                                                                      //
//                                                                      //
//////////////////////////////////////////////////////////////////////////

`ifndef __RRAT_V__
`define __RRAT_V__

`timescale 1ns/100ps

module rrat(
    input                             clock,
    input                             reset,
    input                             rrat_enable,
    input [4:0]                       rob_commit_dest_areg_idx,
    input [`PRF_LEN-1:0]              rob_commit_dest_preg_idx,

    output logic [31:0][`PRF_LEN-1:0] rat_packets_backup,
    output logic [`PRF_LEN-1:0]       rrat_prev_preg_idx,
    output logic [`PRF_SIZE-1:0]      rrat_free_backup,
    output logic [`PRF_SIZE-1:0]      rrat_valid_backup,
    output logic [`PRF_SIZE-1:0] [`PRF_LEN-1:0] rrat_free_preg_queue_backup,        // rrat
    output logic [`PRF_LEN-1:0]                 rrat_free_preg_queue_head_backup,   // rrat
    output logic [`PRF_LEN-1:0]                 rrat_free_preg_queue_tail_backup    // rrat
`ifdef DEBUG
    , output logic [31:0] [`PRF_LEN-1:0]     rrat_packets 
`endif
);

`ifndef DEBUG
    logic [31:0] [`PRF_LEN-1:0] rrat_packets;
`endif

    logic [`PRF_SIZE-1:0] [`PRF_LEN-1:0]  free_preg_queue;
    logic [`PRF_LEN-1:0]                  free_preg_queue_head;
    logic [`PRF_LEN-1:0]                  free_preg_queue_tail;

    assign rat_packets_backup = rrat_packets;
    assign rrat_prev_preg_idx = rrat_packets[rob_commit_dest_areg_idx]; 

    always_ff @(posedge clock) begin
        if (reset) begin
            rrat_packets      <= `SD '{32{`PRF_LEN'b0}};
            rrat_free_backup  <= `SD ~`PRF_SIZE'b1;
            rrat_valid_backup <= `SD `PRF_SIZE'b1;
            for (int i = 0; i < `PRF_SIZE; i++) begin
                rrat_free_preg_queue_backup[i] <= `SD i;
            end 
            rrat_free_preg_queue_head_backup  <= `SD `PRF_LEN'b1;
            rrat_free_preg_queue_tail_backup  <= `SD `PRF_LEN'b1; 
        end
        else if (rrat_enable) begin
            rrat_packets[rob_commit_dest_areg_idx]      <= `SD rob_commit_dest_preg_idx;
            rrat_free_backup[rrat_prev_preg_idx]        <= `SD (rrat_prev_preg_idx == 0) ? 1'b0 : 1'b1;
            rrat_valid_backup[rrat_prev_preg_idx]       <= `SD (rrat_prev_preg_idx == 0) ? 1'b1 : 1'b0;
            rrat_free_backup[rob_commit_dest_preg_idx]  <= `SD 1'b0;
            rrat_valid_backup[rob_commit_dest_preg_idx] <= `SD 1'b1;
            if (rrat_prev_preg_idx != `PRF_LEN'b0) begin
                rrat_free_preg_queue_backup[rrat_free_preg_queue_tail_backup] <= `SD rrat_prev_preg_idx;
                rrat_free_preg_queue_tail_backup <= `SD rrat_free_preg_queue_tail_backup == `PRF_SIZE-1 ? 1 : rrat_free_preg_queue_tail_backup+1;
            end
            rrat_free_preg_queue_head_backup <= `SD rrat_free_preg_queue_head_backup == `PRF_SIZE-1 ? 1 : rrat_free_preg_queue_head_backup+1;
        end
    end

endmodule
`endif // __RRAT_V__