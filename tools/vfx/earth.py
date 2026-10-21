"""The earth kit (docs/vfx.md, "Earth"): draws its sheets on the earth ramp, at the art's own
resolution, with hard alpha. Re-run it to rebuild them after a change:

    python3 tools/vfx/earth.py [--preview DIR]

    assets/fx/earth/earth_spike.png   a piece of quakes and slams: 8 frames (crack, thrust, hold, crumble) x 3 variants, 16x24
    assets/fx/earth/earth_impact.png  a clod or a rock landing: 6 frames, 32x32
    assets/fx/earth/earth_burst.png   the ground bursting (Quake, Sundering Blow, a boss's stomp): 8 frames, 48x48
    assets/fx/earth/earth_clod.png    the shot: a tumbling clod of sand and grit, 4 frames, 16x16 (round: never turned)
    assets/fx/earth/earth_swirl.png   a whirl of blown sand (Sandstorm): 4 frames, 16x16 (round: never turned)

Earth's grammar: matter, not light. Blocky rock lit from the top left (the lit face takes the
ramp's second step, the shade its fourth, a pale highlight on the edges facing the light, the
dark edge around), chunks flung on arcs that fall and stay as pebbles, a dust cloud (the
residue) that rolls low and settles, dark cracks in the ground. Nothing glows.
"""
import math
import os
import random
import sys

from vfxkit import RESIDUE, ROOT, Element, Sheet, clean, outline, point_in_polygon, preview

PALE, SAND, BROWN, SHADE, EDGE = 0, 1, 2, 3, 4
LIGHT = (-0.6, -0.8)
OUT = os.path.join(ROOT, "assets", "fx", "earth")


def face_shade(normal: tuple) -> int:
    d = normal[0] * LIGHT[0] + normal[1] * LIGHT[1]
    if d > 0.3:
        return SAND
    if d > -0.3:
        return BROWN
    return SHADE


def spike(cell, bx: float, by: float, height: float, width: float, lean: float, shown: float = 1.0, tip_glint: bool = True) -> list:
    """A rock spike standing on (bx, by): a blunt-tipped wedge leaning by `lean`, its left face
    lit, its right face in shade, a notch of a facet on each side; `shown` of it out of the
    ground (it thrusts up)."""
    h = height * shown
    if h < 1.0:
        return []
    hw = width * 0.5
    top = (bx + lean * h, by - h)
    pts = [(bx - hw, by + 0.5), (bx + hw, by + 0.5), (bx + hw * 0.55 + lean * h * 0.7, by - h * 0.62),
           (top[0] + 0.9, top[1] + 1.2), top, (top[0] - 0.8, top[1] + 1.6), (bx - hw * 0.6 + lean * h * 0.55, by - h * 0.5)]
    ridge = lambda y: bx + lean * (by - y) + hw * 0.1  # noqa: E731 the split of the faces
    filled = []
    for y in range(cell.h):
        for x in range(cell.w):
            px, py = x + 0.5, y + 0.5
            if point_in_polygon(px, py, pts):
                lit = px < ridge(py)
                index = SAND if lit else (BROWN if px < ridge(py) + hw * 0.45 else SHADE)
                if py > by - h * 0.25 and not lit:
                    index = SHADE  # the foot in its own shadow
                cell.set(x, y, index)
                filled.append((x, y))
    # The highlight: the lit edge toward the light and the tip.
    for x, y in filled:
        if cell.get(x - 1, y) is None and cell.get(x, y) == SAND and y < by - h * 0.3:
            cell.set(x, y, PALE)
    if tip_glint and h >= 6:
        cell.set(top[0], top[1] + 1, PALE)
    return filled


