QEMU       := qemu-system-arm
# memory MUST be at least 128, without that vc-base will be unset
QEMU_FLAGS := -no-reboot -m 128
TOOLCHAIN  := arm-linux-gnu

all: boot-arm-raspi

clean:
	rm -f *.o
	rm -f *.elf
	rm -f *.inc
	rm -f *.img

boot-arm-raspi:
	python bmp2inc.py > bmp_no_os.inc
	$(TOOLCHAIN)-as -o $@.o -mcpu=arm1176jzf-s $@.s
	$(TOOLCHAIN)-ld -o $@.elf -Ttext 0x8000 $@.o

test: boot-arm-raspi
	$(QEMU) -M raspi2 -kernel boot-arm-raspi.elf $(QEMU_FLAGS)

