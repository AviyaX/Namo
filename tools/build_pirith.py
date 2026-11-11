"""Builds the bundled Pirith content from the already-extracted pitaka.lk data.

Reads content/extracted/pitaka_lk_pirith.json (as data only), writes
assets/content/pirith.json and content/pirith_names.md, and checks that every
recording under assets/audio/pirith/ is the downloaded original.

  python -I -X utf8 tools/build_pirith.py <project_root>
  python -I -X utf8 tools/build_pirith.py <project_root> --check
  python -I -X utf8 tools/build_pirith.py <project_root> --import-audio <audio_dir>
"""
from __future__ import annotations

import hashlib
import json
import pathlib
import shutil
import sys

SOURCE = pathlib.Path("content/extracted/pitaka_lk_pirith.json")
OUTPUT = pathlib.Path("assets/content/pirith.json")
NAMES = pathlib.Path("content/pirith_names.md")
AUDIO_DIR = pathlib.Path("assets/audio/pirith")


class BuildError(Exception):
    pass


# Readings listed first, in this order (owner decision 2026-11-10); the rest follow in the source's order.
FIRST = ("08-mahamangala", "09-rathana", "10-karaniya")
NAMES_EN = pathlib.Path("content/pirith_names_en.json")


def _roman_names(root: pathlib.Path, ids: list[str]) -> dict[str, str]:
    """Roman names keyed by site id, from the fixed table keyed by the id's number prefix."""
    try:
        table = json.loads((root / NAMES_EN).read_text(encoding="utf-8"))
    except (OSError, ValueError) as e:
        raise BuildError(f"cannot read {NAMES_EN.as_posix()}: {e}")
    prefixes = {i.split("-", 1)[0]: i for i in ids}
    for key in table:
        if key not in prefixes:
            raise BuildError(f"{NAMES_EN.as_posix()}: entry {key!r} matches no reading")
    for key, site_id in prefixes.items():
        if key not in table:
            raise BuildError(f"{NAMES_EN.as_posix()}: no name for {site_id}")
    for key, name in table.items():
        if not isinstance(name, str) or not name.strip() or not name.isascii():
            raise BuildError(f"{NAMES_EN.as_posix()}: entry {key!r} must be a non-empty ASCII name")
    return {prefixes[k]: v for k, v in table.items()}


def _load(root: pathlib.Path) -> dict:
    try:
        return json.loads((root / SOURCE).read_text(encoding="utf-8"))
    except (OSError, ValueError) as e:
        raise BuildError(f"cannot read {SOURCE}: {e}")


def _duration_ms(text: str) -> int:
    try:
        parts = [int(p) for p in text.split(":")]
    except ValueError:
        raise BuildError(f"bad duration {text!r}")
    seconds = 0
    for p in parts:
        seconds = seconds * 60 + p
    return seconds * 1000


def _sha_and_size(path: pathlib.Path) -> tuple[str, int]:
    try:
        data = path.read_bytes()
    except OSError as e:
        raise BuildError(f"cannot read recording {path.as_posix()}: {e}")
    return hashlib.sha256(data).hexdigest(), len(data)


def _times(blocks: list[dict]) -> list:
    return [None if b["start"] is None or b["end"] is None else [b["start"], b["end"]] for b in blocks]


def _reading(root: pathlib.Path, src: dict, item: dict, collected: str, roman: str) -> dict:
    sha, size = _sha_and_size(root / AUDIO_DIR / f"{item['id']}.m4a")
    if size != item["audio_bytes"]:
        raise BuildError(f"{item['id']}.m4a is {size} bytes, expected {item['audio_bytes']}")
    chanter = src["chanters"][item["chanter"]]["name_en"]
    return {
        "id": f"pirith-{item['id']}",
        "title": item["title_si"],
        "title_roman": roman,
        "audio": {"asset": f"assets/audio/pirith/{item['id']}.m4a",
                  "label": f"Chanted by Ven. {chanter}",
                  "duration_ms": _duration_ms(item["duration"]),
                  "bytes": size, "sha256": sha, "block_times": _times(item["blocks"])},
        "sections": [{
            "id": "p", "number": 1, "heading": item["title_si"], "check": "checked against source",
            "source": {"name": "pitaka.lk/pirith",
                       "locator": f"https://pitaka.lk/pirith/ ({item['id']})",
                       "collected": collected, "translator": ""},
            "corrections": [],
            "verses": [{"id": f"b{n}",
                        "phrases": [{"pali": p["pali"], "sinhala": p["sinhala"], "english": p["english"]}
                                    for p in b["pairs"]],
                        "check": "checked against source", "notes": [], "corrections": []}
                       for n, b in enumerate(item["blocks"], 1)],
        }],
    }