def spikes(cell, items: list, base: float, shown: float = 1.0, tip_glint: bool = True) -> None:
    """Several spikes (dx, height, width, lean) standing on `base`, outlined together on their
    own layer, then laid over `cell` (so the dust and the cracks keep their colors)."""
    from vfxkit import Cell
    layer = Cell(cell.w, cell.h)
    # The heap of broken ground they rise from (not a flat line: a mound of rubble).
    if shown >= 0.5 and items:
        left = min(x - w * 0.6 for x, h, w, lean in items)
        right = max(x + w * 0.6 for x, h, w, lean in items)
        mid, half = (left + right) * 0.5, (right - left) * 0.5
        for y in range(layer.h):
            for x in range(layer.w):
                dx, dy = (x + 0.5 - mid) / max(half, 1.0), (y + 0.5 - base) / 3.4
                if dx * dx + dy * dy <= 1.0 and y + 0.5 <= base + 1.0:
                    layer.set(x, y, SHADE if (x + y) % 3 else BROWN)
    for i, (x, h, w, lean) in enumerate(items):
        spike(layer, x, base, h, w, lean, shown if i == 0 else min(1.0, shown * 1.2), tip_glint)
    outline(layer, EDGE)
    for i, (x, h, w, lean) in enumerate(items):
        hh = h * (shown if i == 0 else min(1.0, shown * 1.2))
        if tip_glint and hh >= 6:
            layer.set(x + lean * hh, base - hh + 1.0, PALE)
        # the lit face keeps a pale edge through the outline
        for y in range(int(base - hh + 2), int(base - hh * 0.3)):
            lx = int(x + lean * (base - y) - w * 0.25)
            if layer.get(lx, y) == SAND:
                layer.set(lx, y, PALE)
    for x, y in layer.opaque():
        cell.set(x, y, layer.get(x, y))


def rock(cell, x: float, y: float, size: int) -> None:
    """A chunk of rock: 1 to 4 pixels across, lit from the top left."""
    x, y = int(round(x)), int(round(y))
    if size <= 1:
        cell.set(x, y, BROWN)
        return
    if size == 2:
        for dx, dy, i in ((0, 0, SAND), (1, 0, BROWN), (0, 1, BROWN), (1, 1, SHADE)):
            cell.set(x + dx, y + dy, i)
        return
    shape = [(1, 0), (2, 0), (0, 1), (1, 1), (2, 1), (3, 1), (0, 2), (1, 2), (2, 2), (3, 2), (1, 3), (2, 3)] if size >= 4 else \
        [(0, 0), (1, 0), (0, 1), (1, 1), (2, 1), (1, 2), (2, 2)]
    for dx, dy in shape:
        light = dx + dy
        cell.set(x + dx, y + dy, PALE if light == 0 or (light == 1 and size >= 4 and dy == 0) else SAND if light <= 2 else BROWN if light <= 3 else SHADE)
    # its dark edge on the lower right
    for dx, dy in shape:
        if (dx + 1, dy) not in shape or (dx, dy + 1) not in shape:
            if dx + dy >= 3:
                cell.set(x + dx, y + dy, EDGE)


def dust(cell, cx: float, cy: float, rx: float, ry: float, seed: float = 0.0, under: bool = True) -> None:
    """A billowing cloud of dust (the residue), its underside in the ramp's brown."""
    for y in range(cell.h):
        for x in range(cell.w):
            px, py = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            a = math.atan2(py, px)
            r = 1.0 + 0.2 * math.sin(4 * a + seed) + 0.1 * math.sin(7 * a + seed * 1.7)
            d = math.hypot(px, py)
            if d <= r:
                if cell.get(x, y) is None:
                    cell.set(x, y, BROWN if under and py > 0.45 * r and d > 0.7 * r else RESIDUE)


def crack(cell, x0: float, y0: float, angle: float, length: float, rng: random.Random, index: int = SHADE) -> None:
    """A crack in the ground: a jagged line of the dark steps, squashed (the floor is seen from
    above at an angle), forking once."""
    x, y = x0, y0
    a = angle
    for i in range(int(length)):
        a += rng.uniform(-0.3, 0.3)
        x += math.cos(a)
        y += math.sin(a) * 0.55
        cell.set(x, y, EDGE if i < length * 0.6 else index)
        if i == int(length * 0.5) and length > 5:
            crack(cell, x, y, a + rng.choice((-0.9, 0.9)), length * 0.4, rng, index)


def thin(cell, keep: int, only=(RESIDUE,)) -> None:
    bayer = (0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5)
    for x, y in cell.opaque():
        if cell.get(x, y) in only and bayer[(y % 4) * 4 + x % 4] >= 16 // keep:
            cell.px[y][x] = None


