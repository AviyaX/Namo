"""Tests for tools/build_pirith.py.

Run: python -I -X utf8 tools/test_build_pirith.py
(-I leaves this folder off the import path, so the build script is loaded by file path.)
Hand-made data uses placeholders such as "A1"; real text is only read from the extracted file.
"""
import hashlib
import re
import shutil
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
    return {"id": item_id, "number": number, "title_si": "T-" + item_id, "chanter": "c1",
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
    names = {i["id"].split("-", 1)[0]: "Name " + i["id"].split("-", 1)[0] for i in items if i["blocks"]}
    (root / "content" / "pirith_names_en.json").write_text(json.dumps(names), encoding="utf-8")
    (root / "assets" / "audio" / "pirith").mkdir(parents=True)
    for name, content in audios.items():
        (root / "assets" / "audio" / "pirith" / f"{name}.m4a").write_bytes(content)
    return tmp, root


FIRST3 = ("08-mahamangala", "09-rathana", "10-karaniya")


def small_tree():
    one = [block(1, 1.5, 3.0, ["a1", "a2"]), block(2, None, 5.0, ["b1"]), block(3, 6.0, None, ["c1"])]
    two = [block(1, 0.0, 1.0, ["d1"])]
    items = [item("05-a", 1, one), item("06-empty", 2, []), item("08-mahamangala", 3, two),
             item("09-rathana", 4, two), item("10-karaniya", 5, two), item("11-b", 6, two)]
    return tree(items, {i["id"]: b"abcdef" for i in items if i["blocks"]})


def run_cli(root, *args):
    return subprocess.run([sys.executable, "-I", "-X", "utf8", str(SCRIPT), str(root), *args],
                          capture_output=True, text=True, encoding="utf-8")


class SmallBuildTest(unittest.TestCase):
    def setUp(self):
        self.tmp, self.root = small_tree()
        self.data = build_pirith.build(self.root)
        self.readings = self.data["categories"][0]["readings"]
        self.by_id = {r["id"]: r for r in self.readings}

    def tearDown(self):
        self.tmp.cleanup()

    def test_empty_item_left_out_and_chosen_ones_first(self):
        self.assertEqual([r["id"] for r in self.readings],
                         ["pirith-08-mahamangala", "pirith-09-rathana", "pirith-10-karaniya",
                          "pirith-05-a", "pirith-11-b"])

    def test_missing_first_item_fails(self):
        with self.assertRaises(build_pirith.BuildError) as ctx:
            build_pirith.build(self.root, first=("99-nope",))
        self.assertIn("99-nope", str(ctx.exception))

    def test_roman_name_from_table(self):
        self.assertEqual(self.by_id["pirith-05-a"]["title_roman"], "Name 05")

    def test_block_times(self):
        r = self.by_id["pirith-05-a"]
        audio = r["audio"]
        self.assertEqual(audio["block_times"], [[1.5, 3.0], None, None])
        self.assertEqual(len(audio["block_times"]), len(r["sections"][0]["verses"]))
        self.assertEqual(audio["duration_ms"], 101000)
        self.assertEqual(audio["bytes"], 6)
        self.assertEqual(audio["sha256"], hashlib.sha256(b"abcdef").hexdigest())
        self.assertEqual(audio["label"], "Chanted by Ven. Test Thero")

    def test_phrases_keep_order_and_strings(self):
        verses = self.by_id["pirith-05-a"]["sections"][0]["verses"]
        self.assertEqual([v["id"] for v in verses], ["b1", "b2", "b3"])
        self.assertEqual(verses[0]["phrases"], [pair("a1"), pair("a2")])

    def test_names_file_positions_and_licence_paragraph(self):
        text = build_pirith.render_names(self.root, self.data).decode("utf-8")
        rows = re.findall(r"^\| (\d+) \| ([^|]+) \|", text, re.M)
        self.assertEqual([int(n) for n, _ in rows], list(range(1, len(self.readings) + 1)))
        self.assertEqual([s.strip() for _, s in rows][:3], list(FIRST3))
        nl = chr(10)
        self.assertIn(nl + nl + "Licence on the source site: ", text)
        self.assertNotIn(nl * 3, text)

    def table_error(self, mutate):
        path = self.root / "content" / "pirith_names_en.json"
        table = json.loads(path.read_text(encoding="utf-8"))
        mutate(table)
        path.write_text(json.dumps(table, ensure_ascii=False), encoding="utf-8")
        with self.assertRaises(build_pirith.BuildError) as ctx:
            build_pirith.build(self.root)
        return str(ctx.exception)

    def test_name_table_problems_fail(self):
        self.assertIn("05", self.table_error(lambda t: t.pop("05")))
        self.assertIn("77", self.table_error(lambda t: t.update({"77": "X", "05": "Name 05"})))
        self.assertIn("'05'", self.table_error(lambda t: t.update({"77": None}) or t.pop("77") or t.update({"05": " "})))
        self.assertIn("'05'", self.table_error(lambda t: t.update({"05": "Sa" + chr(0x101)})))

    def test_check_names_changed_recording(self):
        self.assertEqual(run_cli(self.root).returncode, 0)
        ok = run_cli(self.root, "--check")
        self.assertEqual(ok.returncode, 0, ok.stderr)
        self.assertIn("pirith content is up to date", ok.stdout)
        path = self.root / "assets" / "audio" / "pirith" / "05-a.m4a"
        path.write_bytes(b"abcdeg")
        bad = run_cli(self.root, "--check")
        self.assertNotEqual(bad.returncode, 0)
        self.assertIn("05-a.m4a", bad.stderr)

    def test_check_fails_when_outputs_are_stale(self):
        for rel in ("assets/content/pirith.json", "content/pirith_names.md"):
            with self.subTest(rel=rel):
                self.assertEqual(run_cli(self.root).returncode, 0)
                path = self.root / rel
                path.write_bytes(path.read_bytes() + b" ")
                bad = run_cli(self.root, "--check")
                self.assertNotEqual(bad.returncode, 0)
                self.assertIn(rel, bad.stderr)

    def test_import_refuses_wrong_size(self):
        src = pathlib.Path(self.tmp.name) / "dl"
        src.mkdir()
        for i in self.readings:
            (src / (i["id"][len("pirith-"):] + ".m4a")).write_bytes(b"abcdef")
        (src / "05-a.m4a").write_bytes(b"abc")
        with self.assertRaises(build_pirith.BuildError) as ctx:
            build_pirith.import_audio(self.root, src)
        self.assertIn("05-a.m4a", str(ctx.exception))


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

    def test_order_and_names(self):
        ids = [r["id"] for r in self.readings]
        self.assertEqual([i.split("-", 2)[1] + "-" + i.split("-", 2)[2] for i in ids[:3]], list(FIRST3))
        table = json.loads((ROOT / "content" / "pirith_names_en.json").read_text(encoding="utf-8"))
        self.assertEqual(sorted(table), sorted(i.split("-")[1] for i in ids))
        for r in self.readings:
            self.assertEqual(r["title_roman"], table[r["id"].split("-")[1]])
        text = build_pirith.render_names(ROOT, self.data).decode("utf-8")
        rows = re.findall(r"^\| (\d+) \| ([^|]+) \| [^|]+ \| ([^|]+) \|$", text, re.M)
        self.assertEqual([int(n) for n, _, _ in rows], list(range(1, 40)))
        self.assertEqual([s.strip() for _, s, _ in rows], [i[len("pirith-"):] for i in ids])

    def test_recordings_are_the_originals(self):
        for r in self.readings:
            a = r["audio"]
            data = (ROOT / a["asset"]).read_bytes()
            self.assertEqual((len(data), hashlib.sha256(data).hexdigest()), (a["bytes"], a["sha256"]))
            self.assertEqual(len(a["block_times"]), len(r["sections"][0]["verses"]))


if __name__ == "__main__":
    unittest.main()
