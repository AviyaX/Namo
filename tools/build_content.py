"""Build the app's content file, assets/content/namaskaraya_to_pin_dima.json,
from the text already stored in content/extracted/ (design §5).

Usage: python -I -X utf8 tools/build_content.py <project_root> [--check]

Every line of verse comes out of the stored sources by the rules below. The only
changes made to it are the spelling corrections of design §5.3, each applied the
number of times §5.3 gives; any other count, or a missing anchor, stops the build.
--check builds in memory and compares with the file instead of writing it.
"""
from __future__ import annotations

import json
import pathlib
import re
import sys

OUTPUT = pathlib.Path("assets/content/namaskaraya_to_pin_dima.json")
TITLE = "Buddha Wandanawa"
SUBTITLE = "බුද්ධ වන්දනාව"
NOT_NAMED = "not named by the source"
BRISBANE_TRANSLATOR = "prepared by Cynthia Gunawardana"
CHECKED = "checked against source"
NEEDS_CHECKING = "needs checking"

NAMO_SLUG = "buddha-puja"
NAMO_LOCATOR = "https://namo.lk/buddha-puja/"
NAMO_COLLECTED = "2026-11-09"
NAMO_STOP_HEADING = "Related Resources"
BOOKLET_NAME = "paritha.org booklet (Wandana Gatha)"
BOOKLET_COLLECTED = "2026-11-09"
MAHAMEVNAWA_NAME = "Mahamevnawa \"Vandana\" booklet (Mahamevna Bhavana Asapuwa, Markham ON)"
MAHAMEVNAWA_COLLECTED = "2026-11-09"
BRISBANE_NAME = ("\"Daily Buddha Vandana\", Yasodhara Dhamma School, "
                 "Sri Lankarama Maha Viharaya, Ellen Grove, Brisbane")
BRISBANE_COLLECTED = "2026-11-10"

# Lines further apart than this (in PDF points) start a new stanza.
STANZA_GAP = 22.0

# Design §5.3. (source, printed form, corrected form, places, reason)
CORRECTIONS = [
    ("namo", "ගච්චාමි", "ගච්ඡාමි", 9, "20 uses elsewhere on namo.lk, 9 in the booklet"),
    ("namo", "විඡ්ඡාචරණ", "විජ්ජාචරණ", 1, "18 elsewhere on namo.lk, 4 in the booklet"),
    ("namo", "සමාදියාමී", "සමාදියාමි", 4,
     "10 elsewhere on namo.lk, 5 in the booklet; the page itself uses it twice"),
    ("namo", "සුමාමේරය", "සුරාමේරය", 1,
     "namo.lk's own \"ten precepts\" page and the booklet both print සුරාමේරය; "
     "the page's own Sinhala meaning for the line says සුරාපානය"),
    ("namo", "ධානේසු", "ඨානේසු", 1,
     "the owner's word, 2026-11-10 (\"ඨානේසු is the correct\"); namo.lk's own Sinhala meaning "
     "says \"in all places\" and the Brisbane booklet prints \"Sabbatane\""),
    ("namo", "අධිවාසේ තුනෝ", "අධිවාසේතු නෝ", 1,
     "spacing only; the page itself prints it this way 3 times, the booklet 11"),
    ("namo", "බෝදි", "බෝධි", 1, "9 times on the page itself, 15 elsewhere on namo.lk, 13 in the booklet"),
    ("booklet", "රුස්කර", "රැස්කර", 3, "රැස් 6 times elsewhere in the booklet and 8 on namo.lk"),
    ("booklet", "පුණ්ය", "පුණ්‍ය", 3, "the booklet's own other use; namo.lk"),
    ("booklet", "භූතයා්", "භූතයෝ", 1, "3 times elsewhere in the booklet, 2 on namo.lk"),
    ("booklet", "ම විසින්", "මා විසින්", 3, "5 elsewhere in the booklet, 42 on namo.lk"),
    ("booklet", "සාසණ", "සාසන", 1, "8 elsewhere in the booklet, 5 on namo.lk"),
    ("booklet", "පුංඤ්ඤකෙත්තං", "පුඤ්ඤක්ඛෙත්තං", 1, "2 elsewhere in the booklet, 6 on namo.lk"),
    ("booklet", "අනුත්ථරං", "අනුත්තරං", 1, "3 elsewhere in the booklet, 10 on namo.lk"),
    ("booklet", "දේවානාගා", "දේවා නාගා", 3, "spacing only; both sources print two words elsewhere"),
]
# Forms that match only as a whole word (here: ම must not be the end of a longer word).
WHOLE_WORD = {"ම විසින්"}
SINHALA_LETTER = "඀-෿‍"

