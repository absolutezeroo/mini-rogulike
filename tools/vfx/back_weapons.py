"""The weapons the hero carries at rest (WeaponDef.back_sprite): small pixel art, rebuildable.

    python3 tools/vfx/back_weapons.py [--preview /tmp/back_x8.png]

Writes assets/weapons/back/<id>.png. The hero is a 15-pixel chibi and a weapon in hand is about
10 pixels long (assets/weapons/attack/), so the item icons (14-23 pixels) would dwarf him: each
weapon is redrawn here at the in-hand size, in its icon's own colors, never rotated by code.

Slung weapons (across the back) are drawn along a 45-degree "/" diagonal, the end that rides
over the shoulder (a hilt, an axe's head, a lance's point) at the top right: the rig shows the
sprite as it is when the hero faces down (behind him), mirrored when he faces up (we see the
back) and per side (ActorRig). A slung weapon is described as a profile along its length, top
end first: each step is the core pixel, its width (2: a blade, lit on its upper-left side) and
pixels across it (a guard, an axe's head). The outline (the icons' near-black) goes around by
4-neighbours. Hip things (a tome, shurikens, a coiled whip) are drawn as they are.
"""
from __future__ import annotations

import argparse
import os
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "weapons", "back")

# The icons' colors (assets/weapons/*.png).
C = {
    "o": (0x14, 0x1B, 0x1B),  # outline
    "W": (0xF2, 0xEA, 0xF1),  # steel, lit
    "s": (0xAB, 0xC2, 0xBC),  # steel
    "d": (0x8D, 0x97, 0x7F),  # steel, shade
    "S": (0x5F, 0x71, 0x60),  # steel, dark
    "G": (0xFF, 0xAD, 0x5D),  # brass, light wood
    "w": (0xA3, 0x75, 0x4E),  # wood
    "b": (0x96, 0x53, 0x40),  # dark wood, leather
    "Y": (0xFF, 0xE1, 0x8D),  # bow's lit wood
    "r": (0xD1, 0x4B, 0x34),  # red cover
    "R": (0x8F, 0x3E, 0x56),  # dark red
    "e": (0xE0, 0x39, 0x4C),  # red ribbon
    "c": (0x79, 0xB8, 0xCE),  # cyan gem
    "E": (0xE6, 0x6A, 0x3A),  # orange
}

