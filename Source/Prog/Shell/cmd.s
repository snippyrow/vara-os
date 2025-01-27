; Each command has a 16-character long title (includes EOF)
; Afterwards, include a brief description 64-bytes long

; ECX contains position of initial split with first argument

%macro command 2
    db %1, 0 ; command name
    times (16 - ($ - $$) % 16) db 0 ; pad 16 bytes
    db %2, 0 ; description
    times (64 - ($ - $$) % 64) db 0 ; pad 64 bytes
%endmacro

commands:
    db "help"
    times 12 db 0
    db "clear"
    times 11 db 0
    db "crash"
    times 11 db 0
    db "dump"
    times 12 db 0
    db "ls"
    times 14 db 0
    db "mkdir"
    times 11 db 0
    db "cd"
    times 14 db 0
    db "write"
    times 11 db 0
    db "run"
    times 13 db 0
    times 16 db 0 ; end of commands


handlers:
    dd help_handle
    dd clear_handle
    dd 0
    dd hexedit
    dd f_list_handle
    dd f_mkdir
    dd f_cd
    dd f_write
    dd run

help_handle:
    call kbd_wipe
    ; Loop through all commands and list the names
    mov al, 10
    mov bl, 0
    call tty_putchar ; NL

    mov eax, commands
.loop:
    mov bl, byte [eax]
    test bl, bl ; test first character
    jz .end ; If last command
    ; Print
    mov bl, 0xf
    mov bh, 0
    call tty_printstr
    push eax
    mov al, 10
    mov bl, 0
    call tty_putchar ; NL
    pop eax
    add eax, dword 16
    jmp .loop
.end:
    ret

clear_handle:
    call kbd_wipe
    call tty_clear
    ret

; Core function to execute a file as a process
; EDI = file struct ptr
; Called from shell.s, when the list of built-in commands is exhuasted
; Load in the working directory from the shell dir
exec:
    ; Allocate a spot for it, spawn a process and run
    ; Find file size, allocate and run
    mov ebx, dword [edi + 28] ; size
    shr ebx, 10 ; / 1024
    inc ebx ; add 1
    mov edx, ebx ; total # of clusters to read
    
    mov eax, 0x1A
    mov ebx, 1024
    int 0x80 ; malloc
    test eax, eax
    jz .oom ; no memory
    push eax

    ; read first cluster of executable file, then read the headers for that file
    mov ebp, edi ; move the FAT object here
    mov edi, eax
    mov eax, 0x41
    mov ebx, dword [ebp + 16] ; get cluster for file
    mov ecx, 1
    int 0x80 ; read file

    ; Read file in its entierety again
    push edi
    mov ecx, edx
    mov edx, dword [edi]
    mov edi, edx ; origin address
    mov eax, 0x41
    mov ebx, dword [ebp + 16] ; get cluster for file
    int 0x80 ; read file
    pop edi ; header

    ; Spawn process
    mov eax, 0x30
    mov ebx, dword [edi + 4] ; start addr
    int 0x80
    ; Return EAX is the PID
    ; Pass in the PID
    mov dword [edx + 8], eax
    
    ; Pass the current shell directory to the ENV
    mov eax, dword [shell_dir]
    mov dword [edx + 14], eax

    ; Pass the shell prompt as the arguments
    mov dword [edx + 18], kbd_buffer

    ; Free memory
    pop ebx
    mov eax, 0x1B
    mov ecx, 1024
    int 0x80

    ; Now important, de-register the keyboard from the shell. When yielded back, it will check and re-register if not already done so.
    mov byte [kbd_enabled], 0
    mov eax, [edi] ; where the program will load + 12
    add eax, 12 ; ptr to alive header flag
    mov dword [program_running], eax ; ptr
    mov eax, 0x21
    mov ebx, shell_kbd_hook
    int 0x80

    ; If the executable contains a GUI, as per flags, turn off all shell events
    cmp byte [edi + 13], 0
    je .end
    mov byte [gui_enabled], 0
    mov eax, 0x25
    mov ebx, cur_hook
    int 0x80

    jmp .end ; will be yielded automatically

