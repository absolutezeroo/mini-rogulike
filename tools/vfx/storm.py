"""The storm kit (docs/vfx.md, "Storm"): electric violet-white lightning drawn on the storm ramp,
at the art's own resolution, hard alpha. Re-run it to rebuild the sheets:

    python3 tools/vfx/storm.py [--preview DIR]

    assets/fx/storm/storm_spark.png   the shot: a crackling knot, arcs flickering, 4 frames 16x16
    assets/fx/storm/storm_impact.png  a spark landing: forks out, off, strike again, 6 frames 32x32
    assets/fx/storm/storm_fork.png    a nova's piece: a crackle on the ground, 7 frames x 3 variants, 24x16
    assets/fx/storm/storm_bolt.png    Thunder's strike from the sky: 7 frames 48x96 (ground at row 88)

Storm's grammar: jagged forks (straight runs and sharp knees, never curves), a near-white
channel with a lavender glow and a violet rim, and flicker: 1-3 frames on, a frame off with only
the afterglow, a second strike, then broken segments dying down the ramp. No round orb, no plus
sign (holy owns the 4-point glint): its small bits are little zigzags.
"""
import os
import random
import sys

from strokes import dithered, jag, path, plot, rim, widen
from vfxkit import ROOT, Element, Sheet

CORE, GLOW, BODY, DEEP, EDGE = 0, 1, 2, 3, 4
OUT = os.path.join(ROOT, "assets", "fx", "storm")


def zigzag(cell, x, y, size, index, turn=0):
    """Storm's bit: a little staircase spark (the FORK bit of PixelDraw)."""
    shape = {1: [(0, 0), (1, 1)], 2: [(0, 0), (1, 0), (1, 1), (2, 1)]}.get(size, [(-1, -1), (0, -1), (0, 0), (1, 0), (1, 1), (2, 1)])
    for dx, dy in shape:
        for _ in range(turn % 4):
            dx, dy = -dy, dx
        cell.set(x + dx, y + dy, index)


def arc(rng, center, angle_deg, length, step=2.5, spread=1.6, start=2.0):
    import math
    a = math.radians(angle_deg)
    s = (center[0] + math.cos(a) * start, center[1] + math.sin(a) * start)
    e = (center[0] + math.cos(a) * length, center[1] + math.sin(a) * length)
    return path(jag(s, e, rng, step, spread))


def knot(cell, cx, cy, big=True):
    """The crackling heart: a 2x2 white core in a lavender cross, outlined."""
    for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
        cell.set(cx + dx, cy + dy, CORE)
    if big:
        for dx, dy in ((-1, 0), (-1, 1), (2, 0), (2, 1), (0, -1), (1, -1), (0, 2), (1, 2)):
            cell.set(cx + dx, cy + dy, GLOW)


def build_spark(rng: random.Random) -> Sheet:
    """The shot: ball lightning. A white knot in a lavender glow, a fuzzy ball of charge whose
    pixels flicker, and two or three arcs leaping off it at uneven angles
    (never evenly spaced: three arms at 120 degrees read as a thrown star). The third frame is
    the flicker: the sphere is gone, one short arc."""
    import math
    sheet = Sheet(cell=(16, 16), frames=4)
    c = 7.5
    for frame in range(4):
        cell = sheet.cell(frame)
        dim = frame == 2
        if not dim:
            # The charge around the knot: a fuzzy ball, a few of its pixels flickering off.
            for dx in range(-2, 4):
                for dy in range(-2, 4):
                    corner = (dx in (-2, 3)) and (dy in (-2, 3))
                    if not corner and rng.random() < 0.85:
                        cell.set(7 + dx, 7 + dy, BODY)
        knot(cell, 7, 7, big=not dim)
        base = rng.uniform(0, 360)
        turns = [0.0, rng.uniform(110, 160)]
        turns.append(turns[1] + rng.uniform(80, 120))
        for i in range(1 if dim else (3 if frame == 0 else 2)):
            px = arc(rng, (7.5, 7.5), base + turns[i], (rng.uniform(6.8, 7.5) if i == 0 else (6.0 if i == 1 else 4.6)) if not dim else 4.5, step=2.0, spread=2.2, start=3.0)
            plot(cell, px[:-1], GLOW if not dim else BODY)
            plot(cell, px[-1:], CORE if not dim else DEEP)
        rim(cell, DEEP if not dim else EDGE)
    return sheet


