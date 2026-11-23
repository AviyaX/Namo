"""Assembles the Buddha Wandanawa recordings, one file per section, from:

  - Ven. Nauyane Ariyadhamma Thero's morning Buddha Vandana (YouTube NkxAu76U6z4,
    channel "Theravada"), cut verse by verse;
  - his Saranagamana pirith (hosted/audio/pirith/02-saranagamanam.m4a) for s03;
  - his Pansil (YouTube K7If2Z1B3ME, Ehipassiko) for the five precepts of s04;
  - the owner's own chanting turned into the Thero's voice by computer (Seed-VC),
    slowed to 90%, for what the Thero's recordings lack (COMPUTER below).

Verses are joined in the app's order with a short pause between them. Each verse's
start and end in its file go to content/wandana_audio.json, which
tools/build_content.py reads. Cut times were placed from the video's captions and
moved to the quietest point nearby (ffmpeg silencedetect and a loudness curve).

  python -I -X utf8 tools/assemble_wandana_audio.py <project_root> \
      --vandana <vandana.m4a> --pansil <K7If2Z1B3ME.m4a> --computer <dir of 01.m4a ...>
"""
from __future__ import annotations

import json
import pathlib
import subprocess
import sys
import tempfile

OUT_DIR = pathlib.Path("hosted/audio/wandana")
TIMES = pathlib.Path("content/wandana_audio.json")
PIRITH_02 = pathlib.Path("hosted/audio/pirith/02-saranagamanam.m4a")
RATE = 44100
GAP = 0.7      # seconds of silence between verses
JOIN = 0.25    # between two pieces of one verse
LEAD = 0.3     # before the first verse
TAIL = 0.6     # after the last
THERO = "Chanted by Ven. Nauyane Ariyadhamma Thero"
COMPUTER = "Computer-made chanting in the voice of Ven. Nauyane Ariyadhamma Thero"
SAADHU = 0.25  # fade where the Thero runs straight on into "saadhu"


def v(a: float, b: float, fade: float = 0.03) -> list:
    """One piece of the vandana."""
    return [("V", a, b, fade)]


def c(name: str, a: float | None = None, b: float | None = None) -> list:
    """One computer-made piece (None: from its start / to its end)."""
    return [(f"C:{name}", a, b, 0.03)]


def _run_of(sid: str, starts: list[float], ends: list[float]) -> dict:
    return {f"{sid}-v{i + 1}": v(a, b) for i, (a, b) in enumerate(zip(starts, ends))}


