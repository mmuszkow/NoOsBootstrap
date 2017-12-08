# Maciek Muszkowski (C) 2017

# Jazz is an ancient MIPS architecture using ARC BIOS, 
# dating for the very early 90s (Windows NT 4.0 is the last OS it could run).
#
# I chose it because it was the MIPS arch in QEMU that
# can display video output, which is done by 
# drawing raw pixel data from the G364 framebuffer (extension card).
#
# QEMU has 2 "Jazz-derived" architectures:
# -m magnum and -M pica61 which are essentially the same, but 
# assigns the framebuffer only to magnum.
#
# Jazz MIPS machines used ARC BIOS which you can find in the Internet under 
# names NTPROM.RAW (for WinNT) and RISCOS.RAW (for RiscOS)
# People who distribute these files claim that they are freeware,
# but I'm not sure about that so I decided to write my own simple BIOS
# The architecture is ancient (early 90s) but it can produce a visual output in QEMU
# and is easy to implement drivers so I chose it.

.set noreorder
.set nomips16
.align 2

# This is where bootsector will be loaded (RAM)
.equ BOOTSTRAP_ADDR, 0x1000

_start:
    b reset
    nop

    # values taken from orignal BIOS
    # hexdump -s 0xA0 -n 224 -e '4/4 "0x%.8X " "\n"' mipsel_bios_org.bin 
    # EntryHi, EntryLo0, EntryLo1, PageMask
    # Top 20 bits: VPN.
    # Next 6 bits: PID.
    # Next 6 bits: unused.
    # Next 20 bits: Physical page frame.
    # Next bit: N bit. If set, memory access bypasses the cache. If not set, memory access goes through the cache.
    # Next bit: D bit. If set, memory is writeable. If not set, memory is not writeable.
    # Next bit: V bit. If set, entry is valid.
    # Next bit: G bit. If set, TLB does not check PID for translation.
.tlb_table:
    .word 0xE1000000, 0x03FFC013, 0x00000001, 0x0007E000
    .word 0xE0000000, 0x02000017, 0x00000001, 0x0001E000
    .word 0xE0100000, 0x03C00017, 0x00000001, 0x00000000
    .word 0xE0200000, 0x01800017, 0x01804017, 0x001FE000
    .word 0xE0400000, 0x01808017, 0x0180C017, 0x001FE000
    .word 0xE0800000, 0x01000017, 0x01010017, 0x007FE000
    .word 0xE2000000, 0x02400017, 0x02440017, 0x01FFE000
    .word 0xE4000000, 0x00000017, 0x02400057, 0x00000000
    .word 0xE4002000, 0x02400097, 0x024000D7, 0x00000000
    .word 0xE4004000, 0x02400117, 0x02400157, 0x00000000
    .word 0xE4006000, 0x02400197, 0x024001D7, 0x00000000
    .word 0xE4008000, 0x02400217, 0x02400317, 0x00006000
    .word 0xFFFFE000, 0x00000001, 0x0001FFD7, 0x00000000
    .word 0x10000000, 0x0000141F, 0x00000001, 0x0001E000    
.tlb_table_end:

txt_exc_unhandled: .asciiz "Unhandled exception"

# I'm not sure if jazz supports all of these exceptions
# original BIOS seems to have handler routines for
# 0x200 and 0x380
# tlb refill exception
.org 0x200
    b exc_unhandled
    nop

# xtlb refill exception
.org 0x280
    b exc_unhandled
    nop

# cache error exception
.org 0x300
    b exc_unhandled
    nop

# general exception
# we will handle syscalls here
# $v0 is the syscall code
# see functions definitions for arguments description
# syscall cannot be called from user code
.equ CP0_CAUSE, $13
.equ CP0_EPC,   $14
.equ SYSCALL_PUTS, 4
.equ SYSCALL_GETC, 12
.org 0x380
    # get exception cause
    mfc0 $k0, CP0_CAUSE
    andi $k0, $k0, 0x3C # exc code
    beq  $k0, 0x6C, .int_ret  # ignore TLB load exception after eret, I dunno why it is raised...
    nop
    bne  $k0, 0x20, exc_unhandled # check if syscall
    nop

    # v0 stores syscall cause
    beq  $v0, SYSCALL_PUTS, .syscall_puts
    nop
    beq  $v0, SYSCALL_GETC, .syscall_getc
    nop
    b    exc_unhandled
    nop

    # v0 = 4 -> print string