# Slung: steps top end first. A step is (core, width, light, across) where `light` is the
# color of the second pixel of a 2-wide step (to the right: the shaded side), `across` a list of
# (distance, color) pixels along the "\" diagonal through the core, both sides.
SLUNG = {
    "katana": [
        ("G", 1, None, []),
        ("b", 1, None, []),
        ("w", 1, None, []),
        ("G", 1, None, [(1, "G")]),
        ("W", 2, "d", []),
        ("W", 2, "s", []),
        ("W", 2, "s", []),
        ("s", 1, None, []),
        ("W", 1, None, []),
    ],
    "big_sword": [
        ("G", 1, None, []),
        ("b", 1, None, []),
        ("w", 1, None, []),
        ("G", 2, "w", [(1, "G"), (2, "G")]),
        ("W", 2, "d", []),
        ("W", 2, "s", []),
        ("W", 2, "s", []),
        ("W", 2, "s", []),
        ("W", 2, "d", []),
        ("W", 1, None, []),
    ],
    "templar_sword": [
        ("G", 1, None, []),
        ("w", 1, None, []),
        ("G", 1, None, [(1, "G"), (2, "w")]),
        ("W", 2, "s", []),
        ("W", 2, "s", []),
        ("W", 2, "s", []),
        ("W", 2, "d", []),
        ("W", 1, None, []),
    ],
    "ninjaku": [
        ("s", 1, None, []),
        ("G", 1, None, []),
        ("b", 1, None, []),
        ("d", 1, None, [(1, "d")]),
        ("W", 2, "s", []),
        ("W", 2, "s", []),
        ("W", 2, "d", []),
        ("W", 1, None, []),
    ],
    "rapier": [
        ("G", 1, None, []),
        ("b", 1, None, []),
        ("G", 2, "E", [(1, "G")]),
        ("W", 1, None, []),
        ("s", 1, None, []),
        ("W", 1, None, []),
        ("s", 1, None, []),
        ("W", 1, None, []),
        ("W", 1, None, []),
    ],
    "sai": [
        ("r", 1, None, []),
        ("R", 1, None, []),
        ("r", 1, None, []),
        ("s", 1, None, [(1, "s")]),
        ("W", 1, None, []),
        ("s", 1, None, []),
        ("W", 1, None, []),
    ],
    "axe": [
        ("d", 1, None, []),
        ("s", 1, None, [(1, "s"), (2, "W")]),
        ("s", 1, None, [(1, "s"), (2, "W")]),
        ("d", 1, None, []),
        ("w", 1, None, []),
        ("b", 1, None, []),
        ("w", 1, None, []),
        ("b", 1, None, []),
        ("w", 1, None, []),
    ],
    "hammer": [
        ("w", 1, None, [(1, "w"), (2, "b")]),
        ("G", 1, None, [(1, "G"), (2, "w")]),
        ("b", 1, None, []),
        ("w", 1, None, []),
        ("b", 1, None, []),
        ("w", 1, None, []),
        ("b", 1, None, []),
        ("w", 1, None, []),
    ],
    "pickaxe": [
        ("s", 1, None, [(1, "s"), (2, "d"), (3, "S")]),
        ("G", 1, None, []),
        ("w", 1, None, []),
        ("G", 1, None, []),
        ("w", 1, None, []),
        ("G", 1, None, []),
        ("w", 1, None, []),
    ],
    "lance": [
        ("W", 1, None, []),
        ("W", 2, "s", []),
        ("s", 2, "d", []),
        ("G", 1, None, []),
        ("w", 1, None, []),
        ("e", 1, None, []),
        ("w", 1, None, []),
        ("w", 1, None, []),
        ("G", 1, None, []),
        ("b", 1, None, []),
        ("w", 1, None, []),
    ],
    "stick": [
        ("w", 1, None, []),
        ("w", 1, None, []),
        ("W", 1, None, []),
        ("s", 1, None, []),
        ("W", 1, None, []),
        ("s", 1, None, []),
        ("W", 1, None, []),
        ("s", 1, None, []),
        ("w", 1, None, []),
        ("w", 1, None, []),
    ],
    "magic_wand": [
        ("W", 2, "c", []),
        ("c", 2, "c", []),
        ("G", 1, None, [(1, "b")]),
        ("G", 1, None, []),
        ("G", 1, None, []),
        ("b", 1, None, []),
        ("G", 1, None, []),
        ("G", 1, None, []),
        ("b", 1, None, []),
    ],
}

# The bow: a limb bending away from the string, both drawn along the diagonal. (step, offset
# across, color): the string is the straight diagonal, the limb bows out to the upper left.
BOW_LIMB = [0, 1, 2, 2, 3, 3, 3, 2, 2, 1, 0]
BOW_LIMB_COLOR = "YwwbwGwbwwY"

# Hip things, drawn as they are.
HIP = {
    "book": [
        ".ooooo.",
        "oRrrrWo",
        "oRrGrso",
        "oRrrrWo",
        "oRrrrso",
        ".ooooo.",
    ],
    # A pinwheel of four blades round a dark hole.
    "shuriken": [
        "..oo...",
        ".oWWoo.",
        "..osWso",
        ".osSso.",
        "oWsWo..",
        ".oosWo.",
        "...oo..",
    ],
    # The whip coiled at the belt, its handle hanging.
    "whip": [
        ".ooooo.",
        "oWWWWso",
        "osooWso",
        "osoWoso",
        "osWssWo",
        ".oosoo.",
        "..obo..",
        "..oGo..",
        "...o...",
    ],
}


