#!/usr/bin/python3.6
##!/bin/env python

from PIL import Image, ImageDraw, ImageFont

W = 8
H = 16

img = Image.open('ibm_font.png')
pix = img.load()
COLOR_INDEX = 15


for row in range(H): 
    for c in range(256):
        #if row == 0 or row == 15: b = [15] * 8
        #else: b = [15,0,0,0,0,0,0,15]
        b = [0] * W
        for bit in range(0, W):
            off_x = (c * W + bit) % img.size[0]
            off_y = int((c * W + bit) / img.size[0]) * H + row
            if pix[off_x, off_y] != 0: b[bit] = COLOR_INDEX

        # format print arguments
        b.extend([x/COLOR_INDEX for x in b])
        if c < 127 and chr(c).isprintable():
            b.append('' + chr(c))
        else:
            b.append('\\%Xh' % c)
        print('.byte 0x%.2X, 0x%.2X, 0x%.2X, 0x%.2X, 0x%.2X, 0x%.2X, 0x%.2X, 0x%.2X # %d%d%d%d%d%d%d%d %s' % tuple(b))