.syscall_puts:
    jal puts
    nop
    b .int_ret
    nop
    # v0 = 12 -> read char from kbd
.syscall_getc:
    jal getc
    nop
    b .int_ret
    nop
.int_ret:
    mfc0 $k0, CP0_EPC
    addi $k0, $k0, 4
    mtc0 $k0, CP0_EPC
    eret
    nop

# catch interrupt exception
.org 0x400
    b exc_unhandled
    nop

# EJTAG dbg exc
.org 0x480
    b exc_unhandled
    nop

# Unhandled exception handler
exc_unhandled:
    jal  cls
    nop
    la   $a0, txt_exc_unhandled
    move $a1, $zero
    move $a2, $zero
    jal puts
    nop
    b .
    nop

.org 0x500
reset:

#  Setup the memory mapping (TLB)
.equ CP0_INDEX,     $0
.equ CP0_ENTRY_LO0, $2
.equ CP0_ENTRY_LO1, $3
.equ CP0_PAGE_MASK, $5
.equ CP0_ENTRY_HI,  $10

tlb_init:
    # set EntryHi=0x80000000 for each entry
    mtc0  $zero, CP0_ENTRY_LO0
    mtc0  $zero, CP0_ENTRY_LO1
    lui   $t0, 0x8000
    mtc0  $t0, CP0_ENTRY_HI
    mtc0  $zero, CP0_PAGE_MASK
    move  $s0, $zero
    li    $t0, 0x30 # 48 entries in total for R4000
    mtc0  $zero, CP0_INDEX
.tlb_init_entry:
    mtc0  $s0, CP0_INDEX
    addiu $s0, $s0, 1
    bne   $s0, $t0, .tlb_init_entry
    tlbwi 
    # tlbwi instr above: uses the Index register to choose a TLB entry
    # and writes the EntryLo and EntryHi registers into it
    # tlbwi is executed with each loop cause of the branch delay slot

    # now we load our table
    la    $t1, .tlb_table
    la    $t2, .tlb_table_end
    li    $s0, 7 # we start from index #7
.tlb_load_entry:
    lw    $a0, 0($t1)
    lw    $a1, 4($t1)
    lw    $a2, 8($t1)
    lw    $a3, 12($t1)
    mtc0  $a0, CP0_ENTRY_HI
    mtc0  $a1, CP0_ENTRY_LO0
    mtc0  $a2, CP0_ENTRY_LO1
    mtc0  $a3, CP0_PAGE_MASK
    mtc0  $s0, CP0_INDEX
    addiu $s0, $s0, 1
    tlbwi
    addiu $t1, $t1, 16
    bne   $t1, $t2, .tlb_load_entry
    nop
    b     g364_init
    nop

