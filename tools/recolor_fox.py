#!/usr/bin/env python3
"""Recolour the CC0 fox texture to look B (docs/MASCOT.md): soot black fur, bone white chest,
tail tip and inner ears. Writes assets/pets/fox_ink.png from fox_0.png (Godot extracts that from
fox.glb on import). Run: python3 tools/recolor_fox.py"""
import colorsys
import sys
from PIL import Image

SRC, DST = "assets/pets/fox_0.png", "assets/pets/fox_ink.png"
SOOT, DARK, BONE = (34, 29, 31), (12, 10, 11), (228, 219, 200)

im = Image.open(SRC).convert("RGB")
px = im.load()
for y in range(im.height):
    for x in range(im.width):
        r, g, b = px[x, y]
        h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
        if l > 0.75:
            c = BONE                      # white fur stays pale, a touch warm
        elif l < 0.25:
            c = DARK                      # legs, nose, ear backs
        else:
            c = SOOT                      # the orange coat goes soot black
        px[x, y] = c
im.save(DST)
print("wrote", DST, file=sys.stderr)
