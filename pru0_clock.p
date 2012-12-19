// r0  - routine argument
// r1  - routine argument
// r2  - digit #1 
// r3  - digit #2
// r4  - digit #3
// r5  - digit #4
// r6  - digit #5
// r7  - digit #6
// r8  - digit #7
// r9  - digit #8
// r10 - digit #9
// r11 - run status
// r12 - counter
// r13 - data out
// r29 - return pointer
// r30 - GPO PRU0
// r31 - HOST-to-PRU INTC 

#define PRU0_ARM_INTERRUPT      19
#define ARM_PRU0_INTERRUPT      21

#define DATA_BIT           1<<0
#define CLOCK_BIT          1<<5
#define LATCH_BIT          1<<1

#define CONST_PRUCFG       c4
#define CONST_PRUDRAM      c24

#define CONST_PRUSSINTC    c0
#define SICR_OFFSET        0x24

#define CTBIR_0            0x22020
#define RET_POINTER        r27.w0
#define GPO_PRU0_REG       r30

#define VFD_DIGIT1         r2
#define VFD_DIGIT2         r3
#define VFD_DIGIT3         r4
#define VFD_DIGIT4         r5
#define VFD_DIGIT5         r6
#define VFD_DIGIT6         r7
#define VFD_DIGIT7         r8
#define VFD_DIGIT8         r9
#define VFD_DIGIT9         r10
#define NUM_DIGITS         9

#define RUN_STATUS         r11.t0
#define VFD_BUFFER_SIZE    4 * NUM_DIGITS

.setcallreg RET_POINTER
.origin 0
.entrypoint start

.macro PULSE
        mov     r30, r13
.endm

// 10 clock cycle delay
.macro EN_PULSE
        PULSE
        PULSE
        PULSE
        PULSE
        PULSE
        PULSE
        PULSE
        PULSE
        PULSE
        PULSE
        PULSE
.endm

// EN_PULSE + 3 clock cycle delay
.macro WRITE_DATA
.mparam update_count
        mov r0, update_count
update_begin:
        EN_PULSE

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

update_buffer:
        // clear intterupt
        ldi r0.w2, 0
        ldi r0.w0, ARM_PRU0_INTERRUPT
        sbco r0, CONST_PRUSSINTC, SICR_OFFSET, 4 

        // copy over buffer
        lbco VFD_DIGIT1, CONST_PRUDRAM, 0, VFD_BUFFER_SIZE + 4
        qbbc quit, RUN_STATUS

        // clear everything
        mov r1, 0
        call write_digit

interrupt_check:
        qbbs update_buffer, r31, 30

update_vfd:
        // digit 1
        mov r1, VFD_DIGIT1
        call write_digit

        // digit 2
        mov r1, VFD_DIGIT2
        call write_digit

        // digit 3
        mov r1, VFD_DIGIT3
        call write_digit

        // digit 4
        mov r1, VFD_DIGIT4
        call write_digit

        // digit 5
        mov r1, VFD_DIGIT5
        call write_digit 

        // digit 6
        mov r1, VFD_DIGIT6
        call write_digit

        // digit 7
        mov r1, VFD_DIGIT7
        call write_digit

        // digit 8
        mov r1, VFD_DIGIT8
        call write_digit

        // digit 9
        mov r1, VFD_DIGIT9
        call write_digit

        // loop forever
        jmp interrupt_check
quit:
        // clear display
        mov r1, 0
        call write_digit

        mov r31.b0, PRU0_ARM_INTERRUPT + 16
        halt

        // run MAX6921 chip at ~5mhz
write_digit:
        // 20-bit shift register count
        mov r12, 20
data:
        // check to see right most bit state
        and r13, r1, 1
        or r13, r13, CLOCK_BIT
        WRITE_DATA 10
        
        // clock
        mov r13, 0
        WRITE_DATA 10

        lsr r1, r1, 1
        sub r12, r12, 1
        qbne data, r12, 0
latch:
        // latch
        mov r13, LATCH_BIT
        WRITE_DATA 10
        ret
