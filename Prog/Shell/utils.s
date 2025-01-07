; EAX is ptr of string, return EAX is the length
; Returns the position of the null-terminator
strlen:
    push ebx
    push ecx
    mov ebx, dword 0 ; loop counter for length
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