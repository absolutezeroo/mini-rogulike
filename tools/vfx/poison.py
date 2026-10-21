"""The poison kit (docs/vfx.md, "Poison"): draws its sheets on the poison ramp, at the art's own
resolution, with hard alpha. Re-run it to rebuild them after a change:

    python3 tools/vfx/poison.py [--preview DIR]

    assets/fx/poison/poison_glob.png    the shot: a glob of venom, 16 directions (rows) x 3 frames, 16x16
    assets/fx/poison/poison_splash.png  a glob landing: 7 frames, 32x32
    assets/fx/poison/poison_cloud.png   a nova's piece: a lump of gas, 8 frames x 3 variants, 20x16
    assets/fx/poison/poison_fang.png    a venomous bite: 16 directions x 5 frames, 24x24
    assets/fx/poison/poison_bubble.png  a bubble on a poisoned body: 6 frames, 8x8

Poison's grammar: wet and round, never faceted. A glob is heavy at the front, its tail sags
and drips; it lands in a splash of droplets that fall, a sickly cloud that sinks and crawls,
bubbles that swell and pop, and a puddle. Lit from the top left: the acid green on the lit
side, the deep green in shade, the dark violet edge outlining it on bright floors, the pale
yellow-green core only for the shine.
"""
import math
import os
import random
import sys

from liquid import bezier, bubble, disc, drop, lit, lumps, pop, to_world, tube
from vfxkit import RESIDUE, ROOT, Element, Sheet, clean, outline

CORE, ACID, GREEN, DEEP, EDGE = 0, 1, 2, 3, 4
OUT = os.path.join(ROOT, "assets", "fx", "poison")


def wet(normal: tuple, s: float = 0.0) -> int:
    """The ramp step of a wet round surface facing `normal`: the acid green wherever the light
    reaches (venom glows), the green turning away, the deep green in shade."""
    d = lit(normal)
    if d > -0.15:
        return ACID
    if d > -0.65:
        return GREEN
    return DEEP


def gas(normal: tuple, depth: float, top: float) -> int:
    """The ramp step of a pixel of venomous gas: murky (the residue) through its body, green
    only where the light catches the top of a lump, deep green and the dark edge underneath
    where it sags. A cloud, not a bush: most of it is the residue."""
    d = lit(normal)
    if d > 0.55 and top < 0.4 and depth < 1.6:
        return GREEN
    if d < -0.35 and depth < 1.2:
        return EDGE if top > 0.75 else DEEP
    if top > 0.7:
        return DEEP
    return RESIDUE


def droplet(cell, x: float, y: float, size: int) -> None:
    """A drop of venom flung behind a glob: 2x2 lit at its top left with a dark foot, or one
    pixel over its dark edge."""
    x, y = int(round(x - 0.5)), int(round(y - 0.5))
    if size >= 2:
        for dx, dy, index in ((0, 0, ACID), (1, 0, GREEN), (0, 1, GREEN), (1, 1, DEEP)):
            cell.set(x + dx, y + dy, index)
        cell.set(x + 1, y + 2, EDGE)
        cell.set(x, y + 2, EDGE)
    else:
        cell.set(x, y, ACID)
        cell.set(x, y + 1, EDGE)


def build_glob() -> Sheet:
    """A glob of venom in each direction: a round, heavy head, a stubby tail, and two drops
    flung behind it that sag under their weight (down on screen, whatever the direction); the
    dark edge around, a wet shine on the head's top left. Three frames: the head wobbles, the
    drops trail and the farther one falls away."""
    sheet = Sheet(cell=(16, 16), frames=3, rows=16)
    for row in range(16):
        angle = row * math.tau / 16
        fwd = (math.cos(angle), math.sin(angle))
        for frame in range(3):
            cell = sheet.cell(frame, row)
            c = (8.0, 8.0)
            head_r = (4.1, 3.8, 4.2)[frame]
            length = (3.6, 4.2, 3.2)[frame]
            head = (c[0] + fwd[0] * 2.4, c[1] + fwd[1] * 2.4)
            points, widths = [], []
            steps = 10
            for i in range(steps + 1):
                s = length * i / steps
                points.append((head[0] - fwd[0] * s, head[1] - fwd[1] * s + 0.08 * s * s))
                widths.append(head_r * (1.0 - i / steps) ** 0.6 + 0.4)
            tube(cell, points, widths, wet)
            outline(cell, EDGE)
            clean(cell)
            # The wet shine: three pixels on the head's top left.
            sx, sy = int(head[0] - 1.9), int(head[1] - 1.9)
            for x, y in ((sx, sy), (sx + 1, sy), (sx, sy + 1)):
                if cell.get(x, y) not in (None, EDGE):
                    cell.set(x, y, CORE)
            # Drops behind, sagging: (distance behind, size), the far one dropping away.
            for s, size, fall in (((6.4, 2, 0.6), (8.6, 1, 1.0)), ((5.9, 2, 1.0), (9.0, 1, 1.6)), ((6.8, 2, 0.8), (8.2, 1, 3.0)))[frame]:
                x = head[0] - fwd[0] * s
                y = head[1] - fwd[1] * s + fall + 0.35 * abs(fwd[0]) * s * 0.3
                droplet(cell, x, y, size)
    return sheet


