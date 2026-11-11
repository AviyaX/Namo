"""Tests for tools/build_samantha_patthana.py.

Run: python -I -X utf8 tools/test_build_samantha_patthana.py
Set SAMANTHA_PATTHANA_SRC to the source folder to also compare the committed file with the pages.
Hand-made data uses made-up letter strings; real text is only read from the extracted file.
"""
import importlib.util
import json
import os
import pathlib
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
_SPEC = importlib.util.spec_from_file_location("build_samantha_patthana", ROOT / "tools" / "build_samantha_patthana.py")
build = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(build)

EXTRACTED = ROOT / "content" / "extracted" / "samantha_patthana.json"

IDS = ["u-homage", "u-verses", "u-list"] + [f"u-part-{n}" for n in range(1, 25)] + ["u-closing"]
PALI_COUNTS = [3, 6, 11, 6, 27, 19, 55, 55, 14, 9, 31, 29, 45, 5, 10, 8, 5, 7, 22, 6, 6, 5, 6, 50, 6, 6, 50, 5]
SINHALA_COUNTS = [4, 0, 9, 4, 26, 14, 43, 43, 12, 6, 23, 22, 43, 3, 7, 5, 3, 5, 15, 4, 4, 3, 4, 37, 4, 4, 37, 1]


def make_half(pages_dir, first_page, names, lines_per_page=3):
    """Lays one text line per name onto pages (a blank line inside unit 'c',
    a page break whenever a page is full). Returns (pages, start of each name, last page)."""
    page, line = first_page, 3
    starts, text = [], {}
    for name in names:
        for k in range(2 if name in ("b", "c") else 1):
            if line > lines_per_page + 2:
                page, line = page + 1, 3
            if k == 0:
                starts.append({"page": page, "line": line})
            text.setdefault(page, {})[line] = f"{name}{k}x{page}"
            line += 1
            if name == "c" and k == 0:
                line += 1  # a blank line inside this unit
    for p, rows in text.items():
        top = max(rows)
        body = [str(p), ""] + [rows.get(n, "") for n in range(3, top + 1)]
        (pages_dir / f"page-{p:02d}.txt").write_text("\n".join(body) + "\n", encoding="utf-8")
    return starts, page


def make_source(root, part_numbers=None, overlap=False, stray=False):
    pages_dir = root / "converted" / "pages"
    pages_dir.mkdir(parents=True)
    names = ["a", "b", "c"] + [f"p{n}" for n in range(1, 25)] + ["z"]
    p_starts, p_last = make_half(pages_dir, 4, names)
    s_names = ["h", "l"] + [f"s{n}" for n in range(1, 25)] + ["y"]
    s_starts, s_last = make_half(pages_dir, p_last + 1, s_names)
    if overlap:
        p_starts[4] = dict(p_starts[3])
    if stray:  # a text line before the first unit
        page = pages_dir / "page-04.txt"
        rows = page.read_text(encoding="utf-8").split("\n")
        rows[1] = "stray"
        page.write_text("\n".join(rows), encoding="utf-8")
    numbers = part_numbers or list(range(1, 25))

    def half(starts, pages, opening_keys, extra=0):
        n_open = len(opening_keys)
        parts = []
        for i, number in enumerate(numbers):
            parts.append({"number": number, **starts[n_open + i], "heading": "h",
                          "ends_before": starts[n_open + i + 1]})
        return {"pages": pages,
                "opening": {key: [{**starts[i], "text": "t"}] for i, key in enumerate(opening_keys)},
                "parts": parts, "closing": [{**starts[-1], "text": "t"}]}

    structure = {"title_page": {"page": 1, "lines": []}, "introduction": {"pages": [2, 3]},
                 "pali": half(p_starts, [4, p_last], ["homage", "three_opening_verses", "list_of_24_paccayas"]),
                 "sinhala_meaning": half(s_starts, [p_last + 1, s_last], ["homage", "list_of_24"])}
    (root / "converted" / "structure.json").write_text(json.dumps(structure), encoding="utf-8")
    (root / "introduction_owner_supplied.md").write_text(
        "# T\n\nnote\n\n---\n\nQQ one\n\nQQ two  \n\nQQ three\n", encoding="utf-8")
    return p_last, s_last


class SmallSourceTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def test_lines_in_order_with_page_numbers_and_blanks_skipped(self):
        make_source(self.root)
        data = build.extract(self.root)
        self.assertEqual([u["id"] for u in data["units"]], IDS)
        by_id = {u["id"]: u for u in data["units"]}
        self.assertEqual([e["text"].split("x")[0] for e in by_id["u-verses"]["pali"]], ["b0", "b1"])
        self.assertEqual([e["text"].split("x")[0] for e in by_id["u-list"]["pali"]], ["c0", "c1"])
        self.assertEqual(by_id["u-verses"]["sinhala"], [])
        self.assertEqual(len(by_id["u-part-1"]["pali"]), 1)
        everything = [e for u in data["units"] for e in u["pali"]]
        self.assertEqual([(e["page"], e["line"]) for e in everything],
                         sorted((e["page"], e["line"]) for e in everything))
        self.assertTrue(all(e["line"] >= 3 for e in everything))
        self.assertGreater(everything[-1]["page"], everything[0]["page"])
        self.assertEqual(data["introduction"], ["QQ one", "QQ two  ", "QQ three"])

    def test_part_numbers_out_of_order_fail(self):
        make_source(self.root, part_numbers=[2, 1] + list(range(3, 25)))
        with self.assertRaises(build.BuildError):
            build.extract(self.root)

    def test_overlapping_ranges_fail(self):
        make_source(self.root, overlap=True)
        with self.assertRaises(build.BuildError):
            build.extract(self.root)

    def test_text_outside_every_unit_fails(self):
        make_source(self.root, stray=True)
        with self.assertRaises(build.BuildError) as ctx:
            build.extract(self.root)
        self.assertIn("outside every unit", str(ctx.exception))


class CommittedFileTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = json.loads(EXTRACTED.read_text(encoding="utf-8"))

    def test_units_and_counts(self):
        units = self.data["units"]
        self.assertEqual([u["id"] for u in units], IDS)
        self.assertEqual([len(u["pali"]) for u in units], PALI_COUNTS)
        self.assertEqual([len(u["sinhala"]) for u in units], SINHALA_COUNTS)
        self.assertEqual(sum(PALI_COUNTS), 507)
        self.assertEqual(sum(SINHALA_COUNTS), 385)
        self.assertEqual([u.get("number") for u in units[3:27]], list(range(1, 25)))

    def test_introduction_and_title(self):
        self.assertEqual([len(p) for p in self.data["introduction"]], [253, 617, 1054])
        self.assertEqual(self.data["title"], build.TITLE)

    def test_no_line_has_outer_whitespace(self):
        for u in self.data["units"]:
            for e in u["pali"] + u["sinhala"]:
                self.assertEqual(e["text"], e["text"].strip())
                self.assertTrue(e["text"])

    def test_render_round_trip(self):
        self.assertEqual(build.render(self.data), EXTRACTED.read_text(encoding="utf-8"))


TIMES = ROOT / "content" / "extracted" / "samantha_patthana_times.json"
ASSET = ROOT / "assets" / "content" / "samantha_patthana.json"
PICTURE = ROOT / "assets" / "pictures" / "samantha_patthana.jpg"


def fake_extracted(sinhala_in_verses=False):
    """Made-up extracted data: unit k has k%3+1 Pali lines and 2 meaning lines (none for u-verses)."""
    units = []
    for k, unit_id in enumerate(IDS):
        n = k % 3 + 1
        units.append({
            "id": unit_id, "kind": "x",
            "pali": [{"page": 4, "line": 3 + i, "text": f"P{k}q{i}"} for i in range(n)],
            "sinhala": [] if unit_id == "u-verses" and not sinhala_in_verses
            else [{"page": 40, "line": 3 + i, "text": f"S{k}q{i}"} for i in range(2)]})
    return {"title": "TTL", "introduction": ["I one", "I two", "I three"], "units": units}


def fake_times(extracted, duration=2856000):
    units, at = [], 1000
    for u in extracted["units"]:
        lines = []
        for _ in u["pali"]:
            lines.append({"start_ms": at, "end_ms": at + 900, "how": "matched"})
            at += 1000
        units.append({"id": u["id"], "lines": lines})
    return {"duration_ms": duration, "units": units}


def write_project(root, extracted=None, times=None):
    extracted = extracted or fake_extracted()
    times = times or fake_times(extracted)
    (root / "content" / "extracted").mkdir(parents=True)
    (root / build.OUTPUT).write_text(json.dumps(extracted), encoding="utf-8")
    (root / build.TIMES).write_text(json.dumps(times), encoding="utf-8")
    return extracted, times


class BuildFromFakeDataTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name)
        self.extracted, self.times = write_project(self.root)

    def tearDown(self):
        self.tmp.cleanup()

    def test_shape(self):
        data = build.build(self.root)
        self.assertEqual(data["schema"], 1)
        (cat,) = data["categories"]
        self.assertEqual((cat["id"], cat["short_title"], cat["title"], cat["subtitle"]),
                         ("cat-samantha-patthana", "Samantha Pattana", "Samantha Pattana Dharma Wandanawa", "TTL"))
        intro, vandana = cat["readings"]
        self.assertEqual((intro["id"], intro["title"], vandana["id"], vandana["title"], vandana["title_roman"]),
                         ("sp-introduction", "Introduction", "sp-vandana", "TTL", "Samantha Pattana Dharma Wandanawa"))
        (section,) = intro["sections"]
        self.assertEqual(section["id"], "p")
        self.assertEqual(section["verses"], [
            {"id": f"intro-{n}", "sinhala": t, "always_shown": True, "check": "needs checking"}
            for n, t in enumerate(["I one", "I two", "I three"], 1)])
        (section,) = vandana["sections"]
        verses = section["verses"]
        self.assertEqual([v["id"] for v in verses], IDS)
        self.assertTrue(all(v["keep_lines"] and v["check"] == "needs checking" for v in verses))
        self.assertEqual(verses[3]["phrases"], [{"pali": "P3q0", "sinhala": "", "english": ""}])
        self.assertEqual(verses[1]["phrases"][1]["pali"], "P1q1")
        self.assertEqual(verses[3]["sinhala"], "S3q0\nS3q1")
        self.assertNotIn("sinhala", verses[1])

    def test_audio_times(self):
        audio = build.build(self.root)["categories"][0]["readings"][1]["audio"]
        self.assertEqual(audio["asset"], "assets/audio/samantha_patthana/hYXyO3o7Iac.m4a")
        self.assertEqual(audio["label"], "Chanted by Ven. Kiriwaththuduwe Ariyadassana Thero")
        self.assertEqual((audio["duration_ms"], audio["bytes"], audio["sha256"]),
                         (2856000, build.RECORDING_BYTES, build.RECORDING_SHA256))
        bt, lt = audio["block_times"], audio["line_times"]
        self.assertEqual(len(bt), 28)
        self.assertEqual(bt[0], [1, 2])  # one line at 1 s; the next unit starts at 2 s
        self.assertEqual(bt[1], [2, 4])
        last = self.times["units"][-1]["lines"][-1]["end_ms"] / 1000
        self.assertEqual(bt[-1][1], last)
        self.assertTrue(all(bt[i][1] == bt[i + 1][0] for i in range(27)))
        self.assertEqual([len(x) for x in lt], [len(u["lines"]) for u in self.times["units"]])
        self.assertEqual(lt[1], [2, 3])

    def test_untimed_units_get_null_lines_but_keep_the_block_time(self):
        audio = build.build(self.root, untimed=("u-homage", "u-list"))["categories"][0]["readings"][1]["audio"]
        self.assertEqual(audio["line_times"][0], [None])
        self.assertEqual(audio["line_times"][2], [None] * 3)
        self.assertEqual(audio["line_times"][1], [2, 3])
        self.assertEqual(audio["block_times"][0], [1, 2])
        self.assertEqual(audio["block_times"][2], [4, 7])
        self.assertTrue(all(isinstance(t, (int, float)) for b in audio["block_times"] for t in b))

    def test_default_untimed_unit_is_the_homage(self):
        self.assertEqual(build.UNTIMED_UNITS, ("u-homage",))
        audio = build.build(self.root)["categories"][0]["readings"][1]["audio"]
        self.assertTrue(all(t is None for t in audio["line_times"][0]))
        self.assertTrue(all(t is not None for lt in audio["line_times"][1:] for t in lt))

    def test_times_with_different_counts_raise(self):
        self.times["units"][4]["lines"].pop()
        (self.root / build.TIMES).write_text(json.dumps(self.times), encoding="utf-8")
        with self.assertRaises(build.BuildError):
            build.build(self.root)

    def test_times_with_different_units_raise(self):
        self.times["units"][4]["id"] = "other"
        (self.root / build.TIMES).write_text(json.dumps(self.times), encoding="utf-8")
        with self.assertRaises(build.BuildError):
            build.build(self.root)

    def test_wrong_duration_raises(self):
        self.times["duration_ms"] = 5
        (self.root / build.TIMES).write_text(json.dumps(self.times), encoding="utf-8")
        with self.assertRaises(build.BuildError):
            build.build(self.root)

    def test_correction_applies_to_every_line_and_a_wrong_count_raises(self):
        # "q" occurs once in each of the 28 units' first Pali line and so on; count them from the fixture.
        total = sum(e["text"].count("q0") for u in self.extracted["units"] for k in ("pali", "sinhala") for e in u[k])
        rows = [("q0", "Z0", total, "test")]
        data = build.build(self.root, corrections=rows)
        verses = data["categories"][0]["readings"][1]["sections"][0]["verses"]
        self.assertEqual(verses[3]["phrases"][0]["pali"], "P3Z0")
        self.assertEqual(verses[3]["sinhala"], "S3Z0\nS3q1")
        self.assertEqual(data["categories"][0]["readings"][1]["sections"][0]["corrections"][0]["count"], total)
        with self.assertRaises(build.BuildError):
            build.build(self.root, corrections=[("q0", "Z0", total + 1, "test")])

    def test_no_corrections_by_default(self):
        self.assertEqual(build.CORRECTIONS, [])


