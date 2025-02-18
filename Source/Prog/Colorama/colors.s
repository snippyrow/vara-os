[bits 32]
[org 300000] ; keep clear of stack!

; basically ENV variables
headers:
    origin_addr: dd 300000
    start_addr: dd boot_main
    PID: resd 1
    alive: db 1
    freeze_events: db 1 ; optional, freeze shell events such as a blinking cursor
    running_directory: resd 1
    args: resd 1

; in px
SQUARE_WIDTH equ 32
SQUARE_MARGIN equ 6
ctrl: db 0

keyboard_handler:
    cmp al, byte 0x1D
    je .ctrl
    cmp al, byte 0x9D
    je .unctrl

    cmp al, byte 0x2E
    je .shouldkill
.end:
    ret

.ctrl:
    mov byte [ctrl], 1
    ret
.unctrl:
    mov byte [ctrl], 0
    ret
.shouldkill:
    cmp byte [ctrl], 0
    je .end
    mov byte [alive], 0
    ret

; check for a mouse moved
; For brevity, split into 38x38px blocks and encode position
; For some reason the divide is making it lag
mouse_move:
    ret
    xor eax, eax
    mov ax, word [mouse_abs_x]
    mov bx, word [win_width]
    shr bx, 1
    sub bx, ((SQUARE_WIDTH + SQUARE_MARGIN) * 16) / 2
    mov cx, bx
    add cx, (SQUARE_WIDTH + SQUARE_MARGIN) * 16
    ; BX now contains size between window border and square start
    cmp ax, bx
    jb .end
    cmp ax, cx
    jae .end

    add ax, bx
    xor edx, edx
    mov ebx, 38
    div ebx
    mov dl, al
    xor ebx, ebx
    mov cx, 0x50
    shl ecx, 16
    mov cx, word [win_width]
    int 0x80
    mov eax, 0x12
    int 0x80
    mov eax, 0x10
    int 0x80
    mov dx, word [mouse_abs_x]
    shl edx, 16
    mov dx, word [mouse_abs_y]
    call mouse_render

    
.end:
    ret


boot_main:
    call gui_init

    ; Register a keyboard handler
    mov eax, 0x20
    mov ebx, keyboard_handler
    int 0x80

    ; Configure mouse
    mov word [mouse_abs_x], 0x300
    mov word [mouse_abs_y], 0x300
    mov edx, 0x03000300
    call mouse_mask_update

    ; Set-up a mouse
    mov eax, 0x26
    mov ebx, mouse_handler
    int 0x80

    ; Draw a basic rectangle background
    mov eax, 0x12
    xor ebx, ebx
    mov cx, word [win_height]
    shl ecx, 16
    mov cx, word [win_width]
    mov dl, 0x13
    int 0x80

    ; Each color is represented in a 16x16 grid
    ; Each square is a 32x32px square + 6px border
    ; outer square is 38 x 16 + 6 (offset for center)
    mov bx, word [win_height]
    shr bx, 1 ; / 2
    shl ebx, 16
    mov bx, word [win_width]
    shr bx, 1
    ; Now EBX has the center
    mov ecx, ebx
    sub ebx, (((((SQUARE_WIDTH + SQUARE_MARGIN) * 16) + SQUARE_MARGIN) / 2) << 16) + ((((SQUARE_WIDTH + SQUARE_MARGIN) * 16) + SQUARE_MARGIN) / 2)
    add ecx, (((((SQUARE_WIDTH + SQUARE_MARGIN) * 16) + SQUARE_MARGIN) / 2) << 16) + ((((SQUARE_WIDTH + SQUARE_MARGIN) * 16) + SQUARE_MARGIN) / 2)
    mov dl, 0x15
    int 0x80

; loop over the squares for the X
    ; Init EBX & ECX, use al/ah to deal with counters
    ; EBX is already at the corner
    add ebx, (SQUARE_MARGIN << 16) + SQUARE_MARGIN
    mov ecx, ebx
    add ecx, (SQUARE_WIDTH << 16) + SQUARE_WIDTH
    mov dl, 0xc
    mov al, 16
    mov ah, 16
    mov byte [current_color], 0

.loop_x:
    push ax
    mov eax, 0x12
    mov dl, byte [current_color]
    int 0x80
    pop ax
    dec al
    jz .end_ln
    add ebx, SQUARE_WIDTH + SQUARE_MARGIN
    add ecx, SQUARE_WIDTH + SQUARE_MARGIN
    inc byte [current_color]
    jmp .loop_x
