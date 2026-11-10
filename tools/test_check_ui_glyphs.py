"""Tests for tools/check_ui_glyphs.py.

Run: python -I -X utf8 tools/test_check_ui_glyphs.py
(-I leaves this folder off the import path, so the tool is loaded by file path.)
"""
import importlib.util
import pathlib
import subprocess
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
_SPEC = importlib.util.spec_from_file_location("check_ui_glyphs", ROOT / "tools" / "check_ui_glyphs.py")
tool = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(tool)

FONTS = ROOT / "assets" / "fonts"


def strings(source):
    return [text for _, text in tool.extract_strings(source)]


class ExtractStrings(unittest.TestCase):
    def test_single_and_double_quoted(self):
        self.assertEqual(strings("""final a = 'one'; final b = "two";"""), ["one", "two"])

    def test_the_other_quote_inside_a_string(self):
        self.assertEqual(strings("""final a = "it's"; final b = 'say "hi"';"""), ["it's", 'say "hi"'])

    def test_imports_and_exports_are_skipped(self):
        src = "import 'package:flutter/material.dart';\nexport 'a.dart';\npart 'b.g.dart';\nfinal a = 'shown';"
        self.assertEqual(strings(src), ["shown"])

    def test_keys_are_skipped(self):
        src = "const ValueKey('screen-home'); Key( 'k' ); Text('Home');"
        self.assertEqual(strings(src), ["Home"])

    def test_comments_are_skipped(self):
        src = "// 'not this'\n/* 'nor this' */\nfinal a = 'this';"
        self.assertEqual(strings(src), ["this"])

    def test_escapes_are_decoded(self):
        self.assertEqual(strings(r"final a = 'it’s \u{2014} \n';"), ["it’s — \n"])

    def test_interpolation_is_code_not_text(self):
        self.assertEqual(strings("final a = 'Section $n of ${list.length} done';"), ["Section  of  done"])

    def test_raw_and_triple_quoted(self):
        src = "final a = r'\\n$x'; final b = '''two\nlines''';"
        self.assertEqual(strings(src), ["\\n$x", "two\nlines"])

    def test_line_numbers(self):
        self.assertEqual(tool.extract_strings("a\n\nfinal x = 'y';"), [(3, "y")])


class Cmap(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.label = tool.font_codepoints(FONTS / tool.LABEL_FONT)
        cls.fallback = tool.font_codepoints(FONTS / tool.FALLBACK_FONT)

    def test_letters_and_sinhala_are_in_the_label_font(self):
        for ch in "Aa z.,0":
            self.assertIn(ord(ch), self.label, ch)
        self.assertIn(0x0DB4, self.label)  # a Sinhala letter

    def test_a_character_the_font_lacks_is_reported(self):
        self.assertNotIn(0x1E6D, self.label)
        self.assertEqual(tool.missing_characters("aṭaṭ", self.label), ["ṭ"])

    def test_nothing_is_reported_for_covered_text(self):
        self.assertEqual(tool.missing_characters("Go to Home", self.label), [])


class PirithNames(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sinhala = tool.font_codepoints(FONTS / tool.LABEL_FONT)
        cls.roman = tool.font_codepoints(FONTS / tool.ROMAN_FONT)

    def test_all_39_names_are_covered(self):
        import json

        data = json.loads((ROOT / tool.PIRITH).read_text(encoding="utf-8"))
        readings = [r for c in data["categories"] for r in c["readings"]]
        self.assertEqual(len(readings), 39)
        self.assertEqual(tool.pirith_missing(ROOT, self.sinhala, self.roman), [])

    def test_a_missing_glyph_is_named_with_pirith_and_character(self):
        import json
        import tempfile

        with tempfile.TemporaryDirectory() as d:
            root = pathlib.Path(d)
            (root / "assets" / "content").mkdir(parents=True)
            (root / tool.PIRITH).write_text(
                json.dumps({"categories": [{"readings": [
                    {"id": "pirith-x", "title": "මහා", "title_roman": "Maṭa中"},
                ]}]}),
                encoding="utf-8",
            )
            bad = tool.pirith_missing(root, self.sinhala, self.roman)
        self.assertIn(("pirith-x", "title_roman", "中"), bad)
        self.assertTrue(all(b[0] == "pirith-x" for b in bad))


class RealProject(unittest.TestCase):
    def test_the_project_run_exits_zero(self):
        run = subprocess.run(
            [sys.executable, "-I", "-X", "utf8", str(ROOT / "tools" / "check_ui_glyphs.py"), str(ROOT)],
            capture_output=True,
            text=True,
            encoding="utf-8",
        )
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)


if __name__ == "__main__":
    unittest.main()
