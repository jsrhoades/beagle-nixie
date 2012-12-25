// r0  - routine argument
// r1  - routine argument
// r31 - HOST-to-PRU INTC

#define LOOP_COUNT              20000000
#define PRU1_ARM_INTERRUPT      20
#define PRU1_PRU0_INTERRUPT     18

#define CONST_PRUCFG       c4

.origin 0
.entrypoint start

.macro NOP
        mov     r1, r1
.endm

// 8 clock delay + 2 check
.macro EN_DELAY
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
.endm

start:
        // enable master ocp
        lbco r0, CONST_PRUCFG, 4, 4
        clr r0, r0, 4
        sbco r0, CONST_PRUCFG, 4, 4

sent_interrupt:
        mov r0, LOOP_COUNT

        // send interrupt to PRU0
        mov r31.b0, PRU1_PRU0_INTERRUPT + 16
spin:
        // spin for about a second
        sub r0, r0, 1
        EN_DELAY

        qbne spin, r0, 0
        jmp sent_interrupt

//quit:
//        mov r31.b0, PRU1_ARM_INTERRUPT + 16
//        halt
