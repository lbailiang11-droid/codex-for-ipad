// Eight threads repeatedly create and close socket pairs in one fd table.
// This exercises peer_lock <-> files->lock inversion without libc or a model.
.text
.global _start
_start:
    mov x20, #7
    adr x21, stacks
1:
    add x21, x21, #65536
    mov x1, x21
    mov x0, #0x0f00
    movk x0, #5, lsl #16
    mov x2, #0
    mov x3, #0
    mov x4, #0
    mov x8, #220 // clone(CLONE_VM|FS|FILES|SIGHAND|THREAD|SYSVSEM)
    svc #0
    cmp x0, #0
    b.lt failed
    b.eq worker
    subs x20, x20, #1
    b.ne 1b
    bl race
2:
    adr x9, done
    ldar w10, [x9]
    cmp w10, #7
    b.eq passed
    mov x0, #0
    mov x8, #124 // sched_yield
    svc #0
    b 2b
worker:
    bl race
    adr x9, done
3:
    ldaxr w10, [x9]
    add w10, w10, #1
    stlxr w11, w10, [x9]
    cbnz w11, 3b
    mov x0, #0
    mov x8, #93 // exit this thread only
    svc #0
race:
    stp x22, x30, [sp, #-32]!
    mov x22, #2000
4:
    mov x0, #1 // AF_UNIX
    mov x1, #1
    movk x1, #8, lsl #16 // SOCK_STREAM | SOCK_CLOEXEC
    mov x2, #0
    add x3, sp, #16
    mov x8, #199 // socketpair
    svc #0
    cbnz x0, failed
    ldr w0, [sp, #16]
    mov x8, #57 // close
    svc #0
    cbnz x0, failed
    ldr w0, [sp, #20]
    mov x8, #57
    svc #0
    cbnz x0, failed
    subs x22, x22, #1
    b.ne 4b
    ldp x22, x30, [sp], #32
    ret
passed:
    mov x0, #1
    adr x1, pass_message
    mov x2, #pass_length
    mov x8, #64
    svc #0
    mov x0, #0
    mov x8, #94
    svc #0
failed:
    mov x0, #2
    adr x1, fail_message
    mov x2, #fail_length
    mov x8, #64
    svc #0
    mov x0, #1
    mov x8, #94
    svc #0
.section .rodata
pass_message: .ascii "PASS: 16000 concurrent socketpair/close cycles\n"
.equ pass_length, . - pass_message
fail_message: .ascii "FAIL: socketpair race syscall\n"
.equ fail_length, . - fail_message
.bss
.balign 16
done: .skip 16
stacks: .skip 458752
