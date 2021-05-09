    mov r8, 10
    call add_one
    call print

    mov r8, 100
    call add_one
    call print

    mov r1, 0
    mov r2, 1000
loop:
    mov r8, r1
    call fib
    call print
    inc r1
    cmp r8, r2
    jl loop
    dw 0

print:
    mov r9, 0xFF01
    mov [r9], r8
    ret

add_one:
    add r8, 1
    ret

fib:
    cmp r8, 0
    je .ret0
    mov r9, 0
    mov r10, 1
.loop:
    sub r8, 1
    jz .ret9
    add r9, r10
    sub r8, 1
    jz .ret8
    add r10, r9
    jmp .loop
.ret0:
    ret
.ret8:
    mov r8, r9
    ret
.ret9:
    mov r8, r10
    ret