class CheckAndImportTest(unittest.TestCase):
    """Runs with a tiny stand-in recording whose size and checksum replace the constants."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name) / "project"
        self.root.mkdir()
        write_project(self.root)
        self.original = pathlib.Path(self.tmp.name) / "audio"
        self.original.mkdir()
        self.bytes = b"fake recording bytes"
        (self.original / build.RECORDING).write_bytes(self.bytes)
        import hashlib
        self.saved = (build.RECORDING_BYTES, build.RECORDING_SHA256)
        build.RECORDING_BYTES = len(self.bytes)
        build.RECORDING_SHA256 = hashlib.sha256(self.bytes).hexdigest()

    def tearDown(self):
        build.RECORDING_BYTES, build.RECORDING_SHA256 = self.saved
        self.tmp.cleanup()

    def ready(self):
        build.import_audio(self.root, self.original)
        (self.root / build.ASSET).parent.mkdir(parents=True)
        (self.root / build.ASSET).write_bytes(build.render(build.build(self.root)).encode("utf-8"))

    def check(self):
        return build._check(self.root, build.render(build.build(self.root)))

    def test_up_to_date(self):
        self.ready()
        self.assertIsNone(self.check())

    def test_changed_asset_fails(self):
        self.ready()
        (self.root / build.ASSET).write_text("{}", encoding="utf-8")
        self.assertIn("out of date", self.check())

    def test_missing_asset_fails(self):
        build.import_audio(self.root, self.original)
        self.assertIn("out of date", self.check())

    def test_recording_of_wrong_size_fails(self):
        self.ready()
        (self.root / build.AUDIO_DIR / build.RECORDING).write_bytes(self.bytes + b"x")
        self.assertIn("differs from the original", self.check())

    def test_recording_of_wrong_checksum_fails(self):
        self.ready()
        (self.root / build.AUDIO_DIR / build.RECORDING).write_bytes(b"x" * len(self.bytes))
        self.assertIn("differs from the original", self.check())

    def test_extra_file_fails(self):
        self.ready()
        (self.root / build.AUDIO_DIR / "extra.m4a").write_bytes(b"x")
        self.assertIn("extra.m4a", self.check())

    def test_import_copies_byte_for_byte(self):
        build.import_audio(self.root, self.original)
        self.assertEqual((self.root / build.AUDIO_DIR / build.RECORDING).read_bytes(), self.bytes)

    def test_import_refuses_wrong_size(self):
        (self.original / build.RECORDING).write_bytes(self.bytes + b"x")
        with self.assertRaises(build.BuildError):
            build.import_audio(self.root, self.original)
        self.assertFalse((self.root / build.AUDIO_DIR / build.RECORDING).exists())


class CommittedAssetTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = ASSET.read_text(encoding="utf-8")
        cls.data = json.loads(cls.text)

    def test_counts(self):
        vandana = self.data["categories"][0]["readings"][1]
        verses = vandana["sections"][0]["verses"]
        self.assertEqual(len(verses), 28)
        self.assertEqual(sum(len(v["phrases"]) for v in verses), 507)
        self.assertEqual(sum(len(v["sinhala"].split("\n")) for v in verses if "sinhala" in v), 385)
        self.assertEqual([len(x) for x in vandana["audio"]["line_times"]], [len(v["phrases"]) for v in verses])
        self.assertEqual(len(vandana["audio"]["block_times"]), 28)

    def test_is_what_the_tool_builds_from_the_tracked_files(self):
        self.assertEqual(build.render(build.build(ROOT)), self.text)

    def test_recording_is_the_original(self):
        self.assertIsNone(build._check(ROOT, self.text))

    def test_picture_is_a_byte_copy_of_the_design_image(self):
        self.assertEqual(PICTURE.read_bytes(), (ROOT / "design" / "card_images" / "stupa_dusk.jpg").read_bytes())


SRC = os.environ.get("SAMANTHA_PATTHANA_SRC")


@unittest.skipUnless(SRC and pathlib.Path(SRC).is_dir(),
                     "SAMANTHA_PATTHANA_SRC is not set to the source folder, so the pages are not compared")
class AgainstSourceTest(unittest.TestCase):
    def test_every_line_matches_its_page_and_file_is_current(self):
        src = pathlib.Path(SRC)
        data = json.loads(EXTRACTED.read_text(encoding="utf-8"))
        for u in data["units"]:
            for e in u["pali"] + u["sinhala"]:
                page = (src / "converted" / "pages" / f"page-{e['page']:02d}.txt").read_text(encoding="utf-8")
                self.assertEqual(page.split("\n")[e["line"] - 1], e["text"])
        self.assertEqual(build.render(build.extract(src)), EXTRACTED.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
