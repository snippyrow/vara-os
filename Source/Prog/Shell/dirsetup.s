[bits 32]

; EAX contains cluster to the /home directory
directorysetup:
    mov ebx, eax ; cluster dir
    mov dword [home], eax
    mov eax, 0x40
    mov edi, texteditor
    int 0x80

    mov eax, 0x40
    mov edi, virus
    int 0x80

    mov eax, 0x40
    mov edi, memusage
    int 0x80

    ; Append code to virus file
    ; Malloc enough space (give about 1KB)
    ; Shared between ALL files
    mov eax, 0x1A
    mov ebx, 4096
    int 0x80
    ; Assume we have enough at runtime

    ; Read the disk into the buffer
    mov edi, eax
    mov eax, 0x18
    mov ebx, 90
    mov cl, 1 ; 512b
    int 0x80

    ; Write compiled data
    mov eax, 0x42
    mov ebx, dword [virus + 16] ; cluster start
    mov ecx, 512 ; 1000 bytes seems okay
    mov esi, edi
    int 0x80

    ; Now write memusage program
    mov eax, 0x18
    mov ebx, 91
    mov cl, 1 ; 512b
    int 0x80

    mov eax, 0x42
    mov ebx, dword [memusage + 16] ; cluster start
    mov ecx, 512 ; 1000 bytes seems okay
    mov esi, edi
    int 0x80


    mov eax, 0x18
    mov ebx, 93
    mov cl, 12 ; 8 sectors
    int 0x80

    mov eax, 0x42
    mov ebx, dword [texteditor + 16] ; cluster start
    mov ecx, 6000 ; 1000 bytes seems okay
    mov esi, edi
    int 0x80

    ; Free memory
    mov eax, 0x1B
    mov ebx, edi
    mov ecx, 4096
    int 0x80
    ret


; List out all programs
texteditor:
    db "textedit",0,0,0,0
    db "run"
    db 1
    dd 0 ; cluster, reserved
    dd 0
    dd 0
    dd 4192

virus:
    db "virus",0,0,0,0,0,0,0
    db "run"
    db 1
    dd 0 ; cluster, reserved
    dd 0
    dd 0
    dd 512

memusage:
    db "memusage",0,0,0,0
    db "run"
    db 1
    dd 0 ; cluster, reserved
    dd 0
    dd 0
    dd 512

home: resd 1