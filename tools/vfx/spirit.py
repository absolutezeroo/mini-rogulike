"""The spirit kit (docs/vfx.md, "Spirit"): draws its sheets on the spirit ramp, at the art's own
resolution, with hard alpha. Re-run it to rebuild them after a change:

    python3 tools/vfx/spirit.py [--preview DIR]

    assets/fx/spirit/spirit_wisp.png   the shot: a wisp, 16 directions (rows) x 4 frames, 16x16
    assets/fx/spirit/spirit_ring.png   a wisp landing: a hollow ring, wisps rising, 6 frames, 32x32
    assets/fx/spirit/spirit_flame.png  a nova's piece: a pale flame curling up, 8 frames x 3 variants, 12x20
    assets/fx/spirit/spirit_claw.png   a spectre's touch: hollow claws, 16 directions x 5 frames, 24x24
    assets/fx/spirit/spirit_mote.png   a pale flame lick on a wailed body: 6 frames, 8x10

Spirit's grammar: hollow and curling. Rings with nothing inside, strokes drawn as two edges
with the middle empty, pale flames that curl up and come apart into motes, tails that waver.
The near-white core only at a wisp's heart and a flame's foot; the mint for what still burns;
the teal and the dark sea-green for its edge and for what is going.
"""
import math
import os
import random
import sys

from liquid import disc, lit, ring, to_world, tube
from vfxkit import ROOT, Element, Sheet, clean, outline

CORE, PALE, MINT, TEAL, EDGE = 0, 1, 2, 3, 4
OUT = os.path.join(ROOT, "assets", "fx", "spirit")


def build_wisp() -> Sheet:
    """A wisp in each direction: a round pale head with a white heart, a long tail that
    streams behind it and waves (its wave travels over the four frames), the tail's end coming
    apart into motes; the dark edge around the head and the start of the tail (an enemy shot
    reads on any floor)."""
    sheet = Sheet(cell=(16, 16), frames=4, rows=16)
    for row in range(16):
        angle = row * math.tau / 16
        for frame in range(4):
            cell = sheet.cell(frame, row)
            c = (8.0, 8.0)
            phase = frame * math.pi / 2
            points, widths = [], []
            length = 8.5
            steps = 16
            for i in range(steps + 1):
                s = length * i / steps
                v = 0.32 * s * math.sin(s * 0.95 - phase)
                points.append(to_world(angle, 3.0 - s, v, c))
                widths.append(2.9 * (1.0 - i / steps) ** 1.3 + 0.3)
            body = tube(cell, points, widths, lambda n, s: PALE if s < 0.25 else (MINT if s < 0.6 else TEAL))
            outline(cell, EDGE)
            # The far tail stays soft (no outline): it is coming apart.
            for (x, y), s in body.items():
                if s > 0.55 and cell.get(x, y) == EDGE:
                    cell.set(x, y, TEAL)
            clean(cell)
            hx, hy = to_world(angle, 3.0, 0.0, c)
            disc(cell, hx - 0.3, hy - 0.3, 1.3, CORE)
            # Motes shed off the tail's end, flickering.
            for k, (s, v) in enumerate(((10.5, 1.2), (12.0, -1.0))):
                if (frame + k) % 2 == 0:
                    x, y = to_world(angle, 3.0 - s, v * math.sin(phase + k), c)
                    cell.set(x, y, MINT if k == 0 else TEAL)
    return sheet


