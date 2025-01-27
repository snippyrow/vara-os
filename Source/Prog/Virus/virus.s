[bits 32]
[org 0x400000] ; keep clear of stack!

headers:
    origin_addr: dd 0x400000
    start_addr: dd begin
    PID: resd 1
    alive: db 1
    freeze_events: db 1
    running_directory: resd 1
    args: resd 1

begin:
    ; Request all hooks
    mov eax, 0x37
    int 0x80
    ; Deregister all kbd/pit hooks
    mov ecx, 32 ; counter, we use STDOUT
    xor edi, edi
.loop_kbd:
    mov dword [eax + edi], 0
    add edi, 4
    dec ecx
    jnz .loop_kbd

    mov ecx, 32
    xor edi, edi
.loop_pit:
    mov dword [ebx + edi], 0
    add edi, 4
    dec ecx
    jnz .loop_pit

fun_loop:
    mov eax, fun
    int 0x70
    jmp fun_loop


fun: db 10,"YOU HAVE BEEN HAXXED!! XDDDDDDDD",0