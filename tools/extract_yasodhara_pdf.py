"""Extract the "Daily Buddha Vandana" booklet (Yasodhara Dhamma School, Brisbane) into text.

Usage: python -I -X utf8 extract_yasodhara_pdf.py <pdf_path> <out_json> <out_md>

The PDF is ordinary text in one column: a boxed heading, the Pali in bold Roman
letters, then the English in regular type. Some pages place a text box on top of
another paragraph (page 7), so every line keeps the number of the text block it
came from; lines of one block belong together even where another block's lines
fall between them on the page. Nothing in the wording is changed.
"""
from __future__ import annotations

import json
import os
import re
import sys

import fitz

SOURCE_FILE = "Vandana Gatha Booklet final.pdf (supplied by the app's owner, 2026-11-10)"
COVER = ("DAILY BUDDHA VANDANA (Pali Gatha and English Translations) / Prepared by Cynthia Gunawardana "
         "(Grade 3 Class Teacher) / Yasodhara Dhamma School, Sri Lankarama Maha Viharaya, Ellen Grove, Brisbane")


def main() -> None:
    pdf_path, out_json, out_md = sys.argv[1], sys.argv[2], sys.argv[3]
    doc = fitz.open(pdf_path)
    pages = []
    for pno, page in enumerate(doc):
        lines = []
        for bno, block in enumerate(page.get_text("dict")["blocks"]):
            if block.get("type") != 0:
                continue
            for line in block["lines"]:
                spans = [s for s in line["spans"] if s["text"].strip()]
                text = re.sub(r"[ \t]+", " ", "".join(s["text"] for s in line["spans"])).strip()
                if not text:
                    continue
                x0, y0, _, _ = line["bbox"]
                lines.append({"block": bno, "y": round(y0, 1), "x": round(x0, 1),
                              "bold": all("Bold" in s["font"] for s in spans),
                              "size": round(max(s["size"] for s in spans), 1), "text": text})
        lines.sort(key=lambda ln: (ln["y"], ln["x"]))
        pages.append({"pdf_page": pno + 1, "lines": lines})

    data = {
        "source": {"file": SOURCE_FILE, "url": None, "pdf_title": doc.metadata.get("title"),
                   "pdf_author": doc.metadata.get("author"), "pages": doc.page_count, "cover": COVER,
                   "stated_reuse_terms": "none printed in the PDF"},
        "status": "Copied as printed. The Pali is in Roman letters with partial, non-standard marks "
                  "(for example 'Gacchâmi', 'sammàsambuddhassa') or none, exactly as the PDF has it.",
        "layout": "One column. Bold lines are headings or Pali; regular lines are English. "
                  "'block' is the PDF text block a line came from.",
        "pages": pages,
    }
    os.makedirs(os.path.dirname(out_json), exist_ok=True)
    with open(out_json, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=1)

    md = ["# English booklet (Yasodhara Dhamma School, Brisbane): text for checking", "",
          f"- **Source:** {SOURCE_FILE}",
          f"- **Cover:** {COVER}",
          "- **Status:** copied exactly as printed (ordinary text, no font conversion).",
          "- **Reuse statement:** none printed in the PDF.",
          "- **Layout below:** bold is a heading or Pali, plain is English. A blank line separates text blocks.", ""]
    for pg in pages:
        md += ["---", "", f"## PDF page {pg['pdf_page']}", ""]
        by_block: dict[int, list[dict]] = {}
        for ln in pg["lines"]:
            by_block.setdefault(ln["block"], []).append(ln)
        for bno in sorted(by_block, key=lambda b: by_block[b][0]["y"]):
            for ln in by_block[bno]:
                md.append((f"**{ln['text']}**" if ln["bold"] else ln["text"]) + "  ")
            md.append("")
    os.makedirs(os.path.dirname(out_md), exist_ok=True)
    with open(out_md, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(md) + "\n")
    print("pages", len(pages), "lines", sum(len(p["lines"]) for p in pages))
    for p in pages:
        print(f"  p{p['pdf_page']}: lines={len(p['lines'])} blocks={len({ln['block'] for ln in p['lines']})}")


if __name__ == "__main__":
    main()
