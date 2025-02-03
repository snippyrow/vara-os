[bits 32]
[global _fread_raw]

win_redraw:
    push eax
    mov eax, 0x10
    int 0x80
    pop eax
    ret

win_fillrect:
    push ebp
    mov ebp, esp

    mov eax, 0x12

    ; [y0, x0]
    mov bx, word [esp + 12]
    shl ebx, 16
    mov bx, word [esp + 8]

    ; [y1, x1]
    mov cx, word [esp + 20]
    shl ecx, 16
    mov cx, word [esp + 16]

    mov dl, byte [esp + 24]

    int 0x80

    mov esp, ebp
    pop ebp
    ret

malloc:
    push ebp
    mov ebp, esp

    mov eax, 0x1A
    mov ebx, dword [esp + 8]
    int 0x80

    ; Return EAX
    mov esp, ebp
    pop ebp
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