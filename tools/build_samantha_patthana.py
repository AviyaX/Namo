"""Builds the Samantha Pattana Dharma Wandanawa content from the converted source folder.

Extract mode reads <src>/converted/structure.json, <src>/converted/pages/page-NN.txt and
<src>/introduction_owner_supplied.md (as data only) and writes
content/extracted/samantha_patthana.json, the tracked file every later step builds from.

  python -I -X utf8 tools/build_samantha_patthana.py <project_root> --extract <source_folder>
"""
from __future__ import annotations

import json
import pathlib
import sys

OUTPUT = pathlib.Path("content/extracted/samantha_patthana.json")
STRUCTURE = pathlib.Path("converted/structure.json")
PAGES = pathlib.Path("converted/pages")
INTRODUCTION = pathlib.Path("introduction_owner_supplied.md")

# Sinhala title of the Vandana; structure.json's title_page splits it over several lines, so it is a constant.
TITLE = "සමන්ත පට්ඨාන ධර්ම වන්දනාව"

PARTS = 24


class BuildError(Exception):
    pass


def _read(path: pathlib.Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except OSError as e:
        raise BuildError(f"cannot read {path.as_posix()}: {e}")


def _pos(entry, what: str) -> tuple[int, int]:
    try:
        return (int(entry["page"]), int(entry["line"]))
    except (KeyError, TypeError, ValueError):
        raise BuildError(f"structure.json: {what} has no page and line")


def _first(block, what: str) -> tuple[int, int]:
    if not isinstance(block, list) or not block:
        raise BuildError(f"structure.json: {what} is empty")
    return _pos(block[0], what)


def _starts(half: dict, name: str, opening: list[tuple[str, str]]) -> list[tuple[str, dict, tuple[int, int]]]:
    """Unit (id, fields, start) in order for one half, from the starts in structure.json."""
    units = []
    for unit_id, key in opening:
        kind = {"u-homage": "homage", "u-verses": "verses", "u-list": "list"}[unit_id]
        units.append((unit_id, {"kind": kind}, _first(half["opening"].get(key), f"{name} {key}")))
    parts = half.get("parts")
    if not isinstance(parts, list) or [p.get("number") for p in parts] != list(range(1, PARTS + 1)):
        raise BuildError(f"structure.json: {name} part numbers are not 1-{PARTS} in order")
    for p in parts:
        units.append((f"u-part-{p['number']}", {"kind": "part", "number": p["number"]},
                      _pos(p, f"{name} part {p['number']}")))
    units.append(("u-closing", {"kind": "closing"}, _first(half.get("closing"), f"{name} closing")))
    starts = [s for _, _, s in units]
    if any(a >= b for a, b in zip(starts, starts[1:])):
        raise BuildError(f"structure.json: {name} units overlap or are out of order")
    first_part = len(units) - PARTS - 1
    for i, p in enumerate(parts):
        if _pos(p["ends_before"], f"{name} part {p['number']} ends_before") != starts[first_part + i + 1]:
            raise BuildError(f"structure.json: {name} part {p['number']} does not end where the next unit starts")
    return units


def _half_lines(src: pathlib.Path, pages: list[int]) -> list[dict]:
    """Every text line of the pages: not line 1 (the printed page number), not blank."""
    lines = []
    for page in range(pages[0], pages[1] + 1):
        text = _read(src / PAGES / f"page-{page:02d}.txt")
        for number, line in enumerate(text.split("\n"), start=1):
            if number == 1 or not line.strip():
                continue
            if line != line.strip():
                raise BuildError(f"page {page} line {number} has leading or trailing whitespace")
            lines.append({"page": page, "line": number, "text": line})
    return lines


def _assign(lines: list[dict], units: list, name: str) -> dict[str, list[dict]]:
    out = {unit_id: [] for unit_id, _, _ in units}
    starts = [s for _, _, s in units]
    for entry in lines:
        at = (entry["page"], entry["line"])
        if at < starts[0]:
            raise BuildError(f"{name} page {at[0]} line {at[1]} is outside every unit")
        k = max(i for i, s in enumerate(starts) if s <= at)
        out[units[k][0]].append(entry)
    for unit_id, got in out.items():
        if not got:
            raise BuildError(f"{name} unit {unit_id} has no text")
    return out


def _introduction(src: pathlib.Path) -> list[str]:
    parts = _read(src / INTRODUCTION).replace("\r\n", "\n").split("\n---\n", 1)
    if len(parts) != 2:
        raise BuildError(f"{INTRODUCTION.as_posix()} has no --- line")
    paragraphs = [p for p in parts[1].strip("\n").split("\n\n") if p.strip()]
    if len(paragraphs) != 3:
        raise BuildError(f"{INTRODUCTION.as_posix()} has {len(paragraphs)} paragraphs, expected 3")
    return paragraphs


def extract(src) -> dict:
    src = pathlib.Path(src)
    try:
        structure = json.loads(_read(src / STRUCTURE))
        pali, sinhala = structure["pali"], structure["sinhala_meaning"]
        pali_pages, sinhala_pages = pali["pages"], sinhala["pages"]
    except (ValueError, KeyError, TypeError) as e:
        raise BuildError(f"structure.json: unreadable ({e!r})")
    pali_units = _starts(pali, "pali", [("u-homage", "homage"), ("u-verses", "three_opening_verses"),
                                         ("u-list", "list_of_24_paccayas")])
    sinhala_units = _starts(sinhala, "sinhala", [("u-homage", "homage"), ("u-list", "list_of_24")])
    pali_text = _assign(_half_lines(src, pali_pages), pali_units, "pali")
    sinhala_text = _assign(_half_lines(src, sinhala_pages), sinhala_units, "sinhala")
    units = []
    for unit_id, fields, _ in pali_units:
        unit = {"id": unit_id, **fields, "pali": pali_text[unit_id], "sinhala": sinhala_text.get(unit_id, [])}
        units.append(unit)
    return {
        "source": {
            "structure": STRUCTURE.as_posix(),
            "pages": PAGES.as_posix() + "/page-NN.txt",
            "pali_pages": pali_pages,
            "sinhala_pages": sinhala_pages,
            "introduction": INTRODUCTION.as_posix(),
            "introduction_pages": structure.get("introduction", {}).get("pages"),
        },
        "title": TITLE,
        "introduction": _introduction(src),
        "units": units,
    }


def render(obj: dict) -> str:
    return json.dumps(obj, ensure_ascii=False, indent=1) + "\n"


def main() -> None:
    args = sys.argv[1:]
    if len(args) != 3 or args[1] != "--extract":
        sys.exit("usage: python -I -X utf8 tools/build_samantha_patthana.py <project_root> --extract <source_folder>")
    root = pathlib.Path(args[0])
    try:
        text = render(extract(args[2]))
        (root / OUTPUT).parent.mkdir(parents=True, exist_ok=True)
        (root / OUTPUT).write_bytes(text.encode("utf-8"))
        print(f"wrote {OUTPUT.as_posix()}")
    except BuildError as e:
        sys.exit(f"build_samantha_patthana: {e}")


if __name__ == "__main__":
    main()
