"""The frost kit (docs/vfx.md, "Frost"): draws its sheets on the frost ramp, at the art's own
resolution, with hard alpha. Re-run it to rebuild them after a change:

    python3 tools/vfx/frost.py [--preview DIR]

    assets/fx/frost/frost_shard.png    the shot: 16 directions (rows) x 2 frames, 16x16
    assets/fx/frost/frost_lance.png    the Frost Staff's charged shot, a great shard: 16 directions x 2 frames, 24x24
    assets/fx/frost/frost_impact.png   a shard landing: 6 frames, 32x32
    assets/fx/frost/frost_crystal.png  a nova's piece: 8 frames (grow, hold, crack, shatter) x 3 variants, 16x24
    assets/fx/frost/frost_rime.png     rime on a chilled body's edge: 4 frames (it grows), 8x8

Frost's grammar: angular faceted shards, irregular in size and angle, lit from the top left
(the lit facet takes the ramp's second step, the other its third or fourth), a near-white ridge
or tip, the dark navy edge outlining what is big enough to carry one. Never a radial, symmetric
star: that reads as a shuriken. When it breaks it falls and leaves pale mist (the residue).
"""
import math
import os
import random
import sys

from vfxkit import RESIDUE, ROOT, Element, Sheet, clean, outline, point_in_polygon, rotate

CORE, ICE, STEEL, NAVY, EDGE = 0, 1, 2, 3, 4
LIGHT = (-0.6, -0.8)  # light comes from the top left (unit vector toward it)
OUT = os.path.join(ROOT, "assets", "fx", "frost")


def facet_shade(normal: tuple) -> int:
    """The ramp step of a facet facing `normal` (screen space)."""
    d = normal[0] * LIGHT[0] + normal[1] * LIGHT[1]
    if d > 0.35:
        return ICE
    if d > -0.35:
        return STEEL
    return NAVY


