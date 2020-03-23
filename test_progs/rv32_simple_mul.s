	li x0, 0x4      # pc = 0
        li x12, 0   # pc = 4
	# test MULH not reach high bits
	li x1, 1        # pc = 8
	li x2, 2        # pc = 12
	mulh x5, x2, x1 # pc = 16
	li x4, 0        # pc = 20
	bne x4, x5, FAIL1 # pc = 24
	# test MULH reach high bits
	li x1, -1       # pc = 28
	li x2, 1        # pc = 32
        mulh x6, x2, x1 # pc = 36
	li x4, 0xffffffff # pc = 40
	bne x4, x6, FAIL2 # pc = 44
	# test MULHSU not reach high bits
	li x1, 1           # pc = 48
	li x2, -1          # pc = 52
        mulhsu x7, x2, x1  # pc = 56 # sho
	li x4, 0x0 # pc = 60
	bne x4, x7, FAIL3 # pc = 64
	# test MULHSU reach high bits
	li x1, -2         # pc = 68
	li x2, 1          # pc = 72
        mulhsu x8, x2, x1 # pc = 76
	li x4, 0          # pc = 80
	bne x4, x8, FAIL4 # pc = 84
	# test MULHU not reach high bits
	li x1, 1          # pc = 88
	li x2, -2         # pc = 92
	mulhu x9, x2, x1  # pc = 96
	li x4, 0          # pc = 100
	bne x4, x9, FAIL5 # pc = 104
	# test MULHU reach high bits
	li x1, 1          # pc = 108
	li x2, 2          # pc = 112
        mulhu x10, x2, x1 # pc = 116
	li x4, 0          # pc = 120
	bne x4, x10, FAIL6 # pc = 124
	wfi               # pc = 128
FAIL1:  li x12, 1     # pc = 132
	wfi               # pc = 136
FAIL2:  li x12, 2     # pc = 140
	wfi               # pc = 144
FAIL3:  li x12, 3     # pc = 148
	wfi               # pc = 152
FAIL4:  li x12, 4     # pc = 156
	wfi               # pc = 160
FAIL5:  li x12, 5     # pc = 164
	wfi               # pc = 168
FAIL6:  li x12, 6     # pc = 172
	wfi               # pc = 176
 