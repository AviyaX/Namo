"""Which characters of the shipped Tripitaka text no bundled font can draw.

Run: python -I -X utf8 tools/check_tipitaka_glyphs.py .

Reads (never writes) assets/tipitaka/tree.json.gz names and every entry and
footnote text of assets/tipitaka/text/*.json.gz, and the Rerukane books:
assets/books/index.json (titles, subtitles) and every assets/books/*.json.gz
(page titles, block text, lines, items, table cells, image alt). Prints one line per code point
that none of NotoSansSinhala, NotoSerif and Lora has:
  U+XXXX <unicode name> count=<n> first=<file>
or `OK`. Code points in DISPLAY_SUBSTITUTED are not missing when their
substitute is drawable; they print on a line
  substituted U+XXXX -> U+YYYY count=<n>
Exit 0 when nothing is missing, 1 otherwise. Standard library only.
"""
import gzip
import importlib.util
import json
import pathlib
import sys
import unicodedata

FONTS = ("NotoSansSinhala.ttf", "NotoSerif.ttf", "Lora.ttf")
ALLOWED = {0x0A, 0x0D, 0x09, 0x200B, 0x200C, 0x200D, 0xFEFF, 0x00AD}
# Drawn as the substitute at run time (lib/tipitaka/pali_display.dart,
# _displaySubstitutions). Keep the two tables in step.
DISPLAY_SUBSTITUTED = {0x05F4: 0x0022}
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


def _block_strings(block):
    for key in ("text", "alt"):
        if isinstance(block.get(key), str):
            yield block[key]
    for key in ("lines", "items"):
        for item in block.get(key) or []:
            yield str(item)
    for row in block.get("rows") or []:
        for cell in row:
            yield str(cell)


def book_texts(root):
    """(file label, text) for the Rerukane books' titles and every drawn string; none if absent."""
    base = root / "assets" / "books"
    index_path = base / "index.json"
    if not index_path.is_file():
        return
    index = json.loads(index_path.read_text(encoding="utf-8"))
    for entry in index.get("books", []):
        for key in ("title", "subtitle"):
            if entry.get(key):
                yield "books/index.json", entry[key]
    for path in sorted(base.glob("*.json.gz")):
        label = f"books/{path.name}"
        book = _read(path)
        for key in ("title", "subtitle"):
            if book.get(key):
                yield label, book[key]
        for pg in book.get("pages", []):
            yield label, pg.get("title", "")
            for block in pg.get("blocks", []):
                for text in _block_strings(block):
                    yield label, text


def texts(root):
    """(file label, text) for every drawn string, tree first, then books by name, then the Rerukane books."""
    yield from _tipitaka_texts(root)
    yield from book_texts(root)


def _tipitaka_texts(root):
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
    substituted = {}
    for label, text in texts(root):
        for ch in text:
            cp = ord(ch)
            if cp in points or cp in ALLOWED:
                continue
            if DISPLAY_SUBSTITUTED.get(cp) in points:
                substituted[cp] = substituted.get(cp, 0) + 1
                continue
            if cp in found:
                found[cp][0] += 1
            else:
                found[cp] = [1, label]
    return found, substituted


def main(argv):
    root = pathlib.Path(argv[1] if len(argv) > 1 else ".").resolve()
    found, substituted = report(root)
    for cp in sorted(found):
        count, first = found[cp]
        name = unicodedata.name(chr(cp), "<unnamed>")
        print(f"U+{cp:04X} {name} count={count} first={first}")
    for cp in sorted(substituted):
        print(f"substituted U+{cp:04X} -> U+{DISPLAY_SUBSTITUTED[cp]:04X} "
              f"count={substituted[cp]}")
    if not found and not substituted:
        print("OK")
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
