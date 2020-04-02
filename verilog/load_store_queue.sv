`ifndef DEBUG
`define DEBUG    
`endif

`ifndef __LSQ_V__
`define __LSQ_V__

module load_store_queue(
    // load inputs
    input                                       clock,
    input                                       reset,
    input                                       lb_enable,  
    // From RS_SQ
    input                                       rs_lb_out_valid,
    input              RS_LB_PACKET             rs_lb_packet,  

    // store inputs
    input                               sq_enable,   
    // From RS_SQ: RS prepares the data and send the packet to fill in SQ
    input                               rs_sq_out_valid,
    input         RS_SQ_PACKET          rs_sq_packet,    
    // From rob
    input                               store_enable,   // Store @ROB-HEAD

    // load outputs
    // To previous stage : no space for you
    output logic                       lb_full,
    // To RS 
    output logic [`LB_LEN-1:0]         assigned_lb_idx,

    // store outputs
    // To ROB
    output logic                       sq_head_rsvd, 
    // Out to previous stage
    output logic                       sq_full,
    // To MEM_RS
    output logic [`SQ_LEN-1:0]         sq_tail,
    // To CDB
    output                             sq_valid,
    output [`XLEN-1:0]                 sq_value,
    output [`PRF_LEN-1:0]              sq_prf_idx,
    output [`ROB_LEN-1:0]              sq_rob_idx,
    output [`XLEN-1:0]                 sq_PC,
    // Output to D_cache
    output logic                       lb2cache_request_valid,
    output LB_ENTRY                    lb2cache_request_entry,
    output logic                       sq2cache_request_valid,
    output SQ_ENTRY                    sq2cache_request_entry
    `ifdef DEBUG
        , output STORE_QUEUE            SQ
        , output LOAD_BUFFER            LB
        , output logic                  sq_all_rsvd
        , output logic [`SQ_LEN-1:0]    sq_head
        , output logic [`SQ_LEN-1:0]    secure_age
        , output logic                  lb2sq_request_valid
        , output LB_ENTRY               lb2sq_request_entry
        , output logic [`SQ_LEN-1:0]    sq_counter
        , output logic                  sq_empty
        , output logic                  forward_match
        , output logic [`XLEN-1:0]      forward_data   
        , output logic [`SQ_LEN-1:0]    forward_match_idx
        , output logic [`XLEN-1:0]      forward_addr
        , output logic [`SQ_LEN-1:0]    forward_age
        , output MEM_SIZE               forward_mem_size
        , output logic                      none_selected
        , output logic [`LB_CAPACITY-1:0]   psel_gnt
        , output logic [`LB_LEN-1:0]        lq_free_idx
        , output logic                      lq_conflict
        , output logic [`LB_LEN-1:0]        lq_issue_idx
    `endif
);

    `ifndef DEBUG
        STORE_QUEUE                 SQ;
        LOAD_BUFFER                 LB;          
        // internal signals between SQ and LB
        logic                       sq_all_rsvd;
        logic [`SQ_LEN-1:0]         sq_head;
        logic [`SQ_LEN-1:0]         secure_age;
        logic                       lb2sq_request_valid;
        LB_ENTRY                    lb2sq_request_entry;
        // store combinational
        logic [`SQ_LEN-1:0]         sq_counter;
        logic                       sq_empty;
        logic                       forward_match;
        logic [`XLEN-1:0]           forward_data;
        logic [`SQ_LEN-1:0]         forward_match_idx; 
        logic [`XLEN-1:0]           forward_addr;
        logic [`SQ_LEN-1:0]         forward_age;
        MEM_SIZE                    forward_mem_size;

        //load combinational
        logic                       none_selected;
        logic [`LB_CAPACITY-1:0]    psel_gnt;
        logic [`LB_LEN-1:0]         lq_free_idx;
        logic                       lq_conflict;
        logic [`LB_LEN-1:0]         lq_issue_idx;
    `endif 
    
    logic                       all_rsvd;
    logic [`LB_CAPACITY-1:0]    gnt_bus; 
    logic [`SQ_LEN-1:0]         sq_unkwn_idx;

//////////////////////////////////////////////////////////////////////////
/////////////////////////// store combinational //////////////////////////
//////////////////////////////////////////////////////////////////////////

    assign sq_tail = SQ.tail;
    assign sq_head = SQ.head;
    assign sq_empty = sq_counter==0;
    assign sq_full = sq_counter==`SQ_CAPACITY-1; 

    // When SQ is full, TAIL won't overlap HEAD; To avoid some age problems

    assign sq_head_rsvd = SQ.entries[SQ.head].rsvd;

//////////////////////////////////////////////////////////////////////////
//////////////////////////// load combinational //////////////////////////
//////////////////////////////////////////////////////////////////////////

    assign           lb_full = LB.free_list==0;

    // Choose a free entry to put the new instruction
    always_comb begin
        lq_free_idx = `LB_LEN'h0; 
        for (int j=0; j<`LB_CAPACITY; j++) begin
            if (LB.free_list[j]==0) lq_free_idx = j; 
        end
    end

    // Choose the issue_list from the resolved LB entries
    // They should be older than oldest unresolved store instruction

    always_comb begin
        for (int j=0; j<`LB_CAPACITY; j++) begin
            lq_conflict = 0;
            if (!LB.entries[j].rsvd) 
                LB.issue_list[j] = 0; // Unresolved loads are not considered
            else begin  
                // Consider the loads older than the secure_age
                // E.g. Index 0 - store ...
                //                load (age: 1)
                //      Index 1 - store ???
                // Even if the store at index 0 retires
                // new sq_head has index 1, which is equal the forward_age 1
                // Hence we should consider forward_age geq current sq_head
                //                                   leq secure_age

                // from head to LB.entries[j].age
                if (sq_head <= LB.entries[j].age) begin
                    for (int i=sq_head; i <= LB.entries[j].age; i++) begin
                        if (!(SQ.entries[i].addr <= LB.entries[j].addr && 
                            SQ.entries[i].addr + SQ.entries[i].mem_size >= LB.entries[j].addr + LB.entries[j].mem_size)
                            && ( SQ.entries[i].addr + SQ.entries[i].mem_size>LB.entries[j].addr || LB.entries[j].addr + LB.entries[j].mem_size>SQ.entries[i].addr)) begin
                            // addr lq_conflict
                            LB.issue_list[j] = 0;
                            lq_conflict         = 1;
                        end
                    end
                end else begin
                    for (int i=sq_head; i <= `SQ_CAPACITY-1; i++) begin
                        if (!(SQ.entries[i].addr <= LB.entries[j].addr && 
                            SQ.entries[i].addr + SQ.entries[i].mem_size >= LB.entries[j].addr + LB.entries[j].mem_size)
                            && ( SQ.entries[i].addr + SQ.entries[i].mem_size>LB.entries[j].addr || LB.entries[j].addr + LB.entries[j].mem_size>SQ.entries[i].addr)) begin
                            // addr lq_conflict
                            LB.issue_list[j] = 0;
                            lq_conflict         = 1;
                        end
                    end
                    for (int i=0; i <= LB.entries[j].age; i++) begin
                        if (!(SQ.entries[i].addr <= LB.entries[j].addr && 
                            SQ.entries[i].addr + SQ.entries[i].mem_size >= LB.entries[j].addr + LB.entries[j].mem_size)
                            && ( SQ.entries[i].addr + SQ.entries[i].mem_size>LB.entries[j].addr || LB.entries[j].addr + LB.entries[j].mem_size>SQ.entries[i].addr)) begin
                            // addr lq_conflict
                            LB.issue_list[j] = 0;
                            lq_conflict         = 1;
                        end
                    end
                end

                if (!lq_conflict) begin
                    if (sq_all_rsvd)
                        LB.issue_list[j] = 1;
                    else begin
                        if (sq_head <= secure_age) begin
                        //  START [....... |HEAD ------ SECURE ---|..... ] END
                        //  Whether TAIL wraps doesn't matter, we only care about the range between H&S
                            if (LB.entries[j].age >= sq_head && LB.entries[j].age <= secure_age) begin
                                LB.issue_list[j] = 1;
                            end
                            else if (sq_head > secure_age) begin
                            //  START [|---- SECURE ----| ...... |HEAD ----|] END
                                if(LB.entries[j].age >= sq_head || LB.entries[j].age <= secure_age) begin
                                    LB.issue_list[j] = 1;
                                end
                            end
                        end
                        else LB.issue_list[j] = 0;
                    end
                end
            end 
        end
    end


