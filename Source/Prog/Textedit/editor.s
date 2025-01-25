[bits 32]
[org 0x300000] ; keep clear of stack!

; basically ENV variables
headers:
    origin_addr: dd 0x300000
    start_addr: dd boot_main
    PID: resd 1
    alive: db 1
    freeze_events: db 1 ; optional, freeze shell events such as a blinking cursor
    running_directory: resd 1

kbd_handlers:
    resd 4

; error: only prints once, cannot be executed multiple times, putting a jmp $ before killing itself does nothing somehow
boot_main:
    ; Keyboard to shell has been de-registered
    mov eax, wintitle
    int 0x70

    ; TODO:
    ; clear screen, draw a gui and do a mouse
    call gui_init
    call screen_clear

    ; Register a keyboard handler
    mov eax, 0x20
    mov ebx, keyboard_handler
    mov dword [kbd_handlers], ebx
    int 0x80

    ; Draw a basic topbar
    mov eax, 0x12
    mov ebx, 0 ; [0,0]
    mov ecx, (22 << 16)
    add cx, word [win_width]
    mov dl, 0x13
    int 0x80

    ; Find the name of the current directory using the navigator name, 

    ; Draw a small title scrawl
    call getcwd
    mov ebx, eax
    mov eax, wintitle
    call strcat
    mov ebx, endian
    call strcat
    call strlen
    shl eax, 3 ; each char is 8 wide
    movzx edx, word [win_width]
    sub edx, eax ; sub total width from string bitmap width
    shr edx, 1 ; divide by two for final
    add edx, 0x00030000 ; factor in Y value
    mov edi, wintitle
    mov cl, 0xf
    call win_draw_str

    ; Draw some tooltips
    mov edi, tip1
    mov edx, 0x00030003
    mov cl, 0xf
    call win_draw_str


    ; Allocate space for the mouse mask
    ;mov eax, 0x1A
    ;mov ebx, 19 * 12
    ;int 0x80
    ;mov dword [mouse_mask], eax ; save ptr

    ; Create a mouse now..
    ;mov eax, 0x26
    ;mov ebx, mouse_handler
    ;int 0x80

    ;mov edx, 0x00600020
    ;call mouse_mask_update
    ;call mouse_render

    ; Do a prompt
    mov eax, test2
    mov edi, file_create
    call win_prompt


    mov eax, 0x10
    int 0x80

mainloop:
    mov al, byte [alive]
    test al, al
    jz kill
    jmp mainloop

; EAX = ptr to file name string
file_create:
    ret

gui_input:
    ret

wintitle:
    db 10,"Text editor (/",0
    resb 20
endian: db "/)",0
test2: db "Please enter a file name",0
tip1: db "[ESC] to exit",0

; cannot be called from inside an interrupt!
kill:
    ; De-register keyboard handler
    mov eax, 0x21
    mov ebx, keyboard_handler
    int 0x80

    ; Kill PID
    mov eax, 0x32
    mov ebx, dword [PID]
    int 0x80

    mov byte [alive], 0 ; set alive flag

    ; yield
.y_loop:
    mov eax, 0x31
    int 0x80
    
    jmp .y_loop


%include "Source/Prog/Textedit/gui.s"
%include "Source/Prog/Textedit/utils.s"
;%include "Source/Prog/Textedit/mouse.s"
%include "Source/Prog/Textedit/input.s"