# make          <- runs simv (after compiling simv if needed)
# make all      <- runs simv (after compiling simv if needed)
# make simv     <- compile simv if needed (but do not run)
# make syn      <- runs syn_simv (after synthesizing if needed then 
#                                 compiling synsimv if needed)
# make clean    <- remove files created during compilations (but not synthesis)
# make nuke     <- remove all files created during compilation and synthesis
#
# To compile additional files, add them to the TESTBENCH or SIMFILES as needed
# Every .vg file will need its own rule and one or more synthesis scripts
# The information contained here (in the rules for those vg files) will be 
# similar to the information in those scripts but that seems hard to avoid.
#
#

SOURCE = test_progs/basic_malloc.c

CRT = crt.s
LINKERS = linker.lds
ASLINKERS = aslinker.lds

DEBUG_FLAG = -g
CFLAGS =  -mno-relax -march=rv32im -mabi=ilp32 -nostartfiles -std=gnu11 -mstrict-align -I exception_handler
OFLAGS = -O0
ASFLAGS = -mno-relax -march=rv32im -mabi=ilp32 -nostartfiles -Wno-main -mstrict-align
OBJFLAGS = -SD -M no-aliases 
OBJDFLAGS = -SD -M numeric,no-aliases

##########################################################################
# IF YOU AREN'T USING A CAEN MACHINE, CHANGE THIS TO FALSE OR OVERRIDE IT
CAEN = 1
##########################################################################
ifeq (1, $(CAEN))
	GCC = riscv gcc
	OBJDUMP = riscv objdump
	AS = riscv as
	ELF2HEX = riscv elf2hex
else
	GCC = riscv64-unknown-elf-gcc
	OBJDUMP = riscv64-unknown-elf-objdump
	AS = riscv64-unknown-elf-as
	ELF2HEX = elf2hex
endif
all: simv
	./simv -cm line+tgl | tee program.out

compile: $(CRT) $(LINKERS)
	$(GCC) $(CFLAGS) $(OFLAGS) $(CRT) $(SOURCE) -T $(LINKERS) -o program.elf
	$(GCC) $(CFLAGS) $(DEBUG_FLAG) $(OFLAGS) $(CRT) $(SOURCE) -T $(LINKERS) -o program.debug.elf
assemble: $(ASLINKERS)
	$(GCC) $(ASFLAGS) $(SOURCE) -T $(ASLINKERS) -o program.elf 
	cp program.elf program.debug.elf
disassemble: program.debug.elf
	$(OBJDUMP) $(OBJFLAGS) program.debug.elf > program.dump
	$(OBJDUMP) $(OBJDFLAGS) program.debug.elf > program.debug.dump
	rm program.debug.elf
hex: program.elf
	$(ELF2HEX) 8 8192 program.elf > program.mem

program: compile disassemble hex
	@:

debug_program:
	gcc -lm -g -std=gnu11 -DDEBUG $(SOURCE) -o debug_bin
assembly: assemble disassemble hex
	@:

VCS = vcs -V -sverilog +vc -cm line+tgl -Mupdate -line -full64 +vcs+vcdpluson -debug_pp 
LIB = /afs/umich.edu/class/eecs470/lib/verilog/lec25dscc25.v
#URG = urg -dir simv.vdb -format text
# For visual debugger
VISFLAGS = -lncurses


##### 
# Modify starting here
#####

# TESTBENCH = 	sys_defs.svh	\
# 		ISA.svh         \
# 		testbench/mem.sv  \
# 		testbench/testbench.sv	\
# 		testbench/pipe_print.c	 
# SIMFILES =	verilog/pipeline.sv	\
# 		verilog/regfile.sv	\
# 		verilog/if_stage.sv	\
# 		verilog/id_stage.sv	\
# 		verilog/ex_stage.sv	\
# 		verilog/mem_stage.sv	\
# 		verilog/wb_stage.sv	\

TESTBENCH = 	sys_defs.svh	\
		ISA.svh         \
		testbench/mem.sv  \
		testbench/proc_testbench.sv
SIMFILES =	verilog/alu.sv	\
		verilog/branch.sv	\
		verilog/btb.sv	\
		verilog/cache_arbiter.sv	\
		verilog/cdb.sv	\
		verilog/decoder.sv	\
		verilog/dcache.sv   \
		verilog/icache.sv	\
		verilog/if_id_stage.sv	\
		verilog/load_store_queue.sv   \
		verilog/predictor.sv	\
		verilog/prf.sv	\
		verilog/processor.sv	\
		verilog/psel_gen.sv	\
		verilog/rat.sv	\
		verilog/rob.sv	\
		verilog/rrat.sv	\
		verilog/rs_alu.sv	\
		verilog/rs_branch.sv	\
		verilog/rs_mul.sv	\
		verilog/rs_lb.sv	\
		verilog/rs_sq.sv	\
		verilog/top_level.sv	\
		verilog/wand_sel.sv	\
		verilog/mul/pipe_mul.v

SYNFILES = synth/processor.vg

# Don't ask me why spell VisUal TestBenchER like this...
VTUBER = sys_defs.svh	\
		ISA.svh         \
		testbench/visual_testbench.v \
		testbench/visual_c_hooks.cpp \
		testbench/rob_print.c

synth/processor.vg:        $(SIMFILES) synth/processor.tcl
	cd synth && dc_shell-t -f ./processor.tcl | tee processor_synth.out 

#####
# Should be no need to modify after here
#####
simv:	$(SIMFILES) $(TESTBENCH)
	$(VCS) $(TESTBENCH) $(SIMFILES)	-o simv
	$(URG)


dve:	$(SIMFILES) $(TESTBENCH)
	$(VCS) +memcbk $(TESTBENCH) $(SIMFILES) -o dve -R -gui
.PHONY:	dve

# For visual debugger
vis_simv:	$(SIMFILES) $(VTUBER)
	$(VCS) $(VISFLAGS) $(VTUBER) $(SIMFILES) -o vis_simv 
	./vis_simv

syn_simv:	$(SYNFILES) $(TESTBENCH)
	$(VCS) $(TESTBENCH) $(SYNFILES) $(LIB) -o syn_simv
	$(URG)

syn:	syn_simv
	./syn_simv -cm line+tgl | tee syn_program.out

#dve:	$(SYNFILES) $(TESTBENCH)
#	$(VCS) +memcbk $(TESTBENCH) $(SYNFILES) -o dve -R -gui
# .PHONY:	dve

clean:
	rm -rf *simv *simv.daidir csrc vcs.key program.out *.key
	rm -rf vis_simv vis_simv.daidir
	rm -rf dve* inter.vpd DVEfiles
	rm -rf syn_simv syn_simv.daidir syn_program.out
	rm -rf synsimv synsimv.daidir csrc vcdplus.vpd vcs.key synprog.out pipeline.out writeback.out vc_hdrs.h
	rm -f *.elf *.dump *.mem debug_bin

nuke:	clean
	rm -rf synth/*.vg synth/*.rep synth/*.ddc synth/*.chk synth/command.log synth/*.syn
	rm -rf synth/*.out command.log synth/*.db synth/*.svf synth/*.mr synth/*.pvl
