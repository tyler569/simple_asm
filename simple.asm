fib:
    cmp r8, 0
    je ret0
    mov r12, 0
    mov r13, 1
loop:
    dec r8
    jz ret13
    add r12, r13
    dec r8
    jz ret12
    add r13, r12
    jmp loop
ret0:
    ret
ret12:
    mov r8, r12
    ret
ret13:
    mov r8, r13
    ret
