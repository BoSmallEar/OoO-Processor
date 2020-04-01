//////////////////////////////////////////////////////////////////////////
//                                                                      //
//   Modulename :  rs_lb.v                                             //
//                                                                      //
//  Description :  reservation station for memory                       //
//                                                                      // 
//                                                                      //
//                                                                      //
//////////////////////////////////////////////////////////////////////////

`ifndef DEBUG
`define DEBUG    
`endif

`ifndef __RS_LB_V__
`define __RS_LB_V__

`timescale 1ns/100ps

module rs_lb(
    input                                       clock,
    input                                       reset,
    input [`XLEN-1:0]                           PC,
    input [`XLEN-1:0]                           NPC,
    input                                       enable,
    // from ID_PACKET
    input [`PRF_LEN-1:0]                        base_preg_idx,
	input 				                        base_ready,
	input [`XLEN-1:0]	                        base_value,
    input [`XLEN-1:0]                           offset,
    input [`PRF_LEN-1:0]                        dest_preg_idx,
    input MEM_SIZE                              mem_size,
    input                                       load_signed,

    input                                       commit_mis_pred,
    input [`ROB_LEN-1:0]                        rob_idx,
    input [`LB_LEN-1:0]                         lb_idx,
    input [`PRF_LEN-1:0]                        cdb_dest_preg_idx,
    input                                       cdb_broadcast_valid,
    input [`XLEN-1:0]                           cdb_value,

    output RS_LB_PACKET                         rs_lb_packet,     // overwrite base value, if needed
    output logic                                rs_lb_out_valid,
    output logic                                rs_lb_full           // sent rs_lb_full signal to if stage
    `ifdef DEBUG
        , output RS_LB_PACKET [`RS_LB_SIZE-1:0]     rs_lb_packets
        , output logic [`RS_LB_LEN:0]               rs_lb_counter
        , output logic [`RS_LB_SIZE-1:0]            rs_lb_ex     // goes to priority selector (data ready && FU free)
        , output logic [`RS_LB_SIZE-1:0]            rs_lb_free
        , output logic [`RS_LB_LEN-1:0]             rs_lb_free_idx // the rs idx that is selected for the dispatched instr
        , output logic [`RS_LB_LEN-1:0]             rs_lb_ex_idx
    `endif
);

    `ifndef DEBUG
        RS_LB_PACKET [`RS_LB_SIZE-1:0] rs_lb_packets;
        logic [`RS_LB_LEN:0] rs_lb_counter;
        logic [`RS_LB_SIZE-1:0] rs_lb_ex;     // goes to priority selector (data ready && FU free)
        logic [`RS_LB_SIZE-1:0] rs_lb_free;
        logic [`RS_LB_LEN-1:0] rs_lb_free_idx; // the rs idx that is selected for the dispatched instr
        logic [`RS_LB_LEN-1:0] rs_lb_ex_idx;
    `endif
    
    logic [`RS_LB_SIZE-1:0] psel_gnt;  // output of the priority selector 
    assign rs_lb_full = (rs_lb_counter == `RS_LB_SIZE);

    int i;
    always_comb begin
        rs_lb_free_idx = `RS_LB_LEN'h0; // avoid additional latch, not very important
        for (i=`RS_LB_SIZE-1; i>=0; i--) begin
            if (rs_lb_free[i]) rs_lb_free_idx = i;
        end
    end

    // rs_lb_ex
    int k;
    always_comb begin
        rs_lb_ex = `RS_LB_SIZE'h0;
        for (k = 0; k<`RS_LB_SIZE; k++) begin
            rs_lb_ex[k] = (~rs_lb_free[k])&&(rs_lb_packets[k].base_ready);
        end
    end

    logic no_rs_selected;
    logic [`RS_LB_SIZE-1:0] gnt_bus;
    psel_gen #(.WIDTH(`RS_LB_SIZE), .REQS(1)) psel (
        .req(rs_lb_ex),
        .gnt(psel_gnt),
        .gnt_bus(gnt_bus),
        .empty(no_rs_selected)
    );

    int j;
    always_comb begin
        rs_lb_ex_idx = `RS_LB_LEN'h0; // avoid additional latching
        for (j=0; j<`RS_LB_SIZE; j++) begin
            if (psel_gnt[j]) rs_lb_ex_idx = j; 
        end
    end

    int t;
    always_ff @(posedge clock) begin
        if (reset || commit_mis_pred) begin
            rs_lb_free      <= `SD ~`RS_LB_SIZE'h0;
            rs_lb_counter   <= `SD `RS_LB_LEN'h0;
            rs_lb_out_valid <= `SD 1'b0; 
        end 
        else begin
            rs_lb_counter <= `SD rs_lb_counter + enable - (!no_rs_selected);
            // dispatch 
            if (enable) begin// instr can be dispatched
                rs_lb_packets[rs_lb_free_idx].NPC               <= `SD NPC;
                rs_lb_packets[rs_lb_free_idx].PC                <= `SD PC;
                rs_lb_packets[rs_lb_free_idx].base_ready        <= `SD base_ready;
                rs_lb_packets[rs_lb_free_idx].base_value        <= `SD base_ready ? base_value : base_preg_idx; 
                rs_lb_packets[rs_lb_free_idx].offset            <= `SD offset;
                rs_lb_packets[rs_lb_free_idx].lb_idx            <= `SD lb_idx;
                rs_lb_packets[rs_lb_free_idx].dest_preg_idx     <= `SD dest_preg_idx;
                rs_lb_packets[rs_lb_free_idx].rob_idx           <= `SD rob_idx;
                rs_lb_packets[rs_lb_free_idx].mem_size          <= `SD mem_size;
                rs_lb_packets[rs_lb_free_idx].load_signed       <= `SD load_signed;

                rs_lb_free[rs_lb_free_idx]                      <= `SD 1'b0;
            end
            
            // issue
            if (!no_rs_selected) begin
                rs_lb_packet <= `SD rs_lb_packets[rs_lb_ex_idx];
                rs_lb_out_valid <= `SD 1'b1;
                rs_lb_free[rs_lb_ex_idx] <= `SD 1'b1; 
            end
            else
                rs_lb_out_valid <= `SD 1'b0;
            
            // cdb broadcast
            if (cdb_broadcast_valid) begin
                if (!rs_lb_free[t]) begin
                    for (t=0; t<`RS_LB_SIZE; t++) begin
                        if (~rs_lb_packets[t].base_ready && (rs_lb_packets[t].base_value==cdb_dest_preg_idx)) begin
                            rs_lb_packets[t].base_ready <= `SD 1'b1;
                            rs_lb_packets[t].base_value <= `SD cdb_value;
                        end
                    end
                end
            end  
        end    
    end

endmodule
`endif // __RS_LB_V__