QEMU       := qemu-system-x86_64
QEMU_FLAGS := -no-reboot -m 8
TOOLCHAIN  := x86_64-linux-gnu

all: boot-x86

clean:
	rm -f *.o
	rm -f *.pecoff
	rm -f *.img

boot-x86:
	$(TOOLCHAIN)-as -o $@.o $@.s
	$(TOOLCHAIN)-ld -o $@.pecoff -Ttext 0x7C00 $@.o
	$(TOOLCHAIN)-objcopy -O binary -j .text $@.pecoff $@.img

test: boot-x86
	$(QEMU) -fda boot-x86.img $(QEMU_FLAGS)

