.section .text
.align 4
    nop
    li a1, 1000
    li a2, 2000
    nop
    sw a1, 0(a2)
    wfi
