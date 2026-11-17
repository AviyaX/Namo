"""Extract the Nottingham "Evening Puja and Chanting" booklet into lines and units.

Usage: python -I -X utf8 extract_nottingham_booklet.py <pdf_path> <out_json> <out_md>

The booklet types its Sinhala-script Pali in the legacy FM Bindumathi font, its
Roman Pali in Calibri-Bold and its English in Calibri. The Sinhala is converted
with fm_to_unicode.convert(); Roman and English are copied as printed. Nothing is
corrected: the output is a faithful machine copy for a person to check, and the
lines are grouped into units (Pali / Roman / English) for the content builder.
"""
from __future__ import annotations

import collections
import hashlib
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import fitz  # noqa: E402

from fm_to_unicode import convert  # noqa: E402

SOURCE_FILE = "evening_puja_and_chanting.pdf (supplied by the app's owner, 2026-11-17)"
SIGN_OR_VIRAMA = "්ාැෑිීුූෘෲෙේෛොෝෞෟංඃ"
SPACE_BEFORE_SIGN = re.compile(" +(?=[" + SIGN_OR_VIRAMA + "])")


def is_fm(font: str) -> bool:
    return font.split("+")[-1].upper().startswith("FM")


def _name(span: dict) -> str:
    return span["font"].split("+")[-1]


def merge_baselines(lines: list[dict], tolerance: float = 1.0) -> list[dict]:
    """Join pieces that share a baseline (justified text arrives word by word)."""
    merged: list[dict] = []
    for ln in sorted(lines, key=lambda r: r["y"]):
        if merged and abs(ln["y"] - merged[-1]["y"]) <= tolerance:
            merged[-1]["spans"].extend(ln["spans"])
        else:
            merged.append({"y": ln["y"], "spans": list(ln["spans"])})
    for ln in merged:
        ln["spans"].sort(key=lambda s: s["x"])
    return merged


def line_text(spans: list[dict], problems: list | None = None) -> str:
    """Text of one line: FM runs converted to Unicode, other spans as printed."""
    out = []
    run = ""

    def flush() -> None:
        nonlocal run
        if run:
            out.append(SPACE_BEFORE_SIGN.sub("", convert(run, problems)))
            run = ""

    for s in spans:
        if is_fm(s["font"]):
            run += s["text"]
        else:
            flush()
            out.append(s["text"])
    flush()
    return "".join(out).strip()


def _bearing(spans: list[dict]) -> list[dict]:
    return [s for s in spans if s["text"].strip()]


def _letterless(span: dict) -> bool:
    return not any(ch.isalpha() for ch in span["text"])


def _content(spans: list[dict]) -> list[dict]:
    """Text-bearing spans, leaving out stray punctuation set in another font (a lone "," or " - ")."""
    bearing = _bearing(spans)
    return [s for s in bearing if not _letterless(s)] or bearing


def classify(spans: list[dict], text: str) -> str:
    """Name the kind of line: heading, subheading, pali_si, roman, english, note, break or other."""
    bearing = _content(spans)
    if not bearing:
        return "break"
    fm = [s for s in bearing if is_fm(s["font"])]
    other = [s for s in bearing if not is_fm(s["font"])]
    if fm and other and all(_name(s).startswith("Calibri") for s in other):
        # a Sinhala title with its English beside it: a heading (large type) or an offering sub-heading
        return "heading" if max(s["size"] for s in fm) >= 20 else "subheading"
    if text.startswith("(") and text.endswith(")"):
        return "note"
    if fm and not other:
        return "heading" if max(s["size"] for s in fm) >= 20 else "pali_si"
    if (not fm and all(_name(s) == "Calibri-Bold" and s["size"] >= 18 for s in bearing)
            and text.isupper()):
        return "heading"
    if not fm and all(_name(s) == "Calibri-Bold" and s["flags"] & 16 and s["size"] >= 15 for s in bearing):
        return "roman"
    # IskoolaPota: one letter of an English word was typed in a fallback font in the booklet
    if not fm and all(_name(s) in ("Calibri", "Calibri-Italic", "IskoolaPota") and not s["flags"] & 16
                      and s["size"] <= 13 for s in bearing):
        return "english"
    return "other"


def _split_notes(spans: list[dict]) -> list[list[dict]]:
    """A bracketed instruction such as "(Bow)" beside other text becomes its own line."""
    bearing = _bearing(spans)
    notes = [s for s in bearing if s["text"].strip().startswith("(") and s["text"].strip().endswith(")")]
    if notes and len(notes) < len(bearing):
        return [[s for s in spans if s not in notes], notes]
    return [spans]


