; Lists all processes
; For now, this is the process structure:
; Ignore registers/stack (for now)
; 0-15  : PID
; 16-47 : Ptr
; 48-55 : Flags (0x0 if dead process, 0x1 if baby process, 0x2 if running process)
; 56-63 : Padding

; Theoretical model:
; Contains a parent PID, useful for building a process manager

[bits 32]
[global process_create]
[global process_yield]
[global process_destroy]

MAX_PROC equ 32

; Each process is 8 bytes long in memory
process_list:
    resq MAX_PROC

; EAX
; EBX
; ECX
; EDX
; ESP (Since before the interrupt, jump to the function)
; EBP
; ESI
; EDI
process_states:
    times MAX_PROC resd 8

current_pid:
    dw 1 ; links to first process
proc_index:
    dw 0

; Note: PID is the index incremented by 0x1

; Create a process
; EAX is the function ptr to begin execution
; Return EAX is the PID aka. the index in the process list
; Loop through the list until a dead process is found, and fill it before returning the PID. 0 If failed.
process_create:
    mov edi, process_list
    xor cx, cx ; loop counter to check for max process
.iterate:
    cmp cx, word MAX_PROC
    je .end
    mov bl, byte [edi + 6]
    test bl, bl
    jnz .skip ; if process is alive
    inc cx
    mov word [edi], cx ; update process id
    mov dword [edi + 2], eax ; update ptr
    mov byte [edi + 6], byte 0x1 ; update flag byte to be alive
    movzx eax, cx
    jmp .end
.skip:
    add edi, dword 8
    inc cx
    jmp .iterate
.end:
    ret


; Destroy a process, AKA remove it from a list. Works the same as a process kill.
; When called, and the PID to be removed is the same as the current process it will automatically yield.
; Otherwise, kill the process and return to the caller whether it succeeded or not
; EAX contains the PID
process_destroy:
    and eax, 0x0000FFFF
    dec ax
    shl ax, byte 3
    add eax, process_list
    
    ; eax has process window
    mov [eax + 6], byte 0x0 ; kill
    ret


; Yield the current process to the task scheduler, and it continues to execute another process
; All registers and flags are saved to the task state for this PID, and the new one is loaded.
; It goes in a roundabout way, where each process comes one after another. If there is one process it goes back while saving everything.
; There must always be one process in the list, inserted at the start of execution

; Return address must update to the return vector for the syscall

; ** TODO: Check offsets for stack!! **
; ALSO: Add register saving
process_yield:
    xor eax, eax
    mov ax, [current_pid]
    dec ax ; account for all PID incremented by 1
    mov edi, process_list
    shl ax, byte 3 ; mul by 8
    add edi, eax
    ; edi now contains ptr
    cmp byte [edi + 6], byte 0x2 ; If the flag is old. then save
    jne .continue ; if not 0x2
    ; Coming from a software interrupt, pusha then through a function
    ; Interrupt is 12 bytes (EIP, CS, EFLAGS), pusha is 32 bytes and the function is 4 bytes for the return addr
    mov ebx, [esp + 36] ; 12 + 32 + 4 - 4 (since EIP is saved last)
    mov dword [edi + 2], dword ebx

    xor eax, eax
    mov ax, word [current_pid]
    dec ax
    mov edi, process_states
    shl ax, byte 5 ; x 32
    add edi, eax
    ; save states, EDI has task window
    ; Grab saved register values via the pusha in context
    ; All are offset by the return function addr
    mov eax, [esp + 4] ; EDI (pushed last)
    mov dword [edi + 28], eax
    mov eax, [esp + 8] ; ESI
    mov dword [edi + 24], eax
    mov eax, [esp + 12] ; EBP
    mov dword [edi + 20], eax

    mov eax, esp ; ESP
    add eax, 12 + 32 + 4 ; from before function, pusha and int
    mov dword [edi + 16], eax

    mov eax, [esp + 20] ; EBX
    mov dword [edi + 4], eax
    mov eax, [esp + 24] ; EDX
    mov dword [edi + 8], eax
    mov eax, [esp + 28] ; ECX
    mov dword [edi + 4], eax
    mov eax, [esp + 32] ; EAX
    mov dword [edi], eax

.continue:
    ; check through things to find a new process (EDI is still showing the current process window)
    xor eax, eax
    mov ax, word [proc_index]
    mov edi, process_list
    shl ax, byte 3 ; mul by 8
    add edi, eax
    ; edi now has the updated process window
    mov ax, word [proc_index]
.iterate:
    cmp ax, word MAX_PROC
    je .none
    mov bl, byte [edi + 6] ; flags
    test bl, bl
    jz .skip ; if zero, skip as it is dead
    ; Otherwise, jump here
    mov [edi + 6], byte 0x2 ; set to old all the time
    mov ebx, dword [edi + 2]
    mov dword [esp + 36], ebx ; update EIP return on syscall
    inc ax ; increment for PID working
    mov word [current_pid], ax
    mov word [proc_index], ax
    jmp .end
.skip:
    inc ax
    add edi, 8
    jmp .iterate
    
.none:
    ; If we max out our interrupts with none new found, go back to the old one and change nothing. Change search index to 0
    mov word [proc_index], word 0x0
.end:
    ret