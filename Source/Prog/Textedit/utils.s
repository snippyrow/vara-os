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

; EDI = destination, ESI = source, ECX = # of bytes
memcpy:
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
    ret

; EAX is the uint32, return EAX is ptr for string, 0 if failed
tmpstr_rev: ; reversed
    resb 32
tmpstr: ; modified (non-reversed)
    resb 32
intstr:
    push ebx
    push ecx
    push edx
    push edi
    push esi
    test eax, eax
    jz .iszero
    mov ebx, 10 ; divisor
    mov edi, tmpstr_rev
    xor ecx, ecx ; length counter
.loop:
    test eax, eax
    jz .end ; if there is no more number left
    ; Number in EAX
    xor edx, edx ; clear remainder
    div ebx ; / 10; mod 10
    ; Mod number is in EDX
    add dl, byte '0' ; since mod 10 can never be more than dl
    mov byte [edi], dl
    inc edi
    inc ecx
    jmp .loop
.end:
    ; Reverse copy string
    mov byte [tmpstr + ecx], 0 ; insert EOF at appropriate length
    mov esi, edi
    dec esi
    mov edi, tmpstr
.rev_loop:
    mov al, byte [esi]
    mov byte [edi], al
    dec esi
    inc edi
    dec ecx
    jnz .rev_loop
    jmp .endf
.iszero:
    mov byte [tmpstr], '0'
    mov byte [tmpstr + 1], 0
.endf:
    mov eax, tmpstr
    pop esi
    pop edi
    pop edx
    pop ecx
    pop ebx
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

; Find the current working directory, return EAX = ptr to dir name
cwd_name:
    times 13 db 0
cwd_failed: db "???",0
getcwd:
    ; Find the current directory in the headers, find the parent directory, loop until cluster begin is found and copy name
    mov eax, 0x1A
    mov ebx, 1024 ; 32 items searched max
    int 0x80
    test eax, eax
    jz .end
    push eax ; push ptr

    ; Read the directory into there, re-use for the loop
    mov edi, eax
    mov ebx, dword [running_directory]
    mov ecx, 1
    mov eax, 0x41
    int 0x80

    ; Jump to parent
    ; Navigator should have the first position in any directory
    mov ebx, dword [edi + 16] ; cluster
    ; everything else is the same
    int 0x80

    ; EDI will be the offset
    mov ebx, dword [running_directory]
    mov dx, 32
.loop:
    cmp dword [edi + 16], ebx
    je .found ; if both directories match
    add edi, 32
    dec dx
    jnz .loop
    jmp .failed
.found:
    push edi
    mov edi, cwd_name
    mov al, 0
    mov ecx, 13
    call memset
    pop esi ; to the start of name
    mov edi, cwd_name
    mov ecx, 12
    call memcpy
    jmp .end
.failed:
    ; Free memory
    pop ebx
    mov ecx, 1024
    mov eax, 0x1A
    int 0x80
    mov eax, cwd_failed
    ret
.end:
    ; Free memory
    pop ebx
    mov ecx, 1024
    mov eax, 0x1A
    int 0x80
    mov eax, cwd_name
    ret

; EAX = string A
; EBX = string B
strcat:
    push eax
    mov edi, eax
    call strlen
    add edi, eax ; add length
.addloop:
    mov al, byte [ebx]
    test al, al
    jz .end
    mov byte [edi], al
    inc edi
    inc ebx
    jmp .addloop
.end:
    inc edi
    mov byte [edi], 0
    pop eax
    ret