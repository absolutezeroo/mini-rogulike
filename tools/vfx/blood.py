"""The blood kit (docs/vfx.md, "Blood"): draws its sheets on the blood ramp, at the art's own
resolution, with hard alpha. Re-run it to rebuild them after a change:

    python3 tools/vfx/blood.py [--preview DIR]

    assets/fx/blood/blood_claw.png   a creature's rake: three gashes, 16 directions (rows) x 5 frames, 24x24
    assets/fx/blood/blood_spurt.png  a wound opening: 6 frames, 24x24
    assets/fx/blood/blood_jet.png    a nova's piece: a jet of blood out of the ground, 7 frames x 3 variants, 12x20

Blood's grammar: matter, not light. Gashes that open bright and darken as they close, drops
thrown on ballistic arcs that fall and stay as stains. The pale pink only on the freshest edge
of a cut; the red for what flies; the dark red for what has slowed; the near-black maroon for
the outline and what lies on the floor.
"""
import math
import os
import random
import sys

from liquid import drop, lit, lumps, to_world, tube
from vfxkit import ROOT, Element, Sheet, clean, outline

CORE, RED, DARK, EDGE = 0, 1, 2, 3
OUT = os.path.join(ROOT, "assets", "fx", "blood")


def gash_points(angle: float, c: tuple, u0: float, t0: float, t1: float, bend: float = 1.6) -> tuple:
    """Points and sweep positions of one claw gash in the local frame: a slightly curved stroke
    across the front, from the paw's left (v = -9) to its right (v = +9), slanting forward;
    only the part from `t0` to `t1` of it."""
    points, sweep = [], []
    steps = 18
    for i in range(steps + 1):
        t = t0 + (t1 - t0) * i / steps
        v = -9.0 + 18.0 * t
        u = u0 + 4.5 * t - bend * math.sin(math.pi * t)
        points.append(to_world(angle, u, v, c))
        sweep.append(t)
    return points, sweep


def build_claw() -> Sheet:
    """Three claws raking across the front of the creature in each direction: parallel gashes
    that open from one side to the other, the freshest part pale, then thin and darken from
    where they began, shedding drops off their ends. No outline: a gash is two pixels wide and
    an outline would swallow it; its dark side is its edge."""
    sheet = Sheet(cell=(24, 24), frames=5, rows=16)
    c = (12.0, 12.0)
    offsets = (-6.0, -1.5, 3.0)
    shown = [(0.0, 0.45, 1.0), (0.0, 1.0, 1.0), (0.35, 1.0, 0.8), (0.7, 1.0, 0.6)]
    for row in range(16):
        angle = row * math.tau / 16
        for frame in range(5):
            cell = sheet.cell(frame, row)
            if frame < 4:
                start, end, thick = shown[frame]
                for k, u0 in enumerate(offsets):
                    lag = (0.08, 0.0, 0.05)[k]  # the claws don't land at once
                    t0, t1 = max(start - lag, 0.0), max(end - lag, 0.0)
                    if t1 <= t0 + 0.05:
                        continue
                    points, sweep = gash_points(angle, c, u0, t0, t1)
                    widths = [(0.35 + 0.75 * math.sin(math.pi * t)) * thick for t in sweep]

                    def shade(normal, s, sweep=sweep, frame=frame, t1=t1):
                        t = sweep[min(int(s * (len(sweep) - 1) + 0.5), len(sweep) - 1)]
                        if frame <= 1 and t > t1 - 0.3:
                            return CORE if lit(normal) > -0.3 else RED
                        if frame >= 3:
                            return DARK if lit(normal) > -0.2 else EDGE
                        return RED if lit(normal) > -0.35 else DARK

                    tube(cell, points, widths, shade)
            # Drops thrown off the far end of the gashes, falling.
            if frame >= 2:
                for k, u0 in enumerate(offsets[:2] if frame < 4 else offsets[1:2]):
                    u = u0 + 4.5 + (frame - 1) * 0.8
                    v = 9.0 + (frame - 1) * 1.6
                    x, y = to_world(angle, u, v, c)
                    fall = (frame - 2) ** 2 * 1.2
                    if frame == 4:
                        cell.set(x, y + fall, DARK)
                    else:
                        drop(cell, x, y + fall, frame == 2 and k == 0, RED, EDGE)
    return sheet


