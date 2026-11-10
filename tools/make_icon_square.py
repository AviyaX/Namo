"""Lay a rounded-corner icon over a square of its own edge colour.

Usage: python -I -X utf8 tools/make_icon_square.py <src_png> <out_png>

Takes the median colour of the fully opaque pixels within 12 px of the
transparent corners, fills a square with it, lays the icon on top and saves
the result without an alpha channel. Nothing else in the picture changes.
"""
import statistics
import sys

from PIL import Image, ImageDraw, ImageFilter

BAND = 12


def corner_colour(icon):
    alpha = icon.getchannel("A")
    w, h = icon.size
    # Mark transparent pixels (255), then keep only those joined to a corner.
    mask = alpha.point(lambda a: 255 if a == 0 else 0)
    flood = Image.new("L", (w, h), 0)
    flood.paste(mask)
    for corner in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
        if flood.getpixel(corner) == 255:
            ImageDraw.floodfill(flood, corner, 128)
    region = flood.point(lambda v: 255 if v == 128 else 0)
    near = region.filter(ImageFilter.MaxFilter(2 * BAND + 1))
    rgb = icon.convert("RGB")
    samples = [
        rgb.getpixel((x, y))
        for y in range(h)
        for x in range(w)
        if near.getpixel((x, y)) == 255
        and region.getpixel((x, y)) == 0
        and alpha.getpixel((x, y)) == 255
    ]
    if not samples:
        raise SystemExit("no opaque pixels found near the corners")
    return tuple(int(statistics.median(c[i] for c in samples)) for i in range(3))


def main():
    src, out = sys.argv[1], sys.argv[2]
    icon = Image.open(src).convert("RGBA")
    colour = corner_colour(icon)
    square = Image.new("RGBA", icon.size, colour + (255,))
    square.alpha_composite(icon)
    result = square.convert("RGB")
    result.save(out)
    print("#%02X%02X%02X" % colour)
    check = Image.open(out)
    print(check.size, check.mode)


main()