.oom:
    mov eax, oom_err
    mov bl, 0xf
    mov bh, 0
    call tty_printstr
.end:
    call kbd_wipe
    ret

; List all files in current directory
f_list_handle:
    ; Allocate space for the directory listing
    mov eax, 0x1A ; kernel malloc
    mov ebx, 1024 * 2 ; 64 total items printed max
    int 0x80
    test eax, eax
    jz .oom
    push eax

    ; Fetch
    mov edi, eax
    mov eax, 0x41 ; read FAT raw
    mov ebx, dword [shell_dir]
    mov ecx, 2 ; 2 max
    int 0x80
    
    ; Print contents
    mov ebp, edi ; to buffer
    mov dx, 64 ; counter
.p_loop:
    ; Check if object is a file/directory
    mov al, byte [ebp + 15]
    test al, al
    jz .nf

    ; Print newline
    mov al, 10
    mov ah, 0xf
    mov bl, 0
    call tty_putchar
    
    ; Copy name & extension (if app.)
    ; Is it a directory?
    cmp byte [ebp + 15], 2
    je .isdir
    ; Is it a file?
    cmp byte [ebp + 15], 1
    je .isfile
    ; Is it a navigator?
    cmp byte [ebp + 15], 0x80
    je .isnav ; effectivly the same
.isfile:
    mov edi, f_name
    mov esi, ebp
    mov ecx, 12
    call memcpy
    mov byte [f_name + 12], 0 ; EOF

    mov edi, f_ext
    add esi, 12 ; for ext
    mov ecx, 3
    call memcpy
    mov byte [f_ext + 3], 0 ; EOF

    ; Print object name
    mov eax, f_name
    mov bl, 0xf
    mov bh, 0
    call tty_printstr
    mov al, byte '.'
    mov ah, 0xf
    mov bl, 0
    call tty_putchar
    mov eax, f_ext
    mov bl, 0xf
    mov bh, 0
    call tty_printstr

    jmp .nf
.isdir:
    mov edi, f_name + 1
    mov esi, ebp
    mov ecx, 12
    call memcpy
    mov byte [f_name + 12], 0 ; EOF
    mov byte [f_name], byte '/'

    ; Print object name
    mov eax, f_name
    mov bl, 0xf
    mov bh, 0
    call tty_printstr
    jmp .nf

.isnav:
    mov eax, nav_name
    mov bl, 0xf
    mov bh, 0
    call tty_printstr
    jmp .nf
    
.nf:
    add ebp, 32
    dec dx
    jnz .p_loop
.end:
    mov eax, 0x1B
    pop ebx
    mov ecx, 1024 * 2
    int 0x80 ; free memory
    call kbd_wipe
    ret
.oom:
    pop eax
    mov eax, oom_err
    mov bl, 0xf
    mov bh, 0
    call tty_printstr
    call kbd_wipe
    ret
f_name: resb 14 ; 8 + EOF + /
f_ext: resb 4 ; 3 + EOF


f_mkdir:
    mov ebp, kbd_buffer
    add ebp, ecx
    inc ebp ; just after first split
    mov eax, ebp
    call strlen
    cmp eax, 12
    jg .oversize
    ; malloc
    mov eax, 0x1A
    mov ebx, 32
    int 0x80
    test eax, eax
    jz .oom
    mov edi, eax
    mov esi, ebp
    mov ecx, 12
    call memcpy ; copy dir name
    ; extension is not used
    mov byte [edi + 15], 2 ; directory attribute
    mov dword [edi + 28], 32 ; 32 bytes on disk
    mov eax, 0x40
    mov ebx, dword [shell_dir]

    ; copy current acting prompt, remove '$' and set that as the parent name
    mov esi, parent_dir
    int 0x80 ; make directory

    ; Free memory
    mov eax, 0x1B
    mov ebx, edi
    mov ecx, 32
    int 0x80

    call kbd_wipe
    ret

.oversize:
    mov eax, oversize_err
    mov bl, 0xf
    mov bh, 0
    call tty_printstr
    call kbd_wipe
    ret
