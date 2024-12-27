[bits 32]
[global Kernel_Start]
[extern PIT_Config]
[extern V_WORK_BUFF]
[extern V_DrawRect]
[extern V_UPDATE]
[extern V_TEST_B]
[extern PIT_Int_Handle]
[extern IDT_Add]
[extern Kbd_Int_Handle]
[extern ata_lba_read]
[extern IDT_Remap]
[extern IDT_Desc]
[extern V_DrawString]
[extern Sys_Int_Handle]
[extern V_DrawChar]
[extern VBE_Info]
[extern V_FNT_BUFF]

Kernel_Start:
    ; IDT Has been defined, populate it with components

    ; Map PIT to the handler
    ; PIT will be used for task scheduling
    ; First grab ptr to the IDT entry and populate the stuff

    push dword PIT_Int_Handle
    push dword 32
    call IDT_Add
    add esp, 8

    push dword Kbd_Int_Handle
    push dword 33
    call IDT_Add
    add esp, 8

    ; Start up core interrupt
    push dword Sys_Int_Handle
    push dword 0x80
    call IDT_Add
    add esp, 8
    
    call IDT_Remap

    lidt [IDT_Desc]

    ; Change PIT frequency to 20hz
    mov eax, 20
    call PIT_Config


    ;mov al, 0b11111010 ; Unmask cascade and KBD
    mov al, 0b11111000
    out 0x21, al

    sti

    ; Draw a rect
    mov [V_WORK_BUFF + 15], byte 0xf
    mov eax, dword 0x00100010
    mov ebx, dword 0x01200300
    mov cl, byte 0xc
    call V_DrawRect
    call V_UPDATE


    mov eax, dword 0 ; location of buffer
    mov edi, V_TEST_B          ; Starting LBA
    mov cl, 1           ; # of sectors to read
    call ata_lba_read


    mov esi, test_str
    mov eax, 0x00400020
    mov bh, byte 0xf
    call V_DrawString



    ; Test print the array
    mov ecx, 0
    mov eax, V_TEST_B
.loop:
    cmp ecx, 0xff
    je .end
    mov bl, byte [eax]
    mov [V_WORK_BUFF + ecx + 1280], bl
    inc eax
    inc ecx
    jmp .loop
.end:
    call V_UPDATE
    jmp $

test_str:
    db "Hello, world!",0


; Primary syscall handler
; EAX has the interrupt vector, specifically.
; Syscalls may include drawing shapes, updating screen, requesting video data and such and such.

; LIST:
;   EAX 0x10 = Update screen from work buffer
;   EAX 0x12 = Draw rectangle (ebx = [x0, y0], ecx = [x1, y1], dl = color)
;   EAX 0x13 = Draw default 8x16 character (ebx = [x,y], cl = char, ch = color)
;   EAX 0x16 = Get display information (return eax = VESA information vector, return ebx = work buffer start vector, return vector ecx = default font buffer)
;   EAX 0x18 = ATA LBA read to vector (ebx = LBA start address, cl = # of sectors to read, edi = buffer start address)
Sys_Int_Handle:
    cmp eax, dword 0x10
    je .v_render
    cmp eax, dword 0x12
    je .v_render_rect
    cmp eax, dword 0x13
    je .v_render_dchar
    cmp eax, dword 0x16
    je .v_ret_info
    cmp eax, dword 0x18
    je .ata_read
    iret
.v_render:
    pusha
    call V_UPDATE
    popa
    iret
.v_render_rect:
    pusha
    mov eax, ebx
    mov ebx, ecx
    mov cl, dl
    call V_DrawRect
    popa
    iret
.v_render_dchar:
    pusha
    mov eax, ebx
    mov bl, cl
    mov bh, ch
    call V_DrawChar
    popa
    iret
.v_ret_info:
    mov eax, VBE_Info
    mov ebx, V_WORK_BUFF
    mov ecx, V_FNT_BUFF
    iret
.ata_read:
    pusha
    mov eax, ebx
    call ata_lba_read
    popa
    iret