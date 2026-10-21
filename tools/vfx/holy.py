"""The holy kit (docs/vfx.md, "Holy"): light from above drawn on the holy ramp (warm white,
gold, amber, then the browns that outline it on bright floors), at the art's own resolution,
hard alpha. Re-run it to rebuild the sheets:

    python3 tools/vfx/holy.py [--preview DIR]

    assets/fx/holy/holy_ray.png     a nova's piece: a thin shaft of light rising from the ground, 7 frames x 3 variants, 16x24 (ground at row 22)
    assets/fx/holy/holy_column.png  Smite / Holy Light: a column of light falling onto the ground, 7 frames 40x96 (ground at row 86)
    assets/fx/holy/holy_aegis.png   Holy Shield: a ring of light rising around the hero into a halo, 7 frames 32x40 (feet at row 36)
    assets/fx/holy/holy_sigil.png   heals, buffs, a skill learned (Vfx.magic): a ring of light on the ground, rays rising, 8 frames 48x40 (ring centered on row 30)

Holy's grammar: vertical rays and columns, rings lying on the ground, slow motes falling, and
the 4-point glint (a plus with long vertical arms), which no other element uses. The core is
warm white; the shafts thin out from the sides in and dither away at the top. The sigil is
recolored at runtime for heals and buffs of other colors (`recolor` on its VfxSheetDef), so it
is drawn with all five steps of the ramp in luminance order.
"""
import os
import random
import sys

from strokes import dithered, ellipse, glint, line, plot, rim
from vfxkit import ROOT, Element, Sheet

WHITE, GOLD, AMBER, BRONZE, UMBER = 0, 1, 2, 3, 4
OUT = os.path.join(ROOT, "assets", "fx", "holy")


def shaft(cell, cx, ground, height, widths, top_fade=0.3, salt=0):
    """A vertical shaft of light standing on `ground`: `widths` = [(half_width, index)...] from
    the outside in; its top `top_fade` dithers away."""
    for half, index in widths:
        for y in range(int(ground - height), int(ground) + 1):
            rise = (ground - y) / max(height, 1)
            keep = 1.0 if rise < 1.0 - top_fade else (1.0 - rise) / top_fade
            for x in range(int(cx - half), int(cx + half)):
                if dithered([(x, y)], keep, salt):
                    cell.set(x, y, index)


def build_ray(rng: random.Random) -> Sheet:
    """A thin shaft of light standing on the ground (a cell wider than the shaft, so a ring of
    them stays sparse and never hides the monsters inside it)."""
    sheet = Sheet(cell=(16, 24), frames=7, rows=3)
    ground = 22
    for row, height in enumerate((17, 12, 14)):
        cx = 8
        gx = cx - 1 if row % 2 else cx
        # f0: the light touches the ground: a short bright stub and a glint on the floor.
        f = sheet.cell(0, row)
        shaft(f, cx, ground, height * 0.35, [(1, GOLD)], 0.5)
        plot(f, line(cx - 2, ground, cx + 1, ground), AMBER)
        f.set(cx - 1, ground, WHITE)
        # f1: the shaft at full height, white at its heart, a glint on its top.
        f = sheet.cell(1, row)
        shaft(f, cx, ground, height, [(2, AMBER), (1, WHITE)], 0.3, row)
        plot(f, line(cx - 3, ground, cx + 2, ground), GOLD)
        plot(f, line(cx - 3, ground + 1, cx + 2, ground + 1), BRONZE)
        glint(f, gx, ground - height - 2, 2, GOLD, WHITE)
        # f2: it holds, its glint flares.
        f = sheet.cell(2, row)
        shaft(f, cx, ground, height, [(1, GOLD)], 0.4, row + 1)
        plot(f, line(cx - 2, ground, cx + 1, ground), AMBER)
        glint(f, gx, ground - height - 1, 3, GOLD, WHITE)
        # f3: thinner, the first motes of light drifting down beside it.
        f = sheet.cell(3, row)
        shaft(f, cx, ground, height * 0.8, [(1, AMBER)], 0.6, row)
        f.set(cx - 1, ground, AMBER)
        for mx, my in ((cx - 4, ground - height * 0.6), (cx + 3, ground - height * 0.35)):
            f.set(mx, my, GOLD)
        # f4: a band of it left, dithered; the motes lower.
        f = sheet.cell(4, row)
        shaft(f, cx, ground - 3, height * 0.4, [(1, AMBER)], 0.9, row)
        f.set(cx - 4, ground - height * 0.45, AMBER)
        f.set(cx + 3, ground - height * 0.2, GOLD)
        f.set(cx - 1, ground, BRONZE)
        # f5: motes near the ground.
        f = sheet.cell(5, row)
        f.set(cx - 4, ground - 4, BRONZE)
        f.set(cx + 3, ground - 2, AMBER)
        # f6: the last pixel.
        f = sheet.cell(6, row)
        f.set(cx + 3, ground - 1, UMBER)
    return sheet


