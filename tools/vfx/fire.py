"""The fire kit (docs/vfx.md, "Fire"): draws its sheets on the fire ramp, at the art's own
resolution, with hard alpha. Re-run it to rebuild them after a change:

    python3 tools/vfx/fire.py [--preview DIR]

    assets/fx/fire/fire_bolt.png     the shot: a ball of fire licking back, 16 directions x 3 frames, 16x16
    assets/fx/fire/fire_ray.png      a ray of fire (the Demon Cyclops' eye): 16 directions x 2 frames, 24x24
    assets/fx/fire/fire_impact.png   a shot landing: 7 frames, 32x32
    assets/fx/fire/fire_blast.png    an explosion: 9 frames, 48x48
    assets/fx/fire/fire_lick.png     a piece of novas, waves and arcs: 8 frames (rise, lick, die, smoke) x 3 variants, 12x20
    assets/fx/fire/fire_flicker.png  a small flame on a burning body or a campfire: 12 frames, 8x12
    assets/fx/fire/fire_jet.png      a flame vent's column: 8 frames (burst, roar, die), 16x32
    assets/fx/fire/fire_claw.png     a burning claw (claw.png's strokes in the ramp, licking): 4 frames, 32x32

Fire's grammar: licking teardrops whose round base is white-hot and whose tips go down the
ramp to the dark maroon edge, curling as they rise; embers that rise and die; dark smoke (the
residue) once it burns out. Every shape is a "heat field": tongues add heat, the heat picks the
ramp step, so flames merge the way flames do. Directions are rendered, never rotated.
"""
import math
import os
import random
import sys

from PIL import Image

from vfxkit import RESIDUE, ROOT, Element, Sheet, preview

CORE, YELLOW, ORANGE, RED, EDGE = 0, 1, 2, 3, 4
OUT = os.path.join(ROOT, "assets", "fx", "fire")
RISE = (0.0, -1.0)
# Heat thresholds of the ramp steps (white-hot ... the dark edge).
STEPS = ((0.80, CORE), (0.60, YELLOW), (0.40, ORANGE), (0.20, RED), (0.0, EDGE))