//////////////////////////////////////////////////////////////////////////
//////////////////////////// store combinational /////////////////////////
//////////////////////////////////////////////////////////////////////////

    // Compute the secure_age [sequential version of sq_unkwn_idx]
    // That is the index of the oldest unresolved store instruction
    // Tell LB secure_age to help her decide which load could be issued
 
    always_comb begin
        sq_unkwn_idx = `SQ_CAPACITY-1;
        all_rsvd = 1;
        // Default is the max_index
        // Because when all addresses are resolved, we need a secure_age that's larger than any forward_age
        if (!sq_empty) begin
            if (SQ.tail == 0) begin
                for (int i=`SQ_CAPACITY-1; i>=SQ.head;i--) begin
                    if (SQ.entries[i].rsvd==0) begin
                        sq_unkwn_idx = i;
                        all_rsvd = 0;
                    end
                end
            end
            else if (SQ.head < SQ.tail) begin 
                for (int i=SQ.tail-1; i>=SQ.head;i--) begin
                    if (SQ.entries[i].rsvd==0) begin
                        sq_unkwn_idx = i;
                        all_rsvd = 0;
                    end
                end 

            end
            else if (SQ.head >= SQ.tail ) begin
                for (int i=SQ.tail-1; i>=0;i--) begin
                    if (SQ.entries[i].rsvd==0) begin
                        sq_unkwn_idx = i;
                        all_rsvd = 0;
                    end
                end
                for (int i=`SQ_CAPACITY-1; i>=SQ.head;i--) begin
                    if (SQ.entries[i].rsvd==0) begin
                        sq_unkwn_idx = i;
                        all_rsvd = 0;
                    end
                end
            end
        end
    end

    // To handle the LB forward request
    // We should find the matching address
    // Also we need to consider such cases:
    // STORE 1 byte in the address but the load instruction loads 1 word
    // This is not a perfect match which needs overwritten in D$/Memory 

    logic [`XLEN-1:0] addr_diff; 

    always_comb begin
        forward_addr = lb2sq_request_entry.addr;
        forward_age = lb2sq_request_entry.age;
        forward_match = 0; 
        if (sq_empty) begin
            forward_match = 0;
        end
        else if ((SQ.head < SQ.tail || SQ.tail == 0) && SQ.head < forward_age) begin
            for (int i=SQ.head; i < forward_age; i++) begin    
            if (forward_addr >= SQ.entries[i].addr && forward_addr+1'b1<<forward_mem_size<=SQ.entries + 1'b1<<SQ.entries[i].mem_size) begin
                    forward_match = 1;
                    forward_match_idx = i; 
                end
            end
        end
        else begin
            for (int i=SQ.head; (i < forward_age) && (i < `SQ_CAPACITY); i++) begin
                if (forward_addr >= SQ.entries[i].addr && forward_addr+1'b1<<forward_mem_size<=SQ.entries + 1'b1<<SQ.entries[i].mem_size) begin
                    forward_match = 1;
                    forward_match_idx = i;
                end
            end
            for (int i=0; (i < forward_age) && (i < SQ.tail); i++) begin
                if (forward_addr >= SQ.entries[i].addr && forward_addr+1'b1<<forward_mem_size<=SQ.entries + 1'b1<<SQ.entries[i].mem_size) begin
                    forward_match = 1;
                    forward_match_idx = i;
                end
            end
        end
        // don't forward if load instr needs more data
        addr_diff = forward_addr-SQ.entries[forward_match_idx].addr;
        if (forward_match) begin
            case (lb2sq_request_entry.mem_size)
                BYTE: forward_data = lb2sq_request_entry.load_signed ? {{25{SQ.entries[forward_match_idx].data[8*addr_diff+7]}},  SQ.entries[forward_match_idx].data[8*addr_diff +: 6]}
                                                                        : {24'b0, SQ.entries[forward_match_idx].data[8*addr_diff +: 7]};
                HALF: forward_data = lb2sq_request_entry.load_signed ? {{17{SQ.entries[forward_match_idx].data[8*addr_diff+15]}}, SQ.entries[forward_match_idx].data[addr_diff*8 +: 14]}
                                                                        : {16'b0, SQ.entries[forward_match_idx].data[addr_diff*8 +: 15]};
                WORD: forward_data = SQ.entries[forward_match_idx].data;
                default: forward_data = SQ.entries[forward_match_idx].data;
            endcase 
        end      
    end

    // module outputs to  CDB
    assign sq_valid        = forward_match;
    assign sq_PC           = lb2sq_request_entry.PC;
    assign sq_value        = forward_data;
    assign sq_prf_idx      = lb2sq_request_entry.rd_preg;
    assign sq_rob_idx      = lb2sq_request_entry.rob_idx;


    assign sq2cache_request_valid = store_enable;
    assign sq2cache_request_entry = SQ.entries[SQ.head];
    assign lb2cache_request_valid = lb2sq_request_valid ? !forward_match : 0;
    assign lb2cache_request_entry = lb2sq_request_entry;


//////////////////////////////////////////////////////////////////////////
//////////////////////////// load combinational //////////////////////////
//////////////////////////////////////////////////////////////////////////

    // Choose an issuable entry to issue with the given selector
   
    psel_gen #(.WIDTH(`LB_CAPACITY), .REQS(1)) psel (
        .req(LB.issue_list),
        .gnt(psel_gnt),
        .gnt_bus(gnt_bus),
        .empty(none_selected)
    );

    always_comb begin
        lq_issue_idx = `LB_CAPACITY'h0; 
        for (int j=0; j<`LB_CAPACITY; j++) begin
            if (psel_gnt[j]) lq_issue_idx = j; 
        end
    end