def build_spike(rng: random.Random) -> Sheet:
    """A cluster of rock spikes bursting from the ground (its foot at the bottom middle):
    the ground cracks and puffs, the spikes thrust up fast, hold, crack, crumble into chunks
    and dust, and leave a stump of rubble."""
    sheet = Sheet(cell=(16, 24), frames=8, rows=3)
    clusters = [
        [(7.5, 19, 8.0, 0.1), (3.2, 11, 6.0, -0.4), (12.6, 8, 5.4, 0.45)],
        [(9.0, 17, 8.0, -0.12), (3.8, 10, 6.0, -0.45)],
        [(7.0, 15, 7.4, 0.2), (11.8, 12, 6.0, 0.35), (3.0, 7, 5.0, -0.55)],
    ]
    base = 22.0
    for row, cluster in enumerate(clusters):
        for frame in range(8):
            cell = sheet.cell(frame, row)
            if frame == 0:
                # The ground breaks: dark cracks and a little grit, nothing bright yet.
                dust(cell, 8, base - 1, 4.0, 1.6, row, under=False)
                thin(cell, 2)
                for k in range(3):
                    crack(cell, 8, base, math.pi * (0.1 + 0.4 * k) + rng.uniform(-0.2, 0.2), 4 + k, rng)
                rock(cell, 7, base - 2, 2)
                continue
            if frame < 5:
                if frame <= 2:
                    dust(cell, 8, base - 0.5, 7.5, 2.4 if frame == 1 else 1.8, row + frame)
                spikes(cell, cluster, base, (0.6, 1.05, 1.0, 1.0)[frame - 1])
                if frame == 1:
                    for k in range(4):
                        rock(cell, 8 + rng.uniform(-7, 6), base - rng.uniform(10, 20), 2 if k < 2 else 1)
                elif frame == 2:
                    for k in range(2):
                        rock(cell, 8 + rng.choice((-7, 6)), base - rng.uniform(3, 8), 1)
            elif frame == 5:
                # Cracking: dark seams across, the tip knocked off.
                spikes(cell, [(x, h * (0.82 if i == 0 else 1.0), w, lean) for i, (x, h, w, lean) in enumerate(cluster)], base, 1.0, tip_glint=False)
                for i, (x0, h, w, lean) in enumerate(cluster[:2]):
                    y0 = base - h * 0.45
                    for k in range(-2, 3):
                        x = x0 + lean * (base - y0) + k
                        if cell.get(int(x), int(y0 + k * 0.5)) is not None:
                            cell.set(x, y0 + k * 0.5, EDGE)
                rock(cell, cluster[0][0] + cluster[0][3] * 16, base - 18, 2)
            else:
                # Crumbled: stumps, chunks falling, dust rolling out.
                stump = 0.4 if frame == 6 else 0.2
                dust(cell, 8, base - 1, 8.0, 2.6 if frame == 6 else 2.0, row + frame, under=frame == 6)
                if frame == 7:
                    thin(cell, 2)
                spikes(cell, [(x, h * stump, w, lean) for x, h, w, lean in cluster], base, 1.0, tip_glint=False)
                if frame == 6:
                    for k in range(5):
                        rock(cell, 8 + rng.uniform(-7, 6), base - rng.uniform(6, 15), 3 if k == 0 else 2 if k < 3 else 1)
                else:
                    for k in range(4):
                        rock(cell, 8 + rng.uniform(-7, 6), base - rng.uniform(0, 3), 2 if k == 0 else 1)
    return sheet


def build_impact(rng: random.Random) -> Sheet:
    """A clod landing: it bursts into grit and a few chunks thrown up on arcs, a puff of dust
    that rolls out low and settles; pebbles stay a moment."""
    sheet = Sheet(cell=(32, 32), frames=6, rows=1)
    cx, cy = 16.0, 18.0
    chunks = [(side * rng.uniform(4, 10), rng.uniform(9, 15), s) for side, s in ((-1, 3), (1, 2), (1, 3), (-1, 1), (1, 1))]
    arcs = [(0.0, 0.0), (0.45, 0.8), (0.75, 1.0), (1.0, 0.75), (1.2, 0.3), (1.3, 0.0)]
    for frame in range(6):
        cell = sheet.cell(frame)
        t, lift = arcs[frame]
        if frame == 0:
            dust(cell, cx, cy + 1, 5.0, 2.5, 0.5)
            rock(cell, cx - 2, cy - 2, 4)
        else:
            rx = 5.0 + frame * 1.6
            ry = 3.0 + frame * 0.7
            dust(cell, cx, cy - frame * 0.6, rx, ry, frame, under=frame < 4)
            if frame >= 4:
                thin(cell, 2 if frame == 4 else 3)
            for i, (dx, up, size) in enumerate(chunks):
                x = cx + dx * t
                y = cy - up * lift - 1 + (frame >= 4) * 2
                rock(cell, x, y, size if frame < 5 else 1)
        for x, y in ((cx - 4, cy + 3), (cx + 3, cy + 4)):
            if frame >= 2:
                cell.set(x, y, SHADE)
    return sheet