# the dump from original bios is left here for the reference
#li     $zero, 0xffff # wtf?
#b      .wtf1
#nop
#
#.org 0x180
#.ll6:
#lui    $t0, 0xe000
#ori    $t0, $t0, 0xf000
#srl    $t1, $a0, 0x10
#srl    $t3, $a0, 0x4
#li     $v0, 2
#bne    $t1, $v0, .ll4
#andi   $t3, $t3, 0xf
#.ll4:
#li     $v0, 1
#sb     $t3, 0($t0)
#beq    $t1, $v0, .ll5
#nop
#jr     $ra
#nop
#
#.org 0x230
#.wtf3:
#mtc0   $zero, $2 # EntryLo0
#mtc0   $zero, $3 # EntryLo1
#lui    $t0, 0x8000
#mtc0   $t0, $10  # EntryHi
#mtc0   $zero, $5 # PageMask
#move   $s0, $zero
#li     $t0, 48
#mtc0   $zero, $0 # Index
#.ll:
#mtc0   $s0, $0   # Index
#addiu  $s0, $s0, 1
#bne    $s0, $t0, .ll
#tlbwi
#
#lui    $t1, 0xbfc0
#addiu  $t1, $t1, 160
#lui    $t2, 0xbfc0
#addiu  $t2, $t2, 384
#li     $s0, 7
#.ll2:
#lw     $t3, 0($t1)
#lw     $v0, 4($t1)
#lw     $v1, 8($t1)
#lw     $a0, 12($t1)
#mtc0   $v0, $2 # EntryLo0
#mtc0   $v1, $3 # EntryLo1
#mtc0   $a0, $5 # PageMask
#mtc0   $s0, $0 # Index
#addiu  $s0, $s0, 1
#tlbwi
#addiu  $t1, $t1, 16
#bne    $t1, $t2, .ll2
#
#lui    $t0, 0xa000
#ori    $t0, $t0, 0x400
#sw     $s0, 4($t0)
#jr     $ra
#nop
#
#.org 0x3a8
#.wtf1:
#bal    .wtf3
#nop
#
#.org 0x3b0
#mfc0   $k0, $12   # Status
#lui    $k1, 0x10
#mtc0   $zero, $18 # WatchLo
#mtc0   $zero, $19 # WatchHi
#and    $k1, $k1, $k0
#lui    $k0, 0x2040
#ori    $k0, $k0, 0x4
#mtc0   $k0, $12   # Status
#nop
#beqz   $k1, .ll3
#lui    $k0, 0x2040
#.ll3:
#move   $s5, $zero
#lui    $k0, 0x2040
#mtc0   $k0, $12 # Status
#nop
#nop
#mfc0   $t0, $16 # Config
#li     $t1, 35
#srl    $t2, $t0, 0x11
#andi   $t2, $t2, 0x1
#bnez   $t2, .ll7
#srl    $t2, $t0, 0x16
#.ll7:
#li     $t2, -64 # 0x7FFFF.....
#and    $t0, $t0, $t2
#or     $t0, $t0, $t1
#mtc0   $t0, $16 # Config
#nop
#nop
#bal    .ll6
#li     $a0, 0xd0
#
#.org 0x4a8
#.ll5:
#lui    $t0, 0xE100
#addiu  $t0, $t0, 1208
#jr $t0
#nop

# these values are base on QEMU source and may be wrong for real hardware
# all are physical addresses
# 0x60080000 - G364 fb control register
#      0x0800-0x1000 - palette
#      0x1000-0x2000 - cursor pattern
#      0x0508-0x0520 - cursor palette
#      see defines for the rest
# 0x40000000 - G364 fb

.equ G364_FB_HI,       0xE080 # will map to 0x4000
.equ G364_CTRL_HI,     0xE028 # will map to 0x6008
.equ G364_RESET_HI,    0x6018
.equ G364_BOOT,        0x0
.equ G364_HALF_SYNC,   0x108
.equ G364_BACK_PORCH,  0x110
.equ G364_DISPLAY,     0x118
.equ G364_SHORT_DISP,  0x120
.equ G364_BROAD_PULSE, 0x128
.equ G364_VSYNC,       0x130
.equ G364_PRE_EQ,      0x138
.equ G364_POST_EQ,     0x140
.equ G364_VBLANK,      0x148
.equ G364_VDISPLAY,    0x150
.equ G364_LINE_TIME,   0x158
.equ G364_LINE_START,  0x160
.equ G364_MEM_INIT,    0x168
.equ G364_TSFR_DELAY,  0x170
.equ G364_VRAM_MASK,   0x200
.equ G364_CTLA,        0x300
.equ G364_TOP,         0x400
.equ G364_PAL,         0x800

# the G364 sequence is identical to one in NTPROM.RAW
# The resolution is 1280x400x8bit

