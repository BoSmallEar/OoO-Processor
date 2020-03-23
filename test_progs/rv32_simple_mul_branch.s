	li x0, 0x4
        li x12, 0
	# test MULH not reach high bits
	li x1, 1
	li x2, 2
	mulh x5, x2, x1
	li x4, 0
	bne x4, x5, FAIL1
	# test MULH reach high bits
	li x1, -1
	li x2, 1
        mulh x6, x2, x1
	li x4, 0xffffffff
	bne x4, x6, FAIL2
	# test MULHSU not reach high bits
	li x1, 2
	li x2, -1
        mulhsu x7, x2, x1
	li x4, 0xffffffff
	bne x4, x7, FAIL3
	# test MULHSU reach high bits
	li x1, -2
	li x2, 1
        mulhsu x8, x2, x1
	li x4, 0
	bne x4, x8, FAIL4
	# test MULHU not reach high bits
	li x1, 1
	li x2, -2
	mulhu x9, x2, x1
	li x4, 0
	bne x4, x9, FAIL5
	# test MULHU reach high bits
	li x1, 1
	li x2, 2
        mulhu x10, x2, x1
	li x4, 0
	bne x4, x10, FAIL6
	wfi
FAIL1:  li x12, 1
	wfi
FAIL2:  li x12, 2
	wfi
FAIL3:  li x12, 3
	wfi
FAIL4:  li x12, 4
	wfi
FAIL5:  li x12, 5
	wfi
FAIL6:  li x12, 6
	wfi
