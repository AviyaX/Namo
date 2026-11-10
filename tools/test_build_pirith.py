"""Tests for tools/build_pirith.py.

Run: python -I -X utf8 tools/test_build_pirith.py
(-I leaves this folder off the import path, so the build script is loaded by file path.)
Hand-made data uses placeholders such as "A1"; real text is only read from the extracted file.
"""
import hashlib
import importlib.util
import json
import pathlib
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
_SPEC = importlib.util.spec_from_file_location("build_pirith", ROOT / "tools" / "build_pirith.py")
build_pirith = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(build_pirith)
SCRIPT = ROOT / "tools" / "build_pirith.py"
EXTRACTED = ROOT / "content" / "extracted" / "pitaka_lk_pirith.json"


def pair(tag):
    return {"pali": f"P{tag}", "sinhala": f"S{tag}", "english": f"E{tag}"}


def block(n, start, end, tags):
    return {"n": n, "start": start, "end": end, "pairs": [pair(t) for t in tags]}


def item(item_id, number, blocks, audio=b"abcdef"):
    return {"id": item_id, "number": number, "title_si": "සුත්තං", "chanter": "c1",
            "duration": "1:41", "audio_file": f"{item_id}.m4a", "audio_bytes": len(audio),
            "blocks": blocks}


def tree(items, audios):
    """A temporary project root holding made-up extracted data and recordings."""
    tmp = tempfile.TemporaryDirectory()
    root = pathlib.Path(tmp.name)
    (root / "content" / "extracted").mkdir(parents=True)
    data = {"fetched_utc": "2026-01-02T03:04:05Z",
            "chanters": {"c1": {"name_si": "X", "name_en": "Test Thero"}}, "items": items}
    (root / "content" / "extracted" / "pitaka_lk_pirith.json").write_text(
        json.dumps(data, ensure_ascii=False), encoding="utf-8")
    (root / "assets" / "audio" / "pirith").mkdir(parents=True)
    for name, content in audios.items():
        (root / "assets" / "audio" / "pirith" / f"{name}.m4a").write_bytes(content)
    return tmp, root


class RomaniseTest(unittest.TestCase):
    def test_spec_title(self):
        items = json.loads(EXTRACTED.read_text(encoding="utf-8"))["items"]
        title = next(i for i in items if i["id"] == "08-mahamangala")["title_si"]
        self.assertEqual(build_pirith.romanise(title), "Mahā Maṅgala Suttaṃ")

    def test_unknown_character_raises(self):
        with self.assertRaises(build_pirith.BuildError) as ctx:
            build_pirith.romanise("සුත්තං ?")
        self.assertIn("?", str(ctx.exception))
        self.assertIn("සුත්තං ?", str(ctx.exception))


class SmallBuildTest(unittest.TestCase):
    def setUp(self):
        blocks = [block(1, 1.5, 3.0, ["a1", "a2"]), block(2, None, 5.0, ["b1"]),
                  block(3, 6.0, None, ["c1"])]
        self.tmp, self.root = tree(
            [item("01-x", 1, blocks), item("02-empty", 2, []), item("03-y", 3, [block(1, 0.0, 1.0, ["d1"])])],
            {"01-x": b"abcdef", "03-y": b"abcdef"})
        self.data = build_pirith.build(self.root)
        self.readings = self.data["categories"][0]["readings"]

    def tearDown(self):
        self.tmp.cleanup()

    def test_empty_item_left_out_and_numbers_run_on(self):
        self.assertEqual([r["id"] for r in self.readings], ["pirith-01-x", "pirith-03-y"])
        self.assertEqual([r["sections"][0]["number"] for r in self.readings], [1, 1])

    def test_block_times(self):
        audio = self.readings[0]["audio"]
        self.assertEqual(audio["block_times"], [[1.5, 3.0], None, None])
        self.assertEqual(len(audio["block_times"]), len(self.readings[0]["sections"][0]["verses"]))
        self.assertEqual(audio["duration_ms"], 101000)
        self.assertEqual(audio["bytes"], 6)
        self.assertEqual(audio["sha256"], hashlib.sha256(b"abcdef").hexdigest())
        self.assertEqual(audio["label"], "Chanted by Ven. Test Thero")

    def test_phrases_keep_order_and_strings(self):
        verses = self.readings[0]["sections"][0]["verses"]
        self.assertEqual([v["id"] for v in verses], ["b1", "b2", "b3"])
        self.assertEqual(verses[0]["phrases"], [pair("a1"), pair("a2")])

    def test_check_names_changed_recording(self):
        run = lambda *a: subprocess.run([sys.executable, "-I", "-X", "utf8", str(SCRIPT), str(self.root), *a],
                                        capture_output=True, text=True, encoding="utf-8")
        self.assertEqual(run().returncode, 0)
        ok = run("--check")
        self.assertEqual(ok.returncode, 0, ok.stderr)
        self.assertIn("pirith content is up to date", ok.stdout)
        path = self.root / "assets" / "audio" / "pirith" / "01-x.m4a"
        path.write_bytes(b"abcdeg")
        bad = run("--check")
        self.assertNotEqual(bad.returncode, 0)
        self.assertIn("01-x.m4a", bad.stderr)

    def test_import_refuses_wrong_size(self):
        src = pathlib.Path(self.tmp.name) / "dl"
        src.mkdir()
        (src / "01-x.m4a").write_bytes(b"abc")
        (src / "03-y.m4a").write_bytes(b"abcdef")
        with self.assertRaises(build_pirith.BuildError) as ctx:
            build_pirith.import_audio(self.root, src)
        self.assertIn("01-x.m4a", str(ctx.exception))


class RealDataTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = build_pirith.build(ROOT)
        cls.readings = cls.data["categories"][0]["readings"]

    def test_counts(self):
        verses = [v for r in self.readings for v in r["sections"][0]["verses"]]
        phrases = [p for v in verses for p in v["phrases"]]
        self.assertEqual((len(self.readings), len(verses), len(phrases)), (39, 1157, 5692))

    def test_ids_and_phrases(self):
        for r in self.readings:
            self.assertTrue(r["id"].startswith("pirith-"))
            for v in r["sections"][0]["verses"]:
                for p in v["phrases"]:
                    self.assertEqual(set(p), {"pali", "sinhala", "english"})
                    self.assertTrue(all(p.values()))

    def test_recordings_are_the_originals(self):
        for r in self.readings:
            a = r["audio"]
            data = (ROOT / a["asset"]).read_bytes()
            self.assertEqual((len(data), hashlib.sha256(data).hexdigest()), (a["bytes"], a["sha256"]))
            self.assertEqual(len(a["block_times"]), len(r["sections"][0]["verses"]))


if __name__ == "__main__":
    unittest.main()