def build_ring(rng: random.Random) -> Sheet:
    """A wisp breaking: a white knot, a hollow ring that widens and breaks up going down the
    ramp, and three small flames that rise from it, curling, and thin to motes."""
    sheet = Sheet(cell=(32, 32), frames=6, rows=1)
    cx, cy = 16.0, 17.0
    radii = [0, 4.5, 7.5, 10.0, 12.0, 13.0]
    shades = [CORE, PALE, MINT, TEAL, EDGE, EDGE]
    gaps = [None, None, 0.0, 0.25, 0.45, 0.65]
    starts = [-2.2, -0.9, 0.4]  # where the rising flames leave the ring (angles)
    for frame in range(6):
        f = sheet.cell(frame)
        if frame == 0:
            disc(f, cx, cy, 2.2, PALE)
            disc(f, cx - 0.3, cy - 0.3, 1.2, CORE)
            continue
        cut = gaps[frame]
        keep = None if cut is None else (lambda a, cut=cut, frame=frame: (math.sin(a * 5 + frame) + 1) / 2 > cut)
        ring(f, cx, cy, radii[frame], shades[frame], 2.0 if frame <= 2 else 1.0, keep)
        if frame == 1:
            f.set(cx, cy, CORE)
        if frame >= 2:
            for k, a in enumerate(starts):
                up = (frame - 1) * 3.0
                x0 = cx + math.cos(a) * radii[2]
                y0 = cy + math.sin(a) * radii[2] - up
                curl = math.sin(frame * 1.3 + k * 2.0) * 1.2
                length = 3 if frame <= 3 else (2 if frame == 4 else 1)
                for i in range(length):
                    index = (PALE if i == 0 else MINT) if frame <= 3 else (MINT if frame == 4 else TEAL)
                    f.set(x0 + curl * (i / 2.0), y0 - i, index)
    return sheet


def flame(cell, bx: float, by: float, height: float, width: float, curl: float, phase: float, fade_top: bool = False) -> None:
    """A pale flame standing on (bx, by): a tongue whose middle line curls side to side,
    narrowing to a point; white at its foot, mint up its body, teal at its tip and its edge."""
    if height < 1.0:
        return
    points, widths = [], []
    steps = 12
    for i in range(steps + 1):
        t = i / steps
        y = by - height * t
        x = bx + curl * math.sin(t * 4.2 + phase) * t  # an S: it curls one way, then back
        points.append((x, y))
        widths.append(max(width * (1.0 - t) ** 1.1, 0.5))

    def shade(normal, s):
        d = lit(normal)
        if s < 0.12 and d > -0.3:
            return CORE  # only its foot is white-hot
        if d < -0.45:
            return TEAL if s > 0.35 else MINT  # its shaded edge, darker up the tongue
        if s < 0.4 and d > 0.1:
            return PALE
        return MINT if not fade_top or s < 0.75 else TEAL

    tube(cell, points, widths, shade)


def build_flame(rng: random.Random) -> Sheet:
    """A pale flame curling up out of the ground, its top coming loose as a mote that rises
    while the flame sinks back, the last motes going down the ramp. Its foot sits on the
    bottom rows (anchor)."""
    sheet = Sheet(cell=(12, 20), frames=8, rows=3)
    base = 18.5
    heights = [2.5, 6.5, 10.5, 11.0, 8.5, 5.5, 3.0, 0.0]
    for row in range(3):
        curl = (2.6, -2.8, 2.2)[row]
        phase = rng.uniform(-0.6, 0.6)
        for frame in range(8):
            cell = sheet.cell(frame, row)
            h = heights[frame]
            # No dark outline: a pale flame's edge is its own teal shade (spirit is the pale one).
            flame(cell, 6.0, base, h, 2.1 if frame < 5 else 1.5, curl, phase + frame * 0.9, fade_top=frame >= 4)
            if h > 0:
                clean(cell)
            # The loose tops: motes rising, curling, going down the ramp.
            if frame >= 3:
                for k in range(2 if frame < 7 else 1):
                    rise = (frame - 2) * 2.6 + k * 2.0
                    y = base - 12.0 - rise + 3.0
                    if y < 0:
                        continue
                    x = 6.0 + curl * 0.8 + math.sin(frame * 1.1 + k * 2.4) * 1.5
                    index = PALE if frame <= 4 else (MINT if frame <= 5 else TEAL)
                    cell.set(x, y, index)
                    if frame <= 4 and k == 0:
                        cell.set(x, y + 1, MINT)
    return sheet


