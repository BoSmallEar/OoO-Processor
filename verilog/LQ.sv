parameter LQ_CAPACITY = 8;
parameter LQ_IDX_LEN = 3;

typedef struct packed {
    logic [`XLEN-1:0] address;
    logic [LQ_IDX_LEN-1:0] age;
    logic resolved;
} LQ_ENTRY;

typedef struct packed {
    LQ_ENTRY    [LQ_IDX_LEN-1:0]   entries;
    logic       [LQ_IDX_LEN-1:0]    head;
    logic       [LQ_IDX_LEN-1:0]    tail;
} LOAD_QUEUE;

module load_queue (
    input   clock,
    input   reset,
    input   enable,  // Add an entry
    input   age,
    input                       base,
    input                       no_offset,
    input                       retire,
    // From ALU about previously unresolved SQ entry
    input   [`XLEN-1:0]         resolved_SQ_address,
    input   [SQ_IDX_LEN-1:0]    resolved_SQ_index,
    input   [SQ_IDX_LEN-1:0]    avoid_flush_gap,
    // From ALU about resolved Load address
    input   [`XLEN-1:0]         alu2LQ_addr,
    input   [LQ_IDX_LEN-1:0]    alu2LQ_idx,

    output logic full,
    output logic flush,
 
    output  logic [`XLEN-1:0]           head_load_address,
    output                              head_resolved
);
    LOAD_QUEUE LQ;
    logic [LQ_IDX_LEN-1:0]  counter;
    logic full;
    
    always_comb begin
        if(LQ.entries[LQ.head].address==resolved_SQ_address) begin
        if((LQ.entries[LQ.head].age-1)-resolved_SQ_index<avoid_flush_gap)
            flush = 1;
        else
            flush = 0;
        end
    end
   

    assign full = counter==lQ_CAPACITY;
    assign head_load_address = (counter==0)? 0: LQ.entries[LQ.head].address;
    assign head_resolved = LQ.entries[LQ.head].resolved;

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            LQ.head <= `SD 0;
            LQ.tail <= `SD 0;  //points to empty position
            counter <= `SD 0;
            for(int i=0;i<LQ_CAPACITY;i++) LQ.entries[i].resolved <= `SD 0;
        end

        if (enable) begin 
            LQ.entries[tail].age <= `SD age;
            LQ.tail <= `SD (LQ.tail == `LQ_CAPACITY-1)? 0: LQ.tail + 1;
            if (no_offset)  begin
                LQ.entries[tail].address <=`SD base;
                LQ.entries[tail].resolved <=`SD 1;
            end
        end 

        if (LQ.entries[alu2LQ_idx].resolved==0) begin
            LQ.entries[alu2LQ_idx].address <= `SD alu2LQ_addr;
            LQ.entries[alu2LQ_idx].resolved <=`SD 1;
        end

        if (retire) begin
            counter <= `SD counter - 1;
            LQ.head <= `SD (LQ.head == `LQ_CAPACITY-1)? 0: LQ.head + 1;
        end
        if (enable && ~ retire)   counter <= `SD counter + 1;
        if (~enable && retire)    counter <= `SD counter - 1;
    end

endmodule
