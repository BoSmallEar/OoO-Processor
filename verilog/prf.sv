//////////////////////////////////////////////////////////////////////////
//                                                                      //
//   Modulename :  prf.v                                                //
//                                                                      //
//  Description :  physical register file                               //
//                                                                      // 
//                                                                      //
//                                                                      //
//////////////////////////////////////////////////////////////////////////

`ifndef __PRF_V__
`define __PRF_V__

`timescale 1ns/100ps

module prf(
    input                       clock,
    input                       reset,
    input [`PRF_LEN-1:0]        opa_preg_idx, //
    input [`PRF_LEN-1:0]        opb_preg_idx, //
    input                       assign_free_reg,
    input [`PRF_LEN-1:0]        rrat_prev_reg_idx,
    input                       commit_mis_pred,
    input [`PRF_SIZE-1:0]       rrat_free_backup,  // rrat
    input [`PRF_SIZE-1:0]       rrat_valid_backup, // rrat
    input [`PRF_SIZE-1:0] [`PRF_LEN-1:0] rrat_free_preg_queue_backup;//rrat
    input                       rrat_free_preg_queue_head_backup;//rrat
    input                       rrat_free_preg_queue_tail_backup;//rrat
    input [`XLEN-1:0]           cdb_result,
    input [`PRF_LEN-1:0]        cdb_dest_preg_idx,
    input                       execution_finished,

    output logic [`PRF_LEN-1:0] prf_free_preg_idx,
    output logic                opa_ready, //
    output logic [`XLEN-1:0]    opa_value, //
    output logic                opb_ready, //
    output logic [`XLEN-1:0]    opb_value //
);

logic [`PRF_SIZE-1:0] [`XLEN-1:0]     prf_values;
logic [`PRF_SIZE-1:0]                 prf_free;
logic [`PRF_SIZE-1:0]                 prf_valid;
logic [`PRF_SIZE-1:0] [`PRF_LEN-1:0]  free_preg_queue;
logic [`PRF_LEN-1:0]                  free_preg_queue_head;
logic [`PRF_LEN-1:0]                  free_preg_queue_tail;
logic                                 free_preg_queue_full;
logic                                 free_preg_queue_empty;

assign opa_value = (execution_finished && opa_preg_idx == cdb_dest_preg_idx) ? cdb_result : prf_values[opa_preg_idx];
assign opb_value = (execution_finished && opb_preg_idx == cdb_dest_preg_idx) ? cdb_result : prf_values[opb_preg_idx];
assign opa_ready = (execution_finished && opa_preg_idx == cdb_dest_preg_idx) || prf_valid[opa_preg_idx];
assign opb_ready = (execution_finished && opb_preg_idx == cdb_dest_preg_idx) || prf_valid[opb_preg_idx];



always_ff @(posedge clock) begin
    if (reset) begin
        prf_free              <= `SD `PRF_SIZE'b1;
        prf_valid             <= `SD `PRF_SIZE'b0;
        free_preg_queue_head  <= `SD `PRF_LEN'b0;
        free_preg_queue_tail  <= `SD `PRF_LEN'b0;
        free_preg_queue_full  <= `SD 1'b0;
        free_preg_queue_empty <= `SD 1'b0;
    end
    else if (commit_mis_pred) begin
        prf_free  <= `SD rrat_free_backup;
        prf_valid <= `SD rrat_valid_backup;
        free_preg_queue <= `SD rrat_free_preg_queue_backup;
        
    end
    else begin
        if (execution_finished) begin
            prf_values[cdb_dest_preg_idx] <= cdb_result;
            prf_valid[cdb_dest_preg_idx]  <= 1'b1;
        end

    end
end

endmodule
`endif // __PRF_V__