def ground_glow(cell, cx, cy, rx, ry, index, fill=None):
    if fill is not None:
        for y in range(int(cy - ry), int(cy + ry) + 1):
            for x in range(int(cx - rx), int(cx + rx) + 1):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                    cell.set(x, y, fill)
    plot(cell, ellipse(cx, cy, rx, ry), index)


def build_column(rng: random.Random) -> Sheet:
    sheet = Sheet(cell=(40, 96), frames=7)
    cx, ground = 20, 86
    glints = [(11, 70), (29, 62), (14, 50), (27, 78)]
    # f0: a thin beam finds the ground.
    f = sheet.cell(0)
    shaft(f, cx, ground, ground, [(1, GOLD)], 0.15)
    ground_glow(f, cx, ground, 6, 2, AMBER, GOLD)
    plot(f, line(cx - 2, ground, cx + 1, ground), WHITE)
    # f1: the column falls: wide, white at the heart; the ground floods with light.
    f = sheet.cell(1)
    ground_glow(f, cx, ground, 15, 5, BRONZE, AMBER)
    ground_glow(f, cx, ground, 10, 3, GOLD, WHITE)
    shaft(f, cx, ground, ground, [(6, AMBER), (5, GOLD), (3, WHITE)], 0.22)
    for gx, gy in glints[:3]:
        glint(f, gx, gy, 3, GOLD, WHITE)
    # f2: it holds; rays strike out along the ground.
    f = sheet.cell(2)
    ground_glow(f, cx, ground, 17, 6, BRONZE)
    ground_glow(f, cx, ground, 11, 4, AMBER, GOLD)
    shaft(f, cx, ground, ground, [(5, GOLD), (2, WHITE)], 0.3, 1)
    for dx, dy in ((-1, 0.3), (1, 0.3), (-1, -0.25), (1, -0.25)):
        plot(f, line(cx + dx * 12, ground + dy * 12, cx + dx * 18, ground + dy * 18), GOLD)
    for gx, gy in glints[1:]:
        glint(f, gx, gy - 2, 2, GOLD, WHITE)
    # f3: narrower; the ring of light opens on the ground.
    f = sheet.cell(3)
    ground_glow(f, cx, ground, 19, 7, AMBER)
    shaft(f, cx, ground, ground * 0.85, [(3, GOLD), (1, WHITE)], 0.4, 2)
    for gx, gy in glints[::2]:
        glint(f, gx, gy + 3, 2, AMBER, GOLD)
    ground_glow(f, cx, ground, 6, 2, GOLD, WHITE)
    # f4: the column breaks into dithered bands from the top; motes fall.
    f = sheet.cell(4)
    shaft(f, cx, ground, ground * 0.5, [(2, GOLD)], 0.8, 1)
    plot(f, dithered(ellipse(cx, ground, 20, 7), 0.6), AMBER)
    for gx, gy in glints:
        f.set(gx, gy + 8, GOLD)
    ground_glow(f, cx, ground, 4, 1, AMBER, GOLD)
    # f5: motes lower, the ring dimming.
    f = sheet.cell(5)
    plot(f, dithered(ellipse(cx, ground, 20, 7), 0.35, 1), BRONZE)
    for gx, gy in glints:
        f.set(gx, min(gy + 14, ground - 2), AMBER)
    # f6: the last motes.
    f = sheet.cell(6)
    for gx, gy in glints[::2]:
        f.set(gx, min(gy + 18, ground - 1), UMBER)
    return sheet


