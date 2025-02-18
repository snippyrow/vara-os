[bits 32]

enter_switch:
    resd 1

back_switch:
    resd 1

kbd_switch:
    resd 1

keyboard_handler:
    cmp al, 0x1
    je .exit
    cmp al, 0x1c
    je .enter

    ; Check for Backspace key
    cmp al, byte 0x0E
    je .back

    ; Handle Shift keys
    cmp al, byte 0x2A
    je .shift
    cmp al, byte 0x36
    je .shift

    cmp al, byte 0xAA
    je .unshift
    cmp al, byte 0xB6
    je .unshift

    cmp al, byte 0x1D
    je .ctrl
    cmp al, byte 0x9D
    je .unctrl

    ; Ignore non-printable scancodes
    cmp al, 0x01
    jb .end
    cmp al, 0x39
    ja .end
    
    ; Retrieve ascii character and send it
    mov ebx, dword [kbd_switch]
    test ebx, ebx
    jz .end
    push ebx

    mov bl, byte [upper]
    test bl, bl
    jz .noshift
    ; If shifted:
    mov bl, byte [keymap_shift + eax]
    mov al, bl
    pop ebx ; switch
    jmp ebx ; with the byte in AL
    ret
.noshift:
    mov bl, byte [keymap + eax]
    mov al, bl
    pop ebx ; switch
    jmp ebx ; with the byte in AL


.exit:
    mov byte [alive], 0
    
    ret
.enter:
    ; If needed the scancode for enter is in AL
    mov ebx, dword [enter_switch] ; ptr to enter handler
    test ebx, eax
    jz .end ; end if not existant
    jmp ebx

.back:
    mov ebx, dword [back_switch] ; ptr to backspace handler
    test ebx, ebx
    jz .end ; end if not existant
    jmp ebx

.shift:
    mov byte [upper], byte 0x1
    ret
.unshift:
    mov byte [upper], byte 0x0
    ret
.ctrl:
    mov byte [ctrl], 1
    ret
.unctrl:
    mov byte [ctrl], 0
    ret
.end:
    ret
    

; AL = character input
page_input:
    ; Compute the position of the new character to be put down based on cursor X/Y
    ; Advance the line if necessary
    ; Add tabs/indents, newlines
    ; File writing
    ; Check if it is a control character
    mov bl, byte [ctrl]
    test bl, bl
    jnz .isctrl
.resume:
    ; Add character to the file
    mov edi, dword [file_cursor]
    add edi, dword [file_entry]
    mov byte [edi], al
    inc dword [file_cursor]

    mov cl, al
    mov eax, 0x13
    mov bx, word [file_char_y]
    shl bx, 4 ; abs position
    add bx, 25
    shl ebx, 16
    mov bx, word [file_char_x]
    shl bx, 3
    add bx, (8 * 3) + 15
    mov ch, 0xf
    int 0x80

    mov eax, 0x10
    int 0x80

    inc word [file_char_x]

    add bx, 24 ; give it more of a margin
    cmp bx, word [win_width]
    jae .nextln
    ret
.nextln:
    mov word [file_char_x], 0
    inc word [file_char_y]
    ret
.isctrl:
    cmp al, 'x'
    je .shouldkill
    cmp al, 'X'
    je .shouldkill
    cmp al, 's'
    je page_save
    cmp al, 'S'
    je page_save
    jmp .resume
.shouldkill:
    mov byte [alive], 0
    ret

keymap: db "??1234567890-=??qwertyuiop[]E?asdfghjkl",59,39,96,"A?zxcvbnm,./??? "
keymap_shift: db "??!@#$%^&*()_+??QWERTYUIOP{}??ASDFGHJKL:",34,"~?",92,"ZXCVBNM<>???? "
upper: db 0
ctrl: db 0