.end_ln:
    dec ah
    jz .end_square
    ; Otherwise next line
    sub ebx, (SQUARE_WIDTH + SQUARE_MARGIN) * 15 ; go back 16 steps
    sub ecx, (SQUARE_WIDTH + SQUARE_MARGIN) * 15
    add ebx, (SQUARE_WIDTH + SQUARE_MARGIN) << 16
    add ecx, (SQUARE_WIDTH + SQUARE_MARGIN) << 16
    mov al, 16
    jmp .loop_x
.end_square:
    ; Now draw the codes
    ; Draw the top line first, starting at the top-left corner going across
    ; Best to use kernel for this
    ; Use DL for counting stuff
    mov dl, 16 ; counter
    xor dh, dh

    ; Set up 2d coordinates
    mov bx, word [win_height]
    shr bx, 1
    shl ebx, 16
    mov bx, word [win_width]
    shr bx, 1
    push ebx
    sub ebx, ((((SQUARE_WIDTH + SQUARE_MARGIN) * 16) / 2) + 18 << 16) + (((SQUARE_WIDTH + SQUARE_MARGIN) * 16) / 2) - 6
.loop_top:
    mov cl, byte '$'
    mov ch, 0xf
    mov eax, 0x13
    int 0x80
    add ebx, 8
    mov cl, byte '0'
    int 0x80
    add ebx, 8
    ; Now add 'a' if >9
    cmp dh, 9
    ja .adda
    mov cl, byte '0'
    add cl, dh
.prta:
    int 0x80
    add ebx, (SQUARE_WIDTH + SQUARE_MARGIN) - 16
    inc dh
    dec dl
    jnz .loop_top

    ; Now loop down the corner
    pop ebx ; center of square
    sub ebx, ((((SQUARE_WIDTH + SQUARE_MARGIN) * 16) / 2) - 12 << 16) + (((SQUARE_WIDTH + SQUARE_MARGIN) * 16) / 2) + 30
    mov dl, 16
    xor dh, dh
.loop_side:
    mov cl, byte '$'
    mov ch, 0xf
    mov eax, 0x13
    int 0x80
    cmp dh, 9
    ja .addb
    mov cl, byte '0'
    add cl, dh
.prtb:
    add bx, 8
    int 0x80
    mov cl, '0'
    add bx, 8
    int 0x80
    add ebx, (SQUARE_WIDTH + SQUARE_MARGIN) << 16
    sub bx, 16
    inc dh
    dec dl
    jnz .loop_side

    mov eax, 0x10
    int 0x80
    jmp mainloop
.adda:
    mov cl, dh
    sub cl, 10
    add cl, byte 'A'
    jmp .prta
.addb:
    mov cl, dh
    sub cl, 10
    add cl, byte 'A'
    jmp .prtb
    ; now the main kill loop
mainloop:
    mov al, byte [alive]
    test al, al
    jz kill
    jmp mainloop

current_color:
    db 0

wowstr: db "69"

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

; EDI = string, EDX = [y, x], CL = text color
win_draw_str:
    pusha
    mov ebx, edx
    mov ch, cl
    mov eax, 0x13 ; opcode
.loop:
    mov cl, byte [edi]
    test cl, cl
    jz .end
    int 0x80
    add ebx, 8
    inc edi
    jmp .loop
.end:
    popa
    ret

; cannot be called from inside an interrupt!
kill:
    ; Black out screen
    mov ebx, dword 0x0
    xor edx, edx
    mov dx, word [win_height]
    shl edx, byte 16
    mov ecx, edx
    mov cx, word [win_width]
    mov dl, 0
    mov eax, 0x12
    int 0x80
    ; Update VGA
    mov eax, 0x10
    int 0x80
failedboot:
    ; De-register keyboard handler
    mov eax, 0x21
    mov ebx, keyboard_handler
    int 0x80

    ; De-register mouse handler
    mov eax, 0x27
    mov ebx, mouse_handler
    int 0x80

    ; Kill PID
    mov eax, 0x32
    mov ebx, dword [PID]
    int 0x80

    mov byte [alive], 0 ; set alive flag

    ; yield
.y_loop:
    mov eax, 0x31
    int 0x80
    
    jmp .y_loop

video_info:
    work_start: resd 1
    fnt_start: resd 1
    VBE_Info: resd 1
    win_width: resw 1
    win_height: resw 1
    frame_start: resd 1

%include "Source/Prog/Colorama/mouse.s"
%include "Source/Prog/Colorama/utils.s"