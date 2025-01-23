; The new SFAT32 filesystem implementation, wirtten for faster access times

; Each cluster will be 1024B, sitting after.
; The volume contains 8192 superblocks, each indexing 8192 clusters. This gets us a total of 64GB of usable disk space
; The s-block is just used for searching the FAT quicker

; After the entire FAT structure, lies the data region. This is where a majority of the data is actually stored; directories and files.
; Directories and files are essentially the same, just with official ways of usage.
; Inside a file, it simply works like a raw, until it hits an EOC. Objects can span multiple superblocks without issue, they have no real impact on how files work.
; Writing to the disk is cheap relative from reading.

; Inside each sector of the disk, directories can hold a maximum of 16 entries, each being 32 bytes long.
; char Object name[12]
; char Object ext[3]
; uint8_t attributes
; uint32_t cluster
; uint32_t modified
; uint32_t created
; uint32_t Object size

; FAT Object Attributes:
; 0x00 - Empty
; 0x01 - User File
; 0x02 - User Directory
; 0x04 - System File
; 0x08 - System Directory
; 0x10 - Raw
; 0x80 - Navigator

; Within each directory there exists something called a navigator, for returning to the parent directory. It has a cluster attribute linking to it's parent directory start cluster.

; Superblocks should be decoded from a normal cluster entry, with that going from 0-4294967296
; In all cases where we must read from the disk:
; Reading a file (FAT & data)
; Scanning for an avalible cluster

; Each superblock is structured as such: (assume 32 clusters per s-block, 1KB clusters)
; As on the disk
; The first 512 bytes:
;   0-1      - # of allocated clusters
;   2-511    - Bitmap of all allocated clusters (max)
;   512-1536 - First cluster

; The real location of clusters should be decoded from its pointer
; ALL superblock headers should be loaded to memory
; Update: ALL superblock headers are located in the first section of the volume one after another, for ease of use

; Basically ensure all FAT locations have a cluster

; Since cluster 0 should always be used, empty is now 0x00000000, and EOC is 0xFFFFFFFF
NUM_SBLOCK equ 4 ; each one will index 4096 clusters
OFFSET equ 200


EOC  equ 0xFFFFFFFF
NONE equ 0x00FFFFFF

[extern malloc]
[extern free]
[extern ata_lba_read]
[extern ata_lba_write]
[global FAT_Format]
[global fat_mko]
[global fat_read]
[global fat_write]

; Format the volume, load blank caches and bitmaps
; The header cache is a direct mirror of the hard disk, for easier writing
FAT_Format:
    ; Allocate space for all the counters. 
    ; Since we probably wont have many superblocks, only use 512B (good for 256 superblocks)
    mov eax, 512
    call malloc
    test eax, eax
    jz .failed
    mov dword [counters], eax
    mov edi, eax
    mov eax, 0
    mov ecx, 512
    call memset_dword

    ; Now allocate space for all bitmapped headers
    ; Each superblock gets exactly 512B
    mov eax, NUM_SBLOCK * 512
    call malloc
    test eax, eax
    jz .failed
    mov dword [bitmaps], eax
    mov edi, eax
    mov eax, 0
    mov ecx, NUM_SBLOCK * 512
    call memset_dword

    ; Allocate space for FAT
    mov eax, 32 * 512
    call malloc
    test eax, eax
    jz .failed

    mov edi, eax
    mov ecx, (32 * 512) / 4
    mov eax, NONE
    call memset_dword


    ; Allocate space for an example FAT entry
    mov eax, OFFSET + NUM_SBLOCK + 1 ; past bitmaps and counters
    mov edx, NUM_SBLOCK ; counter
.fat_loop:
    mov cl, 32
    call ata_lba_write
    add eax, 32
    dec edx
    jnz .fat_loop

    ; Now write all headers
    mov eax, OFFSET
    mov cl, 1
    mov edi, dword [counters]
    call ata_lba_write

    ; Write headers
    mov eax, OFFSET + 1
    mov cl, NUM_SBLOCK
    mov edi, dword [bitmaps]
    call ata_lba_write

    ; Now write FAT entries
    ; Loop for each s-block, write in 32 LBA's each
    
    mov eax, 0
    mov ebx, EOC
    call _fat_update
    mov eax, 1 ; success
    ret

.failed:
    xor eax, eax ; error code faield
    ret

; Return EAX = nearest returned cluster, 0 = failed
; continually loop through smaller and smaller sections of the header cache until a usable sector is found
_fat_scan:
    push edx
    push ecx
    push ebx
    push ebp
    ; loop through superblocks
    mov ecx, NUM_SBLOCK
    xor edx, edx ; cluster index
    xor ebx, ebx ; s-block counter
