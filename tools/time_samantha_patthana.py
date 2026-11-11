"""Gives every Pali line of the Samantha Pattana Dharma Wandanawa a start and end time in the recording.

Reads content/extracted/samantha_patthana.json and the recording's automatic captions (timing data
only; no caption word is written anywhere) and writes content/extracted/samantha_patthana_times.json
and content/samantha_patthana_timing_report.md.

  python -I -X utf8 tools/time_samantha_patthana.py <project_root> <captions.json3>

Method: the book's lines and the captions are each reduced to Sinhala letters (hal kirima and anusvara
stripped), and spellings the speech recogniser mixes up are folded together (long/short vowels,
aspirated/plain consonants, retroflex/dental n and l, sibilants, prenasalised stops). The two letter
streams are aligned in order by a global dynamic programme with affine gaps, inside a band around the
straight diagonal. A line is `matched` only when the alignment gives it real evidence (see _evidence);
every other line is `estimated` by letter count between its nearest matched neighbours.
"""
from __future__ import annotations

import json
import pathlib
import sys

EXTRACTED = pathlib.Path("content/extracted/samantha_patthana.json")
OUTPUT = pathlib.Path("content/extracted/samantha_patthana_times.json")
REPORT = pathlib.Path("content/samantha_patthana_timing_report.md")

DURATION_MS = 2856000

# The baseline (rough in-order difflib letter match) the report compares with.
BASELINE_LETTERS_PERCENT = 79
BASELINE_MATCHED_LINES = 437

SINHALA_FIRST, SINHALA_LAST = chr(0x0D80), chr(0x0DFF)
HAL_KIRIMA, ANUSVARA = chr(0x0DCA), chr(0x0D82)

# Spellings the recogniser confuses, folded one letter to one letter (so letter counts are unchanged).
_FOLD_PAIRS = {
    "ආ": "අ", "ඊ": "ඉ", "ඌ": "උ", "ඒ": "එ", "ඕ": "ඔ", "ඈ": "ඇ",
    "ී": "ි", "ූ": "ු", "ේ": "ෙ", "ෝ": "ො", "ෑ": "ැ", "ෲ": "ෘ",
    "ඛ": "ක", "ඝ": "ග", "ඡ": "ච", "ඣ": "ජ", "ඨ": "ට", "ඪ": "ඩ", "ථ": "ත", "ධ": "ද", "ඵ": "ප", "භ": "බ",
    "ණ": "න", "ඤ": "න", "ඥ": "න", "ළ": "ල", "ශ": "ස", "ෂ": "ස",
    "ඟ": "ග", "ඬ": "ඩ", "ඳ": "ද", "ඹ": "බ",
}
_FOLD = str.maketrans(_FOLD_PAIRS)

MATCH, MISMATCH, OPEN, EXTEND = 2, -1, -4, -1
BAND = 400  # caption letters either side of the diagonal the alignment may use
EDGE = 20  # an aligned letter this close to the band's edge means the band was too narrow

# Evidence a line needs to count as matched (letters after folding):
JUMP = 8  # matched letters further apart in the captions than in the book by more than this split a line
MIN_SHARE = 0.6  # at least this share of the line's letters matched in its main run
MIN_LETTERS = 3  # and at least this many
START_SLACK = 3  # and the run starts within this many letters of the line's first letter


class TimingError(Exception):
    pass


def letters(text: str) -> str:
    """Sinhala letters only, hal kirima and anusvara stripped (the baseline's letter count)."""
    return "".join(c for c in text if SINHALA_FIRST <= c <= SINHALA_LAST and c not in (HAL_KIRIMA, ANUSVARA))