def build_burst(rng: random.Random) -> Sheet:
    """The ground bursting (a quake, a crushing blow, a boss stamping): the floor cracks open,
    slabs and chunks are thrown up on arcs, a dust cloud rolls out low and wide; the chunks
    fall back as rubble and the cracks stay a moment (the sheet's last frame lingers)."""
    sheet = Sheet(cell=(48, 48), frames=8, rows=1)
    cx, cy = 24.0, 32.0
    cracks = [(math.radians(a + rng.uniform(-12, 12)), rng.uniform(10, 16)) for a in range(10, 370, 72)]
    chunks = [(math.radians(a + rng.uniform(-25, 25)), rng.uniform(7, 19), rng.uniform(5, 16), s)
              for a, s in zip(range(-160, 200, 52), (4, 2, 3, 1, 2, 4, 2))]
    for frame in range(8):
        cell = sheet.cell(frame)
        local = random.Random(frame * 7 + 3)
        # The cracks under everything, from the first frame on (growing for two frames).
        grow = min(1.0, 0.5 + frame * 0.35)
        for a, ln in cracks:
            crack(cell, cx + math.cos(a) * 2, cy + math.sin(a) * 1, a, ln * grow, random.Random(int(a * 100)))
        if frame == 0:
            # The heave: a slab pushed up, a ring of grit.
            dust(cell, cx, cy + 1, 10.0, 3.0, 0.3)
            spikes(cell, [(cx - 1, 8, 10, 0.1), (cx + 5, 5, 7, 0.45)], cy + 1)
            continue
        t = frame / 7.0
        for i, (a, out, up, size) in enumerate(chunks):
            # Each on its own arc: heavy ones low and short, small ones high, out of step.
            k = min(frame / (4.0 + (i % 3) * 0.7), 1.0)
            reach = out * k
            height = up * 4 * k * (1 - k) * (1.6 if size <= 2 else 0.9)
            x = cx + math.cos(a) * reach * 1.3
            y = cy + math.sin(a) * reach * 0.5 - height
            if frame >= 5:
                y = cy + math.sin(a) * reach * 0.5 + 1
                size = min(size, 2) if frame == 5 else 1 + (size >= 4)
            rock(cell, x, y, size)
        if frame <= 2:
            spikes(cell, [(cx - 1, 11 - frame * 3, 10, 0.1)], cy + 1, tip_glint=frame == 1)
        rx = 11.0 + frame * 3.4
        ry = 4.5 + frame * 1.0
        if frame < 6:
            dust(cell, cx, cy - 2 - frame * 0.8, rx, ry, frame * 1.3)
            dust(cell, cx - rx * 0.4, cy - 6 - frame, rx * 0.35, ry * 0.8, frame)
            if frame >= 4:
                thin(cell, 6 - frame)
        else:
            dust(cell, cx, cy - 6, rx * 0.8, ry * 0.6, frame, under=False)
            thin(cell, 3 if frame == 6 else 4)
        _ = local
    return sheet


