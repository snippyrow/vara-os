; Primary boot manager to facilitate the context switch from shell to windowed mode.
; GUI-based

[bits 32]
[extern win_init]
[global win_redraw]
[global win_width]
[global win_height]
[global win_fillrect]
[global malloc]
[global free]

headers:
    origin_addr: dd 0x800000
    start_addr: dd boot_main
    PID: resd 1
    alive: db 1
    freeze_events: db 1
    running_directory: resd 1
    args: resd 1

boot_main:
    mov bl, 0xf
    mov bh, 0
    mov eax, tesstr
    int 0x70

    call gui_init

    ; Clear the entire screen blue
    mov dl, 0x96 ; bg
    mov eax, 0x12
    xor ebx, ebx
    mov cx, word [win_height]
    shl ecx, 16
    mov cx, word [win_width]
    int 0x80

    mov eax, 0x10
    int 0x80
    
    ; Call a switch
    ; Kill terminal (PID 2)
    mov eax, 0x32
    mov ebx, 2
    int 0x80

    ; De-register all keyboard/pit/stdout hooks
    call dereg

    ; Now switched, jump to the gui written in C


    ; Configure mouse
    mov word [mouse_abs_x], 0x300
    mov word [mouse_abs_y], 0x300
    mov edx, 0x03000300
    call mouse_mask_update

    ; Set-up a mouse
    mov eax, 0x26
    mov ebx, mouse_handler
    int 0x80

    call win_init

    jmp $

    
    ; Now kill myself
    mov eax, 0x32
    mov ebx, dword [PID]
    int 0x80

    mov byte [alive], 0 ; set alive flag
    
    ; yield
.y_loop:
    mov eax, 0x31
    int 0x80
    
    jmp .y_loop
; error: not printing all of the string
tesstr:
    db 10,"Loading window manager..",0

gui_init:
    ; Request critical video information
    mov eax, 0x16
    int 0x80
    ; Move work buffer and font
    mov dword [work_start], ebx
    mov dword [fnt_start], ecx
    mov dword [VBE_Info], eax
    ; Save screen dimensions from VESA info (from REAL bios interrupts)
    mov bx, word [eax + 18]
    mov word [win_width], bx
    mov bx, word [eax + 20]
    mov word [win_height], bx

    mov ebx, dword [eax + 0x28]
    mov dword [frame_start], ebx

    ret

dereg:
    ; Request all hooks
    mov eax, 0x37
    int 0x80

    ; Keyboard
    pusha
    mov ecx, 32
    xor edi, edi
.loop_kbd:
    mov dword [eax + edi], 0
    add edi, 4
    dec ecx
    jnz .loop_kbd
    popa

    ; PIT
    pusha
    mov ecx, 32
    xor edi, edi
.loop_pit:
    mov dword [ebx + edi], 0
    add edi, 4
    dec ecx
    jnz .loop_pit
    popa

    ; STDOUT
    pusha
    mov ebx, 32
    xor edi, edi
.loop_out:
    mov dword [ecx + edi], 0
    add edi, 4
    dec ebx
    jnz .loop_out
    popa

    ret

video_info:
    work_start: resd 1
    fnt_start: resd 1
    VBE_Info: resd 1
    win_width: resw 1
    win_height: resw 1
    frame_start: resd 1

%include "Source/Prog/Boot/mouse.s"
%include "Source/Prog/Boot/utils.s"
%include "Source/Prog/Boot/wrapper.s"