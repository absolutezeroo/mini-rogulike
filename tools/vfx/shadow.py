"""The shadow kit (docs/vfx.md, "Shadow"): the void drawn on the shadow ramp, the one turned
inside out (a near-black violet core, a hot magenta edge), at the art's own resolution, hard
alpha. Re-run it to rebuild the sheets:

    python3 tools/vfx/shadow.py [--preview DIR]

    assets/fx/shadow/shadow_knot.png    the shot (Sorcerer, Octopus ink, Shaman hex): a dark knot, a burning rim, smoke spiralling in, 4 frames 16x16
    assets/fx/shadow/shadow_impact.png  a knot landing: a ring collapsing inward, then a puff of smoke, 6 frames 32x32
    assets/fx/shadow/shadow_smoke.png   a nova's or a trail's piece (Shadow Step): smoke curling up and pulled in, 7 frames x 3 variants, 16x16 (ground at row 13)

Shadow's grammar: things converge. Smoke curls toward the middle, rings shrink, a burning rim
around a hole. Its shots are enemy threats (the Sorcerer's, the Octopus's ink, the Shaman's
hex), so the knot carries a bright, broken rim a little larger than the hitbox.
"""
import math
import os
import sys

from strokes import dithered, ellipse, plot
from vfxkit import RESIDUE, ROOT, Element, Sheet

VOID, DUSK, VIOLET, RIM = 0, 1, 2, 3
OUT = os.path.join(ROOT, "assets", "fx", "shadow")


def disc(cell, cx, cy, r, index, squash=1.0):
    for y in range(cell.h):
        for x in range(cell.w):
            if ((x + 0.5 - cx) / r) ** 2 + ((y + 0.5 - cy) / (r * squash)) ** 2 <= 1.0:
                cell.set(x, y, index)


def ring(cell, cx, cy, r, index, start=0.0, sweep=math.tau, steps=0):
    steps = steps or int(r * 10)
    for i in range(steps + 1):
        a = start + sweep * i / steps
        cell.set(int(math.floor(cx + math.cos(a) * r)), int(math.floor(cy + math.sin(a) * r)), index)


def spiral(cell, cx, cy, start_angle, r_out, r_in, turn, index, tip=None):
    """A smoke curl winding from `r_out` in to `r_in` over `turn` radians."""
    steps = 24
    for i in range(steps + 1):
        t = i / steps
        a = start_angle + turn * t
        r = r_out + (r_in - r_out) * t
        x, y = int(math.floor(cx + math.cos(a) * r)), int(math.floor(cy + math.sin(a) * r))
        if cell.get(x, y) is None:
            cell.set(x, y, tip if (tip is not None and t < 0.15) else index)


def build_knot() -> Sheet:
    sheet = Sheet(cell=(16, 16), frames=4)
    c = 8.0
    for frame in range(4):
        cell = sheet.cell(frame)
        turn = frame * math.pi / 4
        # Two smoke curls drawn in from outside, turning with the rim.
        for k in range(2):
            spiral(cell, c, c, turn + k * math.pi + 0.6, 7.6, 4.6, 1.6, DUSK, VIOLET)
        disc(cell, c, c, 4.6, DUSK)
        disc(cell, c, c, 3.4, VOID)
        # The burning rim: two broken arcs, turning.
        for k in range(2):
            ring(cell, c, c, 4.4, RIM, turn + k * math.pi, 1.9)
            ring(cell, c, c, 4.4, VIOLET, turn + k * math.pi + 1.9, 0.5)
        # The hole's single glint (it looks back).
        cell.set(7 if frame % 2 == 0 else 8, 7, VIOLET)
    return sheet


