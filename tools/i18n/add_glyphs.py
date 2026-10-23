#!/usr/bin/env python3
"""Adds the glyphs the game needs that the pixel font (assets/fonts/PixelOperator8.ttf, Pixel
Operator 8 by Jayvee Enaguas, CC0) lacks: the controls' prompt glyphs (PlayStation's ✕ ○ □ △ and
the arrows ← → ↑ ↓) and the narrow no-break space (U+202F), drawn on its 8-pixel grid (100 units
a pixel, capitals 7 pixels high, a pixel of space on the left) in its own style. The font already
has every French letter and sign (œ Œ « » Î Ï … – — × and the no-break space).
Runs once (it skips glyphs the font already has). Needs fontTools
(pip install fonttools); not used by the game itself.

Usage: python3 tools/i18n/add_glyphs.py [path/to/font.ttf]
"""

import os
import sys

from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
FONT = os.path.join(ROOT, "assets", "fonts", "PixelOperator8.ttf")
PIXEL = 100  # the font's grid: 8 pixels to the em of 800 units
LEFT = 1  # the font's letters start a pixel in (their left side bearing)

# Each glyph: (name, advance in pixels, rows from the top; the last row is the baseline row 0).
# The prompts' glyphs (Prompts, PromptGlyph): PlayStation's face buttons and the arrow keys,
# capital-high (7 pixels) like the letters on the other caps.
GLYPHS = {
    "✕": ("uni2715", 9, [
        "#.....#",
        ".#...#.",
        "..#.#..",
        "...#...",
        "..#.#..",
        ".#...#.",
        "#.....#",
    ]),
    "○": ("uni25CB", 9, [
        "..###..",
        ".#...#.",
        "#.....#",
        "#.....#",
        "#.....#",
        ".#...#.",
        "..###..",
    ]),
    "□": ("uni25A1", 9, [
        "#######",
        "#.....#",
        "#.....#",
        "#.....#",
        "#.....#",
        "#.....#",
        "#######",
    ]),
    "△": ("uni25B3", 9, [
        "...#...",
        "...#...",
        "..#.#..",
        "..#.#..",
        ".#...#.",
        ".#...#.",
        "#######",
    ]),
    "←": ("arrowleft", 9, [
        "",
        "..#....",
        ".#.....",
        "#######",
        ".#.....",
        "..#....",
        "",
    ]),
    "→": ("arrowright", 9, [
        "",
        "....#..",
        ".....#.",
        "#######",
        ".....#.",
        "....#..",
        "",
    ]),
    "↑": ("arrowup", 7, [
        "..#..",
        ".###.",
        "#.#.#",
        "..#..",
        "..#..",
        "..#..",
        "..#..",
    ]),
    "↓": ("arrowdown", 7, [
        "..#..",
        "..#..",
        "..#..",
        "..#..",
        "#.#.#",
        ".###.",
        "..#..",
    ]),
}
# Spaces: the same width as the font's space.
SPACES = {" ": "nbspace", " ": "uni202F"}


def draw(rows):
    pen = TTGlyphPen(None)
    height = len(rows)
    for i, row in enumerate(rows):
        y = height - 1 - i
        x = 0
        while x < len(row):
            if row[x] != "#":
                x += 1
                continue
            start = x
            while x < len(row) and row[x] == "#":
                x += 1
            x0, x1 = round((start + LEFT) * PIXEL), round((x + LEFT) * PIXEL)
            y0, y1 = round(y * PIXEL), round((y + 1) * PIXEL)
            # Clockwise, like the font's own outlines.
            pen.moveTo((x0, y0))
            pen.lineTo((x0, y1))
            pen.lineTo((x1, y1))
            pen.lineTo((x1, y0))
            pen.closePath()
    return pen.glyph()


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else FONT
    font = TTFont(path)
    cmap = font.getBestCmap()
    order = font.getGlyphOrder()
    added = []

    def add(char, name, glyph, advance):
        if ord(char) in cmap:
            return
        order.append(name)
        font["glyf"][name] = glyph
        font["hmtx"][name] = (advance, 0)
        for table in font["cmap"].tables:
            if table.isUnicode():
                table.cmap[ord(char)] = name
        added.append(char)

    for char, (name, advance, rows) in GLYPHS.items():
        add(char, name, draw(rows), round(advance * PIXEL))
    space = cmap[ord(" ")]
    for char, name in SPACES.items():
        add(char, name, TTGlyphPen(None).glyph(), font["hmtx"][space][0])
    font.setGlyphOrder(order)
    font["maxp"].numGlyphs = len(order)
    if "post" in font and font["post"].formatType == 2.0:
        font["post"].extraNames = []  # rebuilt from the glyph order
    font.save(path)
    print("added: %s" % " ".join(repr(c) for c in added) if added else "nothing to add")


if __name__ == "__main__":
    main()
