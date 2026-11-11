"""Which characters of the app's English interface strings the label font lacks.

Run: python -I -X utf8 tools/check_ui_glyphs.py .

Labels are set in NotoSansSinhala, which falls back to Lora for a character it
does not have. The fallback is bundled, so nothing is fetched, but the
character is then drawn in a different face. This lists those characters.

Also checks every pirith `title` against NotoSansSinhala and `title_roman`
against NotoSerif, and the same for the Samantha Pattana asset (its category and
reading `title`, `subtitle` and `short_title` against NotoSansSinhala).

Exit code: 0 whatever is listed; 1 only when a listed character is in neither
bundled font (it would be drawn as a box, or fetched from the network), or a
pirith name has a glyph missing (named by reading and character).
Standard library only.
"""
import pathlib
import re
import struct
import sys

LABEL_FONT = "NotoSansSinhala.ttf"
FALLBACK_FONT = "Lora.ttf"
ROMAN_FONT = "NotoSerif.ttf"
PIRITH = "assets/content/pirith.json"
SAMANTHA = "assets/content/samantha_patthana.json"

# Files whose strings are data for code and never drawn as interface text.
NOT_DRAWN = {
    # The table that folds Pali diacritics to plain letters for searching.
    "lib/library/search.dart",
}


def font_codepoints(path):
    """The set of code points in a TrueType font's cmap (formats 4 and 12)."""
    data = pathlib.Path(path).read_bytes()
    num_tables = struct.unpack(">H", data[4:6])[0]
    cmap = None
    for i in range(num_tables):
        tag, _, offset, _ = struct.unpack(">4sIII", data[12 + 16 * i:28 + 16 * i])
        if tag == b"cmap":
            cmap = offset
    if cmap is None:
        raise ValueError(f"{path}: no cmap table")
    n = struct.unpack(">H", data[cmap + 2:cmap + 4])[0]
    points = set()
    for i in range(n):
        platform, encoding, sub = struct.unpack(">HHI", data[cmap + 4 + 8 * i:cmap + 12 + 8 * i])
        if platform not in (0, 3):
            continue
        t = cmap + sub
        fmt = struct.unpack(">H", data[t:t + 2])[0]
        if fmt == 4:
            segx2 = struct.unpack(">H", data[t + 6:t + 8])[0]
            seg = segx2 // 2
            ends = struct.unpack(f">{seg}H", data[t + 14:t + 14 + segx2])
            starts = struct.unpack(f">{seg}H", data[t + 16 + segx2:t + 16 + 2 * segx2])
            deltas = struct.unpack(f">{seg}h", data[t + 16 + 2 * segx2:t + 16 + 3 * segx2])
            ranges_at = t + 16 + 3 * segx2
            ranges = struct.unpack(f">{seg}H", data[ranges_at:ranges_at + segx2])
            for k in range(seg):
                s, e, d, r = starts[k], ends[k], deltas[k], ranges[k]
                for c in range(s, e + 1):
                    if c == 0xFFFF:
                        continue
                    if r == 0:
                        glyph = (c + d) & 0xFFFF
                    else:
                        at = ranges_at + 2 * k + r + 2 * (c - s)
                        glyph = struct.unpack(">H", data[at:at + 2])[0]
                        if glyph:
                            glyph = (glyph + d) & 0xFFFF
                    if glyph:
                        points.add(c)
        elif fmt == 12:
            groups = struct.unpack(">I", data[t + 12:t + 16])[0]
            for g in range(groups):
                s, e, glyph = struct.unpack(">III", data[t + 16 + 12 * g:t + 28 + 12 * g])
                if glyph:
                    points.update(range(s, e + 1))
    return points


_ESCAPES = {"n": "\n", "t": "\t", "r": "\r", "b": "\b", "f": "\f", "v": "\v"}


def _unescape(body):
    out, i = [], 0
    while i < len(body):
        c = body[i]
        if c != "\\" or i + 1 >= len(body):
            out.append(c)
            i += 1
            continue
        n = body[i + 1]
        if n == "u":
            m = re.match(r"\{([0-9a-fA-F]+)\}|([0-9a-fA-F]{4})", body[i + 2:])
            if m:
                out.append(chr(int(m.group(1) or m.group(2), 16)))
                i += 2 + m.end()
                continue
        if n == "x":
            m = re.match(r"[0-9a-fA-F]{2}", body[i + 2:])
            if m:
                out.append(chr(int(m.group(0), 16)))
                i += 4
                continue
        out.append(_ESCAPES.get(n, n))
        i += 2
    return "".join(out)


