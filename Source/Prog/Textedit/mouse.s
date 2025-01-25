[bits 32]

; When called, EAX contains the mouse datapacket.
; 0-7:   X movement
; 8-15:  y movement
; 16-23: Flags
mouse_handler:
    ; Add the signed X/Y values
    ; Work on the X movement
    ; Move all movement bytes to BX
    mov bx, ax
    shr eax, 16
    ; flags are in al
    mov dl, al
    ; now BL contains X movement and BH contains Y movement, DL contains flags

    test dl, 0x10 ; test for X sign bit
    jnz .signed_x ; jump if number is negative
    ; If unsigned:
    xor ecx, ecx
    movzx cx, bl
    add word [abs_x], cx
    jmp .next
.signed_x:
    test bl, 235 ; test for X overflow
    jbe .next ; too low
    mov dh, 0xff
    sub dh, bl ; dh = 0xff - mov_x
    movzx cx, dh
    sub word [abs_x], cx ; subtract
.next: ; begin work on the Y value

    test dl, 0x20 ; test for Y sign bit
    jnz .signed_y ; jump if number is negative
    ; If unsigned:
    xor ecx, ecx
    movzx cx, bh
    sub word [abs_y], cx
    jmp .finish
.signed_y:

    mov dh, 0xff
    sub dh, bh ; dh = 0xff - mov_y
    movzx cx, dh
    add word [abs_y], cx ; subtract
.finish:
    ; finish
    xor edx, edx
    mov dx, word [abs_x]
    shl edx, 16
    mov dx, word [abs_y]
    call mouse_render
    ret
    


; EDX = [x,y]
mouse_render:
    pusha
    ; Draw directly onto the work buffer
    ; First back-up from the work buffer
    
    ; Render sprite
    ; Find a starting position
    push edx
    xor eax, eax
    xor ebx, ebx
    mov ax, dx ; only transfer Y coord
    mov bx, word [win_width]
    mul ebx ; Y * width
    pop edx
    shr edx, 16
    add eax, edx ; + X
    mov edi, eax ; copy starting pixel
    xor cx, cx ; CH = Y counter, CL = X counter
    mov ebp, dword [work_start]
    ; AX = holder for current word on bitmap
    ; BX = bit index (movzx from CL)
    ; ESI = offset within bitmap word addr
    xor esi, esi
    mov ax, word [mouse_bitmap + esi]
    xor bx, bx
.loop_x:
    bt ax, bx
    jc .yes
    mov byte [ebp + edi], byte 0
    jmp .continue
.yes:
    mov byte [ebp + edi], byte 0xf
.continue:
    inc edi
    inc cl
    inc bx
    cmp cl, 12
    jne .loop_x
.new_y:
    mov cl, 0
    movzx ebx, word [win_width]
    add edi, ebx
    sub edi, 12
    xor bx, bx
    inc ch
    add esi, 2
    mov ax, word [mouse_bitmap + esi]
    cmp ch, 19
    jne .loop_x
.end:
    mov eax, 0x10
    int 0x80 ; update screen
    popa
    ret

; EDX = [x,y]
; Update the region into the mask
mouse_mask_update:
    pusha
    push edx
    xor eax, eax
    xor ebx, ebx
    mov ax, dx ; only transfer Y coord
    mov bx, word [win_width]
    mul ebx ; Y * width
    pop edx
    shr edx, 16
    add eax, edx ; + X
    mov esi, eax ; copy starting addr to memcpy source
    mov dl, 19 ; line counter
    add esi, dword [work_start] ; add ptr

    mov ecx, 12 ; 12 pixels wide
    movzx ebx, word [win_width]

    mov edi, [mouse_mask] ; destination
.loop_ln:
    call memcpy
    dec dl
    jz .end
    add esi, ebx
    sub esi, 12 ; go to next line
    add edi, 12 ; add 12
    jmp .loop_ln
.end:
    popa
    ret
    

; Mouse sprite will invert whatever is below in the work buffer
; 12 x 19 sprite
mouse_bitmap:
    dw 0b0000000000000001
    dw 0b0000000000000011
    dw 0b0000000000000101
    dw 0b0000000000001001
    dw 0b0000000000010001
    dw 0b0000000000100001
    dw 0b0000000001000001
    dw 0b0000000010000001
    dw 0b0000000100000001
    dw 0b0000001000000001
    dw 0b0000010000000001
    dw 0b0000100000000001
    dw 0b0000111110000001
    dw 0b0000000010010001
    dw 0b0000000100101001
    dw 0b0000000100100101
    dw 0b0000001001000011
    dw 0b0000001001000000
    dw 0b0000000110000000

mouse_bitmap_filled:
    dw 0b0000000000000001
    dw 0b0000000000000011
    dw 0b0000000000000111
    dw 0b0000000000001111
    dw 0b0000000000011111
    dw 0b0000000000111111
    dw 0b0000000001111111
    dw 0b0000000011111111
    dw 0b0000000111111111
    dw 0b0000001111111111
    dw 0b0000011111111111
    dw 0b0000111111111111
    dw 0b0000111111111111
    dw 0b0000000011111111
    dw 0b0000000111101111
    dw 0b0000000111100111
    dw 0b0000001111000011
    dw 0b0000001111000000
    dw 0b0000000110000000

mouse_mask:
    resd 1

mouse_properties:
    abs_x: dw 0
    abs_y: dw 0

test: db "Woah!",0