[bits 32]
[global IDT_Desc]
[global PIT_Int_Handle]
[global IDT_Remap]
[global IDT_Begin]
[global IDT_Add]
[global Kbd_Int_Handle]
[global PIT_Config]

[extern V_FRAME_ADDR]
[extern V_UPDATE]
[extern V_DrawRect]

Kbd_Hooks:
    resd 32 ; 32 possible function pointers

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
    mov ebx, eax

    ; Send a command byte to update PIT
    mov al, 0x36
    out 0x43, al

    mov bx, ax
    and ax, word 0xFF
    out 0x40, al

    mov bx, ax
    shr ax, byte 8
    and ax, word 0xFF
    out 0x40, al

    ret

NC: db 0

PIT_Int_Handle:
    pusha
    inc byte [NC]
    mov bl, byte [NC]
    mov eax, [V_FRAME_ADDR]
    mov [eax], bl
    mov al, 0x20
    out 0x20, al
    popa
    iret

Kbd_Int_Handle:
    pusha
    in al, 0x60
    mov al, 0x20
    out 0x20, al
    popa
    iret

; Hook the keyboard to a function
Kbd_Hook:
