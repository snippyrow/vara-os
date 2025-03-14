[bits 32]
[global ata_lba_read]
[global ata_lba_write]
[global malloc]
[global free]
[global mem_table]

; EAX = LBA starting address
; CL  = # of sectors to read
; EDI = Destination buffer starting address

; Read a single sector at a time (to start with)
ata_lba_read:
    pusha

    and eax, 0x0FFFFFFF ; limit # of LBA
    mov ebx, eax
    
    mov dx, word 0x01F6  ; Port to send drive and bit 24 - 27 of LBA
    shr eax, 24          ; Get bit 24 - 27 in al
    or al, 0b11100000    ; Set bit 6 in al for LBA mode
    out dx, al

    mov dx, word 0x01F2  ; Port to send number of sectors
    mov al, cl           ; Get number of sectors from CL
    out dx, al

    mov dx, word 0x01F3  ; Port to send bit 0 - 7 of LBA
    mov eax, ebx         ; Get LBA from EBX
    out dx, al

    mov dx, word 0x01F4  ; Port to send bit 8 - 15 of LBA
    mov eax, ebx         ; Get LBA from EBX
    shr eax, 8           ; Get bit 8 - 15 in AL
    out dx, al

    mov dx, word 0x01F5  ; Port to send bit 16 - 23 of LBA
    mov eax, ebx         ; Get LBA from EBX
    shr eax, 16          ; Get bit 16 - 23 in AL
    out dx, al

    mov dx, word 0x01F7  ; Command port
    mov al, byte 0x20    ; Read with retry.
    out dx, al

.reading:
    in al, dx
    test al, 8
    jz .reading
    push ecx
    push edx
    mov ecx, 256 ; ecx is the counter for INSW
    ; edx is the I/O port to read from
    ; then store that word into EDI buffer

    mov edx, dword 0x01F0 ; Dataport, IN/OUT
    rep insw ; repeat until ecx becomes zero
    pop edx
    pop ecx
    dec cl
    test cl, cl
    jz .end
    ; 400ns delay and repeat
    jmp .reading

.end
    ; Done!
    popa
    ret


; EAX = LBA starting address
; CL  = # of sectors to write to
; EDI = Source buffer for information

; Write multiple sectors to primary ATA device
ata_lba_write:
    pusha

    and eax, 0x0FFFFFFF ; limit # of LBA
    mov ebx, eax
    
    mov dx, word 0x01F6  ; Port to send drive and bit 24 - 27 of LBA
    shr eax, 24          ; Get bit 24 - 27 in al
    or al, 0b11100000    ; Set bit 6 in al for LBA mode
    out dx, al

    mov dx, word 0x01F2  ; Port to send number of sectors
    mov al, cl           ; Get number of sectors from CL
    out dx, al

    mov dx, word 0x01F3  ; Port to send bit 0 - 7 of LBA
    mov eax, ebx         ; Get LBA from EBX
    out dx, al

    mov dx, word 0x01F4  ; Port to send bit 8 - 15 of LBA
    mov eax, ebx         ; Get LBA from EBX
    shr eax, 8           ; Get bit 8 - 15 in AL
    out dx, al

    mov dx, word 0x01F5  ; Port to send bit 16 - 23 of LBA
    mov eax, ebx         ; Get LBA from EBX
    shr eax, 16          ; Get bit 16 - 23 in AL
    out dx, al

    mov dx, word 0x01F7  ; Command port
    mov al, byte 0x30    ; Write sectors
    out dx, al

; Do not use rep, due to it being too fast
.writing:
    in al, dx
    test al, 8
    jz .writing
    push ecx
    push edx
    ; Init loop
    mov cx, 256
    mov dx, word 0x01F0 ; DATA port
.loop:
    mov ax, word [edi]
    out dx, ax
    add edi, 2
    dec cx
    test cx, cx
    jz .next
    jmp .loop
.next:
    pop edx
    pop ecx
    dec cl
    test cl, cl
    jz .endw
    jmp .writing

