parameter SQ_CAPACITY = 8;
parameter SQ_IDX_LEN = 3;

typedef struct packed {
    logic [`XLEN-1:0] address;
    logic [`XLEN-1:0] value;
} SQ_ENTRY;

typedef struct packed {
    SQ_ENTRY    [SQ_CAPACITY-1:0]   entries;
    logic       [SQ_IDX_LEN-1:0]    head;
    logic       [SQ_IDX_LEN-1:0]    tail;
} STORE_QUEUE;

module store_queue (
    input                       clock,
    input                       reset,
    input                       enable,
    input   [`XLEN-1:0]         store_address,
    input   [`XLEN-1:0]         store_data,
    input   [`XLEN-1:0]         load_position,
    input   [SQ_IDX_LEN-1:0]    load_age,       // QUESTION: how to get load age from outside of sq?

    input   [3:0]               mem2SQ_response,   

    output  logic                       full,
    // Output to load instruction
    output  logic [`XLEN-1:0]           forward_data,
    output  logic                       address_match,
    output  logic [SQ_IDX_LEN-1:0]      SQ.tail,
    output  logic [SQ_IDX_LEN-1:0]      SQ.head,
    // Output to D_cache
    output  logic [`XLEN-1:0]           current_store_address,
    output  logic [`XLEN-1:0]           current_store_data
);
    STORE_QUEUE             SQ;
    logic [SQ_IDX_LEN:0]    counter;
    logic                   full;
    logic                   match;
    logic [`XLEN-1:0]       chosen_data;

    assign full = counter==SQ_CAPACITY;
    assign current_store_address = (counter==0)? 0: SQ.entries[SQ.head].address;
    assign current_store_data = (counter==0)? 0:SQ.entries[SQ.head].value;
    always_comb begin
        if (!full && SQ.head==SQ.tail) begin
            match = 0;
        end
        else if (SQ.head < SQ.tail && SQ.head < load_age) begin
            for (int i=SQ.head; i<=load_age-1; i++) begin
                if (load_position==SQ.entries[i].address) begin
                    match = 1;
                    chosen_data = SQ.entries[i].value;
                end
            end
        end
        else if (SQ.head >= SQ.tail && !(load_age<=SQ.head&&load_age>SQ.tail)) begin
            int i;
            i = (SQ_CAPACITY-1>load_age)?load_age:SQ_CAPACITY-1;        // QUESTION: === "i = load_age;"?
            for (i; i>=SQ.head; i--) begin
                if (load_position==SQ.entries[i].address) begin
                    match = 1;
                    chosen_data = SQ.entries[i].value;
                end
            end
            int j;
            j= (load_age<SQ.tail)?load_age:SQ.tail;
            for (i=0; i<=j; i++) begin
                if (load_position==SQ.entries[i].address) begin
                    match = 1;
                    chosen_data = SQ.entries[i].value;
                end
            end
        end
        else
            match = 0;
    end
    always_ff @(posedge clock) begin
        if (reset) begin
            SQ.head <= `SD 0;
            SQ.tail <= `SD 0;  //points to empty position
            counter <= `SD 0;
        end

        if (enable) begin
            SQ.entries[tail].address <= `SD store_address;
            SQ.entries[tail].value <=`SD store_data;
            SQ.tail <= `SD (SQ.tail == `SQ_CAPACITY-1)? 0: SQ.tail + 1;
        end 
        if (mem2SQ_response) begin
            SQ.head <= `SD (SQ.head == `SQ_CAPACITY-1)? 0: SQ.head + 1;
        end
        if (enable && ~ mem2SQ_response)   counter <= `SD counter + 1;
        if (~enable && mem2SQ_response)    counter <= `SD counter - 1;

        address_match <= `SD match;
        if (match)
            forward_data <=`SD chosen_data;
    end

endmodule
