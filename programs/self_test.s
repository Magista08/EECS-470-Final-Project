li	x2, 0x8
li	x3, 0x27bb
slli	x3,	x3,	16 
li	x1, 0x2ee6
or	x3,	x3,	x1 
li	x1, 0x87b
slli	x3,	x3,	12
or	x3,	x3,	x1 
li	x1, 0x0b0
slli	x3,	x3,	12 
or	x3,	x3,	x1
li	x1, 0xfd
slli	x3,	x3,	8 
or	x3,	x3,	x1 
li	x4, 0xb50
slli	x4,	x4,	12 
li	x1, 0x4f3
or	x4,	x4,	x1 
li	x1, 0x2d
slli	x4,	x4,	0x4 
or	x4,	x4,	x1 
li	x5, 0
addi	x5,	x5,	1 
slti	x6,	x5,	16 
mul	x11,	x2,	x3
add	x11,	x11,	x4
mul	x12,	x11,	x3 
add	x12,	x12,	x4 
mul	x13,	x12,	x3 
add	x13,	x13,	x4 
mul	x2,	x13,	x3 
add	x2,	x2,	x4 
srli	x11,	x11,	16 
srli	x12,	x12,	16 
srli	x13,	x13,	16 
srli	x14,	x2,	16 
addi	x1,	x1,	16 
addi	x5,	x5,	1 
slti	x6,	x5,	16
mul	x11,	x2,	x3
add	x11,	x11,	x4 
mul	x12,	x11,	x3 
add	x12,	x12,	x4 
mul	x13,	x12,	x3 
add	x13,	x13,	x4 
mul	x2,	x13,	x3 
add	x2,	x2,	x4
srli	x11,	x11,	16 
srli	x12,	x12,	16 
srli	x13,	x13,	16 
srli	x14,	x2,	16 
addi	x1,	x1,	16 
    addi	x5,	x5,	1 
slti	x6,	x5,	16 
mul	x11,	x2,	x3 
add	x11,	x11,	x4 
mul	x12,	x11,	x3
add	x12,	x12,	x4
mul	x13,	x12,	x3
add	x13,	x13,	x4
mul	x2,	x13,	x3
add	x2,	x2,	x4
srli	x11,	x11,	16
srli	x12,	x12,	16
srli	x13,	x13,	16
srli	x14,	x2,	16
addi	x1,	x1,	16
wfi