.cnt_loop:
    mov ebp, [counters]
    cmp word [ebp], 4096
    jb .continue ; if below max limit
    add ebp, 2
    add edx, 4096
    inc ebx
    dec ecx
    jz .failed
    jmp .cnt_loop
.continue:
    shl ebx, 9 ; x 512 for proper s-block section
    mov ebp, [bitmaps]
    add ebp, ebx
    ; EBX is now redundant
.d_loop:
    ; Loop over the doublewords
    cmp dword [ebp], 0xFFFFFFFF
    jne .d_continue
    add edx, 32
    add ebp, 4
    jmp .d_loop
.d_continue:
    mov eax, dword [ebp]
    xor ecx, ecx ; bit index (CL)
.d_bt:
    ; loop over dword
    bt eax, ecx
    jnc .found
    inc edx
    inc ecx
    jmp .d_bt
.found:
    mov eax, edx
    pop ebp
    pop ebx
    pop ecx
    pop edx
    ret
.failed:
    xor eax, eax
    pop ebp
    pop ebx
    pop ecx
    pop edx
    ret


; EAX = cluster index, return EAX = next cluster ID
_fat_next:
    push ebx
    push ecx
    push edi
    mov ebx, eax
    shr eax, 7 ; / 128 to find LBA
    and ebx, 0b01111111 ; mod 128 to find addr within LBA
    shl ebx, 2 ; x 4 to get the real offset addr
    add eax, OFFSET + NUM_SBLOCK + 1
    mov cl, 1
    mov edi, page
    call ata_lba_read

    mov eax, dword [page + ebx]
    pop edi
    pop ecx
    pop ebx
    ret

; Update a FAT entry and the surrounding bitmap
; EAX = cluster index, EBX = new value.
cluster_index: resd 1
_fat_update:
    push eax
    push ebx
    push ecx
    push edx
    push ebp
    push edi

    mov dword [cluster_index], eax
    mov edx, eax

    shr eax, 7 ; / 128 to find LBA
    and edx, 0b01111111 ; mod 128 to find addr within LBA
    shl edx, 2 ; x 4 to get the real offset addr
    add eax, OFFSET + NUM_SBLOCK + 1
    mov cl, 1
    mov edi, page
    call ata_lba_read

    mov dword [page + edx], ebx
    call ata_lba_write
    ; Now update counter

    mov eax, dword [cluster_index]
    mov ebx, eax ; backup
    

    ; Now allocate, EBX = cluster index
    mov ebp, [bitmaps]
    mov eax, ebx
    mov ecx, ebx
    shr eax, 3 ; / 8 to get byte
    and ecx, 0b111 ; mod to get bit offset
    mov dx, 1
    shl dx, cl
    xor ebx, ebx
    mov bl, byte [ebp + eax]
    bt ebx, ecx
    jc .continue ; already a 1

    ; Increment the counter
    pusha
    mov eax, dword [cluster_index]
    shr eax, 12 ; / 4096 to get s-block
    shl eax, 1 ; x 2 to get counter addr
    mov ebp, dword [counters]
    inc word [ebp + eax]
    mov eax, OFFSET
    mov cl, 1
    mov edi, [counters]
    call ata_lba_write ; commit new counter
    popa

.continue:

    or bl, dl
    mov byte [ebp + eax], bl

    ; Write that s-block bitmap
    mov eax, OFFSET + 1
    mov cl, NUM_SBLOCK
    mov edi, ebp
    call ata_lba_write

    pop edi
    pop ebp
    pop edx
    pop ecx
    pop ebx
    pop eax
    ; return when done
    ret

; simply remove an already on cluster
; EAX = cluster index
fat_deallocate:
    push eax
    mov ebx, eax
    shr ebx, 7 ; FAT LBA
    and eax, 0b01111111
    shl eax, 2 ; x 4 for the absolute offset within sector
    add ebx, OFFSET + NUM_SBLOCK + 1
    mov cl, 1
    mov edi, page
    call ata_lba_read
    mov dword [edi + eax], NONE
    call ata_lba_write
    ; Now update counter & bitmap

    pop eax
    mov ebx, eax
    ; Divide cluster by 4096 to get s-block
    shr eax, 12 ; / 4096
    shl eax, 1 ; x 2 for word offset
    mov edi, [counters]
    dec word [edi + eax]
    ; Write in counters
    mov eax, OFFSET
    ; CL/EDI is set
    mov cl, 1
    call ata_lba_write

    ; Now update bitmap (cluster index in EBX)
    ; Divide by 8 to get the bit
    ; Mod 8 for bit index
    mov eax, ebx
    shr eax, 3 ; / 8
    and ecx, 0b111 ; mod
    mov dx, 1
    shl dx, cl
    mov edi, [bitmaps]
    mov bl, byte [edi + eax]
    not dl
    and bl, dl
    mov byte [edi + eax], bl

    ; Now update all bitmaps
    mov eax, OFFSET + 1
    mov cl, NUM_SBLOCK
    ; EDI loaded
    call ata_lba_write

    ret ; end, return




