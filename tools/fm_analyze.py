"""Analyse the legacy-font (FM Abhaya family) text in a PDF.

Usage: python -I fm_analyze.py <pdf_path> <out_dir>

Produces, in <out_dir>:
  inventory.txt   - every distinct character used in FM-font spans, with counts,
                    plus font/size statistics and the PDF permission flags
  glyphs_N.png    - contact sheets: for each distinct character, the glyph as it
                    is actually drawn in the PDF (cropped from a real page), so the
                    legacy-code -> Sinhala-letter mapping can be checked by eye
"""
import collections
import os
import sys

import fitz  # PyMuPDF
from PIL import Image, ImageDraw, ImageFont


def is_fm(font_name: str) -> bool:
    return "FM" in font_name.upper().split("+")[-1][:2].upper() or font_name.upper().split("+")[-1].startswith("FM")


def main() -> None:
    pdf_path, out_dir = sys.argv[1], sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)
    doc = fitz.open(pdf_path)

    counts = collections.Counter()
    first_seen = {}  # char -> (page_no, char_bbox, line_bbox)
    font_sizes = collections.Counter()
    nonfm_chars = collections.Counter()

    for pno in range(doc.page_count):
        page = doc[pno]
        raw = page.get_text("rawdict")
        for block in raw["blocks"]:
            if block.get("type") != 0:
                continue
            for line in block["lines"]:
                for span in line["spans"]:
                    font = span["font"]
                    font_sizes[(font, round(span["size"], 1))] += len(span["chars"])
                    for ch in span["chars"]:
                        c = ch["c"]
                        if is_fm(font):
                            counts[c] += 1
                            if c not in first_seen and c.strip():
                                first_seen[c] = (pno, fitz.Rect(ch["bbox"]), fitz.Rect(line["bbox"]), font)
                        else:
                            nonfm_chars[(font, c)] += 1

    with open(os.path.join(out_dir, "inventory.txt"), "w", encoding="utf-8") as fh:
        fh.write(f"PERMISSIONS (raw int): {doc.permissions}\n")
        for name in ("PDF_PERM_PRINT", "PDF_PERM_MODIFY", "PDF_PERM_COPY", "PDF_PERM_ANNOTATE",
                     "PDF_PERM_FORM", "PDF_PERM_ACCESSIBILITY", "PDF_PERM_ASSEMBLE", "PDF_PERM_PRINT_HQ"):
            flag = getattr(fitz, name, None)
            if flag is not None:
                fh.write(f"  {name}: {bool(doc.permissions & flag)}\n")
        fh.write("\nFONT / SIZE -> char count\n")
        for (font, size), n in sorted(font_sizes.items(), key=lambda kv: -kv[1]):
            fh.write(f"  {font:40s} {size:5.1f}  {n}\n")
        fh.write(f"\nDISTINCT FM CHARS: {len(counts)}\n")
        for c, n in sorted(counts.items(), key=lambda kv: ord(kv[0])):
            fh.write(f"  U+{ord(c):04X} {c!r:8s} {n}\n")
        fh.write("\nNON-FM CHARS (font, char) -> count\n")
        by_font = collections.defaultdict(str)
        for (font, c), n in nonfm_chars.items():
            by_font[font] += c
        for font, chars in by_font.items():
            fh.write(f"  {font}: {''.join(sorted(set(chars)))!r}\n")

    # Contact sheets
    try:
        label_font = ImageFont.truetype(r"C:\Windows\Fonts\arial.ttf", 22)
    except OSError:
        label_font = ImageFont.load_default()
    zoom = 5
    cell_w, cell_h = 430, 110
    cols, rows = 4, 9
    items = sorted(first_seen.items(), key=lambda kv: ord(kv[0]))
    sheet_no = 0
    for start in range(0, len(items), cols * rows):
        sheet = Image.new("RGB", (cols * cell_w, rows * cell_h), "white")
        draw = ImageDraw.Draw(sheet)
        for idx, (c, (pno, cb, lb, font)) in enumerate(items[start:start + cols * rows]):
            cx, cy = (idx % cols) * cell_w, (idx // cols) * cell_h
            draw.rectangle([cx, cy, cx + cell_w - 1, cy + cell_h - 1], outline="#bbbbbb")
            draw.text((cx + 6, cy + 6), f"{c}", fill="black", font=label_font)
            draw.text((cx + 6, cy + 40), f"U+{ord(c):04X}", fill="#555555", font=label_font)
            draw.text((cx + 6, cy + 72), f"n={counts[c]}", fill="#555555", font=label_font)
            page = doc[pno]
            # glyph alone (padded, because vowel signs have thin or shifted boxes)
            g = fitz.Rect(cb.x0 - 4, lb.y0 - 3, cb.x1 + 4, lb.y1 + 3)
            pix = page.get_pixmap(matrix=fitz.Matrix(zoom, zoom), clip=g)
            gi = Image.frombytes("RGB", (pix.width, pix.height), pix.samples)
            gi.thumbnail((110, cell_h - 10))
            sheet.paste(gi, (cx + 105, cy + 5))
            # in context: the glyph with neighbours either side
            w = fitz.Rect(cb.x0 - 22, lb.y0 - 3, cb.x1 + 22, lb.y1 + 3)
            pix = page.get_pixmap(matrix=fitz.Matrix(zoom, zoom), clip=w)
            wi = Image.frombytes("RGB", (pix.width, pix.height), pix.samples)
            wi.thumbnail((200, cell_h - 10))
            sheet.paste(wi, (cx + 222, cy + 5))
        sheet_no += 1
        sheet.save(os.path.join(out_dir, f"glyphs_{sheet_no}.png"))
    print(f"distinct FM chars: {len(counts)}; sheets: {sheet_no}")


if __name__ == "__main__":
    main()