def build_impact(rng: random.Random) -> Sheet:
    import math
    sheet = Sheet(cell=(32, 32), frames=6)
    c = (15.5, 15.5)
    angles = [a + rng.uniform(-18, 18) for a in (-100, -30, 35, 105, 170)]
    forks = [arc(rng, c, a, rng.uniform(10.0, 13.5), step=3.0, spread=2.2) for a in angles]
    # f0: the flash: a big knot, short stubs of the forks.
    f = sheet.cell(0)
    knot(f, 15, 15)
    for px in forks:
        plot(f, px[:3], GLOW, only_empty=True)
    rim(f, DEEP)
    # f1: the forks at full reach, white channels in a lavender glow, a branch off two of them.
    f = sheet.cell(1)
    knot(f, 15, 15)
    for i, px in enumerate(forks):
        plot(f, px, CORE if i % 2 == 0 else GLOW, only_empty=True)
        if i in (1, 3):
            k = px[len(px) // 2]
            a = math.radians(angles[i] + (35 if i == 1 else -35))
            branch = path(jag(k, (k[0] + math.cos(a) * 5, k[1] + math.sin(a) * 5), rng, 2.5, 1.2))
            plot(f, branch, BODY, only_empty=True)
    widen(f, [p for px in forks for p in px[:len(px) // 3]], GLOW, True, False)
    rim(f, DEEP)
    # f2: off. Only the afterglow of the channels, dithered, and a dim heart.
    f = sheet.cell(2)
    for px in forks:
        plot(f, dithered(px, 0.55, 1), DEEP)
    for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
        f.set(15 + dx, 15 + dy, BODY)
    # f3: the second strike: three of the forks again, thinner, no glow around them.
    f = sheet.cell(3)
    for px in forks[::2]:
        plot(f, px[: max(len(px) - 2, 3)], GLOW)
        plot(f, px[max(len(px) - 2, 3):], BODY)
    for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
        f.set(15 + dx, 15 + dy, CORE)
    rim(f, EDGE)
    # f4: broken: the tips of the forks, going dark.
    f = sheet.cell(4)
    for i, px in enumerate(forks):
        plot(f, px[-4:-1], BODY if i % 2 else DEEP)
    # f5: a few little zigzags flung out, the last of it.
    f = sheet.cell(5)
    for i, px in enumerate(forks[1::2] + forks[:1]):
        x, y = px[-1]
        zigzag(f, x, y, 1, DEEP if i else EDGE, turn=i)
    return sheet


def build_fork(rng: random.Random) -> Sheet:
    """A crackle on the ground (one piece of a storm nova): a jagged arc lying along the floor,
    a branch, a spark jumping up from it; it strikes, goes off, strikes again and breaks up."""
    sheet = Sheet(cell=(24, 16), frames=7, rows=3)
    for row in range(3):
        y0, y1 = 10 + rng.choice((-2, -1, 1)), 10 + rng.choice((-1, 1, 2))
        # A random walk of uneven runs (flat, rising, falling; a sharp drop now and then):
        # lightning, not a regular zigzag.
        main, x, y = [], 2, y0
        while x <= 21:
            run = rng.randint(2, 5)
            slope = rng.choice((0, 0, 1, -1, 1, -1, 2, -2))
            for _ in range(run):
                if x > 21:
                    break
                main.append((x, y))
                x += 1
                if slope and 6 <= y + (1 if slope > 0 else -1) <= 13:
                    y += 1 if slope > 0 else -1
                    if abs(slope) == 2:
                        main.append((x - 1, y))
        k = main[len(main) // 2 + rng.choice((-3, 2))]
        up = path(jag(k, (k[0] + rng.uniform(-2, 2), k[1] - rng.uniform(3, 5)), rng, 2.5, 1.2)) if row != 2 else [k]
        bk = main[len(main) // 4 if row != 1 else 3 * len(main) // 4]
        branch = path(jag(bk, (bk[0] + rng.choice((-1, 1)) * 4, bk[1] + 4), rng, 2.0, 1.0))
        mid = len(main) // 2
        # f0: it runs out from the middle.
        f = sheet.cell(0, row)
        plot(f, main[mid - 4: mid + 4], GLOW)
        f.set(*main[mid], CORE)
        rim(f, DEEP)
        # f1: the strike: white channel, lavender glow above and below, a spark jumping up.
        f = sheet.cell(1, row)
        plot(f, main, CORE)
        plot(f, up, GLOW)
        plot(f, branch, BODY, only_empty=True)
        widen(f, main[mid - 3: mid + 4], GLOW, False, True)
        rim(f, DEEP)
        # f2: off, the afterglow.
        f = sheet.cell(2, row)
        plot(f, dithered(main, 0.5, row), DEEP)
        # f3: strikes again, thinner.
        f = sheet.cell(3, row)
        plot(f, main, GLOW)
        plot(f, up[: len(up) // 2], BODY, only_empty=True)
        for p in main[2::6]:
            f.set(*p, CORE)
        rim(f, EDGE)
        # f4: broken into segments.
        f = sheet.cell(4, row)
        for i in range(0, len(main), 5):
            plot(f, main[i:i + 3], BODY if i % 10 == 0 else DEEP)
        # f5: little zigzags, a little up.
        f = sheet.cell(5, row)
        for i, p in enumerate(main[3::7]):
            zigzag(f, p[0], p[1] - 2, 1 if i % 2 else 2, DEEP, turn=i + row)
        # f6: two dark pixels.
        f = sheet.cell(6, row)
        for p in main[5::9][:2]:
            f.set(p[0], p[1] - 3, EDGE)
    return sheet


def build_bolt(rng: random.Random) -> Sheet:
    """Thunder: a bolt from the sky onto row 88 (where the spell lands): a leader feels its way
    down, the strike (a white channel three pixels wide in its glow, branches, a splash of
    crackles on the ground), a frame off, a second strike, then the channel breaks and dies."""
    import math
    sheet = Sheet(cell=(48, 96), frames=7)
    ground = (24, 88)
    knees = [(24 + rng.uniform(-5, 5), 0)]
    y = 0.0
    x = knees[0][0]
    while y < 80:
        y += rng.uniform(7, 12)
        x = max(10, min(38, x + rng.choice((-1, 1)) * rng.uniform(2.5, 5.5)))
        knees.append((x, min(y, 82)))
    knees.append(ground)
    main = path(knees)
    branches = []
    for at, side, ln in ((0.35, -1, 16), (0.58, 1, 13), (0.74, -1, 10)):
        k = main[int(len(main) * at)]
        a = math.radians(90 + side * rng.uniform(35, 55))
        end = (k[0] + math.cos(a) * ln, k[1] + math.sin(a) * ln)
        branches.append(path(jag(k, end, rng, 3.5, 2.0)))
    splash = []
    for a in (180 + rng.uniform(-8, 8), 205, 335, rng.uniform(-8, 8), 160, 20):
        r = math.radians(a)
        end = (ground[0] + math.cos(r) * rng.uniform(9, 14), ground[1] + math.sin(r) * rng.uniform(3, 5))
        splash.append(path(jag(ground, end, rng, 3.0, 1.2)))
    # f0: the leader, half way down, dim and thin; a streamer rises from the ground to meet it.
    f = sheet.cell(0)
    plot(f, main[: int(len(main) * 0.55)], BODY)
    plot(f, branches[0][: len(branches[0]) // 2], DEEP, only_empty=True)
    plot(f, main[-5:], DEEP)
    # f1: the strike.
    f = sheet.cell(1)
    plot(f, main, CORE)
    widen(f, main, GLOW)
    for b in branches:
        plot(f, b[:-2], GLOW, only_empty=True)
        plot(f, b[-2:], BODY, only_empty=True)
    for s in splash:
        plot(f, s, GLOW, only_empty=True)
    for dx in range(-3, 4):
        f.set(ground[0] + dx, ground[1], CORE)
    for dx in range(-2, 3):
        f.set(ground[0] + dx, ground[1] - 1, CORE)
        f.set(ground[0] + dx, ground[1] + 1, GLOW)
    rim(f, DEEP)
    # f2: off: the channel's afterglow, the ground still bright.
    f = sheet.cell(2)
    plot(f, dithered(main, 0.5), DEEP)
    for s in splash[:3]:
        plot(f, s[:4], BODY)
    for dx in range(-2, 3):
        f.set(ground[0] + dx, ground[1], GLOW)
    # f3: the second strike, thinner, one branch.
    f = sheet.cell(3)
    plot(f, main, CORE)
    widen(f, main[len(main) // 2:], GLOW)
    plot(f, branches[1], BODY, only_empty=True)
    for s in splash[::2]:
        plot(f, s, BODY, only_empty=True)
    for dx in range(-2, 3):
        f.set(ground[0] + dx, ground[1], CORE)
    rim(f, EDGE)
    # f4: the channel breaks from the top down.
    f = sheet.cell(4)
    lower = main[len(main) // 3:]
    for i in range(0, len(lower), 7):
        plot(f, lower[i:i + 4], GLOW if i > len(lower) * 0.6 else BODY)
    for s in splash:
        plot(f, s[2:], DEEP)
    f.set(*ground, GLOW)
    # f5: low segments and crackles on the ground.
    f = sheet.cell(5)
    low = main[int(len(main) * 0.7):]
    for i in range(0, len(low), 6):
        plot(f, low[i:i + 2], DEEP)
    for i, s in enumerate(splash):
        x, y = s[-1]
        zigzag(f, x, y, 2 if i < 2 else 1, BODY if i % 2 else DEEP, turn=i)
    # f6: the last sparks.
    f = sheet.cell(6)
    for i, s in enumerate(splash[::2]):
        x, y = s[-1]
        zigzag(f, x + (1 if i % 2 else -1), y - 1, 1, EDGE if i else DEEP, turn=i + 1)
    return sheet


def main() -> None:
    storm = Element.load("storm")
    rng = random.Random(11)
    sheets = {
        "storm_spark": build_spark(rng),
        "storm_impact": build_impact(rng),
        "storm_fork": build_fork(rng),
        "storm_bolt": build_bolt(rng),
    }
    preview_dir = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
    for name, sheet in sheets.items():
        sheet.save(os.path.join(OUT, name + ".png"), storm)
        if preview_dir:
            os.makedirs(preview_dir, exist_ok=True)
            sheet.preview(os.path.join(preview_dir, name + "_x6.png"), storm, zoom=4 if name == "storm_bolt" else 6)
        print("wrote", os.path.join("assets", "fx", "storm", name + ".png"))


if __name__ == "__main__":
    main()
