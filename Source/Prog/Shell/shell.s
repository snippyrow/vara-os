[bits 32]
[org 0x50000]

; Basic shell program, topmost
; TODO: Removing lines from the shell_back command causes text to work, but otherwise text does not render. Required to go back
; Maybe syscalls are broken?

section .text

start:
    jmp main

test:
    db "Hello testers!",0

main:
    ; Initialize the shell/keyboard drivers
    ; Add keyboard hook
    mov eax, 0x20
    mov ebx, shell_kbd_hook
    int 0x80

    ; Add PIT hook
    mov eax, 0x24
    mov ebx, cur_hook
    int 0x80

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
    mov bx, word [shell_margin]
    shl bx, byte 1 ; x2
    sub ax, bx
    shr ax, byte 3 ; /8 (floored)
    mov word [shell_width], ax

    ; HEIGHT
    mov ax, word [win_height]
    mov bx, word [shell_margin]
    shl bx, byte 1 ; x2
    sub ax, bx
    shr ax, byte 4 ; /16 (floored)
    mov word [shell_height], ax

    ; Clear the screen (draw a rect with background color)
    mov ebx, dword 0x0
    xor edx, edx
    mov dx, word [win_height]
    shl edx, byte 16
    mov ecx, edx
    mov cx, word [win_width]
    mov dl, byte [shell_bg]
    mov eax, 0x12
    int 0x80

    ; Write intro spash
    mov eax, intro
    call tty_printstr
    mov eax, shell_prompt
    call tty_printstr

    ; Render changes
    mov eax, 0x10
    int 0x80

    ; Error: if yielding, only sometimes works
    mov eax, 0x31
    int 0x80

    jmp $

; inconsistant use of characters for some reason
shell_kbd_hook:
    ; Check if the scancode is special

    ; Check for Enter key
    cmp al, byte 0x1C
    je shell_enter

    ; Check for Backspace key
    cmp al, byte 0x0E
    je shell_back

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

.continue:
    ; Format character position
    xor ebx, ebx
    mov bx, word [shell_line]
    shl bx, byte 4 ; x 16
    add bx, word [shell_margin]
    shl ebx, byte 16 ; convert to upper word
    mov bx, word [shell_column]
    shl bx, byte 3
    add bx, word [shell_margin]

    ; Draw a black rectangle to remove the cursor
    mov ecx, ebx
    add ecx, dword 0x00100008 ; add 16 and 8 to X/Y
    mov dl, byte [shell_bg]
    push eax
    mov eax, 0x12
    int 0x80
    pop eax

    cmp byte [upper], byte 0x0
    je .lower
.up:
    mov cl, byte [keymap_shift + eax] ; copy code
    jmp .print
.lower:
    mov cl, byte [keymap + eax] ; copy code
.print:
    mov eax, 0x13 ; syscall for drawing a character
    mov ch, 0xf ; color
    int 0x80


    ; Add character to the keyboard buffer, cancel if it overflows past 256
    ; CL contains the char
    mov eax, kbd_buffer
    call strlen
    cmp eax, dword 0xff
    ja .end ; if above 0xff, end
    ; Insert
    mov byte [kbd_buffer + eax], cl
    inc eax
    mov byte [kbd_buffer + eax], byte 0

    inc word [shell_column]
    mov ax, word [shell_column]
    cmp ax, word [shell_width]
    jb .end
    ; If not bellow, then increment the line
    inc word [shell_line]
    mov word [shell_column], word 0
.end:
    ; Redraw screen
    mov eax, 0x10
    int 0x80
    ret

.shift:
    mov byte [upper], byte 0x1
    ret
.unshift:
    mov byte [upper], byte 0x0
    ret

; Jumped to as an extension, therefore returning will end the keyboard hook
shell_enter:
    mov eax, kbd_buffer
    call strlow
    ; Temporary split at the space
    xor ecx, ecx
.l1:
    mov bl, byte [kbd_buffer + ecx]
    cmp bl, byte ' '
    je .set
    test bl, bl
    jz .res ; if string end
    inc ecx
    jmp .l1
.set:
    mov byte [kbd_buffer + ecx], 0
.res:
    push ecx
    ; Loop over all commands and check if the keyboard buffer matches
    mov eax, commands ; increment by 80 for each one
    xor ecx, ecx ; counter to locate a handler
.loop:
    mov bl, byte [eax]
    test bl, bl ; test first character
    jz .end ; If last command
    ; Otherwise check, EAX already has ptr
    mov ebx, kbd_buffer
    push eax
    call strcmp
    test eax, eax
    pop eax
    ; If the strings match, call
    jnz .call
    ; Otherwise loop back
    add eax, dword 16
    inc ecx
    jmp .loop
.call:
    mov eax, handlers
    shl ecx, byte 2 ; 4 for dword
    add eax, ecx
    mov ebx, dword [eax]
    pop ecx
    call ebx ; call loaded function, returns here
    mov al, 10
    call tty_putchar
    mov eax, shell_prompt
    call tty_printstr
    ret
.end:
    pop ecx
    jmp none_default
    ret

shell_back:
    ; Remove the top character from the keyboard buffer, then draw over the existing character
    mov eax, kbd_buffer
    call strlen
    test eax, eax
    jz .endb ; if buffer len is zero, return
    dec eax
    mov byte [kbd_buffer + eax], byte 0 ; zero-out first to last character of buffer

    ; Undo character on screen
    xor ebx, ebx
    mov ax, word [shell_column]
    sub ax, word 1
    jnc .res ; if there is a carry, then reset the column and decrement the line
    mov ax, word [shell_width]
    dec ax
    dec word [shell_line]
