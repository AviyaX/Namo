"""Find a sequence of legacy characters in the PDF and render where it occurs.

Usage: python -I fm_find.py <pdf_path> <out_png> <seq> [<seq> ...]
  each <seq> is hex code points joined by commas, e.g. 43,4F  for "CO"

Writes one PNG with an enlarged crop of every occurrence (max 4 per sequence),
and prints the page and surrounding raw text for each.
"""
import sys

import fitz
from PIL import Image, ImageDraw, ImageFont


def main() -> None:
    doc = fitz.open(sys.argv[1])
    out_png = sys.argv[2]
    seqs = ["".join(chr(int(h, 16)) for h in arg.split(",")) for arg in sys.argv[3:]]
    crops = []
    for seq in seqs:
        hits = 0
        for pno, page in enumerate(doc):
            for block in page.get_text("rawdict")["blocks"]:
                if block.get("type") != 0:
                    continue
                for line in block["lines"]:
                    chars = [(ch["c"], fitz.Rect(ch["bbox"])) for span in line["spans"] for ch in span["chars"]]
                    text = "".join(c for c, _ in chars)
                    start = text.find(seq)
                    while start != -1 and hits < 4:
                        hits += 1
                        lb = fitz.Rect(line["bbox"])
                        x0 = chars[start][1].x0
                        x1 = chars[start + len(seq) - 1][1].x1
                        clip = fitz.Rect(x0 - 60, lb.y0 - 4, x1 + 60, lb.y1 + 4)
                        pix = page.get_pixmap(matrix=fitz.Matrix(8, 8), clip=clip)
                        img = Image.frombytes("RGB", (pix.width, pix.height), pix.samples)
                        img.thumbnail((800, 170))
                        label = f"{'+'.join(f'{ord(c):02X}' for c in seq)}  p{pno + 1}"
                        crops.append((label, img))
                        ctx = text[max(0, start - 10):start + len(seq) + 10]
                        print(f"{label}: {ctx.encode('unicode_escape').decode('ascii')}")
                        start = text.find(seq, start + 1)
    try:
        font = ImageFont.truetype(r"C:\Windows\Fonts\arial.ttf", 22)
    except OSError:
        font = ImageFont.load_default()
    cell_h = 210
    sheet = Image.new("RGB", (860, max(1, len(crops)) * cell_h), "white")
    draw = ImageDraw.Draw(sheet)
    for i, (label, img) in enumerate(crops):
        y = i * cell_h
        draw.text((8, y + 4), label, fill="red", font=font)
        sheet.paste(img, (20, y + 34))
        draw.line([0, y + cell_h - 1, 860, y + cell_h - 1], fill="#999999")
    sheet.save(out_png)
    print(f"crops: {len(crops)}")


if __name__ == "__main__":
    main()