def build_clod() -> Sheet:
    """A clod of sand and grit tumbling: a lumpy round body lit from the top left, grains on it
    turning from frame to frame (redrawn, never rotated), a few grains falling off behind."""
    sheet = Sheet(cell=(16, 16), frames=4, rows=1)
    cx, cy, r = 8.0, 8.0, 4.2
    for frame in range(4):
        cell = sheet.cell(frame)
        spin = frame * math.tau / 4
        for y in range(16):
            for x in range(16):
                px, py = x + 0.5 - cx, y + 0.5 - cy
                a = math.atan2(py, px)
                edge = r * (1.0 + 0.12 * math.sin(3 * a + spin) + 0.08 * math.sin(5 * a - spin))
                d = math.hypot(px, py)
                if d <= edge:
                    light = (px * LIGHT[0] + py * LIGHT[1]) / max(edge, 0.1)
                    index = PALE if light > 0.55 and d > edge * 0.45 else SAND if light > 0.0 else BROWN if light > -0.5 else SHADE
                    # Grains and grit: a few darker specks that turn with the clod.
                    gx = math.cos(spin) * px - math.sin(spin) * py
                    gy = math.sin(spin) * px + math.cos(spin) * py
                    if (int(gx + 9) * 3 + int(gy + 9) * 5) % 7 == 0 and index in (SAND, BROWN):
                        index += 1
                    cell.set(x, y, index)
        outline(cell, EDGE)
        clean(cell)
        for k in range(3):
            a = spin + k * 2.1
            cell.set(cx + math.cos(a) * 6.6, cy + math.sin(a) * 6.6 + 1, SAND if k == 0 else BROWN)
    return sheet


def build_swirl() -> Sheet:
    """A whirl of blown sand (Sandstorm's gusts): a ragged ball of dust with a spiral of grains
    turning in it, its underside in shade, grains thrown off around it. Round: it is redrawn
    turning from frame to frame, never rotated, and the shot's own trail says where it goes."""
    sheet = Sheet(cell=(16, 16), frames=4, rows=1)
    cx, cy, r = 8.0, 8.0, 5.0
    for frame in range(4):
        cell = sheet.cell(frame)
        spin = frame * math.tau / 4
        for y in range(16):
            for x in range(16):
                px, py = x + 0.5 - cx, y + 0.5 - cy
                a = math.atan2(py, px)
                edge = r * (1.0 + 0.16 * math.sin(3 * a - spin) + 0.1 * math.sin(5 * a + spin))
                d = math.hypot(px, py)
                if d <= edge:
                    under = (px * 0.5 + py) / max(edge, 0.1) > 0.45 and d > edge * 0.6
                    cell.set(x, y, BROWN if under else RESIDUE)
        # Its rim: brown, darker underneath, so it reads on the desert's own sand.
        rim = [(x, y) for x, y in cell.opaque() if any(cell.get(x + dx, y + dy) is None for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
        for x, y in rim:
            cell.set(x, y, SHADE if y + 0.5 > cy + 1 else BROWN)
        # Two arms of grains spiralling in it: one pale, one dark.
        for arm, colors in ((0.0, (PALE, SAND)), (math.pi, (SHADE, BROWN))):
            for i in range(20):
                theta = i * 0.42
                rr = 0.8 + theta * 0.6
                if rr > r - 1.2:
                    break
                x = cx + math.cos(theta + spin + arm) * rr
                y = cy + math.sin(theta + spin + arm) * rr * 0.85
                cell.set(x, y, colors[0] if i < 7 else colors[1])
        # Grains thrown off.
        for k in range(3):
            a = spin * 1.3 + k * 2.2
            cell.set(cx + math.cos(a) * 6.8, cy + math.sin(a) * 6.0, SAND if k == 0 else BROWN)
    return sheet


def main() -> None:
    earth = Element.load("earth")
    rng = random.Random(5)
    sheets = {
        "earth_spike": build_spike(rng),
        "earth_impact": build_impact(rng),
        "earth_burst": build_burst(rng),
        "earth_clod": build_clod(),
        "earth_swirl": build_swirl(),
    }
    preview_dir = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
    for name, sheet in sheets.items():
        sheet.save(os.path.join(OUT, name + ".png"), earth)
        if preview_dir:
            os.makedirs(preview_dir, exist_ok=True)
            zoom = 4 if sheet.cw * sheet.frames > 200 else 6
            if sheet.rows > 4:
                image = sheet.image(earth)
                preview(image.crop((0, 0, image.width, sheet.ch * 6)), os.path.join(preview_dir, name + "_x6.png"), zoom, (sheet.cw, sheet.ch))
            else:
                sheet.preview(os.path.join(preview_dir, name + "_x6.png"), earth, zoom=zoom)
        print("wrote", os.path.join("assets", "fx", "earth", name + ".png"))


if __name__ == "__main__":
    main()
