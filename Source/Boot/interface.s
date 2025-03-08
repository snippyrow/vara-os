[bits 16]
[extern PIT_Int_Handle]
[extern IDT_Desc]
[extern IDT_Begin]
[extern IDT_Remap]
[extern IDT_Add]
[extern Kbd_Int_Handle]
[extern PIT_Config]
[extern ata_lba_read]
[extern Kernel_Start]

[global V_FRAME_ADDR]
[global Test_Proc]
[global V_UPDATE]
[global V_DrawRect]
[global V_WORK_BUFF]
[global V_DrawString]
[global V_TEST_B]
[global V_FNT_BUFF]
[global V_DrawChar]
[global VBE_Info]
[global V_DrawRectRaw]
[global V_DrawPixel]


; Linked kernel starts here.
; 0x100 (640x400)
; 0x101 (640x480)
; 0x103 (800x600)
; 0x105 (1024x768)
; 0x107 (1280x1024)

VBE_RES equ 0x107 ; 1280×1024
SCREEN_WIDTH equ 1280
V_WORK_BUFF equ 0x100000
V_FNT_BUFF equ 0x7E00 + (40 * 512)


start:
    ; Find VBE display information
    mov ax, 0x4F02 ; VESA set video mode function
    mov bx, VBE_RES
    int 0x10

    ; Save VBE information into VBE_Info (0:VBE_Info)
    mov ax, 0
    mov es, ax
    mov ax, 0x4F01
    mov cx, VBE_RES
    mov di, VBE_Info ; Address to store the mode info structure
    int 0x10 ; Call BIOS

    ; Enable A20 Line (thanks osdever)
    in al, 0x92
    or al, 2
    out 0x92, al

    ; Begin jumping to protected mode
    cli ; Disable all interrupts
    lgdt [GDT_Desc]
    mov eax, cr0 
    or al, 1       ; set PE (Protection Enable) bit in CR0 (Control Register 0)
    mov cr0, eax

    jmp 0x08:PMode_Start ; 0x08 is the code segment and address

[bits 32]
PMode_Start:
    ; Move new data segment
    mov ax, 0x10
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    mov esp, 0x90000 ; set stack far away, inside the data segment

    ; Move VBE variables
    mov eax, dword [VBE_Info + 0x28]
    mov [V_FRAME_ADDR], eax

    mov ax, word [VBE_Info + 18]
    mov [V_WIDTH], ax
    mov ax, word [VBE_Info + 20]
    mov [V_HEIGHT], ax

    xor eax, eax
    xor ebx, ebx
    mov ax, [V_WIDTH]
    mov bx, [V_HEIGHT]
    mul ebx
    mov [V_PX], eax


    jmp 0x08:Kernel_Start


; Video functions

; Update the work buffer to the VESA display buffer
; (single-byte per pixel only!)
V_UPDATE:
    pusha
    mov eax, [V_FRAME_ADDR]
    mov edx, [V_PX]
    mov ecx, 0
.loop:
    inc ecx

    mov bl, byte [V_WORK_BUFF + ecx]
    mov [eax + ecx], bl
    cmp ecx, edx
    je .end
    jmp .loop
.end:
    popa
    ret

; Draw a rectangle in the work buffer.
; Higher eax is x0, lower eax is y0, higher ebx is x1, lower ebx is y1
; cl is the pixel color
V_DrawRect:
    pusha                    ; Save all general-purpose registers
    ; Extract inputs from registers
    movzx esi, ax            ; Extract x0 (low word of EAX) into ESI
    shr eax, 16              ; Shift x0 out, leaving y0 in EAX
    movzx ebp, ax            ; Extract y0 into EBP

    movzx edi, bx            ; Extract x1 (low word of EBX) into EDI
    shr ebx, 16              ; Shift x1 out, leaving y1 in EBX
    movzx edx, bx            ; Extract y1 into EDX

    mov bl, cl

.loop_y:                     ; Outer loop for rows (y)
    cmp ebp, edx             ; Check if y0 > y1
    jg .end                  ; End if all rows are processed

    mov ecx, esi             ; Load x0 into ECX for inner loop

.loop_x:                     ; Inner loop for columns (x)
    cmp ecx, edi             ; Check if x0 > x1
    jg .next_row             ; Go to the next row if done with the current row

    ; Calculate pixel position in work buffer
    mov eax, ebp             ; Get current y position
    imul eax, SCREEN_WIDTH   ; Multiply y by screen width
    add eax, ecx             ; Add x position
    mov byte [V_WORK_BUFF + eax], bl ; Write pixel color

    inc ecx                  ; Increment x (column)
    jmp .loop_x              ; Continue inner loop

.next_row:
    inc ebp                  ; Increment row (y)
    jmp .loop_y              ; Continue outer loop
.end:
    popa                     ; Restore all registers
    ret                      ; Return to caller

