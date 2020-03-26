//////////////////////////////////////////////////////////////////////////
//                                                                      //
//   Modulename :  rs_mem.v                                             //
//                                                                      //
//  Description :  reservation station for memory                       //
//                                                                      // 
//                                                                      //
//                                                                      //
//////////////////////////////////////////////////////////////////////////
`ifndef DEBUG
`define DEBUG
`endif
`ifndef __RS_MEM_V__
`define __RS_MEM_V__

`timescale 1ns/100ps

module rs_mem(
    input                 clock,
    input                 reset,
    input [`XLEN-1:0]     PC,
    input [`XLEN-1:0]     NPC,
    input                 enable,
    input [`PRF_LEN-1:0]  opa_preg_idx,
    input [`PRF_LEN-1:0]  opb_preg_idx,
    input [`PRF_LEN-1:0]  dest_preg_idx,
	input 				  opa_ready,
	input 				  opb_ready,
	input [`XLEN-1:0]	  opa_value,
	input [`XLEN-1:0] 	  opb_value,
    input [`XLEN-1:0]     offset,
    input                 commit_mis_pred,
    input [`ROB_LEN-1:0]  rob_idx,
    input [`PRF_LEN-1:0]  cdb_dest_preg_idx,
    input                 cdb_broadcast_valid,
    input [`XLEN-1:0]     cdb_value,
    input  ALU_FUNC       mem_func,     // packet from id 

    output RS_MEM_PACKET  rs_mem_packet,     // overwrite opa and opb value, if needed
    output                rs_mem_out_valid,
    output                rs_mem_full           // sent rs_mem_full signal to if stage
`ifdef DEBUG
    , output RS_MEM_PACKET [`RS_MEM_SIZE-1:0] rs_mem_packets
    , output logic [`RS_MEM_LEN:0] rs_mem_counter
    , output logic [`RS_MEM_SIZE-1:0] rs_mem_ex     // goes to priority selector (data ready && FU free)
    , output logic [`RS_MEM_SIZE-1:0] rs_mem_free
    , output logic [`RS_MEM_LEN-1:0] rs_mem_free_idx // the rs idx that is selected for the dispatched instr
    , output logic [`RS_MEM_LEN-1:0] rs_mem_ex_idx
`endif
);

    `ifndef DEBUG
        RS_MEM_PACKET [`RS_MEM_SIZE-1:0] rs_mem_packets;
        logic [`RS_MEM_LEN:0] rs_mem_counter;
        logic [`RS_MEM_SIZE-1:0] rs_mem_ex;     // goes to priority selector (data ready && FU free)
        logic [`RS_MEM_SIZE-1:0] rs_mem_free;
        logic [`RS_MEM_LEN-1:0] rs_mem_free_idx; // the rs idx that is selected for the dispatched instr
        logic [`RS_MEM_LEN-1:0] rs_mem_ex_idx;
    `endif
    
        logic [`RS_MEM_SIZE-1:0] psel_gnt;  // output of the priority selector 

    // 'issue' : either in the initial state (never issue a RS_MUL_PACKET)
    //           or CDB has broadcast a Mul result such that a new packet can be issued 

    assign rs_mem_full = (rs_mem_counter == `RS_MEM_SIZE);

    int i;
    always_comb begin
        rs_mem_free_idx = `RS_MEM_LEN'h0; // avoid additional latch, not very important
        for (i=`RS_MEM_SIZE-1; i>=0; i--) begin
            if (rs_mem_free[i]) rs_mem_free_idx = i;
        end
    end

    // rs_mem_ex
    int k;
    always_comb begin
        rs_mem_ex = `RS_MEM_SIZE'h0;
        for (k = 0; k<`RS_MEM_SIZE; k++) begin
            rs_mem_ex[k] = (~rs_mem_free[k])&&(rs_mem_packets[k].opa_ready)&&(rs_mem_packets[k].opb_ready);
        end
    end

    logic no_rs_selected;
    logic [`RS_MEM_SIZE-1:0] gnt_bus;
    psel_gen #(.WIDTH(`RS_MEM_SIZE), .REQS(1)) psel (
        .req(rs_mem_ex),
        .gnt(psel_gnt),
        .gnt_bus(gnt_bus),
        .empty(no_rs_selected)
    );

    int j;
    always_comb begin
        rs_mem_ex_idx = `RS_MEM_LEN'h0; // avoid additional latching
        for (j=0; j<`RS_MEM_SIZE; j++) begin
            if (psel_gnt[j]) rs_mem_ex_idx = j; 
        end
    end

    int t;
    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset || commit_mis_pred) begin
            rs_mem_free      <= `SD ~`RS_MEM_SIZE'h0;
            rs_mem_counter   <= `SD 0;
            rs_mem_out_valid <= `SD 1'b0; 
        end 
        else begin
            rs_mem_counter <= `SD rs_mem_counter + enable - (!no_rs_selected);
            // dispatch 
            if (enable) begin// instr can be dispatched
                rs_mem_packets[rs_mem_free_idx].PC <= `SD PC;
                rs_mem_packets[rs_mem_free_idx].NPC <= `SD NPC;
                rs_mem_packets[rs_mem_free_idx].opa_ready <= `SD opa_ready;
                rs_mem_packets[rs_mem_free_idx].opb_ready <= `SD opb_ready;
                
                if (opa_ready)  rs_mem_packets[rs_mem_free_idx].opa_value <= `SD opa_value;
                else rs_mem_packets[rs_mem_free_idx].opa_value <= `SD opa_preg_idx;
                if (opb_ready)  rs_mem_packets[rs_mem_free_idx].opb_value <= `SD opb_value;
                else rs_mem_packets[rs_mem_free_idx].opb_value <= `SD opb_preg_idx;
                rs_mem_packets[rs_mem_free_idx].alu_func       <= `SD id_packet_in.alu_func;
                rs_mem_packets[rs_mee_free_idx].offset         <= `SD id_packet_in.offset;
                rs_mem_packets[rs_mem_free_idx].dest_preg_idx  <= `SD dest_preg_idx;
                rs_mem_packets[rs_mem_free_idx].rob_idx        <= `SD rob_idx;

                rs_mem_free[rs_mem_free_idx] <= `SD 1'b0;
            end
            
            // issue
            if (!no_rs_selected) begin
                rs_fu_packet <= `SD rs_mem_packets[rs_mem_ex_idx];
                rs_mem_out_valid <= `SD 1'b1;
                rs_mem_free[rs_mem_ex_idx] <= `SD 1'b1; 
            end
            else
                rs_mem_out_valid <= `SD 1'b0;
            
            // cdb broadcast
            if (cdb_broadcast_valid) begin
                for (t=0; t<`RS_MEM_SIZE; t++) begin
                    if (~rs_mem_packets[t].opa_ready && (rs_mem_packets[t].opa_value==cdb_dest_preg_idx)) begin
                        rs_mem_packets[t].opa_ready <= `SD 1'b1;
                        rs_mem_packets[t].opa_value <= `SD cdb_value;
                    end
                    if (~rs_mem_packets[t].opb_ready && (rs_mem_packets[t].opb_value==cdb_dest_preg_idx)) begin
                        rs_mem_packets[t].opb_ready <= `SD 1'b1;
                        rs_mem_packets[t].opb_value <= `SD cdb_value;
                    end
                end
            end  
        end    
    end

endmodule
`endif // __RS_MEM_V__