    data1 = 0x0001
    data2 = 0x0002
    data3 = 0x0003
	li	x6, data1
	li	x5, data2
    li  x4, data3
    bne x6, x5, B0
    add x3, x6, x5 # x3 = x6 + x5 
B0: add x2, x5, x4 
    wfi
 

