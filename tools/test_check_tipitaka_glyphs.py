"""Tests for tools/check_tipitaka_glyphs.py.

Run: python -I -X utf8 tools/test_check_tipitaka_glyphs.py
"""
import gzip
import hashlib
import importlib.util
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
TOOL = ROOT / "tools" / "check_tipitaka_glyphs.py"
FONTS = ROOT / "assets" / "fonts"
BOX = "\U0010FFFD"  # private-use plane 16: in none of the fonts


def write_gz(path, obj):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(gzip.compress(json.dumps(obj, ensure_ascii=False).encode("utf-8")))


def make_project(root, tree, books):
    (root / "assets" / "fonts").mkdir(parents=True)
    for name in ("NotoSansSinhala.ttf", "NotoSerif.ttf", "Lora.ttf"):
        shutil.copy(FONTS / name, root / "assets" / "fonts" / name)
    write_gz(root / "assets" / "tipitaka" / "tree.json.gz", tree)
    for name, pages in books.items():
        write_gz(root / "assets" / "tipitaka" / "text" / f"{name}.json.gz", {"pages": pages})


def page(text="abc", foot=None):
    side = {"entries": [{"type": "paragraph", "text": text}], "footnotes": foot or []}
    return {"pali": side, "sinh": {"entries": [], "footnotes": []}}


def run(root):
    return subprocess.run([sys.executable, "-I", "-X", "utf8", str(TOOL), str(root)],
                          capture_output=True, text=True, encoding="utf-8")


def digest(root):
    h = hashlib.sha256()
    for p in sorted((root / "assets").rglob("*")):
        if p.is_file():
            h.update(p.relative_to(root).as_posix().encode() + p.read_bytes())
    return h.hexdigest()


class GlyphReport(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self._tmp.name)
        self.addCleanup(self._tmp.cleanup)

    def test_drawable_characters_pass(self):
        make_project(self.root, {"k": ["abc", "ශ්‍රී", 1, [0, 0], "root", "b-1"]},
                     {"b-1": [page("hello world ශ")]})
        r = run(self.root)
        self.assertEqual((r.returncode, r.stdout.strip()), (0, "OK"), r.stdout + r.stderr)

    def test_missing_character_reported_with_count_and_first_file(self):
        make_project(self.root, {"k": ["abc", "def", 1, [0, 0], "root", "a-1"]},
                     {"a-1": [page("x" + BOX)], "b-1": [page(BOX + BOX, foot=[{"text": BOX}, BOX])]})
        r = run(self.root)
        self.assertEqual(r.returncode, 1, r.stdout)
        lines = r.stdout.strip().splitlines()
        self.assertEqual(len(lines), 1, r.stdout)
        self.assertTrue(lines[0].startswith("U+10FFFD "), lines[0])
        self.assertIn("count=5", lines[0])
        self.assertTrue(lines[0].endswith("first=text/a-1.json.gz"), lines[0])

    def test_tree_names_are_checked_but_atta_and_anya_are_not(self):
        make_project(self.root, {"k": [BOX, "ok", 1, [0, 0], "root", "a-1"],
                                 "atta1": [BOX, BOX, 1, [0, 0], "root", "a-1"],
                                 "anya2": ["ok", BOX, 1, [0, 0], "root", "a-1"]},
                     {"a-1": [page()]})
        r = run(self.root)
        self.assertIn("count=1", r.stdout)
        self.assertIn("first=tree.json.gz", r.stdout)

    def test_allow_listed_characters_not_reported(self):
        allowed = "\n\r\t​‌‍﻿­"
        make_project(self.root, {"k": ["abc", "def", 1, [0, 0], "root", "a-1"]},
                     {"a-1": [page("a" + allowed + "b")]})
        r = run(self.root)
        self.assertEqual((r.returncode, r.stdout.strip()), (0, "OK"), r.stdout)

    def test_assets_untouched(self):
        make_project(self.root, {"k": ["abc", BOX, 1, [0, 0], "root", "a-1"]}, {"a-1": [page(BOX)]})
        before = digest(self.root)
        run(self.root)
        self.assertEqual(before, digest(self.root))


if __name__ == "__main__":
    unittest.main()