# A verse is a list of pieces (source, start, end, fade-out), or None when nothing
# chants it. Sources: V the vandana, P the pansil, S pirith 02, C:<file> computer-made.
SECTIONS: dict[str, dict] = {
    "s01": {"label": COMPUTER, "verses": {
        "s01-v1": c("01.m4a", 0.0, 4.25), "s01-v2": c("01.m4a", 4.25, 8.35),
        "s01-v3": c("01.m4a", 8.35, 12.65), "s01-v4": c("01.m4a", 12.65, 16.85),
        "s01-v5": c("01.m4a", 16.85)}},
    "s02": {"label": THERO, "verses": {"s02-v1": v(0.0, 24.30)}},
    "s03": {"label": THERO, "verses": {"s03-v1": [("S", 27.40, 100.30, 0.03)]}},
    "s04": {"label": THERO + "; the last line computer-made in his voice", "verses": {
        "s04-v1": [("P", 2.0, 55.6, 0.05)] + c("04-last.m4a")}},
    "s05": {"label": THERO, "verses": {
        "s05-v1": v(204.90, 230.95), "s05-v2": v(230.95, 237.70), "s05-v3": v(237.70, 252.55),
        "s05-v4": v(252.55, 266.95), "s05-v5": v(266.95, 281.05, SAADHU)}},
    "s06": {"label": THERO, "verses": {
        "s06-v1": v(285.15, 304.25), "s06-v2": v(304.25, 311.05), "s06-v3": v(311.05, 326.30),
        "s06-v4": v(326.30, 340.55), "s06-v5": v(340.55, 354.60, SAADHU)}},
    "s07": {"label": THERO, "verses": {
        "s07-v1": v(358.75, 416.00), "s07-v2": v(416.00, 422.95), "s07-v3": v(422.95, 438.75),
        "s07-v4": v(438.75, 453.35), "s07-v5": v(453.35, 467.70, SAADHU)}},
    # The Thero's vandana has no verse 3 here.
    "s08": {"label": THERO + "; verses 6 to 8 computer-made in his voice. Verse 3 is not chanted.",
            "verses": {
                "s08-v1": v(472.05, 487.35), "s08-v2": v(487.35, 500.45), "s08-v3": None,
                "s08-v4": v(500.45, 514.70), "s08-v5": v(514.70, 536.90, SAADHU),
                "s08-v6": c("08-6-8.m4a", 0.0, 17.0), "s08-v7": c("08-6-8.m4a", 17.0, 33.95),
                "s08-v8": c("08-6-8.m4a", 33.95)}},
    "s09": {"label": COMPUTER, "verses": {"s09-v1": c("09.m4a")}},
    "s10": {"label": COMPUTER, "verses": {
        "s10-v1": c("10-1-2.m4a", 0.0, 11.2), "s10-v2": c("10-1-2.m4a", 11.2), "s10-v3": c("10-3.m4a")}},
    "s11": {"label": COMPUTER, "verses": {"s11-v1": c("11.m4a")}},
    "s12": {"label": THERO, "verses": {"s12-v1": v(38.30, 52.95)}},
    "s13": {"label": THERO + "; verse 1 computer-made in his voice", "verses": {
        "s13-v1": c("13-1.m4a"), "s13-v2": v(52.95, 67.05)}},
    "s14": {"label": COMPUTER, "verses": {"s14-v1": c("14.m4a", 0.0, 16.0), "s14-v2": c("14.m4a", 16.0)}},
    "s15": {"label": COMPUTER, "verses": {"s15-v1": c("15.m4a")}},
    "s16": {"label": COMPUTER, "verses": {"s16-v1": c("16.m4a")}},
    "s17": {"label": COMPUTER, "verses": {"s17-v1": c("17.m4a")}},
    "s18": {"label": COMPUTER, "verses": {"s18-v1": c("18.m4a")}},
    "s19": {"label": COMPUTER, "verses": {"s19-v1": c("19.m4a")}},
    "s20": {"label": THERO, "verses": {
        "s20-v1": v(2956.45, 2968.45), "s20-v2": v(2968.45, 2980.40), "s20-v3": v(2980.40, 2989.90, 0.2)}},
    "s21": {"label": THERO, "verses": {"s21-v1": v(2743.75, 2761.70)}},
    "s22": {"label": THERO, "verses": {
        "s22-v1": v(2761.70, 2773.80), "s22-v2": v(2773.80, 2786.05), "s22-v3": v(2786.05, 2798.30),
        "s22-v4": v(2798.30, 2835.45)}},
    # The Thero chants verses 1 and 4 three times; the first is taken (for verse 4,
    # its first "... hotu" and the closing "sabba dukkhā pamuccatu").
    "s23": {"label": THERO, "verses": {
        "s23-v1": v(2870.85, 2882.80), "s23-v2": v(2928.60, 2948.10), "s23-v3": v(2948.10, 2956.45),
        "s23-v4": [("V", 2906.55, 2912.70, 0.05), ("V", 2924.65, 2928.60, 0.03)]}},
    "s24": {"label": THERO, "verses": _run_of(
        "s24",
        [1673.05, 1685.95, 1698.40, 1711.80, 1725.60, 1738.20, 1750.80, 1763.60, 1777.15, 1790.45, 1803.60],
        [1685.95, 1698.40, 1711.80, 1725.60, 1738.20, 1750.80, 1763.60, 1777.15, 1790.45, 1803.60, 1818.45])},
    "s25": {"label": THERO, "verses": _run_of(
        "s25", [1818.45, 1832.35, 1845.15, 1858.10, 1871.05], [1832.35, 1845.15, 1858.10, 1871.05, 1884.80])},
    "s26": {"label": THERO, "verses": _run_of(
        "s26", [1884.80, 1897.35, 1910.60, 1923.55, 1936.30, 1948.70],
        [1897.35, 1910.60, 1923.55, 1936.30, 1948.70, 1962.50])},
    "s27": {"label": THERO, "verses": _run_of(
        "s27", [1962.50, 1975.70, 1988.45, 2001.00, 2013.10, 2025.45, 2038.10],
        [1975.70, 1988.45, 2001.00, 2013.10, 2025.45, 2038.10, 2052.55])},
    "s28": {"label": THERO, "verses": {
        "s28-v1": v(2052.55, 2065.95), "s28-v2": v(2065.95, 2083.15), "s28-v3": v(2083.15, 2105.15)}},
    "s29": {"label": THERO, "verses": {"s29-v1": v(2300.05, 2362.50)}},
    "s30": {"label": THERO, "verses": {"s30-v1": v(2362.50, 2434.50)}},
    # His Metta chanting differs from this text except verses 1 and 7.
    "s33": {"label": THERO + ". Only verses 1 and 7 are chanted; his other verses differ from this text.",
            "verses": {"s33-v1": v(1500.35, 1513.05),
                       **{f"s33-v{i}": None for i in (2, 3, 4, 5, 6)},
                       "s33-v7": v(1622.90, 1673.05),
                       **{f"s33-v{i}": None for i in (8, 9, 10, 11)}}},
}