; EAX = directory entry cluster, EBX = ptr to fat object, ESI = parent directory name (for the navigator class)
; First, find a superblock with enough clusters
; Firstly, it shoudl usually work with a single cluster avalible for the first in a raw, however if the directory structure is too large, it requires two.
; Check if the directory entry will require an extra cluster, and scan accordingly.
; Once found, either/or add a new FAT entry that works for the file. Extend the directory if needed.
; Since searching a chain may use many disk reads, use a cache just in case. Scanning can be done with memory only
dir_lba: resd 1
dir_cluster: resd 1
fat_mko:
    pusha
    push esi
    ; First search directory structure
    ; Look through to see if a spot is avalible
    mov dword [dir_cluster], eax
    shl eax, 1 ; x 2 since there are two sectors per cluster (1KB)
    add eax, OFFSET + (NUM_SBLOCK * 32) + NUM_SBLOCK + 1
    mov dword [dir_lba], eax
    mov cl, 2
    mov edi, page_raw

    call ata_lba_read
    mov dx, 32 ; 32 possible entries
    mov ebp, page_raw ; for attribute
.loop_dir:
    mov ch, byte [ebp + 15]
    test ch, ch
    jz .found ; found an avalible spot
    add ebp, 32
    dec dx
    jz .new ; new must be loaded/made
    jmp .loop_dir
.found:
    ; Scan for an avalible cluster
    call _fat_scan
    test eax, eax
    jz .failed
    ; Set cluster dword
    mov dword [ebx + 16], eax
    push ebx
    mov esi, ebx
    mov ebx, EOC
    call _fat_update

    ; copy memory
    mov edi, ebp
    mov ecx, 32
    call memcpy
    mov ebp, eax ; copy the newly scanned cluster
    mov eax, dword [dir_lba]
    mov edi, page_raw
    mov cl, 2
    ; EAX already loaded
    call ata_lba_write ; commit

    ; If it is a directory, automatically insert a navigator linking to the parent directory
    pop ebx
    cmp byte [ebx + 15], 2
    je .addnav
    pop esi
    popa
    ret
    ; now commit LBA
.addnav:
    mov edi, page_raw
    mov eax, 0
    mov ecx, 256
    call memset_dword ; prepare to insert
    
    mov eax, ebp

    mov ecx, 32
    mov esi, navigator_template
    ; EDI is set
    call memcpy
    
    mov edx, dword [dir_cluster]
    mov dword [edi + 16], edx ; set parent cluster
    ; Copy FAT object name to nav name
    pop esi
    mov ecx, 12
    call memcpy

    shl eax, 1
    add eax, OFFSET + (NUM_SBLOCK * 32) + NUM_SBLOCK + 1
    mov cl, 2
    ; EDI is set
    call ata_lba_write


    popa
    ret
.new:
    ; Find next
    mov eax, dword [dir_cluster]
    call _fat_next
    cmp eax, EOC
    je .gen
    ; Otherwise if not EOC, load
    mov dword [dir_cluster], eax
    shl eax, 1
    add eax, OFFSET + (NUM_SBLOCK * 32) + NUM_SBLOCK + 1
    mov dword [dir_lba], eax
    mov cl, 2
    mov edi, page_raw
    call ata_lba_read

    mov dx, 32 ; 32 possible entries
    mov ebp, page_raw ; for attribute
    jmp .loop_dir
.gen:
    ; Generate new
    call _fat_scan
    test eax, eax
    jz .failed
    push eax
    push ebx
    ; Update current directory link
    mov ebx, eax
    mov eax, dword [dir_cluster]
    call _fat_update

    ; Update new
    mov eax, ebx
    mov ebx, EOC
    call _fat_update

    pop ebx
    pop eax

    shl eax, 1
    add eax, OFFSET + (NUM_SBLOCK * 32) + NUM_SBLOCK + 1
    push eax
    mov edi, page_raw
    mov ecx, 1024 / 4
    mov eax, 0
    call memset_dword

    pop eax
    mov edi, page_raw
    mov ecx, 32
    mov esi, ebx
    call memcpy
    mov cl, 2
    call ata_lba_write ; commit new write

    popa
    ret
