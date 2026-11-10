"""Tests for tools/build_content.py.

Run: python -I -X utf8 tools/test_build_content.py
(-I leaves this folder off the import path, so the build script is loaded by file path.)
"""
import importlib.util
import json
import pathlib
import re
import subprocess
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
_SPEC = importlib.util.spec_from_file_location("build_content", ROOT / "tools" / "build_content.py")
build_content = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(build_content)

ASSET = ROOT / "assets" / "content" / "namaskaraya_to_pin_dima.json"

# The 19 headings, copied from the table in §5.1 of the design.
HEADINGS = ['නමස්කාරය', 'තිසරණ සරණයාම', 'පංචශීලය සමාදන්වීම', 'බුදු ගුණ සිහි කිරීම', 'දහම් වැඳීම',
            'සඟුන් වැඳීම', 'චෛත්‍ය වන්දනාව', 'බෝධි වන්දනාව', 'බුද්ධ පූජා ආරාධනාව', 'පහන් පූජාව',
            'සුවඳ දුම් පූජාව', 'මල් පූජාව', 'පැන් පූජාව', 'ආහාර පූජාව', 'ගිලන්පස පූජාව', 'දැහැත් පූජාව',
            'සියල්ල එකවිට පූජා කිරීම', 'දෙවියන්ට පින් දීම', 'තෙරුවන් සමාකර ගැනීම']
VERSES = [1, 1, 1, 1, 1, 1, 1, 3, 1, 1, 2, 2, 1, 1, 1, 1, 1, 4, 3]
NO_ENGLISH = {"s08-v3", "s09-v1", "s14-v1", "s16-v1", "s17-v1", "s18-v2", "s18-v3"}
BRISBANE = {"s07-v1", "s08-v1", "s08-v2", "s10-v1", "s11-v1", "s11-v2", "s12-v1", "s12-v2",
            "s13-v1", "s15-v1", "s18-v1"}
NEEDS = {"s11-v1", "s12-v2", "s18-v4", "s19-v3"}
EXPLANATION = {"s04-v1", "s05-v1", "s06-v1"}
# The rows of §5.3: printed form -> number of places.
NAMO_COUNTS = {'ගච්චාමි': 9, 'විඡ්ඡාචරණ': 1, 'සමාදියාමී': 4, 'සුමාමේරය': 1, 'ධානේසු': 1,
               'අධිවාසේ තුනෝ': 1, 'බෝදි': 1}
BOOKLET_COUNTS = {'රුස්කර': 3, 'පුණ්ය': 3, 'භූතයා්': 1, 'ම විසින්': 3, 'සාසණ': 1,
                  'පුංඤ්ඤකෙත්තං': 1, 'අනුත්ථරං': 1, 'දේවානාගා': 3}
COUNTS = {**NAMO_COUNTS, **BOOKLET_COUNTS}


class BuildContentTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = build_content.build(ROOT)
        cls.sections = cls.data["categories"][0]["readings"][0]["sections"]
        cls.verses = [v for s in cls.sections for v in s["verses"]]

    def section_text(self, numbers):
        return "\n".join(v[field] for s in self.sections if s["number"] in numbers
                         for v in s["verses"] for field in ("pali_si", "sinhala"))

    def test_sections(self):
        self.assertEqual([s["heading"] for s in self.sections], HEADINGS)
        self.assertEqual([s["number"] for s in self.sections], list(range(1, 20)))
        self.assertEqual([s["id"] for s in self.sections], [f"s{n:02d}" for n in range(1, 20)])

    def test_verse_counts(self):
        self.assertEqual([len(s["verses"]) for s in self.sections], VERSES)
        self.assertEqual(len(self.verses), 28)

    def test_english_presence(self):
        self.assertEqual({v["id"] for v in self.verses if v["english"] is None}, NO_ENGLISH)
        self.assertEqual({v["id"] for v in self.verses if v["english_source"] is None}, NO_ENGLISH)
        self.assertEqual({v["id"] for v in self.verses if v["english_kind"] is None}, NO_ENGLISH)

    def test_english_sources(self):
        with_english = [v for v in self.verses if v["english"] is not None]
        brisbane = {v["id"] for v in with_english if "Cynthia Gunawardana" in v["english_source"]["translator"]}
        self.assertEqual(brisbane, BRISBANE)
        mahamevnawa = [v for v in with_english if v["id"] not in BRISBANE]
        self.assertEqual(len(mahamevnawa), 10)
        for v in mahamevnawa:
            self.assertIn("Mahamevnawa", v["english_source"]["name"], v["id"])
            self.assertEqual(v["english_source"]["translator"], "not named by the source", v["id"])

    def test_english_kind(self):
        self.assertEqual({v["id"] for v in self.verses if v["english_kind"] == "explanation"}, EXPLANATION)
        others = {v["english_kind"] for v in self.verses if v["english"] is not None and v["id"] not in EXPLANATION}
        self.assertEqual(others, {"translation"})

    def test_anchors(self):
        by_id = {v["id"]: v for v in self.verses}
        self.assertTrue(by_id["s01-v1"]["english"].startswith("Homage to the Blissful One"))
        self.assertTrue(by_id["s07-v1"]["english"].startswith("I salute every chetiya"))
        self.assertTrue(by_id["s18-v1"]["english"].startswith("May all devas share this merit"))
        self.assertTrue(by_id["s19-v3"]["english"].endswith("Practising well and supreme."))

    def test_no_roman_pali(self):
        self.assertEqual(len(self.verses), 28)
        for v in self.verses:
            self.assertIsNone(v["pali_roman"], v["id"])

    def test_pali_and_sinhala_everywhere(self):
        for v in self.verses:
            self.assertTrue(v["pali_si"].strip(), v["id"])
            self.assertTrue(v["sinhala"].strip(), v["id"])

    def test_stanzas(self):
        by_id = {v["id"]: v for v in self.verses}
        self.assertEqual(len(by_id["s18-v4"]["pali_si"].split("\n\n")), 3)
        self.assertEqual(len(by_id["s18-v4"]["english"].split("\n\n")), 3)
        self.assertTrue(by_id["s17-v1"]["sinhala"].endswith("\n\nසාධූ! සාධූ! සාධූ!"))

    def test_corrections_are_the_listed_ones(self):
        totals = {}
        for v in self.verses:
            for c in v["corrections"]:
                totals[c["from"]] = totals.get(c["from"], 0) + c["count"]
        self.assertEqual(totals, COUNTS)

    def test_printed_slips_are_gone(self):
        namo_text = self.section_text(range(1, 18))
        booklet_text = self.section_text({18, 19})
        for form in NAMO_COUNTS:
            self.assertNotIn(form, namo_text)
        for form in BOOKLET_COUNTS:
            self.assertNotIn(form, booklet_text)

    def test_needs_checking(self):
        self.assertEqual({v["id"] for v in self.verses if v["check"] == "needs checking"}, NEEDS)
        for v in self.verses:
            if v["id"] in NEEDS:
                self.assertGreaterEqual(len(v["notes"]), 1, v["id"])
            else:
                self.assertEqual(v["check"], "checked against source", v["id"])
        for s in self.sections:
            expected = "needs checking" if any(v["id"] in NEEDS for v in s["verses"]) else "checked against source"
            self.assertEqual(s["check"], expected, s["id"])

    def english(self, verse_id):
        return {v["id"]: v for v in self.verses}[verse_id]["english"]

    def test_reflow_short_sections(self):
        line = "Homage to the Blissful One, the Worthy One, the Fully Enlightened One."
        self.assertEqual(self.english("s01-v1").split("\n"), [line] * 3)
        self.assertEqual(len(self.english("s02-v1").split("\n")), 11)
        lines = self.english("s03-v1").split("\n")
        self.assertEqual(len(lines), 5)
        self.assertEqual(lines[0], "I undertake the training rule to abstain from killing living beings.")
        self.assertEqual(lines[-1], "I undertake the training rule to abstain from intoxicants and harmful drugs.")

    def test_reflow_explanations(self):
        s04 = self.english("s04-v1").split("\n")
        self.assertEqual(len(s04), 10)
        self.assertEqual(s04[0], "Such indeed is the Blessed One:")
        self.assertEqual(s04[1], '"Araham" - eradicated greed, hatred, delusion, craving, and is free of all taints.')
        self.assertTrue(all(ln.startswith('"') for ln in s04[1:]))
        s05 = self.english("s05-v1").split("\n")
        self.assertEqual(len(s05), 6)
        self.assertTrue(all(ln.startswith('"') for ln in s05))
        s06 = self.english("s06-v1").split("\n")
        self.assertEqual(len(s06), 5)
        self.assertEqual(s06[2], '"Nayapatipanno" - The Noble Order understands the First Noble Truth '
                                 'and are practising to eradicate suffering')
        self.assertTrue(s06[4].startswith("In Buddha’s Order are the 8 kinds of individuals:"))
        self.assertIn("the position of Once-Returner, the Once-Returner; the one striving to reach "
                      "the Non- returner position", s06[4])

    def test_verse_english_keeps_its_lines(self):
        base = self.baseline()
        for verse_id in ("s07-v1", "s08-v1", "s10-v1", "s18-v4", "s19-v1"):
            self.assertEqual(self.english(verse_id), base[verse_id], verse_id)

    def test_footnote_is_one_line(self):
        self.assertTrue(self.english("s15-v1").endswith(
            "\n\n(Gilan pasa – permissible food & drinks for Buddhist monks and nuns from noon to the "
            "following morning such as fruit juices, sugar candy)"))
        self.assertEqual(len(self.english("s15-v1").split("\n")), 6)

    def baseline(self, field="english"):
        """Every verse's `field` from the content file committed at a448a3c, before the reflow."""
        raw = subprocess.run(["git", "show", "a448a3c:assets/content/namaskaraya_to_pin_dima.json"],
                             cwd=ROOT, check=True, capture_output=True).stdout
        data = json.loads(raw.decode("utf-8"))
        return {v["id"]: v[field] for s in data["categories"][0]["readings"][0]["sections"]
                for v in s["verses"]}

    def test_reflow_changes_only_whitespace(self):
        base = self.baseline()
        checked = 0
        for v in self.verses:
            if v["english"] is None:
                self.assertIsNone(base[v["id"]], v["id"])
                continue
            checked += 1
            self.assertEqual(re.sub(r"\s+", "", v["english"]), re.sub(r"\s+", "", base[v["id"]]), v["id"])
        self.assertEqual(checked, 21)

    def test_pali_and_sinhala_unchanged(self):
        for field in ("pali_si", "sinhala"):
            base = self.baseline(field)
            for v in self.verses:
                self.assertEqual(v[field], base[v["id"]], v["id"])

    def test_reflow_function(self):
        reflow = build_content._reflow_prose
        self.assertEqual(reflow('A b\nc.\nd e\n\nf\n"g" h-\ni j'), 'A b c.\nd e\n\nf\n"g" h-i j')
        with self.assertRaises(build_content.BuildError):
            build_content._check_whitespace_only("a b", "a c")

    def test_nothing_from_outside(self):
        rendered = build_content.render(self.data).decode("utf-8")
        self.assertNotIn("Related Resources", rendered)
        self.assertNotIn("With Devas", rendered)
        for s in self.sections:
            self.assertFalse(s["heading"][:1].isdigit(), s["heading"])

    def test_file_is_reproducible(self):
        first = build_content.render(build_content.build(ROOT))
        second = build_content.render(build_content.build(ROOT))
        self.assertEqual(first, second)
        self.assertEqual(first, ASSET.read_bytes())


if __name__ == "__main__":
    unittest.main()
