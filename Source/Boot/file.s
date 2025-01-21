; CFAT32 Filesystem implementation
; Each cluster is 512B, or one sector of the disk.
; The FAT (File Allocation Table) is located in the first few clusters, and they are reserved
; When referencing a cluster, it is automatically offset by the length of the FAT.

; There can be 16 indexed objects in each cluster inside a directory, each is 32 bytes long

; FAT Structure:
; Each four bytes specify the properties of that cluster. For example, the first entry would correspond to cluster 0.
; Files and directories appear the same, as it's just a file that gets treated differently
; Special FAT definitions:
; 0xFFFFFFFF - End-of-chain, for both directories and files.
; 0x00FFFFFF - Empty cluster. This can be written to.
; All FAT clusters defined are little-endian, where the smallest byte comes first.
; Clusters in the data region can be used by both indexing and raw data for files and directories

; When you jump to a directory, it simply reloads. Otherwise locate the first cluster
; Keep in mind that the starting cluster is in the directory object attributes

; Inside a user directory, there is a special type of object called a navigator. It links up with info towards the parent directory struct.

; FAT Object Attributes:
; 0x00 - Empty
; 0x01 - User File
; 0x02 - User Directory
; 0x04 - System File
; 0x08 - System Directory
; 0x10 - Raw
; 0x80 - Navigator

; A directory cluster contains 16 subdirectories/files, that is structured like this: (minus 1 byte for rounding)
; char Object name[8]
; char Object ext[3]
; uint8_t attributes
; uint32_t cluster
; uint32_t modified
; uint32_t created
; uint32_t Object size
; uint32_t UUID

; The MBR is located on the first sector, and after comes the kernel code.
; At the very start of the volume, a table called the superblock table exists. This table is loaded into memory at format, and is updated whenever needed.
; The superblock table is designed to keep track of used clusters in the data region, and the FAT tracks where those clusters actually go. This is designed to improve scan times.
; After some offset, the FAT as well as the filesystem begins.
; The first directory created is the root directory, starting at cluster 0. It is spawned on-format.

; ** Note: FAT_LENGTH capped at <32640, due to how many sectors ata_write can do at once in the format stage
; The maximum number of entries per directory is 1024 due to memory limits
FAT_OFFSET equ 200 ; 200 sector offset from code
FAT_LENGTH equ 1024 ; 1024 clusters indexed in the FAT
MAX_PER_DIR equ 1024
Secotrs_Per_Cluster equ 1

EOC equ 0xFFFFFFFF
NONE equ 0x00FFFFFF

[global FAT_Format]
[extern malloc]
[extern free]
[extern ata_lba_write]
[extern ata_lba_read]
[global fat_next]
[global fat_update]
[global fat_mko]
[bits 32]

; Each sector of the FAT can index 128 further clusters (sectors)
; Format the entire FAT to empty clusters, in preperation for new files
; Return EAX 0 if error
FAT_Format:
    ; Reserve a place for listing directory entries, and for keeping track of the clusters indexed in the FAT
    mov eax, (MAX_PER_DIR * 32) + (MAX_PER_DIR / 32) * 4 ; First part for listing entires, second for clusters
    call malloc
    test eax, eax
    jz .end
    mov dword [list_ptr], eax ; move ptr

    ; Have the entire FAT loaded into memory to format
    mov eax, dword FAT_LENGTH ; 512 bytes
    shl eax, 2 ; x 4
    mov ecx, eax
    push ecx
    call malloc
    ; test
    ;mov eax, 0x100000
    test eax, eax
    jz .end ; If malloc failed

    mov edi, eax ; current ptr
    mov ebp, eax ; base for the buffer

    ; Fill buffer with all NONE, except for EOC for the root
    ; ECX is already loaded with # of bytes
    mov eax, dword NONE
    mov ecx, dword [esp]
.loop:
    mov dword [edi], eax
    add edi, 4
    dec ecx
    test ecx, ecx
    jz .continue
    jmp .loop
