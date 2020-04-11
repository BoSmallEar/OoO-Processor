# Begin_DVE_Session_Save_Info
# DVE view(Wave.1 ) session
# Saved on Sat Apr 11 02:29:02 2020
# Toplevel windows open: 2
# 	TopLevel.1
# 	TopLevel.2
#   Wave.1: 23 signals
# End_DVE_Session_Save_Info

# DVE version: N-2017.12-SP2-1_Full64
# DVE build date: Jul 14 2018 20:58:30


#<Session mode="View" path="/afs/umich.edu/user/j/e/jerrysun/eecs470/project/group8w20/debug_icache.tcl" type="Debug">

#<Database>

gui_set_time_units 100ps
#</Database>

# DVE View/pane content session: 

# Begin_DVE_Session_Save_Info (Wave.1)
# DVE wave signals session
# Saved on Sat Apr 11 02:29:02 2020
# 23 signals
# End_DVE_Session_Save_Info

# DVE version: N-2017.12-SP2-1_Full64
# DVE build date: Jul 14 2018 20:58:30


#Add ncecessay scopes

gui_set_time_units 100ps

set _wave_session_group_1 icache0
if {[gui_sg_is_group -name "$_wave_session_group_1"]} {
    set _wave_session_group_1 [gui_sg_generate_new_name]
}
set Group1 "$_wave_session_group_1"

gui_sg_addsignal -group "$_wave_session_group_1" { {Sim:proc_testbench.processor0.icache0.clock} {Sim:proc_testbench.processor0.icache0.last_index} {Sim:proc_testbench.processor0.icache0.last_tag} {Sim:proc_testbench.processor0.icache0.current_index} {Sim:proc_testbench.processor0.icache0.current_tag} {Sim:proc_testbench.processor0.icache0.mem2Icache_data} {Sim:proc_testbench.processor0.icache0.mem2Icache_tag} {Sim:proc_testbench.processor0.icache0.mem2Icache_response} {Sim:proc_testbench.processor0.icache0.mem2Icache_response_valid} {Sim:proc_testbench.processor0.icache0.Icache2mem_command} {Sim:proc_testbench.processor0.icache0.Icache2mem_addr} {Sim:proc_testbench.processor0.icache0.icache_blocks} {Sim:proc_testbench.processor0.icache0.Icache2proc_data} {Sim:proc_testbench.processor0.icache0.curr_mem_tag} {Sim:proc_testbench.processor0.icache0.Icache2proc_valid} {Sim:proc_testbench.processor0.icache0.proc2Icache_addr} {Sim:proc_testbench.processor0.if_id_stage_0.PC_reg} {Sim:proc_testbench.processor0.if_id_stage_0.result_mis_pred} {Sim:proc_testbench.processor0.icache0.changed_addr} {Sim:proc_testbench.processor0.icache0.miss_outstanding} {Sim:proc_testbench.processor0.icache0.unanswered_miss} {Sim:proc_testbench.processor0.icache0.update_mem_tag} {Sim:proc_testbench.processor0.icache0.data_write_enable} }
gui_set_radix -radix {decimal} -signals {Sim:proc_testbench.processor0.icache0.last_tag}
gui_set_radix -radix {unsigned} -signals {Sim:proc_testbench.processor0.icache0.last_tag}
gui_set_radix -radix {decimal} -signals {Sim:proc_testbench.processor0.icache0.current_index}
gui_set_radix -radix {unsigned} -signals {Sim:proc_testbench.processor0.icache0.current_index}
gui_set_radix -radix {decimal} -signals {Sim:proc_testbench.processor0.icache0.current_tag}
gui_set_radix -radix {unsigned} -signals {Sim:proc_testbench.processor0.icache0.current_tag}
gui_set_radix -radix {decimal} -signals {Sim:proc_testbench.processor0.icache0.curr_mem_tag}
gui_set_radix -radix {unsigned} -signals {Sim:proc_testbench.processor0.icache0.curr_mem_tag}
if {![info exists useOldWindow]} { 
	set useOldWindow true
}
if {$useOldWindow && [string first "Wave" [gui_get_current_window -view]]==0} { 
	set Wave.1 [gui_get_current_window -view] 
} else {
	set Wave.1 [lindex [gui_get_window_ids -type Wave] 0]
if {[string first "Wave" ${Wave.1}]!=0} {
gui_open_window Wave
set Wave.1 [ gui_get_current_window -view ]
}
}

set groupExD [gui_get_pref_value -category Wave -key exclusiveSG]
gui_set_pref_value -category Wave -key exclusiveSG -value {false}
set origWaveHeight [gui_get_pref_value -category Wave -key waveRowHeight]
gui_list_set_height -id Wave -height 25
set origGroupCreationState [gui_list_create_group_when_add -wave]
gui_list_create_group_when_add -wave -disable
gui_marker_set_ref -id ${Wave.1}  C1
gui_wv_zoom_timerange -id ${Wave.1} 4511122 4513181
gui_list_add_group -id ${Wave.1} -after {New Group} [list ${Group1}]
gui_list_select -id ${Wave.1} {proc_testbench.processor0.icache0.last_tag }
gui_seek_criteria -id ${Wave.1} {Any Edge}


gui_set_pref_value -category Wave -key exclusiveSG -value $groupExD
gui_list_set_height -id Wave -height $origWaveHeight
if {$origGroupCreationState} {
	gui_list_create_group_when_add -wave -enable
}
if { $groupExD } {
 gui_msg_report -code DVWW028
}
gui_list_set_filter -id ${Wave.1} -list { {Buffer 1} {Input 1} {Others 1} {Linkage 1} {Output 1} {Parameter 1} {All 1} {Aggregate 1} {LibBaseMember 1} {Event 1} {Assertion 1} {Constant 1} {Interface 1} {BaseMembers 1} {Signal 1} {$unit 1} {Inout 1} {Variable 1} }
gui_list_set_filter -id ${Wave.1} -text {*}
gui_list_set_insertion_bar  -id ${Wave.1} -group ${Group1}  -item proc_testbench.processor0.if_id_stage_0.result_mis_pred -position below

gui_marker_move -id ${Wave.1} {C1} 4512450
gui_view_scroll -id ${Wave.1} -vertical -set 34
gui_show_grid -id ${Wave.1} -enable false
#</Session>

