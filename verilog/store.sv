typedef struct packed {            
	logic [`XLEN-1:0]       PC;                
    logic [`XLEN-1:0]       addr;
    logic [`XLEN-1:0]       data;
    logic                   rob_idx;
    logic                   rsvd;
    logic  [3:0]            store_byte; // STORE 1 BYTE / HALF WORD/ ONE WORD
} SQ_ENTRY;

typedef struct packed {
    SQ_ENTRY    [`SQ_CAPACITY-1:0]   entries;
    logic       [`SQ_LEN-1:0]        head;
    logic       [`SQ_LEN-1:0]        tail;
} STORE_QUEUE;

typedef struct packed {            
	logic [`XLEN-1:0]       PC;       
    logic [`XLEN-1:0]       forward_data;
    logic [4:0]             rd_preg;
    logic                   rob_idx;    
} FORWARD_PACKET;

typedef struct packed {            
	logic [`XLEN-1:0]       PC;                
    logic [`XLEN-1:0]       addr;
    logic [`XLEN-1:0]       data;
    logic  [3:0]            store_byte; // STORE 1 BYTE / HALF WORD/ ONE WORD
} SQ_2_SB_PACKET;

module store_queue (
    input                               clock,
    input                               reset,
    input                               sq_enable,       
    // From RS_SQ
    input                               rs_sq_out_valid,
    input                               rs_sq_packet,    
    // From load instruction
    input                               lb2sq_request_entry,
    // From rob
    input                               retire_enable,   // Store @ROB-HEAD
    // To ROB
    output  logic                       sq_head_rsvd, 
    // Out to previous stage
    output  logic                       sq_full,
    // Output to load buffer
    output  logic                       sq_empty,
    output  logic [`SQ_LEN-1:0]         sq_tail,         // Also to MEM_RS 
    output  logic [`SQ_LEN-1:0]         sq_head,
    output  logic [`SQ_LEN-1:0]         secure_age, 
    // To CDB
    output  logic                       forward_valid,
    output  FORWARD_PACKET              forward_pack,
    // To Store-Buffer -- Another Advanced Feature
    output  SQ_2_SB_PACKET              sq2sb_packet,
    // Output to D_cache
    output logic                        lb2cache_request_valid,
    output  LB_ENTRY                    lb2cache_request_entry,
);
    STORE_QUEUE                         SQ;
    logic [`SQ_LEN:0]                   counter;
    logic                               sq_full, sq_empty;
    logic                               forward_match;
    logic [`XLEN-1:0]                   forward_data;
    logic [`SQ_LEN-1:0]                 sq_tail;
    logic [`SQ_LEN-1:0]                 sq_head;

    assign sq_tail = SQ.tail;
    assign sq_head = SQ.head;
    assign sq_empty = counter==0;
    assign sq_full = counter==`SQ_CAPACITY-1; 
    // When SQ is full, TAIL won't overlap HEAD; To avoid some age problems
    
    assign sq_head_rsvd = SQ.entries[head].rsvd;
    // Compute the secure_age [sequential version of unkwn_idx]
    // That is the index of the oldest unresolved store instruction
    // Told LB secure_age to help her decide which load could be issued
    logic [`SQ_LEN-1:0]                 unkwn_idx;
    always_comb begin
        unkwn_idx = `SQ_CAPACITY-1;
        // Default is the max_index
        // Because when all addresses are resolved, we need a secure_age that's larger than any load_age
        if (SQ.head < SQ.tail || SQ.tail==0) begin
            for (int i=SQ.tail-1; i>=SQ.head;i--) begin
                if (SQ.entries[i].rsvd==0)
                        unkwn_idx = i;
            end
        end
        else begin
            for (int i=SQ.tail-1; i>=0;i--) begin
                if (SQ.entries[i].rsvd==0)
                        unkwn_idx = i;
            end
            for (int i=`SQ_CAPACITY-1; i>=SQ.head;i--) begin
                if (SQ.entries[i].rsvd==0)
                    unkwn_idx = i;
                end
            end
        end
    end

    // To handle the LB forward request
    // We should find the matching address
    // Also we need to consider such cases:
    // STORE 1 byte in the address but the load instruction loads 1 word
    // This is not a perfect match which needs overwritten in D$/Memory
    logic [`XLEN-1:0]       load_addr;
    logic [`SQ_LEN-1:0]     load_age;
    logic [`SQ_LEN-1:0]     forward_match_idx;
    always_comb begin
        load_addr = lb2sq_request_entry.addr;
        load_age = lb2sq_request_entry.age;
        forward_match = 0;
        if (sq_empty) begin
            forward_match = 0;
        end
        else if ((SQ.head < SQ.tail||SQ.tail==0)&& SQ.head<load_age) begin
            for (int i=SQ.head; i<=load_age-1; i++) begin
                if (load_addr==SQ.entries[i].addr) begin
                    forward_match = 1;
                    forward_match_idx = i;
                end
            end
        end
        else begin
            int i;    
            for (i=SQ.head; (i<`SQ_CAPACITY)&&(i<load_age); i++) begin
                if (load_addr==SQ.entries[i].addr) begin
                    forward_match = 1;
                    forward_match_idx = i;
                end
            end
            for (i=0; (i<load_age)&&(i<SQ.tail); i++) begin
                if (load_addr==SQ.entries[i].addr) begin
                    forward_match = 1;
                    forward_match_idx = i;
                end
            end
        end   
        if (forward_match) begin
            if (lb2sq_request_entry.load_byte <= SQ.entries[i].store_byte)
                forward_data = SQ.entries[i].data;
                // Need further revision
        end      
    end

    FORWARD_PACKET 4ward, forward_pack;
    always_comb begin
        if(forward_match) begin
            4ward.PC = lb2sq_request_entry.PC;
            4ward.forward_data <=`SD forward_data;
            4ward.rd_preg <=`SD lb2sq_request_entry.rd_preg;
            4ward.rob_idx <=`SD lb2sq_request_entry.rob_idx;
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            SQ.head <= `SD 0;
            SQ.tail <= `SD 0;
            counter <= `SD 0;
            for(int i=0;i<`SQ_CAPACITY;i++) begin
                SQ.entries[i].rsvd <= `SD 0;
            end 
            secure_age <=`SD 0;
            forward_valid <= `SD 0;
        end
        else begin
            secure_age <=`SD unkwn_idx;

            // To add the new instruction with unknown data and addr
            if (sq_enable) begin 
                SQ.entries[tail].rsvd <= `SD 0;
                SQ.tail <= `SD (SQ.tail == `SQ_CAPACITY-1)? 0: SQ.tail + 1;
            end 

             // To resolve address and data for the specific entry
            if (rs_sq_out_valid&&SQ.entries[rs_sq_packet.sq_idx].rsvd==0) begin
                SQ.entries[rs_sq_packet.sq_idx].rsvd <=`SD 1;
                SQ.entries[rs_sq_packet.sq_idx].addr <= `SD rs_sq_packet.base_value + rs_sq_packet.offset;
                SQ.entries[rs_sq_packet.sq_idx].data <= `SD rs_sq_packet.src_value;
                SQ.entries[rs_sq_packet.sq_idx].rob_idx <= `SD rs_sq_packet.rob_idx;
                SQ.entries[rs_sq_packet.sq_idx].PC <= `SD rs_sq_packet.PC;
            end

            if (retire_enable&&SQ.entries[head].rsvd) begin     
                // Retire SQ head and transfer it to Post-Retirement STORE Buffer
                // When Store Buffer is non-empty, it sends packet to D$
                // D$ will send store buffer packet to Memory when it is not busy
                // Don't need to wait for D$ to finish this store to retire
                // But when forwarding, load has to check STORE BUFFER TOO
                sq2sb_packet.PC  <=`SD SQ.entries[head].PC; 
                sq2sb_packet.addr  <=`SD SQ.entries[head].addr; 
                sq2sb_packet.data  <=`SD SQ.entries[head].data; 
                sq2sb_packet.store_byte  <=`SD SQ.entries[head].store_byte;                
                // Retire the head
                SQ.entries[head].rsvd <=`SD 0;
                SQ.head <= `SD (SQ.head == `SQ_CAPACITY-1)? 0: SQ.head + 1;
            end

            if (sq_enable && ~ Dcache2SQ_response)   counter <= `SD counter + 1;
            if (~sq_enable && Dcache2SQ_response)    counter <= `SD counter - 1;
            
            if (forward_match) begin
                forward_valid <= `SD 1;
                lb2cache_request_valid <= `SD 0;
                forward_pack <= `SD 4ward;
            end
            else begin
                forward_valid <= `SD 0;
                lb2cache_request_valid <= `SD 1;
                lb2cache_request_entry <=`SD lb2sq_request_entry;
            end

            if (lb2cache_request_entry ==`SD lb2sq_request_entry)
                lb2cache_request_valid <= `SD 0;
        end    
    end

endmodule
