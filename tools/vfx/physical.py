"""The physical kit's things in flight (docs/vfx.md, "Physical"): an arrow, a kunai, a thrown
spear and a tengu's feather, each drawn in 16 directions (one row per direction, row 0 pointing
right, then clockwise) so they never shear the way a turned sprite does. Re-run it to rebuild:

    python3 tools/vfx/physical.py [--preview DIR]

    assets/fx/physical/arrow.png    16 rows x 1 frame, 16x16 (bow, Volley)
    assets/fx/physical/kunai.png    16 rows x 1 frame, 16x16 (Kunai Fan)
    assets/fx/physical/spear.png    16 rows x 1 frame, 24x24 (Spear Throw)
    assets/fx/physical/feather.png  16 rows x 2 frames, 16x16 (the Crimson Tengu's feathers)

These are things, not energy: their colors are the art's own (the old arrow's wood, steel and
red fletching, the kunai's steel; the feather in the blood ramp), outlined in the art's ink so
they read like the sprites around them. The three base directions (0, 22.5 and 45 degrees) are
drawn from the shape (each part sampled at pixel centers, the dark ink around), the other
thirteen are their mirror images and transposes, so the set is perfectly consistent.
"""
import math
import os
import sys

from PIL import Image

from vfxkit import ROOT, preview

OUT = os.path.join(ROOT, "assets", "fx", "physical")

INK = (20, 27, 27)          # 141b1b, the art's outline
WOOD = (163, 117, 78)       # a3754e
WOOD_DARK = (107, 80, 64)   # 6b5040 (earth ramp)
STEEL = (242, 234, 241)     # f2eaf1
STEEL_DARK = (171, 194, 188)  # abc2bc
GREY = (141, 151, 127)      # 8d977f (the kunai's steel)
GREY_DARK = (95, 113, 96)   # 5f7160
RED = (224, 57, 76)         # e0394c
RED_DARK = (143, 62, 86)    # 8f3e56
BLOOD = [(255, 155, 143), (224, 57, 76), (163, 22, 44), (90, 10, 30)]  # the blood ramp


def inside(poly, x, y):
    hit = False
    for i in range(len(poly)):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % len(poly)]
        if (y1 > y) != (y2 > y) and x < x1 + (y - y1) * (x2 - x1) / (y2 - y1):
            hit = not hit
    return hit


def render(size, angle, parts):
    """`parts`: [(kind, geometry, color_fn)] in the thing's own frame (+u = where it points,
    +v = its right side), centered on the cell. kind 'line': (u0, u1) on v = 0, one pixel
    wide; 'poly': a polygon. color_fn(u, v) -> color. Later parts paint over earlier ones."""
    c, s = math.cos(angle), math.sin(angle)
    half = size / 2.0
    grid = [[None] * size for _ in range(size)]
    for y in range(size):
        for x in range(size):
            dx, dy = x + 0.5 - half, y + 0.5 - half
            u = dx * c + dy * s
            v = -dx * s + dy * c
            for kind, geometry, color in parts:
                if kind == "line":
                    u0, u1 = geometry
                    if u0 <= u <= u1 and abs(v) <= 0.55:
                        grid[y][x] = color(u, v)
                elif inside(geometry, u, v):
                    grid[y][x] = color(u, v)
    return grid


def outline(grid):
    size = len(grid)
    edge = []
    for y in range(size):
        for x in range(size):
            if grid[y][x] is None:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < size and 0 <= ny < size and grid[ny][nx] not in (None, INK):
                        edge.append((x, y))
                        break
    for x, y in edge:
        grid[y][x] = INK
    return grid


def flip_x(g):
    return [list(reversed(row)) for row in g]


def flip_y(g):
    return [list(row) for row in reversed(g)]


def transpose(g):
    return [list(col) for col in zip(*g)]


def sixteen(base):
    """Rows for 0, 22.5 ... 337.5 degrees (clockwise on screen, y down) from the drawings at
    0, 22.5 and 45 degrees: a transpose turns d into 90 - d, mirrors give the other quadrants."""
    a0, a1, a2 = base
    q = [a0, a1, a2, transpose(a1), transpose(a0)]   # 0, 22.5, 45, 67.5, 90
    rows = [None] * 16
    for i, g in enumerate(q):
        rows[i] = g                                   # 0..90 (down-right quadrant)
        rows[(8 - i) % 16] = flip_x(g)                # 180 - d
        rows[(8 + i) % 16] = flip_x(flip_y(g))        # 180 + d
        rows[(16 - i) % 16] = flip_y(g)               # 360 - d
    return rows


def sheet(rows_by_frame, size):
    frames = len(rows_by_frame)
    image = Image.new("RGBA", (size * frames, size * 16), (0, 0, 0, 0))
    px = image.load()
    for f, rows in enumerate(rows_by_frame):
        for r, grid in enumerate(rows):
            for y in range(size):
                for x in range(size):
                    if grid[y][x] is not None:
                        px[f * size + x, r * size + y] = grid[y][x] + (255,)
    return image