def build_splash(rng: random.Random) -> Sheet:
    """A glob bursting: a flash of a splat, droplets thrown out and up that fall back, a sickly
    cloud rising out of it then sinking and crawling along the ground, bubbles swelling and
    popping, and a puddle left at the end (the sheet's last frame lingers and dithers out)."""
    sheet = Sheet(cell=(32, 32), frames=7, rows=1)
    cx, cy, ground = 16.0, 16.0, 21
    # Droplets: (vx, vy) in pixels per frame, uneven, mostly up and out.
    drops = [(-3.4, -3.2), (-1.6, -4.4), (0.6, -4.8), (2.3, -3.8), (3.8, -2.2), (-4.2, -0.8), (4.6, -0.2), (1.4, -2.0)]
    gravity = 1.55

    def splat(cell, w, h, body=GREEN):
        blobs = [(cx, cy, h), (cx - w * 0.45, cy + 0.6, h * 0.8), (cx + w * 0.45, cy + 0.4, h * 0.85)]
        lumps(cell, blobs, lambda n, d, t: ACID if lit(n) > 0.3 else (body if lit(n) > -0.5 else DEEP))

    for frame in range(7):
        f = sheet.cell(frame)
        if frame == 0:
            # The flash: a squashed splat, its heart the pale core.
            splat(f, 6.0, 2.8, ACID)
            outline(f, DEEP)
            for x, y in ((15, 15), (16, 15), (17, 15), (16, 16)):
                f.set(x, y, CORE)
        elif frame == 1:
            splat(f, 9.0, 3.2)
            outline(f, EDGE)
            f.set(14, 14, CORE)
            f.set(15, 14, CORE)
            bubble(f, 18, 15, 2, ACID, CORE)
        elif frame == 2:
            # The splat sags into the cloud: its lower half liquid, its top turning to gas.
            lumps(f, [(cx - 3, cy - 2.0, 2.8), (cx + 1, cy - 3.0, 3.2), (cx + 4, cy - 1.0, 2.4)], gas)
            lumps(f, [(cx - 3, cy + 2.0, 2.0), (cx + 2, cy + 2.2, 2.4)], lambda n, d, t: ACID if lit(n) > 0.2 else (GREEN if lit(n) > -0.4 else DEEP))
            outline(f, EDGE)
            bubble(f, 16, 16, 3, ACID, CORE)
        elif frame == 3:
            lumps(f, [(cx - 4, cy - 0.5, 3.0), (cx, cy - 1.5, 3.4), (cx + 4.5, cy + 0.5, 2.8), (cx + 1, cy + 2.5, 2.6)], gas)
            pop(f, 17, 14, 2, ACID)
            bubble(f, 12, 17, 2, ACID, CORE)
        elif frame == 4:
            # Sinking: flatter and lower, thinning.
            lumps(f, [(cx - 5, cy + 2.5, 2.6), (cx, cy + 2.0, 3.0), (cx + 5, cy + 3.0, 2.4)], gas, fade=0.8, seed=2)
            pop(f, 12, 16, 1, ACID)
        else:
            # The puddle, and the last of the cloud crawling along the ground.
            w = 6.5 if frame == 5 else 5.0
            for x in range(int(cx - w), int(cx + w) + 1):
                for y in range(ground - 1, ground + 2):
                    if ((x + 0.5 - cx) / w) ** 2 + ((y + 0.5 - ground) / 1.6) ** 2 <= 1.0:
                        f.set(x, y, DEEP)
            outline(f, EDGE)
            for x in range(int(cx - w * 0.5), int(cx + w * 0.3)):
                if f.get(x, ground - 1) == EDGE and f.get(x, ground) == DEEP:
                    f.set(x, ground - 1, GREEN)  # the light on the puddle's far rim
            if frame == 5:
                f.set(int(cx + 2), ground, ACID)  # a last bubble
                for x, y in ((int(cx - 9), ground - 2), (int(cx - 8), ground - 2), (int(cx + 7), ground - 3), (int(cx + 8), ground - 3), (int(cx + 9), ground - 2)):
                    f.set(x, y, RESIDUE)  # the gas crawling flat along the ground
            else:
                for x, y in ((int(cx - 10), ground - 1), (int(cx + 10), ground - 2)):
                    f.set(x, y, RESIDUE)
        # The droplets, on their arcs: bigger first, a pixel by the time they land.
        if 1 <= frame <= 4:
            for i, (vx, vy) in enumerate(drops):
                t = frame + 0.3
                x = cx + vx * t
                y = cy + vy * t + 0.5 * gravity * t * t
                if y >= ground + 1:
                    f.set(x, ground + (i % 2), DEEP)  # landed: a speck
                    continue
                big = frame <= 2 and i % 3 != 2
                drop(f, x, y, big, ACID, DEEP if big else EDGE)
    return sheet