def _is_english_title(ln: dict) -> bool:
    """An unrecognised Calibri line (13 to 19 pt, below the 26 pt closing flourish) that is italic, or regular but larger than the 12 pt English."""
    return (ln["kind"] == "other" and ln["font"] in ("Calibri", "Calibri-Italic", "Calibri-BoldItalic")
            and (ln["font"] != "Calibri" or ln["size"] > 12) and 13 <= ln["size"] < 20)


def _promote_titles(lines: list[dict]) -> list[dict]:
    """Layout rule: a Pali line followed by such an English title line (and no Roman line before the
    next Pali line) is a heading; the English line becomes its heading_en."""
    out: list[dict] = []
    i = 0
    while i < len(lines):
        ln = lines[i]
        j = i + 1
        while j < len(lines) and lines[j]["kind"] == "break":
            j += 1
        if (ln["kind"] == "pali_si" or (ln["kind"] == "heading" and "heading_en" not in ln)) \
                and j < len(lines) and _is_english_title(lines[j]):
            k = j + 1
            while k < len(lines) and lines[k]["kind"] not in ("pali_si", "roman"):
                k += 1
            if k >= len(lines) or lines[k]["kind"] != "roman":
                ln["kind"] = "heading"
                ln["heading_en"] = lines[j]["text"]
                out.append(ln)
                i = j + 1
                continue
        out.append(ln)
        i += 1
    return out


def build_lines(rows: list[dict], problems: list, pdf_page: int = 0) -> list[dict]:
    """Turn a page's raw rows into classified lines (digit marks dropped, titles attached)."""
    out: list[dict] = []
    for row in merge_baselines(rows):
        raw = "".join(s["text"] for s in row["spans"])
        if raw.strip() and re.fullmatch(r"[\d\s]+", raw):
            continue  # page number or paragraph mark
        for part in _split_notes(row["spans"]):
            local: list = []
            extra = None
            part = [s for s in part if not (is_fm(s["font"]) and s["size"] <= 12 and s["text"].strip().isdigit())]
            if classify(part, "") in ("heading", "subheading") and any(
                    not is_fm(s["font"]) and not _letterless(s) for s in part):
                kind = classify(part, "")
                text = line_text([s for s in part if is_fm(s["font"])], local)
                extra = line_text([s for s in part if not is_fm(s["font"])])
            else:
                text = line_text(part, local)
                kind = classify(part, text)
            if kind == "break" and (not out or out[-1]["kind"] == "break"):
                continue
            bearing = _bearing(part)
            main = max(bearing, key=lambda s: len(s["text"])) if bearing else None
            ln = {"kind": kind, "font": _name(main) if main else "", "size": main["size"] if main else 0,
                  "text": text, "_problems": local,
                  "_title": kind == "heading" and not any(is_fm(s["font"]) for s in bearing)}
            if extra is not None:
                ln["heading_en"] = extra
            out.append(ln)
    while out and out[-1]["kind"] == "break":
        out.pop()
    # the English title sits beside the Sinhala heading: store it on that heading
    merged: list[dict] = []
    i = 0
    while i < len(out):
        ln = out[i]
        if ln["_title"]:
            prev = merged[-1] if merged else None
            nxt = out[i + 1] if i + 1 < len(out) else None
            target = None
            if prev and prev["kind"] == "heading" and not prev["_title"] and "heading_en" not in prev:
                target = prev
            elif nxt and nxt["kind"] == "heading" and not nxt["_title"] and "heading_en" not in nxt:
                target = nxt
            if target is not None:
                target["heading_en"] = ln["text"]
                i += 1
                continue
        merged.append(ln)
        i += 1
    merged = _promote_titles(merged)
    for n, ln in enumerate(merged):
        for p in ln.pop("_problems"):
            problems.append({"pdf_page": pdf_page, "line": n, "problem": p})
        ln.pop("_title")
    return merged


def _new_unit(units: list[dict], heading: str | None) -> dict:
    unit = {"index": len(units), "heading": heading, "pali_si": [], "roman": [], "english": [], "notes": []}
    units.append(unit)
    return unit


def units_of(lines: list[dict]) -> list[dict]:
    """Group one page's lines into units: a heading, or a run of Pali with its Roman and English."""
    units: list[dict] = []
    previous = None
    for ln in lines:
        kind = ln["kind"]
        if kind in ("heading", "subheading"):
            _new_unit(units, ln["text"])
        elif kind == "pali_si":
            unit = units[-1] if units and previous == "pali_si" else _new_unit(units, None)
            unit["pali_si"].append(ln["text"])
        elif kind in ("roman", "english", "note"):
            unit = units[-1] if units else _new_unit(units, None)
            unit["notes" if kind == "note" else kind].append(ln["text"])
        previous = kind
    return units