.failed:
    pop esi
    popa
    xor eax, eax
    ret

; EAX = raw entry cluster, EDI = ptr to buffer, ECX = max # of clusters to read
fat_read:
    pusha
    mov ebp, edi
    mov ebx, ecx ; new counter
    mov edx, eax ; backup
    ; convert to LBA
    shl eax, 1
    add eax, OFFSET + (NUM_SBLOCK * 32) + NUM_SBLOCK + 1
    mov cl, 2
    mov edi, page_raw
.read:
    call ata_lba_read
    mov ecx, 1024
    mov edi, ebp
    mov esi, page_raw
    call memcpy
    dec ebx
    jz .end

    ; Load new and repeat
    add ebp, 1024
    mov eax, edx
    call _fat_next
    mov edx, eax
    shl eax, 1
    add eax, OFFSET + (NUM_SBLOCK * 32) + NUM_SBLOCK + 1
    mov cl, 2
    mov edi, page_raw
    jmp .read

.end:
    popa
    ret

; EAX = raw file begin, EDI = ptr to buffer, ECX = size of buffer
; Be able to allocate and deallocate clusters
fat_write:
    mov ebp, edi ; back-up
    cld ; incrementing
    mov esi, ebp
    mov edi, page_raw
    mov bx, 1024 ; cluster size
.loop:
    movsb ; copy from ESI to EDI (buffer -> page)
    dec bx
    jz .load_new
    dec ecx
    jnz .loop
    jmp .end
.load_new:
    ; If we end our cluster
    push eax
    shl eax, 1
    add eax, OFFSET + (NUM_SBLOCK * 32) + NUM_SBLOCK + 1
    mov cl, 2
    mov edi, page_raw

    call ata_lba_write ; commit
    ; Find next and repeat
    pop eax
    call _fat_next
    cmp eax, EOC
    je .expand
    ; If not, simply load next
    mov bx, 1024
    mov esi, ebp
    mov edi, page_raw

    dec ecx
    jz .end
    jmp .loop
.expand:
    ; Same procedure as load new, but instead generate a new location
    push eax
    call _fat_scan
    mov ebx, eax
    pop eax
    call _fat_update ; update current file to link to the next cluster
    mov eax, ebx
    mov ebx, EOC
    call _fat_update
    ; EAX now has new cluster, zero it out
    push eax
    push ecx
    mov al, 0
    mov ecx, 1024
    call memset
    pop ecx
    pop eax

    mov bx, 1024
    mov esi, ebp
    mov edi, page_raw

    jmp .loop

.end:
    ; If done, resume by zeroing the rest of the raw cluster and commit
    ; bx = how many left
    push eax ; current cluster
    movzx ecx, bx
    mov edi, page_raw
    mov ebx, 1024
    sub ebx, ecx
    add edi, ebx
    mov al, 0
    call memset
    pop eax
    shl eax, 1
    add eax, OFFSET + (NUM_SBLOCK * 32) + NUM_SBLOCK + 1
    mov cl, 2
    mov edi, page_raw
    call ata_lba_write ; commit
    ; Now deallocate all remaining clusters beyond this point
    ret



; EDI = destination, ESI = source, ECX = # of bytes
memcpy:
    push esi
    push edi
    push ecx
    cld
.loop:
    movsb ; Copy byte from [esi] to [edi], increments both
    dec ecx
    jnz .loop
    pop ecx
    pop edi
    pop esi
    ret


; EDI = destination ptr, EAX = replace dword, ECX = # of dwords
memset_dword:
    push edi
    push ecx
.loop:
    mov dword [edi], eax
    add edi, 4
    dec ecx
    jnz .loop
    pop ecx
    pop edi
    ret

; EDI = destination ptr, al = replace byte, ECX = # of bytes
memset:
    push edi
    push ecx
.loop:
    mov byte [edi], al
    inc edi
    dec ecx
    jnz .loop
    pop ecx
    pop edi
    ret

; Temporary page for using LBA
page:
    resb 512

page_raw:
    resb 1024

bitmaps: ; bitmaps for each superblock index
    resd 1

counters: ; counters
    resd 1

navigator_template:
    db "../",0,0,0,0,0,0,0,0,0
    db 0,0,0
    db 0x80
    dd 0 ; cluster
    dd 0
    dd 0
    dd 0