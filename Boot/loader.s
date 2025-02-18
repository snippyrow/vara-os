[bits 32]
[global Kernel_Start]
[extern PIT_Config]
[extern V_WORK_BUFF]
[extern V_DrawRect]
[extern V_UPDATE]
[extern PIT_Int_Handle]
[extern IDT_Add]
[extern Kbd_Int_Handle]
[extern ata_lba_read]
[extern IDT_Remap]
[extern IDT_Desc]
[extern V_DrawString]
[extern Sys_Int_Handle]
[extern V_DrawChar]
[extern VBE_Info]
[extern V_FNT_BUFF]
[extern malloc]
[extern free]
[extern Kbd_Hooks]
[extern Kbd_Test]
[extern process_create]
[extern process_yield]
[extern process_destroy]
[extern PIT_Hooks]
[extern ata_lba_write]
[extern FAT_Format]
[extern fat_mko]
[extern fat_read]
[extern fat_write]
[extern Stdout_Int_Handle]
[extern STDOUT_Hooks]
[extern mem_table]
[extern Mouse_Int_Handle]
[extern Mouse_Hooks]
[extern Mouse_Init]

Kernel_Start:
    ; IDT Has been defined, populate it with components

    ; Map PIT to the handler
    ; PIT will be used for task scheduling
    ; First grab ptr to the IDT entry and populate the stuff

    push dword PIT_Int_Handle
    push dword 32
    call IDT_Add
    add esp, 8

    push dword Kbd_Int_Handle
    push dword 33
    call IDT_Add
    add esp, 8

    push dword Mouse_Int_Handle
    push dword 44
    call IDT_Add
    add esp, 8

    ; Start up core interrupt
    push dword Sys_Int_Handle
    push dword 0x80
    call IDT_Add
    add esp, 8

    ; Attach basic STDOUT
    push dword Stdout_Int_Handle
    push dword 0x70
    call IDT_Add
    add esp, 8
    
    call IDT_Remap

    ; Change PIT frequency to 30hz
    mov eax, 30
    call PIT_Config
    call Mouse_Init


    mov al, 0b11111000 ; Unmask PIT, KBD and Cascade
    out 0x21, al

    mov al, 0b11101111 ; Unmask PS/2 mouse
    out 0xA1, al

    lidt [IDT_Desc]

    sti

    ; Draw a rect
    mov [V_WORK_BUFF + 15], byte 0xf
    mov eax, dword 0x00100010
    mov ebx, dword 0x01200300
    mov cl, byte 0xc
    call V_DrawRect
    call V_UPDATE

    mov esi, test_str
    mov eax, 0x00400020
    mov bh, byte 0xf
    call V_DrawString

    mov eax, 0x10
    int 0x80

    ; Add the basic process
    mov eax, 0x30
    mov ebx, process_test
    int 0x80

    ; Now do a small test and jump to a loaded program
    mov eax, 50 ; Starting LBA
    mov edi, 0x50000 ; Program loaded location
    mov cl, 12 ; # of sectors to read
    call ata_lba_read

    mov eax, 0x30
    mov ebx, 0x50000
    int 0x80

    call FAT_Format
    test eax, eax
    jz 0

    ; Jump to basic looping process
    jmp process_test

    jmp $

process_test:
    mov eax, 0x31
    int 0x80
    jmp process_test

test_str:
    db "Hello, world! How are you? This is just a little test phrase to figure out what is going wrong with any ATA disk reading and writing fucntions. Thanks for stopping by!",0

crash:
    jmp 0

fat_test_struct:
    db "Testfile"
    db "txt"
    db 1
    dd 0x69 ; cluster, reserved
    dd 0
    dd 0
    dd 512
    dd 0



; Primary syscall handler
; EAX has the interrupt vector, specifically.
; Syscalls may include drawing shapes, updating screen, requesting video data and such and such.