def extract_strings(source):
    """Dart string literals in [source] as (line, text) pairs.

    Single, double and triple quoted, raw or not. Skipped: comments, the
    strings of import/export/part directives, and the argument of a key
    (`ValueKey('x')`, `Key('x')`), which is never drawn. Text inside `$name`
    and `${...}` interpolations is code, not string; only the literal pieces
    are returned, joined.
    """
    found = []
    i, n, line = 0, len(source), 1
    while i < n:
        c = source[i]
        if c == "\n":
            line += 1
            i += 1
        elif source.startswith("//", i):
            while i < n and source[i] != "\n":
                i += 1
        elif source.startswith("/*", i):
            end = source.find("*/", i + 2)
            end = n if end < 0 else end + 2
            line += source.count("\n", i, end)
            i = end
        elif c in "'\"" or (
            c == "r"
            and i + 1 < n
            and source[i + 1] in "'\""
            and not (i and (source[i - 1].isalnum() or source[i - 1] == "_"))
        ):
            raw = c == "r"
            start = i
            if raw:
                i += 1
            q = source[i]
            triple = source.startswith(q * 3, i)
            i += 3 if triple else 1
            pieces, buf = [], []
            start_line = line
            while i < n:
                ch = source[i]
                if not raw and ch == "\\" and i + 1 < n:
                    buf.append(source[i:i + 2])
                    line += source[i + 1] == "\n"
                    i += 2
                    continue
                if not raw and ch == "$" and i + 1 < n and source[i + 1] == "{":
                    pieces.append("".join(buf))
                    buf = []
                    depth, i = 1, i + 2
                    while i < n and depth:
                        depth += {"{": 1, "}": -1}.get(source[i], 0)
                        line += source[i] == "\n"
                        i += 1
                    continue
                if not raw and ch == "$" and i + 1 < n and (source[i + 1].isalpha() or source[i + 1] == "_"):
                    pieces.append("".join(buf))
                    buf = []
                    i += 1
                    while i < n and (source[i].isalnum() or source[i] == "_"):
                        i += 1
                    continue
                if (source.startswith(q * 3, i) if triple else ch == q):
                    i += 3 if triple else 1
                    break
                if not triple and ch == "\n":
                    break  # unterminated; give up on this literal
                line += ch == "\n"
                buf.append(ch)
                i += 1
            pieces.append("".join(buf))
            head = source[:start]
            on_line = head[head.rfind("\n") + 1:].strip()
            is_directive = re.match(r"(import|export|part)\b", on_line) is not None
            is_key = re.search(r"Key\(\s*$", head) is not None
            if not is_directive and not is_key:
                text = "".join(p if raw else _unescape(p) for p in pieces)
                found.append((start_line, text))
        else:
            i += 1
    return found


def missing_characters(text, points):
    """The characters of [text] that are not in [points], in order, once each."""
    seen = []
    for ch in text:
        if ord(ch) >= 0x20 and ord(ch) not in points and ch not in seen:
            seen.append(ch)
    return seen


def pirith_missing(root, sinhala_points, roman_points):
    """(reading id, field, character) for each pirith name with a missing glyph.

    `title` is drawn in NotoSansSinhala and `title_roman` in NotoSerif.
    """
    import json

    path = root / PIRITH
    if not path.exists():
        raise FileNotFoundError(f"{PIRITH} is missing; the pirith names cannot be checked")
    data = json.loads(path.read_text(encoding="utf-8"))
    bad = []
    for category in data["categories"]:
        for reading in category["readings"]:
            for field, points in (("title", sinhala_points), ("title_roman", roman_points)):
                for ch in missing_characters(reading.get(field, ""), points):
                    bad.append((reading["id"], field, ch))
    return bad


def samantha_missing(root, sinhala_points, roman_points):
    """(id, field, character) for each Samantha Pattana name with a missing glyph.

    `title`, `subtitle` and `short_title` are drawn in NotoSansSinhala and
    `title_roman` in NotoSerif; categories and readings are both checked.
    """
    import json

    path = root / SAMANTHA
    if not path.exists():
        raise FileNotFoundError(f"{SAMANTHA} is missing; the Samantha Pattana names cannot be checked")
    data = json.loads(path.read_text(encoding="utf-8"))
    fields = (("title", sinhala_points), ("subtitle", sinhala_points),
              ("short_title", sinhala_points), ("title_roman", roman_points))
    bad = []
    for category in data["categories"]:
        for item in [category, *category["readings"]]:
            for field, points in fields:
                for ch in missing_characters(item.get(field, ""), points):
                    bad.append((item["id"], field, ch))
    return bad


def main(argv):
    root = pathlib.Path(argv[1] if len(argv) > 1 else ".").resolve()
    fonts = root / "assets" / "fonts"
    label = font_codepoints(fonts / LABEL_FONT)
    fallback = font_codepoints(fonts / FALLBACK_FONT)
    in_fallback_only = {}
    nowhere = {}
    for path in sorted((root / "lib").rglob("*.dart")):
        rel = path.relative_to(root).as_posix()
        if rel in NOT_DRAWN:
            continue
        for line, text in extract_strings(path.read_text(encoding="utf-8")):
            for ch in missing_characters(text, label):
                target = in_fallback_only if ord(ch) in fallback else nowhere
                target.setdefault(ch, []).append((rel, line, text))
    try:
        roman = font_codepoints(fonts / ROMAN_FONT)
        pirith_bad = pirith_missing(root, label, roman)
        samantha_bad = samantha_missing(root, label, roman)
    except FileNotFoundError as error:
        print(f"error: {error}")
        return 1
    if pirith_bad:
        print("pirith names with a character missing from the font they are drawn in:")
        for reading_id, field, ch in pirith_bad:
            print(f"  {reading_id} {field}: U+{ord(ch):04X} {ch!r}")
    if samantha_bad:
        print("Samantha Pattana names with a character missing from the font they are drawn in:")
        for item_id, field, ch in samantha_bad:
            print(f"  {item_id} {field}: U+{ord(ch):04X} {ch!r}")
        pirith_bad = pirith_bad + samantha_bad
    if not in_fallback_only and not nowhere:
        if pirith_bad:
            return 1
        print("all interface characters are in NotoSansSinhala")
        return 0
    if in_fallback_only:
        print("drawn in Lora (the fallback), not in NotoSansSinhala:")
        for ch, where in sorted(in_fallback_only.items()):
            rel, line, text = where[0]
            more = f"  (+{len(where) - 1} more)" if len(where) > 1 else ""
            print(f"  U+{ord(ch):04X} {ch!r}  {rel}:{line}  {text!r}{more}")
    if nowhere:
        print("in NEITHER bundled font:")
        for ch, where in sorted(nowhere.items()):
            rel, line, text = where[0]
            print(f"  U+{ord(ch):04X} {ch!r}  {rel}:{line}  {text!r}")
        return 1
    return 1 if pirith_bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
