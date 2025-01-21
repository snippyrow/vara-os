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
    db "ls"
    times 14 db 0
    times 16 db 0 ; end of commands


handlers:
    dd help_handle
    dd clear_handle
    dd 0
    dd hexedit
    dd f_list_handle

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

; List all files in current directory
f_list_handle:
    ; Allocate space for the directory listing
    mov eax, 0x1A ; kernel malloc
    mov ebx, 1024 * 2 ; 64 total items printed max
    int 0x80
    test eax, eax
    jz .oom

    ; Fetch
    mov edi, eax
    mov eax, 0x41 ; read FAT raw
    mov ebx, dword [shell_dir]
    mov ecx, 2 ; 2 max
    int 0x80

    ; Print contents
    mov ebp, edi ; to buffer
    mov dx, 64 ; counter
.p_loop:
    ; Check if object is a file/directory
    mov al, byte [ebp + 11]
    test al, al
    jz .nf

    ; Print newline
    mov al, 10
    mov ah, 0xf
    mov bl, 0
    call tty_putchar
    
    ; Copy name & extension (if app.)
    ; Is it a directory?
    cmp byte [ebp + 11], 2
    je .isdir
    ; Is it a file?
    cmp byte [ebp + 11], 1
    je .isfile
.isfile:
    mov edi, f_name
    mov esi, ebp
    mov ecx, 8
    call memcpy
    mov byte [f_name + 8], 0 ; EOF

    mov edi, f_ext
    add esi, 8 ; for ext
    mov ecx, 3
    call memcpy
    mov byte [f_ext + 3], 0 ; EOF

    ; Print object name
    mov eax, f_name
    call tty_printstr
    mov al, byte '.'
    mov ah, 0xf
    call tty_putchar
    mov eax, f_ext
    call tty_printstr

    jmp .nf
.isdir:
    mov edi, f_name + 1
    mov esi, ebp
    mov ecx, 8
    call memcpy
    mov byte [f_name + 9], 0 ; EOF
    mov byte [f_name], byte '/'

    ; Print object name
    mov eax, f_name
    call tty_printstr
    jmp .nf
.nf:
    add ebp, 32
    dec dx
    jnz .p_loop
.end:
    ret
.oom:
    mov eax, oom_err
    call tty_printstr
    ret
f_name: resb 10 ; 8 + EOF + /
f_ext: resb 4 ; 3 + EOF
oom_err: db 10,"Out of system memory, you messed up bad!",14,0

%include "Source/Prog/Shell/hexedit.s"