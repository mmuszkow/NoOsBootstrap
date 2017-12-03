#!/bin/env python

w = 640
h = 480
x = 275 # 307 # sign is 25x40 pixels
y = 220
bpp = 16

# NO OS bitmap
# x---x--xxx-----xxx---xxxx
# xx--x-x---x---x---x-x----
# x-x-x-x---x---x---x--xxx-
# x--xx-x---x---x---x-----x
# x---x--xxx-----xxx--xxxx-
bmp = [ [0b10001001, 0b11000001, 0b11000111, 0b10000000],
        [0b11001010, 0b00100010, 0b00101000, 0b00000000],
        [0b10101010, 0b00100010, 0b00100111, 0b00000000],
        [0b10011010, 0b00100010, 0b00100000, 0b10000000],
        [0b10001001, 0b11000001, 0b11001111, 0b00000000] ]

print('ldr r2, =#%d' % (y * w * (bpp/8) + (x*(bpp/8))))
print('add fb, r2')
for row in range(0, len(bmp)):
    for i in range(0, 8):
        for col in range(0, len(bmp[row])):
            b = bmp[row][col]
            for bit in range(7, -1, -1):
                if b & (1<<bit) != 0:
                    print('str white, [fb, #%d]' % (col*8*8 + (7-bit)*8))
                    if bpp == 16:
                        print('str white, [fb, #%d]' % ((col*8*8 + (7-bit)*8 + 4)))
        print('add fb, #%d' % (w * (bpp/8))) # next row