def lit(light, dark):
    """The upper side (v < 0) lit, the lower side dark."""
    return lambda u, v: light if v < 0.0 else dark


# The arrow is too small to sample: its three base directions are drawn by hand (W wood,
# S/s lit and shaded steel, R/r lit and shaded fletching; the ink is added around).
ARROW = [
    # 0 degrees: the old arrow, as drawn.
    """
................
................
................
................
................
................
................
..RR.......SS...
..rrWWWWWWWWSS..
..RR.......ss...
................
................
................
................
................
................
""",
    # 22.5 degrees
    """
................
................
................
................
................
..R.............
.RRrW...........
...rrWW.........
.......WW.......
.........WSS....
..........sSS...
...........s....
................
................
................
................
""",
    # 45 degrees
    """
................
................
................
...R............
..RrR...........
...RrW..........
.....rW.........
.......W........
........W.......
.........WS.....
.........sSS....
..........sS....
................
................
................
................
""",
]
KEYS = {"W": WOOD, "S": STEEL, "s": STEEL_DARK, "R": RED, "r": RED_DARK}


def drawn(art):
    rows = [line for line in art.strip("\n").split("\n")]
    return outline([[KEYS.get(ch) for ch in row] for row in rows])


def arrow(angle):
    return drawn(ARROW[int(round(angle / (math.pi / 8.0)))])


def kunai(angle):
    parts = [
        ("poly", [(-6.6, -1.6), (-4.0, -1.6), (-4.0, 1.6), (-6.6, 1.6)], lambda u, v: GREY),  # the ring
        ("line", (-6.0, -4.6), lambda u, v: None),
        ("line", (-4.4, -1.0), lambda u, v: GREY_DARK),  # the wrapped grip
        ("poly", [(-1.4, -1.6), (5.0, -0.7), (7.0, 0.0), (5.0, 0.7), (-1.4, 1.6)], lit(STEEL, GREY)),
    ]
    grid = render(16, angle, parts)
    # The ring's hole: its middle pixel back to empty (drawn as a hollow square at 0 degrees).
    return outline(grid)


def spear(angle):
    parts = [
        ("line", (-11.0, 5.0), lambda u, v: WOOD if v <= 0.0 else WOOD_DARK),
        ("poly", [(4.0, -2.1), (8.0, -1.2), (11.2, 0.0), (8.0, 1.2), (4.0, 2.1), (5.2, 0.0)], lit(STEEL, STEEL_DARK)),
        ("line", (-11.0, -9.6), lambda u, v: STEEL_DARK),  # the butt cap
    ]
    return outline(render(24, angle, parts))


def feather(angle, frame):
    """A crimson flight feather: a pale quill along its spine, the vane in the blood ramp (wide
    and lit on one side, narrow and dark on the other), a notch in its edge, a bare quill at the
    tail; the second frame flutters its tip."""
    flutter = 0.7 if frame else 0.0
    vane = [(-4.6, -0.4), (-2.6, -2.6), (2.6, -2.4), (6.0, -0.6 + flutter), (6.4, 0.3 + flutter * 0.5), (2.6, 1.6), (-2.6, 1.6), (-4.6, 0.6)]
    notch = [(0.2, -3.2), (1.4, -3.2), (0.6, -1.4)]
    parts = [
        ("poly", vane, lambda u, v: BLOOD[1] if v < -0.5 else BLOOD[2]),
        ("poly", notch, lambda u, v: None),
        ("line", (-7.0, 5.4), lambda u, v: BLOOD[0] if u > -4.6 else STEEL),  # the quill
    ]
    return outline(render(16, angle, parts))


def build(name, fn, size, frames=1):
    rows_by_frame = []
    for f in range(frames):
        base = [fn(a * math.pi / 8.0) if frames == 1 else fn(a * math.pi / 8.0, f) for a in range(3)]
        rows_by_frame.append(sixteen(base))
    image = sheet(rows_by_frame, size)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".png")
    image.save(path)
    return path, image


def main() -> None:
    out_dir = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
    for name, fn, size, frames in (("arrow", arrow, 16, 1), ("kunai", kunai, 16, 1), ("spear", spear, 24, 1), ("feather", feather, 16, 2)):
        path, image = build(name, fn, size, frames)
        print("wrote", path, image.size)
        if out_dir:
            # The 16 rows laid out in a 4x4 block to judge them side by side.
            block = Image.new("RGBA", (size * 4 * frames, size * 4), (0, 0, 0, 0))
            for r in range(16):
                for f in range(frames):
                    tile = image.crop((f * size, r * size, (f + 1) * size, (r + 1) * size))
                    block.paste(tile, (((r % 4) * frames + f) * size, (r // 4) * size))
            preview(block, os.path.join(out_dir, name + "_x8.png"), 8, (size, size))


if __name__ == "__main__":
    main()
