// r0  - routine argument
// r1  - routine argument

// r2  - vfd digit #2 
// r3  - vfd digit #3
// r4  - vfd digit #4
// r5  - vfd digit #5
// r6  - vfd digit #6
// r7  - vfd digit #7

// r8  - digit value #2
// r9  - digit value #4
// r10 - digit value #5
// r11 - digit value #6
// r12 - digit value #7
// r13 - digit value #8
// r14 - counter / routine argument
// r15 - segment value 0
// r16 - segment value 1
// r17 - segment value 2
// r18 - segment value 3
// r19 - segment value 4
// r20 - segment value 5
// r21 - segment value 6
// r22 - segment value 7
// r23 - segment value 8
// r24 - segment value 9

// r25 - time data 1 
//     - b0 -> hour digit 1
//     - b1 -> hour digit 2
//     - b2 -> minute digit 1 
//     - b3 -> minute digit 2

// r26 - time data 2
//      - b0 -> second digit 1
//      - b1 -> second digit 2
// r27 - return pointer
// r28 - routine argument
// r30 - GPO PRU0
// r31 - HOST-to-PRU INTC

#define REG_HOUR_COUNTER_1        r25.b0
#define REG_HOUR_COUNTER_2        r25.b1

#define REG_MINUTE_COUNTER_1      r25.b2
#define REG_MINUTE_COUNTER_2      r25.b3

#define REG_SECOND_COUNTER_1      r26.b0
#define REG_SECOND_COUNTER_2      r26.b1

#define PRU1_PRU0_INTERRUPT     18
#define PRU0_ARM_INTERRUPT      19

#define DATA_BIT      1<<0
#define CLOCK_BIT     1<<5
#define LATCH_BIT     1<<1

#define VFD_DIGIT_2   r2
#define VFD_DIGIT_3   r3
#define VFD_DIGIT_4   r4
#define VFD_DIGIT_5   r5
#define VFD_DIGIT_6   r6
#define VFD_DIGIT_7   r7

#define VFD_HOUR_1    r8
#define VFD_HOUR_2    r9
#define VFD_MINUTE_1  r10
#define VFD_MINUTE_2  r11
#define VFD_SECOND_1  r12
#define VFD_SECOND_2  r13

#define TIME_DATA_1    r25
#define TIME_DATA_2    r26

#define SEG_A   1<< 0x0a
#define SEG_B   1<< 0x01
#define SEG_C   1<< 0x07
#define SEG_D   1<< 0x08
#define SEG_E   1<< 0x06
#define SEG_F   1<< 0x00
#define SEG_G   1<< 0x02

#define VFD_SEGMENT_0      r15
#define VFD_SEGMENT_1      r16
#define VFD_SEGMENT_2      r17
#define VFD_SEGMENT_3      r18
#define VFD_SEGMENT_4      r19
#define VFD_SEGMENT_5      r20
#define VFD_SEGMENT_6      r21
#define VFD_SEGMENT_7      r22
#define VFD_SEGMENT_8      r23
#define VFD_SEGMENT_9      r24

#define CONST_PRUCFG       c4
#define CONST_PRUSRAM      c24

#define CONST_PRUSSINTC    c0
#define SICR_OFFSET        0x24

#define CTBIR_0            0x22020
#define RET_POINTER        r27.w0
#define GPO_PRU0_REG       r30

.setcallreg RET_POINTER
.origin 0
.entrypoint start

.macro NOP
        mov     r0, r0
.endm

// 10 clock cycle delay
.macro EN_DELAY
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
.endm

// EN_DELAY + 4 clock cycle delay
.macro WRITE_DATA
.mparam update_count
        mov GPO_PRU0_REG, r28
        mov r0, update_count
update_begin:
        EN_DELAY

        sub r0, r0, 1
        qbne update_begin, r0, 0
.endm

start: 
        // setup c24_blk_index + c25_blk_index
        mov r0, 0
        mov r1, CTBIR_0
        sbbo r0, r1, 0, 4

        // enable master ocp
        lbco r0, CONST_PRUCFG, 4, 4
        clr r0, r0, 4
        sbco r0, CONST_PRUCFG, 4, 4

        // load digit indexes and digit segment values
        mov VFD_HOUR_1,   1<< 0x10
        mov VFD_HOUR_2,   1<< 0x11 | 1<< 0x09 // period

        mov VFD_MINUTE_1, 1<< 0x0e
        mov VFD_MINUTE_2, 1<< 0x12 | 1<< 0x09 // period

        mov VFD_SECOND_1, 1<< 0x0d
        mov VFD_SECOND_2, 1<< 0x13
        
        // 0
        mov VFD_SEGMENT_0, SEG_A | SEG_B | SEG_C | SEG_D | SEG_E | SEG_F
        // 1
        mov VFD_SEGMENT_1, SEG_B | SEG_C
        // 2
        mov VFD_SEGMENT_2, SEG_A | SEG_B | SEG_D | SEG_E | SEG_G
        // 3
        mov VFD_SEGMENT_3, SEG_A | SEG_B | SEG_C | SEG_D | SEG_G
        // 4
        mov VFD_SEGMENT_4, SEG_B | SEG_C | SEG_F | SEG_G
        // 5
        mov VFD_SEGMENT_5, SEG_A | SEG_C | SEG_D | SEG_F | SEG_G
        // 6
        mov VFD_SEGMENT_6, SEG_A | SEG_C | SEG_D | SEG_E | SEG_F | SEG_G
        // 7
        mov VFD_SEGMENT_7, SEG_A | SEG_B | SEG_C
        // 8
        mov VFD_SEGMENT_8, SEG_A | SEG_B | SEG_C | SEG_D | SEG_E | SEG_F | SEG_G
        // 9
        mov VFD_SEGMENT_9, SEG_A | SEG_B | SEG_C | SEG_D | SEG_F | SEG_G

        // copy over buffer
        lbco TIME_DATA_1, CONST_PRUSRAM, 0, 8

