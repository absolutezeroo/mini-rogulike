#!/usr/bin/env python3
"""Pixel art for the floors' identity (docs/design/dungeon.md, "Room shapes" and "Ceilings").

Draws, in the Ninja Adventure look (16 px tiles, a dark outline, 3-5 colors a piece, lit from the
top left), the pictures the level data points at:
  assets/tiles/deep_water.png        the deep water of the shaped rooms' pools (two 16x16 tiles)
  assets/tiles/ceiling/<name>.png    one atlas per ceiling (CeilingDef.atlas): roots, chains...

Run from the repo root:  python3 tools/levels/level_art.py
Then `godot --headless --import` for the .import files. The atlases' regions are printed and
written next to each atlas as <name>.regions.txt, for the ceilings' data (data/biomes/ceilings/).
Pillow is the only dependency. Deterministic (a fixed seed): rerunning gives the same pictures.
"""

import os
import random
import sys

from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
TILES = os.path.join(ROOT, "assets", "tiles")


def hexc(text, alpha=255):
    text = text.lstrip("#")
    return (int(text[0:2], 16), int(text[2:4], 16), int(text[4:6], 16), alpha)


class Canvas:
    """A small RGBA picture drawn pixel by pixel (hard alpha only)."""

    def __init__(self, w, h):
        self.w = w
        self.h = h
        self.px = {}

    def put(self, x, y, color):
        if 0 <= x < self.w and 0 <= y < self.h and color is not None:
            self.px[(x, y)] = color

    def get(self, x, y):
        return self.px.get((x, y))

    def rect(self, x, y, w, h, color):
        for j in range(h):
            for i in range(w):
                self.put(x + i, y + j, color)

    def outline(self, color):
        """A 1-pixel outline (4-neighbours) around everything drawn."""
        add = []
        for (x, y) in list(self.px):
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (x + dx, y + dy)
                if n not in self.px and 0 <= n[0] < self.w and 0 <= n[1] < self.h:
                    add.append(n)
        for n in add:
            self.px[n] = color

    def mirrored(self):
        out = Canvas(self.w, self.h)
        for (x, y), c in self.px.items():
            out.px[(self.w - 1 - x, y)] = c
        return out

    def image(self):
        im = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), c)
        return im


# --- Water -------------------------------------------------------------------------------------

def deep_water():
    """Two tiles of deep water: the water ramp's middle, ripples a step up and down."""
    rng = random.Random(7)
    base = hexc("3da6bd")
    deep = hexc("2d697b")
    light = hexc("71ddee")
    im = Image.new("RGBA", (32, 16), base)
    for tile in range(2):
        ox = tile * 16
        for n in range(3 + tile):
            x = rng.randrange(0, 12)
            y = rng.randrange(1, 15)
            for i in range(rng.randrange(3, 6)):
                im.putpixel((ox + (x + i) % 16, y), deep)
            for i in range(rng.randrange(2, 4)):
                im.putpixel((ox + (x + 1 + i) % 16, (y + 1) % 16), light)
    im.save(os.path.join(TILES, "deep_water.png"))


# --- The Ninja Adventure palette (the colors the pack's tiles use) -----------------------------

OUT = hexc("141b1b")  # every outline
BARK = [hexc("965746"), hexc("7b473c"), hexc("433737")]  # light, mid, dark
PALE_ROOT = [hexc("d2b37d"), hexc("a3754e"), hexc("6b5040")]
LEAF = [hexc("adbc3a"), hexc("74a334"), hexc("4a7f4b"), hexc("345a52")]
ROCK = [hexc("8d977f"), hexc("5f7160"), hexc("56634d"), hexc("46402e")]
STEEL = [hexc("f2eaf1"), hexc("c7c7c7"), hexc("8c8c8c"), hexc("4e484a")]
GOLD = [hexc("ffe18d"), hexc("f1c471"), hexc("bd7959"), hexc("61372e")]
BRONZE = [hexc("ffad5d"), hexc("bd7959"), hexc("965746"), hexc("61372e")]
RED = [hexc("e0394c"), hexc("a3162c"), hexc("5a0a1e")]
DULL = [hexc("c69469"), hexc("965746"), hexc("61372e")]  # old cloth (the archive)
SAND = [hexc("ecd5ad"), hexc("c69469"), hexc("bd7959"), hexc("965746")]
CHAR = [hexc("7b473c"), hexc("433737"), hexc("2a1f22")]
EMBER = [hexc("ffe18d"), hexc("ffad5d"), hexc("e46d3a")]
DRIP = hexc("b8dce5")
BONE = [hexc("f2eaf1"), hexc("c7c7c7"), hexc("8c8c8c")]
WEB = [hexc("f2eaf1"), hexc("c7c7c7")]
FLOWER = hexc("f2eaf1")


