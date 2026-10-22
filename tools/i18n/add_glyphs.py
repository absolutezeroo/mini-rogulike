#!/usr/bin/env python3
"""Adds the French glyphs the pixel font (assets/fonts/normal_font.ttf, Ninja Adventure) lacks:
œ Œ « » Î Ï … – — and the no-break spaces (U+00A0, U+202F), plus the controls' prompt glyphs
(PlayStation's ✕ ○ □ △ and the arrows ← → ↑ ↓), drawn on its 9-pixel grid in its own style.
Runs once (it skips glyphs the font already has). Needs fontTools
(pip install fonttools); not used by the game itself.

Usage: python3 tools/i18n/add_glyphs.py [path/to/font.ttf]
"""

import os
import sys

from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
FONT = os.path.join(ROOT, "assets", "fonts", "normal_font.ttf")
PIXEL = 2048 / 9  # the font's grid: 9 pixels to the em

# Each glyph: (name, advance in pixels, rows from the top; the last row is the baseline row 0).
GLYPHS = {
    "œ": ("oe", 9, [
        ".###.##.",
        "#...#..#",
        "#...###.",
        "#...#...",
        ".###.###",
    ]),
    "Œ": ("OE", 11, [
        ".#########",
        "##..##....",
        "##..##....",
        "##..####..",
        "##..##....",
        ".#########",
    ]),
    "«": ("guillemotleft", 6, [
        ".#..#",
        "#..#.",
        ".#..#",
        "",
    ]),
    "»": ("guillemotright", 6, [
        "#..#.",
        ".#..#",
        "#..#.",
        "",
    ]),
    "Î": ("Icircumflex", 7, [
        "..##..",
        ".#..#.",
        "",
        "######",
        "..##..",
        "..##..",
        "..##..",
        "..##..",
        "######",
    ]),
    "Ï": ("Idieresis", 7, [
        ".#..#.",
        "",
        "######",
        "..##..",
        "..##..",
        "..##..",
        "..##..",
        "######",
    ]),
    "…": ("ellipsis", 9, [
        "##.##.##",
        "##.##.##",
    ]),
    "–": ("endash", 7, [
        "######",
        "",
        "",
    ]),
    "—": ("emdash", 10, [
        "#########",
        "",
        "",
    ]),
    # The prompts' glyphs (Prompts, PromptGlyph): PlayStation's face buttons and the arrow keys,
    # capital-high (6 pixels) like the letters on the other caps.
    "✕": ("uni2715", 7, [
        "#....#",
        ".#..#.",
        "..##..",
        "..##..",
        ".#..#.",
        "#....#",
    ]),
    "○": ("uni25CB", 7, [
        ".####.",
        "#....#",
        "#....#",
        "#....#",
        "#....#",
        ".####.",
    ]),
    "□": ("uni25A1", 7, [
        "######",
        "#....#",
        "#....#",
        "#....#",
        "#....#",
        "######",
    ]),
    "△": ("uni25B3", 7, [
        "..##..",
        "..##..",
        ".#..#.",
        ".#..#.",
        "#....#",
        "######",
    ]),
    "←": ("arrowleft", 7, [
        "..#...",
        ".#....",
        "######",
        ".#....",
        "..#...",
        "",
    ]),
    "→": ("arrowright", 7, [
        "...#..",
        "....#.",
        "######",
        "....#.",
        "...#..",
        "",
    ]),
    "↑": ("arrowup", 6, [
        "..#..",
        ".###.",
        "#.#.#",
        "..#..",
        "..#..",
        "..#..",
    ]),
    "↓": ("arrowdown", 6, [
        "..#..",
        "..#..",
        "..#..",
        "#.#.#",
        ".###.",
        "..#..",
    ]),
}
# Spaces: the same width as the font's space.
SPACES = {" ": "nbspace", " ": "narrownbspace"}


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
            x0, x1 = round(start * PIXEL), round(x * PIXEL)
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
