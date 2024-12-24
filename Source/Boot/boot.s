; Bootloader
; The very most basic part, only 512 bytes in all.
; Focus on loading the kernel, as well as set up basic things before exiting

; Kernel code located after MBR

[org 0x7c00]
[bits 16]
KERNEL_START equ 0x7e00

start:
    ; Load the kernel

    ; Buffer
    mov ax, KERNEL_START >> 4
    mov es, ax
    mov ax, word 0
    mov bx, ax

    mov al, byte 60 ; total number of sectors
    mov ch, byte 0 ; cylinder number
    mov cl, byte 2 ; starting sector (after MBR)
    mov dh, byte 0 ; head number

    mov dl, byte 0x80 ; primary drive
    mov ah, byte 2 ; Read drive opcode
    int 0x13

    jc .error
    
    ; Jump to the defined kernel, out of the pure binary
    jmp KERNEL_START

.error:
    mov ah, byte 0x0E ; Print BIOS code
    mov si, err_print
.e_loop:
    lodsb
    cmp al, 0
    je .e_done
    int 0x10
    jmp .e_loop
.e_done:
    jmp $

err_print:
    db "[D] READ ERR",10,13,0

times 510-($-$$) db 0
dw 0xaa55