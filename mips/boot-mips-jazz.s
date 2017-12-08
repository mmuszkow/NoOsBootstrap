.set noreorder
.set nomips16

.global __start

.section .text

__start:
    b .

# align to 512 bytes
. = __start + 511
.byte 0