def build_claw() -> Sheet:
    """A spectre's touch in each direction: three claws raking across the front, each one
    a thin pale stroke with its ghost a step behind dithered in the dark teal (the hollow,
    doubled look of a spectre), and small flames rising off their ends as they fade."""
    sheet = Sheet(cell=(24, 24), frames=5, rows=16)
    c = (12.0, 12.0)
    offsets = (-6.0, -1.5, 3.0)
    shown = [(0.0, 0.5), (0.0, 1.0), (0.3, 1.0), (0.65, 1.0)]

    def gash(angle, u0, t0, t1, shift=0.0):
        points = []
        for i in range(49):
            t = t0 + (t1 - t0) * i / 48
            points.append((u0 + 4.5 * t - 1.6 * math.sin(math.pi * t) - shift, -9.0 + 18.0 * t, t))
        return points

    for row in range(16):
        angle = row * math.tau / 16
        for frame in range(5):
            cell = sheet.cell(frame, row)
            if frame < 4:
                t0, t1 = shown[frame]
                # The ghost of each claw a step behind it (frames 1-2), every other pixel.
                if 1 <= frame <= 2:
                    for u0 in offsets:
                        for u, v, t in gash(angle, u0, t0, t1, shift=2.0):
                            x, y = to_world(angle, u, v, c)
                            if (int(x) + int(y)) % 2 == 0 and cell.get(int(x), int(y)) is None:
                                cell.set(x, y, TEAL)
                # The claws: thin pale strokes, white at the fresh end, thinning to mint.
                for k, u0 in enumerate(offsets):
                    for u, v, t in gash(angle, u0, t0, t1):
                        fresh = frame <= 1 and t > t1 - 0.3
                        index = CORE if fresh else (PALE if frame <= 1 else (MINT if frame == 2 else TEAL))
                        x, y = to_world(angle, u, v, c)
                        cell.set(x, y, index)
                        if frame <= 1 and 0.3 < t < 0.75:
                            x2, y2 = to_world(angle, u + 0.9, v, c)
                            if cell.get(int(x2), int(y2)) is None:
                                cell.set(x2, y2, MINT)  # its middle a pixel thicker
            # Flames rising off the claws' ends as they fade.
            if frame >= 2:
                for k, u0 in enumerate(offsets):
                    if (k + frame) % 2:
                        continue
                    x, y = to_world(angle, u0 + 4.5, 9.0, c)
                    up = (frame - 1) * 2.5
                    index = PALE if frame == 2 else (MINT if frame == 3 else TEAL)
                    cell.set(x, y - up, index)
                    if frame <= 3:
                        cell.set(x + (1 if k else -1), y - up - 1, MINT)
    return sheet


def build_mote() -> Sheet:
    """A pale flame lick rising off a wailed body: a spark, a small flame curling, coming loose,
    a mote going down the ramp."""
    sheet = Sheet(cell=(8, 10), frames=6, rows=1)
    sheet.cell(0).set(4, 7, PALE)
    for x, y, index in ((4, 7, CORE), (4, 6, PALE), (3, 5, MINT)):
        sheet.cell(1).set(x, y, index)
    for x, y, index in ((3, 7, PALE), (4, 7, CORE), (4, 6, PALE), (3, 6, PALE), (4, 5, MINT), (5, 4, MINT), (3, 8, TEAL), (4, 8, TEAL)):
        sheet.cell(2).set(x, y, index)
    for x, y, index in ((4, 6, PALE), (3, 6, MINT), (4, 5, PALE), (5, 4, MINT), (5, 3, TEAL), (4, 7, TEAL)):
        sheet.cell(3).set(x, y, index)
    for x, y, index in ((5, 3, MINT), (5, 2, TEAL), (3, 6, TEAL)):
        sheet.cell(4).set(x, y, index)
    sheet.cell(5).set(4, 1, TEAL)
    return sheet


def main() -> None:
    spirit = Element.load("spirit")
    rng = random.Random(3)
    sheets = {
        "spirit_wisp": build_wisp(),
        "spirit_ring": build_ring(rng),
        "spirit_flame": build_flame(rng),
        "spirit_claw": build_claw(),
        "spirit_mote": build_mote(),
    }
    preview_dir = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
    for name, sheet in sheets.items():
        sheet.save(os.path.join(OUT, name + ".png"), spirit)
        if preview_dir:
            os.makedirs(preview_dir, exist_ok=True)
            sheet.preview(os.path.join(preview_dir, name + "_x6.png"), spirit)
        print("wrote", os.path.join("assets", "fx", "spirit", name + ".png"))


if __name__ == "__main__":
    main()
