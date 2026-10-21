"""Checks an effect sheet against an element's palette and the grid rules (docs/vfx.md).

    python3 tools/vfx/check.py assets/fx/frost/frost_shard.png frost --cell 16x16
    python3 tools/vfx/check.py <sheet.png> <element id> [--cell WxH]

Fails (exit 1) when a pixel is half-transparent (alpha must be 0 or 255), when a color is not
in the element's ramp or residue, or when the sheet doesn't cut into whole cells. Prints the
colors used, and warns about lone pixels (noise a pixel artist would clean up).
"""
import sys

from PIL import Image

from vfxkit import Element


def main() -> None:
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    path, element_id = sys.argv[1:3]
    element = Element.load(element_id)
    image = Image.open(path).convert("RGBA")
    w, h = image.size
    px = image.load()
    problems = []
    used = {}
    lone = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a not in (0, 255):
                problems.append("half-transparent pixel at %d,%d (alpha %d)" % (x, y, a))
            if a == 255:
                used[(r, g, b)] = used.get((r, g, b), 0) + 1
                if all(not (0 <= x + dx < w and 0 <= y + dy < h) or px[x + dx, y + dy][3] == 0 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    lone += 1
    allowed = element.colors()
    for color in used:
        if color not in allowed:
            problems.append("color #%02x%02x%02x is not in the %s ramp" % (color + (element_id,)))
    if "--cell" in sys.argv:
        cw, ch = (int(v) for v in sys.argv[sys.argv.index("--cell") + 1].split("x"))
        if w % cw or h % ch:
            problems.append("%dx%d doesn't cut into %dx%d cells" % (w, h, cw, ch))
    print("%s: %dx%d, %d colors: %s" % (path, w, h, len(used), " ".join("#%02x%02x%02x" % c for c in sorted(used))))
    if lone:
        print("  warning: %d lone pixels" % lone)
    for problem in problems[:20]:
        print("  FAIL: " + problem)
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
