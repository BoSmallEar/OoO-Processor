//////////////////////////////////////////////////////////////////////////
//                                                                      //
//   Modulename :  rs_alu.v                                             //
//                                                                      //
//  Description :  reservation station for instrs that only             //
//                 use ALU                                              // 
//                                                                      //
//                                                                      //
//////////////////////////////////////////////////////////////////////////
`ifndef DEBUG
`define DEBUG
`endif
`ifndef __RS_ALU_V__
`define __RS_ALU_V__

`timescale 1ns/100ps

module rs_alu(
    input                 clock,
    input                 reset,
    input [`XLEN-1:0]     PC,
    input [`XLEN-1:0]     NPC,
    input                 enable,
    input [`PRF_LEN-1:0]  opa_preg_idx,
    input [`PRF_LEN-1:0]  opb_preg_idx,
	input 				  opa_ready,
	input 				  opb_ready,
	input [`XLEN-1:0]	  opa_value,
	input [`XLEN-1:0] 	  opb_value,
    input [`PRF_LEN-1:0]  dest_preg_idx,
    input [`ROB_LEN-1:0]  rob_idx,
    input  ALU_FUNC       alu_func,     // packet from id
    input                 commit_mis_pred,
    // cdb broadcast
    input                 cdb_broadcast_valid,
    input [`PRF_LEN-1:0]  cdb_dest_preg_idx, 
    input [`XLEN-1:0]     cdb_value,
 
    input                 halt,
    input                 illegal,

    output RS_ALU_PACKET  rs_alu_packet,     // overwrite opa and opb value, if needed
    output logic          rs_alu_out_valid,
    output logic          rs_alu_full           // sent rs_full signal to if stage
`ifdef DEBUG
    , output RS_ALU_PACKET [`RS_ALU_SIZE-1:0] rs_alu_packets
    , output logic [`RS_ALU_LEN:0] rs_alu_counter
    , output logic [`RS_ALU_SIZE-1:0] rs_alu_ex    // goes to priority selector (data ready && FU free) 
    , output logic [`RS_ALU_SIZE-1:0] rs_alu_free
    , output logic [`RS_ALU_LEN-1:0] rs_alu_free_idx // the rs idx that is selected for the dispatched instr
    , output logic [`RS_ALU_LEN-1:0] rs_alu_ex_idx 
`endif
);

`ifndef DEBUG
    RS_ALU_PACKET [`RS_ALU_SIZE-1:0] rs_alu_packets;
    logic [`RS_ALU_LEN:0] rs_alu_counter;
    logic [`RS_ALU_SIZE-1:0] rs_alu_ex;     // goes to priority selector (data ready && FU free)
    logic [`RS_ALU_SIZE-1:0] rs_alu_free;
    logic [`RS_ALU_LEN-1:0] rs_alu_free_idx; // the rs idx that is selected for the dispatched instr
    logic [`RS_ALU_LEN-1:0] rs_alu_ex_idx; 
`endif
    
 
    logic [`RS_ALU_SIZE-1:0] psel_gnt;  // output of the priority selector

    // 'issue' : either in the initial state (never issue a RS_MUL_PACKET)
    //           or CDB has broadcast a Mul result such that a new packet can be issued 

    assign rs_alu_full = (rs_alu_counter == `RS_ALU_SIZE);

    int i;
    always_comb begin
        rs_alu_free_idx = `RS_ALU_LEN'h0; // avoid additional latch, not very important
        for (i=`RS_ALU_SIZE-1; i>=0; i--) begin
            if (rs_alu_free[i]) rs_alu_free_idx = i;
        end
    end

    // rs_alu_ex
    int k;
    always_comb begin
        rs_alu_ex = `RS_ALU_SIZE'h0;
        for (k = 0; k<`RS_ALU_SIZE; k++) begin
            rs_alu_ex[k] = (~rs_alu_free[k])&&(rs_alu_packets[k].opa_ready)&&(rs_alu_packets[k].opb_ready);
        end
    end

    logic no_rs_selected;
    logic [`RS_ALU_SIZE-1:0] gnt_bus;
    psel_gen #(.WIDTH(`RS_ALU_SIZE), .REQS(1)) psel (
        .req(rs_alu_ex),
        .gnt(psel_gnt),
        .gnt_bus(gnt_bus),
        .empty(no_rs_selected)
    );

    int j;
    always_comb begin
        rs_alu_ex_idx = `RS_ALU_LEN'h0; // avoid additional latching
        for (j=0; j<`RS_ALU_SIZE; j++) begin
            if (psel_gnt[j]) rs_alu_ex_idx = j; 
        end
    end

    int t;
    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset || commit_mis_pred) begin
            rs_alu_free      <= `SD ~`RS_ALU_SIZE'h0;
            rs_alu_counter   <= `SD `RS_ALU_LEN'h0;
            rs_alu_out_valid <= `SD 1'b0; 
        end 
        else begin
            rs_alu_counter <= `SD rs_alu_counter + (enable&&!halt&&!illegal) - (!no_rs_selected);
            // dispatch 
            if (enable && !halt &&!illegal) begin// instr can be dispatched
                rs_alu_packets[rs_alu_free_idx].PC <= `SD PC;
                rs_alu_packets[rs_alu_free_idx].NPC <= `SD NPC;
                rs_alu_packets[rs_alu_free_idx].opa_ready <= `SD opa_ready;
                rs_alu_packets[rs_alu_free_idx].opb_ready <= `SD opb_ready;
                
                if (opa_ready)  rs_alu_packets[rs_alu_free_idx].opa_value <= `SD opa_value;
                else rs_alu_packets[rs_alu_free_idx].opa_value <= `SD opa_preg_idx;
                if (opb_ready)  rs_alu_packets[rs_alu_free_idx].opb_value <= `SD opb_value;
                else rs_alu_packets[rs_alu_free_idx].opb_value <= `SD opb_preg_idx;
                rs_alu_packets[rs_alu_free_idx].alu_func      <= `SD alu_func;
                rs_alu_packets[rs_alu_free_idx].dest_preg_idx <= `SD dest_preg_idx;
                rs_alu_packets[rs_alu_free_idx].rob_idx       <= `SD rob_idx;

                rs_alu_free[rs_alu_free_idx] <= `SD 1'b0;
            end
            
            // issue
            if (!no_rs_selected) begin
                rs_alu_packet <= `SD rs_alu_packets[rs_alu_ex_idx];
                rs_alu_out_valid <= `SD 1'b1;
                rs_alu_free[rs_alu_ex_idx] <= `SD 1'b1; 
            end
            else
                rs_alu_out_valid <= `SD 1'b0;
            
            // cdb broadcast
            if (cdb_broadcast_valid) begin
                for (t=0; t<`RS_ALU_SIZE; t++) begin
                    if (~rs_alu_packets[t].opa_ready && (rs_alu_packets[t].opa_value==cdb_dest_preg_idx)) begin
                        rs_alu_packets[t].opa_ready <= `SD 1'b1;
                        rs_alu_packets[t].opa_value <= `SD cdb_value;
                    end
                    if (~rs_alu_packets[t].opb_ready && (rs_alu_packets[t].opb_value==cdb_dest_preg_idx)) begin
                        rs_alu_packets[t].opb_ready <= `SD 1'b1;
                        rs_alu_packets[t].opb_value <= `SD cdb_value;
                    end
                end
            end  
        end    
    end

endmodule
`endif // __RS_ALU_V__
