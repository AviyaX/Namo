#!/usr/bin/env python3
"""Build assets/bana/bana.json from the draft list and the topics file.

Usage: python tool/bana/build_bana.py tool/bana/draft-list.json \
           tool/bana/topics.json > assets/bana/bana.json

Titles come from the YouTube title only: it is split at "|" and " - ",
the speaker/channel name forms listed under "trim" in topics.json are cut
out, and what is left is joined with " · ". Titles that still look like they
hold a monk's name are printed to stderr for review.
"""
import json
import re
import sys

VERSION = 2
REVIEW = (
    "thero", "uyane", "ariyadassana", "wassana", "wassaba", "kiriwaththuduv",
    "kiriwaththuduw", "kirivaththuduw", "kiriwathuduv", "ariyadassan",
    "ariyadasana", "ariya asana", "aiyadassana", "kelaniye", "sasanawansa", "pragna",
)
EDGE = " \t-|.​‍‌"


def seconds(text):
    n = 0
    for p in text.split(":"):
        n = n * 60 + int(p)
    return n


def clean_title(title, trims):
    pieces = []
    for raw in re.split(r"\||\s-\s", title):
        piece = raw
        for t in trims:
            piece = t.sub("", piece)
        piece = piece.strip(" 	​‍‌")
        if piece != raw.strip(" 	​‍‌"):
            # A name was cut out: drop the separator it leaves behind.
            piece = piece.rstrip(" 	-.|​‍‌")
        if piece.strip(EDGE) and piece not in pieces:
            pieces.append(piece)
    return " · ".join(pieces)


def main(draft_path, topics_path):
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    draft = json.load(open(draft_path, encoding="utf-8"))
    cfg = json.load(open(topics_path, encoding="utf-8"))
    trims = [re.compile(t, re.I) for t in cfg["trim"]]
    topic_ids = {t["id"] for t in cfg["topics"]}
    speaker_of = {s["name"]: s["id"] for s in cfg["speakers"]}
    channel_of = {c["name"]: c["id"] for c in cfg["channels"]}
    series_of = {s["draft"]: s for s in cfg["series"]}

    seen, bana, parts = set(), [], {s["id"]: [] for s in cfg["series"]}
    for r in draft:
        if r["id"] in seen:
            continue
        seen.add(r["id"])
        title = clean_title(r["title"], trims)
        if not title:
            sys.exit("empty title for " + r["id"])
        if any(w in title.lower() for w in REVIEW):
            print("review:", r["id"], title, file=sys.stderr)
        rec = {
            "id": r["id"],
            "title": title,
            "speaker": speaker_of[r["speaker"]],
            "channel": channel_of[r["channel"]],
            "topics": [],
            "seconds": seconds(r["len"]),
            "embeddable": bool(r["embeddable"]),
        }
        if r.get("series"):
            s = series_of[r["series"]]
            rec["series"] = s["id"]
            rec["part"] = int(r["part"])
            parts[s["id"]].append(rec)
        else:
            codes = r["topics"]
            assert codes and set(codes) <= topic_ids, r["id"]
            rec["topics"] = codes
        bana.append(rec)

    series = []
    for s in cfg["series"]:
        ps = sorted(parts[s["id"]], key=lambda b: b["part"])
        assert [b["part"] for b in ps] == list(range(1, len(ps) + 1)), s["id"]
        series.append({
            "id": s["id"],
            "title": s["draft"],
            "speaker": s["speaker"],
            "channel": s["channel"],
            "topics": s["topics"],
            "parts": [b["id"] for b in ps],
        })
    out = {
        "version": VERSION,
        "topics": [{"id": t["id"], "si": t["si"], "en": t["en"]} for t in cfg["topics"]],
        "speakers": cfg["speakers"],
        "channels": cfg["channels"],
        "series": series,
        "bana": bana,
    }
    json.dump(out, sys.stdout, ensure_ascii=False, indent=1)
    sys.stdout.write("\n")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
