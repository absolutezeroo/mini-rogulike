"""Strokes on the art's grid for the element kits (storm forks, holy rays, shadow curls, arcane
orbits): straight lines and jagged paths of whole pixels, written into a vfxkit Cell as ramp
indices. Shared by storm.py, holy.py, shadow.py and arcane.py.
"""
from __future__ import annotations

import math
import random


def line(x0: float, y0: float, x1: float, y1: float) -> list[tuple]:
    """The pixels of a straight line (Bresenham), both ends included."""
    x0, y0, x1, y1 = int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    out = []
    while True:
        out.append((x0, y0))
        if x0 == x1 and y0 == y1:
            return out
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def path(points: list[tuple]) -> list[tuple]:
    """The pixels of a polyline, without repeats, in order."""
    out: list[tuple] = []
    for a, b in zip(points, points[1:]):
        for p in line(a[0], a[1], b[0], b[1]):
            if not out or out[-1] != p:
                if p not in out:
                    out.append(p)
    return out


def jag(start: tuple, end: tuple, rng: random.Random, step: float = 5.0, spread: float = 3.0) -> list[tuple]:
    """A lightning-like polyline from `start` to `end`: knees every `step` pixels or so, each
    pushed sideways by up to `spread`, the ends exact."""
    length = math.dist(start, end)
    count = max(int(length / step), 1)
    ux, uy = (end[0] - start[0]) / max(length, 1e-6), (end[1] - start[1]) / max(length, 1e-6)
    px, py = -uy, ux
    points = [start]
    side = rng.choice((-1, 1))
    for i in range(1, count):
        t = i / count + rng.uniform(-0.25, 0.25) / count
        off = side * rng.uniform(spread * 0.4, spread)
        side = -side if rng.random() < 0.75 else side
        points.append((start[0] + (end[0] - start[0]) * t + px * off, start[1] + (end[1] - start[1]) * t + py * off))
    points.append(end)
    return points


def plot(cell, pixels: list[tuple], index, only_empty: bool = False) -> None:
    for x, y in pixels:
        if not only_empty or cell.get(x, y) is None:
            cell.set(x, y, index)


def widen(cell, pixels: list[tuple], index, horizontal: bool = True, vertical: bool = False) -> None:
    """Paints the neighbours of `pixels` (left/right, up/down) where nothing is yet: a glow."""
    near = []
    if horizontal:
        near += [(1, 0), (-1, 0)]
    if vertical:
        near += [(0, 1), (0, -1)]
    for x, y in pixels:
        for dx, dy in near:
            if cell.get(x + dx, y + dy) is None and cell.inside(x + dx, y + dy):
                cell.set(x + dx, y + dy, index)


def rim(cell, index, diagonal: bool = False) -> None:
    """A one-pixel outline *outside* the drawing (frost's `outline` turns the drawing's own edge
    dark; thin strokes need theirs kept and a rim around them)."""
    around = set()
    near = [(1, 0), (-1, 0), (0, 1), (0, -1)]
    if diagonal:
        near += [(1, 1), (-1, -1), (1, -1), (-1, 1)]
    for x, y in cell.opaque():
        for dx, dy in near:
            if cell.inside(x + dx, y + dy) and cell.get(x + dx, y + dy) is None:
                around.add((x + dx, y + dy))
    for x, y in around:
        cell.set(x, y, index)


def dithered(pixels: list[tuple], amount: float, salt: int = 0) -> list[tuple]:
    """The pixels kept by a 4x4 ordered dither at `amount` (1 = all)."""
    bayer = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
    return [(x, y) for x, y in pixels if amount > (bayer[((y + salt) & 3) * 4 + ((x + salt) & 3)] + 0.5) / 16.0]


def glint(cell, x: int, y: int, arm: int, index, core=None) -> None:
    """The holy 4-point glint: a plus whose vertical arms are longer than its horizontal ones."""
    x, y = int(round(x)), int(round(y))
    cell.set(x, y, index)
    for i in range(1, arm + 1):
        cell.set(x, y - i, index)
        cell.set(x, y + i, index)
    for i in range(1, max(arm - 1, 1) + 1):
        cell.set(x - i, y, index)
        cell.set(x + i, y, index)
    if core is not None:
        cell.set(x, y, core)


def diamond(cell, x: int, y: int, r: int, index, fill=None) -> None:
    """The arcane rune-glint: a hollow rhombus of radius `r` (|dx| + |dy| == r), filled with
    `fill` inside when given."""
    x, y = int(round(x)), int(round(y))
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            d = abs(dx) + abs(dy)
            if d == r:
                cell.set(x + dx, y + dy, index)
            elif d < r and fill is not None:
                cell.set(x + dx, y + dy, fill)


def ellipse(cx: float, cy: float, rx: float, ry: float, steps: int = 0) -> list[tuple]:
    """The pixels of a stepped ellipse outline (a ring lying on the ground)."""
    steps = steps or int(max(rx, ry) * 8)
    pts = []
    for i in range(steps):
        a = math.tau * i / steps
        p = (math.floor(cx + math.cos(a) * rx + 0.5), math.floor(cy + math.sin(a) * ry + 0.5))
        if p not in pts:
            pts.append(p)
    return pts