; LIST:
;   EAX 0x10 = Update screen from work buffer
;   EAX 0x12 = Draw rectangle (ebx = [y0, x0], ecx = [y1, x1], dl = color)
;   EAX 0x13 = Draw default 8x16 character (ebx = [y,x], cl = char, ch = color)
;   EAX 0x16 = Get display information (return eax = VESA information vector, return ebx = work buffer start vector, return vector ecx = default font buffer)
;   EAX 0x18 = ATA LBA read to vector (ebx = LBA start address, cl = # of sectors to read, edi = buffer start address)
;   EAX 0x19 = ATA write from ptr to LBA (ebx = LBA start address, cl = # of sectors to write, edi = buffer start address)
;   EAX 0x1A = Kernel MALLOC (ebx = # of bytes required, return eax = start ptr (0 if failed))
;   EAX 0x1B = Kernel FREE (ebx = start ptr (from malloc), ecx = size in bytes to free)
;   EAX 0x20 = Hook Keyboard (ebx = function ptr)
;   EAX 0x21 = Unhook Keyboard (ebx = function ptr)
;   EAX 0x24 = Hook PIT (ebx = function ptr)
;   EAX 0x25 = Unhook PIT (ebx = function ptr)
;   EAX 0x26 = Hook Mouse (ebx = function ptr)
;   EAX 0x27 = Unhook Mouse (ebx = function ptr)
;   EAX 0x30 = Spawn Process (ebx = starting addr, return eax = PID (0 if failed))
;   EAX 0x31 = Yield Process to kernel
;   EAX 0x32 = Process Kill (ebx = PID)
;   EAX 0x35 = Hook STDOUT (ebx = ptr to function).. hooks a function, so that whenever standard output is sent it repeats for everything here
;   EAX 0x36 = Unhook STDOUT (ebx = ptr to function).. unhooks the desired function to STDOUT
;   EAX 0x37 = Get hook info (eax = ptr to KBD hooks, ebx = ptr to PIT hooks, ecx = ptr to STDOUT hooks, edx = ptr to malloc memory table)
;   EAX 0x39 = Get kernel info (eax = KB of memory, ebx = ptr to kernel name)

;   EAX 0x40 = Make FAT object (ebx = directory start cluster, edi = fat object ptr, (optional) esi = ptr parent directory name) (esi is for the navigator to work on directories)
;       The function takes care of different types of entries, such as parents, etc. Struct will be modified to reflect properties
;   EAX 0x41 = Read raw (ebx = raw cluster start, edi = buffer ptr, ecx = max clusters).. reads a directory/file, loads it to buffer
;   EAX 0x42 = Touch raw (ebx = file starting cluster, esi = data input buffer, ecx = data size)
;   EAX 0x43 = Format FAT to empty clusters (deletes everything!)

; NOTE: Use int 0x70 for sending through stdout (EAX = ptr to object)
Sys_Int_Handle:
    cli
    cmp eax, dword 0x10
    je .v_render
    cmp eax, dword 0x12
    je .v_render_rect
    cmp eax, dword 0x13
    je .v_render_dchar
    cmp eax, dword 0x16
    je .v_ret_info
    cmp eax, dword 0x18
    je .ata_read
    cmp eax, dword 0x19
    je .ata_write
    cmp eax, dword 0x1A
    je .i_malloc
    cmp eax, dword 0x1B
    je .i_free
    cmp eax, dword 0x20
    je .kbd_hook
    cmp eax, dword 0x21
    je .kbd_unhook
    cmp eax, dword 0x30
    je .proc_create
    cmp eax, dword 0x31
    je .proc_yield
    cmp eax, dword 0x32
    je .proc_kill

    cmp eax, dword 0x24
    je .pit_hook
    cmp eax, dword 0x25
    je .pit_unhook

    cmp eax, dword 0x35
    je .stdout_hook
    cmp eax, dword 0x36
    je .stdout_unhook

    cmp eax, dword 0x26
    je .mouse_hook
    cmp eax, dword 0x27
    je .mouse_unhook

    cmp eax, dword 0x40
    je .fat_mk
    cmp eax, dword 0x41
    je .fat_rd
    cmp eax, dword 0x42
    je .fat_wr
    cmp eax, dword 0x37
    je .ret_hooks
    sti
    iret
.v_render:
    pusha
    call V_UPDATE
    popa
    sti
    iret
.v_render_rect:
    pusha
    mov eax, ebx
    mov ebx, ecx
    mov cl, dl
    call V_DrawRect
    popa
    sti
    iret
.v_render_dchar:
    pusha
    mov eax, ebx
    mov bl, cl
    mov bh, ch
    call V_DrawChar
    popa
    sti
    iret
.v_ret_info:
    mov eax, VBE_Info
    mov ebx, V_WORK_BUFF
    mov ecx, V_FNT_BUFF
    iret
.ata_read:
    pusha
    mov eax, ebx
    call ata_lba_read
    popa
    sti
    iret
.ata_write:
    pusha
    mov eax, ebx
    call ata_lba_write
    popa
    sti
    iret
.m_ret:
    resd 1
.i_malloc:
    pusha
    mov eax, ebx
    call malloc
    mov dword [.m_ret], eax
    popa
    mov eax, dword [.m_ret]
    sti
    iret
.i_free:
    pusha
    mov eax, ebx
    mov ebx, ecx
    call free
    popa
    sti
    iret
.proc_create:
    pusha
    mov eax, ebx
    call process_create
    mov dword [.m_ret], eax
    popa
    mov eax, dword [.m_ret]
    sti
    iret
.proc_yield:
    pusha
    call process_yield
    popa
    iret
.proc_kill:
    pusha
    mov eax, ebx
    call process_destroy
    popa
    sti
    iret
.fat_mk:
    push ebx
    mov eax, ebx
    mov ebx, edi
    call fat_mko
    pop ebx
    iret
.fat_rd:
    pusha
    mov eax, ebx
    call fat_read
    popa
    sti
    iret
.fat_wr:
    pusha
    mov eax, ebx
    mov edi, esi
    call fat_write
    popa
    sti
    iret
.ret_hooks
    mov eax, Kbd_Hooks
    mov ebx, PIT_Hooks
    mov ecx, STDOUT_Hooks
    mov edx, mem_table
    sti
    iret

; STDOUT hooks
.stdout_hook:
    pusha
    mov cl, byte 0 ; Loop counter for iteration
    mov edi, STDOUT_Hooks
.iterate_std:
    cmp cl, byte 64
    je .end_std
    mov edx, dword [edi]
    test edx, edx
    jnz .skip_std
    ; Found a function ptr that is 0, update
    mov dword [edi], ebx
    jmp .end_std
.skip_std:
    inc cl
    add edi, 4
    jmp .iterate_std
.end_std:
    popa
    sti
    iret


.stdout_unhook:
    pusha
    mov cl, byte 0 ; Loop counter for iteration
    mov edi, STDOUT_Hooks
.iterate_unstd:
    cmp cl, byte 64
    je .end_unstd
    mov edx, dword [edi]
    cmp edx, ebx
    jne .skip_unstd
    ; Skip if not equal to the function ptr, otherwise set it
    mov dword [edi], dword 0x0
    jmp .end_unstd
.skip_unstd:
    inc cl
    add edi, 4
    jmp .iterate_unstd
.end_unstd:
    popa
    sti
    iret

; Mouse hooks
.mouse_hook:
    pusha
    mov cl, byte 0 ; Loop counter for iteration
    mov edi, Mouse_Hooks
.iterate_mou:
    cmp cl, byte 64
    je .end_mou
    mov edx, dword [edi]
    test edx, edx
    jnz .skip_mou
    ; Found a function ptr that is 0, update
    mov dword [edi], ebx
    jmp .end_mou
.skip_mou:
    inc cl
    add edi, 4
    jmp .iterate_mou
.end_mou:
    popa
    sti
    iret

.mouse_unhook:
    pusha
    mov cl, byte 0 ; Loop counter for iteration
    mov edi, Mouse_Hooks
.iterate_unmou:
    cmp cl, byte 64
    je .end_unmou
    mov edx, dword [edi]
    cmp edx, ebx
    jne .skip_unmou
    ; Skip if not equal to the function ptr, otherwise set it
    mov dword [edi], dword 0x0
    jmp .end_unmou
.skip_unmou:
    inc cl
    add edi, 4
    jmp .iterate_unmou
.end_unmou:
    popa
    sti
    iret

; Loop through the hook table maximum 32 times, set the function located in ebx.
; Function ptr located in EBX
.kbd_hook:
    pusha
    mov cl, byte 0 ; Loop counter for iteration
    mov edi, Kbd_Hooks
.iterate:
    cmp cl, byte 32
    je .end
    mov edx, dword [edi]
    test edx, edx
    jnz .skip
    ; Found a function ptr that is 0, update
    mov dword [edi], ebx
    jmp .end
.skip:
    inc cl
    add edi, 4
    jmp .iterate
.end:
    popa
    sti
    iret

; Set a ptr in the hook table to 0 based off of function ptr in EBX
.kbd_unhook:
    pusha
    mov cl, byte 0 ; Loop counter for iteration
    mov edi, Kbd_Hooks
.iterate_u:
    cmp cl, byte 32
    je .end_u
    mov edx, dword [edi]
    cmp edx, ebx
    jne .skip_u
    ; Skip if not equal to the function ptr, otherwise set it
    mov dword [edi], dword 0x0
    jmp .end_u
.skip_u:
    inc cl
    add edi, 4
    jmp .iterate_u
.end_u:
    popa
    sti
    iret

.pit_hook:
    pusha
    mov cl, byte 0 ; Loop counter for iteration
    mov edi, PIT_Hooks
.iterate_v1:
    cmp cl, byte 32
    je .end_v1
    mov edx, dword [edi]
    test edx, edx
    jnz .skip_v1
    ; Found a function ptr that is 0, update
    mov dword [edi], ebx
    jmp .end_v1
.skip_v1:
    inc cl
    add edi, 4
    jmp .iterate_v1
.end_v1:
    popa
    sti
    iret

.pit_unhook:
    pusha
    mov cl, byte 0 ; Loop counter for iteration
    mov edi, PIT_Hooks
.iterate_u1:
    cmp cl, byte 32
    je .end_u1
    mov edx, dword [edi]
    cmp edx, ebx
    jne .skip_u1
    ; Skip if not equal to the function ptr, otherwise set it
    mov dword [edi], dword 0x0
    jmp .end_u1
.skip_u1:
    inc cl
    add edi, 4
    jmp .iterate_u1
.end_u1:
    popa
    sti
    iret