def crop(path, x, y, w, h):
    """A piece of a tileset as a Canvas (its opaque pixels)."""
    im = Image.open(os.path.join(TILES, path)).convert("RGBA").crop((x, y, x + w, y + h))
    c = Canvas(w, h)
    for j in range(h):
        for i in range(w):
            p = im.getpixel((i, j))
            if p[3] > 0:
                c.px[(i, j)] = (p[0], p[1], p[2], 255)
    return c


def paste(dst, src, ox, oy):
    for (x, y), color in src.px.items():
        dst.put(x + ox, y + oy, color)


def trim_bottom(c):
    """The canvas cut down to what is drawn (height), top kept: pieces hang from their top."""
    if not c.px:
        return c
    h = max(y for (_, y) in c.px) + 1
    out = Canvas(c.w, h)
    out.px = dict(c.px)
    return out


# --- Things that hang -------------------------------------------------------------------------

def strand(c, rng, x, top, length, ramp, width=3, wander=0.35, rootlets=0.12):
    """A root or a vine strand: thick at the top, a pixel at the tip, wandering a little,
    lit on its left. Rootlets branch off now and then."""
    tips = []
    for y in range(length):
        t = y / max(length - 1, 1)
        w = max(1, round(width * (1.0 - t * 0.85)))
        if rng.random() < wander and 0 < y < length - 1:
            x += rng.choice((-1, 1))
            x = max(1 + w // 2, min(c.w - 2 - w // 2, x))
        left = x - w // 2
        for i in range(w):
            ramp_i = 0 if i == 0 and w > 1 else (1 if i < w - 1 or w == 1 else 2)
            c.put(left + i, top + y, ramp[ramp_i])
        if rootlets and 3 < y < length - 3 and rng.random() < rootlets:
            side = rng.choice((-1, 1))
            for k in range(1, rng.randrange(2, 5)):
                c.put(x + side * (w // 2 + k), top + y + k, ramp[1])
            tips.append((x + side * 3, top + y + 3))
    return x


def roots(rng, length, ramp=BARK, strands=3, clump=True, w=16):
    c = Canvas(w, length + 2)
    if clump:  # the earth they come out of, along the cliff's edge
        for x in range(1, w - 1):
            for y in range(0, rng.randrange(2, 4)):
                c.put(x, y, ramp[1] if y else ramp[2])
    xs = sorted(rng.sample(range(3, w - 3), strands))
    for i, x in enumerate(xs):
        strand(c, rng, x, 1, max(8, length - rng.randrange(0, length // 2) - i * 2), ramp, width=3 if i != 1 else 2)
    c.outline(OUT)
    return trim_bottom(c)


def vines(rng, length, flowers=False, w=16):
    c = Canvas(w, length + 2)
    for x in range(1, w - 1):  # a lip of leaves along the edge
        c.put(x, 0, LEAF[2])
        if rng.random() < 0.6:
            c.put(x, 1, LEAF[1])
    for n, x in enumerate(sorted(rng.sample(range(3, w - 3), 2))):
        top = 1
        ln = length - n * rng.randrange(3, 9)
        for y in range(ln):
            if rng.random() < 0.25 and 0 < y < ln - 1:
                x = max(2, min(w - 3, x + rng.choice((-1, 1))))
            c.put(x, top + y, LEAF[3])
            if y % 3 == 1:  # a leaf, on alternate sides
                side = 1 if (y // 3) % 2 else -1
                c.put(x + side, top + y, LEAF[1])
                c.put(x + side * 2, top + y, LEAF[0])
                c.put(x + side, top + y + 1, LEAF[2])
            if flowers and y % 7 == 5:
                c.put(x - 1, top + y, FLOWER)
                c.put(x + 1, top + y, FLOWER)
                c.put(x, top + y - 1, FLOWER)
                c.put(x, top + y + 1, FLOWER)
                c.put(x, top + y, hexc("ffe18d"))
    c.outline(OUT)
    return trim_bottom(c)


def moss_drape(rng, w=32):
    c = Canvas(w, 16)
    for x in range(1, w - 1):
        depth = rng.randrange(2, 5)
        for y in range(depth):
            c.put(x, y, LEAF[2] if y == 0 else (LEAF[1] if y < depth - 1 else LEAF[0]))
        if rng.random() < 0.3:  # a strand dripping down
            for y in range(depth, depth + rng.randrange(3, 10)):
                c.put(x, y, LEAF[2])
            if rng.random() < 0.5:
                c.put(x, depth + rng.randrange(3, 9), DRIP)
    c.outline(OUT)
    return trim_bottom(c)


def stalactites(rng, w=16, drip=True, ramp=ROCK):
    c = Canvas(w, 30)
    for x in range(0, w):  # the rock lip
        c.put(x, 0, ramp[3])
        c.put(x, 1, ramp[2])
    xs = [rng.randrange(2, 5), rng.randrange(6, 10), rng.randrange(11, w - 2)]
    for x0 in xs:
        length = rng.randrange(8, 26)
        half = rng.choice((2, 2, 3))
        for y in range(length):
            t = y / length
            hw = max(0, round(half * (1 - t)))
            for dx in range(-hw, hw + 1):
                shade = 0 if dx == -hw and hw > 0 else (2 if dx == hw and hw > 0 else 1)
                c.put(x0 + dx, 2 + y, ramp[shade])
        if drip and rng.random() < 0.7:
            c.put(x0, 2 + length + rng.randrange(1, 3), DRIP)
    c.outline(OUT)
    return trim_bottom(c)


def chain(c, x, top, length, ramp=STEEL):
    """A chain hanging straight: a link seen face on (3x4), one seen edge on (1x3), turn about."""
    y = top
    face = True
    while y < top + length:
        if face:
            for j in range(4):
                c.put(x - 1, y + j, ramp[1] if j < 2 else ramp[2])
                c.put(x + 1, y + j, ramp[2] if j < 2 else ramp[3])
            c.put(x, y, ramp[0])
            c.put(x, y + 3, ramp[2])
            y += 3
        else:
            for j in range(3):
                c.put(x, y + j, ramp[1] if j == 0 else ramp[2])
            y += 2
        face = not face
    return y


def hanging_chain(rng, length, end=None, ramp=STEEL, w=12):
    """A chain from the ceiling and what hangs on it: a hook, a skull, a cage, a censer, a disc."""
    c = Canvas(w, length + 20)
    mid = w // 2
    y = chain(c, mid, 0, length, ramp)
    if end == "hook":
        for j in range(4):
            c.put(mid, y + j, ramp[1])
        c.put(mid + 1, y + 4, ramp[1])
        c.put(mid + 2, y + 3, ramp[2])
        c.put(mid + 2, y + 2, ramp[0])
    elif end == "skull":
        skull = crop("floor_detail.png", 208, 0, 16, 16)
        paste(c, skull, mid - 8, y - 3)
    elif end == "cage":
        cw, ch = 9, 12
        left = mid - cw // 2
        for j in range(ch):
            for i in range(0, cw, 2):
                c.put(left + i, y + j, ramp[1] if i < cw // 2 else ramp[2])
        for i in range(cw):
            c.put(left + i, y, ramp[0])
            c.put(left + i, y + ch // 2, ramp[2])
            c.put(left + i, y + ch - 1, ramp[2])
        bone = crop("floor_detail.png", 224, 0, 16, 16)  # a bone lying in it
        for (bx, by), color in bone.px.items():
            if 4 <= bx < 12 and 6 <= by < 10:
                c.put(left + bx - 3, y + ch - 5 + by - 6, color)
    elif end == "censer":
        bowl = [(0, 3), (-1, 4), (1, 4)]
        for k in range(-3, 4):  # the three chains of the bowl meeting
            c.put(mid + k // 2, y + abs(k) // 2, ramp[2])
        for j in range(5):
            half = 4 - max(0, j - 2)
            for i in range(-half, half + 1):
                shade = 0 if i == -half else (2 if i >= half - 1 else 1)
                c.put(mid + i, y + 3 + j, BRONZE[shade + (1 if j > 2 else 0)])
        for i in (-2, 0, 2):  # embers in it
            c.put(mid + i, y + 3, EMBER[rng.randrange(0, 3)])
        c.put(mid - 1, y + 2, EMBER[1])
        c.put(mid + 1, y + 2, EMBER[0])
    elif end == "disc":  # a sun disc of the Dead Sun's priests
        r = 4
        for j in range(-r, r + 1):
            for i in range(-r, r + 1):
                d = i * i + j * j
                if d <= r * r:
                    c.put(mid + i, y + r + j + 1, GOLD[0] if d < 4 and i <= 0 else (GOLD[1] if i - j < 3 else GOLD[2]))
        for (i, j) in ((0, -r - 2), (0, r + 2), (-r - 2, 0), (r + 2, 0)):
            c.put(mid + i, y + r + 1 + j, GOLD[1])
    elif end == "bones":
        # A bundle of long bones tied under the chain: three hanging side by side.
        for k, (dx, ln) in enumerate(((-3, 9), (0, 11), (3, 8))):
            x = mid + dx
            for j in range(ln):
                c.put(x, y + 1 + j, BONE[0] if j < ln // 2 else BONE[1])
                c.put(x + 1, y + 1 + j, BONE[1] if j < ln // 2 else BONE[2])
            for (kx, ky) in ((-1, 0), (2, 0), (-1, ln - 1), (2, ln - 1)):  # the knobs
                c.put(x + kx, y + 1 + ky, BONE[1])
        for i in range(-4, 6):  # the cord round them
            c.put(mid + i, y + 3, BARK[1])
    c.outline(OUT)
    return trim_bottom(c)


def chain_swag(rng, w=32, ramp=STEEL):
    """A chain hung between two rings in the wall, sagging."""
    c = Canvas(w, 16)
    for x in range(2, w - 2):
        t = (x - 2) / (w - 5)
        sag = round(7 * 4 * t * (1 - t))
        y = 2 + sag
        c.put(x, y, ramp[1] if x % 3 else ramp[0])
        c.put(x, y + 1, ramp[2] if x % 3 else ramp[3])
    for x in (1, w - 2):  # the rings
        c.put(x, 1, ramp[0])
        c.put(x, 2, ramp[1])
        c.put(x, 3, ramp[2])
    c.outline(OUT)
    return trim_bottom(c)


def cobweb(rng, w=16):
    c = Canvas(w, w)
    for k in range(5):  # threads from the corner
        angle = (k + 0.5) / 5 * 1.5708
        import math
        for r in range(1, w):
            x = round(math.cos(angle) * r)
            y = round(math.sin(angle) * r * 0.9)
            if r < w - 2 - k % 2:
                c.put(x, y, WEB[1])
    for r in (4, 8, 12):  # the rings across them
        import math
        for s in range(30):
            angle = s / 29 * 1.5708
            x = round(math.cos(angle) * r)
            y = round(math.sin(angle) * r * 0.9 + (1 if 8 < s < 22 else 0))
            c.put(x, y, WEB[0] if s % 3 else WEB[1])
    return c


def banner(rng, cloth=RED, trim=GOLD, w=14, length=28, torn=False, sigil=True):
    c = Canvas(w + 2, length + 4)
    for x in range(0, w + 2):  # the rod
        c.put(x, 0, BARK[1])
        c.put(x, 1, BARK[2])
    c.put(0, 0, BARK[0])
    c.put(w + 1, 0, BARK[0])
    for y in range(2, length):
        for x in range(1, w + 1):
            edge = x in (1, w) or y == 2
            shade = 0 if x < 4 else (1 if x < w - 2 else 2 if len(cloth) > 2 else 1)
            c.put(x, y, trim[1] if edge and trim else cloth[shade])
    # The bottom: a swallowtail, or torn rags.
    for x in range(1, w + 1):
        cut = abs(x - (w + 1) / 2)
        drop = round(4 - cut * 0.7) if not torn else rng.randrange(0, 6)
        for y in range(length - max(drop, 0), length):
            c.px.pop((x, y), None)
        if torn and rng.random() < 0.3:
            for y in range(length - drop - rng.randrange(2, 6), length - drop):
                c.px.pop((x, y), None)
    if sigil:  # the sun sign of the Pyre Temple, in its trim
        cx, cy = (w + 1) // 2 + 0, length // 2
        for (i, j) in ((0, -3), (-2, -2), (2, -2), (-3, 0), (3, 0), (-2, 2), (2, 2), (0, 3)):
            c.put(cx + i, cy + j, trim[0] if trim else cloth[0])
        c.put(cx, cy, trim[0] if trim else cloth[0])
    c.outline(OUT)
    return trim_bottom(c)


def beam(rng, ramp=CHAR, embers=True, w=16, h=10):
    """Three parts side by side (left end, middle, right end) of a charred beam across a room."""
    c = Canvas(w * 3, h)
    for part in range(3):
        ox = part * w
        for x in range(w):
            for y in range(2, h - 2):
                shade = 0 if y == 2 else (1 if y < h - 3 else 2)
                c.put(ox + x, y, ramp[shade])
            if rng.random() < 0.25:
                c.put(ox + x, rng.randrange(3, h - 3), ramp[2])
        if embers:
            for k in range(2):
                c.put(ox + rng.randrange(1, w - 1), rng.randrange(4, h - 3), EMBER[rng.randrange(1, 3)])
    # The ends broken off: ragged.
    for y in range(2, h - 2):
        for x in range(rng.randrange(0, 4)):
            c.px.pop((x, y), None)
        for x in range(rng.randrange(0, 4)):
            c.px.pop((w * 3 - 1 - x, y), None)
    c.outline(OUT)
    return c


def arch(rng, ramp=SAND, w=16, h=16):
    """Three parts of a stone arch across a room: the left springer, a row of voussoirs (the
    middle, repeated), the right springer."""
    c = Canvas(w * 3, h)
    for part in range(3):
        ox = part * w
        if part == 1:
            for x in range(w):
                for y in range(3, 11):
                    joint = (x % 8 == 0) or y == 3
                    c.put(ox + x, y, ramp[2] if joint else (ramp[0] if y < 6 else ramp[1]))
            continue
        # A springer: the arch's foot, curving down to the wall.
        for x in range(w):
            t = x / (w - 1) if part == 0 else 1 - x / (w - 1)
            bottom = 11 + round(4 * (1 - t) ** 2)
            for y in range(3, min(h, bottom)):
                joint = (x % 8 == 0) or y == 3
                c.put(ox + x, y, ramp[2] if joint else (ramp[0] if y < 6 else ramp[1]))
    c.outline(OUT)
    return c


def awning(rng, stripes=(hexc("f2eaf1"), hexc("e0394c")), w=32):
    c = Canvas(w, 14)
    for x in range(w):
        stripe = stripes[(x // 4) % 2]
        for y in range(0, 9):
            c.put(x, y, stripe if y > 1 else BARK[1])
        if (x % 8) in (1, 2, 3, 4, 5, 6):  # scallops
            depth = 9 + (1 if (x % 8) in (2, 3, 4, 5) else 0) + (1 if (x % 8) in (3, 4) else 0)
            for y in range(9, depth + 1):
                c.put(x, y, stripe)
    for x in range(w):  # its shade under the rod
        if c.get(x, 2) is not None:
            c.put(x, 2, hexc("c7c7c7") if stripes[(x // 4) % 2] == hexc("f2eaf1") else RED[1])
    c.outline(OUT)
    return trim_bottom(c)


def palm_fronds(rng, w=32):
    """Palm leaves hanging over the edge (the oasis' palms grow on the plateau above)."""
    src = crop("desert.png", 160, 64, 32, 24)  # the top of a palm of the pack
    c = Canvas(w, 24)
    for (x, y), color in src.px.items():
        if y < 20:
            c.put(x, y, color)
    return trim_bottom(c)


def sand_lip(rng, w=8):
    """Where the sand trickles from: a crack's broken lip (the stream itself is particles)."""
    c = Canvas(w, 4)
    for x in range(1, w - 1):
        c.put(x, 0, SAND[2])
        if rng.random() < 0.6:
            c.put(x, 1, SAND[1])
    c.put(w // 2, 2, SAND[0])
    c.outline(OUT)
    return trim_bottom(c)


# --- Atlases ----------------------------------------------------------------------------------

def pack(name, pieces):
    """Packs `pieces` ([(key, Canvas)]) into one atlas (shelves 2 px apart) and saves it, with the
    regions next to it. Returns {key: (x, y, w, h)}."""
    pad = 2
    width = 256
    x = y = shelf = 0
    regions = {}
    for key, c in pieces:
        if x + c.w > width:
            x = 0
            y += shelf + pad
            shelf = 0
        regions[key] = (x, y, c.w, c.h)
        x += c.w + pad
        shelf = max(shelf, c.h)
    height = y + shelf
    im = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    for key, c in pieces:
        rx, ry, _, _ = regions[key]
        im.alpha_composite(c.image(), (rx, ry))
    folder = os.path.join(TILES, "ceiling")
    os.makedirs(folder, exist_ok=True)
    im.save(os.path.join(folder, name + ".png"))
    with open(os.path.join(folder, name + ".regions.txt"), "w") as f:
        for key, r in regions.items():
            f.write("%s %d %d %d %d\n" % (key, *r))
    return regions


def ceilings():
    """One atlas per ceiling (the keys are the pieces' names in data/biomes/ceilings/)."""
    rng = random.Random(1213)
    out = {}
    out["grotto"] = pack("grotto", [
        ("stalactites_a", stalactites(rng)), ("stalactites_b", stalactites(rng)), ("stalactites_c", stalactites(rng)),
        ("roots_a", roots(rng, 34)), ("roots_b", roots(rng, 26, strands=2)), ("roots_c", roots(rng, 40)),
        ("moss_a", moss_drape(rng)), ("moss_b", moss_drape(rng)),
        ("side_roots_a", roots(rng, 30, strands=2, clump=False, w=10)), ("side_roots_b", roots(rng, 22, strands=2, clump=False, w=10)),
    ])
    out["garden"] = pack("garden", [
        ("roots_a", roots(rng, 36, PALE_ROOT)), ("roots_b", roots(rng, 28, PALE_ROOT, strands=2)), ("roots_c", roots(rng, 44, PALE_ROOT)),
        ("vines_a", vines(rng, 32, flowers=True)), ("vines_b", vines(rng, 24, flowers=True)), ("vines_c", vines(rng, 40)),
        ("side_vines_a", vines(rng, 28, w=10)), ("side_vines_b", vines(rng, 20, flowers=True, w=10)),
        ("moss_a", moss_drape(rng)),
    ])
    out["drowned"] = pack("drowned", [
        ("stalactites_a", stalactites(rng)), ("stalactites_b", stalactites(rng)), ("stalactites_c", stalactites(rng)),
        ("moss_a", moss_drape(rng)), ("moss_b", moss_drape(rng)), ("moss_c", moss_drape(rng, 24)),
        ("roots_a", roots(rng, 30)), ("roots_b", roots(rng, 22, strands=2)),
        ("side_moss_a", vines(rng, 26, w=10)),
    ])
    out["ossuary"] = pack("ossuary", [
        ("chain_hook", hanging_chain(rng, 40, "hook")), ("chain_skull", hanging_chain(rng, 34, "skull", w=16)),
        ("chain_cage", hanging_chain(rng, 30, "cage")), ("chain_bones", hanging_chain(rng, 36, "bones", w=16)),
        ("swag_a", chain_swag(rng)), ("swag_b", chain_swag(rng, 24)),
        ("cobweb", cobweb(rng)), ("roots_a", roots(rng, 24, strands=2)),
    ])
    out["archive"] = pack("archive", [
        ("banner_a", banner(rng, DULL, None, torn=True, sigil=False)), ("banner_b", banner(rng, DULL, None, length=22, torn=True, sigil=False)),
        ("cobweb", cobweb(rng)), ("chain_hook", hanging_chain(rng, 36, "hook")), ("swag_a", chain_swag(rng)),
        ("roots_a", roots(rng, 22, strands=2)),
    ])
    out["temple"] = pack("temple", [
        ("banner_a", banner(rng)), ("banner_b", banner(rng, length=34)),
        ("censer_a", hanging_chain(rng, 40, "censer", BRONZE[1:] + [OUT], w=12)), ("censer_b", hanging_chain(rng, 30, "censer", BRONZE[1:] + [OUT], w=12)),
        ("swag_a", chain_swag(rng, ramp=GOLD)), ("cobweb", cobweb(rng)),
    ])
    out["cinders"] = pack("cinders", [
        ("beam", beam(rng)), ("beam_b", beam(rng)),
        ("censer_a", hanging_chain(rng, 34, "censer", BRONZE[1:] + [OUT], w=12)),
        ("chain_hook", hanging_chain(rng, 30, "hook", [CHAR[0], CHAR[0], CHAR[1], CHAR[2]])),
        ("roots_a", roots(rng, 22, CHAR, strands=2)),
    ])
    out["dust_city"] = pack("dust_city", [
        ("arch", arch(rng)), ("arch_b", arch(rng)),
        ("awning_a", awning(rng)), ("awning_b", awning(rng, (hexc("f2eaf1"), hexc("3da6bd")))),
        ("fronds", palm_fronds(rng)), ("sand_lip", sand_lip(rng)),
    ])
    out["dead_sun"] = pack("dead_sun", [
        ("arch", arch(rng)), ("chain_disc", hanging_chain(rng, 40, "disc", GOLD, w=16)), ("chain_disc_b", hanging_chain(rng, 28, "disc", GOLD, w=16)),
        ("swag_a", chain_swag(rng, ramp=GOLD)), ("sand_lip", sand_lip(rng)), ("cobweb", cobweb(rng)),
    ])
    return out


def paper_boats():
    """Two paper boats rotting on a bank (the Drowned Hall): one afloat, one sagging."""
    im = Image.new("RGBA", (32, 16), (0, 0, 0, 0))
    for n, sag in enumerate((0, 2)):
        c = Canvas(16, 16)
        # The hull: a trapezoid, the sail: a triangle, folded paper lit from the left.
        for y in range(9, 12):
            inset = y - 9
            for x in range(2 + inset, 14 - inset):
                c.put(x, y + (sag if x > 8 else 0) // 2, STEEL[1] if x < 8 else STEEL[2])
        for y in range(4 + sag, 9):
            half = (y - 4 - sag) // 2 + 1
            for x in range(8 - half, 8 + half):
                c.put(x, y, STEEL[0] if x < 8 else STEEL[1])
        c.put(5, 10, hexc("bd7959"))  # damp stains
        c.put(11, 9 + sag // 2, hexc("8c8c8c"))
        c.outline(OUT)
        im.alpha_composite(c.image(), (n * 16, 0))
    im.save(os.path.join(TILES, "paper_boats.png"))


def main():
    deep_water()
    paper_boats()
    print("deep_water.png, paper_boats.png")
    for name, regions in ceilings().items():
        print(name, len(regions), "pieces")


if __name__ == "__main__":
    sys.exit(main())
