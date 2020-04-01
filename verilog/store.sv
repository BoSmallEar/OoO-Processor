module store_queue (
    input                               clock,
    input                               reset,
    input                               sq_enable,   
    // From RS_SQ: RS prepares the data and send the packet to fill in SQ
    input                               rs_sq_out_valid,
    input         RS_SQ_PACKET          rs_sq_packet,    
    // From load buffer: it sends an entry to SQ to ask forwarding
    input                               lb2sq_request_valid,
    input         LB_ENTRY              lb2sq_request_entry,
    // From rob
    input                               store_enable,   // Store @ROB-HEAD
    // To ROB
    output  logic                       sq_head_rsvd, 
    // Out to previous stage
    output  logic                       sq_full,
    // Output to load buffer
    output  logic                       seq_all_rsvd,
    output  logic [`SQ_LEN-1:0]         sq_tail,         // Also to MEM_RS 
    output  logic [`SQ_LEN-1:0]         sq_head,
    output  logic [`SQ_LEN-1:0]         secure_age, 
    // To CDB
    output  logic                       forward_valid,
    output  FORWARD_PACKET              forward_pack,
    // Output to D_cache
    output  logic                       lb2cache_request_valid,
    output  LB_ENTRY                    lb2cache_request_entry,
    output  logic                       sq2cache_request_valid,
    output  SQ_ENTRY                    sq2cache_request_entry
);

    STORE_QUEUE                         SQ;
    logic [`SQ_LEN-1:0]                 counter;
    logic                               sq_empty;
    logic                               forward_match;
    logic [`XLEN-1:0]                   forward_data;

    assign sq_tail = SQ.tail;
    assign sq_head = SQ.head;
    assign sq_empty = counter==0;
    assign sq_full = counter==`SQ_CAPACITY-1; 

    // When SQ is full, TAIL won't overlap HEAD; To avoid some age problems

    assign sq_head_rsvd = SQ.entries[SQ.head].rsvd;
    // Compute the secure_age [sequential version of unkwn_idx]
    // That is the index of the oldest unresolved store instruction
    // Tell LB secure_age to help her decide which load could be issued
    logic [`SQ_LEN-1:0]                 unkwn_idx;
    logic                               all_rsvd;
    always_comb begin
        unkwn_idx = `SQ_CAPACITY-1;
        all_rsvd = 1;
        // Default is the max_index
        // Because when all addresses are resolved, we need a secure_age that's larger than any load_age
        if (SQ.head < SQ.tail || SQ.tail==0) begin
            // 杰瑞: 如果SQ.tail == 0, i的初始值就不太对了吧
            // Aziu: 会wrap
            for (int i=SQ.tail-1; i>=SQ.head;i--) begin
                if (SQ.entries[i].rsvd==0) begin
                    unkwn_idx = i;
                    all_rsvd = 0;
                end
            end
        end
        else if (SQ.head > SQ.tail ) begin
            // 杰瑞: 要考虑tail == head吗
            // Aziu: empty, 这个情况下all_rsvd==1
            for (int i=SQ.tail-1; i>=0;i--) begin
                if (SQ.entries[i].rsvd==0) begin
                    unkwn_idx = i;
                    all_rsvd = 0;
                end
            end
            for (int i=`SQ_CAPACITY-1; i>=SQ.head;i--) begin
                if (SQ.entries[i].rsvd==0)
                    unkwn_idx = i;
                    all_rsvd = 0;
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
    logic MEM_SIZE          load_mem_size;
    logic [`SQ_LEN-1:0]     forward_match_idx;
    always_comb begin
        load_addr = lb2sq_request_entry.addr;
        load_age = lb2sq_request_entry.age;
        mem_size = lb2sq_request_entry.MEM_SIZE;
        if (sq_empty) begin
            forward_match = 0;
        end
        else if ((SQ.head < SQ.tail || SQ.tail == 0) && SQ.head < load_age) begin
            for (int i=SQ.head; i < load_age; i++) begin
                if (load_addr >= SQ.entries[i].addr && load_addr+1'b1<<load_mem_size<=SQ.entries + ) begin
                    forward_match = 1;
                    forward_match_idx = i;
                end
            end
        end
        else begin
            for (int i=SQ.head; (i < load_age) && (i < `SQ_CAPACITY); i++) begin
                if (load_addr == SQ.entries[i].addr) begin
                    forward_match = 1;
                    forward_match_idx = i;
                end
            end
            for (int i=0; (i < load_age) && (i < SQ.tail); i++) begin
                if (load_addr == SQ.entries[i].addr) begin
                    forward_match = 1;
                    forward_match_idx = i;
                end
            end
        end
        // don't forward if load instr needs more data
        if (forward_match) begin
            if (lb2sq_request_entry.mem_size <= SQ.entries[forward_match_idx].mem_size) begin
                // select store data starting from least significant bit
                case (lb2sq_request_entry.mem_size) begin
                    BYTE: forward_data = lb2sq_request_entry.load_signed ? {{25{SQ.entries[forward_match_idx].data[7]}}, SQ.entries[forward_match_idx].data[6:0]}
                                                                         : {24'b0, SQ.entries[forward_match_idx].data[7:0]};
                    HALF: forward_data = lb2sq_request_entry.load_signed ? {{17{SQ.entries[forward_match_idx].data[15]}}, SQ.entries[forward_match_idx].data[14:0]};
                                                                         : {16'b0, SQ.entries[forward_match_idx].data[15:0]};
                    WORD: forward_data = SQ.entries[forward_match_idx].data;
                    default: forward_data = SQ.entries[forward_match_idx].data;
                end
            end
            else begin
                forward_match = 0;
            end
        end      
    end

    FORWARD_PACKET 4ward;
    always_comb begin
        if(forward_match) begin
            4ward.PC = lb2sq_request_entry.PC;
            4ward.forward_data = forward_data;
            4ward.rd_preg = lb2sq_request_entry.rd_preg;
            4ward.rob_idx = lb2sq_request_entry.rob_idx;
        end
    end

    // assign forward_valid          = forward_match;
    // assign forward_pack           = 4ward;
    assign sq2cache_request_valid = store_enable;
    assign sq2cache_request_entry = SQ.entries[SQ.head];
    // assign lb2cache_request_valid = forward_match ? 0     : lb2sq_request_valid;
    // assign lb2cache_request_entry = forward_match ? 4ward : lb2sq_request_entry;

    always_ff @(posedge clock) begin
        if (reset) begin
            SQ.head <= `SD 0;
            SQ.tail <= `SD 0;
            counter <= `SD 0;
            for(int i=0;i<`SQ_CAPACITY;i++) begin
                SQ.entries[i].rsvd  <= `SD 0;
            end 
            secure_age              <= `SD 0;
            forward_valid           <= `SD 0;
        end
        else begin
            secure_age <= `SD unkwn_idx;

            // To add the new instruction with unknown data and addr
            if (sq_enable) begin 
                SQ.entries[SQ.tail].rsvd <= `SD 0;
                SQ.tail <= `SD (SQ.tail == `SQ_CAPACITY-1)? 0: SQ.tail + 1;
            end 

             // To resolve address and data for the specific entry
            if (rs_sq_out_valid && SQ.entries[rs_sq_packet.sq_idx].rsvd == 0) begin
                SQ.entries[rs_sq_packet.sq_idx].rsvd        <= `SD 1;
                SQ.entries[rs_sq_packet.sq_idx].addr        <= `SD rs_sq_packet.base_value + rs_sq_packet.offset;
                SQ.entries[rs_sq_packet.sq_idx].data        <= `SD rs_sq_packet.src_value;
                SQ.entries[rs_sq_packet.sq_idx].rob_idx     <= `SD rs_sq_packet.rob_idx;
                SQ.entries[rs_sq_packet.sq_idx].PC          <= `SD rs_sq_packet.PC;
                SQ.entries[rs_sq_packet.sq_idx].mem_size    <= `SD rs_sq_packet.mem_size;
            end

            if (sq2cache_request_valid) begin 
                // Retire the head; Move head pointer
                SQ.entries[SQ.head].rsvd    <= `SD 0;
                SQ.head                     <= `SD (SQ.head == `SQ_CAPACITY-1) ? 0 : SQ.head + 1;
            end

            if (sq_enable && ~(store_enable && SQ.entries[SQ.head].rsvd)) counter <= `SD counter + 1;
            if (~sq_enable && (store_enable && SQ.entries[SQ.head].rsvd)) counter <= `SD counter - 1;

            if (forward_match) begin
                forward_valid           <= `SD 1;
                lb2cache_request_valid  <= `SD 0;
                forward_pack            <= `SD 4ward;
            end
            else begin
                forward_valid           <= `SD 0;
                lb2cache_request_valid  <= `SD 1;
                lb2cache_request_entry  <= `SD lb2sq_request_entry;
            end

            if (lb2cache_request_entry == `SD lb2sq_request_entry)
                lb2cache_request_valid  <= `SD 0;
            
            seq_all_rsvd <= `SD all_rsvd;
        end    
    end

endmodule