.continue:
    ; Add the first EOC
    mov edi, ebp
    mov dword [edi], dword EOC
    ; Now write the entire FAT
    mov eax, dword FAT_OFFSET
    mov ecx, dword FAT_LENGTH
    shr ecx, 7 ; / 128 for length in clusters of the disk
    call ata_lba_write

    ; Free memory
    mov eax, ebp
    pop ebx
    call free

    mov eax, 1 ; success
.end:
    ret

; EAX = input cluster, return EAX = next cluster (EOC if end)
fat_next:
    push ecx
    push edx
    push edi
    mov edx, eax
    shr eax, 7 ; / 128
    add eax, dword FAT_OFFSET
    
    cmp eax, dword [loaded]
    je .send ; if the sector has already been cached
    ; EAX now contains starting LBA
    mov cl, 1
    mov edi, page
    call ata_lba_read
    mov dword [loaded], eax ; save new value
.send:
    and edx, dword 0b01111111 ; mod 128
    shl edx, 2 ; x 4 for dword
    mov eax, dword [page + edx]
    pop edi
    pop edx
    pop ecx
    ret

; Return EAX = avalible FAT cluster
; Scan entire FAT volume for avalible clusters
fat_scan:
    push edi
    push esi
    push ecx
    mov edi, page ; base ptr for comparison and reading disk
    mov eax, dword FAT_OFFSET - 1 ; LBA incrementation
    mov dword [loaded], dword 0xFFFFFFFF
.loop_next:
    ; EAX/EDI already loaded with LBA and buffer
    mov cl, 1
    inc eax
    cmp eax, (FAT_LENGTH * 4) / 512 + FAT_OFFSET
    ja .none
    call ata_lba_read
    xor esi, esi ; page offset
    mov cl, 128 ; becomes counter
.loop_c:
    cmp dword [edi + esi], dword NONE
    je .end
    ; If not blank, inc
    add esi, 4
    dec cl
    jz .loop_next
    jmp .loop_c
.end:
    shr esi, 2 ; /4 to find cluster
    sub eax, dword FAT_OFFSET ; localize LBA to FAT cluster
    shr eax, 7 ; x 128 to go to cluster
    add eax, esi
    pop ecx
    pop esi
    pop edi
    ret
.none:
    mov eax, 0xFFFFFFFF ; if failed
    pop ecx
    pop esi
    pop edi
    ret
    

; EAX = index cluster, EBX = new cluster value
fat_update:
    push eax
    push ecx
    push edx
    push edi
    ; Cache the new sector
    mov edx, eax
    shr eax, 7 ; / 128
    add eax, dword FAT_OFFSET

    cmp eax, dword [loaded]
    je .change

    mov cl, 1
    mov edi, page
    call ata_lba_read
    mov dword [loaded], eax ; save new value
.change:
    and edx, dword 0b01111111 ; mod 128
    shl edx, 2 ; x 4 for dword
    mov dword [page + edx], ebx
    ; EAX already has the required LBA, as does CL
    mov edi, page
    call ata_lba_write
    pop edi
    pop edx
    pop ecx
    pop eax
    ret

; EAX = directory entry cluster, return EAX = ptr
fat_dir_list:
    ; loop through, adding to the list of all clusters
    mov edi, dword [list_ptr]

    ; Convert first cluster to LBA
    ; EDI is restored after the ATA call
    push eax
    add eax, dword FAT_OFFSET
    add eax, (FAT_LENGTH * 4) / 512 ; go past FAT
    mov cl, 1
    call ata_lba_read
    add edi, 512
    pop eax

.fat_loop:
    call fat_next
    cmp eax, dword EOC
    je .end_scan
    ; Convert next cluster to LBA
    push eax
    add eax, dword FAT_OFFSET
    add eax, (FAT_LENGTH * 4) / 512 ; go past FAT
    call ata_lba_read
    pop eax
    add edi, 512
    jmp .fat_loop
.end_scan:
    mov eax, dword [list_ptr]
    ret