def slung(steps) -> dict:
    """Pixels of a slung weapon: step k's core at (n - 1 - k, k), the top end at the top right.
    Pixels across (a guard, a head) run along the "\\" diagonal, each joined to the one before by
    a pixel beside it, so a guard is a solid bar and not a dotted line."""
    n = len(steps)
    pixels = {}
    for k, (core, width, light, across) in enumerate(steps):
        x, y = n - 1 - k + 3, k + 3
        pixels[(x, y)] = core
        if width == 2:
            pixels[(x + 1, y)] = light
        for distance, color in across:
            pixels.setdefault((x + distance, y + distance), color)
            pixels.setdefault((x + distance, y + distance - 1), color)
            pixels.setdefault((x - distance, y - distance), color)
            pixels.setdefault((x - distance + 1, y - distance), color)
    return pixels


def bow() -> tuple[dict, dict]:
    """The limb (outlined) and the string (a thin line, no outline: it is a cord)."""
    n = len(BOW_LIMB)
    limb = {}
    string = {}
    previous = None
    for k in range(n):
        x, y = n - 1 - k + 4, k + 1
        out = BOW_LIMB[k]
        point = (x - out, y - out)
        if previous:
            # 4-connected: a step across, then down.
            px, py = previous
            while px != point[0]:
                px += 1 if point[0] > px else -1
                limb.setdefault((px, py), BOW_LIMB_COLOR[k])
            while py != point[1]:
                py += 1 if point[1] > py else -1
                limb.setdefault((px, py), BOW_LIMB_COLOR[k])
        limb[point] = BOW_LIMB_COLOR[k]
        previous = point
        if 0 < k < n - 1:
            string[(x, y)] = "d"
    return limb, string


def outlined(pixels: dict, over: dict | None = None) -> Image.Image:
    filled = dict(pixels)
    for (x, y) in list(pixels):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if (x + dx, y + dy) not in filled:
                filled[(x + dx, y + dy)] = "o"
    for point, key in (over or {}).items():
        if point not in pixels:
            filled[point] = key
    return paint(filled)


def paint(pixels: dict) -> Image.Image:
    xs = [p[0] for p in pixels]
    ys = [p[1] for p in pixels]
    x0, y0 = min(xs), min(ys)
    image = Image.new("RGBA", (max(xs) - x0 + 1, max(ys) - y0 + 1), (0, 0, 0, 0))
    for (x, y), key in pixels.items():
        image.putpixel((x - x0, y - y0), C[key] + (255,))
    return image


def from_rows(rows) -> Image.Image:
    pixels = {}
    for y, row in enumerate(rows):
        for x, key in enumerate(row):
            if key != ".":
                pixels[(x, y)] = key
    return paint(pixels)


def build() -> dict:
    images = {name: outlined(slung(steps)) for name, steps in SLUNG.items()}
    limb, string = bow()
    images["bow"] = outlined(limb, string)
    for name, rows in HIP.items():
        images[name] = from_rows(rows)
    return images


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview", help="a zoomed sheet of every weapon (x8), for review")
    args = parser.parse_args()
    os.makedirs(OUT, exist_ok=True)
    images = build()
    for name, image in sorted(images.items()):
        image.save(os.path.join(OUT, name + ".png"))
        print(name, image.size)
    if args.preview:
        cell = 20
        names = sorted(images)
        sheet = Image.new("RGBA", (cell * len(names), cell * 2), (0, 0, 0, 0))
        for i, name in enumerate(names):
            for row, floor in enumerate([(36, 28, 40, 255), (196, 170, 120, 255)]):
                tile = Image.new("RGBA", (cell, cell), floor)
                tile.alpha_composite(images[name], (2, 2))
                sheet.alpha_composite(tile, (i * cell, row * cell))
        sheet.resize((sheet.width * 8, sheet.height * 8), Image.NEAREST).save(args.preview)


if __name__ == "__main__":
    main()