g364_init:
    # dunno, status check?
    lui $a0, G364_RESET_HI
    lw  $t0, 0x2000($a0)

    # reset
    lui $a0, G364_RESET_HI
    sw  $zero, 0($a0)

    # load G364 control register address
    lui $a0, G364_CTRL_HI

    # boot timing
    li  $t0, 0x76
    sw  $t0, G364_BOOT($a0)

    # set flags (defines copied from linux kernel)
    # VRAM_ADR_INC - bits 13 and 12 of Control A
    # PIX_PIPE_DEL - bits 17 and 16 of Control A
    # DELAY_SAMPLE
    lui $t0, 0x00B0
    ori $t0, 0x3000
    sw  $t0, G364_CTLA($a0)

    # line timing: half sync
    li  $t0, 0x17
    sw  $t0, G364_HALF_SYNC($a0)

    # line timing: back porch
    li  $t0, 0x38
    sw  $t0, G364_BACK_PORCH($a0)

    # width (1280px)
    li  $t0, 320
    sw  $t0, G364_DISPLAY($a0)

    # line timing: line time
    li  $t0, 0x1B2
    sw  $t0, G364_LINE_TIME($a0)

    # line timing: short display
    li  $t0, 0x68
    sw  $t0, G364_SHORT_DISP($a0)

    # frame timing: broad puls
    li  $t0, 0xCE
    sw  $t0, G364_BROAD_PULSE($a0)

    # frame timing: v sync
    li  $t0, 6
    sw  $t0, G364_VSYNC($a0)

    # frame timing: v preequalise
    li  $t0, 2
    sw  $t0, G364_PRE_EQ($a0)

    # frame timing: v postequalise
    li  $t0, 2
    sw  $t0, G364_POST_EQ($a0)

    # frame timing: v blank
    li  $t0, 0x3E
    sw  $t0, G364_VBLANK($a0)

    # height (400px)
    li  $t0, 0x800
    sw  $t0, G364_VDISPLAY($a0)

    # frame store: line start
    sw  $zero, G364_LINE_START($a0)

    # vram cycle: transfer delay
    li  $t0, 0x2E
    sw  $t0, G364_TSFR_DELAY($a0)

    # vram cycle: mem init
    li  $t0, 0x3D2
    sw  $t0, G364_MEM_INIT($a0)

    # vram cycle: mask register
    lui $t0, 0xFF
    ori $t0, 0xFFFF
    sw  $t0, G364_VRAM_MASK($a0)

    # palette, 16 colors
    sw  $zero, 0x800($a0)
    lui $t0, 0xB0
    ori $t0, $t0, 0x0000
    sw  $t0, 0x808($a0)
    li  $t0, 0xB000
    sw  $t0, 0x810($a0)
    lui $t0, 0xB0
    ori $t0, 0xB000
    sw  $t0, 0x818($a0)
    li  $t0, 0xB0
    sw  $t0, 0x820($a0)
    lui $t0, 0xB0
    ori $t0, 0x00B0
    sw  $t0, 0x828($a0)
    li  $t0, 0xB0B0
    sw  $t0, 0x830($a0)
    lui $t0, 0xB0
    ori $t0, 0xB0B0
    sw  $t0, 0x838($a0)
    sw  $zero, 0x840($a0)
    lui $t0, 0xFF
    ori $t0, 0x0000
    sw  $t0, 0x848($a0)
    li  $t0, 0xFF00
    sw  $t0, 0x850($a0)
    lui $t0, 0xFF
    ori $t0, 0xFF00
    sw  $t0, 0x858($a0)
    li  $t0, 0x00FF
    sw  $t0, 0x860($a0)
    lui $t0, 0xFF
    ori $t0, 0x00FF
    sw  $t0, 0x868($a0)
    li  $t0, 0xFFFF
    sw  $t0, 0x870($a0)
    lui $t0, 0xFF
    ori $t0, 0xFFFF
    sw  $t0, 0x878($a0)

    #  set same flags + ENABLE_VTG
    lui $t0, 0xB0
    ori $t0, 0x3001
    sw  $t0, G364_CTLA($a0)

    # top of the screen
    sw  $zero, G364_TOP($a0)

    # print welcome message
    la   $a0, txt_bios
    move $a1, $zero
    move $a2, $zero
    jal  puts
    nop

