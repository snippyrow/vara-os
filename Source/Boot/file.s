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
; After some fofset, the FAT as well as the filesystem begins.
; The first directory created is the root directory, starting at cluster 0. It is spawned on-format.

; ** Note: FAT_LENGTH capped at <32640, due to how many sectors ata_write can do at once
FAT_OFFSET equ 200 ; 200 sector offset from code
FAT_LENGTH equ 1024 ; 1024 clusters in the FAT
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
[bits 32]

; Each sector of the FAT can index 128 further clusters (sectors)
; Format the entire FAT to empty clusters, in preperation for new files
; Return EAX 0 if error
FAT_Format:
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
    cmp eax, dword [loaded]
    je .send ; if the sector has already been cached
    shr eax, 7 ; / 128
    add eax, dword FAT_OFFSET
    ; EAX now contains starting LBA
    mov cl, 1
    mov edi, page
    call ata_lba_read
    mov dword [loaded], edx ; save new value
.send:
    and edx, dword 0b01111111 ; mod 128
    shl edx, 2 ; x 4 for dword
    mov eax, dword [page + edx]
    pop edi
    pop edx
    pop ecx
    ret

; EAX = index cluster, EBX = new cluster
fat_update:
    push eax
    push ecx
    push edx
    push edi
    cmp eax, dword [loaded]
    je .change
    ; Cache the new sector
    mov edx, eax
    shr eax, 7 ; / 128
    add eax, dword FAT_OFFSET
    mov cl, 1
    mov edi, page
    call ata_lba_read
    mov dword [loaded], edx ; save new value
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

; Fast 512-byte page instead of needing malloc
page:
    resb 512

loaded:
    dd 0xFFFFFFFF ; The current cluster sitting in the page (set to a random value so not 0)