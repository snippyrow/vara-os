[bits 32]
[org 0x800000]

; Basically neofetch but better :D

headers:
    origin_addr: dd 0x800000
    start_addr: dd main
    PID: resd 1
    alive: db 1
    freeze_events: db 0
    running_directory: resd 1
    args: resd 1

main:
    mov bh, 0
    ; Draw logo one line at a time (11)
    mov cl, 11
    mov edi, logo
    mov esi, messages
    mov ebp, msglist
.logo_loop:
    mov bl, 0x2B
    mov eax, edi
    int 0x70
    add edi, 27

    cmp cl, 7
    jb .skip

    ; Now print current message
    mov bl, 0xc
    mov eax, esi
    int 0x70
    add esi, 12
    
    ; Print text associated
    mov bl, 0xf
    mov eax, dword [ebp]
    int 0x70
    add ebp, 4

.skip:
    dec cl
    jnz .logo_loop
    
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
logo:
    db 10,"       _.,,,,,,,._       ",0,10,"    .d''         ``b.    ",0,10,"  .p'      .ooo     `q.  ",0,10,".d'      .88'        `b. ",0,10,".d'     d88'          `b.",0,10,"::     d888P'Ybo.      ::",0,10,"`p.    Y88[   ]88     .q'",0,10," `p.   `Y88   88P    .q' ",0,10,"  `b.    `88bod8'   .d'  ",0,10, "    `q..          ..,'   ",0,10,"       '',,,,,,,,''       ",10,0

messages:
    db "   USER: ",0,0,0
    db "   OS: ",0,0,0,0,0
    db "   KERNEL: ",0
    db "   RES: ",0,0,0,0
    db "   MEM: ",0,0,0,0
msglist:
    dd user
    dd os
    dd kernel
    dd res
    dd mem

; Dynamically fetch info later (probably add to fetch function)
user: db "@root",0
os: db "Celsix 1 x86_64",0
kernel: db "CKern 1.3-x86",0
; find resolution dynamically later
res: db "1280x1024 @ 0xFF",0
mem: db "65535KB",0 ; do this later