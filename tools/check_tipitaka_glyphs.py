"""Which characters of the shipped Tripitaka text no bundled font can draw.

Run: python -I -X utf8 tools/check_tipitaka_glyphs.py .

Reads (never writes) assets/tipitaka/tree.json.gz names and every entry and
footnote text of assets/tipitaka/text/*.json.gz. Prints one line per code point
that none of NotoSansSinhala, NotoSerif and Lora has:
  U+XXXX <unicode name> count=<n> first=<file>
or `OK`. Exit 0 when none, 1 otherwise. Standard library only.
"""
import gzip
import importlib.util
import json
import pathlib
import sys
import unicodedata

FONTS = ("NotoSansSinhala.ttf", "NotoSerif.ttf", "Lora.ttf")
ALLOWED = {0x0A, 0x0D, 0x09, 0x200B, 0x200C, 0x200D, 0xFEFF, 0x00AD}
SKIPPED_KEY_PREFIXES = ("atta", "anya")


def _load_font_reader():
    path = pathlib.Path(__file__).resolve().with_name("check_ui_glyphs.py")
    spec = importlib.util.spec_from_file_location("check_ui_glyphs", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.font_codepoints


def _read(path):
    return json.loads(gzip.decompress(path.read_bytes()).decode("utf-8"))


def _footnote_text(note):
    if isinstance(note, dict):
        return note.get("text", "")
    return note if isinstance(note, str) else ""


def texts(root):
    """(file label, text) for every drawn string, tree first, then books by name."""
    base = root / "assets" / "tipitaka"
    tree = _read(base / "tree.json.gz")
    for key, node in tree.items():
        if key.startswith(SKIPPED_KEY_PREFIXES):
            continue
        for name in node[:2]:
            yield "tree.json.gz", name
    for path in sorted((base / "text").glob("*.json.gz")):
        label = f"text/{path.name}"
        for pg in _read(path)["pages"]:
            for side in ("pali", "sinh"):
                part = pg.get(side) or {}
                for entry in part.get("entries", []):
                    yield label, entry.get("text", "") if isinstance(entry, dict) else str(entry)
                for note in part.get("footnotes", []):
                    yield label, _footnote_text(note)


def report(root):
    font_codepoints = _load_font_reader()
    points = set()
    for name in FONTS:
        points |= font_codepoints(root / "assets" / "fonts" / name)
    found = {}
    for label, text in texts(root):
        for ch in text:
            cp = ord(ch)
            if cp in points or cp in ALLOWED:
                continue
            if cp in found:
                found[cp][0] += 1
            else:
                found[cp] = [1, label]
    return found


def main(argv):
    root = pathlib.Path(argv[1] if len(argv) > 1 else ".").resolve()
    found = report(root)
    if not found:
        print("OK")
        return 0
    for cp in sorted(found):
        count, first = found[cp]
        name = unicodedata.name(chr(cp), "<unnamed>")
        print(f"U+{cp:04X} {name} count={count} first={first}")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
