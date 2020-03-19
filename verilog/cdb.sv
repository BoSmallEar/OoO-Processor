module cdb(
    //inputs
    input clock,
    input reset,
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

    /* Inputs from MEM */
    // input                 mem_valid,
    // input [`XLEN-1:0]     mem_value,
    // input [`PRF_LEN-1:0]  mem_prf_idx,
    // input [`ROB_LEN-1:0]  mem_rob_idx,
    // input [`XLEN-1:0]     mem_PC,

    /* Inputs from BRANCH */
    input                 br_valid,
    input                 br_direction,
    input [`XLEN-1:0]     br_target_PC,
    input [`PRF_LEN-1:0]  br_prf_idx,
    input [`ROB_LEN-1:0]  br_rob_idx,
    input                 br_mis_pred, 
    input                 br_cond_branch,
    input                 br_uncond_branch,             
    input                 br_local_pred_direction,  // predicted by local predictor
    input                 br_global_pred_direction, // predicted by global predictor
    input [`XLEN-1:0]     br_PC,

    /* Outputs */
    output logic [3:0]           module_select,              // Whose value to broadcast
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

    logic                 mem_valid;
    logic [`XLEN-1:0]     mem_value;
    logic [`PRF_LEN-1:0]  mem_prf_idx;
    logic [`ROB_LEN-1:0]  mem_rob_idx;
    logic [`XLEN-1:0]     mem_PC;
    
    assign mem_valid = 0;
    assign cdb_req = {alu_valid, mul_valid, mem_valid, br_valid};

    // WIDTH is # candidates to select
    // REQ is # to select
    // example: WIDTH=3, REQ=2: req(111) -> 110 , 100 010 , 0
    psel_gen #(.WIDTH(4), .REQS(1)) psel (
        .req(cdb_req),
        .gnt(module_select),
        .gnt_bus(gnt_bus),
        .empty(broadcast_empty)
    );

    always_ff @(posedge clock) begin
        if (reset || broadcast_empty) begin
            cdb_broadcast_valid       <= `SD 1'b0;
            cdb_broadcast_inst_PC     <= `SD `XLEN'hfacebeec;
            cdb_mis_pred              <= `SD 1'b0;
            cdb_br_target_PC          <= `SD `XLEN'hfacebeec;
            cdb_local_pred_direction  <= `SD 1'b0;
            cdb_global_pred_direction <= `SD 1'b0;
        end
        else begin
            cdb_broadcast_valid <= `SD 1'b1;
            case(module_select)
                4'b1000: begin
                    cdb_dest_preg_idx       <= `SD alu_prf_idx;
                    cdb_broadcast_value     <= `SD alu_value;
                    cdb_rob_idx             <= `SD alu_rob_idx;
                    cdb_broadcast_inst_PC   <= `SD alu_PC;
                end
                4'b0100: begin
                    cdb_dest_preg_idx       <= `SD mul_prf_idx;
                    cdb_broadcast_value     <= `SD mul_value;
                    cdb_rob_idx             <= `SD mul_rob_idx;
                    cdb_broadcast_inst_PC   <= `SD mul_PC;
                end
                4'b0010: begin 
                    cdb_dest_preg_idx       <= `SD mem_prf_idx;
                    cdb_broadcast_value     <= `SD mem_value;
                    cdb_rob_idx             <= `SD mem_rob_idx;
                    cdb_broadcast_inst_PC   <= `SD mem_PC;
                end
                4'b0001: begin 
                    cdb_broadcast_valid     <= `SD 1'b0;
                    cdb_dest_preg_idx       <= `SD br_prf_idx;
                    cdb_broadcast_value     <= `SD 0;
                    cdb_rob_idx             <= `SD br_rob_idx;
                    cdb_broadcast_inst_PC   <= `SD br_PC;
                    cdb_br_direction        <= `SD br_direction;
                    cdb_br_target_PC        <= `SD br_target_PC;
                    cdb_mis_pred            <= `SD br_mis_pred;
                    cdb_local_pred_direction  <= `SD br_local_pred_direction;
                    cdb_global_pred_direction <= `SD br_global_pred_direction;
                end
                default: begin 
                    cdb_broadcast_inst_PC   <= `SD `XLEN'hfacebeec;
                    cdb_dest_preg_idx       <= `SD 0;
                    cdb_broadcast_value     <= `SD 0;
                    cdb_rob_idx             <= `SD 0;
                end
            endcase 
        end

	end

endmodule