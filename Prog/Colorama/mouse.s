[bits 32]
[global mouse_abs_x]
[global mouse_abs_y]
[global mouse_left_handler]
[global mouse_middle_handler]
[global mouse_right_handler]

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

    ; Test for button clicks
    xor cl, cl
    test dl, 1
    jnz .leftclick
    test dl, 2
    jnz .rightclick
    test dl, 4
    jnz .middleclick

.update:
    test cl, cl
    jz .unclicked
.render_update:
    ; Black out old mouse position from mask
    mov dx, word [mouse_abs_x]
    shl edx, 16
    mov dx, word [mouse_abs_y]
    call mouse_mask_draw

    ; Test X for a sign, otherwise none
    test bl, 0x80 ; test for last bit (sign)
    jnz .signed_x
    movzx cx, bl
    add word [mouse_abs_x], cx

    ; Bounds check
    mov cx, word [mouse_abs_x]
    add cx, 12 ; add width
    cmp cx, word [win_width]
    ja .x_large

    jmp .next
.signed_x:
    mov cl, 0xff
    sub cl, bl
    movzx cx, cl
    sub word [mouse_abs_x], cx
    jc .x_small
.next:
    test bh, 0x80
    jnz .signed_y
    movzx cx, bh
    sub word [mouse_abs_y], cx
    jc .y_small
    jmp .finish
.signed_y:
    mov cl, 0xff
    sub cl, bh
    movzx cx, cl
    add word [mouse_abs_y], cx

    mov cx, word [mouse_abs_y]
    add cx, 18
    cmp cx, word [win_height]
    ja .y_large
.finish:
    ; finish
    mov dx, word [mouse_abs_x]
    shl edx, 16
    mov dx, word [mouse_abs_y]
    call mouse_mask_update
    call mouse_render
.end:
    call mouse_move
    ret
    
.x_large:
    mov cx, word [win_width]
    sub cx, 12
    mov word [mouse_abs_x], cx
    jmp .next
.x_small:
    mov word [mouse_abs_x], 0
    jmp .next
.y_large:
    mov cx, word [win_height]
    sub cx, 1
    mov word [mouse_abs_y], cx
    jmp .finish
.y_small:
    mov word [mouse_abs_y], 0
    jmp .finish
.leftclick:
    mov byte [mouse_filled], 1
    inc cl
    mov eax, dword [mouse_left_handler]
    test eax, eax
    jz .update
    call eax
    jmp .update
.middleclick:
    mov byte [mouse_filled], 1
    inc cl
    mov eax, dword [mouse_middle_handler]
    test eax, eax
    jz .update
    call eax
    jmp .update
.rightclick:
    mov byte [mouse_filled], 1
    inc cl
    mov eax, dword [mouse_right_handler]
    test eax, eax
    jz .update
    call eax
    jmp .update
.unclicked:
    mov byte [mouse_filled], 0
    jmp .render_update


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
    mov ebp, dword [frame_start]
    ; AX = holder for current word on bitmap
    ; BX = bit index (movzx from CL)
    ; ESI = offset within bitmap word addr
    xor esi, esi
    cmp byte [mouse_filled], 0
    jne .clicked
    mov edx, mouse_bitmap
    jmp .resume
.clicked:
    mov edx, mouse_bitmap_filled
.resume:
    mov ax, word [edx + esi]
    xor bx, bx
.loop_x:
    bt ax, bx
    jc .yes
    ;mov byte [ebp + edi], byte 0x96
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
    mov ax, word [edx + esi]
    cmp ch, 19
    jne .loop_x
.end:
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

    mov edi, dword [mouse_mask] ; destination
.loop_ln:
    call memcpy
    dec dl
    jz .end
    add esi, ebx
    add edi, 12 ; add 12
    jmp .loop_ln
.end:
    popa
    ret

; EDX = [x,y]
; Draw back in the mouse mask
mouse_mask_draw:
    pusha
    push edx
    movzx eax, dx ; transfer Y coordinate
    movzx ebx, word [win_width] ; window width
    mul ebx
    pop edx
    shr edx, 16
    add eax, edx ; add X coordinate
    mov edi, eax
    add edi, dword [frame_start] ; add buffer

    mov dl, 19 ; ln counter
    mov ecx, 12 ; 12px wide

    mov esi, dword [mouse_mask]
.loop_ln:
    call memcpy
    dec dl
    jz .end
    ; If another line
    add edi, ebx ; add ebx (window width)
    add esi, 12 ; next line in mask
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
    mouse_abs_x: dw 0
    mouse_abs_y: dw 0
    mouse_filled: db 0

mouse_hooks:
    mouse_left_handler: resd 1
    mouse_middle_handler: resd 1
    mouse_right_handler: resd 1