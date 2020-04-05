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
        , output logic [`SQ_LEN-1:0]    sq_head 
        , output logic [`SQ_LEN-1:0]    sq_counter
        , output logic                  sq_empty      
        , output logic [`LB_LEN-1:0]        lq_free_idx
        , output logic [`LB_LEN-1:0]        lq_issue_idx
        , output logic [`LB_LEN-1:0]        lq_forward_idx
    `endif
);

    `ifndef DEBUG
        STORE_QUEUE                 SQ;
        LOAD_BUFFER                 LB;          
        // internal signals between SQ and LB 
        logic [`SQ_LEN-1:0]         sq_head; 
        // store combinational
        logic [`SQ_LEN-1:0]         sq_counter;
        logic                       sq_empty;   
        //load combinational  
        logic [`LB_LEN-1:0]         lq_free_idx;
        logic [`LB_LEN-1:0]         lq_issue_idx;
        logic [`LB_LEN-1:0]         lq_forward_idx;
    `endif 
     

    logic [`LB_CAPACITY-1:0]    issue_psel_gnt;
    logic [`LB_CAPACITY-1:0]    issue_gnt_bus;
    logic                       issue_none_selected;

    logic [`LB_CAPACITY-1:0]    forward_psel_gnt;
    logic [`LB_CAPACITY-1:0]    forward_gnt_bus;
    logic                       forward_none_selected;
        
    logic [`XLEN-1:0] addr_diff; 

    // Choose an issuable entry to issue with the given selector
    psel_gen #(.WIDTH(`LB_CAPACITY), .REQS(1)) psel_issue (
        .req(LB.issue_list & (~LB.free_list)),
        .gnt(issue_psel_gnt),
        .gnt_bus(issue_gnt_bus),
        .empty(issue_none_selected)
    );
    // Choose a forwardable entry to forward with the given selector
    psel_gen #(.WIDTH(`LB_CAPACITY), .REQS(1)) psel_forward (
        .req(LB.forward_list & (~LB.free_list)),
        .gnt(forward_psel_gnt),
        .gnt_bus(forward_gnt_bus),
        .empty(forward_none_selected)
    );

