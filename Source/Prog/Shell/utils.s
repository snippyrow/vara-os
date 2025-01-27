; EAX is ptr of string, return EAX is the length
; Returns the position of the null-terminator
strlen:
    push ebx
    push ecx
    xor ebx, ebx ; loop counter for length
.loop:
    mov cl, byte [eax]
    test cl, cl
    jz .end
    ; If not zero, inc and redo
    inc ebx
    inc eax
    jmp .loop
.end:
    mov eax, ebx
    pop ecx
    pop ebx
    ; EAX has cntr
    ret

; EAX = ptr A, EBX = ptr B, return EAX = T/F (case sensetive)
strcmp:
    push ecx
    push edx
    xor ecx, ecx
.loop:
    mov dl, byte [eax + ecx]
    mov dh, byte [ebx + ecx]
    cmp dl, dh
    jne .end_f
    test dl, dl
    jz .end_t
    inc ecx
    jmp .loop
.end_f:
    pop edx
    pop ecx
    xor eax, eax ; false
    ret
.end_t:
    pop edx
    pop ecx
    mov eax, dword 1 ; true
    ret

; EAX = ptr of the string, destructivly makes it go lowercase
strlow:
    push ebx
.loop:
    mov bl, byte [eax]
    test bl, bl
    jz .end
    cmp bl, byte 'A'
    jae .r1
    jmp .continue
.r1:
    cmp bl, byte 'Z'
    jbe .r2
    jmp .continue
.r2:
    add bl, byte 32
    mov byte [eax], bl
.continue:
    inc eax
    jmp .loop
.end:
    pop ebx
    ret

; EAX is string ptr, return EAX is uint32. Hex values not accepted
strint:
    push esi
    push ebx
    push ecx
    mov esi, eax
    xor eax, eax
    xor ecx, ecx
.loop:
    mov cl, byte [esi]
    test cl, cl
    jz .end
    cmp cl, byte '0'
    jb .resume
    cmp cl, byte '9'
    ja .resume
    
    ; x10
    mov ebx, eax
    shl eax, 3
    shl ebx, 1
    add eax, ebx

    sub cl, byte '0'
    add eax, ecx

; If not in range
.resume:
    inc esi
    jmp .loop
.end:
    pop ecx
    pop ebx
    pop esi
    ret

; EAX is the uint32, return EAX is ptr for string, 0 if failed
; CL is the mandated number of digits


tstr:
    resb 32
tstr2:
    resb 32
hexstr:
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
    mov eax, tstr
    ret

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