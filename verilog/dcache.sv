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

typedef struct packed {
    logic [7:0]     tag;
    logic           valid;
    CACHE_BLOCK     data;   // 8 Byte (64 bits) per block plus metadata
} DCACHE_BLOCK;

typedef struct packed {
    logic [63:0]    data1;
    logic [63:0]    data2;  
} VICTIM;

/* Cache Restrictions:
 - 128 bytes of data in the data cache.   [16 blocks]
 - One victim cache of two 8-byte blocks (16 bytes of data)
        - Does not include whatever metadata you need for each block    */


module load_queue( // may be out of order
    input                       ,

    output                           
);
module store_queue( // may be out of order
    input                       ,

    output                           
);

endmodule

parameter WAY_WIDTH=4;
parameter DCACHE_CAPACITY=16;
parameter NUM_SETS=2;
parameter NUM_WAYS=8;

// return the index in the specific set
module bit_plru(
    input   set_index,
    output  logic [WAY_WIDTH-1:0] replace,
);
    logic [NUM_SETS-1:0][NUM_WAYS-1:0] status_bits;
    logic all_one;
    assign all_one = (status_bits[set_idex]==NUM_WAYS'b1);

    logic [WAY_WIDTH-1:0] chosen;

    always_comb begin
        if (ALL_ONE):
            status_bits[set_index] = NUM_WAYS'b0;
        for (int i=NUM_WAYS-1;i>=0;i--) begin
            if (status_bits[set_index][i]==0) chosen = i;
        end
        replace = chosen;
        status_bits[set_index][chosen] = 1;
    end
endmodule

module dcache(
    input                           clock,
    input                           reset,
    input           [`XLEN-1:0]     proc2Dcache_addr,
    input           [3:0]           mem2Dcache_response,     // Tag from memory about current request
	input           [63:0]          mem2Dcache_data,         // Data coming back from memory
	input           [3:0]           mem2Dcache_tag,          

    // Outputs to processor
    output logic  	[`XLEN-1:0] 	Dcache2proc_data,        // If command is LOAD
    output logic                    Dcache2proc_valid,    

    // Outputs to main memory
    output logic    [1:0]           Dcache2mem_command,    // Issue a bus load
	output logic    [`XLEN-1:0]     Dcache2mem_addr        // Address sent to memory
);

    // I have 16 blocks in Dcache
    DCACHE_BLOCK [3:0] dcache_blocks;  

    // Extract the tag and index of the requested block
    logic [7:0] current_tag;                            // Unique identifier of a specific block
    logic [4:0] current_index;                          // Decides the position in the cache
    assign { current_tag, current_index } = proc2Dcache_addr[31:3];
    // Check whether inputed a new block address
    logic [7:0] last_tag;
    logic [4:0] last_index;
    logic changed_addr = (current_index!=last_index) || (current_tag!=last_tag);
    // Read the information from the requested block -- data/valid
    DCACHE_BLOCK  current_block = dcache_blocks[current_index];
    assign Dcache2proc_data = proc2Dcache_addr[2]? current_block.data[63:32]:current_block.data[31:0];
    assign Dcache2proc_valid = current_block.valid && (current_block.tag == current_tag);

    // Case: Hit
    // Case: Miss
    logic       miss_outstanding;
    logic       data_write_enable;

t logic  	[`XLEN-1:0] 	Dcache2proc_data,        // If command is LOAD
    output logic                    Dcache2proc_valid,    

    // Outputs to main memory
    output logic    [1:0]           Dcache2mem_command,    // Issue a bus load
	output logic    [`XLEN-1:0]     Dcache2mem_addr        // Address sent to memory
);

    // I have 16 blocks in Dcache
    DCACHE_BLOCK [3:0] dcache_blocks;  

    // Extract the tag and index of the requested block
    logic [7:0] current_tag;                            // Unique identifier of a specific block
    logic [4:0] current_index;                          // Decides the position in the cache
    assign { current_tag, current_index } = proc2Dcache_addr[31:3];
    // Check whether inputed a new block address
    logic [7:0] last_tag;
    logic [4:0] last_index;
    logic changed_addr = (current_index!=last_index) || (current_tag!=last_tag);
    // Read the information from the requested block -- data/valid
    DCACHE_BLOCK  current_block = dcache_blocks[current_index];
    assign Dcache2proc_data = proc2Dcache_addr[2]? current_block.data[63:32]:current_block.data[31:0];
    assign Dcache2proc_valid = current_block.valid && (current_block.tag == current_tag);

    // Case: Hit
    // Case: Miss
    logic       miss_outstanding;
    logic       data_write_enable;

t logic  	[`XLEN-1:0] 	Dcache2proc_data,        // If command is LOAD
    output logic                    Dcache2proc_valid,    

    // Outputs to main memory
    output logic    [1:0]           Dcache2mem_command,    // Issue a bus load
	output logic    [`XLEN-1:0]     Dcache2mem_addr        // Address sent to memory
);

    // I have 16 blocks in Dcache
    DCACHE_BLOCK [3:0] dcache_blocks;  

    // Extract the tag and index of the requested block
    logic [7:0] current_tag;                            // Unique identifier of a specific block
    logic [4:0] current_index;                          // Decides the position in the cache
    assign { current_tag, current_index } = proc2Dcache_addr[31:3];
    // Check whether inputed a new block address
    logic [7:0] last_tag;
    logic [4:0] last_index;
    logic changed_addr = (current_index!=last_index) || (current_tag!=last_tag);
    // Read the information from the requested block -- data/valid
    DCACHE_BLOCK  current_block = dcache_blocks[current_index];
    assign Dcache2proc_data = proc2Dcache_addr[2]? current_block.data[63:32]:current_block.data[31:0];
    assign Dcache2proc_valid = current_block.valid && (current_block.tag == current_tag);

    // Case: Hit
    // Case: Miss
    logic       miss_outstanding;
    logic       data_write_enable;

t logic  	[`XLEN-1:0] 	Dcache2proc_data,        // If command is LOAD
    output logic                    Dcache2proc_valid,    

    // Outputs to main memory
    output logic    [1:0]           Dcache2mem_command,    // Issue a bus load
	output logic    [`XLEN-1:0]     Dcache2mem_addr        // Address sent to memory
);

    // I have 16 blocks in Dcache
    DCACHE_BLOCK [3:0] dcache_blocks;  

    // Extract the tag and index of the requested block
    logic [7:0] current_tag;                            // Unique identifier of a specific block
    logic [4:0] current_index;                          // Decides the position in the cache
    assign { current_tag, current_index } = proc2Dcache_addr[31:3];
    // Check whether inputed a new block address
    logic [7:0] last_tag;
    logic [4:0] last_index;
    logic changed_addr = (current_index!=last_index) || (current_tag!=last_tag);
    // Read the information from the requested block -- data/valid
    DCACHE_BLOCK  current_block = dcache_blocks[current_index];
    assign Dcache2proc_data = proc2Dcache_addr[2]? current_block.data[63:32]:current_block.data[31:0];
    assign Dcache2proc_valid = current_block.valid && (current_block.tag == current_tag);

    // Case: Hit
    // Case: Miss
    logic       miss_outstanding;
    logic       data_write_enable;

t logic  	[`XLEN-1:0] 	Dcache2proc_data,        // If command is LOAD
    output logic                    Dcache2proc_valid,    

    // Outputs to main memory
    output logic    [1:0]           Dcache2mem_command,    // Issue a bus load
	output logic    [`XLEN-1:0]     Dcache2mem_addr        // Address sent to memory
);

    // I have 16 blocks in Dcache
    DCACHE_BLOCK [3:0] dcache_blocks;  

    // Extract the tag and index of the requested block
    logic [7:0] current_tag;                            // Unique identifier of a specific block
    logic [4:0] current_index;                          // Decides the position in the cache
    assign { current_tag, current_index } = proc2Dcache_addr[31:3];
    // Check whether inputed a new block address
    logic [7:0] last_tag;
    logic [4:0] last_index;
    logic changed_addr = (current_index!=last_index) || (current_tag!=last_tag);
    // Read the information from the requested block -- data/valid
    DCACHE_BLOCK  current_block = dcache_blocks[current_index];
    assign Dcache2proc_data = proc2Dcache_addr[2]? current_block.data[63:32]:current_block.data[31:0];
    assign Dcache2proc_valid = current_block.valid && (current_block.tag == current_tag);

    // Case: Hit
    // Case: Miss
    logic       miss_outstanding;
    logic       data_write_enable;

