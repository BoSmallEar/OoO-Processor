module predictor(
    // current instruction
	input                   clock,                  // system clock
	input                   reset,                  // system reset
	input   [`XLEN-1:0]     PC,                     // PC of branch to be predicted
    
    // resolved branch: updates on history tables
    input                   result_direction,       // branch is actually taken or not
    input                   result_enable,   
    input   [`XLEN-1:0]     result_PC,              // resolved branch target address
    input   [`XLEN-1:0]     prev_branch_PC,         // resolved branch's own PC
    
    // output
	output  logic [`XLEN-1:0]     pred_next_PC      // prediction on PC of branch
);

// tournament selector 
// 
assign pred_next_PC = PC + 4;



endmodule

/*
Predictor

Input
PC 

direction
valid
result addr

output
next PC
*/