typedef struct packed{
    logic [`XLEN-1:0] PC;
    logic [`XLEN-1:0] target_PC;
    logic             valid;
} BTB_PACKET;

`ifndef __BTB_V__
`define __BTB_V__
`timescale 1ns/100ps

module btb(
    //inputs
	input                   clock,                  // system clock
	input                   reset,                  // system reset
    input [`XLEN-1:0]       PC, 
    
    input                   result_taken,       // branch is actually taken or not
    input                   result_branch,   
    input   [`XLEN-1:0]     result_PC,                 // resolved branch's own PC
    input   [`XLEN-1:0]     result_target_PC,          // resolved branch target address

    //outputs
    output logic  [`XLEN-1:0]   btb_target_PC,
    output logic                btb_taken
    
);


    parameter branch_offset_pow = 256;

    BTB_PACKET [branch_offset_pow-1:0] btb_packets;


    assign btb_taken = btb_packets[PC[9:2]].valid &&  (btb_packets[PC[9:2]].PC == PC);
    assign btb_target_PC = btb_taken ? btb_packets[PC[9:2]].target_PC : PC + 4;

    always_ff @(posedge clock) begin
        if (reset) begin
            int i;
            for (i=0; i<branch_offset_pow; i++) begin
                btb_packets[i].valid <= `SD 1'b0;
            end
        end

        else if (result_branch && result_taken) begin
            btb_packets[result_PC[9:2]].PC <= `SD result_PC;
            btb_packets[result_PC[9:2]].target_PC <= `SD result_target_PC;
            btb_packets[result_PC[9:2]].valid <= `SD 1'b1;
        end
    end
endmodule
`endif