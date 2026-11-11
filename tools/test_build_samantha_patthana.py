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