# Sections 18-19: the paritha.org booklet by printed page and line index (design §5.1, Task 4).
BOOKLET_SECTION_HEADINGS = {18: (37, 0), 19: (37, 32)}
BOOKLET_HEADING_SPELLING = ("පින්දීම", "පින් දීම", "owner's spelling")
BOOKLET_VERSES = [
    # (verse id, printed page, large-line stanzas, small lines)
    ("s18-v1", 37, [(2, 3)], (5, 6)),
    ("s18-v2", 37, [(8, 9)], (11, 12)),
    ("s18-v3", 37, [(14, 15)], (17, 18)),
    ("s18-v4", 37, [(20, 21), (23, 24), (26, 27)], (29, 30)),
    ("s19-v1", 37, [(34, 35)], (37, 38)),
    ("s19-v2", 38, [(0, 1)], (3, 4)),
    ("s19-v3", 38, [(6, 7)], (9, 11)),
]

# English from the Mahamevnawa PDF: right-column lines within the y ranges.
# (verse id, [(pdf page, y from, y to), ...], first line starts with, last line ends with, kind)
MAHAMEVNAWA = [
    ("s01-v1", [(2, 123.7, 199.0)], "Homage to the Blissful One", "Fully Enlightened One.", "translation"),
    ("s02-v1", [(2, 259.5, 410.1)], "I go to the Buddha for refuge.",
     "A third time, I go to the Sangha for refuge.", "translation"),
    ("s03-v1", [(2, 470.6, 606.1)], "I undertake the training rule to abstain from killing",
     "intoxicants and harmful drugs.", "translation"),
    ("s04-v1", [(3, 123.6, 500.8)], "Such indeed is the Blessed One:",
     "holds these great, extra-ordinary qualities.", "explanation"),
    ("s05-v1", [(4, 123.9, 320.2)], "\"Svakkhato\" -", "the wise to understand and realize.", "explanation"),
    ("s06-v1", [(4, 389.7, 661.2)], "\"Supatipanno\" - The Order of the Blessed One are",
     "hospitality, worthy of respect and worship.", "explanation"),
    ("s18-v4", [(16, 665.7, float("inf")), (17, 0.0, 253.0)], "May mighty deities and nagas",
     "long protect myself and others.", "translation"),
    ("s19-v1", [(17, 639.3, 684.4)], "If, due to negligence, I have done some",
     "Perfect one of vast wisdom.", "translation"),
    ("s19-v2", [(18, 102.1, 147.3)], "If, due to negligence, I have done some",
     "Visible and unaffected by time.", "translation"),
    ("s19-v3", [(18, 177.4, 226.6)], "If, due to negligence, I have done some",
     "Practising well and supreme.", "translation"),
]

# Sections 1-6 are prose set in a narrow column and are re-set as sentences; the others are verse,
# whose line breaks are the translator's and stay.
MAHAMEVNAWA_PROSE = {"s01-v1", "s02-v1", "s03-v1", "s04-v1", "s05-v1", "s06-v1"}