update_buffer:
        // clear interrupt
        ldi r0.w2, 0
        ldi r0.w0, PRU1_PRU0_INTERRUPT
        sbco r0, CONST_PRUSSINTC, SICR_OFFSET, 4 

        call increment_timer

        // hour digit 1
        mov r0, REG_HOUR_COUNTER_1
        mov r1, VFD_HOUR_1

        call update_digit
        mov VFD_DIGIT_7, r1

        // hour digit 2
        mov r0, REG_HOUR_COUNTER_2
        mov r1, VFD_HOUR_2

        call update_digit
        mov VFD_DIGIT_6, r1

        // minute digit 1
        mov r0, REG_MINUTE_COUNTER_1
        mov r1, VFD_MINUTE_1

        call update_digit
        mov VFD_DIGIT_5, r1

        // minute digit 2
        mov r0, REG_MINUTE_COUNTER_2
        mov r1, VFD_MINUTE_2

        call update_digit
        mov VFD_DIGIT_4, r1

        // second digit 1
        mov r0, REG_SECOND_COUNTER_1
        mov r1, VFD_SECOND_1

        call update_digit
        mov VFD_DIGIT_3, r1

        // second digit 2
        mov r0, REG_SECOND_COUNTER_2
        mov r1, VFD_SECOND_2

        call update_digit
        mov VFD_DIGIT_2, r1

interrupt_check:
        qbbs update_buffer, r31, 30

update_vfd:
        // digit 2
        mov r1, VFD_DIGIT_2
        call write_digit

        // digit 3
        mov r1, VFD_DIGIT_3
        call write_digit

        // digit 4
        mov r1, VFD_DIGIT_4
        call write_digit

        // digit 5
        mov r1, VFD_DIGIT_5
        call write_digit

        // digit 6
        mov r1, VFD_DIGIT_6
        call write_digit

        // digit 7
        mov r1, VFD_DIGIT_7
        call write_digit

        // loop forever
        jmp interrupt_check
//quit:
//        mov r31.b0, PRU0_ARM_INTERRUPT + 16
//        halt

        // run MAX6921 chip at ~5mhz
write_digit:
        // 20-bit shift register count
        mov r14, 20
data:
        // check to see right most bit state
        and r28, r1, 1
        or r28, r28, CLOCK_BIT
        WRITE_DATA 10
        
        // clock
        mov r28, 0
        WRITE_DATA 10

        lsr r1, r1, 1
        sub r14, r14, 1
        qbne data, r14, 0

latch:
        // latch
        mov r28, LATCH_BIT
        WRITE_DATA 10
        ret

update_digit:
        qbne digit_8, r0, 9
        or r1, r1, VFD_SEGMENT_9
digit_8:
        qbne digit_7, r0, 8
        or r1, r1, VFD_SEGMENT_8
digit_7:
        qbne digit_6, r0, 7
        or r1, r1, VFD_SEGMENT_7
digit_6:
        qbne digit_5, r0, 6
        or r1, r1, VFD_SEGMENT_6
digit_5:
        qbne digit_4, r0, 5
        or r1, r1, VFD_SEGMENT_5
digit_4:
        qbne digit_3, r0, 4
        or r1, r1, VFD_SEGMENT_4
digit_3:
        qbne digit_2, r0, 3
        or r1, r1, VFD_SEGMENT_3
digit_2:
        qbne digit_1, r0, 2
        or r1, r1, VFD_SEGMENT_2
digit_1:
        qbne digit_0, r0, 1
        or r1, r1, VFD_SEGMENT_1
digit_0:
        qbne digit_exit, r0, 0
        or r1, r1, VFD_SEGMENT_0
digit_exit:
        ret

// update time in buffer
increment_timer:
        add REG_SECOND_COUNTER_2, REG_SECOND_COUNTER_2, 1
        qbne counter_exit, REG_SECOND_COUNTER_2, 10
        mov REG_SECOND_COUNTER_2, 0

        add REG_SECOND_COUNTER_1, REG_SECOND_COUNTER_1, 1
        qbne counter_exit, REG_SECOND_COUNTER_1, 6
        mov REG_SECOND_COUNTER_1, 0

        add REG_MINUTE_COUNTER_2, REG_MINUTE_COUNTER_2, 1
        qbne counter_exit, REG_MINUTE_COUNTER_2, 10
        mov REG_MINUTE_COUNTER_2, 0

        add REG_MINUTE_COUNTER_1, REG_MINUTE_COUNTER_1, 1
        qbne counter_exit, REG_MINUTE_COUNTER_1, 6
        mov REG_MINUTE_COUNTER_1, 0

        add REG_HOUR_COUNTER_2, REG_HOUR_COUNTER_2, 1
        qbne skip_rollover_check, REG_HOUR_COUNTER_2, 4
        qbne skip_rollover_check, REG_HOUR_COUNTER_1, 2
        
        // midnight
        mov REG_HOUR_COUNTER_1, 0
        mov REG_HOUR_COUNTER_2, 0
skip_rollover_check:
        qbne counter_exit, REG_HOUR_COUNTER_2, 10
        mov REG_HOUR_COUNTER_2, 0

        add REG_HOUR_COUNTER_1, REG_HOUR_COUNTER_1, 1
        qbne counter_exit, REG_HOUR_COUNTER_1, 3
        mov REG_HOUR_COUNTER_1, 0

counter_exit:
        ret
