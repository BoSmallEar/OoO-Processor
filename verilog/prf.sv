//////////////////////////////////////////////////////////////////////////
//                                                                      //
//   Modulename :  prf.v                                                //
//                                                                      //
//  Description :  physical register file                               //
//                                                                      // 
//                                                                      //
//                                                                      //
//////////////////////////////////////////////////////////////////////////
`ifndef DEBUG
`define DEBUG
`endif
`ifndef __PRF_V__
`define __PRF_V__

`timescale 1ns/100ps

module prf(
    input                       clock,
    input                       reset,
    input [`PRF_LEN-1:0]        opa_preg_idx,
    input [`PRF_LEN-1:0]        opb_preg_idx,
    input                       prf_enable,
    input [`PRF_LEN-1:0]        rrat_prev_reg_idx,
    input                       commit_mis_pred,
    input                       commit_uncond_branch,
    input [`PRF_LEN-1:0]        rob_commit_dest_preg_idx,
    input                       commit_valid,
    input [`PRF_SIZE-1:0]       rrat_free_backup,                       // rrat
    input [`PRF_SIZE-1:0]       rrat_valid_backup,                      // rrat
    input [`PRF_SIZE-1:0] [`PRF_LEN-1:0] rrat_free_preg_queue_backup,   // rrat
    input [`PRF_LEN-1:0]        rrat_free_preg_queue_head_backup,       // rrat
    input [`PRF_LEN-1:0]        rrat_free_preg_queue_tail_backup,       // rrat
    input [`XLEN-1:0]           cdb_result,
    input [`PRF_LEN-1:0]        cdb_dest_preg_idx,
    input                       cdb_broadcast_valid, 

    output logic [`PRF_LEN-1:0] prf_free_preg_idx,
    output logic                opa_ready,
    output logic [`XLEN-1:0]    opa_value,
    output logic                opb_ready,
    output logic [`XLEN-1:0]    opb_value

`ifdef DEBUG
    , output logic [`PRF_SIZE-1:0] [`XLEN-1:0]     prf_values
    , output logic [`PRF_SIZE-1:0]                 prf_free
    , output logic [`PRF_SIZE-1:0]                 prf_valid
    , output logic [`PRF_SIZE-1:0] [`PRF_LEN-1:0]  free_preg_queue
    , output logic [`PRF_LEN-1:0]                  free_preg_queue_head
    , output logic [`PRF_LEN-1:0]                  free_preg_queue_tail
`endif
);

    `ifndef DEBUG
        logic [`PRF_SIZE-1:0] [`XLEN-1:0]     prf_values;
        logic [`PRF_SIZE-1:0]                 prf_free;
        logic [`PRF_SIZE-1:0]                 prf_valid;
        logic [`PRF_SIZE-1:0] [`PRF_LEN-1:0]  free_preg_queue;
        logic [`PRF_LEN-1:0]                  free_preg_queue_head;
        logic [`PRF_LEN-1:0]                  free_preg_queue_tail;
    `endif


    // assign opa_value = (cdb_broadcast_valid && (opa_preg_idx == cdb_dest_preg_idx)) ? cdb_result : prf_values[opa_preg_idx];
    // assign opb_value = (cdb_broadcast_valid && (opb_preg_idx == cdb_dest_preg_idx)) ? cdb_result : prf_values[opb_preg_idx];
    // assign opa_ready = (cdb_broadcast_valid && (opa_preg_idx == cdb_dest_preg_idx)) || prf_valid[opa_preg_idx];
    // assign opb_ready = (cdb_broadcast_valid && (opb_preg_idx == cdb_dest_preg_idx)) || prf_valid[opb_preg_idx];
    always_comb begin
        for (int i = `PRF_SIZE-1; i>0; i--) begin
            if (prf_free[i]) prf_free_preg_idx = i;
        end
    end 
 
    assign opa_value =  (cdb_dest_preg_idx == 0) ? prf_values[opa_preg_idx] : 
                        (cdb_broadcast_valid && (opa_preg_idx == cdb_dest_preg_idx)) ? cdb_result : prf_values[opa_preg_idx];
    assign opb_value =  (cdb_dest_preg_idx == 0) ? prf_values[opb_preg_idx] : 
                        (cdb_broadcast_valid && (opb_preg_idx == cdb_dest_preg_idx)) ? cdb_result : prf_values[opb_preg_idx];
    assign opa_ready = (opa_preg_idx == 0) || (cdb_broadcast_valid && (opa_preg_idx == cdb_dest_preg_idx)) || prf_valid[opa_preg_idx]; 
    assign opb_ready = (opb_preg_idx == 0) || (cdb_broadcast_valid && (opb_preg_idx == cdb_dest_preg_idx)) || prf_valid[opb_preg_idx]; 

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            prf_free               <= `SD ~`PRF_SIZE'b1;
            prf_valid              <= `SD `PRF_SIZE'b1;
            for (int i = 0; i < `PRF_SIZE; i++) begin
                free_preg_queue[i] <= `SD i;
                prf_values[i]      <= `SD `XLEN'b0;
            end 
            free_preg_queue_head  <= `SD `PRF_LEN'b1;
            free_preg_queue_tail  <= `SD `PRF_LEN'b1; 
            
        end
        else if (commit_mis_pred) begin
            if (commit_uncond_branch) begin
                for (int i=0; i<`PRF_SIZE; i++) begin
                    if (i == rob_commit_dest_preg_idx) begin
                        prf_free[i] <= `SD 1'b0;
                        prf_valid[i] <= `SD 1'b1;
                    end
                    else if ((i == rrat_prev_reg_idx) && (rrat_prev_reg_idx != 0)) begin
                        prf_free[i] <= `SD 1'b1;
                        prf_valid[i] <= `SD 1'b0;
                    end 
                    else begin
                        prf_free[i] <= `SD rrat_free_backup[i];
                        prf_valid[i] <= `SD rrat_valid_backup[i];
                    end
                end
                free_preg_queue      <= `SD rrat_free_preg_queue_backup;
                free_preg_queue_head <= `SD rrat_free_preg_queue_head_backup;
                free_preg_queue_tail <= `SD rrat_free_preg_queue_tail_backup;
            end
            else begin
                prf_free             <= `SD rrat_free_backup;
                prf_valid            <= `SD rrat_valid_backup;
                free_preg_queue      <= `SD rrat_free_preg_queue_backup;
                free_preg_queue_head <= `SD rrat_free_preg_queue_head_backup;
                free_preg_queue_tail <= `SD rrat_free_preg_queue_tail_backup;
            end
        end
        else begin 
            if (commit_valid) begin
                // commit    
                if (rrat_prev_reg_idx != `PRF_LEN'b0) begin
                    prf_valid[rrat_prev_reg_idx]  <= `SD 1'b0;
                    prf_free[rrat_prev_reg_idx]   <= `SD 1'b1;
                    free_preg_queue[free_preg_queue_tail] <= `SD rrat_prev_reg_idx;
                    free_preg_queue_tail <= `SD free_preg_queue_tail == `PRF_SIZE-1 ? 1 : free_preg_queue_tail+1;
                end
            end
            if (prf_enable) begin
                // dispatch
                prf_free[prf_free_preg_idx] <= `SD 1'b0;
                free_preg_queue_head        <= `SD free_preg_queue_head == `PRF_SIZE-1 ? 1 : free_preg_queue_head+1;
            end
            if (cdb_broadcast_valid && cdb_dest_preg_idx!=`PRF_LEN'b0) begin
                // execution complete
                prf_values[cdb_dest_preg_idx] <= `SD cdb_result;
                prf_valid[cdb_dest_preg_idx]  <= `SD 1'b1;
            end
        end
    end

endmodule
`endif // __PRF_V__