# English from the Brisbane booklet: non-bold lines of one block, first anchor through last anchor.
# (verse id, pdf page, block, first line starts with, last line starts with)
BRISBANE = [
    ("s07-v1", 8, 4, "I salute every chetiya", "And all images of the Buddha."),
    ("s08-v1", 9, 1, "Seated at whose base,", "That very bodhi tree do I adore"),
    ("s08-v2", 9, 1, "These great trees of enlightenment", "May there be homage to you."),
    ("s10-v1", 10, 1, "With lights brightly shining", "(*three worlds"),
    ("s11-v1", 10, 2, "With perfumed incense,", "Who dispels the darkness"),
    ("s11-v2", 10, 2, "Fragrant of voice and form,", "With fragrance I worship."),
    ("s12-v1", 9, 1, "This mass of flowers fresh", "I offer at the sacred lotus"),
    ("s12-v2", 9, 2, "I worship the Buddha with these flowers;", "Our body will undergo decay."),
    ("s13-v1", 11, 2, "O Lord! The blessed one", "Out of great compassion on us."),
    ("s15-v1", 11, 3, "O Lord! The blessed one", "from noon to the following morning"),
    ("s18-v1", 12, 1, "May all devas share this merit", "Of happiness and prosperity."),
]

# Verses marked "needs checking", with the wording of design §5.2 / §5.3.
NEEDS = {
    "s11-v1": [
        "namo.lk prints the second line as \"සුගන්ධිනාහං ගන්ධේන – පූජයාමි තථාගතං\", the same line as "
        "in the next verse. The Brisbane booklet reads \"Pujaye Pujaniyanam tam / Puja bhajana "
        "muttamam\", and namo.lk's own Sinhala meaning translates that reading. No stored source has "
        "that line in Sinhala letters, so the Pali stays as namo.lk prints it and is not changed "
        "without the owner's word.",
        "The Brisbane English for this verse also ends with a line that belongs to the lamp verse "
        "(\"Who dispels the darkness\"); it is kept as printed.",
    ],
    "s12-v2": [
        "The app's Pali reads \"ලභාමි මොක්ඛං\" (the paritha.org booklet reads the same); the "
        "Brisbane booklet reads \"cha hothu mokkam\" and translates that.",
    ],
    "s18-v4": [
        "The app's Pali reads \"ලෝක සාසනං\"; Mahamevnawa reads \"sasanam\". (The Brisbane booklet "
        "reads \"loka sasanam\", as the app does.)",
    ],
    "s19-v3": [
        "The app's Pali ends \"පුඤ්ඤක්ඛෙත්තං අනුත්තරං\"; Mahamevnawa ends \"Supatipanna anuttara\".",
    ],
}


class BuildError(Exception):
    pass


def _load(root: pathlib.Path, name: str) -> dict:
    with open(root / "content" / "extracted" / f"{name}.json", encoding="utf-8") as f:
        return json.load(f)


def _strip_lines(text: str) -> str:
    return "\n".join(line.strip(" ") for line in text.split("\n"))


def _verse(verse_id: str, pali_si: str, sinhala: str) -> dict:
    return {"id": verse_id, "pali_si": pali_si, "pali_roman": None, "sinhala": sinhala,
            "english": None, "english_source": None, "english_kind": None,
            "check": CHECKED, "notes": [], "corrections": []}


def _namo_sections(namo: dict) -> list[dict]:
    items = [it for it in namo["items"] if it["slug"] == NAMO_SLUG]
    if len(items) != 1:
        raise BuildError(f"namo.lk: expected one item {NAMO_SLUG!r}, found {len(items)}")
    source = {"name": "namo.lk", "locator": NAMO_LOCATOR, "collected": NAMO_COLLECTED, "translator": NOT_NAMED}
    sections: list[dict] = []
    blocks = items[0]["blocks"]
    i = 0
    while i < len(blocks):
        block = blocks[i]
        role, text = block["role"], block["text"]
        if role == "heading":
            heading = re.sub(r"^\d+\.\s*", "", text.strip(" "))
            if heading == NAMO_STOP_HEADING:
                break
            sections.append({"heading": heading, "source": source, "corrections": [], "verses": []})
            i += 1
        elif role == "pali":
            if not sections:
                raise BuildError(f"namo.lk block {i}: Pali before the first heading")
            if i + 1 >= len(blocks) or blocks[i + 1]["role"] != "sinhala_meaning":
                raise BuildError(f"namo.lk block {i}: Pali not followed by a Sinhala meaning")
            verses = sections[-1]["verses"]
            verse_id = f"s{len(sections):02d}-v{len(verses) + 1}"
            verses.append(_verse(verse_id, _strip_lines(text), _strip_lines(blocks[i + 1]["text"])))
            i += 2
        elif role == "sinhala_meaning":
            # a second Sinhala meaning in a row joins the verse before it
            if not sections or not sections[-1]["verses"]:
                raise BuildError(f"namo.lk block {i}: Sinhala meaning with no verse before it")
            verse = sections[-1]["verses"][-1]
            verse["sinhala"] += "\n\n" + _strip_lines(text)
            i += 1
        else:
            raise BuildError(f"namo.lk block {i}: unexpected role {role!r}")
    else:
        raise BuildError(f"namo.lk: heading {NAMO_STOP_HEADING!r} not found")
    return sections