def build_sigil(rng: random.Random) -> Sheet:
    sheet = Sheet(cell=(48, 40), frames=8)
    cx, cy = 24, 30
    outer = ellipse(cx, cy, 20, 8)
    inner = ellipse(cx, cy, 14, 5.5)
    ticks = [(cx + dx, cy + dy) for dx, dy in ((0, -7), (0, 7), (-17, 0), (17, 0), (-12, -5), (12, -5), (-12, 5), (12, 5))]
    feet = [(cx - 16, cy - 4), (cx - 7, cy - 7), (cx + 6, cy - 7), (cx + 16, cy - 4), (cx - 11, cy + 6), (cx + 10, cy + 6)]
    heights = [9, 13, 11, 8, 6, 7]

    def rays(cell, scale, lift, index, top_index):
        for (x, y), h in zip(feet, heights):
            h = max(int(h * scale), 1)
            pixels = line(x, y - lift, x, y - lift - h)
            plot(cell, pixels[:-2], index)
            plot(cell, pixels[-2:], top_index)

    # f0: the ring draws itself (its left half), a flash at the heart.
    f = sheet.cell(0)
    plot(f, [p for p in inner if p[0] <= cx], AMBER)
    glint(f, cx, cy, 1, GOLD, WHITE)
    # f1: both rings, the glint over the middle.
    f = sheet.cell(1)
    plot(f, outer, GOLD)
    plot(f, inner, AMBER)
    plot(f, dithered(ellipse(cx, cy, 21, 9), 0.5), BRONZE)
    glint(f, cx, cy - 12, 3, GOLD, WHITE)
    # f2: the marks between the rings light; the rays start up.
    f = sheet.cell(2)
    plot(f, outer, GOLD)
    plot(f, inner, AMBER)
    for x, y in ticks:
        f.set(x, y, WHITE)
    rays(f, 0.45, 0, GOLD, WHITE)
    glint(f, cx, cy - 13, 2, GOLD, WHITE)
    # f3: the rays at full height, glints on two of them.
    f = sheet.cell(3)
    plot(f, outer, GOLD)
    plot(f, inner, AMBER)
    for x, y in ticks:
        f.set(x, y, GOLD)
    rays(f, 1.0, 0, GOLD, WHITE)
    glint(f, feet[1][0], feet[1][1] - heights[1] - 2, 2, GOLD, WHITE)
    glint(f, feet[3][0], feet[3][1] - heights[3] - 2, 1, GOLD, WHITE)
    # f4: the rays leave the ground and thin; the rings dim.
    f = sheet.cell(4)
    plot(f, outer, AMBER)
    plot(f, dithered(inner, 0.7), AMBER)
    rays(f, 0.7, 4, AMBER, GOLD)
    glint(f, feet[2][0], feet[2][1] - heights[2] - 4, 1, GOLD, WHITE)
    # f5: the ring dithers, motes come down.
    f = sheet.cell(5)
    plot(f, dithered(outer, 0.6), BRONZE)
    plot(f, dithered(inner, 0.35, 1), AMBER)
    for (x, y), h in zip(feet, heights):
        f.set(x, y - h // 2, GOLD if h > 8 else AMBER)
    # f6: little of the ring, motes lower.
    f = sheet.cell(6)
    plot(f, dithered(outer, 0.3, 2), BRONZE)
    for (x, y), h in zip(feet[::2], heights[::2]):
        f.set(x, y - 2, AMBER)
    # f7: the last.
    f = sheet.cell(7)
    plot(f, dithered(outer, 0.12, 3), UMBER)
    return sheet


def build_aegis(rng: random.Random) -> Sheet:
    """A ring of light lying at the feet rises around the body, a cylinder of light behind it,
    and stays over the head as a halo, then sheds motes."""
    sheet = Sheet(cell=(32, 40), frames=7)
    cx, feet = 16, 36
    posts = [5, 9, 23, 27]

    def ring_at(cell, y, rx, ry, index, front=None):
        pts = ellipse(cx, y, rx, ry)
        plot(cell, pts, index)
        if front is not None:
            plot(cell, [(x, py) for x, py in pts if py > y and abs(x - cx) < rx * 0.6], front)

    for frame, (y, rx, ry) in enumerate(((feet, 11, 3.5), (28, 12, 3.5), (18, 12, 3.5), (9, 11, 3.2), (6, 8, 2.4))):
        f = sheet.cell(frame)
        if 1 <= frame <= 3:
            for i, x in enumerate(posts):
                plot(f, dithered(line(x, y + 2, x, feet - 1), 0.75 - frame * 0.15, i), AMBER)
            plot(f, dithered(ellipse(cx, feet, 11, 3.5), 0.6 - frame * 0.15), BRONZE)
        ring_at(f, y, rx, ry, GOLD if frame < 4 else AMBER, WHITE if frame < 4 else GOLD)
        if frame >= 3:
            glint(f, cx + (6 if frame == 3 else -5), y - 3, 2 if frame == 3 else 1, GOLD, WHITE)
    f = sheet.cell(5)
    plot(f, dithered(ellipse(cx, 6, 8, 2.4), 0.5), AMBER)
    for x, y in ((cx - 7, 12), (cx + 5, 15), (cx + 1, 10)):
        f.set(x, y, GOLD)
    f = sheet.cell(6)
    for x, y in ((cx - 7, 18), (cx + 5, 21)):
        f.set(x, y, BRONZE)
    f.set(cx + 1, 15, AMBER)
    return sheet


def main() -> None:
    holy = Element.load("holy")
    rng = random.Random(5)
    sheets = {
        "holy_ray": build_ray(rng),
        "holy_column": build_column(rng),
        "holy_sigil": build_sigil(rng),
        "holy_aegis": build_aegis(rng),
    }
    preview_dir = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
    for name, sheet in sheets.items():
        sheet.save(os.path.join(OUT, name + ".png"), holy)
        if preview_dir:
            os.makedirs(preview_dir, exist_ok=True)
            sheet.preview(os.path.join(preview_dir, name + "_x6.png"), holy, zoom=4 if name == "holy_column" else 6)
        print("wrote", os.path.join("assets", "fx", "holy", name + ".png"))


if __name__ == "__main__":
    main()
