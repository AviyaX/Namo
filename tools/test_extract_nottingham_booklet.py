"""Tests for extract_nottingham_booklet.py (synthetic page data; the last test needs the real PDF)."""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import extract_nottingham_booklet as ex  # noqa: E402

PDF = os.path.join(HERE, "..", "source_material", "evening_puja_nottingham", "evening_puja_and_chanting.pdf")

FM = "FMBindumathix"


def span(font, size, text, x=0.0, flags=None):
    if flags is None:
        flags = 16 if "Bold" in font else 4 if font.startswith("FM") else 0
    return {"x": x, "font": font, "size": size, "flags": flags, "text": text}


def line(kind, text, **extra):
    return {"kind": kind, "text": text, **extra}


class MergeAndText(unittest.TestCase):
    def test_merge_baselines_joins_justified_words(self):
        rows = [{"y": 391.3, "spans": [span("Calibri-Bold", 18, "paccayā", x=150)]},
                {"y": 391.3, "spans": [span("Calibri-Bold", 18, "nāma-rūpan,", x=240)]},
                {"y": 391.3, "spans": [span("Calibri-Bold", 18, "Viññāṇa", x=70)]}]
        merged = ex.merge_baselines(rows)
        self.assertEqual(len(merged), 1)
        self.assertEqual([s["text"] for s in merged[0]["spans"]], ["Viññāṇa", "paccayā", "nāma-rūpan,"])

    def test_line_text_converts_fm_and_joins_without_spaces(self):
        self.assertEqual(ex.line_text([span(FM, 19, "nqoaOx kudñ")]), "බුද්ධං නමාමි")
        self.assertEqual(ex.line_text([span(FM, 19, "b;sm s fida")]), "ඉතිපි සෝ")
        self.assertEqual(ex.line_text([span("Calibri-Bold", 17, "Buddhan namāmi")]), "Buddhan namāmi")


class Classify(unittest.TestCase):
    def test_classify_each_kind(self):
        self.assertEqual(ex.classify([span(FM, 19, "nqoaOx kudñ")], "බුද්ධං නමාමි"), "pali_si")
        self.assertEqual(ex.classify([span("Calibri-Bold", 17, "Buddhan namāmi")], "Buddhan namāmi"), "roman")
        self.assertEqual(ex.classify([span("Calibri", 12, "Homage to the Buddha")], "Homage to the Buddha"),
                         "english")
        self.assertEqual(ex.classify([span("Calibri-Bold", 16, "(Bow)")], "(Bow)"), "note")
        self.assertEqual(ex.classify([span(FM, 20, "f;rejka")], "x"), "heading")
        self.assertEqual(ex.classify([span(FM, 19, "f;rejka"), span("Calibri-BoldItalic", 15, "Flowers", flags=18)],
                                     "x Flowers"), "subheading")
        self.assertEqual(ex.classify([], ""), "break")

    def test_english_title_is_a_heading(self):
        self.assertEqual(ex.classify([span("Calibri-Bold", 18, "BOWING TO THE TRIPLE GEM")],
                                     "BOWING TO THE TRIPLE GEM"), "heading")

    def test_unrecognised_is_other(self):
        self.assertEqual(ex.classify([span("Calibri-Italic", 26, "Sādu! Sādu! Sādu!", flags=2)],
                                     "Sādu! Sādu! Sādu!"), "other")


class Lines(unittest.TestCase):
    def test_page_numbers_and_digit_marks_are_dropped(self):
        rows = [{"y": 785.0, "spans": [span("Calibri", 11, "3 ")]},
                {"y": 124.1, "spans": [span(FM, 11, "1 ")]}]
        self.assertEqual(ex.build_lines(rows, []), [])

    def test_note_beside_roman_becomes_its_own_line(self):
        rows = [{"y": 175.0, "spans": [span("Calibri-Bold", 17, "Buddhan namāmi      ", x=70)]},
                {"y": 175.0, "spans": [span("Calibri-Bold", 16, "(Bow)", x=400)]}]
        got = ex.build_lines(rows, [])
        self.assertEqual([(g["kind"], g["text"]) for g in got], [("roman", "Buddhan namāmi"), ("note", "(Bow)")])

    def test_english_title_attaches_to_the_sinhala_heading(self):
        rows = [{"y": 73.2, "spans": [span(FM, 20, "f;rejka kuialdr")]},
                {"y": 96.7, "spans": [span("Calibri-Bold", 18, "BOWING TO THE TRIPLE GEM")]}]
        got = ex.build_lines(rows, [])
        self.assertEqual(len(got), 1)
        self.assertEqual(got[0]["kind"], "heading")
        self.assertEqual(got[0]["heading_en"], "BOWING TO THE TRIPLE GEM")


class TitleRule(unittest.TestCase):
    def _page(self, *rows):
        return ex.build_lines([{"y": 100.0 + 30 * i, "spans": sp} for i, sp in enumerate(rows)], [])

    def test_pali_line_before_english_title_is_a_heading(self):
        got = self._page([span(FM, 19, "iqÆ")], [span("Calibri-BoldItalic", 15, "Sharing merits.")],
                         [span(FM, 19, "idOq")], [span("Calibri-Bold", 18, "Idan me")])
        self.assertEqual([g["kind"] for g in got], ["heading", "pali_si", "roman"])
        self.assertEqual(got[0]["heading_en"], "Sharing merits.")

    def test_title_rule_leaves_a_pali_roman_pair_alone(self):
        got = self._page([span(FM, 19, "idOq")], [span("Calibri-Bold", 18, "Idan me")],
                         [span("Calibri", 12, "Homage")])
        self.assertEqual([g["kind"] for g in got], ["pali_si", "roman", "english"])


class Units(unittest.TestCase):
    def test_units_split_at_each_pali_run(self):
        lines = [line("pali_si", "a"), line("pali_si", "b"), line("roman", "r"), line("english", "e"),
                 line("pali_si", "c"), line("roman", "r2"), line("english", "e2")]
        units = ex.units_of(lines)
        self.assertEqual([len(u["pali_si"]) for u in units], [2, 1])
        self.assertEqual([u["index"] for u in units], [0, 1])
        self.assertEqual(units[1]["roman"], ["r2"])

    def test_units_heading_starts_a_unit(self):
        units = ex.units_of([line("heading", "H"), line("pali_si", "a"), line("roman", "r"), line("english", "e")])
        self.assertEqual(len(units), 2)
        self.assertEqual(units[0]["heading"], "H")
        self.assertEqual(units[0]["pali_si"], [])
        self.assertIsNone(units[1]["heading"])

    def test_roman_without_unit_opens_one(self):
        units = ex.units_of([line("roman", "r"), line("english", "e"), line("note", "(n)"), line("break", "")])
        self.assertEqual(len(units), 1)
        self.assertEqual(units[0]["notes"], ["(n)"])


class RealPdf(unittest.TestCase):
    @unittest.skipUnless(os.path.exists(PDF), "booklet PDF not present")
    def test_real_pdf_page_3(self):
        data = ex.extract(PDF)
        self.assertEqual(data["conversion_problems"], [])
        units = data["pages"][2]["units"]
        self.assertTrue(any(u["pali_si"] == ["බුද්ධං නමාමි"] and u["roman"] == ["Buddhan namāmi"]
                            and u["english"] == ["Homage to the Buddha"] and u["notes"] == ["(Bow)"]
                            for u in units))


if __name__ == "__main__":
    unittest.main()