.oom:
    mov eax, oom_err
    mov bl, 0xf
    mov bh, 0
    call tty_printstr
    call kbd_wipe
    ret
    
; Needs a complete re-write ASAP!
f_cd:
    ; Read current directory
    ; Get ptr to the name desired in EAX
    mov ebp, kbd_buffer
    add ebp, ecx
    inc ebp ; just after first split

    ; Allocate space for the directory listing
    mov eax, 0x1A ; kernel malloc
    mov ebx, 1024 * 2 ; 64 total items printed max
    int 0x80
    test eax, eax
    jz .oom
    push eax

    ; Fetch
    mov edi, eax
    mov eax, 0x41 ; read FAT raw
    mov ebx, dword [shell_dir]
    mov ecx, 2 ; 2 max
    int 0x80

    ; Check if we are jumping to the parent directorty by the "../" keyword
    mov eax, ebp
    mov ebx, nav_name
    call strcmp
    test eax, eax
    jnz .isnav

    ; Otherwise do a loop
    mov dx, 64 ; 64 max items
.loop:
    cmp byte [edi + 15], 2
    jne .loop_continue ; not a directory
    ; Compare names
    mov eax, ebp ; prompt
    mov ebx, edi ; item name
    call strcmp
    test eax, eax
    jz .loop_continue ; not true
    ; Now switch
    mov eax, dword [edi + 16]
    mov dword [shell_dir], eax

    mov eax, edi ; ptr to item name
    mov ebp, edi ; backup
    call strlen
    mov ecx, eax ; move length
    mov edi, shell_prompt
    mov esi, ebp
    call memcpy
    mov edi, parent_dir
    call memcpy
    mov byte [parent_dir + eax], 0
    mov byte [shell_prompt + eax], byte '$'
    mov byte [shell_prompt + eax + 1], byte ' '
    mov byte [shell_prompt + eax + 2], byte 0

    jmp .end

.loop_continue:
    add edi, 32
    dec dx
    jz .end
    jmp .loop

.isnav:
    ; Just jump to the first thing in the list
    cmp byte [edi + 15], 0x80
    jne .end
    mov eax, dword [edi + 16]
    mov dword [shell_dir], eax

    mov eax, edi ; ptr to string name
    mov byte [edi + 12], 0
    mov ebp, edi ; backup
    call strlen
    mov ecx, eax ; move length
    mov edi, shell_prompt
    mov esi, ebp
    call memcpy
    mov edi, parent_dir
    call memcpy
    mov byte [parent_dir + ecx], 0
    mov byte [shell_prompt + ecx], byte '$'
    mov byte [shell_prompt + ecx + 1], byte ' '
    mov byte [shell_prompt + ecx + 2], byte 0

    jmp .end

.oom:
    mov eax, oom_err
    mov bl, 0xf
    mov bh, 0
    call tty_printstr
.end:
    ; free the memory
    pop ebx
    mov eax, 0x1B
    mov ecx, 1024 * 2
    int 0x80

    call kbd_wipe
    ret



f_write:
    mov ebp, kbd_buffer
    add ebp, ecx
    inc ebp ; just after first split

    ; Allocate space to read directory
    

    ; Fetch directory


    call kbd_wipe
    ret

run:
    ; dump filesystem
    ; Read a file desired and spawn it as a process
    mov ebp, kbd_buffer
    add ebp, ecx
    inc ebp ; just after first split

    ; Allocate space for dir
    mov eax, 0x1A ; kernel malloc
    mov ebx, 1024 * 2 ; 64 total items printed max
    int 0x80
    test eax, eax
    jz .oom
    push eax

    ; Fetch
    mov edi, eax
    mov eax, 0x41 ; read FAT raw
    mov ebx, dword [shell_dir]
    mov ecx, 2 ; 2 max
    int 0x80
    mov ebx, edi

    ; Split string into a name and extension
    xor ecx, ecx
    