# RC4030 chipset  controls the DMA and IRQs, 
# the values and sequence are taken from the original BIOS
# you can see what each register means in qemu/hw/dma/rc4030.c

.equ RC4030_BASE_HI, 0xE000 # will map to 0x8000

rc4030_init:
    lui $a0, RC4030_BASE_HI

    # global config register, 0x0 = 0x1552
    li $t0, 0x1552
    sw $t0, 0x0($a0)

    # DMA transl. table base, 0x18 = ...
    la $t0, dma_transl_table
    sw $t0, 0x18($a0)

    # DMA transl. table limit, 0x20 = 0x1000
    li $t0, 0x1000
    sw $t0, 0x20($a0)

    # DMA transl. table invalidated, 0x28 = 0x1
    li $t0, 0x1
    sw $t0, 0x28($a0)

    # cache maintenance, 0x30 = 0x1F
    li $t0, 0x1F
    sw $t0, 0x30($a0)

    # I/O cache physical tag, 0x48 = 0x1
    li $t0, 0x1
    sw $t0, 0x48($a0)

     # I/O cache logical tag, 0x50 = 0x80000001
    lui $t0, 0x8000
    ori $t0, 0x1
    sw $t0, 0x50($a0)

    # I/O cache byte mask, 0x58 = 0xF0F0F0F
    lui $t0, 0xF0F
    ori $t0, 0xF0F
    sw $t0, 0x58($a0)

    # I/O cache buffer window, 0x60 = 0xA
    li $t0, 0xA
    sw $t0, 0x60($a0)

    # remote speed reg, 0x78 = 0x0
    sw $zero, 0x78($a0)

    # remote speed reg, 0x80 = 0x1
    li $t0, 0x1
    sw $t0, 0x80($a0)

    # remote speed reg, 0x88 = 0x2
    li $t0, 0x2
    sw $t0, 0x88($a0)

    # remote speed reg, 0x90 = 0x7
    li $t0, 0x7
    sw $t0, 0x90($a0)

    # remote speed reg, 0x98 = 0x3
    li $t0, 0x3
    sw $t0, 0x98($a0)

    # remote speed reg, 0xA0 = 0x2
    li $t0, 0x2
    sw $t0, 0xA0($a0)

    # remote speed reg, 0xA8 = 0x2
    li $t0, 0x2
    sw $t0, 0xA8($a0)

    # remote speed reg, 0xB0 = 0x2
    li $t0, 0x2
    sw $t0, 0xB0($a0)

    # remote speed reg, 0xB8 = 0x4
    li $t0, 0x4
    sw $t0, 0xB8($a0)

    # remote speed reg, 0xC0 = 0x1
    li $t0, 0x1
    sw $t0, 0xC0($a0)

    # remote speed reg, 0xC8 = 0x2
    li $t0, 0x2
    sw $t0, 0xC8($a0)

    # remote speed reg, 0xD0 = 0x1
    li $t0, 0x1
    sw $t0, 0xD0($a0)

    # remote speed reg, 0xD8 = 0x7
    li $t0, 0x7
    sw $t0, 0xD8($a0)

    # remote speed reg, 0xE0 = 0x1
    li $t0, 0x1
    sw $t0, 0xE0($a0)

    # remote speed reg, 0xE8 = 0x3F
    li $t0, 0x3F
    sw $t0, 0xE8($a0)

    # DMA, 0x100 = 0x11
    li $t0, 0x11
    sw $t0, 0x100($a0)

    # DMA, 0x108 = 0x1
    li $t0, 0x1
    sw $t0, 0x108($a0)

    # DMA, 0x110 = 0x24
    li $t0, 0x24
    sw $t0, 0x110($a0)

    # DMA, 0x118 = 0xF10
    li $t0, 0xF10
    sw $t0, 0x118($a0)

    # DMA, 0x120 = 0xA
    li $t0, 0xA
    sw $t0, 0x120($a0)

    # DMA, 0x128 = 0x0
    sw $zero, 0x128($a0)

    # DMA, 0x130 = 0x0
    sw $zero, 0x130($a0)

    # DMA, 0x138 = 0x0
    sw $zero, 0x138($a0)

    # DMA, 0x140 = 0x0
    sw $zero, 0x140($a0)

    # DMA, 0x148 = 0x0
    sw $zero, 0x148($a0)

    # DMA, 0x150 = 0x0
    sw $zero, 0x150($a0)

    # DMA, 0x158 = 0x0
    sw $zero, 0x158($a0)

    # DMA, 0x160 = 0x0
    sw $zero, 0x160($a0)

    # DMA, 0x168 = 0x0
    sw $zero, 0x168($a0)

    # DMA, 0x170 = 0x0
    sw $zero, 0x170($a0)

    # DMA, 0x178 = 0x0
    sw $zero, 0x178($a0)

    # DMA, 0x180 = 0x0
    sw $zero, 0x180($a0)

    # DMA, 0x188 = 0x0
    sw $zero, 0x188($a0)

    # DMA, 0x190 = 0x0
    sw $zero, 0x190($a0)

    # DMA, 0x198 = 0x0
    sw $zero, 0x198($a0)

    # DMA, 0x1A0 = 0x0
    sw $zero, 0x1A0($a0)

    # DMA, 0x1A8 = 0x0
    sw $zero, 0x1A8($a0)

    # DMA, 0x1B0 = 0x0
    sw $zero, 0x1B0($a0)

    # DMA, 0x1B8 = 0x0
    sw $zero, 0x1B8($a0)

    # DMA, 0x1C0 = 0x0
    sw $zero, 0x1C0($a0)

    # DMA, 0x1C8 = 0x0
    sw $zero, 0x1C8($a0)

    # DMA, 0x1D0 = 0x0
    sw $zero, 0x1D0($a0)

    # DMA, 0x1D8 = 0x0
    sw $zero, 0x1D8($a0)

    # DMA, 0x1E0 = 0x0
    sw $zero, 0x1E0($a0)

    # DMA, 0x1E8 = 0x0
    sw $zero, 0x1E8($a0)

    # DMA, 0x1F0 = 0x0
    sw $zero, 0x1F0($a0)

    # DMA, 0x1F8 = 0x0
    sw $zero, 0x1F8($a0)

    # memory refresh rate, 0x210 = 0x180FA
    lui $t0, 0x1
    ori $t0, 0x80FA
    sw $t0, 0x210($a0)

    # interval timer reload, 0x228 = 0x0
    sw $zero, 0x228($a0)

    b kbd_init
    nop

