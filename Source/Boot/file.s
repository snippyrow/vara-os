; CFAT32 Filesystem implementation
; Each cluster is 512B, or one sector of the disk.
; The FAT (File Allocation Table) is located in the first few clusters, and they are reserved
; When referencing a cluster, it is automatically offset by the length of the FAT.

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

