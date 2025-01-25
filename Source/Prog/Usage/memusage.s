[bits 32]
[org 0x400000] ; keep clear of stack!

headers:
    origin_addr: dd 0x400000
    start_addr: dd begin
    PID: resd 1
    alive: db 1
    freeze_events: db 0

NUM_BLOCKS equ 65535
BLOCK_SIZE equ 128
; each block indexes eight

begin:
    ; request info
    mov eax, 0x37
    int 0x80
    ; EDX has ptr to mem table
    mov ebx, NUM_BLOCKS ; overall counter
    xor cx, cx ; bit index
    xor edi, edi
    xor eax, eax
    xor ebp, ebp ; counter for how many bytes of memory used
    mov ah, 8 ; counter
.loop_byte_begin:
    mov al, byte [edx + edi]
.loop_bt:
    bt ax, cx
    jnc .continue
    ; if the block is used
    add ebp, 128
.continue:
    dec ah
    jz .new
    inc cx
    jmp .loop_bt
.new:
    ; new byte
    xor cx, cx
    mov ah, 8
    inc edi
    dec ebx
    jz .end
    jmp .loop_byte_begin
.end:
    ; yield after calculations
    mov eax, 0x31
    int 0x80
    ; end
    ; Print used memory
    ; Convert used to number
    mov eax, guistr
    int 0x70
    ; print total memory

    mov eax, (NUM_BLOCKS * 8 * 128) / 1024
    mov edx, eax
    mov cl, 6
    call hexstr
    int 0x70
    mov eax, suffix
    int 0x70

    mov eax, ebp
    shr eax, 10 ; / 1024 to go from B to KB
    mov ebx, eax
    mov cl, 6
    call hexstr
    int 0x70
    mov eax, suffix
    int 0x70


    ; Free memory
    mov edx, (NUM_BLOCKS * 8 * 128) / 1024
    sub edx, ebx
    mov eax, edx
    mov cl, 6
    call hexstr
    int 0x70
    mov eax, suffix
    int 0x70
    

    ; Now kill myself
    mov eax, 0x32
    mov ebx, dword [PID]
    int 0x80
    
    mov byte [alive], 0 ; set alive flag

    ; yield
.y_loop:
    mov eax, 0x31
    int 0x80
    
    jmp .y_loop
    

; EAX is the uint32, return EAX is ptr for string, 0 if failed
; CL is the mandated number of digits
tstr:
    resb 32
tstr2:
    resb 32
hexstr:
    mov edx, eax
    mov edi, tstr2 ; new ptr
    push edi
    push ecx
.loop:
    test edx, edx
    jz .fill ; if the number is over
    mov eax, edx
    mov ch, byte '0'
    and eax, dword 0xF
    cmp al, 9
    jbe .noadd
    ; Add
    mov ch, byte 'A'
    sub al, 10
.noadd:
    add ch, al
    mov byte [edi], ch
    shr edx, 4
    inc edi
    dec cl
    jmp .loop
.fill:
    test cl, cl
    jz .end
    dec cl
    mov byte [edi], byte '0'
    inc edi
    jmp .fill

.end:
    mov byte [edi], 0
    pop ecx
    pop eax ; start vector

    ; Reverse string
    ; Loop until CL is 0
    ; DL is incrementing counter
    and ecx, 0x000000FF
    xor edx, edx
.l:
    test cl, cl
    jz .e
    mov bl, byte [tstr2 + ecx - 1]
    mov byte [tstr + edx], bl
    dec cl
    inc dl
    jmp .l
.e:
    mov byte [tstr + edx], 0
    mov eax, tstr
    ret

    ; EDI = destination, ESI = source, ECX = # of bytes
memcpy:
    push esi
    push edi
    push ecx
    cld
.loop:
    movsb ; Copy byte from [esi] to [edi], increments both
    dec ecx
    jnz .loop
    pop ecx
    pop edi
    pop esi
    ret


guistr:
    db 10,"         total      used      free",10,"Mem:  ",0
suffix: db "KB  ",0