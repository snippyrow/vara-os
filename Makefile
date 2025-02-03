CFLAGS = -ffreestanding -g -m32
SOURCES = boot.s kernel.s

all: asm link run

asm:
	nasm -felf32 "Source/Boot/boot.s" -f bin -o "Binaries/boot.bin"
# /usr/local/i386elfgcc/bin/i386-elf-gcc $(CFLAGS) -c Source/kernel.cpp -o Binaries/kernel.o
	nasm "Source/Boot/loader.s" -f elf -o "Binaries/loader.o"
	nasm "Source/Boot/interface.s" -f elf -o "Binaries/interface.o"
	nasm "Source/Boot/interrupt.s" -f elf -o "Binaries/interrupt.o"
	nasm "Source/Boot/driver.s" -f elf -o "Binaries/driver.o"
	nasm "Source/Boot/proc.s" -f elf -o "Binaries/proc.o"
	nasm "Source/Boot/file.s" -f elf -o "Binaries/file.o"

# compile shell program on boot
	nasm -felf32 "Source/Prog/Shell/shell.s" -f bin -o "Binaries/shell.bin"

	nasm -felf32 "Source/Prog/Sys/bootmenu.s" -f bin -o "Binaries/bootmenu.bin"
	nasm -felf32 "Source/Prog/Virus/virus.s" -f bin -o "Binaries/virus.bin"
	nasm -felf32 "Source/Prog/Usage/memusage.s" -f bin -o "Binaries/memusage.bin"
	nasm -felf32 "Source/Prog/Textedit/editor.s" -f bin -o "Binaries/texteditor_v1.bin"
	nasm -felf32 "Source/Prog/Sysfetch/fetch.s" -f bin -o "Binaries/sysfetch.bin"


#nasm -felf32 "Source/Prog/Boot/mgr.s" -f bin -o "Binaries/switchmgr.bin"
	nasm "Source/Prog/Boot/mgr.s" -f elf -o "Binaries/switchmgr.o"
# compile window manager in C++
	/usr/local/i386elfgcc/bin/i386-elf-gcc $(CFLAGS) -c Source/Prog/Boot/Windows/init.cpp -o Binaries/win.o
# link
	/usr/local/i386elfgcc/bin/i386-elf-ld -o "Binaries/winmgr.bin" -Ttext 0x800000 "Binaries/switchmgr.o" "Binaries/win.o" --oformat binary

# /usr/local/i386elfgcc/bin/i386-elf-gcc $(CFLAGS) -c Source/Utilities/Util.cpp -o Binaries/util.o

link:
	/usr/local/i386elfgcc/bin/i386-elf-ld -o "Binaries/k_loader.bin" -Ttext 0x7e00 "Binaries/interface.o" "Binaries/interrupt.o" "Binaries/driver.o" "Binaries/loader.o" "Binaries/proc.o" "Binaries/file.o" --oformat binary
# /usr/local/i386elfgcc/bin/i386-elf-ld -o "Binaries/shell.bin" -Ttext 0x400000 "Binaries/shell_p.o" --oformat binary

run:
	dd if=Binaries/boot.bin of=main.img bs=512
	dd if=Binaries/k_loader.bin of=main.img bs=512 seek=1
	dd if=Assets/font.bin of=main.img bs=512 seek=40
	dd if=Binaries/shell.bin of=main.img bs=512 seek=50
	dd if=Binaries/bootmenu.bin of=main.img bs=512 seek=70
	dd if=Binaries/virus.bin of=main.img bs=512 seek=90
	dd if=Binaries/memusage.bin of=main.img bs=512 seek=91
	dd if=Binaries/texteditor_v1.bin of=main.img bs=512 seek=93
	dd if=Binaries/sysfetch.bin of=main.img bs=512 seek=101
	dd if=Binaries/winmgr.bin of=main.img bs=512 seek=103
	dd if=/dev/zero bs=1M count=30 >> main.img
# append 7100000 zeroes to convert to vdi

	qemu-system-x86_64 \
	-enable-kvm \
    -drive file=main.img,format=raw,index=0,if=none,id=mydrive \
	-device ide-hd,drive=mydrive,cyls=1024,heads=16,secs=63,bus=ide.0 \
	-cpu qemu64 \
    -m 128M \
	-boot order=c \
    -d int \
    -no-reboot

	qemu-img convert -f raw -O raw main.img vbox.img
	VBoxManage convertfromraw vbox.img vara.vdi --format VDI


# sudo dd if=main.img of=/dev/sda bs=4M status=progress && sync
# -enable-kvm
# cloc . --exclude-dir=.venv,OLD
# qemu-img convert -f raw -O raw main.img output.img (prepare image for vbox)


# TODO:
#	Write syscalls for filesystem
#	Process management
#	Text editor
#	KnitC compiler