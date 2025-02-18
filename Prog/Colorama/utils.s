; EDI = destination, ESI = source, ECX = # of bytes
memcpy:
    test ecx, ecx
    jz .failed ; if ECX = 0, it will roll over and thing will go BAD
    push esi
    push edi
    push ecx
    cld
.loop:
    movsb ; Copy byte from [esi] to [edi], increments both
    dec ecx
    jnz .loop
    pop ecx
    pop edi
    pop esi
.failed:
    ret

; EAX is the uint32, return EAX is ptr for string, 0 if failed
; CL is the mandated number of digits

tstr:
    resb 32
tstr2:
    resb 32
hexstr:
    pusha
    mov edx, eax
    mov edi, tstr2 ; new ptr
    push edi
    push ecx
.loop:
    test edx, edx
    jz .fill ; if the number is over
    mov eax, edx
    mov ch, byte '0'
    and eax, dword 0xF
    cmp al, 9
    jbe .noadd
    ; Add
    mov ch, byte 'A'
    sub al, 10
.noadd:
    add ch, al
    mov byte [edi], ch
    shr edx, 4
    inc edi
    dec cl
    jmp .loop
.fill:
    test cl, cl
    jz .end
    dec cl
    mov byte [edi], byte '0'
    inc edi
    jmp .fill

.end:
    mov byte [edi], 0
    pop ecx
    pop eax ; start vector

    ; Reverse string
    ; Loop until CL is 0
    ; DL is incrementing counter
    and ecx, 0x000000FF
    xor edx, edx
.l:
    test cl, cl
    jz .e
    mov bl, byte [tstr2 + ecx - 1]
    mov byte [tstr + edx], bl
    dec cl
    inc dl
    jmp .l
.e:
    mov byte [tstr + edx], 0
    popa
    mov eax, tstr
    ret

; EDI = destination ptr, al = replace byte, ECX = # of bytes
memset:
    push edi
    push ecx
.loop:
    mov byte [edi], al
    inc edi
    dec ecx
    jnz .loop
    pop ecx
    pop edi
    ret

    