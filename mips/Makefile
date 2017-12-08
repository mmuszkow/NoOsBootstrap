QEMU       := qemu-system-mips64el
QEMU_FLAGS := -cpu R4000 -no-reboot -m 128
ASM_FLAGS  := -EL -march=r4000
TOOLCHAIN  := mips64-linux-gnu

all: boot-mips-jazz

clean:
	rm -f *.o
	rm -f *.elf
	rm -f *.img

openbios-jazz:
	./font2inc.py > font8x16.inc
	$(TOOLCHAIN)-as $(ASM_FLAGS) -o $@.o $@.s
	$(TOOLCHAIN)-ld -EL -A r4000 -Ttext 0xBFC00000 -o $@.elf $@.o
	$(TOOLCHAIN)-objcopy -O binary -j .text $@.elf mipsel_bios.bin

boot-mips-jazz: openbios-jazz
	$(TOOLCHAIN)-as $(ASM_FLAGS) -o $@.o $@.s 
	$(TOOLCHAIN)-ld -EL -A r4000 -o $@.elf -Ttext 0x1000 $@.o
	$(TOOLCHAIN)-objcopy -O binary -j .text $@.elf $@.img

test: boot-mips-jazz
	$(QEMU) -M magnum -fda boot-mips-jazz.img $(QEMU_FLAGS)