def page_rows(page) -> list[dict]:
    rows = []
    for block in page.get_text("rawdict")["blocks"]:
        if block.get("type") != 0:
            continue
        for line in block["lines"]:
            spans = []
            for s in line["spans"]:
                text = "".join(ch["c"] for ch in s["chars"])
                if text:
                    spans.append({"x": s["bbox"][0], "font": s["font"].split("+")[-1],
                                  "size": round(s["size"], 1), "flags": s["flags"], "text": text})
            if spans:
                rows.append({"y": line["spans"][0]["origin"][1], "spans": spans})
    return rows


def extract(pdf_path: str) -> dict:
    with open(pdf_path, "rb") as fh:
        digest = hashlib.sha256(fh.read()).hexdigest()
    doc = fitz.open(pdf_path)
    problems: list = []
    pages = []
    fonts: set[str] = set()
    for pno in range(doc.page_count):
        rows = page_rows(doc[pno])
        fonts.update(s["font"] for r in rows for s in r["spans"] if s["text"].strip())
        lines = build_lines(rows, problems, pno + 1)
        pages.append({"pdf_page": pno + 1, "printed_page": pno + 1, "lines": lines, "units": units_of(lines)})
    return {
        "source": {"file": SOURCE_FILE, "sha256": digest, "pages": doc.page_count, "fonts": sorted(fonts),
                   "note": "Converted from FM Bindumathi with tools/fm_to_unicode.py; nothing corrected"},
        "conversion_problems": problems,
        "pages": pages,
    }


def write_review(data: dict, path: str) -> None:
    md = ["# Evening Puja and Chanting (Nottingham) — converted text for checking", "",
          f"- **Source:** {data['source']['file']}",
          f"- **PDF details:** {data['source']['pages']} pages, sha256 {data['source']['sha256']}",
          "- **Status:** machine-converted from an old (non-Unicode) Sinhala font. **Not yet checked by a person.**",
          "- **How to check:** open the PDF beside this file and compare page by page. "
          "Each section below is one page of the booklet.",
          "- **Spelling:** kept exactly as the booklet has it, including any misprints. Nothing was corrected.",
          "- **Layout key:** each line is shown with the kind it was given (heading, subheading, pali_si, roman, "
          "english, note, break, other), then the units the lines were grouped into.", ""]
    for pg in data["pages"]:
        md += ["---", "", f"## Page {pg['printed_page']} (PDF page {pg['pdf_page']})", ""]
        if not pg["lines"]:
            md += ["_(no text on this page)_", ""]
            continue
        md += ["| kind | text |", "|---|---|"]
        for ln in pg["lines"]:
            text = ln["text"].replace("|", "/")
            if ln.get("heading_en"):
                text += f"  _[{ln['heading_en']}]_"
            md.append(f"| {ln['kind']} | {text} |")
        md += ["", "Units:", ""]
        for u in pg["units"]:
            head = f" heading: {u['heading']}," if u["heading"] else ""
            md.append(f"- unit {u['index']}:{head} Pali {len(u['pali_si'])}, Roman {len(u['roman'])}, "
                      f"English {len(u['english'])}, notes {len(u['notes'])}")
        md.append("")
    md += ["---", "", "## Conversion problems", ""]
    if data["conversion_problems"]:
        md += ["| PDF page | line | problem |", "|---|---|---|"]
        md += [f"| {p['pdf_page']} | {p['line']} | {p['problem']} |" for p in data["conversion_problems"]]
    else:
        md.append("_None._")
    md.append("")
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(md))


def main() -> None:
    pdf_path, out_json, out_md = sys.argv[1], sys.argv[2], sys.argv[3]
    data = extract(pdf_path)
    os.makedirs(os.path.dirname(os.path.abspath(out_json)), exist_ok=True)
    with open(out_json, "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=1)
    write_review(data, out_md)
    kinds = collections.Counter(ln["kind"] for pg in data["pages"] for ln in pg["lines"])
    units = sum(len(pg["units"]) for pg in data["pages"])
    print(f"pages={len(data['pages'])} units={units} problems={len(data['conversion_problems'])} "
          f"kinds={dict(kinds)}")


if __name__ == "__main__":
    main()