class Field:
    """Heat over a cell (0 = nothing): tongues and balls add to it, `paint` turns it into ramp
    steps (and the smoke, kept apart, into the residue)."""

    def __init__(self, w: int, h: int):
        self.w, self.h = w, h
        self.heat = [[0.0] * w for _ in range(h)]
        self.smoke = [[False] * w for _ in range(h)]

    def add(self, x: int, y: int, value: float) -> None:
        if 0 <= x < self.w and 0 <= y < self.h and value > self.heat[y][x]:
            self.heat[y][x] = value

    def ball(self, cx: float, cy: float, r: float, hot: float = 1.0, rim: float = 0.25, lumps: float = 0.0, seed: float = 0.0) -> None:
        """A mass of fire: `hot` at its heart, `rim` at its edge; `lumps` makes its outline
        billow (a fraction of the radius)."""
        for y in range(self.h):
            for x in range(self.w):
                px, py = x + 0.5 - cx, y + 0.5 - cy
                d = math.hypot(px, py)
                a = math.atan2(py, px)
                edge = r * (1.0 + lumps * (0.6 * math.sin(3 * a + seed) + 0.4 * math.sin(5 * a + seed * 2.3)))
                if d <= edge:
                    d = d * r / max(edge, 0.01)
                    self.add(x, y, rim + (hot - rim) * (1.0 - d / max(r, 0.01)) ** 0.8)

    def tongue(self, bx: float, by: float, r: float, length: float, direction=RISE, curl: float = 0.0,
               phase: float = 0.0, hot: float = 0.95, tip: float = 0.12) -> None:
        """A lick of flame from a round base at (bx, by) of radius `r`, `length` long along
        `direction`, its spine waving by `curl` (pixels), hottest at the base's middle."""
        dx, dy = direction
        n = math.hypot(dx, dy) or 1.0
        dx, dy = dx / n, dy / n
        nx, ny = -dy, dx
        for y in range(self.h):
            for x in range(self.w):
                px, py = x + 0.5 - bx, y + 0.5 - by
                u = px * dx + py * dy  # along the tongue
                v = px * nx + py * ny  # across it
                if u < 0.0:
                    d = math.hypot(u, v)
                    if d <= r:
                        self.add(x, y, hot - (hot - 0.35) * (d / r) ** 1.4)
                    continue
                if u > length:
                    continue
                s = u / length
                wave = curl * math.sin(s * math.pi * 1.4 + phase) * s
                width = r * (1.0 - s) ** 0.75 + 0.35
                off = abs(v - wave)
                if off <= width:
                    across = off / width
                    value = hot * (1.0 - s * (1.0 - tip / hot)) - across * 0.32 * (1.0 - s * 0.5)
                    self.add(x, y, max(value, 0.05))

    def puff(self, cx: float, cy: float, r: float) -> None:
        """A billowing blot of smoke (the residue)."""
        seed = cx * 1.7 + cy * 0.9
        for y in range(self.h):
            for x in range(self.w):
                px, py = x + 0.5 - cx, (y + 0.5 - cy) * 1.2
                a = math.atan2(py, px)
                if math.hypot(px, py) <= r * (1.0 + 0.22 * math.sin(4 * a + seed) + 0.12 * math.sin(7 * a + seed)):
                    self.smoke[y][x] = True

    def paint(self, cell, rim_dark: bool = True) -> None:
        """Into `cell`: the heat as ramp steps; the outer pixels of the upper half (the tips, the
        top of a ball) take the dark edge so it reads on the desert's sand."""
        for y in range(self.h):
            for x in range(self.w):
                if self.smoke[y][x] and self.heat[y][x] <= 0.0:
                    cell.set(x, y, RESIDUE)
        for y in range(self.h):
            for x in range(self.w):
                value = self.heat[y][x]
                if value <= 0.0:
                    continue
                for threshold, index in STEPS:
                    if value > threshold:
                        cell.set(x, y, index)
                        break
        if rim_dark:
            for y in range(self.h):
                for x in range(self.w):
                    if self.heat[y][x] <= 0.0 or self.heat[y][x] > 0.5:
                        continue
                    above = y == 0 or self.heat[y - 1][x] <= 0.0
                    side = (x == 0 or self.heat[y][x - 1] <= 0.0) or (x == self.w - 1 or self.heat[y][x + 1] <= 0.0)
                    if above:
                        cell.set(x, y, EDGE)
                    elif side and self.heat[y][x] < 0.32:
                        cell.set(x, y, RED)


def ember(cell, x: float, y: float, index: int, big: bool = False) -> None:
    cell.set(x, y, index)
    if big:
        cell.set(x, y - 1, min(index + 1, EDGE))


