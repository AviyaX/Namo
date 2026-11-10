"""Zoomed check of specific legacy-font characters, with their surrounding raw text.

Usage: python -I fm_zoom.py <pdf_path> <out_dir> <hex code points...>

For each requested character: writes up to 3 occurrences as large crops of the
whole word/line region into zoom_N.png, and the raw legacy text around each
occurrence into zoom_contexts.txt, so the mapping can be confirmed by eye.
"""
import os
import sys

import fitz
from PIL import Image, ImageDraw, ImageFont


def main() -> None:
    pdf_path, out_dir = sys.argv[1], sys.argv[2]
    # characters are given as hex code points (e.g. 41 D8 153) so the shell cannot mangle them
    wanted = [chr(int(arg, 16)) for arg in sys.argv[3:]]
    os.makedirs(out_dir, exist_ok=True)
    doc = fitz.open(pdf_path)
    found = {c: [] for c in wanted}
    for pno in range(doc.page_count):
        raw = doc[pno].get_text("rawdict")
        for block in raw["blocks"]:
            if block.get("type") != 0:
                continue
            for line in block["lines"]:
                chars = [(ch["c"], fitz.Rect(ch["bbox"]), span["font"])
                         for span in line["spans"] for ch in span["chars"]]
                text = "".join(c for c, _, _ in chars)
                for i, (c, bbox, font) in enumerate(chars):
                    if c in found and len(found[c]) < 3 and "FM" in font:
                        found[c].append((pno, bbox, fitz.Rect(line["bbox"]), text, i))

    try:
        label_font = ImageFont.truetype(r"C:\Windows\Fonts\arial.ttf", 24)
    except OSError:
        label_font = ImageFont.load_default()
    rows = []
    with open(os.path.join(out_dir, "zoom_contexts.txt"), "w", encoding="utf-8") as fh:
        for c in wanted:
            for pno, bbox, lb, text, i in found[c]:
                lo, hi = max(0, i - 12), min(len(text), i + 13)
                fh.write(f"U+{ord(c):04X} {c!r} page {pno + 1}: ...{text[lo:i]}[{c}]{text[i + 1:hi]}...\n")
                clip = fitz.Rect(bbox.x0 - 45, lb.y0 - 4, bbox.x1 + 45, lb.y1 + 4)
                pix = doc[pno].get_pixmap(matrix=fitz.Matrix(8, 8), clip=clip)
                img = Image.frombytes("RGB", (pix.width, pix.height), pix.samples)
                img.thumbnail((520, 150))
                rows.append((c, pno, img))
    per_sheet = 18  # 6 rows x 3 cols
    cell_w, cell_h = 570, 190
    for s in range(0, len(rows), per_sheet):
        sheet = Image.new("RGB", (3 * cell_w, 6 * cell_h), "white")
        draw = ImageDraw.Draw(sheet)
        for idx, (c, pno, img) in enumerate(rows[s:s + per_sheet]):
            x, y = (idx % 3) * cell_w, (idx // 3) * cell_h
            draw.rectangle([x, y, x + cell_w - 1, y + cell_h - 1], outline="#999999")
            draw.text((x + 6, y + 4), f"{c}  U+{ord(c):04X}  p{pno + 1}", fill="red", font=label_font)
            sheet.paste(img, (x + 20, y + 36))
        sheet.save(os.path.join(out_dir, f"zoom_{s // per_sheet + 1}.png"))
    print(f"occurrences rendered: {len(rows)}")


if __name__ == "__main__":
    main()
