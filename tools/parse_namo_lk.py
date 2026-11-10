"""Turn the downloaded namo.lk articles into structured text for review.

Usage: python -I parse_namo_lk.py <raw_dir> <out_json> <out_md>

Each namo.lk article is a series of text boxes. The site marks a box that holds
Pali with the class "pali-quote" and a box that holds the Sinhala meaning with
"sin-meaning" (other marker classes are picked up the same way). This script
keeps the boxes in page order with those labels and changes nothing else.
"""
from __future__ import annotations

import collections
import html as html_lib
import json
import os
import re
import sys

MODULE_RE = re.compile(
    r'<div class="([^"]*\bet_pb_module et_pb_text\b[^"]*)"[^>]*>\s*<div class="et_pb_text_inner">(.*?)</div>\s*</div>',
    re.DOTALL,
)
# Ten older articles come through the data feed with the page builder's own
# markup left unexpanded: [et_pb_text module_class="pali-quote" ...]text[/et_pb_text]
SHORTCODE_RE = re.compile(r"\[et_pb_text([^\]]*)\](.*?)\[/et_pb_text\]", re.DOTALL)
SHORTCODE_CLASS_RE = re.compile(r"module_class=(?:&#8221;|&#8243;|&quot;|\")([^&\"]*)")
KNOWN_LAYOUT = re.compile(r"^(et_pb_|et-|et_)")


def text_boxes(rendered: str) -> list[tuple[str, str]]:
    """All text boxes of an article in page order, as (marker classes, inner html)."""
    found = [(m.start(), m.group(1), m.group(2)) for m in MODULE_RE.finditer(rendered)]
    for m in SHORTCODE_RE.finditer(rendered):
        cls = SHORTCODE_CLASS_RE.search(m.group(1))
        found.append((m.start(), cls.group(1) if cls else "", m.group(2)))
    found.sort(key=lambda t: t[0])
    return [(cls, inner) for _, cls, inner in found]


def to_text(fragment: str) -> str:
    s = re.sub(r"<!--.*?-->", "", fragment, flags=re.DOTALL)
    s = re.sub(r"<br\s*/?>", "\n", s)
    s = re.sub(r"</(p|h[1-6]|li|div)>", "\n\n", s)
    s = re.sub(r"<[^>]+>", "", s)
    s = html_lib.unescape(s).replace(" ", " ").replace("​", "")
    lines = [re.sub(r"[ \t]+", " ", ln).strip() for ln in s.split("\n")]
    out: list[str] = []
    for ln in lines:
        if ln or (out and out[-1]):
            out.append(ln)
    while out and not out[-1]:
        out.pop()
    return "\n".join(out)


def role_of(class_attr: str, inner: str) -> tuple[str, list[str]]:
    extra = [c for c in class_attr.split() if not KNOWN_LAYOUT.match(c)]
    joined = " ".join(extra).lower()
    if "pali" in joined:
        return "pali", extra
    if "sin" in joined:
        return "sinhala_meaning", extra
    if "eng" in joined or re.search(r"\ben\b", joined):
        return "english_meaning", extra
    if re.match(r"\s*<h[1-6]", inner):
        return "heading", extra
    return "text", extra


