[bits 32]
[global _fread_raw]
[global win_putchar]
[global win_update]
[global win_fillrect]

win_update:
    mov eax, 0x10
    int 0x80
    ret

win_fillrect:

    mov eax, 0x12

    ; [y0, x0]
    mov bx, word [esp + 8]
    shl ebx, 16
    mov bx, word [esp + 4]

    ; [y1, x1]
    mov cx, word [esp + 16]
    shl ecx, 16
    mov cx, word [esp + 12]

    mov dl, byte [esp + 20]

    int 0x80
    ret

win_putchar:

    mov eax, 0x13

    ; [y0, x0]
    mov bx, word [esp + 8]
    shl ebx, 16
    mov bx, word [esp + 4]

    ; Color
    mov ch, byte [esp + 12]
    ; Char
    mov cl, byte [esp + 16]

    int 0x80

    ret

malloc:

    mov eax, 0x1A
    mov ebx, dword [esp + 8]
    int 0x80

    ; Return EAX
    ret

free:
    push ebp
    mov ebp, esp

    mov eax, 0x1B
    mov ebx, dword [esp + 8]
    mov ecx, dword [esp + 12]
    int 0x80

    mov esp, ebp
    pop ebp
    ret


_fread_raw:
    push ebp
    mov ebp, esp

    mov eax, 0x41
    mov ebx, dword [esp + 8]
    mov edi, dword [esp + 12]
    mov ecx, dword [esp + 16]
    int 0x80

    mov esp, ebp
    pop ebp
    ret