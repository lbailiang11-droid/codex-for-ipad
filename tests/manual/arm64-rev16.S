// Linux AArch64 regression for the REV16 vector instruction.
// No libc: cross-link this file and run it inside the ARM64 iSH guest.
// Case 2 contains 0x4e201821, the Codex app-server crash instruction.

.text
.global _start

.macro check_vector reg, expected
    str q\reg, [sp]
    ldp x1, x2, [sp]
    adr x0, \expected
    ldp x3, x4, [x0]
    cmp x1, x3
    b.ne failed
    cmp x2, x4
    b.ne failed
.endm

_start:
    sub sp, sp, #16
    adr x19, source

    // The 64-bit forms must clear the destination's nonzero upper half.
    ldr q1, [x19]
    rev16 v1.8b, v1.8b
    check_vector 1, expected_64

    ldr q1, [x19]
    rev16 v1.16b, v1.16b
    check_vector 1, expected_128

    // High-numbered, distinct registers also exercise register addressing.
    ldr q31, [x19]
    ldr q30, [x19]
    rev16 v30.8b, v31.8b
    check_vector 30, expected_64
    check_vector 31, source

    ldr q31, [x19]
    ldr q30, [x19]
    rev16 v30.16b, v31.16b
    check_vector 30, expected_128
    check_vector 31, source

    mov x0, #1
    adr x1, passed_message
    mov x2, #passed_message_len
    mov x8, #64
    svc #0
    mov x0, #0
    b exit

failed:
    mov x0, #2
    adr x1, failed_message
    mov x2, #failed_message_len
    mov x8, #64
    svc #0
    mov x0, #1
exit:
    mov x8, #93
    svc #0

.section .rodata
.balign 16
source:
    .byte 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77
    .byte 0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff
expected_64:
    .byte 0x11, 0x00, 0x33, 0x22, 0x55, 0x44, 0x77, 0x66
    .quad 0
expected_128:
    .byte 0x11, 0x00, 0x33, 0x22, 0x55, 0x44, 0x77, 0x66
    .byte 0x99, 0x88, 0xbb, 0xaa, 0xdd, 0xcc, 0xff, 0xee
passed_message:
    .ascii "REV16 vector: 4 cases passed\n"
.equ passed_message_len, . - passed_message
failed_message:
    .ascii "REV16 vector: register mismatch\n"
.equ failed_message_len, . - failed_message

.section .note.GNU-stack,"",%progbits
