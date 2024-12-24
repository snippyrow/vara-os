CFLAGS = -ffreestanding -g -m32
SOURCES = boot.s kernel.s

all: asm link run

asm:
	nasm -felf32 "Source/Boot/boot.s" -f bin -o "Binaries/boot.bin"
# /usr/local/i386elfgcc/bin/i386-elf-gcc $(CFLAGS) -c Source/kernel.cpp -o Binaries/kernel.o
	nasm "Source/Boot/interface.s" -f elf -o "Binaries/interface.o"
	nasm "Source/Boot/interrupt.s" -f elf -o "Binaries/interrupt.o"
	nasm "Source/Boot/driver.s" -f elf -o "Binaries/driver.o"
# nasm "Source/Asm/proc.s" -f elf -o "Binaries/proc.o"
# /usr/local/i386elfgcc/bin/i386-elf-gcc $(CFLAGS) -c Source/Utilities/Util.cpp -o Binaries/util.o

link:
	/usr/local/i386elfgcc/bin/i386-elf-ld -o "Binaries/loader.bin" -Ttext 0x7e00 "Binaries/interface.o" "Binaries/interrupt.o" "Binaries/driver.o" --oformat binary

run:
	dd if=Binaries/boot.bin of=main.img bs=512 count=63
	dd if=Binaries/loader.bin of=main.img bs=512 seek=1
	dd if=Assets/font.bin of=main.img bs=512 seek=40
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

# sudo dd if=main.img of=/dev/sda bs=4M status=progress && sync
# -enable-kvm
# cloc . --exclude-dir=.venv,OLD