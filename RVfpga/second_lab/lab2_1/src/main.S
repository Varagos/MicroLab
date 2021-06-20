.globl main #


.equ N, 10

.data
A: .word 0,1,2,7,-8,4,5,-12,11,-2
B: .word 0,1,2,7,-8,4,5,12,-11,-2

.bss
#initialized to 0
C: .space 4*N


.text
main:
    la t0,A
    la t1,B
    add t1,t1,4*(N-1)
    la t2,A
    add t2,t2,4*(N-1)       #upper-limit
    la t5,C                 #output array 
for_loop:
    bgt t0,t2,end_label
    lw t3, 0(t0)             #A[i]
    lw t4, 0(t1)             #A[N-1-i]
    add t3, t3, t4
    bge t3,zero,skip_reverse
    neg t3,t3               #t3 = -t3
skip_reverse:
    sw t3,0(t5)
    addi t0, t0, 4; # t0 = t1 + 4
    addi t1, t1, -4
    addi t5, t5, 4
    j for_loop
end_label:



.end