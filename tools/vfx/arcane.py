"""The arcane kit (docs/vfx.md, "Arcane"): bright magenta sorcery drawn on the arcane ramp, at
the art's own resolution, hard alpha. Re-run it to rebuild the sheets:

    python3 tools/vfx/arcane.py [--preview DIR]

    assets/fx/arcane/arcane_missile.png  the shot (Arcane Bolt, the Arcane synergy's ring): a diamond glint, three motes orbiting it, 8 frames 16x16
    assets/fx/arcane/arcane_impact.png   a missile landing: a ring of rune-diamonds turning outward, 6 frames 32x32
    assets/fx/arcane/arcane_rune.png     a nova's piece: a glyph lighting up over the ground and fading, 6 frames x 3 variants, 12x16 (ground at row 14)

Arcane's grammar: orbits, runes and the diamond glint (a rhombus, hollow or filled: holy owns
the 4-point glint). The motes go round on a tilted orbit, the ones behind in the ramp's dark
steps; the core is near-white pink.
"""
import math
import os
import sys

from strokes import diamond, dithered, ellipse, plot
from vfxkit import ROOT, Element, Sheet

CORE, PINK, ORCHID, PLUM, NIGHT = 0, 1, 2, 3, 4
OUT = os.path.join(ROOT, "assets", "fx", "arcane")

GLYPHS = [
    # Three little runes, 5 wide x 7 tall, as strokes of pixels.
    [(2, 0), (2, 1), (2, 2), (2, 3), (2, 4), (2, 5), (2, 6), (1, 1), (0, 2), (3, 1), (4, 2), (1, 4), (3, 4)],
    [(0, 0), (0, 1), (0, 2), (0, 3), (0, 4), (0, 5), (0, 6), (1, 1), (2, 2), (3, 3), (2, 4), (1, 5), (4, 0), (4, 6)],
    [(2, 0), (1, 1), (3, 1), (0, 2), (4, 2), (2, 2), (2, 3), (2, 4), (1, 5), (3, 5), (0, 6), (4, 6)],
]


def orbit_point(c, angle, rx=6.2, ry=3.4, tilt=-0.45):
    x, y = math.cos(angle) * rx, math.sin(angle) * ry
    ct, st = math.cos(tilt), math.sin(tilt)
    return c + x * ct - y * st, c + x * st + y * ct, math.sin(angle)


def build_missile() -> Sheet:
    sheet = Sheet(cell=(16, 16), frames=8)
    c = 7.5
    for frame in range(8):
        cell = sheet.cell(frame)
        base = frame * math.radians(15)
        motes = []
        for k in range(3):
            a = base + k * math.tau / 3
            motes.append([orbit_point(c, a - math.radians(28) * j) for j in range(3)])
        # Behind the core first (darker), then the core, then the motes in front.
        for mote in motes:
            if mote[0][2] < 0:
                for j, (x, y, _) in enumerate(mote[:2]):
                    cell.set(math.floor(x + 0.5), math.floor(y + 0.5), PLUM if j == 0 else NIGHT)
        diamond(cell, 7, 7, 3, PLUM)
        diamond(cell, 7, 7, 2, PINK, CORE if frame % 4 < 2 else PINK)
        cell.set(7, 7, CORE)
        if frame % 4 >= 2:
            for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0)):
                cell.set(7 + dx, 7 + dy, CORE)
        for mote in motes:
            if mote[0][2] >= 0:
                for j, (x, y, _) in reversed(list(enumerate(mote))):
                    cell.set(math.floor(x + 0.5), math.floor(y + 0.5), (CORE, PINK, ORCHID)[j])
    return sheet


def build_impact() -> Sheet:
    sheet = Sheet(cell=(32, 32), frames=6)
    c = 15
    # f0: the diamond bursts (a filled rhombus with a hollow one around it, never a plus).
    f = sheet.cell(0)
    diamond(f, c, c, 6, ORCHID)
    diamond(f, c, c, 4, PLUM)
    diamond(f, c, c, 3, PINK, CORE)
    # f1-f4: six rune-diamonds on a tilted ring, turning outward and dimming.
    for frame, (r, turn, size, edge, fill) in enumerate(((8, 0.0, 2, PINK, None), (10.5, 0.35, 2, PINK, None), (12, 0.6, 1, ORCHID, None), (13, 0.8, 1, PLUM, None)), start=1):
        f = sheet.cell(frame)
        if frame <= 2:
            plot(f, dithered(ellipse(c, c, r - 3, (r - 3) * 0.75), 0.5 if frame == 1 else 0.3), ORCHID)
        for k in range(6):
            a = turn + k * math.tau / 6
            x, y = c + math.cos(a) * r, c + math.sin(a) * r * 0.75
            diamond(f, x, y, size, edge, fill)
            if frame == 1:
                f.set(round(x), round(y), CORE)
        if frame == 1:
            diamond(f, c, c, 1, PINK, CORE)
    # f5: the last of the runes.
    f = sheet.cell(5)
    for k in range(0, 6, 2):
        a = 1.0 + k * math.tau / 6
        f.set(c + math.cos(a) * 13.5, c + math.sin(a) * 10, NIGHT)
    return sheet


def build_rune() -> Sheet:
    sheet = Sheet(cell=(12, 16), frames=6, rows=3)
    for row, glyph in enumerate(GLYPHS):
        for frame, (lift, index, rim) in enumerate(((0, PLUM, None), (1, PINK, NIGHT), (2, PINK, PLUM), (3, ORCHID, None), (4, PLUM, None))):
            f = sheet.cell(frame, row)
            ox, oy = 3, 7 - lift
            pts = [(ox + x, oy + y) for x, y in glyph]
            if frame == 4:
                pts = dithered(pts, 0.55, row)
            if rim is not None:
                for x, y in pts:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        if (x + dx, y + dy) not in pts:
                            f.set(x + dx, y + dy, rim)
            plot(f, pts, index)
            if frame in (1, 2):
                f.set(ox + glyph[0][0], oy + glyph[0][1], CORE)
                diamond(f, ox + 2, oy - 3, 1, PINK if frame == 1 else ORCHID, CORE if frame == 1 else None)
            # Its shadow of light on the ground.
            if frame <= 3:
                plot(f, [(x, 14) for x in range(4, 8)], PLUM if frame else NIGHT)
        f = sheet.cell(5, row)
        f.set(5, 5 - row % 2, PLUM)
        f.set(6, 14, NIGHT)
    return sheet


def main() -> None:
    arcane = Element.load("arcane")
    sheets = {
        "arcane_missile": build_missile(),
        "arcane_impact": build_impact(),
        "arcane_rune": build_rune(),
    }
    preview_dir = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
    for name, sheet in sheets.items():
        sheet.save(os.path.join(OUT, name + ".png"), arcane)
        if preview_dir:
            os.makedirs(preview_dir, exist_ok=True)
            sheet.preview(os.path.join(preview_dir, name + "_x6.png"), arcane, zoom=6)
        print("wrote", os.path.join("assets", "fx", "arcane", name + ".png"))


if __name__ == "__main__":
    main()