dma_transl_table: .zero 0x1000

# i8042 standard PS/2 keyboard initialization
# QEMU version here, google for proper initialization on real hw

.equ KBD_BASE,   0xE0005001 # will map to 0x80005001
.equ KBD_DATA,   0x60 # r/w
.equ KBD_STATUS, 0x64 # r
.equ KBD_CMD,    0x64 # w

kbd_init:
    la   $a0, KBD_BASE
    li   $t0, 0xAE # cmd: enable first PS/2 port
    sb   $t0, KBD_CMD($a0)
.kbd_flush:
    lb   $t0, KBD_STATUS($a0)
    andi $t0, $t0, 1 # input buffer empty/full flag
    beqz $t0, .kbd_init_end
    nop # branch delay slot
    lb   $t0, KBD_DATA($a0)
    b .kbd_flush
    nop # branch delay slot
.kbd_init_end:

# check if memory where we want to put bootsector is writable
mem_check:
    la   $a0, BOOTSTRAP_ADDR
    li   $t0, 0xC0DEBABE
    sw   $t0, 0($a0)
    lw   $t1, 0($a0)
    beq  $t0, $t1, .mem_check_end
    nop
    la   $a0, txt_mem_fail
    move $a1, $zero
    li   $a2, 1
    jal  puts
    nop
    b .  # memory write failed, halt
    nop
.mem_check_end:

# load 1st sector from floppy
# this will work ONLY in QEMU
.equ FDD_BASE, 0xE0003000 # will map to 0x80003000
.equ FDD_DOR,  2
.equ FDD_MSR,  4
.equ FDD_FIFO, 5
.equ FDD_CCR,  7

