#!/usr/bin/env python3
"""
Generates all pixel-art assets for the "Anatomy Pixel Lab" Godot project.

Outputs (PNG, nearest-neighbor friendly, transparent where needed):
  assets/sprites/brain.png        - sagittal brain + brain stem + spinal cord
  assets/sprites/heart.png        - heart silhouette with chamber regions
  assets/sprites/lungs.png        - lungs + trachea region
  assets/sprites/face_base.png    - neutral face base
  assets/sprites/mouth_happy.png / mouth_sad.png / mouth_anger.png / mouth_pain.png / mouth_dizzy.png
  assets/sprites/eyes_neutral.png / eyes_happy.png / eyes_sad.png / eyes_anger.png / eyes_pain.png / eyes_dizzy.png
  assets/sprites/brow_neutral.png / brow_sad.png / brow_anger.png / brow_pain.png / brow_worry.png
  assets/sprites/limbs/*.png      - torso, head, upperarm, forearm, hand, thigh, shin, foot
  assets/ui/swatch.png            - palette color chart for the ColorPicker preview

Run:  python3 tools/generate_assets.py
Requires: Pillow
"""
import os
import random
from PIL import Image, ImageDraw

random.seed(42)
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPR = os.path.join(ROOT, "assets", "sprites")
LIMB = os.path.join(SPR, "limbs")
UI = os.path.join(ROOT, "assets", "ui")
for d in (SPR, LIMB, UI):
    os.makedirs(d, exist_ok=True)

PAL = {
    "pink1": (255, 208, 196), "pink2": (240, 178, 160), "skin": (255, 205, 160),
    "skinD": (224, 168, 122), "skinS": (184, 128, 90),
    "cream": (255, 244, 214),
    "gray1": (235, 235, 240), "gray2": (200, 200, 210), "gray3": (150, 150, 165),
    "ink": (30, 30, 40), "white": (255, 255, 255),
    "red1": (230, 80, 80), "red2": (185, 45, 55), "red3": (135, 25, 40),
    "maroon": (95, 20, 35),
    "blue1": (110, 200, 255), "blue2": (60, 130, 220), "blue3": (30, 70, 150),
    "yellow": (255, 230, 90), "orange": (255, 160, 60),
    "green1": (120, 220, 140), "green2": (60, 160, 90),
    "purple1": (190, 140, 230), "purple2": (120, 80, 170),
    "brown1": (150, 100, 70), "brown2": (100, 65, 45),
}