def _booklet_line(pages: dict, page: int, index: int, kind: str) -> str:
    line = pages[page][index]
    if line["kind"] != kind:
        raise BuildError(f"booklet page {page} line {index}: expected {kind!r}, found {line['kind']!r}")
    return line["text"]


def _booklet_sections(booklet: dict) -> list[dict]:
    pages = {p["printed_page"]: p["lines"] for p in booklet["pages"] if p["printed_page"] in (37, 38)}
    url = booklet["source"]["url"]
    sections = {}
    for number, (page, index) in BOOKLET_SECTION_HEADINGS.items():
        heading = _booklet_line(pages, page, index, "subheading")
        locator = f"{url}, printed page 37" if number == 18 else f"{url}, printed pages 37–38"
        sections[number] = {
            "heading": heading,
            "source": {"name": BOOKLET_NAME, "locator": locator, "collected": BOOKLET_COLLECTED,
                       "translator": NOT_NAMED},
            "corrections": [], "verses": []}
    printed, corrected, reason = BOOKLET_HEADING_SPELLING
    heading = sections[18]["heading"]
    if heading.count(printed) != 1:
        raise BuildError(f"section 18 heading {heading!r} does not contain {printed!r} once")
    sections[18]["heading"] = heading.replace(printed, corrected)
    sections[18]["corrections"].append(
        {"field": "heading", "from": printed, "to": corrected, "count": 1, "reason": reason})
    for verse_id, page, stanzas, (small_from, small_to) in BOOKLET_VERSES:
        pali = "\n\n".join(
            "\n".join(_booklet_line(pages, page, k, "large") for k in range(a, b + 1)) for a, b in stanzas)
        sinhala = " ".join(_booklet_line(pages, page, k, "small") for k in range(small_from, small_to + 1))
        sections[int(verse_id[1:3])]["verses"].append(_verse(verse_id, pali, sinhala))
    return [sections[18], sections[19]]


def _correct(verse: dict, scope_rows: list[tuple], totals: dict) -> None:
    for _, printed, corrected, _, reason in scope_rows:
        if printed in WHOLE_WORD:
            pattern = re.compile(f"(?<![{SINHALA_LETTER}]){re.escape(printed)}")
        else:
            pattern = re.compile(re.escape(printed))
        for field in ("pali_si", "sinhala"):
            new_text, count = pattern.subn(corrected, verse[field])
            if count:
                verse[field] = new_text
                verse["corrections"].append(
                    {"field": field, "from": printed, "to": corrected, "count": count, "reason": reason})
                totals[printed] += count


def _join_by_gap(lines: list[tuple[int, float, str]]) -> str:
    """Join (page, y, text) lines with \\n; a gap over STANZA_GAP on one page becomes \\n\\n."""
    out = lines[0][2]
    for (page_a, y_a, _), (page_b, y_b, text) in zip(lines, lines[1:]):
        out += ("\n\n" if page_a == page_b and y_b - y_a > STANZA_GAP else "\n") + text
    return out