def _run(args: list[str]) -> None:
    subprocess.run(args, check=True, capture_output=True)


def _probe(path: pathlib.Path, entry: str, stream: bool = False) -> str:
    args = ["ffprobe", "-v", "error"] + (["-select_streams", "a:0"] if stream else [])
    args += ["-show_entries", entry, "-of", "csv=p=0", str(path)]
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout.strip()


def _duration(path: pathlib.Path) -> float:
    return float(_probe(path, "format=duration"))


def _piece(src: pathlib.Path, a, b, fade: float, denoise: bool, out: pathlib.Path) -> float:
    """Cuts [a, b) of src to a mono WAV, faded at both ends; its length."""
    args = ["ffmpeg", "-y", "-loglevel", "error"]
    if a is not None:
        args += ["-ss", f"{a:.3f}"]
    if b is not None:
        args += ["-to", f"{b:.3f}"]
    args += ["-i", str(src)]
    length = (b if b is not None else _duration(src)) - (a or 0.0)
    filters = ["aresample=44100"]
    if denoise:
        filters.append("afftdn=nf=-25")
    filters += ["afade=t=in:d=0.03", f"afade=t=out:st={max(0.0, length - fade):.3f}:d={fade:.3f}"]
    _run(args + ["-af", ",".join(filters), "-ac", "1", "-ar", str(RATE), "-c:a", "pcm_s16le", str(out)])
    return _duration(out)


def assemble(root: pathlib.Path, vandana: pathlib.Path, pansil: pathlib.Path, computer: pathlib.Path) -> dict:
    sources = {"V": vandana, "P": pansil, "S": root / PIRITH_02}
    (root / OUT_DIR).mkdir(parents=True, exist_ok=True)
    times: dict[str, dict] = {}
    with tempfile.TemporaryDirectory() as tmp_name:
        tmp = pathlib.Path(tmp_name)
        silence = {}
        for name, secs in (("lead", LEAD), ("gap", GAP), ("tail", TAIL), ("join", JOIN)):
            silence[name] = tmp / f"{name}.wav"
            _run(["ffmpeg", "-y", "-loglevel", "error", "-f", "lavfi", "-i", f"anullsrc=r={RATE}:cl=mono",
                  "-t", f"{secs}", "-c:a", "pcm_s16le", str(silence[name])])
        for sid, sec in SECTIONS.items():
            parts = [silence["lead"]]
            at = _duration(silence["lead"])
            block_times: list = []
            for vid, pieces in sec["verses"].items():
                if pieces is None:
                    block_times.append(None)
                    continue
                if any(t is not None for t in block_times):
                    parts.append(silence["gap"])
                    at += _duration(silence["gap"])
                start = at
                for k, (src, a, b, fade) in enumerate(pieces):
                    if k:
                        parts.append(silence["join"])
                        at += _duration(silence["join"])
                    path = computer / src[2:] if src.startswith("C:") else sources[src]
                    out = tmp / f"{vid}-{k}.wav"
                    at += _piece(path, a, b, fade, denoise=not src.startswith("C:"), out=out)
                    parts.append(out)
                block_times.append([round(start, 3), round(at, 3)])
            parts.append(silence["tail"])
            listing = tmp / f"{sid}.txt"
            listing.write_text("".join(f"file '{p.as_posix()}'\n" for p in parts), encoding="utf-8")
            joined = tmp / f"{sid}.wav"
            _run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", str(listing),
                  "-c", "copy", str(joined)])
            target = root / OUT_DIR / f"{sid[1:]}.m4a"
            _run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(joined), "-af",
                  "loudnorm=I=-15:TP=-1.5:LRA=11", "-ar", str(RATE), "-ac", "1", "-c:a", "aac", "-b:a", "56k",
                  "-movflags", "+faststart", "-map_metadata", "-1", str(target)])
            times[sid] = {"path": f"audio/wandana/{sid[1:]}.m4a", "label": sec["label"],
                          "block_times": block_times}
            print(sid, target.name, f"{_duration(target):.1f}s",
                  sum(t is not None for t in block_times), "of", len(block_times), "verses")
    (root / TIMES).write_text(json.dumps(times, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    return times


def main(argv: list[str]) -> int:
    if len(argv) != 7 or argv[1] != "--vandana" or argv[3] != "--pansil" or argv[5] != "--computer":
        print(__doc__, file=sys.stderr)
        return 2
    assemble(pathlib.Path(argv[0]), pathlib.Path(argv[2]), pathlib.Path(argv[4]), pathlib.Path(argv[6]))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