def build_cloud(rng: random.Random) -> Sheet:
    """A lump of venomous gas welling out of the ground, swelling, bubbling, then sinking and
    crawling flat before it thins away: the piece a poison nova is made of. Its foot sits on
    the bottom rows (anchor)."""
    sheet = Sheet(cell=(20, 16), frames=8, rows=3)
    base = 14.0

    for row in range(3):
        jitter = [(rng.uniform(-1.2, 1.2), rng.uniform(-0.8, 0.8)) for _ in range(6)]
        shift = rng.uniform(-1.0, 1.0)

        def at(i, x, y, r):
            return (10.0 + shift + x + jitter[i][0], base + y + jitter[i][1] * 0.5, r)

        stages = [
            [at(0, 0, -1.5, 2.2), at(1, 2.2, -1.0, 1.6)],
            [at(0, -1, -3.5, 3.2), at(1, 2.5, -4.5, 2.6), at(2, -3.5, -2.0, 2.0), at(3, 3.5, -1.8, 2.0)],
            [at(0, 0, -6.5, 4.0), at(1, -4.0, -4.0, 3.2), at(2, 4.0, -5.0, 3.2), at(3, -1.5, -2.2, 3.0), at(4, 3.0, -2.0, 2.8)],
            [at(0, 0.5, -7.0, 4.0), at(1, -4.5, -4.5, 3.0), at(2, 4.5, -5.5, 3.0), at(3, -2.0, -2.0, 3.2), at(4, 3.5, -2.2, 3.0)],
            [at(0, 0, -4.5, 3.6), at(1, -5.0, -3.0, 3.0), at(2, 5.0, -3.5, 3.0), at(3, -1.0, -1.5, 3.2), at(5, 6.5, -1.2, 2.2)],
            [at(0, -1, -2.5, 3.2), at(1, -6.0, -1.8, 2.6), at(2, 5.5, -2.0, 2.8), at(5, 7.5, -1.0, 2.0)],
            [at(1, -6.5, -1.2, 2.2), at(2, 6.0, -1.5, 2.2), at(0, 0, -1.4, 2.4)],
            [at(1, -7.0, -0.8, 1.6), at(2, 6.5, -1.0, 1.6)],
        ]
        fades = [1.0, 1.0, 1.0, 1.0, 0.9, 0.7, 0.5, 0.35]
        for frame, blobs in enumerate(stages):
            cell = sheet.cell(frame, row)
            lumps(cell, blobs, gas, fade=fades[frame], seed=row + frame)
            if frame == 0:
                for x in range(7, 14):
                    if cell.get(x, 14) is None and rng.random() < 0.4:
                        cell.set(x, 14, DEEP)  # the ground wet where it wells up
            # Bubbles: one swells on the cloud's top, pops, another rises.
            bx = int(10 + shift + (2 if row % 2 else -2))
            if frame == 2:
                bubble(cell, bx, 6, 2, ACID, CORE)
            elif frame == 3:
                bubble(cell, bx, 4, 3, ACID, CORE)
            elif frame == 4:
                pop(cell, bx + 1, 5, 2, ACID)
                bubble(cell, bx - 5, 9, 2, ACID, CORE)
            elif frame == 5:
                pop(cell, bx - 5, 9, 1, GREEN)
    return sheet


