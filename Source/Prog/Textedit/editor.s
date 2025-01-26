[bits 32]
[org 0x300000] ; keep clear of stack!

; TODO: backspace, tabs, cursor, opening old files

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

background: db 0xDE
file_entry: resd 1 ; ptr to the file
file_cursor: resd 1 ; position of the ptr (end)
file_cluster_begin: resd 1 ; cluster start of raw file being edited

; cursor position in the file
file_char_x: dw 0
file_char_y: dw 0

; error: only prints once, cannot be executed multiple times, putting a jmp $ before killing itself does nothing somehow
boot_main:
    ; Keyboard to shell has been de-registered
    call testfunc ; check file integrity
    cmp eax, 12
    je .boot_resume
    mov eax, booterr
    int 0x70
    jmp kill
.boot_resume
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

    ; Draw a bottom bar
    mov eax, 0x12
    mov bx, word [win_height]
    sub bx, 22
    shl ebx, 16 ; move to Y
    mov ecx, ebx
    add cx, word [win_width]
    add ecx, dword (22 << 16)
    mov dl, 0x13
    int 0x80

    ; Draw keybind tips
    mov edi, bottomtext
    mov edx, ebx
    add edx, 0x00030003
    mov cl, 0xf
    call win_draw_str

    ; Do a prompt
    mov eax, test2
    mov edi, file_new
    call win_prompt


    mov eax, 0x10
    int 0x80

mainloop:
    mov al, byte [alive]
    test al, al
    jz kill
    jmp mainloop

; EAX = ptr to file name string
; Return EAX = accept/reject input
file_struct: resb 32
file_new:
    ; Split the buffer between a name and extension
    mov esi, eax
    mov edi, file_struct
    mov cl, 12
.loop_name:
    mov al, byte [esi]
    cmp al, '.'
    je .ext
    mov byte [edi], al
    inc edi
    inc esi
    dec cl
    jz .failed
    jmp .loop_name
.ext:
    inc esi
    mov edi, file_struct + 12
    mov cl, 3
.loop_ext:
    movsb
    dec cl
    jnz .loop_ext

    ; Add file attribute and size
    mov byte [file_struct + 15], 1 ; is file
    mov dword [file_struct + 28], 0 ; size
    mov eax, 0x40
    mov ebx, [running_directory]
    mov edi, file_struct
    int 0x80

    ; Now open the newly created file
    mov eax, dword [file_struct + 16] ; cluster
    call file_open
    test eax, eax
    jz .failed ; if operation failed

    mov eax, 1 ; success
    ret
.failed:
    xor eax, eax ; failed
    ret

; Open raw file based on start cluster, allocate towards the file entry ptr
; Allocate a maximum of 16384 bytes (characters) for now
; EAX = file start cluster
file_open:
    push eax
    mov eax, 0x1A
    mov ebx, 16384
    int 0x80
    test eax, eax
    jz .failed
    mov dword [file_entry], eax

    ; read in file
    pop ebx ; cluster start
    mov edi, eax ; destination
    mov ecx, 16 ; 16 max clusters, = 16384B
    int 0x80

    mov dword [file_cluster_begin], ebx

    ; Format text window
    call reformat

    ; File was read, return
    mov eax, 1
    ret


.failed:
    xor eax, eax
    ret

; Reformat the text window to match what is in the file entry object
reformat:
    ; Clear text window
    mov ebx, 0x00160000 ; start here
    mov cx, word [win_height]
    sub cx, 22
    shl ecx, 16
    mov cx, word [win_width]
    mov dl, byte [background]
    mov eax, 0x12
    int 0x80

    ; Initiate things by highlighting the first line in a brighter color (all line goes under text/border)
    mov eax, 0x12
    mov ebx, (25 << 16)
    mov dx, word [win_width]
    mov ecx, ebx
    add ecx, (16 << 16)
    add cx, dx
    mov dl, 0xAE
    int 0x80


    ; Start with the first line number
    movzx eax, word [file_char_y] ; starting line
    inc eax
    mov edx, ((22 + 5) << 16) + 5 ; starting coordinate
    mov cl, 0xf
    ; max # of lines to render (NOT absolute)
    mov bx, word [win_height]
    sub bx, 44 ; both topbars
    shr bx, 4 ; / 16
    mov ch, bl
.char_loop:
    push eax
    call intstr
    mov edi, eax
    pop eax
    inc eax
    call win_draw_str
    add edx, 0x00100000 ; next line
    dec ch
    jnz .char_loop

    ; Draw a thin line to seperate line numbers from page contents (0px wide)
    mov eax, 0x12
    mov ebx, (22 << 16) + (8 * 3) + 6
    mov ecx, ebx
    mov dx, word [win_height]
    sub dx, 44
    shl edx, 16
    add dx, 0
    add ecx, edx
    mov dl, 0xf
    int 0x80


    mov eax, 0x10
    int 0x80
    ret

page_nl:
    mov word [file_char_x], 0
    inc word [file_char_y]

    ; Insert a newline into file
    mov edi, dword [file_cursor]
    add edi, dword [file_entry]
    mov byte [edi], 10
    inc dword [file_cursor]

    ; re-draw the correct line later

    ret

page_back:
    ret ; for now
    cmp word [file_cursor], 0
    je .end ; if nothing left

    ; Erase character in buffer
    dec word [file_cursor]
    movzx eax, word [file_cursor]
    mov byte [file_entry + eax], 0

    ; Black out character
    cmp word [file_char_x], 0
    je .prevln ; if we need to go UP a line

    ; Calculate max column
    mov ax, word [win_width]
    sub ax, 

.prevln:

.end:
    ret

; Jumped from keyboard switch, save and close file
page_save:
    mov eax, 0x42
    mov ebx, dword [file_cluster_begin]
    mov esi, dword [file_entry]
    mov ecx, 16384 ; 16 clusters (16,384B)
    int 0x80

    ; kill
    mov byte [alive], 0
    ret

wintitle:
    db 10,"Text editor (/",0
    resb 20
endian: db "/)",0
test2: db "Create or open file",0
tip1: db "[ESC] to exit",0
bottomtext: db "^X to close ^S to save ^N to make new file",0
booterr: db "ERROR: File integrity check failed.",0

; cannot be called from inside an interrupt!
kill:
    ; Black out screen
    mov ebx, dword 0x0
    xor edx, edx
    mov dx, word [win_height]
    shl edx, byte 16
    mov ecx, edx
    mov cx, word [win_width]
    mov dl, 0
    mov eax, 0x12
    int 0x80
    ; Update VGA
    mov eax, 0x10
    int 0x80

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

testfunc:
    mov eax, 12
    ret