module cache_arbiter(
    // Main Memory
    input BUS_COMMAND     Dcache2mem_command,      // Issue a bus load
    input MEM_SIZE        Dcache2mem_size,
	input [`XLEN-1:0]     Dcache2mem_addr,         // Address sent to memory
    input [`XLEN-1:0]     Dcache2mem_data, 
    input BUS_COMMAND     Icache2mem_command,    // command sent to memory
	input [`XLEN-1:0]     Icache2mem_addr,  // Address sent to memor 
    
    input [3:0]           mem2cache_response,     // Tag from memory about current request
	input [63:0]          mem2cache_data,         // Data coming back from memory
	input [3:0]           mem2cache_tag,    

    output logic          [3:0]           mem2Dcache_response,     // Tag from memory about current request
	output logic          [63:0]          mem2Dcache_data,         // Data coming back from memory
	output logic          [3:0]           mem2Dcache_tag,    
    output logic                          mem2Dcache_response_valid,      
    output logic          [3:0]           mem2Icache_response,     // Tag from memory about current request
	output logic          [63:0]          mem2Icache_data,         // Data coming back from memory
	output logic          [3:0]           mem2Icache_tag,        
    output logic                          mem2Icache_response_valid,     
    output logic          BUS_COMMAND     cache2mem_command,      // Issue a bus load
    output logic          MEM_SIZE        cache2mem_size,  

	output logic          [`XLEN-1:0]     cache2mem_addr,         // Address sent to memory
    output logic          [`XLEN-1:0]     cache2mem_data, 
);
    assign mem2Dcache_response = mem2cache_response;
    assign mem2Icache_response = mem2cache_response;
    assign mem2Dcache_data = mem2cache_data;
    assign mem2Icache_data = mem2cache_data;
    assign mem2Icache_tag = mem2cache_tag;
    assign mem2Dcache_tag = mem2cache_tag;
    assign mem2Dcache_response_valid = (Dcache2mem_command != 0);
    assign mem2Icache_response_valid =  (Dcache2mem_command == 0) && (Icache2mem_command!=0);
    assign cache2mem_command = Dcache2mem_command!=0 ? Dcache2mem_command : Icache2mem_command;
    assign cache2mem_addr =  Dcache2mem_command!=0 ? Dcache2mem_addr : Icache2mem_addr;
    assign cache2mem_data =  Dcache2mem_command!=0 ? Dcache2mem_data : 0; 

endmodule