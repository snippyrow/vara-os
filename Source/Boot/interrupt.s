[bits 32]
[global IDT_Desc]
[global PIT_Int_Handle]
[global IDT_Remap]
[global IDT_Begin]
[global IDT_Add]
[global Kbd_Int_Handle]
[global PIT_Config]
[global Kbd_Hooks]
[global Kbd_Test]
[global PIT_Hooks]
[global Stdout_Int_Handle]
[global STDOUT_Hooks]

[extern V_FRAME_ADDR]
[extern V_UPDATE]
[extern V_DrawRect]
[extern V_DrawChar]
[extern malloc]
[extern free]

IDT_Remap:
    ; Re-map the master & slave PIC. How does it work? 
    mov al, 0x11
    out 0x20, al
    out 0xA0, al

    ; ICW2
    mov al, 0x20
    out 0x21, al
    mov al, 0x28
    out 0xA1, al

    ; ICW3
    mov al, 4
    out 0x21, al
    mov al, 0x28
    out 0xA1, al

    ; ICW4
    mov al, 1
    out 0x21, al
    out 0xA1, al

    ; OCW1
    mov al, 0
    out 0x21, al
    out 0xA1, al

    ; Mask interrupts
    mov al, 0b11111011 ; mask everything but cascade
    out 0x21, al
    mov al, 0b11111111 ; mask all
    out 0xA1, al

    ret

IDT_Begin:
    resq 256 ; 256 items x 8 bytes each

IDT_Desc:
    dw (0xFF * 8) - 1
    dd IDT_Begin

; expects arguments for the function address and the interrupt gate
; (1) Gate_addr, (2) Int_num
IDT_Add:
    mov [.r_eax], eax
    mov [.r_ebx], ebx
    mov eax, [esp + 4]
    mov bl, byte 8
    mul bl
    add eax, IDT_Begin

    mov ebx, [esp + 8]
    and ebx, dword 0x0000FFFF
    mov [eax], bx ; low word of address

    mov [eax + 2], word 0x8 ; code segment in GDT
    mov [eax + 5], byte 0x8E ; flags are always the same for these IDT gates

    mov ebx, [esp + 8]
    shr ebx, byte 16
    and ebx, dword 0x0000FFFF
    mov [eax + 6], bx ; high word of address
    mov eax, [.r_eax]
    mov ebx, [.r_ebx]
    ret

.r_eax:
    resb 4

.r_ebx:
    resb 4

; Frequency stays in eax
PIT_Config:
    mov ebx, eax
    mov eax, dword 1193182
    xor edx, edx
    div ebx
    mov bx, ax

    ; Send a command byte to update PIT
    mov al, 0x36
    out 0x43, al

    mov al, bl
    out 0x40, al
    
    mov al, bh
    out 0x40, al

    ret

NC: db 0

PIT_Hooks:
    ;dd Test_PIT
    times 32 dd 0 ; 32 possible func ptrs

PIT_Int_Handle:
    cli
    pusha
    xor eax, eax
    mov cl, byte 0 ; Loop counter for iteration
    mov edi, PIT_Hooks
.iterate:
    cmp cl, byte 32
    je .end
    mov ebx, dword [edi]
    test ebx, ebx
    jz .skip
    pusha
    call ebx
    popa
.skip:
    inc cl
    add edi, 4
    jmp .iterate
.end:
    mov al, 0x20
    out 0x20, al
    popa
    sti
    iret

Test_PIT:
    inc byte [NC]
    mov bl, byte [NC]
    mov eax, [V_FRAME_ADDR]
    mov [eax], bl
    ret

Kbd_Hooks:
    times 32 dd 0 ; 32 possible function pointers

; CL  = loop counter (up to 32)
; EDI = function vector
Kbd_Int_Handle:
    cli
    pusha
    xor eax, eax
    in al, 0x60
    mov cl, byte 0 ; Loop counter for iteration
    mov edi, Kbd_Hooks
.iterate:
    cmp cl, byte 32
    je .end
    mov ebx, dword [edi]
    test ebx, ebx
    jz .skip
    pusha
    ; scancode is already in AL, and is restored after the function
    call ebx
    popa
.skip:
    inc cl
    add edi, 4
    jmp .iterate
.end:
    mov al, 0x20
    out 0x20, al
    popa
    sti
    iret


NCD: resd 1

Kbd_Test:
    mov eax, 0x13
    mov ebx, 0x00500020
    mov cl, 'A'
    mov ch, 0xf
    int 0x80
    
    mov eax, 64
    call malloc
    mov dword [NCD], eax

    cmp eax, 0
    jne .true
.false:
    mov cl, 'F'
    jmp .end
.true:
    mov cl, 'T'

    mov eax, dword [NCD]
    mov ebx, 64
    call free

.end:
    mov eax, 0x13
    mov ebx, 0x00900020
    mov ch, 0xf
    int 0x80

    mov eax, 0x10
    int 0x80

    ret

; STDOUT manager
STDOUT_Hooks:
    times 64 dd 0 ; 64 possible function pointers

; EAX contains the thing that needs forwarding
Stdout_Int_Handle:
    cli
    pusha
    ; EAX is preserved
    mov cl, byte 0 ; Loop counter for iteration
    mov edi, STDOUT_Hooks
.iterate:
    cmp cl, byte 64
    je .end
    mov ebx, dword [edi]
    test ebx, ebx
    jz .skip
    pusha
    ; scancode is already in AL, and is restored after the function
    call ebx
    popa
.skip:
    inc cl
    add edi, 4
    jmp .iterate
.end:
    popa
    sti
    iret

