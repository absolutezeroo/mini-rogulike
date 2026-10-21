"""Palette-locked pixel art for the game's effects (docs/vfx.md).

Everything here works at the art's own resolution (one image pixel = one art pixel, drawn 2x in
the game), with hard alpha and only the colors of one element's ramp (data/vfx/elements/*.tres):

    from vfxkit import Element, Sheet, polygon, outline
    frost = Element.load("frost")            # ramp[0] = core ... ramp[-1] = edge, + residue
    sheet = Sheet(cell=(16, 16), frames=2, rows=16)
    cell = sheet.cell(0, 3)                   # a Cell: set(x, y, index), get, fill_polygon...
    sheet.save("assets/fx/frost/frost_shard.png", frost)
    sheet.preview("/tmp/shard_x6.png", frost) # zoomed, on a dark and a light floor

Cells hold ramp indices (0 = core, len-1 = edge, RESIDUE for the element's residue, None for
empty), so a drawing can't drift off the palette, and the same drawing can be saved in another
element's ramp. `python3 tools/vfx/check.py` validates a sheet; `recolor.py` palette-swaps one.
"""
from __future__ import annotations

import math
import os
import re
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
RESIDUE = -1  # index of the element's residue color (mist, smoke, dust)
DARK_FLOOR = (36, 28, 40)
LIGHT_FLOOR = (196, 170, 120)


def _floats(text: str) -> list[float]:
    return [float(v) for v in re.findall(r"-?[0-9.]+", text)]


class Element:
    """An element's colors, read from data/vfx/elements/<id>.tres."""

    def __init__(self, element_id: str, ramp: list[tuple], residue: tuple | None):
        self.id = element_id
        self.ramp = ramp
        self.residue = residue

    @staticmethod
    def load(element_id: str) -> "Element":
        path = os.path.join(ROOT, "data", "vfx", "elements", element_id + ".tres")
        text = open(path, encoding="utf-8").read()
        values = _floats(re.search(r"^ramp = PackedColorArray\(([^)]*)\)", text, re.M).group(1))
        ramp = [tuple(round(c * 255) for c in values[i:i + 3]) for i in range(0, len(values), 4)]
        residue = None
        match = re.search(r"^residue = Color\(([^)]*)\)", text, re.M)
        if match:
            r, g, b, a = _floats(match.group(1))
            if a > 0:
                residue = (round(r * 255), round(g * 255), round(b * 255))
        return Element(element_id, ramp, residue)

    def rgb(self, index: int) -> tuple:
        if index == RESIDUE:
            return self.residue if self.residue else self.ramp[-1]
        return self.ramp[max(0, min(index, len(self.ramp) - 1))]

    def colors(self) -> set:
        allowed = set(self.ramp)
        if self.residue:
            allowed.add(self.residue)
        return allowed


class Cell:
    """One frame: a grid of ramp indices (None = transparent)."""

    def __init__(self, width: int, height: int):
        self.w = width
        self.h = height
        self.px = [[None] * width for _ in range(height)]

    def inside(self, x: int, y: int) -> bool:
        return 0 <= x < self.w and 0 <= y < self.h

    def set(self, x: int, y: int, index) -> None:
        x, y = int(round(x)), int(round(y))
        if self.inside(x, y):
            self.px[y][x] = index

    def get(self, x: int, y: int):
        return self.px[y][x] if self.inside(x, y) else None

    def fill_polygon(self, points: list[tuple], index) -> list[tuple]:
        """Fills the pixels whose centers fall inside `points`; returns them."""
        filled = []
        for y in range(self.h):
            for x in range(self.w):
                if point_in_polygon(x + 0.5, y + 0.5, points):
                    self.px[y][x] = index
                    filled.append((x, y))
        return filled

    def opaque(self) -> list[tuple]:
        return [(x, y) for y in range(self.h) for x in range(self.w) if self.px[y][x] is not None]


