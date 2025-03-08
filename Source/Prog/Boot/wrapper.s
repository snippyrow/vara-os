[bits 32]
[global _fread_raw]
[global win_putchar]
[global win_update]
[global win_fillrect]
[global win_rawfillrect]
[global win_putpixel]
[global pit_reg]
[global Yield]
[global proc_reg]

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

win_rawfillrect:
    mov eax, 0x11
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
    mov eax, 0x1B
    mov ebx, dword [esp + 4]
    mov ecx, dword [esp + 8]
    int 0x80
    ret


_fread_raw:
    mov eax, 0x41
    mov ebx, dword [esp + 4]
    mov edi, dword [esp + 8]
    mov ecx, dword [esp + 12]
    int 0x80
    ret

win_putpixel:
    mov eax, 0x14
    mov bx, word [esp + 8]
    shl ebx, 16
    mov bx, word [esp + 4]

    mov cl, byte [esp + 12]
    int 0x80
    ret

pit_reg:
    mov eax, 0x24
    mov ebx, dword [esp + 4]
    int 0x80
    ret

Yield:
    mov eax, 0x31
    int 0x80
    ret

proc_reg:
    mov eax, 0x30
    mov ebx, dword [esp + 4]
    int 0x80
    ; EAX is the returned PID
    ret