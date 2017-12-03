# Maciek Muszkowski (C) 2017
# compile with:
# as -o boot-x86.o boot-x86.s
# ld -o boot-x86.pecoff -Ttext 0x7C00 boot-x86.o
# objcopy -O binary -j .text boot-x86.pecoff boot-x86.img

    .code16      # 16-bits code, real mode
    .text
    .global _start # executable code

_start:
    # initialize registers
    movw %cs, %ax
    movw %ax, %ds
    movw %ax, %es
    movw %ax, %ss
    xorw %sp, %sp

    # initialize video using int 0x10
    # ah=0, al=3 -> 80x25 text mode
    xorb %ah, %ah
    movb $0x03, %al 
    int  $0x10
    
    # print welcome message using int 0x10
    # bh=page, ah=0x0E, al=char
    leaw txt_welcome, %si
    movb $0x0E, %ah
    movb $0x00, %bh
_putc_loop:
    lodsb        # loads byte from ds:si to al
    orb %al, %al # check if char != 0
    jz  beep     # if yes, finish
    int $0x10    # put al to screen
    jmp _putc_loop
    
beep:
    # PIT's Mode Control Register  0x43
    # Counter 2 Register           0x42
    # System Control Port Register 0x61
    movb $0xB6, %al  # Counter 2, LSB first, square wave  
    outb %al, $0x43  # out 0x43, 0b10110110
    movw $1193, %ax  # freq=1000, PIT_div = 1193180 / freq
    outb %al, $0x42  # out 0x43, LSB(PIT_div)
    shrw $8, %ax
    outb %al, $0x42  # out 0x43, MSB(PIT_div)
    inb  $0x61, %al 
    orb  $3, %al
    outb %al, $0x61  # out 0x51, in(0x61) | 3
    # wait for 100ms (0x30D40) using int 0x15, ah=0x86
    movw $0x8600, %ax
    movw $0x0001, %cx
    movw $0x86A0, %dx
    int  $0x15      # wait for (cx<<16|dx) us
    # stop playing sound
    inb  $0x61, %al
    andb $0xFC, %al
    outb %al, $0x61
    
    # wait for any key using int 0x16
    xorb %ah, %ah
    int  $0x16

reboot:
    int  $0x19           # this should never return
    ljmp $0xf000,$0xfff0 # fallback #1, jmp to reset vector
    jmp  reboot          # fallback #2, try again

txt_welcome: .asciz "No OS installed, press any key to reboot ..."
   
    # bootsector always ends with 0xAA55
    . = _start + 510
    .word 0xAA55

