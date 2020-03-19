typedef union packed {
    logic [63:0] double;
    logic [1:0][31:0] words;
    logic [3:0][15:0] halves;
    logic [7:0][7:0] bytes;
} CACHE_BLOCK;

typedef struct packed {
    logic [7:0] tag;
    logic [4:0] block_num;
    logic [2:0] block_offset;
} DMAP_ADDR; //address breakdown for a direct-mapped cache
typedef struct packed {
    logic [9:0] tag;
    logic [2:0] set_index;
    logic [2:0] block_offset;
} SASS_ADDR; //address breakdown for a set associative cache
typedef union packed {
    DMAP_ADDR d; //for direct mapped
    SASS_ADDR s; //for set associative
} ADDR; //now we can pass around a common data type

typedef struct packed{
    logic [7:0]     tag;
    logic           valid;
    CACHE_BLOCK    data;  
} ICACHE_BLOCK;

 


//icahe: 256 byte: 32 lines, block size: 8 byte
        /*
        Cache Size Restriction
        I 256 bytes (32 x 8 bytes) of data in th，
    output logic                    Icahce_valid,e instruction cache
        I 256 bytes of data in the data cache.
        I One victim cache of two 8-byte blocks (16 bytes of data).
        I Does not include whatever metadata you need for each block
        I LRU bits, valid bits, tag bits, etc...
        I Levels the playing field for everyone, and avoids long synthesis times
        Number of CDBs can be at most number of ways you are superscalar
        I Why? Design Compiler doesn’t punish you as much as it should
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

    //outputs
    output logic  	[`XLEN-1:0] 	Icache2proc_data,
    output logic                    Icache2proc_valid,
    output logic    [1:0]           Icache2mem_command,    // command sent to memory
	output logic    [`XLEN-1:0]     Icache2mem_addr  // Address sent to memory
);

    ICACHE_BLOCK [31:0] icache_blocks;

    logic [7:0] current_tag;
    logic [4:0] current_index;
    logic [4:0] last_index;
    logic [7:0] last_tag;
    
    logic       miss_outstanding;
    logic       data_write_enable;

    logic [3:0] curr_mem_tag;

    assign Icache2proc_data = proc2Icache_addr[2]? icache_blocks[current_index].data[63:32]: icache_blocks[current_index].data[31:0];
    assign Icache2proc_valid = icache_blocks[current_index].valid && (icache_blocks[current_index].tag == current_tag);

    wire changed_addr = (current_index!=last_index) || (current_tag!=last_tag);

    wire unanswered_miss = changed_addr ? !Icache2proc_valid :
                            miss_outstanding & (mem2Icache_response==0);

    assign data_write_enable = (curr_mem_tag == mem2Icache_tag);
    wire update_mem_tag = changed_addr | miss_outstanding | data_write_enable;
                            
    assign {current_tag, current_index} = proc2Icache_addr[31:3];
    assign Icache2mem_addr = {proc2Icache_addr[31:3], 3'b0};
    assign Icache2mem_command = (miss_outstanding && !changed_addr);
    
    
    always_ff @(posedge clock) begin
        if (reset) begin
            int i;
            for (i=0; i<32; i++) begin
                icache_blocks[i].valid <= `SD 1'b0;
            end
        end
        else begin
            miss_outstanding <= `SD unanswered_miss;
            last_index       <= `SD current_index;
            last_tag         <= `SD current_tag;

            if (update_mem_tag) begin
                if (changed_addr) begin
                    curr_mem_tag <= `SD 4'b0;
                end
                else if (miss_outstanding) begin
                    curr_mem_tag <= `SD mem2Icache_response;
                end
                else if (data_write_enable) begin
                    curr_mem_tag <= `SD 4'b0;
                end
            end

            // update I-cache contents
            if(data_write_enable) begin
                icache_blocks[current_index].tag <= `SD current_tag;
                icache_blocks[current_index].valid <= `SD 1'b1;
                icache_blocks[current_index].data <= `SD mem2Icache_data;
            end
        end
    end


endmodule