def shard(cell, center, angle, length, width, ridge_glint=0.55, with_outline=True, skew=0.0):
    """A faceted ice shard: a long rhombus split along its ridge into a lit facet and a dark
    one, a bright ridge toward the tip, outlined when it is big enough."""
    tip = length * 0.6
    back = -length * 0.4
    local = [(tip, 0.0), (skew, -width * 0.5), (back, 0.1), (skew * 0.6, width * 0.5)]
    pts = rotate(local, angle, center)
    upper = rotate([(tip, 0.0), (skew, -width * 0.5), (back, 0.1)], angle, center)
    n_up = rotate([(0.0, -1.0)], angle)[0]
    n_down = rotate([(0.0, 1.0)], angle)[0]
    shade_up, shade_down = facet_shade(n_up), facet_shade(n_down)
    if shade_up == shade_down:
        shade_down = min(shade_down + 1, NAVY)
    filled = []
    for y in range(cell.h):
        for x in range(cell.w):
            px, py = x + 0.5, y + 0.5
            if point_in_polygon(px, py, pts):
                cell.set(x, y, shade_up if point_in_polygon(px, py, upper) else shade_down)
                filled.append((x, y))
    # The ridge: from the tip back over `ridge_glint` of the length, in the core color.
    ca, sa = math.cos(angle), math.sin(angle)
    steps = max(int(length * ridge_glint * 2), 1)
    for i in range(steps):
        t = i / (2.0)
        rx = center[0] + (tip - 1.0 - t) * ca
        ry = center[1] + (tip - 1.0 - t) * sa
        if (int(rx), int(ry)) in filled:
            cell.set(int(rx), int(ry), CORE if i < steps * 0.6 else ICE)
    if with_outline and length >= 7:
        edge = [(x, y) for x, y in filled if any(cell.get(x + dx, y + dy) is None for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
        for x, y in edge:
            if cell.get(x, y) != CORE:
                cell.set(x, y, EDGE)
    return filled


def despike(cell, passes=2):
    """Shaves the one-pixel stubs a rasterized shape leaves on its outline (an edge pixel with
    a single opaque neighbour sticking out), which read as little arms."""
    for _ in range(passes):
        for x, y in cell.opaque():
            near = sum(cell.get(x + dx, y + dy) is not None for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            diagonal = sum(cell.get(x + dx, y + dy) is not None for dx, dy in ((1, 1), (-1, -1), (1, -1), (-1, 1)))
            if cell.get(x, y) == EDGE and near <= 1 and diagonal <= 1:
                cell.px[y][x] = None


def diamond(cell, x, y, size, index):
    """A small angular ice chip: one pixel, a 3-pixel wedge, or a slanted 5-pixel sliver,
    turned by where it is (never a plus sign: that is the storm's spark)."""
    turn = (x * 7 + y * 3) % 4
    if size <= 1:
        shape = [(0, 0)]
    elif size == 2:
        shape = [(0, 0), (1, 0), (0, -1)]
    else:
        shape = [(0, 0), (1, 0), (1, -1), (2, -1), (0, 1)]
    for dx, dy in shape:
        for _ in range(turn):
            dx, dy = -dy, dx
        cell.set(x + dx, y + dy, index)


def build_shard() -> Sheet:
    """One faceted shard per direction, rendered (not rotated) so its light stays top-left in
    every direction: a short sharp point and a long tapering tail (the shoulder sits toward the front),
    the lit facet and the shaded one, the dark edge around, a near-white tip and one glint on
    the ridge that slides back on the second frame."""
    sheet = Sheet(cell=(16, 16), frames=2, rows=16)
    for row in range(16):
        angle = row * math.tau / 16
        ca, sa = math.cos(angle), math.sin(angle)
        for frame in range(2):
            cell = sheet.cell(frame, row)
            center = (8.0 + 0.5 * ca, 8.0 + 0.5 * sa)
            shard(cell, center, angle, 14.0, 6.0, ridge_glint=0.0, with_outline=False, skew=1.9)
            outline(cell, EDGE)
            clean(cell)
            despike(cell)
            glint = 2.2 if frame == 0 else 0.2
            for d, index in ((6.4, CORE), (5.4, CORE), (glint + 1.5, CORE)):
                x, y = int(center[0] + d * ca + 0.5), int(center[1] + d * sa + 0.5)
                if cell.get(x, y) is not None:
                    cell.set(x, y, index)
    # Near the vertical, a rasterized shard grows bumps at its shoulders: those rows are the
    # near-horizontal ones mirrored on the diagonal (an exact pixel copy, angle a -> 90 - a,
    # and the top-left light stays top-left).
    for row, source in ((3, 1), (4, 0), (5, 15), (11, 9), (12, 8), (13, 7)):
        for frame in range(2):
            src = sheet.cell(frame, source)
            dst = sheet.cell(frame, row)
            for y in range(16):
                for x in range(16):
                    dst.px[y][x] = src.px[x][y]
    return sheet


def build_lance() -> Sheet:
    """The charged shot: the shard's shape authored bigger (never the shard stretched): a long
    faceted lance with a second, shorter shard riding its flank, a near-white ridge, the dark
    edge around, two glints that slide back along the ridge."""
    sheet = Sheet(cell=(24, 24), frames=2, rows=16)
    for row in range(16):
        angle = row * math.tau / 16
        ca, sa = math.cos(angle), math.sin(angle)
        for frame in range(2):
            cell = sheet.cell(frame, row)
            center = (12.0 + 0.5 * ca, 12.0 + 0.5 * sa)
            shard(cell, center, angle, 21.0, 9.0, ridge_glint=0.0, with_outline=False, skew=3.0)
            # A shorter shard riding its flank, a little behind (irregular, never symmetric).
            side = (center[0] - 3.0 * ca + 2.6 * -sa, center[1] - 3.0 * sa + 2.6 * ca)
            shard(cell, side, angle + 0.18, 11.0, 4.5, ridge_glint=0.0, with_outline=False, skew=1.2)
            outline(cell, EDGE)
            clean(cell)
            despike(cell)
            glints = (9.6, 8.6, 5.0 if frame == 0 else 2.0, 4.0 if frame == 0 else 1.0)
            for d in glints:
                x, y = int(center[0] + d * ca + 0.5), int(center[1] + d * sa + 0.5)
                if cell.get(x, y) is not None:
                    cell.set(x, y, CORE)
    for row, source in ((3, 1), (4, 0), (5, 15), (11, 9), (12, 8), (13, 7)):
        for frame in range(2):
            src = sheet.cell(frame, source)
            dst = sheet.cell(frame, row)
            for y in range(24):
                for x in range(24):
                    dst.px[y][x] = src.px[x][y]
    return sheet


def build_impact(rng: random.Random) -> Sheet:
    sheet = Sheet(cell=(32, 32), frames=6, rows=1)
    c = (16.0, 15.0)
    # Five shards at uneven angles and lengths: biggest first, flying out and breaking.
    angles = [math.radians(a + rng.uniform(-12, 12)) for a in (-105, -38, 18, 88, 158)]
    lengths = [9.0, 11.0, 8.0, 10.0, 7.0]
    # f0: the flash. A compact bright knot and three uneven cracks, no symmetric star.
    f = sheet.cell(0)
    for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1), (-1, 0), (1, -1), (2, 0), (0, 2)):
        f.set(16 + dx, 15 + dy, ICE)
    for dx, dy in ((0, 0), (1, 0), (0, 1)):
        f.set(16 + dx, 15 + dy, CORE)
    for a, n in ((angles[1], 5), (angles[3], 4), (angles[4], 3)):
        for i in range(2, 2 + n):
            f.set(16 + math.cos(a) * i, 15 + math.sin(a) * i, ICE if i < n else STEEL)
    # f1: the burst at its biggest: the shards are out, a cracked heart remains.
    f = sheet.cell(1)
    for a, ln in zip(angles, lengths):
        shard(f, (c[0] + math.cos(a) * 6.5, c[1] + math.sin(a) * 6.5), a, ln, 4.2, skew=rng.uniform(-0.8, 0.8))
    for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
        f.set(16 + dx, 15 + dy, ICE)
    f.set(16, 15, CORE)
    # f2: further out, shorter (their tips broke), the heart gone; the first cold mist.
    f = sheet.cell(2)
    for i, (a, ln) in enumerate(zip(angles, lengths)):
        d = 9.5 + i % 2
        shard(f, (c[0] + math.cos(a) * d, c[1] + math.sin(a) * d + 1), a + rng.uniform(-0.2, 0.2), ln - 3, 3.4, ridge_glint=0.3, with_outline=False)
    for x, y in ((14, 18), (18, 19), (16, 20)):
        f.set(x, y, RESIDUE)
    clean(f)
    # f3: broken into chips, falling; the mist sinks.
    f = sheet.cell(3)
    for i, a in enumerate(angles):
        d = 12.0
        x, y = c[0] + math.cos(a) * d, c[1] + math.sin(a) * d + 2
        diamond(f, int(x), int(y), 2, STEEL if i % 2 else ICE)
        if i % 2 == 0:
            f.set(int(x - math.cos(a) * 3), int(y - math.sin(a) * 3 + 2), NAVY)
    for x, y in ((13, 20), (15, 21), (17, 21), (19, 20), (16, 22)):
        f.set(x, y, RESIDUE)
    # f4: small chips lower, the mist low and spreading.
    f = sheet.cell(4)
    for i, a in enumerate(angles):
        d = 13.5
        f.set(c[0] + math.cos(a) * d, c[1] + math.sin(a) * d + 4.5, NAVY if i % 2 else STEEL)
    for x, y in ((11, 22), (14, 23), (18, 23), (21, 22)):
        f.set(x, y, RESIDUE)
    f.set(16, 23, NAVY)
    # f5: the last few pixels before it lingers out.
    f = sheet.cell(5)
    for i, a in enumerate(angles[::2]):
        f.set(c[0] + math.cos(a) * 14, c[1] + math.sin(a) * 14 + 7, EDGE)
    for x, y in ((10, 24), (20, 24)):
        f.set(x, y, NAVY)
    return sheet


def prism(cell, bx, by, height, width, lean, shown=1.0, glint=None):
    """A crystal standing on (bx, by): a pointed prism leaning by `lean` (pixels per pixel of
    height), its left face lit, its right face in shade, its point near-white; `shown` of its
    height out of the ground (it grows)."""
    h = height * shown
    if h < 1.0:
        return
    hw = width * 0.5
    top = (bx + lean * h, by - h)
    shoulder = 0.78
    pts = [(bx - hw, by), (bx + hw, by), (bx + hw + lean * h * shoulder, by - h * shoulder), top, (bx - hw + lean * h * shoulder, by - h * shoulder)]
    ridge_x = lambda y: bx + lean * (by - y) + hw * 0.15  # noqa: E731 the face split
    for y in range(cell.h):
        for x in range(cell.w):
            px, py = x + 0.5, y + 0.5
            if point_in_polygon(px, py, pts):
                if py < by - h * 0.86:
                    index = CORE if px < ridge_x(py) + 0.5 else ICE
                else:
                    index = ICE if px < ridge_x(py) else STEEL
                cell.set(x, y, index)
    if glint is not None:
        gx, gy = bx + lean * (by - (by - h * glint)) - hw * 0.3, by - h * glint
        cell.set(gx, gy, CORE)


def build_crystal(rng: random.Random) -> Sheet:
    sheet = Sheet(cell=(16, 24), frames=8, rows=3)
    clusters = [
        # (offset, height, width, lean) per prism: main, side, small
        [(0.0, 17, 5.0, 0.12), (-4.0, 10, 4.0, -0.3), (4.5, 6, 3.0, 0.38)],
        [(0.5, 14, 5.0, -0.1), (4.0, 11, 4.0, 0.32), (-4.5, 5, 3.0, -0.4)],
        [(-0.5, 15, 4.6, 0.2), (3.5, 7, 3.6, 0.42), (-3.5, 9, 3.6, -0.26)],
    ]
    growth = [0.22, 0.55, 0.9, 1.0, 1.0]
    for row, cluster in enumerate(clusters):
        base = 22.0
        for frame in range(8):
            cell = sheet.cell(frame, row)
            if frame < 5:
                for i, (dx, h, w, lean) in enumerate(cluster):
                    shown = growth[frame] * (1.0 if i == 0 else min(1.0, growth[frame] * 1.25))
                    prism(cell, 8.0 + dx, base, h, w, lean, shown, glint=(0.7 if frame == 3 else 0.45) if i == 0 and frame >= 3 else None)
                outline(cell, EDGE)
                # The point of each stays bright through the outline.
                for i, (dx, h, w, lean) in enumerate(cluster):
                    shown = growth[frame] * (1.0 if i == 0 else min(1.0, growth[frame] * 1.25))
                    hh = h * shown
                    if hh >= 3:
                        cell.set(8.0 + dx + lean * hh, base - hh + 1.0, CORE)
                if frame == 0:
                    for x in range(4, 13):
                        if cell.get(x, 22) is None and rng.random() < 0.5:
                            cell.set(x, 22, NAVY)  # the ground cracking under it
            elif frame == 5:
                # Cracking: the same cluster, dark cracks across, its point knocked aside.
                for i, (dx, h, w, lean) in enumerate(cluster):
                    prism(cell, 8.0 + dx, base, h, w, lean, 1.0)
                outline(cell, EDGE)
                for i, (dx, h, w, lean) in enumerate(cluster[:2]):
                    y0 = base - h * 0.45
                    for k in range(-2, 3):
                        x = 8.0 + dx + lean * (base - y0) + k
                        if cell.get(int(x), int(y0 - k * 0.6)) is not None:
                            cell.set(x, y0 - k * 0.6, EDGE)
            else:
                # Shattered: stumps, flying fragments, falling chips, the cold mist.
                stump = 0.35 if frame == 6 else 0.12
                for i, (dx, h, w, lean) in enumerate(cluster):
                    prism(cell, 8.0 + dx, base, h * stump, w, lean, 1.0)
                outline(cell, EDGE)
                if frame == 6:
                    for k in range(5):
                        fx = 8 + rng.uniform(-6.5, 6.5)
                        fy = base - rng.uniform(9, 17)
                        diamond(cell, int(fx), int(fy), 2 if k < 3 else 1, ICE if k % 2 == 0 else STEEL)
                    for x, y in ((5, 21), (11, 20), (8, 19)):
                        cell.set(x, y, RESIDUE)
                else:
                    for k in range(4):
                        cell.set(8 + rng.uniform(-7, 7), base - rng.uniform(0, 5), NAVY if k % 2 else STEEL)
                    for x, y in ((3, 22), (6, 21), (10, 22), (13, 21), (8, 20)):
                        cell.set(x, y, RESIDUE)
    return sheet


def build_rime() -> Sheet:
    """Hoarfrost needles on the right edge of a body (mirrored for the left), growing."""
    sheet = Sheet(cell=(8, 8), frames=4, rows=1)
    stages = [
        [((4, 4), STEEL), ((4, 5), NAVY)],
        [((4, 4), ICE), ((5, 3), CORE), ((4, 5), NAVY), ((3, 5), EDGE)],
        [((4, 4), ICE), ((5, 3), ICE), ((6, 2), CORE), ((5, 4), STEEL), ((6, 4), ICE), ((4, 5), NAVY), ((3, 5), EDGE), ((3, 4), NAVY)],
        [((4, 4), ICE), ((5, 3), ICE), ((6, 2), ICE), ((7, 1), CORE), ((5, 4), STEEL), ((6, 4), ICE), ((7, 4), CORE),
         ((4, 3), STEEL), ((4, 2), ICE), ((4, 1), CORE), ((4, 5), NAVY), ((5, 5), NAVY), ((3, 5), EDGE), ((3, 4), NAVY), ((3, 3), EDGE)],
    ]
    for frame, pixels in enumerate(stages):
        cell = sheet.cell(frame)
        for (x, y), index in pixels:
            cell.set(x, y, index)
    return sheet


def main() -> None:
    frost = Element.load("frost")
    rng = random.Random(7)
    sheets = {
        "frost_shard": build_shard(),
        "frost_lance": build_lance(),
        "frost_impact": build_impact(rng),
        "frost_crystal": build_crystal(rng),
        "frost_rime": build_rime(),
    }
    preview_dir = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
    for name, sheet in sheets.items():
        sheet.save(os.path.join(OUT, name + ".png"), frost)
        if preview_dir:
            os.makedirs(preview_dir, exist_ok=True)
            sheet.preview(os.path.join(preview_dir, name + "_x6.png"), frost, zoom=8 if name == "frost_rime" else 6)
        print("wrote", os.path.join("assets", "fx", "frost", name + ".png"))


if __name__ == "__main__":
    main()