.endw:
    ; Done!
    ; Flush cache
    mov dx, word 0x01F7 ; command port
    mov al, byte 0xE7 ; Cache flush command
    out dx, al
.flush_wait:
    in al, dx
    test al, 0b10000000 ; Check BSY (bit 7)
    jnz .flush_wait

    popa
    ret

; EAX contains the number of bytes required
; Return EAX contains the pointer to the start (0 if failed)

block_size equ 128              ; Example block size (adjust as needed)
num_blocks equ 75535            ; Total number of blocks (adjust as needed)
;mem_table:
    ;db 0b11111100
    ;resb num_blocks

mem_table equ 0x1000000
; Instead of a hard-coded table, have it be at the base ptr and then begin allocations after
base_address equ 0x1000000 + num_blocks     ; Base address of memory pool


; Max # of blocks is 64 x 8, or 64KB
malloc:
    dec eax ; size_t - 1
    xor edx, edx ; clear divisor for divide
    mov ebx, block_size
    div ebx
    inc eax ; after + 1
    mov esi, eax

    ; Initialize counting variables
    xor eax, eax ; eax = 0 (count)
    xor edx, edx ; total counted blocks
    xor ebp, ebp ; starting block

    xor ebx, ebx ; s_block (use for final start)

.loop_sblock:
    cmp ebx, num_blocks
    jae .alloc_failed

    xor ecx, ecx ; b_block (eight times per byte)
.loop_b:
    cmp ecx, 8 ; if at the end
    jae .next_sblock

    ; Now check if the bit is free
    movzx ax, byte [mem_table + ebx]
    bt ax, cx
    jc .block_used ; if the bit found was a 1

    ; Otherwise, the bit is free
.inc_cnt:
    cmp edx, 0
    jne .continue
    ; If we are starting a chain, set the start
    mov eax, ebx
    imul eax, dword 8
    add eax, ecx
    mov ebp, eax
.continue:
    inc edx
    inc ecx
    cmp edx, esi ; check if the number we counted is equal to the required # of blocks
    jb .loop_b ; If we have less than the required go back
    ; Otherwise complete and calculate the offset here
    ; Update all blocks first before returning, OK to change registers now

    ; First find the super block and byte block start, and increment

    xor ebx, ebx ; the current iteration counter (cmp with required)
    
.set_blocks:
    mov eax, ebp ; s_block
    add eax, ebx ; + index
    mov ecx, eax
    shr eax, 3 ; start / 8
    and ecx, 7 ; start % 8

    mov dh, 1
    shl dh, cl; byte index for counter (since is taken from start block + index ending)
    or byte [mem_table + eax], dh
    inc ebx

    cmp ebx, esi
    jb .set_blocks ; if we are not done, compare and redo

    ; Then calculate new address
    mov eax, ebp
    imul eax, block_size
    add eax, dword base_address

    ;mov eax, ebp
    ret



.block_used:
    inc ecx
    xor edx, edx ; reset counted blocks to zero
    jmp .loop_b

.next_sblock:
    inc ebx
    jmp .loop_sblock

.alloc_failed:
    xor eax, eax
    ret

; EAX = starting ptr, EBX = # of bytes to free
free:
    ; Calculate required space
    pusha
    xor edx, edx

    mov ecx, eax
    mov eax, ebx
    dec eax
    mov ebx, dword block_size
    div ebx
    inc eax
    mov edi, eax ; Required # of blocks

    ; ECX has starting ptr
    sub ecx, dword base_address
    xor edx, edx
    mov ebx, dword block_size
    mov eax, ecx
    div ebx
    mov ebp, eax ; Starting block #

    ; Define EBX as the loop index
    xor ebx, ebx
    
.loop:
    mov eax, ebp
    add eax, ebx
    mov ecx, eax
    shr eax, 3 ; / 8
    and ecx, 7 ; % 8

    mov dh, 1
    shr dh, cl
    not dh

    and byte [mem_table + eax], dh

    inc ebx
    cmp ebx, edi
    jl .loop

.end:
    popa
    ret
