; Each command has a 16-character long title (includes EOF)
; Afterwards, include a brief description 64-bytes long

; ECX contains position of initial split with first argument

%macro command 2
    db %1, 0 ; command name
    times (16 - ($ - $$) % 16) db 0 ; pad 16 bytes
    db %2, 0 ; description
    times (64 - ($ - $$) % 64) db 0 ; pad 64 bytes
%endmacro

commands:
    db "help"
    times 12 db 0
    db "clear"
    times 11 db 0
    db "crash"
    times 11 db 0
    db "dump"
    times 12 db 0
    times 16 db 0 ; end of commands


handlers:
    dd help_handle
    dd clear_handle
    dd 0
    dd hexedit

help_handle:
    call kbd_wipe
    ; Loop through all commands and list the names
    mov al, 10
    mov bl, 0
    call tty_putchar ; NL

    mov eax, commands
.loop:
    mov bl, byte [eax]
    test bl, bl ; test first character
    jz .end ; If last command
    ; Print
    call tty_printstr
    push eax
    mov al, 10
    mov bl, 0
    call tty_putchar ; NL
    pop eax
    add eax, dword 16
    jmp .loop
.end:
    ret

clear_handle:
    call kbd_wipe
    call tty_clear
    ret

%include "Source/Prog/Shell/hexedit.s"