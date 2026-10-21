"""Palette swap: paints a sheet in an element's ramp by luminance (docs/vfx.md).

    python3 tools/vfx/recolor.py assets/projectiles/energyball.png poison assets/fx/poison/poison_orb.png
    python3 tools/vfx/recolor.py <in.png> <element id> <out.png> [--preview out_x6.png]

The brightest shade of the sheet takes the ramp's core, the darkest its edge, the shades between
spread over the ramp in order (by rank, like VfxRamp.recolor_image in the game); alpha becomes
hard (1-bit). The same thing happens at runtime for a VfxSheetDef with `recolor` on; run this
instead when the recolored sheet deserves its own file (to touch it up by hand afterwards).
"""
import sys

from PIL import Image

from vfxkit import Element, preview


def luma(rgb: tuple) -> int:
    r, g, b = rgb[:3]
    return round(0.299 * r + 0.587 * g + 0.114 * b)


def recolor(image: Image.Image, ramp: list) -> Image.Image:
    image = image.convert("RGBA")
    pixels = image.load()
    w, h = image.size
    shades = sorted({luma(pixels[x, y]) for y in range(h) for x in range(w) if pixels[x, y][3] >= 128}, reverse=True)
    last = len(ramp) - 1
    index = {s: round(i / max(len(shades) - 1, 1) * last) for i, s in enumerate(shades)}
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = out.load()
    for y in range(h):
        for x in range(w):
            c = pixels[x, y]
            if c[3] >= 128:
                px[x, y] = tuple(ramp[index[luma(c)]]) + (255,)
    return out


def main() -> None:
    if len(sys.argv) < 4:
        print(__doc__)
        sys.exit(1)
    source, element_id, target = sys.argv[1:4]
    element = Element.load(element_id)
    out = recolor(Image.open(source), element.ramp)
    out.save(target)
    if "--preview" in sys.argv:
        preview(out, sys.argv[sys.argv.index("--preview") + 1])
    print("%s -> %s (%s ramp, %d colors)" % (source, target, element_id, len(element.ramp)))


if __name__ == "__main__":
    main()
