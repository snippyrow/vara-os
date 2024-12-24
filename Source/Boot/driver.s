[bits 32]
[global ata_lba_read]

; EAX = LBA starting address
; CL  = # of sectors to read
; EDI = Destination buffer starting address

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

    mov eax, 256 ; Read 256 words (512 bytes) (one sector)
    xor bx, bx
    mov bl, cl ; read "CL" sectors
    mul bx ; # of sectors * 256 words per sector
    mov ecx, eax ; ecx is the counter for INSW
    ; edx is the I/O port to read from
    ; then store that word into EDI buffer

    mov edx, dword 0x01F0 ; Dataport, IN/OUT
    rep insw ; repeat until ecx becomes zero

    ; Done!
    
    popa
    ret