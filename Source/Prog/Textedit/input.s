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
.end:
    ret

keymap: db "??1234567890-=??qwertyuiop[]E?asdfghjkl",59,39,96,"A?zxcvbnm,./??? "
keymap_shift: db "??!@#$%^&*()_+??QWERTYUIOP{}??ASDFGHJKL:",34,"~?",92,"ZXCVBNM<>???? "
upper: db 0