.equ FDD_CMD_SPECIFY,   3
.equ FDD_CMD_READ,      6
.equ FDD_CMD_RECALIB,   7
.equ FDD_CMD_SENSE_INT, 8
.equ FDD_CMD_SEEK,      15

# uses t0
.macro fdd_wait base, flag
1001:
    lb   $t0, FDD_MSR(\base)
    andi $t0, \flag
    beqz $t0, 1001b
    nop
.endm
.macro fdd_send_cmd base, cmd
    fdd_wait \base, 0x80
    li  $t0, \cmd
    sb  $t0, FDD_FIFO(\base)
.endm
.macro fdd_read_data base
    fdd_wait \base, 0xD0
    lb       $v0, FDD_FIFO(\base)
.endm
.macro fdd_wait_int base
    fdd_send_cmd  \base, FDD_CMD_SENSE_INT
    fdd_read_data \base
    fdd_read_data \base
.endm
fdd_read_bootsector:
    # put info for user to insert the floppy
    # and wait for him to press the key
    la   $a0, txt_welcome
    move $a1, $zero
    li   $a2, 1
    jal  puts
    nop
    jal  getc
    nop

    # enter, then exit reset mode
    la   $a0, FDD_BASE
    sb   $zero, FDD_DOR($a0)
    li   $t0, 0x04
    sb   $t0, FDD_DOR($a0)
    fdd_wait_int $a0

    # outb(CCR, 0x00) - 500Kbps for 1.44
    sb   $zero, FDD_CCR($a0)

    # configure the drive
    fdd_send_cmd $a0, FDD_CMD_SPECIFY
    fdd_send_cmd $a0, 0xDF
    fdd_send_cmd $a0, 0x03

    # floppy motor on
    li $t0, 0x14
    sb $t0, FDD_DOR($a0)

    # calibrate
    fdd_send_cmd $a0, FDD_CMD_RECALIB
    fdd_send_cmd $a0, 0 # drive
    fdd_wait_int $a0

    # seek
    fdd_send_cmd $a0, FDD_CMD_SEEK
    fdd_send_cmd $a0, 0 # head
    fdd_send_cmd $a0, 1 # cylinder
    fdd_wait_int $a0

    # read command
    fdd_send_cmd $a0, FDD_CMD_READ
    fdd_send_cmd $a0, 0 # index | head
    fdd_send_cmd $a0, 0 # cylinder
    fdd_send_cmd $a0, 0 # head
    fdd_send_cmd $a0, 1 # sector
    fdd_send_cmd $a0, 2 # bytes per sector (128*2^2 = 512)
    fdd_send_cmd $a0, 1 # last sector 1
    fdd_send_cmd $a0, 0x1B # GAP3 length
    fdd_send_cmd $a0, 0xFF # data length (?)

    # read the whole sector to bootstrap address
    la   $a1, BOOTSTRAP_ADDR
    move $t2, $zero
.fdd_read_byte:
    fdd_read_data $a0
    sb   $v0, 0($a1)
    addi $t2, $t2, 1
    addi $a1, $a1, 1
    bne  $t2, 512, .fdd_read_byte
    nop

    # motor off
    li   $t0, 0
    sb   $t0, FDD_DOR($a0)

boot:
    jal  cls
    nop
    la   $a0, BOOTSTRAP_ADDR
    jr   $a0
    nop

# Prints text to screen, arguments (none is preserved):
# $a0 - str
# $a1 - x
# $a2 - y
#
# uses:
# $s0 - fb ptr
# $s1 - stride
# $s2 - font ptr
# $t0 - color index value (tmp)
# $t1 - char
# $t2 - pixel column (each char has 8 columns)
font: .include "font8x16.inc"
puts:
    # verify parameters
    bltz $a1, .puts_end
    nop # branch delay slot
    bltz $a2, .puts_end
    nop # branch delay slot
    bge  $a1, 1280, .puts_end
    nop # branch delay slot
    bge  $a2, 400, .puts_end
    nop # branch delay slot

    # stride = y * 1280
    move $s1, $a2
    sll  $a2, $a2, 14
    sll  $s1, $s1, 12   
    or   $s1, $s1, $a2

    # compute fb offset += stride + x * 8
    sll   $a1, $a1, 3
    lui   $s0, G364_FB_HI
    add   $s0, $s0, $s1
    add   $s0, $s0, $a1

