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

# compile shell program on boot
	nasm -felf32 "Source/Prog/Shell/shell.s" -f bin -o "Binaries/shell.bin"
# nasm "Source/Asm/proc.s" -f elf -o "Binaries/proc.o"
# /usr/local/i386elfgcc/bin/i386-elf-gcc $(CFLAGS) -c Source/Utilities/Util.cpp -o Binaries/util.o

link:
	/usr/local/i386elfgcc/bin/i386-elf-ld -o "Binaries/k_loader.bin" -Ttext 0x7e00 "Binaries/interface.o" "Binaries/interrupt.o" "Binaries/driver.o" "Binaries/loader.o" "Binaries/proc.o" --oformat binary
# /usr/local/i386elfgcc/bin/i386-elf-ld -o "Binaries/shell.bin" -Ttext 0x400000 "Binaries/shell_p.o" --oformat binary

run:
	dd if=Binaries/boot.bin of=main.img bs=512
	dd if=Binaries/k_loader.bin of=main.img bs=512 seek=1
	dd if=Assets/font.bin of=main.img bs=512 seek=40
	dd if=Binaries/shell.bin of=main.img bs=512 seek=50
	dd if=/dev/zero bs=1 count=100000 >> main.img

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

# sudo dd if=main.img of=/dev/sda bs=4M status=progress && sync
# -enable-kvm
# cloc . --exclude-dir=.venv,OLD
# qemu-img convert -f raw -O raw main.img output.img (prepare image for vbox)


# TODO:
#	Write syscalls for filesystem
#	Process management