[bits 32]
[org 600000] ; keep clear of stack!

; Tutorial:
; Origin_addr is the address where the program will be loaded
; Start_addr is the ptr to the boot function
; PID is the current process ID
; Freeze_events is if this is a real GUI program, then it tells whatever called it to halt until done
; Running_directory is an optional parameter to link to a hosting directory
; Args is a ptr to whatever arguments are passed to the program. They can be anything, but usually links to a string

headers:
    origin_addr: dd 600000
    start_addr: dd boot_main
    PID: resd 1
    alive: db 1
    freeze_events: db 0
    running_directory: resd 1
    args: resd 1

; error: only prints once, cannot be executed multiple times, putting a jmp $ before killing itself does nothing somehow
boot_main:
    mov bl, 0xf
    mov bh, 0
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
    db 10,"Welcome to my operating system, vara 1.0!",10,"To get started, try running from programs in the /bin directory.",10,"The system is in its infancy, though there is much to discover (myself included).",10,0

