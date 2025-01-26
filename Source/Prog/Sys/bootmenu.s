[bits 32]
[org 0x600000] ; keep clear of stack!

headers:
    origin_addr: dd 0x600000
    start_addr: dd boot_main
    PID: resd 1
    alive: db 1
    freeze_events: db 0
    running_directory: resd 1

; error: only prints once, cannot be executed multiple times, putting a jmp $ before killing itself does nothing somehow
boot_main:
    mov eax, tesstr
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
; error: not printing all of the string
tesstr:
    db 10,"Welcome to my operating system, vara 1.0!",10,"To get started, try running from programs in the /home directory.",10,"The system is in its infancy, though there is much to discover (myself included).",10,0