//////////////////////////////////////////////////////////////////////////
//////////////////////////// load sequential /////////////////////////////
//////////////////////////////////////////////////////////////////////////

    // Sequentially 
    always_ff @(posedge clock) begin
        if (reset) begin
            for(int i=0;i<`LB_CAPACITY;i++) begin
                LB.entries[i].rsvd <= `SD 1'b0;
            end 
            LB.free_list <= `SD {`LB_CAPACITY{1'b1}};
        end
        
        if (lb_enable) begin  
            // Tell RS this inst is entered into FREE_INDEX 
            assigned_lb_idx                 <= `SD lq_free_idx;
            // Age is the current SQ tail, new entry is always unresolved
            LB.entries[lq_free_idx].age        <= `SD sq_tail;
            LB.entries[lq_free_idx].rsvd       <= `SD 0;
            // Update the list - this entry no longer free/resolved
            LB.free_list[lq_free_idx]          <= `SD 0;    
        end 
        
        // RS fills information into specific entry when it's ready
        if (rs_lb_out_valid && LB.entries[rs_lb_packet.lb_idx].rsvd == 0) begin
            LB.entries[rs_lb_packet.lb_idx].PC          <= `SD rs_lb_packet.PC;
            LB.entries[rs_lb_packet.lb_idx].addr        <= `SD rs_lb_packet.base_value + rs_lb_packet.offset;
            LB.entries[rs_lb_packet.lb_idx].rd_preg     <= `SD rs_lb_packet.dest_preg_idx;
            LB.entries[rs_lb_packet.lb_idx].rob_idx     <= `SD rs_lb_packet.rob_idx;
            LB.entries[rs_lb_packet.lb_idx].rsvd        <= `SD 1;
            LB.entries[rs_lb_packet.lb_idx].mem_size    <= `SD rs_lb_packet.mem_size;
            LB.entries[rs_lb_packet.lb_idx].load_signed <= `SD rs_lb_packet.load_signed;
        end

        // Some load inst can be issued
        // Once issued; Retire from LB
        if (!none_selected) begin
            lb2sq_request_valid         <= `SD 1;
            lb2sq_request_entry         <= `SD LB.entries[lq_issue_idx];
            LB.free_list[lq_issue_idx]  <= `SD 1;
        end
        else
            lb2sq_request_valid <= `SD 0;
    end



//////////////////////////////////////////////////////////////////////////
/////////////////////////// store sequential /////////////////////////////
//////////////////////////////////////////////////////////////////////////


    always_ff @(posedge clock) begin
        if (reset) begin
            SQ.head <= `SD 0;
            SQ.tail <= `SD 0;
            sq_counter <= `SD 0;
            for(int it=0;it<`SQ_CAPACITY;it++) begin
                SQ.entries[it].rsvd  <= `SD 0;
            end 
            secure_age              <= `SD 0;
        end
        else begin
            secure_age <= `SD sq_unkwn_idx;

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

            if (sq_enable && ~(store_enable && SQ.entries[SQ.head].rsvd)) sq_counter <= `SD sq_counter + 1;
            if (~sq_enable && (store_enable && SQ.entries[SQ.head].rsvd)) sq_counter <= `SD sq_counter - 1;

            // if (lb2sq_request_valid) begin
            //     if (forward_match) begin
            //         lb2cache_request_valid  <= `SD 0;
            //     end
            //     else begin
            //         lb2cache_request_valid  <= `SD 1;
            //         lb2cache_request_entry  <= `SD lb2sq_request_entry;
            //     end
            // end
            // else    lb2cache_request_valid  <= `SD 0;

            sq_all_rsvd <= `SD all_rsvd;
        end    
    end
endmodule

`endif