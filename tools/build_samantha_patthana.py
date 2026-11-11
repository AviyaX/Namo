"""Builds the Samantha Pattana Dharma Wandanawa content.

Extract mode reads <src>/converted/structure.json, <src>/converted/pages/page-NN.txt and
<src>/introduction_owner_supplied.md (as data only) and writes
content/extracted/samantha_patthana.json, the tracked file every later step builds from.
Build mode turns that file and content/extracted/samantha_patthana_times.json into
assets/content/samantha_patthana.json, and checks the bundled recording is the original.

  python -I -X utf8 tools/build_samantha_patthana.py <project_root>
  python -I -X utf8 tools/build_samantha_patthana.py <project_root> --check
  python -I -X utf8 tools/build_samantha_patthana.py <project_root> --import-audio <audio_dir>
  python -I -X utf8 tools/build_samantha_patthana.py <project_root> --extract <source_folder>
"""
from __future__ import annotations

import hashlib
import json
import pathlib
import shutil
import sys

OUTPUT = pathlib.Path("content/extracted/samantha_patthana.json")
TIMES = pathlib.Path("content/extracted/samantha_patthana_times.json")
ASSET = pathlib.Path("assets/content/samantha_patthana.json")
AUDIO_DIR = pathlib.Path("assets/audio/samantha_patthana")
STRUCTURE = pathlib.Path("converted/structure.json")
PAGES = pathlib.Path("converted/pages")
INTRODUCTION = pathlib.Path("introduction_owner_supplied.md")

# Sinhala title of the Vandana; structure.json's title_page splits it over several lines, so it is a constant.
TITLE = "සමන්ත පට්ඨාන ධර්ම වන්දනාව"

PARTS = 24

# Corrections to line text applied at build: rows (from, to, expected count, reason). A row whose
# count does not match the text raises BuildError.
CORRECTIONS: list[tuple[str, str, int, str]] = []

# Units whose lines get no line time (the recording does not follow the printed lines there).
UNTIMED_UNITS = ("u-homage",)

RECORDING = "hYXyO3o7Iac.m4a"
RECORDING_BYTES = 46219957
RECORDING_SHA256 = "fe3bdcda759cbd18e4e2e0bfc739d25301622b217f84995ac9c5e5bdc61b2c20"
DURATION_MS = 2856000

ROMAN_TITLE = "Samantha Pattana Dharma Wandanawa"
RECORDING_LABEL = "Chanted by Ven. Kiriwaththuduwe Ariyadassana Thero"
CHECK = "needs checking"


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




def _json(path: pathlib.Path) -> dict:
    try:
        return json.loads(_read(path))
    except ValueError as e:
        raise BuildError(f"{path.as_posix()}: unreadable ({e})")


def _corrected(units: list[dict], corrections) -> list[dict]:
    """Copies of the units with the correction rows applied to every line of text."""
    units = json.loads(json.dumps(units))
    for old, new, count, reason in corrections:
        lines = [e for u in units for k in ("pali", "sinhala") for e in u[k]]
        got = sum(e["text"].count(old) for e in lines)
        if got != count:
            raise BuildError(f"correction {reason!r}: {old!r} occurs {got} times, expected {count}")
        for e in lines:
            e["text"] = e["text"].replace(old, new)
    return units


def _seconds(ms: int) -> float | int:
    value = round(ms / 1000, 3)
    return int(value) if value == int(value) else value


def _audio(timed: list[dict], untimed) -> dict:
    block_times, line_times = [], []
    for i, unit in enumerate(timed):
        start = unit["lines"][0]["start_ms"]
        end = timed[i + 1]["lines"][0]["start_ms"] if i + 1 < len(timed) else unit["lines"][-1]["end_ms"]
        block_times.append([_seconds(start), _seconds(end)])
        line_times.append([None if unit["id"] in untimed else _seconds(l["start_ms"]) for l in unit["lines"]])
    return {"asset": f"{AUDIO_DIR.as_posix()}/{RECORDING}", "label": RECORDING_LABEL,
            "duration_ms": DURATION_MS, "bytes": RECORDING_BYTES, "sha256": RECORDING_SHA256,
            "block_times": block_times, "line_times": line_times}