def new(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def outline(img, col=(30, 30, 40, 255)):
    """Add a 1px dark outline around opaque pixels."""
    px = img.load()
    w, h = img.size
    mask = [(x, y) for y in range(h) for x in range(w) if px[x, y][3] > 0]
    out = img.copy()
    opx = out.load()
    for x, y in mask:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and opx[nx, ny][3] == 0:
                opx[nx, ny] = col
    return out


def save(img, path, do_outline=True):
    if do_outline:
        img = outline(img)
    img.save(path)
    print("wrote", path, img.size)


# ---------------------------------------------------------------- BRAIN ----
def make_brain():
    W, H = 128, 160
    img = new(W, H)
    d = ImageDraw.Draw(img)
    # cerebrum: lumpy blob (dome-ish), front on LEFT
    cx, cy, rx, ry = 62, 58, 46, 38
    steps = 64
    pts = []
    for i in range(steps):
        import math
        a = math.pi * i / (steps - 1)  # top half from pi..0
        bump = 3.2 * math.sin(a * 7)
        pts.append((cx - rx * math.cos(a) + bump * math.cos(a),
                    cy - (ry + bump * 0.4) * math.sin(a)))
    for i in range(steps):
        import math
        a = math.pi * i / (steps - 1)
        bump = 2.4 * math.sin(a * 5 + 1)
        pts.append((cx - rx * 0.92 * math.cos(a) - bump * math.cos(a),
                    cy + (ry * 0.62 + bump * 0.3) * math.sin(a)))
    d.polygon(pts, fill=(*PAL["pink1"], 255))
    # shading bottom
    d.ellipse([cx - rx, cy + 4, cx + rx, cy + ry + 14], fill=None)
    # cerebellum (back-bottom, right side)
    d.ellipse([84, 74, 112, 96], fill=(*PAL["pink2"], 255))
    # brain stem going down
    d.rectangle([58, 84, 70, 104], fill=(*PAL["pink2"], 255))
    # spinal cord
    d.rectangle([60, 100, 68, 156], fill=(*PAL["gray2"], 255))
    # vertebrae segments
    for y in range(102, 154, 8):
        d.rectangle([56, y, 72, y + 5], fill=(*PAL["gray1"], 255))
        d.line([56, y, 72, y], fill=(*PAL["gray3"], 255))
    # gyri squiggles on cerebrum
    def squiggle(x0, y0, segs, col):
        x, y = x0, y0
        for _ in range(segs):
            nx = x + random.randint(-6, 8)
            ny = y + random.randint(-5, 5)
            d.line([(x, y), (nx, ny)], fill=col, width=1)
            x, y = nx, ny
    gyri = (*PAL["pink2"], 255)
    for (sx, sy) in [(30, 40), (44, 30), (60, 26), (76, 34), (90, 50),
                     (34, 58), (52, 52), (70, 50), (86, 66), (44, 68), (64, 68)]:
        squiggle(sx, sy, 3, gyri)
    # cerebellum folia lines
    for yy in range(78, 94, 4):
        d.line([(88, yy), (108, yy)], fill=(*PAL["maroon"][:2] + (120,), 255))
    # nerve roots leaving brain stem to the right
    for (ex, ey, bx, by) in [(70, 88, 100, 110), (70, 96, 108, 126), (68, 104, 104, 142)]:
        d.line([(ex, ey), (bx, by)], fill=(*PAL["yellow"], 255), width=2)
    save(img, os.path.join(SPR, "brain.png"))


# ---------------------------------------------------------------- HEART ----
def make_heart():
    W, H = 128, 128
    img = new(W, H)
    d = ImageDraw.Draw(img)
    # main body: rounded two-lobe top, tapered bottom-left apex
    d.ellipse([20, 30, 76, 86], fill=(*PAL["red1"], 255))
    d.ellipse([56, 26, 112, 82], fill=(*PAL["red1"], 255))
    d.polygon([(22, 70), (108, 66), (72, 118)], fill=(*PAL["red1"], 255))
    d.ellipse([30, 55, 100, 105], fill=(*PAL["red1"], 255))
    # vessels on top
    d.rectangle([40, 8, 54, 40], fill=(*PAL["blue2"], 255))   # vena cava
    d.rectangle([60, 4, 78, 36], fill=(*PAL["red2"], 255))    # aorta
    d.rectangle([82, 10, 94, 38], fill=(*PAL["red2"], 255))   # pulmonary
    # darker chambers hint
    d.ellipse([34, 60, 74, 96], fill=(*PAL["red2"], 255))
    d.ellipse([66, 52, 100, 88], fill=(*PAL["red3"], 255))
    # apex highlight
    d.polygon([(60, 96), (84, 92), (72, 116)], fill=(*PAL["red3"], 255))
    # coronary grooves
    d.line([(40, 58), (66, 70), (96, 60)], fill=(*PAL["maroon"], 255), width=2)
    d.line([(58, 40), (52, 66), (60, 92)], fill=(*PAL["maroon"], 255), width=1)
    d.line([(80, 42), (84, 64), (76, 86)], fill=(*PAL["maroon"], 255), width=1)
    save(img, os.path.join(SPR, "heart.png"))


# ---------------------------------------------------------------- LUNGS ----
def make_lungs():
    W, H = 144, 128
    img = new(W, H)
    d = ImageDraw.Draw(img)
    pink = (*PAL["pink1"], 255)
    pinkD = (*PAL["pink2"], 255)
    # trachea
    d.rectangle([66, 4, 78, 34], fill=pinkD)
    for ty in range(6, 34, 6):
        d.line([(66, ty), (78, ty)], fill=(*PAL["maroon"], 255))
    # bronchi
    d.line([(70, 32), (48, 46)], fill=pinkD, width=6)
    d.line([(74, 32), (96, 46)], fill=pinkD, width=6)
    # left lung (viewer left) - bean shape
    d.ellipse([12, 34, 66, 112], fill=pink)
    d.rectangle([52, 34, 66, 112], fill=(0, 0, 0, 0))  # carve medial edge
    d.ellipse([12, 34, 66, 112], fill=pink)
    # simpler: draw lobes
    d.ellipse([14, 36, 62, 78], fill=pink)
    d.ellipse([16, 60, 60, 112], fill=pink)
    d.line([(20, 66), (56, 60)], fill=(*PAL["maroon"], 255), width=1)  # fissure
    # right lung (bigger, 3 lobes)
    d.ellipse([82, 34, 132, 76], fill=pink)
    d.ellipse([84, 56, 130, 92], fill=pink)
    d.ellipse([84, 74, 128, 114], fill=pink)
    d.line([(88, 62), (126, 58)], fill=(*PAL["maroon"], 255), width=1)
    d.line([(88, 86), (124, 82)], fill=(*PAL["maroon"], 255), width=1)
    # bronchial tree hints
    for (x0, y0) in [(44, 50), (40, 70), (100, 52), (104, 74)]:
        d.line([(x0, y0), (x0 - 8, y0 + 14)], fill=pinkD)
        d.line([(x0, y0), (x0 + 8, y0 + 14)], fill=pinkD)
    save(img, os.path.join(SPR, "lungs.png"))


# ---------------------------------------------------------------- FACE -----
FW, FH = 96, 96
FCX, FCY = 48, 50

def face_base():
    img = new(FW, FH)
    d = ImageDraw.Draw(img)
    d.ellipse([12, 10, 84, 88], fill=(*PAL["skin"], 255))
    # hair cap
    d.chord([10, 6, 86, 60], 180, 360, fill=(*PAL["brown1"], 255))
    d.rectangle([10, 28, 86, 36], fill=(0, 0, 0, 0))
    d.chord([10, 8, 86, 58], 180, 360, fill=(*PAL["brown1"], 255))
    # bangs
    for bx in range(16, 80, 10):
        d.polygon([(bx, 34), (bx + 8, 34), (bx + 4, 42)], fill=(*PAL["brown1"], 255))
    # cheeks blush zone marker (faint)
    d.ellipse([20, 56, 32, 64], fill=(255, 150, 150, 60))
    d.ellipse([64, 56, 76, 64], fill=(255, 150, 150, 60))
    # ears
    d.ellipse([6, 44, 16, 60], fill=(*PAL["skin"], 255))
    d.ellipse([80, 44, 90, 60], fill=(*PAL["skin"], 255))
    # nose
    d.polygon([(46, 56), (50, 56), (48, 64)], fill=(*PAL["skinD"], 255))
    save(img, os.path.join(SPR, "face_base.png"))


def _overlay(name, fn):
    img = new(FW, FH)
    d = ImageDraw.Draw(img)
    fn(d)
    save(img, os.path.join(SPR, name + ".png"), do_outline=False)


def eyes_neutral(d):
    d.ellipse([28, 44, 40, 54], fill=(*PAL["white"], 255))
    d.ellipse([56, 44, 68, 54], fill=(*PAL["white"], 255))
    d.ellipse([32, 47, 37, 52], fill=(*PAL["ink"], 255))
    d.ellipse([60, 47, 65, 52], fill=(*PAL["ink"], 255))

def eyes_happy(d):
    for x in (28, 56):
        d.arc([x, 42, x + 12, 56], 200, 340, fill=(*PAL["ink"], 255), width=2)

def eyes_sad(d):
    d.ellipse([28, 46, 40, 56], fill=(*PAL["white"], 255))
    d.ellipse([56, 46, 68, 56], fill=(*PAL["white"], 255))
    d.ellipse([31, 49, 36, 54], fill=(*PAL["ink"], 255))
    d.ellipse([61, 49, 66, 54], fill=(*PAL["ink"], 255))
    # droop lids outer corners
    d.line([(28, 47), (34, 44)], fill=(*PAL["ink"], 255), width=2)
    d.line([(68, 47), (62, 44)], fill=(*PAL["ink"], 255), width=2)

def eyes_anger(d):
    d.ellipse([28, 46, 40, 56], fill=(*PAL["white"], 255))
    d.ellipse([56, 46, 68, 56], fill=(*PAL["white"], 255))
    d.ellipse([31, 49, 36, 54], fill=(200, 40, 40, 255))
    d.ellipse([61, 49, 66, 54], fill=(200, 40, 40, 255))

def eyes_pain(d):
    for x in (28, 56):
        d.line([(x, 44), (x + 12, 54)], fill=(*PAL["ink"], 255), width=2)
        d.line([(x + 12, 44), (x, 54)], fill=(*PAL["ink"], 255), width=2)

def eyes_dizzy(d):
    for x in (28, 56):
        # spiral approximated with arcs
        d.arc([x, 44, x + 12, 56], 0, 300, fill=(*PAL["ink"], 255), width=1)
        d.arc([x + 3, 47, x + 9, 53], 0, 300, fill=(*PAL["ink"], 255), width=1)

def mouth_happy(d):
    d.arc([34, 62, 62, 80], 20, 160, fill=(*PAL["ink"], 255), width=2)
    d.pieslice([36, 66, 60, 80], 0, 180, fill=(180, 60, 80, 255))

def mouth_sad(d):
    d.arc([36, 72, 60, 88], 200, 340, fill=(*PAL["ink"], 255), width=2)

def mouth_anger(d):
    d.line([(36, 78), (60, 74)], fill=(*PAL["ink"], 255), width=3)
    d.line([(36, 81), (60, 77)], fill=(180, 60, 80, 255), width=1)

def mouth_pain(d):
    d.ellipse([40, 70, 56, 82], fill=(120, 30, 50, 255))
    d.rectangle([40, 70, 56, 74], fill=(*PAL["white"], 255))

def mouth_dizzy(d):
    # wavy line
    x = 36
    while x < 60:
        d.arc([x, 72, x + 8, 80], 180, 360, fill=(*PAL["ink"], 255), width=1)
        d.arc([x + 4, 74, x + 12, 82], 0, 180, fill=(*PAL["ink"], 255), width=1)
        x += 8

def brow_neutral(d):
    d.line([(28, 40), (40, 39)], fill=(*PAL["brown2"], 255), width=2)
    d.line([(56, 39), (68, 40)], fill=(*PAL["brown2"], 255), width=2)

def brow_sad(d):
    d.line([(28, 42), (40, 36)], fill=(*PAL["brown2"], 255), width=2)
    d.line([(68, 42), (56, 36)], fill=(*PAL["brown2"], 255), width=2)

def brow_anger(d):
    d.line([(28, 36), (42, 44)], fill=(*PAL["brown2"], 255), width=3)
    d.line([(68, 36), (54, 44)], fill=(*PAL["brown2"], 255), width=3)

def brow_pain(d):
    d.line([(28, 40), (40, 36)], fill=(*PAL["brown2"], 255), width=2)
    d.line([(68, 40), (56, 36)], fill=(*PAL["brown2"], 255), width=2)

def brow_worry(d):
    d.line([(28, 38), (40, 34)], fill=(*PAL["brown2"], 255), width=2)
    d.line([(68, 38), (56, 34)], fill=(*PAL["brown2"], 255), width=2)


# ---------------------------------------------------------------- LIMBS ----
def limb_part(name, w, h, kind):
    """Vertical capsule parts; pivot at TOP CENTER for limbs, center for torso/head."""
    img = new(w, h)
    d = ImageDraw.Draw(img)
    m = 2
    r = (w - 2 * m) // 2
    if kind == "capsule_top":
        d.ellipse([m, m, w - m, m + 2 * r], fill=(*PAL["skin"], 255))
        d.rectangle([m, m + r, w - m, h - m - r], fill=(*PAL["skin"], 255))
        d.ellipse([m, h - m - 2 * r, w - m, h - m], fill=(*PAL["skin"], 255))
        # muscle shading stripe
        d.rectangle([m + 2, m + r, m + 4, h - m - r], fill=(*PAL["skinD"], 255))
    elif kind == "hand":
        d.ellipse([m, m, w - m, h - m], fill=(*PAL["skin"], 255))
        for fx in range(m + 2, w - 4, 5):
            d.rectangle([fx, h - 8, fx + 3, h - 2], fill=(*PAL["skin"], 255))
    elif kind == "foot":
        d.ellipse([m, m, w - m, h - m], fill=(*PAL["skin"], 255))
        d.polygon([(m, h // 2), (w - m, h // 2), (w - m, h - m), (m, h - m)],
                  fill=(*PAL["skinD"], 255))
    elif kind == "torso":
        d.rounded_rectangle([m, m, w - m, h - m], radius=6, fill=(*PAL["skin"], 255))
        d.rectangle([m + 6, m + 6, w - m - 6, h - m - 6], fill=(*PAL["skin"], 255))
        d.line([(w // 2, m + 8), (w // 2, h - m - 8)], fill=(*PAL["skinD"], 255))
    elif kind == "head":
        d.ellipse([m, m, w - m, h - m], fill=(*PAL["skin"], 255))
        d.chord([m, m, w - m, int(h * 0.7)], 180, 360, fill=(*PAL["brown1"], 255))
        d.ellipse([w // 2 - 8, h // 2, w // 2 - 2, h // 2 + 6], fill=(*PAL["ink"], 255))
        d.ellipse([w // 2 + 2, h // 2, w // 2 + 8, h // 2 + 6], fill=(*PAL["ink"], 255))
    save(img, os.path.join(LIMB, name + ".png"))


def make_swatches():
    img = new(16 * len(PAL), 16)
    d = ImageDraw.Draw(img)
    for i, (name, c) in enumerate(PAL.items()):
        d.rectangle([i * 16, 0, i * 16 + 15, 15], fill=c + (255,))
    save(img, os.path.join(UI, "swatch.png"), do_outline=False)


if __name__ == "__main__":
    make_brain()
    make_heart()
    make_lungs()
    face_base()
    for nm, fn in [("eyes_neutral", eyes_neutral), ("eyes_happy", eyes_happy),
                   ("eyes_sad", eyes_sad), ("eyes_anger", eyes_anger),
                   ("eyes_pain", eyes_pain), ("eyes_dizzy", eyes_dizzy)]:
        _overlay(nm, fn)
    for nm, fn in [("mouth_happy", mouth_happy), ("mouth_sad", mouth_sad),
                   ("mouth_anger", mouth_anger), ("mouth_pain", mouth_pain),
                   ("mouth_dizzy", mouth_dizzy)]:
        _overlay(nm, fn)
    for nm, fn in [("brow_neutral", brow_neutral), ("brow_sad", brow_sad),
                   ("brow_anger", brow_anger), ("brow_pain", brow_pain),
                   ("brow_worry", brow_worry)]:
        _overlay(nm, fn)
    limb_part("torso", 40, 56, "torso")
    limb_part("head", 36, 36, "head")
    limb_part("upper_arm", 12, 30, "capsule_top")
    limb_part("forearm", 10, 28, "capsule_top")
    limb_part("hand", 14, 14, "hand")
    limb_part("thigh", 14, 34, "capsule_top")
    limb_part("shin", 11, 32, "capsule_top")
    limb_part("foot", 16, 10, "foot")
    make_swatches()
    print("All assets generated.")