class Sheet:
    """Frames in columns, rows of directions or variants."""

    def __init__(self, cell: tuple, frames: int, rows: int = 1):
        self.cw, self.ch = cell
        self.frames = frames
        self.rows = rows
        self.cells = [[Cell(self.cw, self.ch) for _ in range(frames)] for _ in range(rows)]

    def cell(self, frame: int, row: int = 0) -> Cell:
        return self.cells[row][frame]

    def image(self, element: Element) -> Image.Image:
        image = Image.new("RGBA", (self.cw * self.frames, self.ch * self.rows), (0, 0, 0, 0))
        pixels = image.load()
        for row in range(self.rows):
            for frame in range(self.frames):
                cell = self.cells[row][frame]
                for y in range(self.ch):
                    for x in range(self.cw):
                        index = cell.px[y][x]
                        if index is not None:
                            pixels[frame * self.cw + x, row * self.ch + y] = element.rgb(index) + (255,)
        return image

    def save(self, path: str, element: Element) -> None:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        self.image(element).save(path)

    def preview(self, path: str, element: Element, zoom: int = 6) -> None:
        preview(self.image(element), path, zoom, (self.cw, self.ch))


def preview(image: Image.Image, path: str, zoom: int = 6, grid: tuple | None = None) -> None:
    """`image` zoomed `zoom` times (nearest), over a dark floor then a light one, with a faint
    line between cells, to judge it the way it will be seen."""
    w, h = image.size
    out = Image.new("RGB", (w * zoom, h * zoom * 2 + zoom), (0, 0, 0))
    for i, floor in enumerate((DARK_FLOOR, LIGHT_FLOOR)):
        back = Image.new("RGBA", (w, h), floor + (255,))
        back.alpha_composite(image)
        big = back.resize((w * zoom, h * zoom), Image.NEAREST).convert("RGB")
        if grid:
            px = big.load()
            for gx in range(0, w, grid[0]):
                for y in range(h * zoom):
                    px[gx * zoom, y] = tuple(min(255, c + 30) for c in px[gx * zoom, y])
            for gy in range(0, h, grid[1]):
                for x in range(w * zoom):
                    px[x, gy * zoom] = tuple(min(255, c + 30) for c in px[x, gy * zoom])
        out.paste(big, (0, i * (h * zoom + zoom)))
    out.save(path)


def point_in_polygon(x: float, y: float, points: list[tuple]) -> bool:
    inside = False
    n = len(points)
    for i in range(n):
        x1, y1 = points[i]
        x2, y2 = points[(i + 1) % n]
        if (y1 > y) != (y2 > y):
            cross = x1 + (y - y1) * (x2 - x1) / (y2 - y1)
            if x < cross:
                inside = not inside
    return inside


def rotate(points: list[tuple], angle: float, center: tuple = (0.0, 0.0)) -> list[tuple]:
    c, s = math.cos(angle), math.sin(angle)
    return [(center[0] + x * c - y * s, center[1] + x * s + y * c) for x, y in points]


def outline(cell: Cell, index, diagonal: bool = False) -> None:
    """Turns every opaque pixel touching a transparent one (or the cell's border) into `index`:
    the dark edge that keeps an effect readable on bright floors."""
    edge = []
    for x, y in cell.opaque():
        near = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        if diagonal:
            near += [(1, 1), (-1, -1), (1, -1), (-1, 1)]
        if any(cell.get(x + dx, y + dy) is None for dx, dy in near):
            edge.append((x, y))
    for x, y in edge:
        cell.px[y][x] = index


def clean(cell: Cell) -> None:
    """Removes lone pixels (no opaque 4-neighbour) and fills one-pixel holes: the noise a
    rasterizer leaves and a pixel artist never would."""
    for x, y in cell.opaque():
        if all(cell.get(x + dx, y + dy) is None for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            cell.px[y][x] = None
    for y in range(cell.h):
        for x in range(cell.w):
            if cell.px[y][x] is None:
                near = [cell.get(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))]
                if all(n is not None for n in near):
                    cell.px[y][x] = max(near)