def _check_whitespace_only(before: str, after: str) -> None:
    if re.sub(r"\s+", "", before) != re.sub(r"\s+", "", after):
        raise BuildError("reflowing English changed more than line breaks and spaces")


def _reflow_prose(text: str) -> str:
    """Re-set column-wrapped prose as sentences: a source line starts a new line only when it is the
    first of its paragraph, follows a line ending in '.' or ':', or itself starts with a double quote.
    Otherwise it joins the line before with one space, or with none after a letter and '-'."""
    paragraphs = []
    for paragraph in text.split("\n\n"):
        out = ""
        for k, line in enumerate(paragraph.split("\n")):
            if k == 0:
                out = line
            elif out.endswith((".", ":")) or line.startswith('"'):
                out += "\n" + line
            elif re.search(r"[^\W\d_]-$", out):
                out += line
            else:
                out += " " + line
        paragraphs.append(out)
    result = "\n\n".join(paragraphs)
    _check_whitespace_only(text, result)
    return result


def _join_footnote(text: str) -> str:
    """Join each paragraph that is a '( ... )' footnote into one line."""
    paragraphs = []
    for paragraph in text.split("\n\n"):
        lines = paragraph.split("\n")
        if lines[0].startswith("(") and lines[-1].endswith(")"):
            paragraph = " ".join(lines)
        paragraphs.append(paragraph)
    result = "\n\n".join(paragraphs)
    _check_whitespace_only(text, result)
    return result


def _mahamevnawa_english(maha: dict) -> dict:
    pages = {p["pdf_page"]: p["right_column"] for p in maha["pages"]}
    url = maha["source"]["url"]
    result = {}
    for verse_id, ranges, first, last, kind in MAHAMEVNAWA:
        lines = []
        for page, y_from, y_to in ranges:
            lines += [(page, ln["y"], ln["text"]) for ln in sorted(pages[page], key=lambda ln: ln["y"])
                      if y_from <= ln["y"] <= y_to and not ln["bold"]]
        if not lines or not lines[0][2].startswith(first):
            raise BuildError(f"{verse_id}: Mahamevnawa range does not start with {first!r}")
        if not lines[-1][2].endswith(last):
            raise BuildError(f"{verse_id}: Mahamevnawa range does not end with {last!r}")
        first_page, last_page = ranges[0][0], ranges[-1][0]
        where = f"PDF page {first_page}" if first_page == last_page else f"PDF pages {first_page}–{last_page}"
        text = _join_by_gap(lines)
        if verse_id in MAHAMEVNAWA_PROSE:
            text = _reflow_prose(text)
        result[verse_id] = (text, kind, {
            "name": MAHAMEVNAWA_NAME, "locator": f"{url}, {where}", "collected": MAHAMEVNAWA_COLLECTED,
            "translator": NOT_NAMED})
    return result


def _is_divider(text: str) -> bool:
    stripped = text.strip()
    return bool(stripped) and set(stripped) <= {"-"}


def _brisbane_english(yaso: dict) -> dict:
    pages = {p["pdf_page"]: p["lines"] for p in yaso["pages"]}
    file_name = yaso["source"]["file"].split(" (")[0]
    result = {}
    for verse_id, page, block, first, last in BRISBANE:
        lines = sorted((ln for ln in pages[page]
                        if ln["block"] == block and not ln["bold"] and not _is_divider(ln["text"])),
                       key=lambda ln: ln["y"])
        starts = [k for k, ln in enumerate(lines) if ln["text"].startswith(first)]
        ends = [k for k, ln in enumerate(lines) if ln["text"].startswith(last)]
        if len(starts) != 1 or len(ends) != 1 or ends[0] < starts[0]:
            raise BuildError(f"{verse_id}: Brisbane anchors {first!r} .. {last!r} not found once, in order, "
                             f"on page {page} block {block}")
        chosen = [(page, ln["y"], ln["text"]) for ln in lines[starts[0]:ends[0] + 1]]
        result[verse_id] = (_join_footnote(_join_by_gap(chosen)), "translation", {
            "name": BRISBANE_NAME, "locator": f"{file_name}, PDF page {page}", "collected": BRISBANE_COLLECTED,
            "translator": BRISBANE_TRANSLATOR})
    return result