def build_spurt(rng: random.Random) -> Sheet:
    """A wound opening: a ragged splash (not a star), drops thrown out and up on uneven arcs,
    falling and slowing down the ramp, a few specks left where they land."""
    sheet = Sheet(cell=(24, 24), frames=6, rows=1)
    cx, cy, ground = 12.0, 11.0, 18
    drops = [(-2.6, -2.8), (-1.0, -3.6), (0.8, -3.2), (2.4, -2.4), (3.2, -0.8), (-3.4, -0.6), (1.6, -1.2), (-1.8, -1.6), (0.2, -2.2)]
    gravity = 1.4
    for frame in range(6):
        f = sheet.cell(frame)
        if frame == 0:
            lumps(f, [(cx, cy, 2.6), (cx - 2.2, cy + 0.8, 1.8), (cx + 2.0, cy - 1.0, 1.6)],
                  lambda n, d, t: CORE if d > 1.2 else RED)
            for dx, dy in ((-4, -2), (4, -3), (5, 1), (-3, 3)):
                f.set(cx + dx, cy + dy, RED)
            outline(f, EDGE)
            f.set(cx, cy, CORE)
        elif frame == 1:
            lumps(f, [(cx, cy + 0.5, 2.0), (cx + 1.5, cy + 1.0, 1.4)], lambda n, d, t: RED if lit(n) > 0 else DARK)
            outline(f, EDGE)
        elif frame == 2:
            f.set(cx, cy + 2, DARK)
            f.set(cx + 1, cy + 2, EDGE)
        for i, (vx, vy) in enumerate(drops):
            if frame == 0:
                break
            t = frame + 0.2
            x = cx + vx * t
            y = cy + vy * t + 0.5 * gravity * t * t
            if y >= ground:
                f.set(x, ground + (i % 2), EDGE if frame >= 4 else DARK)
                continue
            big = frame <= 3 and i % 2 == 0
            drop(f, x, y, big, RED if frame <= 2 else DARK, DARK if big and frame <= 2 else EDGE)
    return sheet


def build_jet(rng: random.Random) -> Sheet:
    """A jet of blood bursting out of the ground: it shoots up leaning, its top breaks into
    drops that arc over and fall, and it leaves a stain. Its foot sits on the bottom rows."""
    sheet = Sheet(cell=(12, 20), frames=7, rows=3)
    base = 18.0
    for row in range(3):
        lean = (0.18, -0.22, 0.05)[row]
        heights = [2.0, 6.5, 11.5, 7.0, 3.0, 0.0, 0.0]
        side = 1 if lean >= 0 else -1
        for frame in range(7):
            f = sheet.cell(frame, row)
            h = heights[frame]
            if h > 0:
                points, widths = [], []
                for i in range(12):
                    y = base - h * i / 11
                    points.append((6.0 + lean * (base - y) + (0.4 * math.sin(i * 0.9 + row)), y))
                    widths.append(1.5 - 0.4 * i / 11 if frame < 3 else 1.2 - 0.4 * i / 11)
                # No outline (it would eat a 3-pixel jet): its shaded side is its edge.
                tube(f, points, widths, lambda n, s: CORE if s > 0.82 and frame <= 2 else (RED if lit(n) > -0.2 else (DARK if lit(n) > -0.7 else EDGE)))
            # The top breaking into drops that arc over and fall.
            tx = 6.0 + lean * 11.5
            if frame >= 3:
                t = frame - 2.5
                for k, (vx, vy, big) in enumerate(((1.4, -1.6, True), (2.4, -0.6, False), (0.4, -1.9, False))):
                    x = tx + side * vx * t
                    y = base - 11.5 + vy * t + 0.9 * t * t
                    if y >= base:
                        f.set(x, base + 0.5, DARK if frame < 6 else EDGE)
                        continue
                    drop(f, x, y, big and frame <= 4, RED if frame <= 4 else DARK, EDGE)
            # The ground where it came out: splashed, then stained.
            if frame <= 2:
                for dx in (-2, -1, 1, 2):
                    if f.get(6 + dx, 18) is None:
                        f.set(6 + dx, 18, RED if abs(dx) == 1 else DARK)
            elif frame >= 4:
                for dx in range(-2, 3):
                    f.set(6 + dx, 18, DARK if abs(dx) < 2 and frame < 6 else EDGE)
                f.set(6, 19, EDGE)
    return sheet


def main() -> None:
    blood = Element.load("blood")
    rng = random.Random(5)
    sheets = {
        "blood_claw": build_claw(),
        "blood_spurt": build_spurt(rng),
        "blood_jet": build_jet(rng),
    }
    preview_dir = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
    for name, sheet in sheets.items():
        sheet.save(os.path.join(OUT, name + ".png"), blood)
        if preview_dir:
            os.makedirs(preview_dir, exist_ok=True)
            sheet.preview(os.path.join(preview_dir, name + "_x6.png"), blood)
        print("wrote", os.path.join("assets", "fx", "blood", name + ".png"))


if __name__ == "__main__":
    main()