def build_impact() -> Sheet:
    sheet = Sheet(cell=(32, 32), frames=6)
    c = 16.0
    rays = [i * math.tau / 7 + 0.3 for i in range(7)]
    # f0: a wide ring of burning rim, the hole opening.
    f = sheet.cell(0)
    disc(f, c, c, 2.6, VOID)
    plot(f, dithered([(int(c + math.cos(a) * 11), int(c + math.sin(a) * 11)) for a in [i * math.tau / 80 for i in range(80)]], 0.85), RIM)
    ring(f, c, c, 10, VIOLET)
    # f1: it shrinks; filaments are sucked in from outside.
    f = sheet.cell(1)
    for a in rays[::2] + rays[1:2]:
        for r in range(10, 15):
            b = a + (r - 10) * 0.16  # curling in, not shining out
            f.set(int(c + math.cos(b) * r), int(c + math.sin(b) * r), DUSK if r > 12 else VIOLET)
    disc(f, c, c, 7.6, DUSK)
    disc(f, c, c, 5.0, VOID)
    ring(f, c, c, 8, RIM)
    # f2: smaller, darker, the filaments closer.
    f = sheet.cell(2)
    for a in rays[1::2]:
        for r in range(6, 10):
            b = a + 0.25 + (r - 6) * 0.2
            f.set(int(c + math.cos(b) * r), int(c + math.sin(b) * r), DUSK)
    disc(f, c, c, 5.0, DUSK)
    disc(f, c, c, 3.6, VOID)
    ring(f, c, c, 5, RIM)
    # f3: a knot, burning at its edge.
    f = sheet.cell(3)
    disc(f, c, c, 3.4, RIM)
    disc(f, c, c, 2.4, VOID)
    # f4: it pops: a few sparks thrown out, a puff of smoke where it was.
    f = sheet.cell(4)
    disc(f, c, c + 1, 3.0, RESIDUE, 0.7)
    disc(f, c - 1, c, 1.6, DUSK)
    for a in rays[::2]:
        f.set(int(c + math.cos(a) * 7), int(c + math.sin(a) * 7), RIM)
    # f5: the smoke thins.
    f = sheet.cell(5)
    pts = [(x, y) for y in range(int(c - 3), int(c + 4)) for x in range(int(c - 4), int(c + 4)) if ((x - c) / 4) ** 2 + ((y - c) / 3) ** 2 <= 1]
    plot(f, dithered(pts, 0.4), RESIDUE)
    for a in rays[1::3]:
        f.set(int(c + math.cos(a) * 9), int(c + math.sin(a) * 9 + 1), VIOLET)
    return sheet


def build_smoke() -> Sheet:
    sheet = Sheet(cell=(16, 16), frames=7, rows=3)
    for row in range(3):
        cx = 7.5 + (row - 1) * 0.5
        sway = (-1, 1, -1)[row]
        # (radius, lift, curl turn) per frame: swells, curls, is drawn back in and thins.
        stages = [(2.0, 0, 0.0), (3.4, 1, 0.6), (4.3, 2, 1.2), (3.6, 4, 1.8), (2.6, 5, 2.4)]
        for frame, (r, lift, turn) in enumerate(stages):
            f = sheet.cell(frame, row)
            cy = 11.5 - lift
            if frame >= 2:
                spiral(f, cx, cy, turn * sway + (0 if row != 1 else 2), r + 2.4, r * 0.4, 1.7 * sway, VIOLET if frame == 2 else DUSK)
            disc(f, cx, cy, r, DUSK, 0.85)
            if r >= 3:
                disc(f, cx + 0.3, cy + 0.3, r - 1.4, VOID, 0.85)
            # The bright edge catches on the top of the curl.
            if frame <= 3:
                ring(f, cx, cy, r - 0.2, RIM if frame < 3 else VIOLET, -math.pi * 0.85 + row * 0.3, 0.9)
            if frame == 4:
                pts = f.opaque()
                for x, y in pts:
                    f.px[y][x] = None
                plot(f, dithered([(x, y) for x, y in pts], 0.7, row), DUSK)
        f = sheet.cell(5, row)
        pts = [(x, y) for y in range(4, 9) for x in range(int(cx - 2), int(cx + 3))]
        plot(f, dithered(pts, 0.35, row), RESIDUE)
        f = sheet.cell(6, row)
        f.set(int(cx) - 1 + row % 2, 5, DUSK)
        f.set(int(cx) + 2, 3, RESIDUE)
    return sheet


def main() -> None:
    shadow = Element.load("shadow")
    sheets = {
        "shadow_knot": build_knot(),
        "shadow_impact": build_impact(),
        "shadow_smoke": build_smoke(),
    }
    preview_dir = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
    for name, sheet in sheets.items():
        sheet.save(os.path.join(OUT, name + ".png"), shadow)
        if preview_dir:
            os.makedirs(preview_dir, exist_ok=True)
            sheet.preview(os.path.join(preview_dir, name + "_x6.png"), shadow, zoom=6)
        print("wrote", os.path.join("assets", "fx", "shadow", name + ".png"))


if __name__ == "__main__":
    main()