def build(root: pathlib.Path) -> dict:
    root = pathlib.Path(root)
    sections = _namo_sections(_load(root, "namo_lk"))
    if len(sections) != 17:
        raise BuildError(f"namo.lk: expected 17 sections, found {len(sections)}")
    sections += _booklet_sections(_load(root, "paritha_booklet"))

    totals = {row[1]: 0 for row in CORRECTIONS}
    namo_rows = [row for row in CORRECTIONS if row[0] == "namo"]
    booklet_rows = [row for row in CORRECTIONS if row[0] == "booklet"]
    for number, section in enumerate(sections, start=1):
        for verse in section["verses"]:
            _correct(verse, namo_rows if number <= 17 else booklet_rows, totals)
    for _, printed, corrected, expected, _ in CORRECTIONS:
        if totals[printed] != expected:
            raise BuildError(f"correction {printed!r} -> {corrected!r}: applied {totals[printed]} times, "
                             f"§5.3 says {expected}")

    english = {**_mahamevnawa_english(_load(root, "mahamevnawa_vandana")),
               **_brisbane_english(_load(root, "yasodhara_vandana"))}
    verses = {v["id"]: v for s in sections for v in s["verses"]}
    for verse_id, (text, kind, source) in english.items():
        if verse_id not in verses:
            raise BuildError(f"English for {verse_id}, which is not a verse")
        verses[verse_id].update({"english": text, "english_source": source, "english_kind": kind})
    for verse_id, notes in NEEDS.items():
        verses[verse_id]["check"] = NEEDS_CHECKING
        verses[verse_id]["notes"] = list(notes)

    out_sections = []
    for number, section in enumerate(sections, start=1):
        check = NEEDS_CHECKING if any(v["check"] == NEEDS_CHECKING for v in section["verses"]) else CHECKED
        out_sections.append({"id": f"s{number:02d}", "number": number, "heading": section["heading"],
                             "check": check, "source": section["source"],
                             "corrections": section["corrections"], "verses": section["verses"]})
    return {"schema": 1, "categories": [{
        "id": "cat-namaskaraya", "title": TITLE, "subtitle": SUBTITLE,
        "readings": [{"id": "namaskaraya", "title": TITLE, "audio": None, "sections": out_sections}]}]}


def render(data: dict) -> bytes:
    return (json.dumps(data, ensure_ascii=False, indent=1) + "\n").encode("utf-8")


def _first_difference(built: dict, path: pathlib.Path) -> str:
    try:
        stored = json.loads(path.read_text(encoding="utf-8"))
        stored_verses = {v["id"]: v for c in stored["categories"] for r in c["readings"]
                         for s in r["sections"] for v in s["verses"]}
    except (OSError, ValueError, KeyError, TypeError) as e:
        return f"cannot read {path}: {e}"
    for c in built["categories"]:
        for r in c["readings"]:
            for s in r["sections"]:
                for v in s["verses"]:
                    if stored_verses.get(v["id"]) != v:
                        return f"first differing verse: {v['id']}"
    return "the verses match; the difference is outside them (headings, sources or layout)"


def main() -> None:
    args = sys.argv[1:]
    check = "--check" in args
    args = [a for a in args if a != "--check"]
    if len(args) != 1:
        sys.exit("usage: python -I -X utf8 tools/build_content.py <project_root> [--check]")
    root = pathlib.Path(args[0])
    try:
        data = build(root)
    except BuildError as e:
        sys.exit(f"build_content: {e}")
    rendered = render(data)
    path = root / OUTPUT
    if check:
        if path.exists() and path.read_bytes() == rendered:
            print("content file is up to date")
            return
        sys.exit(f"content file is out of date ({_first_difference(data, path)}); "
                 f"run python -I -X utf8 tools/build_content.py {args[0]}")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(rendered)
    print(f"wrote {OUTPUT.as_posix()}")


if __name__ == "__main__":
    main()