.putc: 
    lb    $t1, 0($a0)        # char = *str
    beqz  $t1, .puts_end     # char == 0 -> finish
    nop # branch delay slot

    sll   $t1, $t1, 3        # char is 8px wide 
    move  $t2, $zero         # pixel column (0-7)
    la    $s2, font
    add   $s2, $s2, $t1      # offset in font table
.putc_pix_col:                # why lb/sb, not lw/sw? to avoid unaligned access exception
    lb    $t0,  0 * 2048($s2) # index = font[row * 2048 + char]
    sb    $t0,  0 * 1280($s0) # *(fb + row * stride) = index
    lb    $t0,  1 * 2048($s2)
    sb    $t0,  1 * 1280($s0)
    lb    $t0,  2 * 2048($s2)
    sb    $t0,  2 * 1280($s0)
    lb    $t0,  3 * 2048($s2)
    sb    $t0,  3 * 1280($s0)
    lb    $t0,  4 * 2048($s2)
    sb    $t0,  4 * 1280($s0)
    lb    $t0,  5 * 2048($s2)
    sb    $t0,  5 * 1280($s0)
    lb    $t0,  6 * 2048($s2)
    sb    $t0,  6 * 1280($s0)
    lb    $t0,  7 * 2048($s2)
    sb    $t0,  7 * 1280($s0)
    lb    $t0,  8 * 2048($s2)
    sb    $t0,  8 * 1280($s0)
    lb    $t0,  9 * 2048($s2)
    sb    $t0,  9 * 1280($s0)
    lb    $t0, 10 * 2048($s2)
    sb    $t0, 10 * 1280($s0)
    lb    $t0, 11 * 2048($s2)
    sb    $t0, 11 * 1280($s0)
    lb    $t0, 12 * 2048($s2)
    sb    $t0, 12 * 1280($s0)
    lb    $t0, 13 * 2048($s2)
    sb    $t0, 13 * 1280($s0)
    lb    $t0, 14 * 2048($s2)
    sb    $t0, 14 * 1280($s0)
    lb    $t0, 15 * 2048($s2)
    sb    $t0, 15 * 1280($s0)
    addiu $t2, $t2, 1        # pixel column++
    addiu $s0, $s0, 1        # fb++
    addiu $s2, $s2, 1        # font++
    bne   $t2, 8, .putc_pix_col
    nop # branch delay slot

    addiu $a0, $a0, 1       # next char
    b     .putc
    nop # branch delay slot

.puts_end:
    jr    $ra
    nop # branch delay slot

# Clear the screen
cls:
    lui   $a0, G364_FB_HI
    move  $t1, $zero
    li    $t2, 1280
    li    $t3, 400
.clear_row:
    move  $t0, $zero
.clear_cols:
    sb    $zero, 0($a0)
    addiu $t0, $t0, 1
    bne   $t0, $t2, .clear_cols
    addiu $a0, $a0, 1 # branch delay slot
    addiu $t1, $t1, 1
    bne   $t1, $t3, .clear_row
    nop # branch delay slot
    jr    $ra
    nop

# Waits for pressing any key, returns:
# $v0 - pressed key code
#
# uses:
# $a0 - base address
getc:
    la    $a0, KBD_BASE
.wait.data:
    lb    $v0, KBD_STATUS($a0)
    andi  $v0, $v0, 1
    beqz  $v0, .wait.data
    nop # branch delay slot
    lb    $v0, KBD_DATA($a0)
    jr    $ra
    nop # branch delay slot

txt_bios: .asciiz "openbios-jazz"
txt_welcome: .asciiz "Press any key to boot from floppy ..."
txt_mem_fail: .asciiz "Destination address is not writable"

