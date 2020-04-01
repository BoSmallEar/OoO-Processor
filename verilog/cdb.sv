module cdb(
    //inputs
    input clock,
    input reset,
    input commit_mis_pred,
    /* ------------ Who is coming ? for all Execution units [To be edited]---------- */
    /* Inputs from ALU */
    input                 alu_valid,
    input [`XLEN-1:0]     alu_value,
    input [`PRF_LEN-1:0]  alu_prf_idx,
    input [`ROB_LEN-1:0]  alu_rob_idx,
    input [`XLEN-1:0]     alu_PC,

    /* Inputs from MUL */
    input                 mul_valid,
    input [`XLEN-1:0]     mul_value,
    input [`PRF_LEN-1:0]  mul_prf_idx,
    input [`ROB_LEN-1:0]  mul_rob_idx,
    input [`XLEN-1:0]     mul_PC,

    /* Inputs from Dcache */
    input                 dcache_valid,
    input [`XLEN-1:0]     dcache_value,
    input [`PRF_LEN-1:0]  dcache_prf_idx,
    input [`ROB_LEN-1:0]  dcache_rob_idx,  
    input [`XLEN-1:0]     dcache_PC,

    /* Inputs from Store Queue */
    input                 sq_valid,
    input [`XLEN-1:0]     sq_value,
    input [`PRF_LEN-1:0]  sq_prf_idx,
    input [`ROB_LEN-1:0]  sq_rob_idx,
    input [`XLEN-1:0]     sq_PC,

    /* Inputs from BRANCH */
    input [`XLEN-1:0]     br_PC,
    input                 br_valid,
    input [`PRF_LEN-1:0]  br_prf_idx,
    input [`XLEN-1:0]     br_value,
    input                 br_direction,
    input [`XLEN-1:0]     br_target_PC,
    input [`ROB_LEN-1:0]  br_rob_idx,
    input                 br_mis_pred, 
    input                 br_cond_branch,
    input                 br_uncond_branch,             
    input                 br_local_pred_direction,  // predicted by local predictor
    input                 br_global_pred_direction, // predicted by global predictor

    /* Outputs */
    output logic [4:0]           module_select,              // Whose value to broadcast
    output logic                 cdb_broadcast_valid,
    output logic [`XLEN-1:0]     cdb_broadcast_value,
    output logic [`PRF_LEN-1:0]  cdb_dest_preg_idx,
    output logic [`ROB_LEN-1:0]  cdb_rob_idx,
    
    output logic [`XLEN-1:0]     cdb_broadcast_inst_PC,

    /* Outputs for BRANCH */
    output logic                 cdb_br_direction,
    output logic [`XLEN-1:0]     cdb_br_target_PC,
    output logic                 cdb_mis_pred,
    output logic                 cdb_local_pred_direction,
    output logic                 cdb_global_pred_direction
);

    logic [3:0] cdb_req;
    logic broadcast_empty;
    logic [3:0] gnt_bus;

 

    CDB_ALU_PACKET [`ALU_QUEUE_SIZE-1:0] cdb_alu_queue; 
    CDB_MUL_PACKET [`MUL_QUEUE_SIZE-1:0] cdb_mul_queue;  
    CDB_BR_PACKET  [`BR_QUEUE_SIZE-1:0]  cdb_br_queue;
    CDB_DCACHE_PACKET  [`DCACHE_QUEUE_SIZE-1:0]  cdb_dcache_queue;  
    CDB_SQ_PACKET [`SQ_QUEUE_SIZE-1:0] cdb_sq_queue;

    logic    [`ALU_QUEUE_LEN-1:0]   cdb_alu_queue_head;
    logic    [`ALU_QUEUE_LEN-1:0]   cdb_alu_queue_tail; 
    logic                           cdb_alu_queue_empty;
    //logic    [`ALU_QUEUE_LEN-1:0]   cdb_alu_queue_counter;

    logic    [`MUL_QUEUE_LEN-1:0]   cdb_mul_queue_head;
    logic    [`MUL_QUEUE_LEN-1:0]   cdb_mul_queue_tail; 
    logic                           cdb_mul_queue_empty;
    //logic    [`MUL_QUEUE_LEN-1:0]   cdb_mul_queue_counter;
 
    logic    [`BR_QUEUE_LEN-1:0]    cdb_br_queue_head;
    logic    [`BR_QUEUE_LEN-1:0]    cdb_br_queue_tail; 
    logic                           cdb_br_queue_empty;
    //logic    [`BR_QUEUE_LEN-1:0]    cdb_br_queue_counter;

    logic    [`DCACHE_QUEUE_LEN-1:0]    cdb_dcache_queue_head;
    logic    [`DCACHE_QUEUE_LEN-1:0]    cdb_dcache_queue_tail; 
    logic                               cdb_dcache_queue_empty; 

    logic    [`SQ_QUEUE_LEN-1:0]    cdb_sq_queue_head;
    logic    [`SQ_QUEUE_LEN-1:0]    cdb_sq_queue_tail; 
    logic                           cdb_sq_queue_empty; 
    
    assign cdb_req = {alu_valid|(~cdb_alu_queue_empty) , mul_valid|(~cdb_mul_queue_empty), br_valid|(~cdb_br_queue_empty), dcache_valid|(~cdb_dcache_queue_empty), sq_valid|(~cdb_sq_queue_empty)};
    assign cdb_alu_queue_empty = cdb_alu_queue_head == cdb_alu_queue_tail;
    assign cdb_mul_queue_empty = cdb_mul_queue_head == cdb_mul_queue_tail;
    assign cdb_br_queue_empty = cdb_br_queue_head   == cdb_br_queue_tail;
    assign cdb_dcache_queue_empty = cdb_dcache_queue_head   == cdb_dcache_queue_tail;
    assign cdb_sq_queue_empty = cdb_sq_queue_head   == cdb_sq_queue_tail;
    
    
    // WIDTH is # candidates to select
    // REQ is # to select
    // example: WIDTH=3, REQ=2: req(111) -> 110 , 100 010 , 0
    psel_gen #(.WIDTH(5), .REQS(1)) psel (
        .req(cdb_req),
        .gnt(module_select),
        .gnt_bus(gnt_bus),
        .empty(broadcast_empty)
    );

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset || commit_mis_pred) begin
            cdb_broadcast_valid       <= `SD 1'b0;
            cdb_broadcast_inst_PC     <= `SD `XLEN'hfacebeec;
            cdb_mis_pred              <= `SD 1'b0;
            cdb_br_direction          <= `SD 1'b0;
            cdb_br_target_PC          <= `SD `XLEN'hfacebeec;
            cdb_local_pred_direction  <= `SD 1'b0;
            cdb_global_pred_direction <= `SD 1'b0;
            cdb_alu_queue_head        <= `SD `ALU_QUEUE_LEN'b0;
            cdb_alu_queue_tail        <= `SD `ALU_QUEUE_LEN'b0;
            cdb_mul_queue_head        <= `SD `MUL_QUEUE_LEN'b0;
            cdb_mul_queue_tail        <= `SD `MUL_QUEUE_LEN'b0;
        
            cdb_br_queue_head         <= `SD `BR_QUEUE_LEN'b0;
            cdb_br_queue_tail         <= `SD `BR_QUEUE_LEN'b0;
            cdb_dcache_queue_head         <= `SD `BR_QUEUE_LEN'b0;
            cdb_dcache_queue_tail         <= `SD `BR_QUEUE_LEN'b0;
        end
        else begin
            // results from FU, store in queue
            if (alu_valid) begin
                cdb_alu_queue[cdb_alu_queue_tail].alu_value   <= `SD alu_value;
                cdb_alu_queue[cdb_alu_queue_tail].alu_prf_idx <= `SD alu_prf_idx;
                cdb_alu_queue[cdb_alu_queue_tail].alu_rob_idx <= `SD alu_rob_idx;
                cdb_alu_queue[cdb_alu_queue_tail].alu_PC      <= `SD alu_PC;
                cdb_alu_queue_tail                            <= `SD (cdb_alu_queue_tail == `ALU_QUEUE_SIZE-1) ? 0 : cdb_alu_queue_tail + 1;
            end
            if (mul_valid) begin
                cdb_mul_queue[cdb_mul_queue_tail].mul_value   <= `SD mul_value;
                cdb_mul_queue[cdb_mul_queue_tail].mul_prf_idx <= `SD mul_prf_idx;
                cdb_mul_queue[cdb_mul_queue_tail].mul_rob_idx <= `SD mul_rob_idx;
                cdb_mul_queue[cdb_mul_queue_tail].mul_PC      <= `SD mul_PC;
                cdb_mul_queue_tail                            <= `SD (cdb_mul_queue_tail == `MUL_QUEUE_SIZE-1) ? 0 : cdb_mul_queue_tail + 1;
            end
            if (br_valid) begin 
                cdb_br_queue[cdb_br_queue_tail].br_value   <= `SD br_value;
                cdb_br_queue[cdb_br_queue_tail].br_prf_idx <= `SD br_prf_idx;
                cdb_br_queue[cdb_br_queue_tail].br_rob_idx <= `SD br_rob_idx;
                cdb_br_queue[cdb_br_queue_tail].br_PC      <= `SD br_PC;
                cdb_br_queue[cdb_br_queue_tail].br_direction        <= `SD br_direction;
                cdb_br_queue[cdb_br_queue_tail].br_target_PC        <= `SD br_target_PC;
                cdb_br_queue[cdb_br_queue_tail].br_mis_pred         <= `SD br_mis_pred;
                cdb_br_queue[cdb_br_queue_tail].br_cond_branch      <= `SD br_cond_branch;
                cdb_br_queue[cdb_br_queue_tail].br_uncond_branch    <= `SD br_uncond_branch;
                cdb_br_queue[cdb_br_queue_tail].br_local_pred_direction     <= `SD br_local_pred_direction;
                cdb_br_queue[cdb_br_queue_tail].br_global_pred_direction    <= `SD br_global_pred_direction;
                cdb_br_queue_tail                                           <= `SD (cdb_br_queue_tail == `BR_QUEUE_SIZE-1) ? 0 : cdb_br_queue_tail + 1;
            end
            if (dcache_valid) begin
                cdb_dcache_queue[cdb_dcache_queue_tail].dcache_value   <= `SD dcache_value;
                cdb_dcache_queue[cdb_dcache_queue_tail].dcache_prf_idx <= `SD dcache_prf_idx;
                cdb_dcache_queue[cdb_dcache_queue_tail].dcache_rob_idx <= `SD dcache_rob_idx;
                cdb_dcache_queue[cdb_dcache_queue_tail].dcache_PC      <= `SD dcache_PC;
                cdb_dcache_queue_tail                                  <= `SD (cdb_dcache_queue_tail == `DCACHE_QUEUE_SIZE-1) ? 0 : cdb_dcache_queue_tail + 1;
            end
            if(sq_valid) begin
                cdb_sq_queue[cdb_sq_queue_tail].sq_value     <= `SD sq_value;
                cdb_sq_queue[cdb_sq_queue_tail].sq_prf_idx   <= `SD sq_prf_idx;
                cdb_sq_queue[cdb_sq_queue_tail].sq_rob_idx   <= `SD sq_rob_idx;
                cdb_sq_queue[cdb_sq_queue_tail].sq_PC        <= `SD sq_PC;
                cdb_sq_queue_tail                            <= `SD (cdb_sq_queue_tail == `SQ_QUEUE_SIZE-1) ? 0 : cdb_sq_queue_tail + 1;
            end

            // select a result to broacast
            case(module_select)
                5'b10000: begin
                    cdb_dest_preg_idx       <= `SD cdb_alu_queue_empty ? alu_prf_idx : cdb_alu_queue[cdb_alu_queue_head].alu_prf_idx;
                    cdb_broadcast_value     <= `SD cdb_alu_queue_empty ? alu_value   : cdb_alu_queue[cdb_alu_queue_head].alu_value;
                    cdb_rob_idx             <= `SD cdb_alu_queue_empty ? alu_rob_idx : cdb_alu_queue[cdb_alu_queue_head].alu_rob_idx;
                    cdb_broadcast_inst_PC   <= `SD cdb_alu_queue_empty ? alu_PC      : cdb_alu_queue[cdb_alu_queue_head].alu_PC;
                    cdb_mis_pred            <= `SD 1'b0;
                    cdb_br_direction        <= `SD 1'b0;
                    cdb_alu_queue_head      <= `SD (cdb_alu_queue_head == `ALU_QUEUE_SIZE-1) ? 0 : cdb_alu_queue_head + 1;
                    cdb_broadcast_valid     <= `SD 1'b1;
                end
                5'b01000: begin
                    cdb_dest_preg_idx       <= `SD cdb_mul_queue_empty ? mul_prf_idx : cdb_mul_queue[cdb_mul_queue_head].mul_prf_idx;
                    cdb_broadcast_value     <= `SD cdb_mul_queue_empty ? mul_value   : cdb_mul_queue[cdb_mul_queue_head].mul_value;
                    cdb_rob_idx             <= `SD cdb_mul_queue_empty ? mul_rob_idx : cdb_mul_queue[cdb_mul_queue_head].mul_rob_idx;
                    cdb_broadcast_inst_PC   <= `SD cdb_mul_queue_empty ? mul_PC      : cdb_mul_queue[cdb_mul_queue_head].mul_PC;
                    cdb_mis_pred            <= `SD 1'b0;
                    cdb_br_direction        <= `SD 1'b0;
                    cdb_mul_queue_head      <= `SD (cdb_mul_queue_head == `MUL_QUEUE_SIZE-1) ? 0 : cdb_mul_queue_head + 1;
                    cdb_broadcast_valid     <= `SD 1'b1;
                end
                5'b00100: begin
                    cdb_dest_preg_idx         <= `SD cdb_br_queue_empty ? br_prf_idx :
                                                                          cdb_br_queue[cdb_br_queue_head].br_prf_idx;
                    cdb_broadcast_value       <= `SD cdb_br_queue_empty ? br_value :
                                                                          cdb_br_queue[cdb_br_queue_head].br_value;                                                      
                    cdb_rob_idx               <= `SD cdb_br_queue_empty ? br_rob_idx :
                                                                          cdb_br_queue[cdb_br_queue_head].br_rob_idx;
                    cdb_broadcast_inst_PC     <= `SD cdb_br_queue_empty ? br_PC :
                                                                          cdb_br_queue[cdb_br_queue_head].br_PC;
                    cdb_br_direction          <= `SD cdb_br_queue_empty ? br_direction :
                                                                          cdb_br_queue[cdb_br_queue_head].br_direction;
                    cdb_br_target_PC          <= `SD cdb_br_queue_empty ? br_target_PC : 
                                                                          cdb_br_queue[cdb_br_queue_head].br_target_PC;
                    cdb_mis_pred              <= `SD cdb_br_queue_empty ? br_mis_pred :
                                                                          cdb_br_queue[cdb_br_queue_head].br_mis_pred;
                    cdb_local_pred_direction  <= `SD cdb_br_queue_empty ? br_local_pred_direction :
                                                                          cdb_br_queue[cdb_br_queue_head].br_local_pred_direction;
                    cdb_global_pred_direction <= `SD cdb_br_queue_empty ? br_global_pred_direction :
                                                                          cdb_br_queue[cdb_br_queue_head].br_global_pred_direction;
                    cdb_br_queue_head         <= `SD (cdb_br_queue_head == `BR_QUEUE_SIZE-1) ? 0 : cdb_br_queue_head + 1;
                    cdb_broadcast_valid       <= `SD 1'b1;
                end
                5'b00010: begin
                    cdb_dest_preg_idx       <= `SD cdb_dcache_queue_empty ? dcache_prf_idx : cdb_dcache_queue[cdb_dcache_queue_head].dcache_prf_idx;
                    cdb_broadcast_value     <= `SD cdb_dcache_queue_empty ? dcache_value   : cdb_dcache_queue[cdb_dcache_queue_head].dcache_value;
                    cdb_rob_idx             <= `SD cdb_dcache_queue_empty ? dcache_rob_idx : cdb_dcache_queue[cdb_dcache_queue_head].dcache_rob_idx;
                    cdb_broadcast_inst_PC   <= `SD cdb_dcache_queue_empty ? dcache_PC      : cdb_dcache_queue[cdb_dcache_queue_head].dcache_PC;
                    cdb_mis_pred            <= `SD 1'b0;
                    cdb_br_direction        <= `SD 1'b0;
                    cdb_dcache_queue_head      <= `SD (cdb_dcache_queue_head == `DCACHE_QUEUE_SIZE-1) ? 0 : cdb_dcache_queue_head + 1;
                    cdb_broadcast_valid     <= `SD 1'b1;
                end
                5'b00001: begin
                    cdb_dest_preg_idx       <= `SD cdb_sq_queue_empty ? sq_prf_idx : cdb_sq_queue[cdb_sq_queue_head].sq_prf_idx;
                    cdb_broadcast_value     <= `SD cdb_sq_queue_empty ? sq_value   : cdb_sq_queue[cdb_sq_queue_head].sq_value;
                    cdb_rob_idx             <= `SD cdb_sq_queue_empty ? sq_rob_idx : cdb_sq_queue[cdb_sq_queue_head].sq_rob_idx;
                    cdb_broadcast_inst_PC   <= `SD cdb_sq_queue_empty ? sq_PC      : cdb_sq_queue[cdb_sq_queue_head].sq_PC;
                    cdb_mis_pred            <= `SD 1'b0;
                    cdb_br_direction        <= `SD 1'b0;
                    cdb_sq_queue_head      <= `SD (cdb_sq_queue_head == `SQ_QUEUE_SIZE-1) ? 0 : cdb_sq_queue_head + 1;
                    cdb_broadcast_valid     <= `SD 1'b1;
                end
                default: begin 
                    cdb_broadcast_inst_PC   <= `SD `XLEN'hfacebeec;
                    cdb_dest_preg_idx       <= `SD 0;
                    cdb_broadcast_value     <= `SD 0;
                    cdb_rob_idx             <= `SD 0;
                    cdb_mis_pred            <= `SD 1'b0;
                    cdb_br_direction        <= `SD 1'b0;
                    cdb_broadcast_valid     <= `SD 1'b0;
                end
            endcase 
        end

	end

endmodule