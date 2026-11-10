"""Extract the paritha.org Sinhala/Pali booklet into Unicode text for review.

Usage: python -I extract_booklet.py <pdf_path> <out_json> <out_md>

The booklet is typed in legacy FM fonts, so its text is converted with
fm_to_unicode.convert(). Nothing is corrected or re-ordered beyond that: the
output is meant to be a faithful, machine-converted copy that a person then
checks against the PDF, page by page.
"""
from __future__ import annotations

import collections
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import fitz  # noqa: E402

from fm_to_unicode import convert  # noqa: E402

SOURCE_URL = "https://www.paritha.org/wp-content/uploads/2019/11/Booklet-1.pdf"


def is_fm(font: str) -> bool:
    return font.split("+")[-1].upper().startswith("FM")


def collapse_letterspacing(legacy: str) -> tuple[str, bool]:
    """Headings in the booklet are typed with a space between every letter
    ("k u ia ld r h"). Join them back into words; 2+ spaces mark a word break."""
    stripped = legacy.strip()
    tokens = [t for t in stripped.split(" ") if t]
    if len(tokens) >= 4 and all(len(t) <= 3 for t in tokens) \
            and sum(len(t) <= 2 for t in tokens) / len(tokens) >= 0.6:
        words = re.split(r" {2,}", stripped)
        return " ".join(w.replace(" ", "") for w in words), True
    return legacy, False


def page_rows(page) -> list[dict]:
    raw = page.get_text("rawdict")
    # The booklet makes bold by drawing the same text twice (fill, then outline).
    # The outline pass shows up in the text trace as type 1.
    bold_rects = [fitz.Rect(t["bbox"]) for t in page.get_texttrace() if t.get("type") == 1]

    def is_bold(bbox) -> bool:
        r = fitz.Rect(bbox)
        cx, cy = (r.x0 + r.x1) / 2, (r.y0 + r.y1) / 2
        return any(b.x0 - 1 <= cx <= b.x1 + 1 and b.y0 - 1 <= cy <= b.y1 + 1 for b in bold_rects)

    lines = []
    for block in raw["blocks"]:
        if block.get("type") != 0:
            continue
        for line in block["lines"]:
            spans = []
            for span in line["spans"]:
                text = "".join(ch["c"] for ch in span["chars"])
                if text:
                    spans.append({"font": span["font"].split("+")[-1], "size": round(span["size"], 1),
                                  "text": text, "x0": span["bbox"][0], "x1": span["bbox"][2],
                                  "bold": is_bold(span["bbox"])})
            if spans:
                b = line["bbox"]
                fm_sizes = [s["size"] for s in spans if is_fm(s["font"]) and s["text"].strip()]
                # L = large type (verses), S = small type (meanings), N = no Sinhala-font text
                cls = "N" if not fm_sizes else ("L" if max(fm_sizes) >= 16 else "S")
                lines.append({"y0": b[1], "y1": b[3], "x0": b[0], "cls": cls, "segments": [spans]})
    lines.sort(key=lambda ln: (round(ln["y0"], 1), ln["x0"]))
    rows: list[dict] = []
    for ln in lines:
        merged = False
        # Join pieces that sit on the same printed row, but never a large-type piece with a
        # small-type one: on the sutta pages those are two separate columns (verse | meaning).
        for prev in rows[-4:][::-1]:
            overlap = min(prev["y1"], ln["y1"]) - max(prev["y0"], ln["y0"])
            height = min(prev["y1"] - prev["y0"], ln["y1"] - ln["y0"])
            same_class = prev["cls"] == ln["cls"] or "N" in (prev["cls"], ln["cls"])
            if height > 0 and overlap / height > 0.6 and same_class:
                prev["segments"].extend(ln["segments"])
                prev["y1"] = max(prev["y1"], ln["y1"])
                if prev["cls"] == "N":
                    prev["cls"] = ln["cls"]
                merged = True
                break
        if not merged:
            rows.append(ln)
    for row in rows:
        row["segments"].sort(key=lambda seg: seg[0]["x0"])
    return rows


