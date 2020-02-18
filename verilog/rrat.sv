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
    input                             enable,
    input [4:0]                       rob_commit_dest_areg_idx,
    input [`PRF_LEN-1:0]              rob_commit_dest_preg_idx,

    output logic [31:0][`PRF_LEN-1:0] rat_packets_backup,
    output logic [`PRF_LEN-1:0]       rrat_prev_preg_idx,
    output logic [`PRF_SIZE-1:0]      rrat_free_backup,
    output logic ['PRF_SIZE-1:0]      rrat_valid_backup
);

    logic [31:0] [`PRF_LEN-1:0] rrat_packets;

    assign rat_packets_backup = rrat_packets;
    assign rrat_prev_preg_idx = rrat_packets[rob_commit_dest_areg_idx]; 

    always_ff @(posedge clock) begin
        if (reset) begin
            rrat_free_backup  <= `SD `PRF_SIZE'b1;
            rrat_valid_backup <= `SD `PRF_SIZE'b0;
        end
        else if (enable) begin
            rrat_packets[rob_commit_dest_areg_idx]      <= `SD rob_commit_dest_preg_idx;
            rrat_free_backup[rrat_prev_preg_idx]        <= `SD 1'b1;
            rrat_valid_backup[rrat_prev_preg_idx]       <= `SD 1'b0;
            rrat_free_backup[rob_commit_dest_preg_idx]  <= `SD 1'b0;
            rrat_valid_backup[rob_commit_dest_preg_dix] <= `SD 1'b1;
        end
    end

endmodule
`endif // __RRAT_V__