.section .text
.align 4
	nop											# 0
	li sp, 2048									# 4 - 8 ???
## Branch tests ##
	li t0, 0x1 #TODO: this will be test number 	# 12
	li t6, 0									# 16
	li t1, 1									# 20
	li t2, 2									# 24
	bne t1,t2, bt1								# 28
	nop											# 32
	nop											# 36
	nop											# 40
	wfi											# 44
bt1:
	addi t6, t6, 1								# 48 branch target
	li t1, 0									# 52
	li t2, 0									# 56
	bne t1, t2, bt2								# 60
	addi t6, t6, 1								# 64
bt2:
	beq t1, t2, bt3								# 68
	nop											# 72
	wfi											# 76
bt3:
	addi t6, t6, 1								# 80 branch target
	addi t1, t1, 1								# 84
	bltu t1, t0, bt4							# 88
	blt  t1, t0, bt4							# 92
	bge  t0, t1, bt4							# 96
	bgeu t0, t1, bt4 							# 100
	addi t6, t6, 1								# 104
	bge	 t1, t0, bt4							# 108
	nop											# 112
	wfi											# 116
bt4:
	lui t1, 0xfffff								# 120 branch target
	lui t0, 0x7ffff								# 124
	bgeu t1, t0, btt1							# 128
	nop											# 132
	wfi											# 136
btt1:
	bltu t0, t1, btt2							# 140
	nop											# 144
	wfi											# 148
btt2:
	blt t1, t0, btt3							# 152
	nop											# 156
	wfi											# 160
btt3:
	bge t0, t1, btt4							# 164
	nop											# 168
	wfi											# 172
btt4:
	jal btt5 									# 176 branch target
	nop											# 180
	wfi											# 184
btt5:
	li t0, 0									# 188
	la t1, btt6									# 192 196
	jalr t0,t1,0								# 200
linkaddr:
	wfi											# 204
btt6:
	la t1, linkaddr								# 208 212
	bne t0, t1, linkaddr						# 216

## Immediate tests ##
	li t0, 0x1 #TODO: this will be the test number	# 220   
	li t6 , 0 #zero out                             # 224
	ori t6, t6, -2048                               # 228
	ori t1, t1, -1                                  # 232
	li t2, 0                                        # 236
	addi t2, t2, 3
	andi t2, t2, 1
	li t3, 0
	xori t3, t3, -1 
	bne t3, t1, FAIL
	andi t1, t1, -2048
	bne t1,t6, FAIL
	slti t4, t1, 1	
	sltiu t5, t1, 1
	bne t4,t5, im_hop
	bge t1, t1, FAIL
im_hop:	
	li t2, 0x1
	slli t2, t2, 12
	lui t1, 1
	bne t2, t1, FAIL
	lui t1, 0xfffff
	srli t1, t1, 31
	li t2, 1
	bne t2, t1, FAIL
	lui t1, 0xfffff
	srai t1, t1, 31
	lui t2, 0xfffff
	ori t2, t2, -1
	bne t2, t1, FAIL 
## Memory tests ##
	li t0, 0x2 #TODO: testname	
	li t1, 255
	sb t1, 0(sp) 
	lb t2, 0(sp)
	bge t2, t1, FAIL
	lbu t2, 0(sp)
	bne t1,t2, FAIL	
	ori t1, t1, -1 
	lui t1, 0xf	
	sh t1, 0(sp)
	lh t2, 0(sp)
	bge t2, t1, FAIL
	lhu t2, 0(sp)
	bne t2, t2, FAIL	
	ori t1, t1, -1 
	lui t1, 0x7ffff
	sw t1, 0(sp)
	lw t2, 0(sp)
	bne t1, t2, FAIL
## Arithimetic between register tests ##
	li t0, 0x3
	li t1, 5
	li t2, 0
	add t2, t1, t1
	slli t1, t1, 1	
	bne t1, t2, FAIL
	li t1, 0x3
	li t2, 0x4
	or t1, t1,t2
	li t3, 0x7
	bne t1,t3, FAIL	
	li t1, 3
	sub t1, t1, t2
	li t2, -1
	bne t1,t2, FAIL
	# TODO: Finish out with arithmetic instructions, they have been enurmated 
	# in the previous section with immeadiates, just need to test them w/ reg args
## MULT Instructions ##
	li t0, 0x4
	li t1, 14
	li t2, 40
	mul t3, t2, t1
	li t4, 560
	bne t4, t3, FAIL
	lui t1, 0x7ff00
	lui t2, 0x55555
	mulhu t5, t1, t2
	mul t4, t1, t2
	lui t1, 0xfff00
    lui t2, 0xf5555
	mulh t5, t1,t2
	mul t4, t1,t2
	wfi
FAIL: 
	wfi                                             # 532
