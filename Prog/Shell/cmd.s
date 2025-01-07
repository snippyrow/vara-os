; Each command has a 16-character long title (includes EOF)
commands:
    db "help",0,"???????????"
    db "testcrash",0,"??????"
    times 16 db 0

handlers:
    dd help_handle
    dd 0

help_handle:
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