.n_loop:
    cmp byte [ebp + ecx], byte '.'
    je .cpy1
    inc ecx
    cmp ecx, 12
    ja .end
    jmp .n_loop
.cpy1:
    ; copy name, then ext (fixed size)
    mov edi, run_name
    mov esi, ebp
    call memcpy
    mov byte [run_name + ecx], 0
    ; now copy extension
    mov edi, run_ext
    mov esi, ebp
    add esi, ecx
    inc esi ; past the "."
    mov ecx, 3
    call memcpy
    mov byte [run_ext + 3], 0
    
    ; EDI links to FS
    mov dx, 64
    mov edi, ebx ; backed up from previously
.loop:
    cmp byte [edi + 15], 1
    jne .loop_continue ; is a file
    mov eax, run_name
    mov ebx, edi ; object name
    call strcmp
    test eax, eax
    jz .loop_continue
    
    ; If names match, load the extension and check that too
    mov eax, run_ext
    mov ebx, edi ; object ext
    add ebx, 12

    mov byte [edi + 15], 0 ; set EOF
    call strcmp
    test eax, eax
    jz .loop_continue
    ; If both match and it is a file, run
    
    ; Allocate a spot for it, spawn a process and run
    ; Find file size, allocate and run
    mov ebx, dword [edi + 28] ; size
    shr ebx, 10 ; / 1024
    inc ebx ; add 1
    mov edx, ebx ; total # of clusters to read
    
    mov eax, 0x1A
    mov ebx, 1024
    int 0x80 ; malloc
    test eax, eax
    jz .oom ; no memory
    push eax

    ; read first cluster of executable file, then read the headers for that file
    mov ebp, edi ; move the FAT object here
    mov edi, eax
    mov eax, 0x41
    mov ebx, dword [ebp + 16] ; get cluster for file
    mov ecx, 1
    int 0x80 ; read file

    ; Read file in its entierety again
    push edi
    mov ecx, edx
    mov edx, dword [edi]
    mov edi, edx ; origin address
    mov eax, 0x41
    mov ebx, dword [ebp + 16] ; get cluster for file
    int 0x80 ; read file
    pop edi ; header

    ; Spawn process
    mov eax, 0x30
    mov ebx, dword [edi + 4] ; start addr
    int 0x80
    ; Return EAX is the PID
    ; Pass in the PID
    mov dword [edx + 8], eax
    
    ; Pass the current shell directory to the ENV
    mov eax, dword [shell_dir]
    mov dword [edx + 14], eax

    ; Pass the shell prompt as the arguments
    mov dword [edx + 18], kbd_buffer

    ; Free memory
    pop ebx
    mov eax, 0x1B
    mov ecx, 1024
    int 0x80

    ; Now important, de-register the keyboard from the shell. When yielded back, it will check and re-register if not already done so.
    mov byte [kbd_enabled], 0
    mov eax, [edi] ; where the program will load + 12
    add eax, 12 ; ptr to alive header flag
    mov dword [program_running], eax ; ptr
    mov eax, 0x21
    mov ebx, shell_kbd_hook
    int 0x80

    ; If the executable contains a GUI, as per flags, turn off all shell events
    cmp byte [edi + 13], 0
    je .end
    mov byte [gui_enabled], 0
    mov eax, 0x25
    mov ebx, cur_hook
    int 0x80



    jmp .end ; will be yielded automatically
    
.loop_continue:
    add edi, 32
    dec dx
    jz .end
    jmp .loop

.oom:
    mov eax, oom_err
    mov bl, 0xf
    mov bh, 0
    call tty_printstr
.end:
    ; free the memory from very first fs scan
    pop ebx
    mov eax, 0x1B
    mov ecx, 1024 * 2
    int 0x80

    call kbd_wipe
    ret

oom_err: db 10,"Out of system memory, you messed up bad!",14,0
oversize_err: db 10,"File object name too long, maximum 12 characters",14,0
nav_name: db "../",0
parent_dir: resb 16
run_name: resb 13
run_ext:
    resb 3
    db 0

%include "Source/Prog/Shell/hexedit.s"

dead: db 0