def tidy(cell) -> None:
    """No lone pixel of flame (an ember is drawn on purpose, after)."""
    for x, y in cell.opaque():
        if cell.get(x, y) == RESIDUE:
            continue
        if all(cell.get(x + dx, y + dy) is None for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            cell.px[y][x] = None


def build_bolt() -> Sheet:
    """A ball of fire with three tongues licking back from it, leaning up a little (fire
    rises whichever way it flies), waving from frame to frame. A white-hot front."""
    sheet = Sheet(cell=(16, 16), frames=3, rows=16)
    for row in range(16):
        a = row * math.tau / 16
        d = (math.cos(a), math.sin(a))
        n = (-d[1], d[0])
        for frame in range(3):
            f = Field(16, 16)
            hx, hy = 8.0 + d[0] * 2.6, 8.0 + d[1] * 2.6
            back = (-d[0], -d[1] - 0.3)
            phase = frame * 2.1
            for lateral, length, curl in ((0.0, 9.0, 1.2), (-1.7, 6.0, 0.9), (1.7, 6.5, -0.9)):
                f.tongue(hx + n[0] * lateral - d[0] * 0.5, hy + n[1] * lateral - d[1] * 0.5, 2.2 if lateral == 0 else 1.6,
                         length - (frame % 2) * (1.0 if lateral else 0.0), back, curl, phase + lateral, hot=0.72)
            f.ball(hx, hy, 3.4, hot=1.0, rim=0.45)
            cell = sheet.cell(frame, row)
            f.paint(cell)
            tidy(cell)
    return sheet


def build_ray() -> Sheet:
    """A lance of fire: a long white-hot core and a sheath licking back, for a monster's eye
    beam (a burst of rays). Longer and thinner than the fireball: a beam, not a ball."""
    sheet = Sheet(cell=(24, 24), frames=2, rows=16)
    for row in range(16):
        a = row * math.tau / 16
        d = (math.cos(a), math.sin(a))
        n = (-d[1], d[0])
        for frame in range(2):
            f = Field(24, 24)
            tip_x, tip_y = 12.0 + d[0] * 7.0, 12.0 + d[1] * 7.0
            back = (-d[0], -d[1])
            f.tongue(tip_x, tip_y, 1.9, 17.0, back, 0.8, frame * 2.6, hot=0.98, tip=0.2)
            for lateral in (-1.6, 1.6):
                f.tongue(tip_x - d[0] * 3 + n[0] * lateral, tip_y - d[1] * 3 + n[1] * lateral, 1.0, 9.0 + frame, back,
                         lateral * 0.6, frame * 1.7 + lateral, hot=0.6)
            cell = sheet.cell(frame, row)
            f.paint(cell)
            tidy(cell)
    return sheet


def build_impact(rng: random.Random) -> Sheet:
    """A fireball bursting: a white flash, tongues licking out and up, flames breaking off and
    rising, embers, a puff of dark smoke that thins out."""
    sheet = Sheet(cell=(32, 32), frames=7, rows=1)
    cx, cy = 16.0, 18.0
    angles = [math.radians(a + rng.uniform(-14, 14)) for a in (-90, -38, -142, 8, 172, 62, 118)]
    # f0: the flash, a hot irregular knot.
    f = Field(32, 32)
    f.ball(cx, cy, 4.2, hot=1.0, rim=0.7)
    for a in angles[:3]:
        f.tongue(cx, cy, 1.6, 5.0, (math.cos(a), math.sin(a)), 0.0, 0.0, hot=0.85)
    f.paint(sheet.cell(0), rim_dark=False)
    # f1: the burst at its biggest: tongues out, bending up.
    f = Field(32, 32)
    for i, a in enumerate(angles):
        dx, dy = math.cos(a), math.sin(a) - 0.6
        f.tongue(cx + math.cos(a) * 2, cy + math.sin(a) * 2, 2.4, 8.0 + (i % 3) * 1.5, (dx, dy), 1.2, i, hot=0.82)
    f.ball(cx, cy, 5.2, hot=1.0, rim=0.6)
    f.paint(sheet.cell(1))
    tidy(sheet.cell(1))
    # f2: the heart cools, the tongues rise, the first embers.
    f = Field(32, 32)
    for i, a in enumerate(angles):
        dx, dy = math.cos(a) * 0.8, math.sin(a) - 1.1
        f.tongue(cx + math.cos(a) * 4, cy + math.sin(a) * 3 - 1, 2.2, 8.0 + (i % 2) * 2, (dx, dy), 1.5, i * 1.3, hot=0.7)
    f.ball(cx, cy, 4.5, hot=0.72, rim=0.4)
    f.paint(sheet.cell(2))
    tidy(sheet.cell(2))
    for x, y in ((9, 9), (23, 8), (16, 4)):
        ember(sheet.cell(2), x, y, YELLOW)
    # f3: flames break off and rise; smoke starts on top.
    f = Field(32, 32)
    for i, a in enumerate(angles[:5]):
        bx, by = cx + math.cos(a) * 6, cy + math.sin(a) * 3 - 4
        f.tongue(bx, by, 1.8, 5.0 + (i % 2) * 2, RISE, 1.0, i, hot=0.58)
    f.tongue(cx, cy + 2, 2.6, 6.0, RISE, 1.0, 0.7, hot=0.55)
    f.puff(cx - 3, cy - 10, 2.6)
    f.puff(cx + 3, cy - 11, 2.2)
    f.paint(sheet.cell(3))
    tidy(sheet.cell(3))
    for x, y in ((7, 7), (25, 6), (14, 2), (20, 4)):
        ember(sheet.cell(3), x, y, ORANGE)
    # f4: small dying flames, the smoke rising.
    f = Field(32, 32)
    for i, bx in enumerate((11.0, 16.0, 21.0)):
        f.tongue(bx, cy - 2 - (i % 2) * 2, 1.3, 4.0, RISE, 0.8, i, hot=0.45)
    f.puff(cx - 2, cy - 13, 3.2)
    f.puff(cx + 4, cy - 14, 2.6)
    f.puff(cx - 6, cy - 9, 1.8)
    f.paint(sheet.cell(4))
    tidy(sheet.cell(4))
    for x, y in ((8, 4), (24, 3), (18, 1)):
        ember(sheet.cell(4), x, y, RED)
    # f5: the smoke, thinning (every other pixel of it), two embers.
    f = Field(32, 32)
    f.puff(cx - 1, cy - 15, 3.4)
    f.puff(cx + 5, cy - 16, 2.4)
    f.paint(sheet.cell(5))
    _thin(sheet.cell(5), 2)
    ember(sheet.cell(5), 9, 2, RED)
    ember(sheet.cell(5), 23, 1, EDGE)
    # f6: last wisps.
    f = Field(32, 32)
    f.puff(cx, cy - 17, 3.0)
    f.paint(sheet.cell(6))
    _thin(sheet.cell(6), 3)
    return sheet


def build_blast(rng: random.Random) -> Sheet:
    """An explosion (Fireball, bombs, barrels, Inferno): a flash, a ball of fire whose tongues
    lick out then up into a rising, cooling mushroom, then dark smoke and embers."""
    sheet = Sheet(cell=(48, 48), frames=9, rows=1)
    cx, cy = 24.0, 28.0
    angles = [math.radians(a + rng.uniform(-10, 10)) for a in range(-90, 270, 36)]
    lengths = [rng.uniform(9, 13) for _ in angles]
    # f0: the flash.
    f = Field(48, 48)
    f.ball(cx, cy, 7.0, hot=1.0, rim=0.75, lumps=0.12, seed=0.4)
    for a in angles[::3]:
        f.tongue(cx, cy, 2.0, 7.0, (math.cos(a), math.sin(a)), 0.0, 0.0, hot=0.9)
    f.paint(sheet.cell(0), rim_dark=False)
    # f1-f2: the ball swells, tongues lick out.
    for frame, (grow, r, hot) in enumerate(((0.7, 10.0, 1.0), (1.0, 12.0, 0.92)), start=1):
        f = Field(48, 48)
        for i, (a, ln) in enumerate(zip(angles, lengths)):
            dx, dy = math.cos(a), math.sin(a) - 0.35 * frame
            f.tongue(cx + math.cos(a) * r * 0.5, cy + math.sin(a) * r * 0.4, 3.2, ln * grow, (dx, dy), 1.6, i, hot=0.8)
        # A billowing body (cooler), and its white heart off-center, rising, ragged.
        f.ball(cx, cy, r, hot=0.78, rim=0.5, lumps=0.16, seed=frame * 1.3)
        f.ball(cx - r * 0.45, cy + r * 0.25, r * 0.55, hot=0.7, rim=0.5, lumps=0.2, seed=frame)
        f.ball(cx + r * 0.5, cy + r * 0.2, r * 0.5, hot=0.7, rim=0.5, lumps=0.2, seed=frame + 2)
        f.ball(cx - 1.5, cy - r * 0.2, r * 0.5, hot=hot, rim=0.7, lumps=0.3, seed=frame * 2.7 + 0.5)
        f.ball(cx + r * 0.25, cy - r * 0.35, r * 0.3, hot=hot, rim=0.75, lumps=0.2, seed=frame + 4)
        f.paint(sheet.cell(frame))
        tidy(sheet.cell(frame))
    # f3: the mushroom rises, the heart cools from the bottom.
    f = Field(48, 48)
    for i, a in enumerate(angles):
        dx, dy = math.cos(a) * 0.7, math.sin(a) * 0.4 - 1.0
        f.tongue(cx + math.cos(a) * 9, cy + math.sin(a) * 5 - 3, 3.0, lengths[i] * 0.9, (dx, dy), 2.0, i * 1.7, hot=0.68)
    f.ball(cx, cy - 4, 9.0, hot=0.7, rim=0.4, lumps=0.2, seed=2.0)
    f.puff(cx, cy - 18, 4.0)
    f.paint(sheet.cell(3))
    tidy(sheet.cell(3))
    for k in range(5):
        a = rng.uniform(-math.pi, 0)
        ember(sheet.cell(3), cx + math.cos(a) * 20, cy - 6 + math.sin(a) * 14, YELLOW, k < 2)
    # f4: broken flames under a head of smoke.
    f = Field(48, 48)
    for i, bx in enumerate((14.0, 19.0, 24.0, 29.0, 34.0)):
        f.tongue(bx, cy - 2 - (i % 2) * 3, 2.4, 7.0 + (i % 3), RISE, 1.6, i, hot=0.58)
    f.puff(cx - 5, cy - 20, 5.0)
    f.puff(cx + 5, cy - 21, 4.5)
    f.puff(cx, cy - 14, 4.0)
    f.paint(sheet.cell(4))
    tidy(sheet.cell(4))
    for k in range(6):
        ember(sheet.cell(4), rng.uniform(6, 42), rng.uniform(2, 20), ORANGE, k < 2)
    # f5: the smoke on top, the last flames low.
    f = Field(48, 48)
    for i, bx in enumerate((17.0, 24.0, 31.0)):
        f.tongue(bx, cy, 1.6, 4.0, RISE, 1.0, i, hot=0.45)
    f.puff(cx - 6, cy - 23, 5.5)
    f.puff(cx + 5, cy - 24, 5.0)
    f.puff(cx, cy - 17, 4.0)
    f.paint(sheet.cell(5))
    tidy(sheet.cell(5))
    for k in range(5):
        ember(sheet.cell(5), rng.uniform(6, 42), rng.uniform(0, 16), RED)
    # f6-f8: the smoke thins and rises, embers die.
    for frame, (lift, keep) in zip((6, 7, 8), ((26, 1), (28, 2), (30, 3))):
        f = Field(48, 48)
        f.puff(cx - 6, cy - lift, 5.0 - frame * 0.3)
        f.puff(cx + 5, cy - lift - 1, 4.6 - frame * 0.3)
        f.paint(sheet.cell(frame))
        _thin(sheet.cell(frame), keep + 1)
        for k in range(4 - keep):
            ember(sheet.cell(frame), rng.uniform(8, 40), rng.uniform(0, 12), EDGE)
    return sheet


def build_lick(rng: random.Random) -> Sheet:
    """One lick of fire standing on the ground (its base at the bottom middle): it rises fast,
    licks and curls, sinks, a flame tears off its tip, then a puff of smoke and an ember."""
    sheet = Sheet(cell=(12, 20), frames=8, rows=3)
    base_y = 18.0
    for row in range(3):
        phase = row * 2.0
        lean = (-0.25, 0.1, 0.3)[row]
        side = (1, -1, 1)[row]
        heights = (4.0, 10.0, 15.0, 13.0, 14.0, 9.0, 5.0)
        for frame in range(8):
            f = Field(12, 20)
            if frame < 6:
                h = heights[frame] - (row == 2) * 2
                r = (2.0, 3.0, 3.4, 3.3, 3.2, 2.8)[frame]
                hot = (1.0, 0.97, 0.95, 0.9, 0.85, 0.7)[frame]
                f.tongue(6.0, base_y - r * 0.6, r, h, (lean, -1.0), 1.4 + frame * 0.2, phase + frame * 1.9, hot=hot)
                if 1 <= frame <= 4:
                    f.tongue(6.0 + side * 2.5, base_y - 1.5, 1.6, h * 0.45, (side * 0.4, -1.0), 0.6, phase + frame, hot=hot * 0.8)
                if frame == 5:
                    f.tongue(6.0 + lean * 10, base_y - 13, 1.2, 3.0, RISE, 0.5, frame, hot=0.5)
            elif frame == 6:
                f.tongue(6.0, base_y - 1.0, 1.6, 4.0, RISE, 0.6, phase, hot=0.5)
                f.puff(6.0 + lean * 8, base_y - 12, 2.3)
            else:
                f.puff(6.0 + lean * 9, base_y - 14, 2.6)
            cell = sheet.cell(frame, row)
            f.paint(cell)
            tidy(cell)
            if frame == 6:
                ember(cell, 6 + side * 3, base_y - 9, ORANGE)
            if frame == 7:
                _thin(cell, 2)
                ember(cell, 6 - side * 2, base_y - 7, RED)
                ember(cell, 6 + side, base_y - 1, EDGE)
    return sheet


def build_flicker() -> Sheet:
    """A small flame's life (8x12): born thin, round and licking, curling, then shrinking to an
    ember. Burning bodies throw them; a campfire plays three out of step."""
    sheet = Sheet(cell=(8, 12), frames=12, rows=1)
    stages = [
        (2.0, 1.3, 9.0, 0.97), (2.6, 2.2, 8.0, 1.0), (2.8, 2.6, 8.5, 0.98), (2.9, 2.8, 9.0, 0.95),
        (3.0, 2.9, 9.0, 0.92), (3.0, 2.8, 8.5, 0.9), (3.0, 2.7, 8.0, 0.86), (3.0, 2.5, 7.0, 0.8),
        (3.2, 2.2, 6.0, 0.72), (3.4, 1.9, 4.5, 0.62), (3.6, 1.5, 3.0, 0.5), (3.8, 1.0, 1.5, 0.4),
    ]
    for frame, (lift, r, h, hot) in enumerate(stages):
        f = Field(8, 12)
        f.tongue(4.0, 11.0 - lift + r * 0.4, r, h, RISE, 1.3, frame * 1.1, hot=hot)
        cell = sheet.cell(frame)
        f.paint(cell)
        if frame < 11:
            tidy(cell)
    return sheet


def build_jet() -> Sheet:
    """A column of fire roaring out of a vent (its base at the bottom): a burst, a tall licking
    column, then it sinks back and smokes."""
    sheet = Sheet(cell=(16, 32), frames=8, rows=1)
    base = 30.0
    stages = [(8, 3.0, 1.0), (20, 4.2, 1.0), (27, 4.6, 0.97), (25, 4.4, 0.95), (28, 4.5, 0.95), (22, 4.0, 0.85), (12, 3.2, 0.7), (5, 2.2, 0.5)]
    for frame, (h, r, hot) in enumerate(stages):
        f = Field(16, 32)
        f.tongue(8.0, base - r * 0.5, r, h, RISE, 1.6, frame * 1.7, hot=hot)
        if 1 <= frame <= 5:
            f.tongue(4.5, base - 1, 2.0, h * 0.45, (-0.4, -1.0), 0.9, frame * 2.3, hot=hot * 0.85)
            f.tongue(11.5, base - 1, 2.0, h * 0.5, (0.4, -1.0), -0.9, frame * 1.3, hot=hot * 0.85)
        if frame >= 6:
            f.puff(8.0, base - h - 6, 2.6 if frame == 6 else 3.0)
        cell = sheet.cell(frame)
        f.paint(cell)
        tidy(cell)
        if frame in (2, 4, 6):
            ember(cell, 3 + frame, max(base - h - 3, 2), YELLOW if frame < 6 else RED)
    return sheet


def build_claw() -> Sheet:
    """A burning claw: claw.png's three strokes painted on the ramp (white-hot leading edge,
    cooling behind), and on the later frames the strokes licking into small flames and embers
    as they fade."""
    source = Image.open(os.path.join(ROOT, "assets", "fx", "claw.png")).convert("RGBA")
    px = source.load()
    sheet = Sheet(cell=(32, 32), frames=4, rows=1)
    bright = {(255, 255, 255): CORE, (255, 225, 141): YELLOW, (255, 173, 93): ORANGE}
    for frame in range(4):
        cell = sheet.cell(frame)
        f = Field(32, 32)
        for y in range(32):
            for x in range(32):
                c = px[frame * 32 + x, y]
                if c[3] < 128:
                    continue
                index = bright.get(c[:3], ORANGE)
                if frame >= 2:
                    index = min(index + 1, RED)  # it cools as it fades
                cell.set(x, y, index)
                # Licks rising off the strokes once they are drawn.
                if frame >= 1 and px[frame * 32 + x, y - 1][3] < 128 and (x * 7 + y * 3) % (11 if frame == 1 else 8) == 0:
                    f.tongue(x + 0.5, y + 0.5, 1.0, 2.0 + frame, RISE, 0.6, x * 0.7, hot=0.62 - frame * 0.08)
        for y in range(32):
            for x in range(32):
                if f.heat[y][x] > 0.0 and cell.get(x, y) is None:
                    value = f.heat[y][x]
                    cell.set(x, y, ORANGE if value > 0.45 else RED if value > 0.25 else EDGE)
        if frame >= 2:
            for k in range(3):
                ember(cell, 8 + k * 7 + frame, 6 + (k * 5) % 7 - frame, YELLOW if frame == 2 else RED)
    return sheet


def _thin(cell, keep: int) -> None:
    """Keeps one smoke pixel in `keep` (ordered), the way the game dithers a fade."""
    bayer = (0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5)
    for x, y in cell.opaque():
        if cell.get(x, y) == RESIDUE and bayer[(y % 4) * 4 + x % 4] >= 16 // keep:
            cell.px[y][x] = None


def main() -> None:
    fire = Element.load("fire")
    rng = random.Random(11)
    sheets = {
        "fire_bolt": build_bolt(),
        "fire_ray": build_ray(),
        "fire_impact": build_impact(rng),
        "fire_blast": build_blast(rng),
        "fire_lick": build_lick(rng),
        "fire_flicker": build_flicker(),
        "fire_jet": build_jet(),
        "fire_claw": build_claw(),
    }
    preview_dir = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
    for name, sheet in sheets.items():
        sheet.save(os.path.join(OUT, name + ".png"), fire)
        if preview_dir:
            os.makedirs(preview_dir, exist_ok=True)
            zoom = 4 if sheet.cw * sheet.frames > 200 else 6
            if sheet.rows > 4:
                image = sheet.image(fire)
                preview(image.crop((0, 0, image.width, sheet.ch * 6)), os.path.join(preview_dir, name + "_x6.png"), zoom, (sheet.cw, sheet.ch))
            else:
                sheet.preview(os.path.join(preview_dir, name + "_x6.png"), fire, zoom=zoom)
        print("wrote", os.path.join("assets", "fx", "fire", name + ".png"))


if __name__ == "__main__":
    main()