def convert_row(row: dict, problems: list) -> dict | None:
    weight = collections.Counter()
    bold_chars = 0
    fm_chars = 0
    pieces = []
    letterspaced = False
    for seg in row["segments"]:
        seg_text = ""
        run = ""
        for span in seg:
            if is_fm(span["font"]):
                n_vis = len(span["text"].strip())
                fm_chars += n_vis
                bold_chars += n_vis if span.get("bold") else 0

        def flush() -> str:
            nonlocal run, letterspaced
            if not run:
                return ""
            legacy, spaced = collapse_letterspacing(run)
            letterspaced = letterspaced or spaced
            run = ""
            return convert(legacy, problems)

        for span in seg:
            if is_fm(span["font"]):
                run += span["text"]
                weight[(span["font"], span["size"])] += len(span["text"].strip())
            else:
                seg_text += flush()
                if span["font"].lower().startswith("wingdings"):
                    seg_text += "❖" * len(span["text"].strip()) + (" " if span["text"].endswith(" ") else "")
                else:
                    seg_text += span["text"]
        seg_text += flush()
        pieces.append((seg[0]["x0"], seg[-1]["x1"], seg_text))
    # Pieces on the same row that sit far apart are two columns: keep them visibly apart.
    text = ""
    prev_x1 = None
    for x0, x1, piece in pieces:
        piece = re.sub(r"[ \t]+", " ", piece).strip()
        if not piece:
            continue
        if text:
            text += "   |   " if prev_x1 is not None and x0 - prev_x1 > 22 else " "
        text += piece
        prev_x1 = x1
    if not text:
        return None
    bold = fm_chars > 0 and bold_chars / fm_chars >= 0.8
    if weight:
        (font, size), _ = weight.most_common(1)[0]
    else:
        font, size = row["segments"][0][0]["font"], row["segments"][0][0]["size"]
    if not weight:
        kind = "other"
    elif letterspaced or size >= 21:
        kind = "heading"
    elif bold and size >= 16 and "|" not in text:
        kind = "subheading"
    elif size >= 16:
        kind = "large"
    else:
        kind = "small"
    return {"kind": kind, "font": font, "size": size, "text": text, "y0": round(row["y0"], 1),
            "y1": round(row["y1"], 1)}


