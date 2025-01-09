[bits 32]

current_off: resd 0

wall: db " |  ",0
decoded:
    resb 16
    db 0

hexedit:
    ; ECX argstart generated at call
    ; Get memory starting address from arguments
    mov ebp, kbd_buffer ; where number starts
    add ebp, ecx
    inc ebp

    mov eax, ebp
    call strint
    mov ebp, eax ; EBP now has the base address
    
    xor ch, ch ; total line counter
.startln:
    cmp ch, 32
    je .end
    ; Add address base
    push ecx
    ; Do a newline before the start of the new line (real)

    mov al, 10
    mov bl, 0
    call tty_putchar ; NL

    mov eax, ebp
    mov cl, 8
    call hexstr
    pop ecx ; return counting stuff
    ; Add extra spaces/etc
    mov byte [eax + 8], byte ':'
    mov byte [eax + 9], byte ' '
    mov byte [eax + 10], 0
    call tty_printstr

    ; CL is byte counter
    xor cl, cl
.loop:
    push ecx
    xor eax, eax
    mov al, byte [ebp]
    movzx edx, cl
    call .insert
    mov cl, 2
    call hexstr
    ; Append a space
    mov byte [eax + 2], byte ' '
    mov byte [eax + 3], 0
    call tty_printstr
    pop ecx
    inc cl
    inc ebp
    cmp cl, 16
    jb .loop
    
.endln:
    ; Print the wall
    mov eax, wall
    call tty_printstr
    ; Print the decoded map
    mov eax, decoded
    call tty_printstr
    inc ch
    jmp .startln

; Decodes and inserts an ascii character
.insert:
    ; EDX contains offset to decoded
    ; AL contains char
    cmp al, byte 0x20
    jb .endi
    cmp al, byte 0x7E
    ja .endi
    mov byte [decoded + edx], al
    ret
.endi:
    ; Insert placeholder
    mov byte [decoded + edx], byte '.'
    ret
.end:
    call kbd_wipe
    ret