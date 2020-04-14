`ifndef DEBUG
`define DEBUG
`endif
`ifndef __ICACHE_V__
`define __ICACHE_V__

//icahe: 256 byte: 32 lines, block size: 8 byte
        /*
        Cache Size Restriction
        I 256 bytes (32 x 8 bytes) of data in th?
    output logic                    Icahce_valid,e instruction cache
        I 256 bytes of data in the data cache.
        I One victim cache of two 8-byte blocks (16 bytes of data).
        I Does not include whatever metadata you need for each block
        I LRU bits, valid bits, tag bits, etc...
        I Levels the playing field for everyone, and avoids long synthesis times
        Number of CDBs can be at most number of ways you are superscalar
        I Why? Design Compiler doesn?t punish you as much as it should
        I You will need to schedule or stall functional units
        */

    

module icache(
    //inputs
    input                           clock,
    input                           reset,
    input           [`XLEN-1:0]     proc2Icache_addr,
    input           [3:0]           mem2Icache_response,         // Tag from memory about current request
	input           [63:0]          mem2Icache_data,             // Data coming back from memory
	input           [3:0]           mem2Icache_tag,    
    input                           mem2Icache_response_valid,
    input                           commit_mis_pred, 

    //outputs
    output logic  	[`XLEN-1:0] 	Icache2proc_data,
    output logic                    Icache2proc_valid,
    output BUS_COMMAND              Icache2mem_command,    // command sent to memory
	output logic    [`XLEN-1:0]     Icache2mem_addr  // Address sent to memory
);
    logic [3:0] num_block_prefetch;
    assign num_block_prefetch = 7; 
    logic [`XLEN-1:0] last_addr;
    logic [7:0] curr_tag;
    logic [4:0] curr_idx;
    logic [12:0] curr_victim_tag;
    logic [`XLEN-1:0] send_addr;
    logic [7:0] send_tag;
    logic [4:0] send_idx;
    logic [12:0] send_victim_tag; 
    logic        send_addr_hit; 
    logic [3:0] send_mem_tag;
    logic [`XLEN-1:0] goal_addr; 
    logic             change_addr;
    logic             curr_victim_cache_hit;
    logic             curr_victim_cache_way;
    logic             send_victim_cache_hit;
    logic             send_victim_cache_way;
    SEND_BUFFER_ENTRY [`SEND_BUFFER_SIZE-1:0] send_buffer;
    logic [`SEND_BUFFER_LEN-1:0] send_buffer_head_ptr;
    logic [`SEND_BUFFER_LEN-1:0] send_buffer_send_ptr;
    logic [`SEND_BUFFER_LEN-1:0] send_buffer_tail_ptr;
 
    assign goal_addr = {proc2Icache_addr[31:3],3'b0} + num_block_prefetch*8; 
    assign curr_tag = proc2Icache_addr[15:8];
    assign curr_victim_tag = proc2Icache_addr[15:3];
    assign curr_idx = proc2Icache_addr[7:3];
    assign send_tag = send_addr[15:8];
    assign send_victim_tag = send_addr[15:3];
    assign send_idx = send_addr[7:3];
    assign send_addr_hit = ((icache_blocks[send_idx].valid) && (icache_blocks[send_idx].tag == send_tag)) || send_victim_cache_hit;
    assign Icache2mem_addr = send_buffer[send_buffer_send_ptr].addr;
    assign Icache2mem_command =  (send_buffer[send_buffer_send_ptr].valid && ~send_buffer[send_buffer_send_ptr].done) ? BUS_LOAD : BUS_NONE; 
    assign Icache2proc_valid = ((icache_blocks[curr_idx].valid) && (icache_blocks[curr_idx].tag == curr_tag)) || curr_victim_cache_hit; 
    assign Icache2proc_data =  curr_victim_cache_hit? (proc2Icache_addr[2]? victim_cache.victim_blocks[curr_victim_cache_way].data[63:32]:  victim_cache.victim_blocks[curr_victim_cache_way].data[31:0]) : (proc2Icache_addr[2]? icache_blocks[curr_idx].data[63:32]: icache_blocks[curr_idx].data[31:0]);
    assign change_addr = (proc2Icache_addr != last_addr) && (proc2Icache_addr != last_addr+4);

    ICACHE_BLOCK [31:0] icache_blocks;
    VICTIM_CACHE victim_cache;

    
    always_comb begin
        curr_victim_cache_hit = 0;
        send_victim_cache_hit = 0;
        for(int i = 0; i < 2; i++) begin
            if (victim_cache.victim_blocks[i].valid && (victim_cache.victim_blocks[i].tag == curr_victim_tag)) begin 
                curr_victim_cache_hit = 1;
                curr_victim_cache_way = i;
            end    
            if (victim_cache.victim_blocks[i].valid && (victim_cache.victim_blocks[i].tag == send_victim_tag)) begin 
                send_victim_cache_hit = 1;
                send_victim_cache_way = i;
            end
        end
    end

 
    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin 
            for (int i=0; i<32; i++) begin
                icache_blocks[i].valid <= `SD 1'b0;
            end
            send_buffer_head_ptr <= `SD 0; 
            send_buffer_send_ptr <= `SD 0;
            send_buffer_tail_ptr <= `SD 0;
            send_addr <= `SD 0;
            last_addr <= `SD 0; 
            for(int i = 0; i < 2; i++) begin
                victim_cache.victim_blocks[i].valid <= `SD 1'b0;  
            end
            victim_cache.lru <= `SD 1'b0;
            
            for(int i = 0; i < `SEND_BUFFER_SIZE; i++) begin
                send_buffer[i].valid <= `SD 0;
                send_buffer[i].done <= `SD 0; 
            end
        end
        else begin  
            last_addr <= `SD proc2Icache_addr;
            if (change_addr) begin   
                if (!Icache2proc_valid) begin
                    send_addr <= `SD {proc2Icache_addr[31:3],3'b0}; 
                end
                else begin 
                    send_addr <= `SD {proc2Icache_addr[31:3],3'b0} + 8; 
                end
                send_buffer_head_ptr <= `SD 0; 
                send_buffer_send_ptr <= `SD 0;
                send_buffer_tail_ptr <= `SD 0; 
                for(int i = 0; i < `SEND_BUFFER_SIZE; i++) begin
                    send_buffer[i].valid <= `SD 0;
                    send_buffer[i].done <= `SD 0; 
                end
            end
            else begin
                if (send_addr <= goal_addr)begin  
                        if (send_addr_hit) begin
                            send_addr <= `SD send_addr + 4'h8; 
                            if (send_victim_cache_hit) begin
                                icache_blocks[send_idx].data <= `SD victim_cache.victim_blocks[send_victim_cache_way].data;
                                icache_blocks[send_idx].tag <= `SD send_tag;
                                icache_blocks[send_idx].valid <= `SD  victim_cache.victim_blocks[send_victim_cache_way].valid;
                                victim_cache.victim_blocks[send_victim_cache_way].data <=  `SD    icache_blocks[send_idx].data;
                                victim_cache.victim_blocks[send_victim_cache_way].valid <=  `SD   icache_blocks[send_idx].valid ;
                                victim_cache.victim_blocks[send_victim_cache_way].tag <=  `SD   {icache_blocks[send_idx].tag,send_idx};
                                victim_cache.lru <= `SD ~send_victim_cache_way;
                            end
                        end
                        else if (!send_buffer[send_buffer_tail_ptr].valid || send_buffer[send_buffer_tail_ptr].done)begin
                            send_buffer[send_buffer_tail_ptr].valid <= `SD 1'b1;
                            send_buffer[send_buffer_tail_ptr].done <= `SD 1'b0;
                            send_buffer[send_buffer_tail_ptr].addr <= `SD send_addr;
                            send_buffer[send_buffer_tail_ptr].mem_tag <= `SD 0; 
                            send_buffer_tail_ptr              <= `SD (send_buffer_tail_ptr == `SEND_BUFFER_SIZE-1) ? 0 : (send_buffer_tail_ptr + 1);
                        end 
                end
                if (mem2Icache_response != 0 && mem2Icache_response_valid && Icache2mem_command == BUS_LOAD) begin
                    send_buffer[send_buffer_send_ptr].mem_tag   <= `SD mem2Icache_response; 
                    send_buffer_send_ptr                        <= `SD (send_buffer_send_ptr == `SEND_BUFFER_SIZE-1)? 0: (send_buffer_send_ptr + 1);
                end
                for(int i = 0; i < `SEND_BUFFER_SIZE; i++) begin 
                    if (send_buffer[i].valid && !send_buffer[i].done && (send_buffer[i].mem_tag == mem2Icache_tag) && (mem2Icache_tag != 0)) begin
                        send_buffer[i].done <= `SD 1; 
                        icache_blocks[send_buffer[i].addr[7:3]].tag <= `SD send_buffer[i].addr[15:8];
                        icache_blocks[send_idx].valid <= `SD 1'b1;
                        icache_blocks[send_idx].data <= `SD mem2Icache_data;
                        victim_cache.victim_blocks[victim_cache.lru].data <=  `SD    icache_blocks[send_idx].data;
                        victim_cache.victim_blocks[victim_cache.lru].valid <=  `SD   icache_blocks[send_idx].valid ;
                        victim_cache.victim_blocks[victim_cache.lru].tag <=  `SD   {icache_blocks[send_idx].tag,send_idx};
                        victim_cache.lru <= `SD ~victim_cache.lru;
                    end 
                end            
            end
        end
    end


endmodule
`endif