def main() -> None:
    pdf_path, out_json, out_md = sys.argv[1], sys.argv[2], sys.argv[3]
    doc = fitz.open(pdf_path)
    problems: list = []
    pages = []
    for pno in range(doc.page_count):
        page = doc[pno]
        rows = [r for r in (convert_row(row, problems) for row in page_rows(page)) if r]
        printed = None
        # the printed page number is a lone number at the foot (or head) of the page
        if rows and re.fullmatch(r"\d{1,2}", rows[-1]["text"]):
            printed = int(rows[-1]["text"])
            rows = rows[:-1]
        elif rows and re.fullmatch(r"\d{1,2}", rows[0]["text"]):
            printed = int(rows[0]["text"])
            rows = rows[1:]
        # Group rows into paragraphs separately for large type and small type, then put the
        # paragraphs in top-to-bottom order. On single-column pages this is simply reading
        # order. On pages with verse on the left and meaning on the right, each verse block
        # is followed by the meaning printed beside it, instead of the two being mixed.
        paragraphs: list[dict] = []
        for stream in ("main", "small"):
            current = None
            for r in rows:
                if (r["kind"] == "small") != (stream == "small"):
                    continue
                h = r["y1"] - r["y0"]
                standalone = r["kind"] in ("heading", "subheading")
                if (current is None or standalone or current["standalone"]
                        or r["y0"] - current["y1"] > 0.45 * max(h, current["h"])):
                    current = {"top": r["y0"], "y1": r["y1"], "h": h, "standalone": standalone,
                               "order": 0 if stream == "main" else 1, "rows": []}
                    paragraphs.append(current)
                current["rows"].append(r)
                current["y1"], current["h"] = max(current["y1"], r["y1"]), h
        paragraphs.sort(key=lambda p: (round(p["top"] / 6), p["order"], p["top"]))
        lines = []
        for para in paragraphs:
            if lines:
                lines.append({"kind": "break"})
            lines.extend({k: r[k] for k in ("kind", "font", "size", "text")} for r in para["rows"])
        pages.append({"pdf_page": pno + 1, "printed_page": printed,
                      "has_image": bool(page.get_images(full=True)), "lines": lines})

    # contents list, as printed on PDF page 2
    toc = []
    for ln in pages[1]["lines"]:
        if ln["kind"] == "break":
            continue
        m = re.match(r"^(\d{1,2})\.\s*(.+)$", ln["text"])
        if m:
            nums = re.findall(r"\d+", m.group(2))
            title = re.sub(r"\s*\d+\s*", " ", m.group(2)).strip()
            toc.append({"number": int(m.group(1)), "title": title,
                        "start_page": int(nums[0]) if nums else None,
                        "as_printed": ln["text"]})

    problem_counts = collections.Counter(problems)
    data = {
        "source": {
            "url": SOURCE_URL,
            "pdf_title": doc.metadata.get("title"),
            "pdf_author": doc.metadata.get("author"),
            "pdf_created": doc.metadata.get("creationDate"),
            "pages": doc.page_count,
            "fonts": "FM Bindumathi, FM Abhaya, FM Samantha (legacy, non-Unicode)",
            "copy_flag_note": "The PDF's security settings switch off text copying (printing and "
                              "screen-reader access are allowed). The booklet itself says it is for free "
                              "distribution.",
        },
        "status": "MACHINE-CONVERTED FROM A LEGACY FONT. NOT YET CHECKED BY A PERSON. "
                  "Spelling is exactly as typed in the source, including any misprints.",
        "line_kinds": {
            "heading": "letter-spaced or very large line in the booklet",
            "subheading": "bold line in the booklet's large type",
            "large": "main text, set in large type (FM Bindumathi 16pt+): the verses to recite",
            "small": "small type (mostly FM Abhaya 12-14pt): Sinhala meaning, instructions, notes",
            "other": "line with no Sinhala-font text (numbers, web address)",
            "break": "visible gap between lines in the booklet",
        },
        "conversion_problems": dict(problem_counts),
        "contents_as_printed": toc,
        "pages": pages,
    }
    os.makedirs(os.path.dirname(out_json), exist_ok=True)
    with open(out_json, "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=1)

    starts = collections.defaultdict(list)
    for entry in toc:
        if entry["start_page"] is not None:
            starts[entry["start_page"]].append(entry)

    md = []
    md.append("# Sinhala and Pali booklet (paritha.org) — converted text for checking")
    md.append("")
    md.append(f"- **Source:** {SOURCE_URL}")
    md.append(f"- **PDF details:** title \"{doc.metadata.get('title')}\", author \"{doc.metadata.get('author')}\", "
              f"{doc.page_count} pages")
    md.append("- **Status:** machine-converted from an old (non-Unicode) Sinhala font. **Not yet checked by a person.**")
    md.append("- **How to check:** open the PDF beside this file and compare page by page. "
              "Each section below is one page of the booklet.")
    md.append("- **Spelling:** kept exactly as the booklet has it, including any misprints. Nothing was corrected.")
    md.append("- **Layout key:** normal text = the booklet's large type (the verses). "
              "Indented quote text = the booklet's small type (Sinhala meaning, instructions). "
              "Headings = lines the booklet prints large or bold.")
    md.append("- **Two-column pages:** where the booklet prints two columns side by side, each row shows "
              "left column `|` right column, as on the page. The reading order (down the left, then down "
              "the right) still has to be confirmed.")
    md.append("")
    md.append("## Contents as printed in the booklet")
    md.append("")
    md.append("| No. | Title | Starts on booklet page |")
    md.append("|---|---|---|")
    for entry in toc:
        md.append(f"| {entry['number']} | {entry['title']} | {entry['start_page']} |")
    md.append("")
    for pg in pages:
        label = f"Booklet page {pg['printed_page']}" if pg["printed_page"] is not None else "Unnumbered page"
        md.append("---")
        md.append("")
        md.append(f"## {label} (PDF page {pg['pdf_page']})")
        md.append("")
        for entry in starts.get(pg["printed_page"], []):
            md.append(f"**▶ Contents item {entry['number']} starts on this page: {entry['title']}**")
            md.append("")
        if not pg["lines"]:
            md.append("_(no text on this page" + (" — image only" if pg["has_image"] else "") + ")_")
            md.append("")
            continue
        para: list[str] = []
        para_kind = None

        def flush_para() -> None:
            nonlocal para, para_kind
            if not para:
                return
            if para_kind == "small":
                md.extend(f"> {t}  " for t in para)
            else:
                md.extend(f"{t}  " for t in para)
            md.append("")
            para, para_kind = [], None

        for ln in pg["lines"]:
            if ln["kind"] == "break":
                flush_para()
                continue
            if ln["kind"] in ("heading", "subheading"):
                flush_para()
                md.append(("### " if ln["kind"] == "heading" else "#### ") + ln["text"])
                md.append("")
                continue
            kind = "small" if ln["kind"] == "small" else "large"
            if para_kind is not None and kind != para_kind:
                flush_para()
            para_kind = kind
            para.append(ln["text"])
        flush_para()

    # Letter combinations that cannot occur in correctly spelled Sinhala. They
    # mark either a misprint in the booklet or a conversion slip, so they are
    # the first places a reviewer should look.
    odd_patterns = [
        (re.compile(r"ා්"), "ා followed by ් (a kombuva may be missing in the booklet)"),
        (re.compile(r"[ාැෑිීුූෘෙේෛොෝෞ]{2,}"), "two vowel signs in a row"),
        (re.compile(r"(^|\s)[ාැෑිීුූෘෙේෛොෝෞ්ං]"), "vowel sign or hal with no letter before it"),
        (re.compile(r"⟦"), "character that could not be converted"),
    ]
    odd = []
    for pg in pages:
        for ln in pg["lines"]:
            if ln["kind"] == "break":
                continue
            for pattern, why in odd_patterns:
                if pattern.search(ln["text"]):
                    odd.append((pg["printed_page"], pg["pdf_page"], why, ln["text"]))
                    break
    md.append("---")
    md.append("")
    md.append("## Lines worth a closer look")
    md.append("")
    md.append("These lines contain letter combinations that do not occur in correctly spelled Sinhala. "
              "Each is either a misprint in the booklet itself or a slip in the conversion, "
              "so compare these with the PDF first.")
    md.append("")
    if odd:
        md.append("| Booklet page | PDF page | What looks odd | Line as converted |")
        md.append("|---|---|---|---|")
        for printed, pdf_page, why, text in odd:
            md.append(f"| {printed if printed is not None else '—'} | {pdf_page} | {why} | {text.replace('|', '/')} |")
    else:
        md.append("_None found._")
    md.append("")
    data["lines_worth_a_closer_look"] = [
        {"printed_page": p, "pdf_page": q, "reason": why, "text": text} for p, q, why, text in odd]
    with open(out_json, "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=1)

    os.makedirs(os.path.dirname(out_md), exist_ok=True)
    with open(out_md, "w", encoding="utf-8") as fh:
        fh.write("\n".join(md) + "\n")
    print(f"lines flagged for a closer look: {len(odd)}")

    n_lines = sum(1 for pg in pages for ln in pg["lines"] if ln["kind"] != "break")
    print(f"pages={len(pages)} lines={n_lines} toc_entries={len(toc)} problems={sum(problem_counts.values())}")
    for note, count in problem_counts.most_common():
        print(f"  {count} x {note}".encode("unicode_escape").decode("ascii"))


if __name__ == "__main__":
    main()