; EAX = file cluster start, EBX = output ptr
fat_o_read:
    ; loop through, adding to the list of all clusters
    mov edi, ebx

    ; Convert first cluster to LBA
    ; EDI is restored after the ATA call
    push eax
    add eax, dword FAT_OFFSET
    add eax, (FAT_LENGTH * 4) / 512 ; go past FAT
    mov cl, 1
    call ata_lba_read
    add edi, 512
    pop eax

.fat_loop:
    call fat_next
    cmp eax, dword EOC
    je .end_scan
    ; Convert next cluster to LBA
    push eax
    add eax, dword FAT_OFFSET
    add eax, (FAT_LENGTH * 4) / 512 ; go past FAT
    call ata_lba_read
    pop eax
    add edi, 512
    jmp .fat_loop
.end_scan:
    ret


; EAX = fat object ptr, EBX = directory entry cluster
fat_mko:
    pusha
    ; Firstly, find if there is space in the root cluster. Otherwise, continue, make a new cluster if needed.
    ; Recursivly search directory structure
    push eax ; pushed until we need it
    mov edi, page
    mov eax, ebx
    add eax, dword FAT_OFFSET
    add eax, (FAT_LENGTH * 4) / 512
    mov cl, 1
    mov dword [loaded], dword 0xFFFFFFFF ; disable for this command
    call ata_lba_read
    
    xor ebp, ebp ; offset within the page
    xor ch, ch ; ch is the counter
.loop_ava:
    mov al, byte [edi + ebp + 11]
    test al, al
    jz .avalible
    ; Otherwise, increment ebp and counter
    inc ch
    add ebp, 32
    cmp ch, 16
    jb .loop_ava
.new_load:
    ; If we are out of spots in this cluster
    xor ebp, ebp
    xor ch, ch
    mov eax, ebx
    push eax ; save current cluster, in case we need a new one
    call fat_next
    cmp eax, dword EOC
    je .new ; make a new cluster
    pop eax
    ; Otherwise read into the next one
    mov ebx, eax ; store the new cluster for the next-next, and for if it is avalible
    add eax, dword FAT_OFFSET
    add eax, (FAT_LENGTH * 4) / 512
    ; cl/edi is set
    call ata_lba_read
    jmp .loop_ava

.new:
    ; TODO: Finish new, make the FAT update, provide clusters for navigators and make a function to search for unused clusters/dealloc
    pop ecx ; the current end
    call fat_scan
    cmp eax, dword 0xFFFFFFFF
    je 0
    push eax
    mov ebx, eax ; new cluster value
    mov eax, ecx ; index to change
    call fat_update
    mov eax, ebx
    mov ebx, dword EOC
    call fat_update
    pop ebx ; searched cluster
    mov ebp, 0
    mov edi, page
    
.avalible:
    ; EBX has the cluster needed, EBP contains the offset within the page region and EDI has the page itself
    ; Copy fat to desired spot
    pop esi ; ptr to struct
    ; Scan for the next cluster avalible
    call fat_scan
    cmp eax, dword 0xFFFFFFFF
    je 0
    ; EAX has index
    push ebx
    mov ebx, dword EOC
    call fat_update
    pop ebx
    ; Move EAX into the cluster
    mov dword [esi + 12], eax

    mov eax, ebx
    add eax, dword FAT_OFFSET
    add eax, (FAT_LENGTH * 4) / 512
    mov cl, 1
    call ata_lba_read ; read before writing changes

    add edi, ebp ; add page offset
    mov ecx, 32 ; 32 bytes
    call memcpy

    mov edi, page
    mov cl, 1
    call ata_lba_write ; commit changes
    popa
    ret

.err:
    jmp 0

; EDI = destination, ESI = source, ECX = # of bytes
memcpy:
    push esi
    push edi
    cld
.loop:
    movsb ; Copy byte from [esi] to [edi], increments both
    dec ecx
    jnz .loop
    pop edi
    pop esi
    ret

; Fast 512-byte page instead of needing malloc
page:
    resb 512
loaded:
    dd 0xFFFFFFFF ; The currently loaded LBA, to enable caches
list_ptr:
    resd 1 ; points to malloc'd ptr for listing entries in a directroy and for counting clusters