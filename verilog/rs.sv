//////////////////////////////////////////////////////////////////////////
//                                                                      //
//   Modulename :  rs.v                                                 //
//                                                                      //
//  Description :  reservation station                                  //
//                                                                      // 
//                                                                      //
//                                                                      //
//////////////////////////////////////////////////////////////////////////

`ifndef __RS_V__
`define __RS_V__

`timescale 1ns/100ps

module rs(
    input clock,
    input reset,
    input [`PRF_LEN-1:0]  opa_preg_idx,
    input [`PRF_LEN-1:0]  opb_preg_idx,
    input [`PRF_LEN-1:0]  prf_free_preg_idx,
	input 				  opa_ready,
	input 				  opb_ready,
	input [`XLEN-1:0]	  opa_value,
	input [`XLEN-1:0] 	  opb_value,
    input                 commit_mis_pred,
    input [`ROB_LEN-1:0]  rob_tail,
    input [`PRF_LEN-1:0]  cdb_dest_preg_idx,
    input [`XLEN-1:0]     cdb_value,
    input                 id_packet_in,      // packet from id

    output ID_FU_PACKET   id_packet_out,     // overwrite opa and opb value, if needed
    output [`ROB_LEN-1:0] rob_idx
);



endmodule
`endif // __RS_V__