def main() -> None:
    raw_dir, out_json, out_md = sys.argv[1], sys.argv[2], sys.argv[3]
    index = json.load(open(os.path.join(raw_dir, "index.json"), encoding="utf-8"))
    cats = {}
    cat_path = os.path.join(raw_dir, "categories.json")
    if os.path.exists(cat_path):
        for c in json.load(open(cat_path, encoding="utf-8")):
            cats[c["id"]] = html_lib.unescape(c["name"])

    items = []
    marker_classes = collections.Counter()
    for entry in index["items"]:
        rec = json.load(open(os.path.join(raw_dir, entry["file"]), encoding="utf-8"))
        rendered = rec["content"]["rendered"]
        blocks = []
        for class_attr, inner in text_boxes(rendered):
            role, extra = role_of(class_attr, inner)
            marker_classes.update(extra)
            text = to_text(inner)
            if text:
                blocks.append({"role": role, "text": text})
        items.append({
            "kind": entry["kind"],
            "slug": entry["slug"],
            "title": html_lib.unescape(entry["title"] or ""),
            "link": entry["link"],
            "published": entry["date"],
            "modified": entry["modified"],
            "categories": [cats.get(c, str(c)) for c in (entry.get("categories") or [])],
            "blocks": blocks,
        })

    data = {
        "source": index["source"],
        "fetched_utc": index["fetched_utc"],
        "method": index["method"],
        "reuse_terms_on_site": index["reuse_terms_on_site"],
        "status": "Copied as published on namo.lk. Not checked against any printed book.",
        "roles": {
            "heading": "section heading on the page",
            "pali": "box the site marks as Pali (written in Sinhala letters)",
            "sinhala_meaning": "box the site marks as Sinhala meaning",
            "english_meaning": "box the site marks as English",
            "text": "any other text box (introductions, notes)",
        },
        "marker_classes_seen": dict(marker_classes),
        "items": items,
    }
    os.makedirs(os.path.dirname(out_json), exist_ok=True)
    with open(out_json, "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=1)

    posts = [it for it in items if it["kind"] == "posts"]
    pages = [it for it in items if it["kind"] == "pages"]
    md = ["# namo.lk — every text page, as published", ""]
    md.append(f"- **Source:** {index['source']} (downloaded {index['fetched_utc']} through the site's public data feed)")
    md.append(f"- **Articles:** {len(posts)} prayer/sutta articles, plus {len(pages)} general pages (listed at the end)")
    md.append("- **Status:** copied exactly as namo.lk publishes it. Not checked against a printed book.")
    md.append("- **Reuse:** namo.lk states no reuse terms anywhere on the site.")
    md.append("- **Layout key:** normal text = Pali (in Sinhala letters). Indented quote = Sinhala meaning. "
              "*Italic quote* = English, where the site gives it.")
    md.append("")
    md.append("## List of articles")
    md.append("")
    md.append("| # | Title | Pali boxes | Sinhala boxes | English boxes | Link |")
    md.append("|---|---|---|---|---|---|")
    for n, it in enumerate(posts, 1):
        counts = collections.Counter(b["role"] for b in it["blocks"])
        md.append(f"| {n} | {it['title']} | {counts['pali']} | {counts['sinhala_meaning']} | "
                  f"{counts['english_meaning']} | {it['link']} |")
    md.append("")
    for n, it in enumerate(posts, 1):
        md.append("---")
        md.append("")
        md.append(f"## {n}. {it['title']}")
        md.append("")
        md.append(f"Link: {it['link']} · published {it['published'][:10]} · last changed {it['modified'][:10]}")
        md.append("")
        for b in it["blocks"]:
            lines = b["text"].split("\n")
            if b["role"] == "heading":
                md.append("### " + " ".join(ln for ln in lines if ln))
            elif b["role"] == "pali":
                md.extend((ln + "  ") if ln else "" for ln in lines)
            elif b["role"] == "sinhala_meaning":
                md.extend(("> " + ln + "  ") if ln else ">" for ln in lines)
            elif b["role"] == "english_meaning":
                md.extend(("> *" + ln + "*  ") if ln else ">" for ln in lines)
            else:
                md.append("**[other text on the page]**  ")
                md.extend((ln + "  ") if ln else "" for ln in lines)
            md.append("")
    md.append("---")
    md.append("")
    md.append("## General pages (not prayer text; stored but not reproduced here)")
    md.append("")
    for it in pages:
        md.append(f"- {it['title']} — {it['link']}")
    os.makedirs(os.path.dirname(out_md), exist_ok=True)
    with open(out_md, "w", encoding="utf-8") as fh:
        fh.write("\n".join(md) + "\n")

    print(f"posts={len(posts)} pages={len(pages)} marker classes={dict(marker_classes)}")
    for it in posts:
        counts = collections.Counter(b["role"] for b in it["blocks"])
        print(f"  {it['slug']:42s} {dict(counts)}")


if __name__ == "__main__":
    main()