def build(root: pathlib.Path, first: tuple[str, ...] = FIRST) -> dict:
    src = _load(root)
    collected = src["fetched_utc"][:10]
    items = [it for it in src["items"] if it["blocks"]]
    by_id = {it["id"]: it for it in items}
    for f in first:
        if f not in by_id:
            raise BuildError(f"{f} is not among the readings")
    items = [by_id[f] for f in first] + [it for it in items if it["id"] not in first]
    roman = _roman_names(root, [it["id"] for it in items])
    readings = [_reading(root, src, it, collected, roman[it["id"]]) for it in items]
    return {"schema": 1, "categories": [{"id": "cat-pirith", "title": "Pirith", "subtitle": "පිරිත්",
                                         "readings": readings}]}


def render(data: dict) -> bytes:
    return (json.dumps(data, ensure_ascii=False, indent=1) + "\n").encode("utf-8")


def render_names(root: pathlib.Path, data: dict) -> bytes:
    src = _load(root)
    lines = ["# Pirith in Namo", "",
             "Generated by tools/build_pirith.py; do not edit. The position is the pirith's number in",
             "the list; Roman names come from content/pirith_names_en.json.", "",
             f"Source: {src.get('source', '')}", "",
             f"Licence on the source site: {' '.join(src.get('reuse_terms_on_site', '').split())}", "",
             "| No. | Site id | Sinhala name | Roman name |", "|---|---|---|---|"]
    for number, r in enumerate(data["categories"][0]["readings"], 1):
        site_id = r["id"][len("pirith-"):]
        lines.append(f"| {number} | {site_id} | {r['title']} | {r['title_roman']} |")
    return (chr(10).join(lines) + chr(10)).encode("utf-8")


def import_audio(root: pathlib.Path, audio_dir: pathlib.Path) -> None:
    """Copies the needed recordings byte for byte, refusing any whose size differs."""
    needed = [it for it in _load(root)["items"] if it["blocks"]]
    for it in needed:
        src = audio_dir / f"{it['id']}.m4a"
        try:
            size = src.stat().st_size
        except OSError as e:
            raise BuildError(f"cannot read {src}: {e}")
        if size != it["audio_bytes"]:
            raise BuildError(f"{src.name} is {size} bytes, expected {it['audio_bytes']}; not copied")
    (root / AUDIO_DIR).mkdir(parents=True, exist_ok=True)
    for it in needed:
        shutil.copyfile(audio_dir / f"{it['id']}.m4a", root / AUDIO_DIR / f"{it['id']}.m4a")


def _check(root: pathlib.Path, data: dict, rendered: bytes, names: bytes) -> str | None:
    """Returns a description of the first difference, or None."""
    readings = data["categories"][0]["readings"]
    try:
        stored = json.loads((root / OUTPUT).read_text(encoding="utf-8"))["categories"][0]["readings"]
    except (OSError, ValueError, KeyError, IndexError):
        stored = []
    for r in stored + readings:
        a = r["audio"]
        path = root / a["asset"]
        sha, size = _sha_and_size(path)
        if (sha, size) != (a["sha256"], a["bytes"]):
            return f"{path.name} differs from the original"
    for rel, want in ((OUTPUT, rendered), (NAMES, names)):
        path = root / rel
        if not path.exists() or path.read_bytes() != want:
            return f"{rel.as_posix()} is out of date"
    wanted = {pathlib.Path(r["audio"]["asset"]).name for r in readings}
    extra = sorted(p.name for p in (root / AUDIO_DIR).glob("*") if p.name not in wanted)
    if extra:
        return f"unexpected file in {AUDIO_DIR.as_posix()}: {extra[0]}"
    return None


def main() -> None:
    args = sys.argv[1:]
    check = "--check" in args
    args = [a for a in args if a != "--check"]
    audio_dir = None
    if "--import-audio" in args:
        k = args.index("--import-audio")
        if k + 1 >= len(args):
            sys.exit("--import-audio needs a folder")
        audio_dir = pathlib.Path(args[k + 1])
        del args[k:k + 2]
    if len(args) != 1 or (check and audio_dir):
        sys.exit("usage: python -I -X utf8 tools/build_pirith.py <project_root> [--check | --import-audio <audio_dir>]")
    root = pathlib.Path(args[0])
    try:
        if audio_dir:
            import_audio(root, audio_dir)
        data = build(root)
        rendered, names = render(data), render_names(root, data)
        if check:
            problem = _check(root, data, rendered, names)
            if problem:
                sys.exit(f"pirith content is out of date: {problem}; "
                         f"run python -I -X utf8 tools/build_pirith.py {args[0]}")
            print("pirith content is up to date")
            return
        for rel, content in ((OUTPUT, rendered), (NAMES, names)):
            (root / rel).parent.mkdir(parents=True, exist_ok=True)
            (root / rel).write_bytes(content)
            print(f"wrote {rel.as_posix()}")
    except BuildError as e:
        sys.exit(f"build_pirith: {e}")


if __name__ == "__main__":
    main()