//////////////////////////////////////////////////////////////////////////
/////////////////////////// combinational //////////////////////////
//////////////////////////////////////////////////////////////////////////

    // sq
    assign sq_tail = SQ.tail;
    assign sq_head = SQ.head;
    assign sq_empty = sq_counter==0;
    assign sq_full = sq_counter==`SQ_CAPACITY-1; 

    // When SQ is full, TAIL won't overlap HEAD; To avoid some age problems

    assign sq_head_rsvd = SQ.entries[SQ.head].rsvd;
    assign lb_full = (LB.free_list==`LB_CAPACITY'b0);

    // module outputs to CDB
    assign sq_valid        = !forward_none_selected;
    assign sq_PC           = LB.entries[lq_forward_idx].PC;
    assign sq_value        = LB.entries[lq_forward_idx].forward_data;
    assign sq_prf_idx      = LB.entries[lq_forward_idx].rd_preg;
    assign sq_rob_idx      = LB.entries[lq_forward_idx].rob_idx;

    // module outputs to Dcache
    assign sq2cache_request_valid = store_enable;
    assign sq2cache_request_entry = SQ.entries[SQ.head]; 
    assign lb2cache_request_valid = !issue_none_selected;
    assign lb2cache_request_entry = LB.entries[lq_issue_idx];


    // Choose a free entry to put the new instruction
    always_comb begin
        lq_issue_idx = `LB_CAPACITY'h0; 
        lq_forward_idx = `LB_CAPACITY'h0;
        lq_free_idx = `LB_LEN'h0; 
        for (int j=0; j<`LB_CAPACITY; j++) begin
            if (issue_psel_gnt[j]) lq_issue_idx = j;   
            if (forward_psel_gnt[j]) lq_forward_idx = j; 
            if (LB.free_list[j]==1) lq_free_idx = j; 
        end
    end
 



    // Choose the issue_list from the resolved LB entries
    // They should be older than oldest unresolved store instruction

    always_comb begin
        for (int j=0; j<`LB_CAPACITY; j++) begin 
            addr_diff = 0;
            if (!LB.entries[j].rsvd) begin
                LB.forward_list[j] = 0;
                LB.issue_list[j] = 0; // Unresolved loads are not considered
            end
            else begin  
                // default: can issue
                LB.forward_list[j] = 0;
                LB.issue_list[j] = 1; // Unresolv
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
                        for (int i=0; i <= `SQ_CAPACITY-1; i++) begin
                            if ((i >= sq_head) && (i < LB.entries[j].age)) begin
                                if (!SQ.entries[i].rsvd) begin
                                    LB.issue_list[j] = 0; 
                                    LB.forward_list[j] = 0;
                                end
                                else if((SQ.entries[i].addr <= LB.entries[j].addr) && 
                                    ((SQ.entries[i].addr + SQ.entries[i].mem_size) >= (LB.entries[j].addr + LB.entries[j].mem_size))) begin
                                    LB.issue_list[j] = 0; 
                                    LB.forward_list[j] = 1;
                                    addr_diff = LB.entries[j].addr-SQ.entries[i].addr;
                                     case (LB.entries[j].mem_size)
                                        BYTE: LB.entries[j].forward_data = LB.entries[j].load_signed ? {{25{SQ.entries[i].data[8*addr_diff+7]}},  SQ.entries[i].data[8*addr_diff +: 6]}
                                                                                                : {24'b0, SQ.entries[i].data[8*addr_diff +: 7]};
                                        HALF: LB.entries[j].forward_data = LB.entries[j].load_signed ? {{17{SQ.entries[i].data[8*addr_diff+15]}}, SQ.entries[i].data[addr_diff*8 +: 14]}
                                                                                                : {16'b0, SQ.entries[i].data[addr_diff*8 +: 15]};
                                        WORD: LB.entries[j].forward_data = SQ.entries[i].data;
                                        default: LB.entries[j].forward_data = SQ.entries[i].data;
                                    endcase 
                                end
                                else if (((SQ.entries[i].addr + SQ.entries[i].mem_size)>LB.entries[j].addr) || ((LB.entries[j].addr + LB.entries[j].mem_size)>SQ.entries[i].addr)) begin
                                    LB.issue_list[j] = 0; 
                                    LB.forward_list[j] = 0;
                                end
                            end
                        end
                    end 
                    else begin // head > age
                        for (int i=0; i <= `SQ_CAPACITY-1; i++) begin
                            if (i >= sq_head) begin
                                if (!SQ.entries[i].rsvd) begin
                                    LB.issue_list[j] = 0; 
                                    LB.forward_list[j] = 0;
                                end
                                else if((SQ.entries[i].addr <= LB.entries[j].addr) && 
                                    ((SQ.entries[i].addr + SQ.entries[i].mem_size) >= (LB.entries[j].addr + LB.entries[j].mem_size))) begin
                                    LB.issue_list[j] = 0; 
                                    LB.forward_list[j] = 1;
                                    addr_diff = LB.entries[j].addr-SQ.entries[i].addr;
                                     case (LB.entries[j].mem_size)
                                        BYTE: LB.entries[j].forward_data = LB.entries[j].load_signed ? {{25{SQ.entries[i].data[8*addr_diff+7]}},  SQ.entries[i].data[8*addr_diff +: 6]}
                                                                                                : {24'b0, SQ.entries[i].data[8*addr_diff +: 7]};
                                        HALF: LB.entries[j].forward_data = LB.entries[j].load_signed ? {{17{SQ.entries[i].data[8*addr_diff+15]}}, SQ.entries[i].data[addr_diff*8 +: 14]}
                                                                                                : {16'b0, SQ.entries[i].data[addr_diff*8 +: 15]};
                                        WORD: LB.entries[j].forward_data = SQ.entries[i].data;
                                        default: LB.entries[j].forward_data = SQ.entries[i].data;
                                    endcase 
                                end
                                else if (!(SQ.entries[i].addr <= LB.entries[j].addr && 
                                    SQ.entries[i].addr + SQ.entries[i].mem_size >= LB.entries[j].addr + LB.entries[j].mem_size)
                                    && ( SQ.entries[i].addr + SQ.entries[i].mem_size>LB.entries[j].addr || LB.entries[j].addr + LB.entries[j].mem_size>SQ.entries[i].addr)) begin
                                    LB.issue_list[j] = 0; 
                                    LB.forward_list[j] = 0;
                                end
                            end
                        end
                        for (int i=0; i <= `SQ_CAPACITY-1; i++) begin
                            if (i < LB.entries[j].age) begin
                                if (!SQ.entries[i].rsvd) begin
                                    LB.issue_list[j] = 0; 
                                    LB.forward_list[j] = 0;
                                end
                                else if((SQ.entries[i].addr <= LB.entries[j].addr) && 
                                    ((SQ.entries[i].addr + SQ.entries[i].mem_size) >= (LB.entries[j].addr + LB.entries[j].mem_size))) begin
                                    LB.issue_list[j] = 0; 
                                    LB.forward_list[j] = 1;
                                    addr_diff = LB.entries[j].addr-SQ.entries[i].addr;
                                     case (LB.entries[j].mem_size)
                                        BYTE: LB.entries[j].forward_data = LB.entries[j].load_signed ? {{25{SQ.entries[i].data[8*addr_diff+7]}},  SQ.entries[i].data[8*addr_diff +: 6]}
                                                                                                : {24'b0, SQ.entries[i].data[8*addr_diff +: 7]};
                                        HALF: LB.entries[j].forward_data = LB.entries[j].load_signed ? {{17{SQ.entries[i].data[8*addr_diff+15]}}, SQ.entries[i].data[addr_diff*8 +: 14]}
                                                                                                : {16'b0, SQ.entries[i].data[addr_diff*8 +: 15]};
                                        WORD: LB.entries[j].forward_data = SQ.entries[i].data;
                                        default: LB.entries[j].forward_data = SQ.entries[i].data;
                                    endcase 
                                end
                                else if (!(SQ.entries[i].addr <= LB.entries[j].addr && 
                                    SQ.entries[i].addr + SQ.entries[i].mem_size >= LB.entries[j].addr + LB.entries[j].mem_size)
                                    && ( SQ.entries[i].addr + SQ.entries[i].mem_size>LB.entries[j].addr || LB.entries[j].addr + LB.entries[j].mem_size>SQ.entries[i].addr)) begin
                                    LB.issue_list[j] = 0; 
                                    LB.forward_list[j] = 0;
                                end
                            end
                        end
                    end
            end 
        end
    end





//////////////////////////////////////////////////////////////////////////
//////////////////////////// load sequential /////////////////////////////
//////////////////////////////////////////////////////////////////////////

    assign assigned_lb_idx = lq_free_idx;

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
            // assigned_lb_idx                 <= `SD lq_free_idx;
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
        if (!issue_none_selected) begin
            LB.free_list[lq_issue_idx]  <= `SD 1;
        end
        if (!forward_none_selected) begin
            LB.free_list[lq_forward_idx]  <= `SD 1;
        end
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
                // SQ.entries[it].valid  <= `SD 0;
            end 
            // secure_age              <= `SD 0;
        end
        else begin
           //  secure_age <= `SD sq_unkwn_idx;

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
                //SQ.entries[SQ.head].valid    <= `SD 0;
                SQ.head                     <= `SD (SQ.head == `SQ_CAPACITY-1) ? 0 : SQ.head + 1;
            end

            if (sq_enable && ~(store_enable && SQ.entries[SQ.head].rsvd)) sq_counter <= `SD sq_counter + 1;
            if (~sq_enable && (store_enable && SQ.entries[SQ.head].rsvd)) sq_counter <= `SD sq_counter - 1;

        end    
    end
endmodule

`endif
