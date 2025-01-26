[bits 32]

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

    ; Format shell dimensions for resolution
    ; WIDTH
    mov ax, word [win_width]
    mov bx, word [text_margin]
    shl bx, byte 1 ; x2
    sub ax, bx
    shr ax, byte 3 ; /8 (floored)
    mov word [text_width], ax

    ; HEIGHT
    mov ax, word [win_height]
    mov bx, word [text_margin]
    shl bx, byte 1 ; x2
    sub ax, bx
    shr ax, byte 4 ; /16 (floored)
    mov word [text_height], ax

screen_clear:
    ; Clear the screen (draw a rect with background color)
    mov ebx, dword 0x0
    xor edx, edx
    mov dx, word [win_height]
    shl edx, byte 16
    mov ecx, edx
    mov cx, word [win_width]
    mov dl, byte [background]
    mov eax, 0x12
    int 0x80

    ; Update VGA
    mov eax, 0x10
    int 0x80
    ret

; Prompt user with a window in the center of the screen, take an input string and close it on enter.
; EAX = prompt title string ptr
; CL = max input length
; EDI = submit call
; Note: EAX is returned with the ptr to the user input
prompt_height equ 95
shadow_offset equ 4 ; in px
popup_width: resw 1
popup_corner: resd 1
textbox_corner: resd 1
prompt_buffer: resb 50

prompt_call: resd 1

win_prompt:
    ; Draw the box shadow first
    mov dword [prompt_call], edi
    push eax
    call strlen
    shl ax, 3 ; x 8 (8 pix wide)
    add ax, 100 ; + 100px
    mov word [popup_width], ax
    mov bx, word [win_width]
    sub bx, ax ; minus win width
    shr bx, 1 ; /2
    ; Window will be 64px tall
    xor edx, edx
    mov dx, word [win_height]
    sub dx, prompt_height
    shr dx, 1
    shl edx, 16 ; move the Y coord
    mov dx, bx ; move X start coord
    ; EDX now has start coordinates
    mov ebx, edx ; start
    mov dword [popup_corner], ebx
    mov ecx, edx ; end
    add cx, ax ; add X coordinate by size of prompt
    add ecx, (prompt_height) << 16 ; add Y coordinate seperately
    ; add shadow offsets
    push ecx
    push ebx
    add ecx, (shadow_offset << 16) + shadow_offset
    add ebx, (shadow_offset << 16) + shadow_offset
    mov dl, 0xBB
    mov eax, 0x12
    int 0x80

    ; Now draw the root
    pop ebx
    pop ecx
    mov dl, 0x6 ; nice orange
    int 0x80

    ; Draw the centered title
    pop eax ; ptr to title
    mov edi, eax
    call strlen
    shl ax, 3 ; width of text bitmap
    mov dx, ax
    add dx, 100 ; window width
    sub dx, ax
    shr dx, 1 ; margin size in DX
    ; Calculate window root abs X
    ; Pop start rect position + DX
    push ebx
    
    add bx, dx ; window corner + margin to X coord
    mov edx, ebx
    add edx, 0x00060000 ; add 6px down
    mov cl, 0xf
    call win_draw_str

    ; Draw some special borders going down the sides
    ; Ascii code 177 (gray)
    pop ebx ; window corner addr
    push ebx
    mov dl, 6 ; counter
    mov cl, 177 ; code
    mov ch, 0x72 ; color
    ; draw a line down the side using ascii char 177
.loop_a:
    int 0x80
    add ebx, 0x00100000
    dec dl
    jnz .loop_a
    ; now for the next corner
    pop ebx
    add bx, word [popup_width]
    sub ebx, 7
    ; Move to the card corner
    mov dl, 6
.loop_b:
    int 0x80
    add ebx, 0x00100000
    dec dl
    jnz .loop_b

    ; Now work on the input field
    mov ebx, dword [popup_corner]
    add ebx, ((prompt_height / 2) - 5 << 16) + 20 ; add the Y coordinate, 20 left
    mov edx, ebx
    add dx, word [popup_width]
    sub dx, 40 ; twice the margin (into X)
    add edx, (20 << 16)
    mov ecx, edx
    mov dl, 0xf
    mov eax, 0x12
    mov dword [textbox_corner], ebx
    int 0x80

    mov dword [kbd_switch], prompt_kbd
    mov dword [enter_switch], prompt_submit
    mov dword [back_switch], prompt_back
.end:
    ret

prompt_kbd:
    ; AL = char
    mov dl, al
    mov eax, prompt_buffer
    call strlen
    cmp eax, 50
    jae .end
    mov byte [prompt_buffer + eax], dl ; insert character to buffer
    mov byte [prompt_buffer + eax + 1], 0 ; insert EOF
    ; Draw character
    shl eax, 3 ; x8 for pixel position X
    mov ecx, eax
    mov eax, dword [textbox_corner]

    ; If CX is too large, skip rendering the character
    mov bx, word [popup_width]
    sub bx, 44 ; (margins + 1/2 char)
    cmp cx, bx
    jae .end

    add ax, cx ; add the X coordinate
    add eax, 0x00020002 ; add 2 to Y/X coord
    mov cl, dl ; move character
    mov ebx, eax ; move text position
    mov ch, 0x0
    mov eax, 0x13
    int 0x80

    ; Update screen
    mov eax, 0x10
    int 0x80

.end:
    ret

prompt_submit:
    mov ebx, dword [prompt_call]
    test ebx, ebx
    jz .end
    mov eax, prompt_buffer
    call ebx
    test eax, eax
    jz .declined
.end:
    ; Zero out buffer
    ; Deregister prompt switches and hand back to main editor
    mov edi, prompt_buffer
    mov al, 0
    mov ecx, 50
    call memset
    
    ; Destroy window
    mov ebx, dword [popup_corner]
    mov ecx, ebx
    movzx edx, word [popup_width]
    add ecx, edx
    add ecx, shadow_offset
    add ecx, (prompt_height + shadow_offset) << 16 ; add height
    mov dl, byte [background]
    mov eax, 0x12
    int 0x80
    
    mov dword [prompt_call], 0
    mov dword [kbd_switch], page_input
    mov dword [enter_switch], page_nl
    mov dword [back_switch], page_back
    
    mov eax, 0x10
    int 0x80
    ret
.declined:
    ret

; backspace
prompt_back:
    mov eax, prompt_buffer
    call strlen
    test eax, eax
    jz .nospace
    dec eax
    mov byte [prompt_buffer + eax], 0

    ; Black out textbox
    shl eax, 3 ; x8 for pixel position X
    mov ecx, eax

    ; If CX is too large, skip rendering a backspace
    mov bx, word [popup_width]
    sub bx, 44 ; (margins + 1/2 char)
    cmp cx, bx
    jae .nospace

    mov eax, dword [textbox_corner]
    add ax, cx ; add the X coordinate
    add eax, 0x00020002 ; add 2 to Y/X coord
    mov ebx, eax ; move text position
    mov ecx, ebx
    add ecx, 0x00100008
    mov dl, 0xf
    mov eax, 0x12
    int 0x80

    ; Update screen
    mov eax, 0x10
    int 0x80

.nospace:
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

video_info:
    work_start: resd 1
    fnt_start: resd 1
    VBE_Info: resd 1
    win_width: resw 1
    win_height: resw 1

text_margin: dw 6 ; in pixels

cur_column: resw 1
cur_line: resw 1

text_width: resw 1
text_height: resw 1