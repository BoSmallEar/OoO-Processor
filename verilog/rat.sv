//////////////////////////////////////////////////////////////////////////
//                                                                      //
//   Modulename :  rat.v                                                //
//                                                                      //
//  Description :  register allocation table                            //
//                                                                      // 
//                                                                      //
//                                                                      //
//////////////////////////////////////////////////////////////////////////

`ifndef DEBUG
`define DEBUG
`endif
`ifndef __RAT_V__
`define __RAT_V__

`timescale 1ns/100ps

module rat(
    input                       clock,
    input                       reset,
    input                       rat_enable,
    input                       commit_mis_pred,
    input                       commit_uncond_branch,
    input [4:0]                 rob_commit_dest_areg_idx,
    input [`PRF_LEN-1:0]        rob_commit_dest_preg_idx, 
    input [4:0]                 opa_areg_idx,
    input [4:0]                 opb_areg_idx,
    input [4:0]                 dest_areg_idx,
    input [`PRF_LEN-1:0]        prf_free_preg_idx,
    input [31:0][`PRF_LEN-1:0]  rat_packets_backup,

    output logic [`PRF_LEN-1:0] opa_preg_idx,
    output logic [`PRF_LEN-1:0] opb_preg_idx
    `ifdef DEBUG
    , output logic [31:0] [`PRF_LEN-1:0]     rat_packets 
    `endif
);

    `ifndef DEBUG
    logic [31:0] [`PRF_LEN-1:0] rat_packets;
    `endif

    assign opa_preg_idx = rat_packets[opa_areg_idx];
    assign opb_preg_idx = rat_packets[opb_areg_idx];

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) 
            rat_packets      <= `SD'{32{`PRF_LEN'b0}};
        else if (commit_mis_pred) begin
            if (commit_uncond_branch) begin
                for (int i=0; i < 32; i++) begin
                    if (i == rob_commit_dest_areg_idx)
                        rat_packets[i] <= `SD rob_commit_dest_preg_idx;
                    else
                        rat_packets[i] <= `SD rat_packets_backup[i];
                end
            end
            else
                rat_packets <= `SD rat_packets_backup;
        end
        else if (rat_enable)
            rat_packets[dest_areg_idx] <= `SD prf_free_preg_idx;
    end

endmodule
`endif // __RAT_V__