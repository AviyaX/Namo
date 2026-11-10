"""Extract the Mahamevnawa (Canada) "Vandana" PDF into text for review.

Usage: python -I extract_english_pdf.py <pdf_path> <out_json> <out_md>

The PDF is ordinary text set in two columns: Pali in Roman letters on the left,
English on the right. This keeps the two columns apart, page by page, and
changes nothing in the wording.
"""
from __future__ import annotations

import json
import os
import re
import sys

import fitz

SOURCE_URL = "https://www.mahamevnawa.ca/uploads/1/0/7/1/107195823/vandana_v1.pdf"


def main() -> None:
    pdf_path, out_json, out_md = sys.argv[1], sys.argv[2], sys.argv[3]
    doc = fitz.open(pdf_path)
    pages = []
    for pno, page in enumerate(doc):
        mid = page.rect.width / 2
        cols = {"left": [], "right": [], "full": []}
        for block in page.get_text("dict")["blocks"]:
            if block.get("type") != 0:
                continue
            for line in block["lines"]:
                text = "".join(span["text"] for span in line["spans"])
                text = re.sub(r"[ \t]+", " ", text).strip()
                if not text:
                    continue
                x0, y0, x1, _ = line["bbox"]
                bold = all("Bold" in span["font"] for span in line["spans"] if span["text"].strip())
                # Measured on this PDF: left-column lines start at x = 30-150,
                # right-column lines at x = 280-390. The cover page is the only
                # single-column page.
                if pno == 0:
                    side = "full"
                elif x0 < mid - 40:
                    side = "left"
                else:
                    side = "right"
                cols[side].append({"y": round(y0, 1), "x": round(x0, 1), "bold": bold, "text": text})
        for side in cols:
            cols[side].sort(key=lambda ln: (ln["y"], ln["x"]))
        pages.append({"pdf_page": pno + 1, "full_width": cols["full"],
                      "left_column": cols["left"], "right_column": cols["right"]})

    data = {
        "source": {"url": SOURCE_URL, "pdf_title": doc.metadata.get("title"),
                   "pdf_author": doc.metadata.get("author"), "pages": doc.page_count,
                   "cover": "VANDANA - Homage to the Buddha, Dhamma and Sangha / Mahamevna Bhavana Asapuwa, Markham ON",
                   "stated_reuse_terms": "none printed in the PDF"},
        "status": "Copied as printed. The Pali is in plain Roman letters WITHOUT diacritics "
                  "(a, i, u, m, n ... not ā, ī, ū, ṃ, ñ ...), exactly as the PDF has it.",
        "columns": {"left_column": "Pali in Roman letters", "right_column": "English"},
        "pages": pages,
    }
    os.makedirs(os.path.dirname(out_json), exist_ok=True)
    with open(out_json, "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=1)

    md = ["# English booklet (Mahamevnawa, Canada) — text for checking", ""]
    md.append(f"- **Source:** {SOURCE_URL}")
    md.append(f"- **PDF details:** {doc.page_count} pages; cover reads \"VANDANA — Homage to the Buddha, Dhamma and Sangha\", "
              "Mahamevna Bhavana Asapuwa, Markham, Ontario")
    md.append("- **Status:** copied exactly as printed (this PDF is ordinary text, so no font conversion was needed).")
    md.append("- **Pali spelling:** the PDF prints Pali in plain Roman letters with **no accent marks** "
              "(for example `sammasambuddhassa`, not `sammāsambuddhassa`). That is how it is kept here.")
    md.append("- **No translator, date or reuse statement is printed anywhere in the PDF.**")
    md.append("- **Layout:** each page has Pali on the left and English on the right. Below, each page shows the "
              "left column first, then the right column.")
    md.append("")

    def emit(lines: list[dict]) -> None:
        prev_y = None
        for ln in lines:
            if prev_y is not None and ln["y"] - prev_y > 22:
                md.append("")
            md.append((f"**{ln['text']}**" if ln["bold"] else ln["text"]) + "  ")
            prev_y = ln["y"]
        md.append("")

    for pg in pages:
        md.append("---")
        md.append("")
        md.append(f"## PDF page {pg['pdf_page']}")
        md.append("")
        if pg["full_width"]:
            emit(pg["full_width"])
        if pg["left_column"]:
            md.append("### Left column — Pali (Roman letters)")
            md.append("")
            emit(pg["left_column"])
        if pg["right_column"]:
            md.append("### Right column — English")
            md.append("")
            emit(pg["right_column"])
    os.makedirs(os.path.dirname(out_md), exist_ok=True)
    with open(out_md, "w", encoding="utf-8") as fh:
        fh.write("\n".join(md) + "\n")
    print("pages", len(pages), "lines",
          sum(len(p["left_column"]) + len(p["right_column"]) + len(p["full_width"]) for p in pages))
    for p in pages:
        heads = [ln["text"] for ln in p["left_column"] + p["right_column"] + p["full_width"] if ln["bold"]]
        print(f"  p{p['pdf_page']}: L={len(p['left_column'])} R={len(p['right_column'])} F={len(p['full_width'])} bold={heads[:6]}")


if __name__ == "__main__":
    main()
