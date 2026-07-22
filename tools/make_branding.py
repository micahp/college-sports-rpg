#!/usr/bin/env python3
"""Generate North Valley State branding textures (CC0-safe, fully procedural).

Outputs to assets/branding/ and assets/ground/. Rerun any time; deterministic.
Palette: navy #1F335C, gold #EBB84D (docs/ART_PIPELINE.md).
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

NAVY = (31, 51, 92)
NAVY_DARK = (22, 36, 66)
GOLD = (235, 184, 77)
GOLD_DARK = (196, 148, 52)
CREAM = (246, 240, 226)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BRAND = os.path.join(ROOT, "assets", "branding")
GROUND = os.path.join(ROOT, "assets", "ground")
FONT = "/usr/share/fonts/opentype/urw-base35/NimbusSans-Bold.otf"

os.makedirs(BRAND, exist_ok=True)
os.makedirs(GROUND, exist_ok=True)


def font(size):
    return ImageFont.truetype(FONT, size)


def center_text(draw, xy, text, size, fill, tracking=0):
    f = font(size)
    if tracking:
        widths = [draw.textlength(ch, font=f) + tracking for ch in text]
        total = sum(widths) - tracking
        x = xy[0] - total / 2
        for ch, w in zip(text, widths):
            draw.text((x, xy[1]), ch, font=f, fill=fill, anchor="lm")
            x += w
    else:
        draw.text(xy, text, font=f, fill=fill, anchor="mm")


# --- Ridgehawk emblem: gold hawk head in a navy roundel -------------------------

def draw_hawk(d, scale, ox, oy):
    """Constructive hawk-head mark: gold shapes carved by navy overlays."""
    def pt(x, y):
        return (ox + x * scale, oy + y * scale)

    def circle(cx, cy, r, color):
        d.ellipse([pt(cx - r, cy - r), pt(cx + r, cy + r)], fill=color)

    # Head and neck in gold
    circle(0.42, 0.40, 0.28, GOLD)
    d.polygon([pt(0.16, 0.48), pt(0.54, 0.56), pt(0.50, 0.88), pt(0.14, 0.88)], fill=GOLD)
    # Beak: sharp triangle, hook carved by a navy circle under the tip
    d.polygon([pt(0.58, 0.20), pt(1.00, 0.42), pt(0.58, 0.60)], fill=GOLD)
    circle(0.82, 0.66, 0.20, NAVY)
    # Feather notches at the neck's bottom edge
    d.polygon([pt(0.10, 0.90), pt(0.22, 0.70), pt(0.30, 0.90)], fill=NAVY)
    d.polygon([pt(0.30, 0.90), pt(0.40, 0.72), pt(0.52, 0.90)], fill=NAVY)
    # Brow + eye
    d.polygon([pt(0.26, 0.28), pt(0.60, 0.24), pt(0.60, 0.34)], fill=NAVY)
    d.polygon([pt(0.34, 0.36), pt(0.52, 0.33), pt(0.46, 0.47)], fill=NAVY)


def draw_emblem(size=512, ring_text=True):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = size / 2
    d.ellipse([8, 8, size - 8, size - 8], fill=NAVY, outline=GOLD, width=int(size * 0.035))
    inner = size * 0.115
    d.ellipse([inner, inner, size - inner, size - inner], outline=GOLD, width=int(size * 0.012))
    draw_hawk(d, size * 0.52, size * 0.245, size * 0.22)
    if ring_text:
        f = font(int(size * 0.072))
        for i, ch in enumerate("RIDGEHAWKS"):
            ang = math.radians(-152 + i * 12.5)
            r = size * 0.415
            x, y = c + r * math.cos(ang), c + r * math.sin(ang)
            ch_img = Image.new("RGBA", (60, 60), (0, 0, 0, 0))
            ImageDraw.Draw(ch_img).text((30, 30), ch, font=f, fill=GOLD, anchor="mm")
            ch_img = ch_img.rotate(-math.degrees(ang) - 90, resample=Image.BICUBIC)
            img.alpha_composite(ch_img, (int(x) - 30, int(y) - 30))
        center_text(d, (c, size * 0.80), "EST. 1962", int(size * 0.055), GOLD)
    return img


draw_emblem().save(os.path.join(BRAND, "emblem.png"))

# Plain emblem (no ring text) for small uses
draw_emblem(ring_text=False).save(os.path.join(BRAND, "emblem_plain.png"))


# --- Street-pole banner ---------------------------------------------------------

def pole_banner(path, top, bottom, accent_gold=False):
    w, h = 256, 512
    bg, fg = (GOLD, NAVY) if accent_gold else (NAVY, GOLD)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Banner shape with a chevron cut at the bottom
    d.polygon([(6, 0), (w - 6, 0), (w - 6, h - 60), (w // 2, h - 8), (6, h - 60)], fill=bg)
    d.polygon([(6, 0), (w - 6, 0), (w - 6, h - 60), (w // 2, h - 8), (6, h - 60)],
              outline=fg, width=6)
    emblem = draw_emblem(160, ring_text=False)
    img.alpha_composite(emblem, (w // 2 - 80, 54))
    center_text(d, (w // 2, 268), top, 44, fg, tracking=2)
    center_text(d, (w // 2, 320), bottom, 22, fg if accent_gold else CREAM, tracking=1)
    d.rectangle([28, 356, w - 28, 362], fill=fg)
    img.save(os.path.join(BRAND, path))


pole_banner("banner_theu.png", "THE U", "NORTH VALLEY STATE")
pole_banner("banner_hawks.png", "GO", "RIDGEHAWKS", accent_gold=True)


# --- Rec Center facade banner ---------------------------------------------------

w, h = 256, 640
img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
d.rectangle([0, 0, w, h], fill=NAVY_DARK)
d.rectangle([10, 10, w - 10, h - 10], outline=GOLD, width=5)
emblem = draw_emblem(170, ring_text=False)
img.alpha_composite(emblem, (w // 2 - 85, 36))
for i, word in enumerate(["REC", "CENTER"]):
    center_text(d, (w // 2, 264 + i * 58), word, 46, GOLD, tracking=2)
d.rectangle([36, 386, w - 36, 392], fill=GOLD)
center_text(d, (w // 2, 430), "HOME OF", 24, CREAM, tracking=2)
center_text(d, (w // 2, 470), "RIDGEHAWK", 30, CREAM, tracking=1)
center_text(d, (w // 2, 508), "BASKETBALL", 30, CREAM, tracking=1)
img.save(os.path.join(BRAND, "banner_rec.png"))


# --- Walk-on tryouts poster -----------------------------------------------------

w, h = 512, 680
img = Image.new("RGBA", (w, h), CREAM + (255,))
d = ImageDraw.Draw(img)
d.rectangle([0, 0, w, 150], fill=NAVY)
center_text(d, (w // 2, 52), "WALK-ON", 62, GOLD, tracking=4)
center_text(d, (w // 2, 116), "TRYOUTS", 62, GOLD, tracking=4)
# Basketball
bx, by, br = w // 2, 330, 120
d.ellipse([bx - br, by - br, bx + br, by + br], fill=(214, 118, 54), outline=NAVY, width=8)
d.line([bx - br, by, bx + br, by], fill=NAVY, width=7)
d.line([bx, by - br, bx, by + br], fill=NAVY, width=7)
d.arc([bx - br * 1.9, by - br, bx - br * 0.25, by + br], -62, 62, fill=NAVY, width=7)
d.arc([bx + br * 0.25, by - br, bx + br * 1.9, by + br], 118, 242, fill=NAVY, width=7)
d.rectangle([0, 470, w, 680], fill=NAVY)
center_text(d, (w // 2, 510), "SATURDAY · 9 AM", 44, CREAM, tracking=2)
center_text(d, (w // 2, 566), "REC CENTER COURT 1", 36, GOLD, tracking=2)
center_text(d, (w // 2, 626), "ALL STUDENTS WELCOME", 28, CREAM, tracking=2)
img.save(os.path.join(BRAND, "poster_walkon.png"))


# --- Campus map poster ----------------------------------------------------------

w, h = 512, 680
img = Image.new("RGBA", (w, h), (226, 232, 238, 255))
d = ImageDraw.Draw(img)
d.rectangle([0, 0, w, 96], fill=NAVY)
center_text(d, (w // 2, 48), "CAMPUS MAP", 46, GOLD, tracking=4)
# Paths
d.rectangle([236, 96, 276, 620], fill=(200, 204, 208))
d.rectangle([60, 380, 452, 420], fill=(200, 204, 208))
blocks = [
    ("REC CENTER", 130, 130, 382, 260, NAVY),
    ("LIBRARY", 60, 300, 210, 370, (108, 122, 148)),
    ("DORMS", 302, 300, 452, 370, (108, 122, 148)),
    ("DINING", 60, 440, 210, 520, (108, 122, 148)),
    ("QUAD", 302, 440, 452, 520, (126, 152, 116)),
]
for name, x0, y0, x1, y1, color in blocks:
    d.rounded_rectangle([x0, y0, x1, y1], radius=10, fill=color)
    center_text(d, ((x0 + x1) / 2, (y0 + y1) / 2), name, 26, CREAM, tracking=1)
# You are here
d.ellipse([238, 546, 274, 582], fill=(196, 60, 48), outline=CREAM, width=4)
center_text(d, (256, 616), "YOU ARE HERE", 26, NAVY, tracking=1)
img.save(os.path.join(BRAND, "poster_map.png"))


# --- Club table banner ----------------------------------------------------------

w, h = 512, 256
img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
d.rectangle([0, 0, w, h], fill=GOLD)
d.rectangle([8, 8, w - 8, h - 8], outline=NAVY, width=6)
center_text(d, (w // 2, 62), "RIDGEHAWK", 54, NAVY, tracking=2)
center_text(d, (w // 2, 126), "CLUB SPORTS", 54, NAVY, tracking=2)
center_text(d, (w // 2, 196), "SIGN UP TODAY", 34, NAVY_DARK, tracking=3)
img.save(os.path.join(BRAND, "banner_club.png"))


# --- Plaza ground emblem decal --------------------------------------------------

decal = draw_emblem(512, ring_text=False).convert("RGBA")
# Wear it down: lower alpha with soft noise
rnd = random.Random(11)
px = decal.load()
for y in range(512):
    for x in range(512):
        r, g, b, a = px[x, y]
        if a:
            px[x, y] = (r, g, b, int(a * 0.82))
decal = decal.filter(ImageFilter.GaussianBlur(0.6))
decal.save(os.path.join(BRAND, "decal_emblem.png"))


# --- Soft tileable grass texture ------------------------------------------------

size = 512
rnd = random.Random(7)
base = (98, 118, 74)
img = Image.new("RGB", (size, size), base)
px = img.load()
# Low-frequency blotches via layered value noise (tileable through wraparound)
import colorsys

cells = 8
grid = [[rnd.uniform(-1, 1) for _ in range(cells)] for _ in range(cells)]
grid2 = [[rnd.uniform(-1, 1) for _ in range(cells * 4)] for _ in range(cells * 4)]


def sample(grid, n, fx, fy):
    x0, y0 = int(fx * n) % n, int(fy * n) % n
    x1, y1 = (x0 + 1) % n, (y0 + 1) % n
    tx, ty = (fx * n) % 1.0, (fy * n) % 1.0
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
    a = grid[y0][x0] * (1 - tx) + grid[y0][x1] * tx
    b = grid[y1][x0] * (1 - tx) + grid[y1][x1] * tx
    return a * (1 - ty) + b * ty


for y in range(size):
    for x in range(size):
        n = sample(grid, cells, x / size, y / size) * 0.7
        n += sample(grid2, cells * 4, x / size, y / size) * 0.3
        v = 1.0 + n * 0.075
        h, s, val = colorsys.rgb_to_hsv(base[0] / 255, base[1] / 255, base[2] / 255)
        s = max(0.0, s * (1.0 + n * 0.10))
        r, g, b = colorsys.hsv_to_rgb(h + n * 0.008, s, min(1.0, val * v))
        px[x, y] = (int(r * 255), int(g * 255), int(b * 255))
img.save(os.path.join(GROUND, "T_Grass_Soft.png"))

print("branding written to", BRAND)
