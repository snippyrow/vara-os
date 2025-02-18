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

    mov eax, 0x40
    mov edi, sysfetch
    int 0x80

    mov eax, 0x40
    mov edi, colorama
    int 0x80

    mov eax, 0x40
    mov edi, windowboot
    int 0x80

    ; Append code to virus file
    ; Malloc enough space (give about 1KB)
    ; Shared between ALL files
    mov eax, 0x1A
    mov ebx, 0x4000
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
    mov cl, 8 ; 8 sectors
    int 0x80

    mov eax, 0x42
    mov ebx, dword [texteditor + 16] ; cluster start
    mov ecx, 4096 ; 1000 bytes seems okay
    mov esi, edi
    int 0x80

    ; Now copy the sysfetch program
    mov eax, 0x18
    mov ebx, 101
    mov cl, 2
    int 0x80

    mov eax, 0x42
    mov ebx, dword [sysfetch + 16] ; cluster start
    mov ecx, 1000 ; 1000 bytes seems okay
    mov esi, edi
    int 0x80

    ; copy colorama program
    mov eax, 0x18
    mov ebx, 103
    mov cl, 4
    int 0x80

    mov eax, 0x42
    mov ebx, dword [colorama + 16] ; cluster start
    mov ecx, 3000 ; 1000 bytes seems okay
    mov esi, edi
    int 0x80

    ; Write window switcher
    mov eax, 0x18
    mov ebx, 110
    mov cl, 30
    int 0x80

    mov eax, 0x42
    mov ebx, dword [windowboot + 16] ; cluster start
    mov ecx, 0x4000 ; 1000 bytes seems okay
    mov esi, edi
    int 0x80


    ; Free memory
    mov eax, 0x1B
    mov ebx, edi
    mov ecx, 0x4000
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
    dd 4096

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

sysfetch:
    db "sysfetch",0,0,0,0
    db "run"
    db 1
    dd 0 ; cluster, reserved
    dd 0
    dd 0
    dd 1000

colorama:
    db "colorama",0,0,0,0
    db "run"
    db 1
    dd 0 ; cluster, reserved
    dd 0
    dd 0
    dd 3000

windowboot:
    db "window",0,0,0,0,0,0
    db "run"
    db 1
    dd 0 ; cluster, reserved
    dd 0
    dd 0
    dd 0x4000
    

home: resd 1