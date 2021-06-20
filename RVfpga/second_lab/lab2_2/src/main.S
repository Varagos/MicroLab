.globl main

.text
main:
//GPIO_INOUT 0x80001408
//GPIO_LEDS 0x80001404---2lsB
    lui t0, 0x80001
    lui t1, 0x10    //t1=0x00010000
    addi t1, t1, -1 //t1=0xFFFF
    sw t1, 1032(t0) //1032 = 0x408
    sw zero, 1028(t0)   //all leds off initially
    li s1, 15       //times to shift
    li s2, 0xFFFF   //bit mask-pseudo command eq to lui and addi -1
next_bit:
    blt s1, zero, all_on
    mv s3, s1       //expendable copy of s1
    li t1, 1        //starting bit0
    lw t3, 1028(t0) //load led state
    or t3, t3, t1 
    sw t3, 1028(t0) //switch on Leds_bit0 
shift_loop:
    beq zero, s3, shift_done # if s3 == zero then shift_done
    lw t3, 1028(t0)     //get leds state
    xori t4, s2, -1     //One's complement of bit mask ~ eq to NOT
    and t4, t3, t4      //keep led state not to be shifted
    and t3, t3, s2      //mask bits to be shifted
    slli t3, t3, 1      //shift left logical 1 bit
    or t3, t4, t3       //add shifted value to stable leds
    sw t3, 1028(t0)     //switch on leds
    addi s3, s3, -1     //decrement shift count
    j shift_loop
    
shift_done:
    addi s1, s1, -1
    srli s2, s2, 1      //shift right logical bit mask
    j next_bit
all_on:
    //all 16 bits are ON, 
    li s1, 15       //times to shift
    li s2, 0xFFFF   //bit mask
next_bit_2:
    blt s1, zero, all_off
    mv s3, s1       //expendable copy of s1
    li t1, 0x7FFF        //starting msb-pseudo li
    lw t3, 1028(t0) //load led state
    and t3, t3, t1  //switch off msb
    sw t3, 1028(t0) //switch on Leds_bit0 
shift_loop_2:
    beq zero, s3, shift_done_2 //if s3 == zero then shift_done
    lw t3, 1028(t0)     //get leds state
    xori t4, s2, -1     //One's complement of bit mask ~ eq to NOT
    and t4, t3, t4      //keep led state not to be shifted
    //and t3, t3, s2      //mask bits to be shifted
    srli t3, t3, 1      //shift right logical 1 bit
    lui t5,0x8          //switch on msb, because 0 gets inserted from shift right
    or t3, t3, t5       //msb will be switched off by outter loop on last iteration
    and t3, t3, s2      //mask bits because one's affect OR now
    or t3, t4, t3       //add shifted value to stable leds
    sw t3, 1028(t0)     //switch on leds
    addi s3, s3, -1     //decrement shift count
    j shift_loop_2

shift_done_2:
    addi s1, s1, -1
    slli s2, s2, 1  //reduce mask 1 bit from right
    lui t1, 0x10    //t1=0x00010000
    addi t1, t1, -1 //t1=0xFFFF
    and s2, s2, t1  //mask shift completed
    j next_bit_2
all_off:


.end