def _caption_letters(events: list) -> tuple[str, list[tuple[int, int]]]:
    """The captions' letters in time order and each letter's (start, end) in ms.

    A word starts at its event's tStartMs plus its tOffsetMs and ends at the next word's start or its
    event's end, whichever is first; its letters share that time evenly."""
    words = []
    for event in events:
        start = int(event.get("tStartMs", 0))
        end = start + int(event.get("dDurationMs", 0))
        for seg in event.get("segs") or []:
            word = letters(seg.get("utf8", ""))
            if word:
                words.append((start + int(seg.get("tOffsetMs", 0)), end, word))
    words.sort(key=lambda w: w[0])  # stable, so words at the same time keep their order
    text, times = [], []
    for k, (at, end, word) in enumerate(words):
        stop = max(at, min(end, words[k + 1][0]) if k + 1 < len(words) else end)
        n = len(word)
        for q, c in enumerate(word):
            text.append(c)
            times.append((at + (stop - at) * q // n, at + (stop - at) * (q + 1) // n))
    return "".join(text), times


def _bands(nb: int, nc: int) -> list[tuple[int, int]]:
    """For each row 0..nb, the caption columns lo..hi the alignment may use: BAND either side of the
    straight diagonal from (0, 0) to (nb, nc)."""
    bands = []
    for i in range(nb + 1):
        guide = i * nc // nb if nb else nc
        bands.append((max(0, guide - BAND), min(nc, guide + BAND)))
    bands[nb] = (bands[nb][0], nc)
    return bands


def _align(book: str, caps: str) -> list[int]:
    """For each book letter, the caption letter it is aligned to with an equal folded letter, or -1.

    Global alignment with affine gaps (Gotoh), so a stretch the recording has and the book has not (or
    the reverse) is skipped in one piece instead of scattering stray letters across it. On equal scores
    the traceback prefers skipping a caption letter, then a match, so a passage chanted several times
    is matched to its first chanting."""
    fb, fc = book.translate(_FOLD), caps.translate(_FOLD)
    bands = _bands(len(fb), len(fc))
    neg = -(10 ** 9)
    oe = OPEN + EXTEND
    # States: 0 = letters paired (M), 1 = book letter skipped (X), 2 = caption letter skipped (Y).
    # Each cell packs the predecessor state of M (bits 0-1), X (bits 2-3) and Y (bits 4-5).
    lo, hi = bands[0]
    width = hi - lo + 1
    pm, px, py = [neg] * width, [neg] * width, [neg] * width
    pm[0] = 0
    ptr0 = bytearray(width)
    for j in range(1, width):
        py[j] = OPEN + EXTEND * j
        ptr0[j] = (2 << 4) if j > 1 else 0
    ptrs = [ptr0]
    for i in range(1, len(fb) + 1):
        plo, phi = lo, hi
        lo, hi = bands[i]
        letter = fb[i - 1]
        width = hi - lo + 1
        cm, cx, cy = [neg] * width, [neg] * width, [neg] * width
        ptr = bytearray(width)
        for j in range(lo, hi + 1):
            k = j - lo
            bits = 0
            q = j - 1 - plo
            if j >= 1 and 0 <= q <= phi - plo:
                a, b, c = pm[q], px[q], py[q]
                # Picks the best predecessor state, ties to Y, M, X (see docstring); inlined here and below for speed.
                if c >= a and c >= b:
                    best, s = c, 2
                elif a >= b:
                    best, s = a, 0
                else:
                    best, s = b, 1
                cm[k] = best + (MATCH if fc[j - 1] == letter else MISMATCH)
                bits = s
            q = j - plo
            if q <= phi - plo:
                a, b, c = pm[q] + oe, px[q] + EXTEND, py[q] + oe
                if c >= a and c >= b:
                    best, s = c, 2
                elif a >= b:
                    best, s = a, 0
                else:
                    best, s = b, 1
                cx[k] = best
                bits |= s << 2
            if k > 0:
                a, b, c = cm[k - 1] + oe, cx[k - 1] + oe, cy[k - 1] + EXTEND
                if c >= a and c >= b:
                    best, s = c, 2
                elif a >= b:
                    best, s = a, 0
                else:
                    best, s = b, 1
                cy[k] = best
                bits |= s << 4
            ptr[k] = bits
        pm, px, py = cm, cx, cy
        ptrs.append(ptr)
    pairs = [-1] * len(fb)
    i, j = len(fb), len(fc)
    k = j - bands[i][0]
    a, b, c = pm[k], px[k], py[k]
    state = 2 if c >= a and c >= b else (0 if a >= b else 1)
    while i > 0 or j > 0:
        bits = ptrs[i][j - bands[i][0]]
        if state == 0:
            if fb[i - 1] == fc[j - 1]:
                pairs[i - 1] = j - 1
            state = bits & 3
            i, j = i - 1, j - 1
        elif state == 1:
            state = (bits >> 2) & 3
            i -= 1
        else:
            state = (bits >> 4) & 3
            j -= 1
    for i, p in enumerate(pairs):
        lo, hi = bands[i + 1]
        if p >= 0 and ((lo > 0 and p - lo < EDGE) or (hi < len(fc) and hi - p < EDGE)):
            raise TimingError("the alignment reached the edge of its band; widen BAND")
    return pairs


def _evidence(pairs: list[int]) -> tuple[int, int, int] | None:
    """The main run of one line's matched letters, as (first book offset, first caption letter, last
    caption letter), or None when the line has no real evidence.

    Matched letters are split into runs wherever the captions jump ahead more than JUMP letters beyond
    the book (a stray letter matched far from the rest); the longest run (earliest on a tie) is kept.
    The line counts only if that run holds MIN_SHARE of its letters, at least MIN_LETTERS, and starts
    within START_SLACK letters of the line's start, so its start time is the chanting's own."""
    hits = [(q, p) for q, p in enumerate(pairs) if p >= 0]
    if not hits:
        return None
    runs = [[hits[0]]]
    for (q0, p0), (q1, p1) in zip(hits, hits[1:]):
        if (p1 - p0) - (q1 - q0) > JUMP:
            runs.append([])
        runs[-1].append((q1, p1))
    run = max(runs, key=len)  # max keeps the first of equal runs
    if len(run) < MIN_LETTERS or len(run) < MIN_SHARE * len(pairs) or run[0][0] > START_SLACK:
        return None
    return run[0][0], run[0][1], run[-1][1]


def _place(counts: list[int], t0: int, t1: int) -> list[tuple[int, int]]:
    """Spreads lines with these letter counts over t0..t1 in proportion to their letters."""
    total, done, out = sum(counts), 0, []
    for n in counts:
        start = t0 + (t1 - t0) * done // total if total else t0
        done += n
        end = t0 + (t1 - t0) * done // total if total else t0
        out.append((start, end))
    return out


def _time(units: list, events: list, duration_ms: int) -> tuple[list, dict]:
    book, spans = "", []
    for u in units:
        for line in u["pali"]:
            text = letters(line["text"])
            spans.append((len(book), len(book) + len(text)))
            book += text
    caps, times = _caption_letters(events)
    pairs = _align(book, caps)
    raw = sum(1 for i, p in enumerate(pairs) if p >= 0 and book[i] == caps[p])
    # Matched lines: (start, end) from their main run of letters; None for the others.
    found = []
    for a, b in spans:
        run = _evidence(pairs[a:b])
        found.append(None if run is None else (times[run[1]][0], times[run[2]][1]))
    lines, k = [], 0
    while k < len(found):
        if found[k] is not None:
            lines.append((*found[k], "matched"))
            k += 1
            continue
        stop = k
        while stop < len(found) and found[stop] is None:
            stop += 1
        t0 = lines[-1][1] if lines else 0
        t1 = found[stop][0] if stop < len(found) else duration_ms
        counts = [b - a for a, b in spans[k:stop]]
        lines += [(s, e, "estimated") for s, e in _place(counts, t0, max(t0, t1))]
        k = stop
    # Invariants: starts never decrease, start <= end <= next start, nothing past the recording's end.
    out, floor = [], 0
    for s, _, how in lines:
        floor = min(max(floor, s), duration_ms)
        out.append([floor, 0, how])
    for i, (s, e, _) in enumerate(lines):
        nxt = out[i + 1][0] if i + 1 < len(out) else duration_ms
        out[i][1] = max(out[i][0], min(e, nxt))
    timed, i = [], 0
    for u in units:
        timed.append({"id": u["id"], "lines": [
            {"start_ms": s, "end_ms": e, "how": how} for s, e, how in out[i:i + len(u["pali"])]]})
        i += len(u["pali"])
    folded = sum(1 for p in pairs if p >= 0)
    stats = {"letters": len(book), "raw": raw, "folded": folded}
    return timed, stats


def time_lines(units: list, events: list, duration_ms: int) -> list:
    """Each unit's Pali lines with start_ms, end_ms and how (matched or estimated). Pure."""
    return _time(units, events, duration_ms)[0]


def _clock(ms: int) -> str:
    return f"{ms // 60000}:{ms // 1000 % 60:02d}.{ms % 1000:03d}"


def _percent(part: int, whole: int) -> str:
    return f"{100 * part / whole:.1f}%" if whole else "0.0%"


def report(units: list, timed: list, stats: dict) -> str:
    flat = []
    for u, t in zip(units, timed):
        for n, (line, tl) in enumerate(zip(u["pali"], t["lines"]), start=1):
            flat.append((u["id"], n, line, tl))
    total = len(flat)
    matched = sum(1 for *_, tl in flat if tl["how"] == "matched")
    longest, run, run_at, best_at = 0, 0, None, None
    for k, (*_, tl) in enumerate(flat):
        if tl["how"] == "estimated":
            run += 1
            run_at = k - run + 1
            if run > longest:
                longest, best_at = run, run_at
        else:
            run = 0
    out = []
    if matched < BASELINE_MATCHED_LINES:
        out.append(f"Shortfall: {matched} of {total} lines matched, below the baseline's "
                   f"{BASELINE_MATCHED_LINES}.")
        out.append("")
    out += [
        "# Samantha Pattana line times",
        "",
        f"Made by `tools/time_samantha_patthana.py` from `{EXTRACTED.as_posix()}` and the recording's",
        "automatic captions (timing data only; no caption word is copied here). Lines are identified by",
        "position; their text is not copied either.",
        "",
        "| Measure | Achieved | Baseline |",
        "| --- | --- | --- |",
        f"| Letters matched (identical letters) | {_percent(stats['raw'], stats['letters'])} "
        f"| {BASELINE_LETTERS_PERCENT}% |",
        f"| Letters matched (after folding spellings the recogniser confuses) "
        f"| {_percent(stats['folded'], stats['letters'])} | - |",
        f"| Lines matched | {matched} of {total} | {BASELINE_MATCHED_LINES} of {total} |",
        "",
    ]
    if longest:
        uid, n, line, _ = flat[best_at]
        out.append(f"Longest run of consecutive estimated lines: {longest} (from {uid} line {n}, "
                   f"page {line['page']} line {line['line']}).")
    else:
        out.append("Longest run of consecutive estimated lines: 0.")
    out += ["", "## Start of each unit", "", "| Unit | Start | ms | How |", "| --- | --- | --- | --- |"]
    for t in timed:
        first = t["lines"][0]
        out.append(f"| {t['id']} | {_clock(first['start_ms'])} | {first['start_ms']} | {first['how']} |")
    out += ["", "## Estimated lines", "",
            "| Unit | Line in unit | Page | Line | Start |", "| --- | --- | --- | --- | --- |"]
    for uid, n, line, tl in flat:
        if tl["how"] == "estimated":
            out.append(f"| {uid} | {n} | {line['page']} | {line['line']} | {_clock(tl['start_ms'])} |")
    return "\n".join(out) + "\n"


def render(timed: list, duration_ms: int) -> str:
    return json.dumps({"duration_ms": duration_ms, "units": timed}, ensure_ascii=False, indent=1) + "\n"


def main() -> None:
    args = sys.argv[1:]
    if len(args) != 2:
        sys.exit("usage: python -I -X utf8 tools/time_samantha_patthana.py <project_root> <captions.json3>")
    root = pathlib.Path(args[0])
    try:
        units = json.loads((root / EXTRACTED).read_text(encoding="utf-8"))["units"]
        events = json.loads(pathlib.Path(args[1]).read_text(encoding="utf-8"))["events"]
    except (OSError, ValueError, KeyError) as e:
        sys.exit(f"time_samantha_patthana: cannot read the inputs: {e}")
    try:
        timed, stats = _time(units, events, DURATION_MS)
    except TimingError as e:
        sys.exit(f"time_samantha_patthana: {e}")
    (root / OUTPUT).write_bytes(render(timed, DURATION_MS).encode("utf-8"))
    (root / REPORT).write_bytes(report(units, timed, stats).encode("utf-8"))
    print(f"wrote {OUTPUT.as_posix()} and {REPORT.as_posix()}")


if __name__ == "__main__":
    main()
