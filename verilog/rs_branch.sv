//////////////////////////////////////////////////////////////////////////
//                                                                      //
//   Modulename :  rs.v                                                 //
//                                                                      //
//   Description :  reservation station                                  //
//                                                                      //
//////////////////////////////////////////////////////////////////////////
`ifndef DEBUG
`define DEBUG
`endif
`ifndef __RS_BRANCH_V__
`define __RS_BRANCH_V__

`timescale 1ns/100ps

module rs_branch(
    input                    clock,
    input                    reset,
    input [`XLEN-1:0]        PC,
    input [`XLEN-1:0]        NPC,
    input                    enable,
    input [`PRF_LEN-1:0]     opa_preg_idx,
    input [`PRF_LEN-1:0]     opb_preg_idx,
    input 				     opa_ready,
    input [`XLEN-1:0]	     opa_value,
    input 				     opb_ready,
    input [`XLEN-1:0]	     opb_value,
    input [`XLEN-1:0]        offset,
    input                    is_jalr,
    input [`ROB_LEN-1:0]     rob_idx,
    input [`PRF_LEN-1:0]     dest_preg_idx,
    input [2:0]              branch_func,
    input                    cond_branch,
    input                    uncond_branch,
    input                    br_pred_direction,
    input [`XLEN-1:0]        br_pred_target_PC,
    input                    local_pred_direction,
    input                    global_pred_direction,
    input                    commit_mis_pred,
    // cdb broadcast
    input                    cdb_broadcast_valid,
    input [`PRF_LEN-1:0]     cdb_dest_preg_idx,
    input [`XLEN-1:0]        cdb_value,                  

    output RS_BRANCH_PACKET  rs_branch_packet,     // overwrite opa and opb value, if needed
    output logic             rs_branch_out_valid,
    output logic             rs_branch_full           // sent rs_full signal to if stage
`ifdef DEBUG
    , output RS_BRANCH_PACKET [`RS_BR_SIZE-1:0] rs_branch_packets
    , output logic [`RS_BR_LEN:0] rs_branch_counter
    , output logic [`RS_BR_SIZE-1:0] rs_branch_ex     // goes to priority selector (data ready && FU free) 
    , output logic [`RS_BR_SIZE-1:0] rs_branch_free
    , output logic [`RS_BR_LEN-1:0] rs_branch_free_idx // the rs idx that is selected for the dispatched instr
    , output logic [`RS_BR_LEN-1:0] rs_branch_ex_idx
`endif

);

    `ifndef DEBUG
    RS_BRANCH_PACKET [`RS_BR_SIZE-1:0] rs_branch_packets;
    logic [`RS_BR_LEN:0] rs_branch_counter;
    logic [`RS_BR_SIZE-1:0] rs_branch_ex;     // goes to priority selector (data ready && FU free) 
    logic [`RS_BR_SIZE-1:0] rs_branch_free;
    logic [`RS_BR_LEN-1:0] rs_branch_free_idx; // the rs idx that is selected for the dispatched instr
    logic [`RS_BR_LEN-1:0] rs_branch_ex_idx; 
    `endif

    logic [`RS_BR_SIZE-1:0] psel_gnt;  // output of the priority selector
 
    int i;
    always_comb begin
        rs_branch_free_idx = `RS_BR_LEN'h0; // avoid additional latch, not very important
        for (i=`RS_BR_SIZE-1; i>=0; i--) begin
            if (rs_branch_free[i]) rs_branch_free_idx = i;
        end
    end

    // rs_branch_ex
    int k;
    always_comb begin
        rs_branch_ex = `RS_BR_SIZE'h0;
        for (k = 0; k<`RS_BR_SIZE; k++) begin
            rs_branch_ex[k] = (~rs_branch_free[k])&&(rs_branch_packets[k].opa_ready)&&(rs_branch_packets[k].opb_ready);
        end
    end

    logic no_rs_selected;
    logic [`RS_BR_SIZE-1:0] gnt_bus;

    psel_gen #(.WIDTH(`RS_BR_SIZE), .REQS(1)) psel (
        .req(rs_branch_ex),
        .gnt(psel_gnt),
        .gnt_bus(gnt_bus),
        .empty(no_rs_selected)
    );

    int j;
    always_comb begin
        rs_branch_ex_idx = `RS_BR_LEN'h0; // avoid additional latching
        for (j=0; j<`RS_BR_SIZE; j++) begin
            if (psel_gnt[j]) rs_branch_ex_idx = j; 
        end
    end

    // 'issue' : either in the initial state (never issue a RS_MUL_PACKET)
    //           or CDB has broadcast a Mul result such that a new packet can be issued 

    assign rs_branch_full = (rs_branch_counter == `RS_BR_SIZE);
    assign rs_branch_out_valid = !no_rs_selected;
    assign rs_branch_packet = rs_branch_packets[rs_branch_ex_idx];


    int t;
    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset || commit_mis_pred) begin
            rs_branch_free      <= `SD ~`RS_BR_SIZE'h0;
            rs_branch_counter   <= `SD 0;
            rs_branch_out_valid <= `SD 1'b0;
        end 
        else begin
            rs_branch_counter <= `SD rs_branch_counter + enable - (!no_rs_selected);
            // dispatch 
            if (enable) begin// instr can be dispatched
                rs_branch_packets[rs_branch_free_idx].PC <= `SD PC;
                rs_branch_packets[rs_branch_free_idx].NPC <= `SD NPC;

                rs_branch_packets[rs_branch_free_idx].opa_ready <= `SD opa_ready;
                rs_branch_packets[rs_branch_free_idx].opb_ready <= `SD opb_ready;
                rs_branch_packets[rs_branch_free_idx].opa_value <= `SD opa_ready? opa_value : opa_preg_idx; 
                rs_branch_packets[rs_branch_free_idx].opb_value <= `SD opb_ready? opb_value : opb_preg_idx;

                rs_branch_packets[rs_branch_free_idx].rob_idx               <= `SD rob_idx;
                rs_branch_packets[rs_branch_free_idx].dest_preg_idx         <= `SD dest_preg_idx;
                rs_branch_packets[rs_branch_free_idx].offset                <= `SD offset;
                rs_branch_packets[rs_branch_free_idx].is_jalr               <= `SD is_jalr;
                rs_branch_packets[rs_branch_free_idx].branch_func           <= `SD branch_func;
                rs_branch_packets[rs_branch_free_idx].cond_branch           <= `SD cond_branch;
                rs_branch_packets[rs_branch_free_idx].uncond_branch         <= `SD uncond_branch;
                rs_branch_packets[rs_branch_free_idx].br_pred_direction     <= `SD br_pred_direction;
                rs_branch_packets[rs_branch_free_idx].br_pred_target_PC     <= `SD br_pred_target_PC;
                rs_branch_packets[rs_branch_free_idx].local_pred_direction  <= `SD local_pred_direction;
                rs_branch_packets[rs_branch_free_idx].global_pred_direction <= `SD global_pred_direction;   
                
                rs_branch_free[rs_branch_free_idx] <= `SD 1'b0;
                
            end
            
            // issue
            if (!no_rs_selected) begin
                rs_branch_free[rs_branch_ex_idx] <= `SD 1'b1; 
            end
            
            // cdb broadcast
            if (cdb_broadcast_valid) begin
                for (t=0; t<`RS_BR_SIZE; t++) begin
                    if (!rs_branch_free[t]) begin
                        if (~rs_branch_packets[t].opa_ready && (rs_branch_packets[t].opa_value==cdb_dest_preg_idx)) begin
                            rs_branch_packets[t].opa_ready <= `SD 1'b1;
                            rs_branch_packets[t].opa_value <= `SD cdb_value;
                        end
                        if (~rs_branch_packets[t].opb_ready && (rs_branch_packets[t].opb_value==cdb_dest_preg_idx)) begin
                            rs_branch_packets[t].opb_ready <= `SD 1'b1;
                            rs_branch_packets[t].opb_value <= `SD cdb_value;
                        end
                    end
                end
            end  
        end    
    end

endmodule
`endif // __RS_BRANCH_V__ 