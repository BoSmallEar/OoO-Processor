        data1 = 0x000a
        data2 = 0x0002
        data3 = 0x0003
        li	x6, data1 # n = 10
        li	x5, 1   # i = 1 
        addi x4, x0, 0 # s = 0
Loop:   add  x4, x4, x5 # s = s + i
        addi  x5, x5, 1 # i = i + 1
        bne x6, x5, Loop # if (i!=n)  
        wfi
 