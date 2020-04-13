`ifndef DEBUG
`define DEBUG    
`endif

`ifndef __RAS_V__
`define __RAS_V__

`define RAS_SIZE 4
`define RAS_LEN  2
`define RAS_COUNTER_LEN 3

`timescale 1ns/100ps

module ras(
    input                clock,
    input                reset,
    input [`XLEN-1:0]    jal_PC_plus_4,   // addr pushed to stack
    input                ras_push_enable, // is the dispatched inst a jal (function call) inst? 
    input                ras_pop_enable,  // is the dispatched inst a jalr (function return) inst?
    input                commit_mis_pred,
    output               read_from_ras,
    output [`XLEN-1:0]   jal_ret_addr     // addr poped from stack
);

logic [`RAS_SIZE-1:0][`XLEN-1:0] ras;         // data structure of the return address stack
logic [`RAS_LEN-1:0]             tosp;        // top of the stack pointer, points to the last filled location in the stack, points to the next addr to pop
logic [`RAS_LEN-1:0]             tosp_plus_1; // points to the empty location immediately next to the last filled location, points to the nest addr top push
logic [`RAS_LEN:0]               ras_counter; // 000: ras empty; 100: ras saturate
// logic [`XLEN-1:0]                use_when_empty_reg; // when ras becomes empty, this reg contains the last poped data (ras functions even when the stack is empty)
logic                            ras_full;
logic                            ras_empty;

assign ras_full      = ras_counter == `RAS_COUNTER_LEN'h4;
assign ras_empty     = ras_counter == `RAS_COUNTER_LEN'h0;
// assign read_from_ras = ~(ras_empty && (use_when_empty_reg == 0));
assign read_from_ras = ~ras_empty;
assign jal_ret_addr = ras[tosp];

// synopsys sync_set_reset "reset"
always_ff @(posedge clock) begin
    if (reset) begin
        // reset ras (make every entry 0)
        for (int i = 0; i < `RAS_SIZE; i++) 
            ras[i] <= `SD `XLEN'h0;
        // reset tosp: point to the last stack frame (since ras is circular)
        tosp <= `SD `RAS_LEN'b11;
        // reset tosp_plus_1: point to the first stack frame
        tosp_plus_1 <= `SD `RAS_LEN'b0;
        // reset the ras counter (to zero)
        ras_counter <= `SD `RAS_LEN'h0;
        // reset the use when empty reg (to zero)
        use_when_empty_reg <= `SD `XLEN'h0;
    end
    else if (commit_mis_pred) begin
        // reset ras (make every entry 0)
        for (int i = 0; i < `RAS_SIZE; i++) 
            ras[i] <= `SD `XLEN'h0;
        // reset tosp: point to the last stack frame (since ras is circular)
        tosp <= `SD `RAS_LEN'b11;
        // reset tosp_plus_1: point to the first stack frame
        tosp_plus_1 <= `SD `RAS_LEN'b00;
        // reset the ras counter (to zero)
        ras_counter <= `SD `RAS_COUNTER_LEN'h0;
        // reset the use when empty reg (to zero)
        use_when_empty_reg <= `SD `XLEN'h0;
    end
    else if (ras_push_enable) begin
        // store jal_PC_plus_4 to ras, if ras is full, the stack frame just get overwritten
        ras[tosp_plus_1] <= `SD jal_PC_plus_4;
        // move tosp and tosp_plus_1
        tosp <= `SD (tosp == `RAS_LEN'b11) ? `RAS_LEN'b00 : (tosp+1); // tosp <= `SD tosp_plus_1;
        tosp_plus_1 <= `SD (tosp_plus_1 == `RAS_LEN'b11) ? `RAS_LEN'b00 : (tosp_plus_1+1);
        // increment ras counter when ras is not full, keep the counter value if ras is full
        if (!ras_full)
            ras_counter <= `SD ras_counter+1;
    end 
    else if (ras_pop_enable && !ras_empty) begin
        // store the last poped address to use_when_empty_reg
        use_when_empty_reg <= `SD ras[tosp]; 
        // move tosp and tosp_plus_1
        tosp <= `SD (tosp == `RAS_LEN'b00) ? `RAS_LEN'b11 : (tosp-1);
        tosp_plus_1 <= `SD (tosp_plus_1 == `RAS_LEN'b00) ? `RAS_LEN'b00 : (tosp_plus_1-1); // tosp_plus_1 <= `SD tosp;
        // decrement ras_counter
        ras_counter <= `SD ras_counter-1;
    end
end

endmodule
`endif