#!/usr/bin/env python3
"""Generate interior surface textures (CC0-safe, fully procedural).

Outputs to assets/interiors/. Deterministic; rerun any time.
  wood_court.png  - maple hardwood planks for the Rec Center court
  wood_dorm.png   - warmer oak planks for Room 214
  carpet.png      - low-pile navy-gray carpet for the lecture room
"""
import os
import random

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "interiors")
os.makedirs(OUT, exist_ok=True)


def planks(name, base, spread, seed, plank_w=64, size=512):
    rnd = random.Random(seed)
    img = Image.new("RGB", (size, size), base)
    d = ImageDraw.Draw(img)
    for x0 in range(0, size, plank_w):
        y = -rnd.randint(0, 300)
        while y < size:
            length = rnd.randint(180, 340)
            tone = rnd.uniform(-spread, spread)
            col = tuple(max(0, min(255, int(c + tone))) for c in base)
            d.rectangle([x0, y, x0 + plank_w - 1, y + length], fill=col)
            # grain streaks
            for _ in range(10):
                gx = x0 + rnd.randint(3, plank_w - 4)
                g = tuple(max(0, min(255, int(c - rnd.uniform(4, 14)))) for c in col)
                d.line([gx, y, gx + rnd.randint(-3, 3), y + length], fill=g, width=1)
            # seam at plank end
            d.line([x0, y, x0 + plank_w, y], fill=tuple(int(c * 0.72) for c in base), width=2)
            y += length
        d.line([x0, 0, x0, size], fill=tuple(int(c * 0.7) for c in base), width=2)
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    img.save(os.path.join(OUT, name))


def carpet(name, base, seed, size=256):
    rnd = random.Random(seed)
    img = Image.new("RGB", (size, size), base)
    px = img.load()
    for x in range(size):
        for y in range(size):
            n = rnd.uniform(-10, 10)
            px[x, y] = tuple(max(0, min(255, int(c + n))) for c in base)
    img = img.filter(ImageFilter.GaussianBlur(0.8))
    img.save(os.path.join(OUT, name))


planks("wood_court.png", (214, 170, 116), 14, 7)
planks("wood_dorm.png", (168, 120, 78), 16, 11, plank_w=80)
carpet("carpet.png", (78, 86, 104), 3)
print("interior textures written to", OUT)
