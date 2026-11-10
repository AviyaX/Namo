"""Show the raw legacy text and an enlarged image of every line on a page whose
converted text contains a given Unicode string.

Usage: python -I fm_line_probe.py <pdf_path> <pdf_page_number> <hex utf-8 of the string> <out_png>
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import fitz  # noqa: E402
from PIL import Image  # noqa: E402

from fm_to_unicode import convert  # noqa: E402


def main() -> None:
    doc = fitz.open(sys.argv[1])
    page = doc[int(sys.argv[2]) - 1]
    needle = bytes.fromhex(sys.argv[3]).decode("utf-8")
    crops = []
    for block in page.get_text("rawdict")["blocks"]:
        if block.get("type") != 0:
            continue
        for line in block["lines"]:
            legacy = "".join(ch["c"] for span in line["spans"] for ch in span["chars"])
            if needle in convert(legacy):
                print(legacy.encode("unicode_escape").decode("ascii"))
                print("  fonts:", sorted({(s["font"], round(s["size"], 1)) for s in line["spans"]}))
                r = fitz.Rect(line["bbox"])
                pix = page.get_pixmap(matrix=fitz.Matrix(5, 5), clip=fitz.Rect(r.x0 - 4, r.y0 - 5, r.x1 + 4, r.y1 + 5))
                crops.append(Image.frombytes("RGB", (pix.width, pix.height), pix.samples))
    if crops:
        crops = crops[:4]
        w = max(c.width for c in crops)
        sheet = Image.new("RGB", (w, sum(c.height + 10 for c in crops)), "white")
        y = 0
        for c in crops:
            sheet.paste(c, (0, y))
            y += c.height + 10
        if sheet.width > 1800:
            sheet = sheet.resize((1800, int(sheet.height * 1800 / sheet.width)))
        sheet.save(sys.argv[4])
    print("matches:", len(crops))


if __name__ == "__main__":
    main()