; Draw a rectangle in the raw frame buffer.
; Higher eax is x0, lower eax is y0, higher ebx is x1, lower ebx is y1
; cl is the pixel color
V_DrawRectRaw:
    pusha ; Save all general-purpose registers
    ; Extract inputs from registers
    movzx esi, ax ; Extract x0 (low word of EAX) into ESI
    shr eax, 16 ; Shift x0 out, leaving y0 in EAX
    movzx ebp, ax ; Extract y0 into EBP

    movzx edi, bx ; Extract x1 (low word of EBX) into EDI
    shr ebx, 16 ; Shift x1 out, leaving y1 in EBX
    movzx edx, bx ; Extract y1 into EDX

    mov bl, cl

.loop_y: ; Outer loop for rows (y)
    cmp ebp, edx ; Check if y0 > y1
    jg .end ; End if all rows are processed

    mov ecx, esi ; Load x0 into ECX for inner loop

.loop_x: ; Inner loop for columns (x)
    cmp ecx, edi ; Check if x0 > x1
    jg .next_row ; Go to the next row if done with the current row

    ; Calculate pixel position in work buffer
    mov eax, ebp ; Get current y position
    imul eax, SCREEN_WIDTH ; Multiply y by screen width
    add eax, ecx ; Add x position
    add eax, dword [V_FRAME_ADDR] ; Add frame buffer address
    mov byte [eax], bl ; Write pixel color

    inc ecx ; Increment x (column)
    jmp .loop_x ; Continue inner loop

.next_row:
    inc ebp ; Increment row (y)
    jmp .loop_y ; Continue outer loop
.end:
    popa ; Restore all registers
    ret ; Return to caller

; High EAX is X coordinate, Low EAX is Y coordinate
; bl is the character code, bh is the font color

V_DrawChar:
    ; EDI contains offset within the font buffer
    pusha
    xor esi, esi
    xor ebp, ebp
    movzx esi, ax ; X
    and eax, dword 0xFFFF0000
    shr eax, byte 16
    movzx ebp, ax ; Y

    mov ch, bh

    xor edi, edi
    sub bl, byte 32
    movzx edi, bl
    imul edi, dword 16


    mov eax, ebp
    xor ebx, ebx
    movzx ebx, word [V_WIDTH] ; must be a constant for some reason, otherwise bugs out Y coordinates
    mov bp, word [V_WIDTH]
    mul ebx
    add eax, esi

    ; EAX now contains absolute corner

    mov cl, byte 0 ; total line counter
    mov ebx, dword 0 ; byte index counter
.loop_y:
    movzx dx, byte [V_FNT_BUFF + edi]
.loop_b:
    bt dx, bx
    jnc .continue
    ; Draw the pixel
    mov [V_WORK_BUFF + eax + ebx], byte ch
.continue:
    inc ebx
    cmp ebx, dword 8
    je .endb
    jmp .loop_b
.endb:
    xor ebx, ebx
    inc cl
    inc edi
    add eax, ebp
    cmp cl, byte 16
    je .end
    jmp .loop_y
.end:
    popa
    ret

V_DrawPixel:
    movzx esi, ax ; move X coordinate
    shr eax, 16 ; shift Y into the first part and multiply by the width of each line
    movzx ebx, word [V_WIDTH]
    mul ebx
    add eax, esi ; add in the X coordinate
    mov byte [V_WORK_BUFF + eax], cl
    ret


; Low EAX is X coordinate, High EAX is Y coordinate
; ESI is the string pointer
V_DrawString:
    pusha
.loop:
    mov bl, [esi]
    cmp bl, 0
    je .end

    ; If not EOF, print the character
    call V_DrawChar
    add eax, dword 8
    inc esi
    jmp .loop
.end:
    popa
    ret


; Data structures

V_TEST_B:
    times 0xff db 0xd

VBE_Info:
    resb 256

V_PX:
    dd 0
V_WIDTH:
    resb 2
V_HEIGHT:
    resb 2
V_FRAME_ADDR:
    resb 4


; Defines one data segment and one code segment spanning the entire map
; Flat memory model
GDT_Start:
    GDT_NULL:
        dq 0
    GDT_CODE:
        dw 0xffff     ; Limit
        dw 0x0000     ; Base addr
        db 0x00       ; Base addr
        db 0b10011010 ; Access byte (Present, kernel, segment, code, not executable, RW, Reserved)
        db 0b11001111 ; Flags & Limit
        db 0x00       ; Base
    GDT_DATA:
        dw 0xffff     ; Limit
        dw 0x0000     ; Base addr
        db 0x00       ; Base addr
        db 0b10010010 ; Access byte
        db 0b11001111 ; Flags & Limit
        db 0x00       ; Base
GDT_End:

GDT_Desc:
    dw GDT_End-GDT_Start
    dq GDT_Start

; TODO:
    ; Disk reader
    ; Task system
    ; File system
    ; Memory allocator (copy from C)

; The end?
; A re-usable boot loader, pre-initates protected mode, video mode etc
; Comes with a hard drive reader and other utilities for a protected mode application
; Basic framework