def build_fang() -> Sheet:
    """A venomous bite in each direction: two curved fangs, pale and wet, open wide, snap shut
    in front of the mouth, venom spurts forward off their points and drips down."""
    sheet = Sheet(cell=(24, 24), frames=5, rows=16)
    c = (12.0, 12.0)
    # (base, control, tip) of the upper fang per frame, in the local frame (u forward, v right).
    poses = [[(u * 0.82, v * 0.82) for u, v in pose] for pose in (
        ((-6.0, -7.5), (1.0, -9.0), (5.5, -3.5)),
        ((-5.0, -6.5), (3.0, -7.0), (7.0, -1.2)),
        ((-4.5, -5.5), (4.0, -4.5), (7.5, 0.6)),
    )]
    for row in range(16):
        angle = row * math.tau / 16
        for frame in range(5):
            cell = sheet.cell(frame, row)
            if frame < 3:
                base, control, tip = poses[frame]
                tips = {}
                for side in (1.0, -1.0):
                    a = to_world(angle, base[0], base[1] * side, c)
                    b = to_world(angle, tip[0], tip[1] * side, c)
                    k = to_world(angle, control[0], control[1] * side, c)
                    points = bezier(a, k, b, 16)
                    widths = [max(2.4 * (1.0 - i / 16) ** 0.7, 0.7) for i in range(17)]
                    tips.update(tube(cell, points, widths, lambda n, s: CORE if lit(n) > 0.25 else (ACID if lit(n) > -0.5 else GREEN)))
                outline(cell, EDGE)
                clean(cell)
                # The points stay pale (an outline would swallow them): a fang reads by its tip.
                for (x, y), s in tips.items():
                    if s > 0.72 and cell.get(x, y) == EDGE:
                        cell.set(x, y, CORE if s > 0.88 else ACID)
            # Venom: a spurt off the points as they meet, then drops falling.
            if frame == 2:
                for u, v, big in ((9.5, -1.0, True), (11.0, 1.5, False), (10.0, 2.5, False)):
                    x, y = to_world(angle, u, v, c)
                    drop(cell, x, y, big, ACID, DEEP)
            elif frame == 3:
                for u, v, fall, big in ((10.5, -1.5, 2.0, True), (11.5, 2.0, 3.0, False), (8.5, 0.5, 1.5, True)):
                    x, y = to_world(angle, u, v, c)
                    drop(cell, x, y + fall, big, ACID, DEEP if big else EDGE)
                x, y = to_world(angle, 8.0, 0.0, c)
                cell.set(x, y - 1, RESIDUE)
                cell.set(x + 1, y - 2, RESIDUE)
            elif frame == 4:
                for u, v, fall in ((10.5, -1.5, 5.0), (11.5, 2.0, 6.5)):
                    x, y = to_world(angle, u, v, c)
                    cell.set(x, y + fall, DEEP)
                x, y = to_world(angle, 8.0, 0.0, c)
                cell.set(x, y + 1, RESIDUE)
    return sheet


def build_bubble() -> Sheet:
    """A bubble rising off a poisoned body: a speck, a ring that swells with its shine, a
    wobble, the pop flinging four pixels, the last of it."""
    sheet = Sheet(cell=(8, 8), frames=6, rows=1)
    sheet.cell(0).set(4, 5, GREEN)
    bubble(sheet.cell(1), 4, 5, 2, ACID, CORE)
    bubble(sheet.cell(2), 3, 3, 3, ACID, CORE)
    bubble(sheet.cell(3), 3, 2, 3, ACID, CORE)
    pop(sheet.cell(3), 0, 0, 0, None)
    pop(sheet.cell(4), 4, 3, 2, ACID)
    for x, y in ((1, 1), (6, 1)):
        sheet.cell(5).set(x, y, GREEN)
    return sheet


def main() -> None:
    poison = Element.load("poison")
    rng = random.Random(11)
    sheets = {
        "poison_glob": build_glob(),
        "poison_splash": build_splash(rng),
        "poison_cloud": build_cloud(rng),
        "poison_fang": build_fang(),
        "poison_bubble": build_bubble(),
    }
    preview_dir = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
    for name, sheet in sheets.items():
        sheet.save(os.path.join(OUT, name + ".png"), poison)
        if preview_dir:
            os.makedirs(preview_dir, exist_ok=True)
            sheet.preview(os.path.join(preview_dir, name + "_x6.png"), poison, zoom=10 if name == "poison_bubble" else 6)
        print("wrote", os.path.join("assets", "fx", "poison", name + ".png"))


if __name__ == "__main__":
    main()
