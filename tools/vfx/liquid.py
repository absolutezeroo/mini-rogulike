"""Shapes for the soft kits (poison, blood, spirit): globs, drops, lumps of gas, strokes and
rings, drawn at the art's own resolution on an element's ramp (docs/vfx.md). The hard, faceted
shapes of frost live in frost.py; these are round and wet.

Everything takes a vfxkit Cell and ramp indices. Shapes that point somewhere are described in a
local frame (u forward along `angle`, v to its right) and rasterized per direction, so a 16-row
sheet is drawn, never rotated; the light stays top-left in every row.
"""
import math

LIGHT = (-0.6, -0.8)  # unit vector toward the light: the top left, as for every sheet


def lit(normal: tuple) -> float:
    """How much a surface facing `normal` (screen space) faces the light, -1 to 1."""
    length = math.hypot(normal[0], normal[1]) or 1.0
    return (normal[0] * LIGHT[0] + normal[1] * LIGHT[1]) / length


def to_world(angle: float, u: float, v: float, center: tuple) -> tuple:
    """A point of the local frame (u forward along `angle`, v to its right) in cell space."""
    ca, sa = math.cos(angle), math.sin(angle)
    return (center[0] + u * ca - v * sa, center[1] + u * sa + v * ca)


def disc(cell, cx: float, cy: float, r: float, index) -> list:
    """Fills the pixels whose centers are within `r` of (cx, cy); returns them."""
    filled = []
    for y in range(int(cy - r - 1), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            if cell.inside(x, y) and (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
                cell.set(x, y, index)
                filled.append((x, y))
    return filled


def ring(cell, cx: float, cy: float, r: float, index, thickness: float = 1.0, keep=None) -> None:
    """A hollow ring of whole pixels (stepped like a hand-drawn circle). `keep(angle)` says
    which parts of it are drawn (a ring breaking up)."""
    for y in range(int(cy - r - 2), int(cy + r + 3)):
        for x in range(int(cx - r - 2), int(cx + r + 3)):
            if not cell.inside(x, y):
                continue
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if r - thickness < d <= r:
                if keep is None or keep(math.atan2(y + 0.5 - cy, x + 0.5 - cx)):
                    cell.set(x, y, index)


def tube(cell, points: list, widths: list, shade) -> dict:
    """A soft shape swept along `points` (a sampled center line in cell space) with a radius
    per point: a glob's tail, a fang, a flame's tongue. Each pixel inside is painted
    `shade(normal, s)`, where `normal` points from the nearest center point out to the pixel
    and `s` is that point's place along the line (0 = first). Returns {pixel: s}."""
    inside = {}
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    reach = max(widths) + 1
    for y in range(int(min(ys) - reach), int(max(ys) + reach + 1)):
        for x in range(int(min(xs) - reach), int(max(xs) + reach + 1)):
            if not cell.inside(x, y):
                continue
            px, py = x + 0.5, y + 0.5
            best = None
            for i, (cx, cy) in enumerate(points):
                d = math.hypot(px - cx, py - cy) - widths[i]
                if d <= 0.0 and (best is None or d < best[0]):
                    best = (d, i)
            if best is not None:
                i = best[1]
                normal = (px - points[i][0], py - points[i][1])
                cell.set(x, y, shade(normal, i / max(len(points) - 1, 1)))
                inside[(x, y)] = i / max(len(points) - 1, 1)
    return inside


def lumps(cell, blobs: list, shade, fade: float = 1.0, seed: int = 0) -> dict:
    """A cloud of overlapping round lumps [(cx, cy, r), ...]: each pixel takes the shade of
    the lump it is deepest in (`shade(normal, depth, top)`, `top` = how high in the cloud),
    `fade` < 1 drops pixels by ordered dithering (a cloud thinning out). Returns {pixel: depth}."""
    bayer = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
    if not blobs:
        return {}
    top = min(b[1] - b[2] for b in blobs)
    bottom = max(b[1] + b[2] for b in blobs)
    found = {}
    for y in range(cell.h):
        for x in range(cell.w):
            px, py = x + 0.5, y + 0.5
            best = None
            for cx, cy, r in blobs:
                depth = r - math.hypot(px - cx, py - cy)
                if depth >= 0 and (best is None or depth > best[0]):
                    best = (depth, (px - cx, py - cy))
            if best is None:
                continue
            threshold = (bayer[((y + seed) & 3) * 4 + ((x + seed) & 3)] + 0.5) / 16.0
            if fade < 1.0 and fade <= threshold:
                continue
            height = (py - top) / max(bottom - top, 1.0)
            cell.set(x, y, shade(best[1], best[0], height))
            found[(x, y)] = best[0]
    return found


def drop(cell, x: float, y: float, big: bool, light, dark) -> None:
    """A falling drop: a pixel and the one under it, or a 2x2 lit at its top left."""
    x, y = int(x), int(y)
    if big:
        cell.set(x, y, light)
        cell.set(x + 1, y, dark)
        cell.set(x, y + 1, dark)
        cell.set(x + 1, y + 1, dark)
    else:
        cell.set(x, y, light)
        cell.set(x, y + 1, dark)


def bezier(a: tuple, control: tuple, b: tuple, steps: int) -> list:
    """Points along a quadratic curve from `a` to `b`."""
    out = []
    for i in range(steps + 1):
        t = i / steps
        out.append(((1 - t) ** 2 * a[0] + 2 * (1 - t) * t * control[0] + t * t * b[0],
                    (1 - t) ** 2 * a[1] + 2 * (1 - t) * t * control[1] + t * t * b[1]))
    return out


def arc_points(center: tuple, radius: float, start: float, end: float, steps: int) -> list:
    """Points along a circle's arc from angle `start` to `end` (radians)."""
    return [(center[0] + radius * math.cos(start + (end - start) * i / steps),
             center[1] + radius * math.sin(start + (end - start) * i / steps)) for i in range(steps + 1)]


def bubble(cell, x: int, y: int, size: int, rim, shine) -> None:
    """A bubble: a hollow ring of whole pixels (3 wide: a diamond of 4, 4 wide: a rounded
    square of 8) and a shine on its top left inside the rim."""
    if size <= 1:
        cell.set(x, y, rim)
        return
    if size == 2:
        for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
            cell.set(x + dx, y + dy, rim)
        cell.set(x - 1, y - 1, shine)  # the light catches its rim
        return
    for dx, dy in ((0, -1), (1, -1), (-1, 0), (2, 0), (-1, 1), (2, 1), (0, 2), (1, 2)):
        cell.set(x + dx, y + dy, rim)
    cell.set(x, y, shine)


def pop(cell, x: int, y: int, spread: int, index) -> None:
    """A bubble bursting: four pixels flung out on the diagonals."""
    for dx, dy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        cell.set(x + dx * spread, y + dy * spread, index)
