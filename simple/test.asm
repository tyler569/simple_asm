fib:
    cmp r1, 0
    je .ret0
    mov r2, 0
    mov r3, 1

.loop:
    sub r1, 1
    jz .ret9
    add r2, r3
    sub r1, 1
    jz .ret8
    add r3, r2
    jmp .loop

.ret0:
    ret

.ret8:
    mov r1, r2
    ret

.ret9:
    mov r1, r3
    ret
