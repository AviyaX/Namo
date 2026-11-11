"""Tests for tools/time_samantha_patthana.py.

Run: python -I -X utf8 tools/test_time_samantha_patthana.py
Set SAMANTHA_PATTHANA_SRC to the source folder to also check the outputs against the captions.
Hand-made data uses made-up letter strings; real text is only read from the extracted file.
"""
import importlib.util
import json
import os
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
_SPEC = importlib.util.spec_from_file_location("time_samantha_patthana", ROOT / "tools" / "time_samantha_patthana.py")
timing = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(timing)

EXTRACTED = ROOT / "content" / "extracted" / "samantha_patthana.json"
TIMES = ROOT / "content" / "extracted" / "samantha_patthana_times.json"
REPORT = ROOT / "content" / "samantha_patthana_timing_report.md"

MIN_MATCHED = 437


def units(*groups):
    """Units u-0, u-1, ... whose Pali lines are the given made-up strings."""
    return [{"id": f"u-{k}", "pali": [{"page": 4, "line": 3 + n, "text": t} for n, t in enumerate(lines)]}
            for k, lines in enumerate(groups)]


def event(start, words, step=200, duration=1000):
    return {"tStartMs": start, "dDurationMs": duration,
            "segs": [{"utf8": w, **({"tOffsetMs": k * step} if k else {})} for k, w in enumerate(words)]}


NEWLINE = {"tStartMs": 0, "dDurationMs": 10, "segs": [{"utf8": "\n"}]}


def flat(timed):
    return [line for u in timed for line in u["lines"]]


def assert_invariants(test, lines, duration):
    for k, line in enumerate(lines):
        test.assertLessEqual(line["start_ms"], line["end_ms"])
        if k + 1 < len(lines):
            test.assertLessEqual(line["start_ms"], lines[k + 1]["start_ms"])
            test.assertLessEqual(line["end_ms"], lines[k + 1]["start_ms"])
    test.assertLessEqual(lines[-1]["end_ms"], duration)


class TimeLinesTest(unittest.TestCase):
    def test_exact_matches_get_the_caption_times(self):
        got = flat(timing.time_lines(units(["කගචජ", "ටඩතද"], ["පබමය"]),
                                     [NEWLINE, event(1000, ["කගචජ"]), event(2000, ["ටඩ", "තද"]),
                                      {"tStartMs": 2500}, event(3000, ["පබමය"])], 10000))
        self.assertEqual([(g["start_ms"], g["end_ms"], g["how"]) for g in got],
                         [(1000, 2000, "matched"), (2000, 3000, "matched"), (3000, 4000, "matched")])

    def test_line_without_caption_words_is_estimated_by_letter_count(self):
        got = flat(timing.time_lines(units(["කගචජ", "යරලව", "සහළෆයරලව", "පබමය"]),
                                     [event(1000, ["කගචජ"]), event(8000, ["පබමය"])], 10000))
        self.assertEqual([g["how"] for g in got], ["matched", "estimated", "estimated", "matched"])
        self.assertEqual([g["start_ms"] for g in got], [1000, 2000, 4000, 8000])
        self.assertEqual(got[1]["end_ms"], 4000)
        self.assertEqual(got[2]["end_ms"], 8000)

    def test_identical_consecutive_lines_are_not_swapped(self):
        got = flat(timing.time_lines(units(["කගචජ", "කගචජ"], ["පබමය"]),
                                     [event(1000, ["කගචජ"]), event(3000, ["කගචජ"]), event(5000, ["පබමය"])], 9000))
        self.assertEqual([(g["start_ms"], g["how"]) for g in got],
                         [(1000, "matched"), (3000, "matched"), (5000, "matched")])

    def test_passage_chanted_three_times_matches_its_first_chanting(self):
        got = flat(timing.time_lines(units(["කගචජටඩ"], ["පබමය"]),
                                     [event(1000, ["කගචජටඩ"]), event(3000, ["කගචජටඩ"]),
                                      event(5000, ["කගචජටඩ"]), event(7000, ["පබමය"])], 9000))
        self.assertEqual([(g["start_ms"], g["how"]) for g in got], [(1000, "matched"), (7000, "matched")])

    def test_output_never_steps_backwards_when_an_event_is_out_of_order(self):
        got = flat(timing.time_lines(units(["කගචජ", "ටඩතද", "පබමය"]),
                                     [event(5000, ["කගචජ"]), event(3000, ["ටඩතද"]), event(7000, ["පබමය"])], 9000))
        assert_invariants(self, got, 9000)
        self.assertEqual(got[2]["start_ms"], 7000)

    def test_lines_before_the_first_and_after_the_last_match_fit_the_recording(self):
        got = flat(timing.time_lines(units(["යරලව", "කගචජ", "සහළෆ"]), [event(4000, ["කගචජ"])], 9000))
        self.assertEqual([g["how"] for g in got], ["estimated", "matched", "estimated"])
        self.assertEqual(got[0]["start_ms"], 0)
        assert_invariants(self, got, 9000)


class CommittedFilesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.units = json.loads(EXTRACTED.read_text(encoding="utf-8"))["units"]
        cls.times = json.loads(TIMES.read_text(encoding="utf-8"))
        cls.report = REPORT.read_text(encoding="utf-8")

    def test_same_units_and_line_counts(self):
        self.assertEqual(self.times["duration_ms"], 2856000)
        self.assertEqual([u["id"] for u in self.times["units"]], [u["id"] for u in self.units])
        self.assertEqual([len(u["lines"]) for u in self.times["units"]], [len(u["pali"]) for u in self.units])

    def test_invariants(self):
        lines = flat(self.times["units"])
        self.assertEqual(len(lines), 507)
        assert_invariants(self, lines, 2856000)
        for line in lines:
            self.assertEqual(set(line), {"start_ms", "end_ms", "how"})
            self.assertIn(line["how"], ("matched", "estimated"))
            self.assertIsInstance(line["start_ms"], int)
            self.assertIsInstance(line["end_ms"], int)

    def test_matched_count_and_anchors(self):
        lines = flat(self.times["units"])
        self.assertGreaterEqual(sum(1 for line in lines if line["how"] == "matched"), MIN_MATCHED)
        by_id = {u["id"]: u["lines"] for u in self.times["units"]}
        self.assertEqual(by_id["u-homage"][0]["how"], "matched")
        self.assertEqual(by_id["u-verses"][0]["how"], "matched")

    def test_report_names_exactly_the_estimated_lines(self):
        estimated = section_rows(self.report, "## Estimated lines")
        expected = []
        for u, t in zip(self.units, self.times["units"]):
            for n, (line, tl) in enumerate(zip(u["pali"], t["lines"]), start=1):
                if tl["how"] == "estimated":
                    expected.append([u["id"], str(n), str(line["page"]), str(line["line"]),
                                     timing._clock(tl["start_ms"])])
        self.assertEqual(estimated, expected)

    def test_report_states_figures_and_every_unit_start(self):
        matched = sum(1 for line in flat(self.times["units"]) if line["how"] == "matched")
        self.assertIn(f"| Lines matched | {matched} of 507 | 437 of 507 |", self.report)
        self.assertIn("Longest run of consecutive estimated lines:", self.report)
        starts = section_rows(self.report, "## Start of each unit")
        self.assertEqual([r[0] for r in starts], [u["id"] for u in self.units])
        self.assertEqual([int(r[2]) for r in starts], [u["lines"][0]["start_ms"] for u in self.times["units"]])


def section_rows(text, heading):
    """The cells of a markdown table's body rows under the heading."""
    body = text.split(heading + "\n", 1)[1].split("\n## ", 1)[0]
    rows = [r for r in body.split("\n") if r.startswith("| ")]
    return [[c.strip() for c in r.strip("|").split("|")] for r in rows[1:] if not r.startswith("| ---")]


SRC = os.environ.get("SAMANTHA_PATTHANA_SRC")


@unittest.skipUnless(SRC and pathlib.Path(SRC).is_dir(),
                     "SAMANTHA_PATTHANA_SRC is not set to the source folder, so the captions are not checked")
class AgainstCaptionsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        captions = pathlib.Path(SRC) / "audio" / "captions" / "si-orig.json3"
        cls.events = json.loads(captions.read_text(encoding="utf-8"))["events"]
        cls.units = json.loads(EXTRACTED.read_text(encoding="utf-8"))["units"]

    def test_outputs_are_current(self):
        timed, stats = timing._time(self.units, self.events, timing.DURATION_MS)
        self.assertEqual(timing.render(timed, timing.DURATION_MS), TIMES.read_text(encoding="utf-8"))
        self.assertEqual(timing.report(self.units, timed, stats), REPORT.read_text(encoding="utf-8"))

    def test_no_caption_word_is_written(self):
        pali = "\n".join(line["text"] for u in self.units for line in u["pali"])
        words = {w.strip() for e in self.events for s in e.get("segs") or [] for w in re.split(r"\s+", s.get("utf8", ""))}
        foreign = sorted(w for w in words if w and w not in pali)
        self.assertTrue(foreign)
        for path in (TIMES, REPORT):
            text = path.read_text(encoding="utf-8")
            leaked = [w for w in foreign if w in text]
            self.assertEqual(leaked, [], f"{path.name} holds caption words")


if __name__ == "__main__":
    unittest.main()