def build(root, corrections=None, untimed=None) -> dict:
    root = pathlib.Path(root)
    corrections = CORRECTIONS if corrections is None else corrections
    untimed = UNTIMED_UNITS if untimed is None else untimed
    extracted, times = _json(root / OUTPUT), _json(root / TIMES)
    try:
        units = _corrected(extracted["units"], corrections)
        timed = times["units"]
        title = extracted["title"]
        paragraphs = extracted["introduction"]
        duration = times["duration_ms"]
    except (KeyError, TypeError) as e:
        raise BuildError(f"extracted or times file is missing {e}")
    if duration != DURATION_MS:
        raise BuildError(f"times file duration is {duration} ms, expected {DURATION_MS}")
    if [u["id"] for u in units] != [t.get("id") for t in timed]:
        raise BuildError("times file units differ from the text's units")
    for u, t in zip(units, timed):
        if len(u["pali"]) != len(t.get("lines", [])) or not u["pali"]:
            raise BuildError(f"{u['id']}: {len(u['pali'])} text lines but {len(t.get('lines', []))} times")
    if len(paragraphs) != 3:
        raise BuildError(f"introduction has {len(paragraphs)} paragraphs, expected 3")
    verses = []
    for u in units:
        verse = {"id": u["id"], "keep_lines": True,
                 "phrases": [{"pali": e["text"], "sinhala": "", "english": ""} for e in u["pali"]]}
        if u["sinhala"]:
            verse["sinhala"] = "\n".join(e["text"] for e in u["sinhala"])
        verse["check"] = CHECK
        verses.append(verse)
    source = {"name": "tipitaka.lk", "locator": f"{title}.pdf (the page on tipitaka.lk is not yet known)",
              "collected": "2026-11-11", "translator": ""}
    applied = [{"field": "text", "from": a, "to": b, "reason": r, "count": n} for a, b, n, r in corrections]
    intro = {
        "id": "sp-introduction", "title": "Introduction",
        "sections": [{
            "id": "p", "number": 1, "heading": "Introduction", "check": CHECK,
            "source": {"name": "Supplied by the owner", "locator": INTRODUCTION.as_posix(),
                       "collected": "2026-11-11", "translator": ""},
            "corrections": [],
            "verses": [{"id": f"intro-{n}", "sinhala": text, "always_shown": True, "check": CHECK}
                       for n, text in enumerate(paragraphs, 1)],
        }],
    }
    vandana = {
        "id": "sp-vandana", "title": title, "title_roman": ROMAN_TITLE,
        "audio": _audio(timed, untimed),
        "sections": [{"id": "p", "number": 1, "heading": title, "check": CHECK, "source": source,
                      "corrections": applied, "verses": verses}],
    }
    return {"schema": 1, "categories": [{
        "id": "cat-samantha-patthana", "title": "Samantha Pattana Dharma Wandanawa",
        "short_title": "Samantha Pattana", "subtitle": title, "readings": [intro, vandana]}]}


def _sha_and_size(path: pathlib.Path) -> tuple[str, int]:
    try:
        data = path.read_bytes()
    except OSError as e:
        raise BuildError(f"cannot read recording {path.as_posix()}: {e}")
    return hashlib.sha256(data).hexdigest(), len(data)


def import_audio(root, audio_dir) -> None:
    """Copies the recording byte for byte, refusing a file of the wrong size or checksum."""
    src = pathlib.Path(audio_dir) / RECORDING
    sha, size = _sha_and_size(src)
    if size != RECORDING_BYTES:
        raise BuildError(f"{src.name} is {size} bytes, expected {RECORDING_BYTES}; not copied")
    if sha != RECORDING_SHA256:
        raise BuildError(f"{src.name} has checksum {sha}, expected {RECORDING_SHA256}; not copied")
    (pathlib.Path(root) / AUDIO_DIR).mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, pathlib.Path(root) / AUDIO_DIR / RECORDING)


def _check(root, rendered: str) -> str | None:
    """Returns a description of the first difference, or None."""
    root = pathlib.Path(root)
    path = root / AUDIO_DIR / RECORDING
    if _sha_and_size(path) != (RECORDING_SHA256, RECORDING_BYTES):
        return f"{path.name} differs from the original"
    stored = root / ASSET
    if not stored.exists() or stored.read_bytes() != rendered.encode("utf-8"):
        return f"{ASSET.as_posix()} is out of date"
    extra = sorted(p.name for p in (root / AUDIO_DIR).glob("*") if p.name != RECORDING)
    if extra:
        return f"unexpected file in {AUDIO_DIR.as_posix()}: {extra[0]}"
    return None


USAGE = ("usage: python -I -X utf8 tools/build_samantha_patthana.py <project_root> "
         "[--check | --import-audio <audio_dir> | --extract <source_folder>]")


def main() -> None:
    args = sys.argv[1:]
    mode = args[1] if len(args) > 1 else ""
    wants = {"": 1, "--check": 2, "--extract": 3, "--import-audio": 3}
    if mode not in wants or len(args) != wants[mode]:
        sys.exit(USAGE)
    root = pathlib.Path(args[0])
    try:
        if mode == "--extract":
            text = render(extract(args[2]))
            (root / OUTPUT).parent.mkdir(parents=True, exist_ok=True)
            (root / OUTPUT).write_bytes(text.encode("utf-8"))
            print(f"wrote {OUTPUT.as_posix()}")
            return
        if mode == "--import-audio":
            import_audio(root, args[2])
        rendered = render(build(root))
        if mode == "--check":
            problem = _check(root, rendered)
            if problem:
                sys.exit(f"samantha patthana content is out of date: {problem}; "
                         f"run python -I -X utf8 tools/build_samantha_patthana.py {args[0]}")
            print("samantha patthana content is up to date")
            return
        (root / ASSET).parent.mkdir(parents=True, exist_ok=True)
        (root / ASSET).write_bytes(rendered.encode("utf-8"))
        print(f"wrote {ASSET.as_posix()}")
    except BuildError as e:
        sys.exit(f"build_samantha_patthana: {e}")


if __name__ == "__main__":
    main()