.res:
    mov word [shell_column], ax
    shl ax, byte 3 ; x 8 for column, + margin
    add ax, word [shell_margin]
    mov bx, word [shell_line]
    shl bx, byte 4 ; x 16
    add bx, word [shell_margin]
    shl ebx, byte 16 ; make higher word
    add ebx, eax ; add in the X value
    ; swap X and Y for rectangle function for both EBX and ECX
    ;rol ebx, byte 16
    mov ecx, ebx
    add ecx, dword 0x00100010 ; add 16 to both X and Y, for X to remove cursor if it were to exist
    mov dl, byte [shell_bg]
    mov eax, 0x12
    int 0x80
    ; Rect was drawn, update screen
    mov eax, 0x10
    int 0x80

.endb:
    ret

kbd_wipe:
    ; Zero out keyboard buffer fully
    mov eax, 0xff
.loop:
    test eax, eax
    jz .end
    dec eax
    mov byte [kbd_buffer + eax], byte 0
    jmp .loop
.end:
    ret

; Automatically format terminal to insert a character (advances user cursor, text-wrap)
; AL = char, AH = char color, BL = background
tty_putchar:
    pusha
    ; Special cases
    ; Newline (NL), create a new line and carridge return
    ; Backspace, go back
    ; Tab space, insert two spaces
    mov dl, bl ; for rectangle, EAX is preserved
    xor ebx, ebx
    mov bx, word [shell_line]
    shl bx, byte 4 ; x 16
    add bx, word [shell_margin]
    shl ebx, byte 16 ; convert to upper word
    mov bx, word [shell_column]
    shl bx, byte 3
    add bx, word [shell_margin]

    ; Draw a black rectangle to remove the cursor
    mov ecx, ebx
    add ecx, dword 0x00100008
    push eax
    mov eax, 0x12
    int 0x80
    pop eax

    ; Check for special cases
    ; NEWLINE:
    cmp al, byte 0xA
    je .NL

    ; Now draw character
    mov cl, al
    mov ch, ah
    mov eax, 0x13 ; syscall for drawing a character
    int 0x80

    ; Update lines
    inc word [shell_column]
    mov ax, word [shell_column]
    cmp ax, word [shell_width]
    jb .end
    ; If not bellow, then increment the line
    inc word [shell_line]
    mov word [shell_column], word 0
.end:
    popa
    ret
.NL:
    mov word [shell_column], word 0
    inc word [shell_line]
    popa
    ret

; Fast wrapper for printing to screen (EAX = string ptr), only plain colors
tty_printstr:
    pusha
    mov ecx, eax
.loop:
    mov al, byte [ecx]
    test al, al
    jz .end
    mov ah, byte 0xf
    mov bl, byte 0
    call tty_putchar
    inc ecx
    jmp .loop
.end:
    popa
    ret

tty_clear:
    mov ebx, dword 0x0
    xor edx, edx
    mov dx, word [win_height]
    shl edx, byte 16
    mov ecx, edx
    mov cx, word [win_width]
    mov dl, byte [shell_bg]
    mov eax, 0x12
    int 0x80

    mov word [shell_column], word 0
    mov word [shell_line], word 0

    mov eax, 0x10
    int 0x80

    ret

; Default command run when no other commands found
str: db 10,"Command not found.",10,0
none_default:
    mov eax, str
    call tty_printstr
    
    mov al, 10
    call tty_putchar
    mov eax, shell_prompt
    call tty_printstr
    ; Render changes
    mov eax, 0x10
    int 0x80

    ; Zero out keyboard buffer fully
    mov eax, 0xff
.loop:
    test eax, eax
    jz .end
    dec eax
    mov byte [kbd_buffer + eax], byte 0
    jmp .loop
.end:
    ret

cur_hook:
    mov al, byte [cursor_state]
    inc al
    cmp al, byte 18
    je .tick
    cmp al, byte 36
    je .untick
    mov byte [cursor_state], al
    ret
.box:
    xor ebx, ebx
    mov bx, word [shell_line]
    shl bx, byte 4 ; x 16
    add bx, word [shell_margin]
    shl ebx, byte 16 ; convert to upper word
    mov bx, word [shell_column]
    shl bx, byte 3
    add bx, word [shell_margin]

    mov ecx, ebx
    add ecx, dword 0x00100008 ; add 16 and 8 to X/Y
    ret
.tick:
    mov byte [cursor_state], al
    ; Blink cursor on at current position

    call .box
    mov dl, 0xf
    mov eax, 0x12
    int 0x80
    mov eax, 0x10
    int 0x80

    ret
.untick:
    mov byte [cursor_state], byte 0
    call .box
    mov dl, 0x0
    mov eax, 0x12
    int 0x80
    mov eax, 0x10
    int 0x80
    ret



section .data

shell_margin: dw 6 ; in pixels

shell_column: resw 1
shell_line: resw 1

shell_width: resw 1
shell_height: resw 1

cursor_state: resb 1 ; 0-31

keymap: db "??1234567890-=??qwertyuiop[]E?asdfghjkl",59,39,96,"A?zxcvbnm,./??? "
keymap_shift: db "??!@#$%^&*()_+??QWERTYUIOP{}??ASDFGHJKL:",34,"~?",92,"ZXCVBNM<>???? "
upper: db 0
shell_bg: db 0

kbd_buffer: times 256 db 0
shell_prompt: db "/$ ",0

intro: db "Vara OS devshell loaded. Type 'help' for information.",10,0

video_info:
    work_start: resd 1
    fnt_start: resd 1
    VBE_Info: resd 1
    win_width: resw 1
    win_height: resw 1

%include "Source/Prog/Shell/cmd.s"
%include "Source/Prog/Shell/utils.s"