; SPDX-License-Identifier: MPL-2.0
EXTERN Writer:PROC
EXTERN Wrapper:PROC
PUBLIC Invoke, CallSite, Continuation, Relay

.code
Invoke PROC FRAME
    push rbx
    .pushreg rbx
    push rbp
    .pushreg rbp
    push rsi
    .pushreg rsi
    push rdi
    .pushreg rdi
    push r12
    .pushreg r12
    push r13
    .pushreg r13
    push r14
    .pushreg r14
    push r15
    .pushreg r15
    sub rsp, 0E8h
    .allocstack 0E8h
    movaps [rsp+30h], xmm6
    .savexmm128 xmm6, 30h
    movaps [rsp+40h], xmm7
    .savexmm128 xmm7, 40h
    movaps [rsp+50h], xmm8
    .savexmm128 xmm8, 50h
    movaps [rsp+60h], xmm9
    .savexmm128 xmm9, 60h
    movaps [rsp+70h], xmm10
    .savexmm128 xmm10, 70h
    movaps [rsp+80h], xmm11
    .savexmm128 xmm11, 80h
    movaps [rsp+90h], xmm12
    .savexmm128 xmm12, 90h
    movaps [rsp+0A0h], xmm13
    .savexmm128 xmm13, 0A0h
    movaps [rsp+0B0h], xmm14
    .savexmm128 xmm14, 0B0h
    movaps [rsp+0C0h], xmm15
    .savexmm128 xmm15, 0C0h
    .endprolog

    mov [rsp+20h], rsp
    stmxcsr [rsp+28h]
    fnstcw [rsp+2Ch]
    mov rbx, 21
    mov rbp, 22
    mov rsi, 23
    mov rdi, 24
    mov r12, 25
    mov r13, 26
    mov r14, 27
    mov r15, 28
    pcmpeqd xmm6, xmm6
    pcmpeqd xmm7, xmm7
    pcmpeqd xmm8, xmm8
    pcmpeqd xmm9, xmm9
    pcmpeqd xmm10, xmm10
    pcmpeqd xmm11, xmm11
    pcmpeqd xmm12, xmm12
    pcmpeqd xmm13, xmm13
    pcmpeqd xmm14, xmm14
    pcmpeqd xmm15, xmm15
CallSite LABEL BYTE
    call Writer
Continuation LABEL BYTE
    cmp [rsp+20h], rsp
    jne BadAbi
    cmp rbx, 21
    jne BadAbi
    cmp rbp, 22
    jne BadAbi
    cmp rsi, 23
    jne BadAbi
    cmp rdi, 24
    jne BadAbi
    cmp r12, 25
    jne BadAbi
    cmp r13, 26
    jne BadAbi
    cmp r14, 27
    jne BadAbi
    cmp r15, 28
    jne BadAbi
    pcmpeqd xmm0, xmm0
    movdqa xmm1, xmm6
    pcmpeqb xmm1, xmm0
    pmovmskb edx, xmm1
    cmp edx, 0FFFFh
    jne BadAbi
    movdqa xmm1, xmm7
    pcmpeqb xmm1, xmm0
    pmovmskb edx, xmm1
    cmp edx, 0FFFFh
    jne BadAbi
    movdqa xmm1, xmm8
    pcmpeqb xmm1, xmm0
    pmovmskb edx, xmm1
    cmp edx, 0FFFFh
    jne BadAbi
    movdqa xmm1, xmm9
    pcmpeqb xmm1, xmm0
    pmovmskb edx, xmm1
    cmp edx, 0FFFFh
    jne BadAbi
    movdqa xmm1, xmm10
    pcmpeqb xmm1, xmm0
    pmovmskb edx, xmm1
    cmp edx, 0FFFFh
    jne BadAbi
    movdqa xmm1, xmm11
    pcmpeqb xmm1, xmm0
    pmovmskb edx, xmm1
    cmp edx, 0FFFFh
    jne BadAbi
    movdqa xmm1, xmm12
    pcmpeqb xmm1, xmm0
    pmovmskb edx, xmm1
    cmp edx, 0FFFFh
    jne BadAbi
    movdqa xmm1, xmm13
    pcmpeqb xmm1, xmm0
    pmovmskb edx, xmm1
    cmp edx, 0FFFFh
    jne BadAbi
    movdqa xmm1, xmm14
    pcmpeqb xmm1, xmm0
    pmovmskb edx, xmm1
    cmp edx, 0FFFFh
    jne BadAbi
    movdqa xmm1, xmm15
    pcmpeqb xmm1, xmm0
    pmovmskb edx, xmm1
    cmp edx, 0FFFFh
    jne BadAbi
    stmxcsr [rsp+0D0h]
    mov edx, [rsp+0D0h]
    xor edx, [rsp+28h]
    test edx, 0FFC0h
    jne BadAbi
    fnstcw [rsp+2Eh]
    mov dx, [rsp+2Eh]
    cmp dx, [rsp+2Ch]
    jne BadAbi
    jmp Restore
BadAbi:
    mov eax, -1
Restore:
    movaps xmm6, [rsp+30h]
    movaps xmm7, [rsp+40h]
    movaps xmm8, [rsp+50h]
    movaps xmm9, [rsp+60h]
    movaps xmm10, [rsp+70h]
    movaps xmm11, [rsp+80h]
    movaps xmm12, [rsp+90h]
    movaps xmm13, [rsp+0A0h]
    movaps xmm14, [rsp+0B0h]
    movaps xmm15, [rsp+0C0h]
    add rsp, 0E8h
    pop r15
    pop r14
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rbp
    pop rbx
    ret
Invoke ENDP

; Leaf relay. RSP and all argument registers are untouched.
Relay PROC
    jmp Wrapper
Relay ENDP
END
