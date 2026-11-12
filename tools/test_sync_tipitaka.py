"""Tests for tools/sync_tipitaka.py.

Run: python -I -X utf8 tools/test_sync_tipitaka.py
(-I leaves this folder off the import path, so the tool is loaded by file path.)
All text below is made-up ASCII; nothing here is Tripitaka text.
"""
import contextlib
import gzip
import hashlib
import importlib.util
import io
import json
import pathlib
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
_SPEC = importlib.util.spec_from_file_location("sync_tipitaka", ROOT / "tools" / "sync_tipitaka.py")
tool = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(tool)


def entry(kind, text):
    return {"type": kind, "text": text}


def page(num, entries):
    return {
        "pageNum": num,
        "pali": {"entries": entries, "footnotes": []},
        "sinh": {"entries": [dict(e) for e in entries], "footnotes": []},
    }


# Flat entries of dn-9: 0 title (no node), 1 sp heading, 2 dn heading,
# 3 dn-1 heading, 4 dn-1 paragraph | 5 leaf heading, 6 leaf text,
# 7 leaf heading, 8 gatha.
BOOK = {
    "filename": "dn-9",
    "pages": [
        page(1, [entry("centered", "TITLE"), entry("heading", "SP"), entry("heading", "DN"),
                 entry("heading", "D1"), entry("paragraph", "own text of d1")]),
        page(2, [entry("heading", "L1"), entry("paragraph", "leaf one"),
                 entry("heading", "L2"), entry("gatha", "leaf two")]),
    ],
}
ATTA = {"filename": "atta-dn-9", "pages": [page(1, [entry("paragraph", "commentary")])]}
TREE = {
    "sp": ["S", "S", 0, [0, 1], "root", "dn-9"],
    "dn": ["D", "D", 1, [0, 2], "sp", "dn-9"],
    "dn-1": ["D1", "D1", 2, [0, 3], "dn", "dn-9"],
    "dn-1-1": ["L1", "L1", 3, [1, 0], "dn-1", "dn-9"],
    "dn-1-2": ["L2", "L2", 3, [1, 2], "dn-1", "dn-9"],
    "atta-dn-1": ["A", "A", 1, [0, 0], "root", "atta-dn-9"],
}


def raw(obj):
    return json.dumps(obj, ensure_ascii=False).encode("utf8")


def run(argv):
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        code = tool.main(argv)
    return code, out.getvalue()


def git_cmd(clone):
    return ["git", "-c", "core.autocrlf=false", "-c", "user.name=t", "-c", "user.email=t@example.com", "-C", str(clone)]


def make_clone(base):
    clone = base / "clone"
    (clone / "public" / "static" / "text").mkdir(parents=True)
    (clone / "public" / "static" / "data").mkdir(parents=True)
    (clone / "public" / "static" / "text" / "dn-9.json").write_bytes(raw(BOOK))
    (clone / "public" / "static" / "text" / "atta-dn-9.json").write_bytes(raw(ATTA))
    (clone / "public" / "static" / "text" / "anya-x.json").write_bytes(raw({"pages": []}))
    (clone / "public" / "static" / "data" / "tree.json").write_bytes(raw(TREE))
    (clone / "LICENSE.md").write_bytes(b"made-up licence\n")
    (clone / "shared").mkdir()
    (clone / "shared" / "markup-cases.json").write_bytes(b'[{"in": "a"}]\n')
    (clone / "e2e" / "legacy" / "goldens").mkdir(parents=True)
    items = [{"lang": "pali", "text": "p%d" % i, "out": {"00": "P%d" % i, "11": "x"}} for i in range(450)]
    items += [{"lang": "sinh", "text": "s%d" % i, "out": {"00": "S%d" % i}} for i in range(50)]
    (clone / "e2e" / "legacy" / "goldens" / "beautify.json").write_bytes(raw(items))
    git = git_cmd(clone)
    subprocess.run(git + ["init", "-q"], check=True)
    subprocess.run(git + ["add", "-A"], check=True)
    subprocess.run(git + ["commit", "-q", "-m", "fixture"], check=True)
    return clone


class Base(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.base = pathlib.Path(self._tmp.name)
        self.clone = make_clone(self.base)
        self.project = self.base / "project"
        self.project.mkdir()
        self.assets = self.project / "assets" / "tipitaka"

    def pack(self):
        code, out = run([str(self.project), "--from", str(self.clone)])
        self.assertEqual(code, 0, out)

    def check(self):
        return run([str(self.project), "--check"])

    def snapshot(self):
        return {str(p.relative_to(self.assets)): p.read_bytes()
                for p in sorted(self.assets.rglob("*")) if p.is_file()}

    def rewrite_gz(self, rel, obj):
        (self.assets / rel).write_bytes(gzip.compress(raw(obj), 9, mtime=0))

    def fix_manifest_hash(self, name, data):
        path = self.assets / "manifest.json"
        m = json.loads(path.read_text(encoding="utf8"))
        m["files"][name] = {"sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data)}
        path.write_text(json.dumps(m), encoding="utf8")


class Pack(Base):
    def test_pack_ships_only_canon_files(self):
        self.pack()
        self.assertEqual([p.name for p in (self.assets / "text").iterdir()], ["dn-9.json.gz"])

    def test_unpacked_bytes_equal_source(self):
        self.pack()
        src = self.clone / "public" / "static"
        self.assertEqual(gzip.decompress((self.assets / "text" / "dn-9.json.gz").read_bytes()),
                         (src / "text" / "dn-9.json").read_bytes())
        self.assertEqual(gzip.decompress((self.assets / "tree.json.gz").read_bytes()),
                         (src / "data" / "tree.json").read_bytes())
        self.assertEqual((self.assets / "LICENSE.md").read_bytes(), b"made-up licence\n")

    def test_gzip_has_no_name_and_no_time(self):
        self.pack()
        head = (self.assets / "text" / "dn-9.json.gz").read_bytes()[:10]
        self.assertEqual(head[3], 0)  # no flags: no file name
        self.assertEqual(head[4:8], b"\0\0\0\0")  # mtime 0

    def test_pack_is_repeatable(self):
        self.pack()
        first = self.snapshot()
        self.pack()
        self.assertEqual(self.snapshot(), first)

    def test_manifest_lists_parents_with_text_and_readings(self):
        self.pack()
        m = json.loads((self.assets / "manifest.json").read_text(encoding="utf8"))
        self.assertEqual(m["schema"], 1)
        self.assertEqual(m["readings"], 3)
        self.assertEqual(m["parentsWithText"], ["dn-1"])
        self.assertEqual(list(m["files"]), ["text/dn-9", "tree"])
        self.assertEqual(m["licence"], "CC BY-ND 4.0")
        self.assertEqual(m["source"], "https://github.com/pathnirvana/tipitaka.lk")
        head = subprocess.run(["git", "-C", str(self.clone), "log", "-1", "--format=%H|%cs"],
                              capture_output=True, text=True, check=True).stdout.strip()
        self.assertEqual((m["commit"], m["commitDate"]), tuple(head.split("|")))
        self.assertEqual(m["files"]["text/dn-9"]["bytes"], len(raw(BOOK)))

    def test_removed_source_file_is_removed_from_assets(self):
        self.pack()
        (self.assets / "text" / "dn-8.json.gz").write_bytes(b"stale")
        self.pack()
        self.assertEqual([p.name for p in (self.assets / "text").iterdir()], ["dn-9.json.gz"])


class Check(Base):
    def setUp(self):
        super().setUp()
        self.pack()

    def test_check_passes_after_pack(self):
        code, out = self.check()
        self.assertEqual((code, out.strip()), (0, "OK"))

    def test_check_fails_on_changed_byte(self):
        book = json.loads(json.dumps(BOOK))
        book["pages"][0]["pali"]["entries"][4]["text"] = "own text of d2"
        self.rewrite_gz("text/dn-9.json.gz", book)
        code, out = self.check()
        self.assertEqual(code, 1)
        self.assertIn("text/dn-9", out)
        self.assertNotIn("OK", out)

    def test_check_fails_on_extra_file(self):
        (self.assets / "text" / "dn-10.json.gz").write_bytes(gzip.compress(b"{}", 9, mtime=0))
        code, out = self.check()
        self.assertEqual(code, 1)
        self.assertIn("dn-10", out)

    def test_check_fails_on_missing_file(self):
        (self.assets / "text" / "dn-9.json.gz").unlink()
        code, out = self.check()
        self.assertEqual(code, 1)
        self.assertIn("dn-9", out)

    def test_check_fails_when_node_points_past_file(self):
        tree = json.loads(json.dumps(TREE))
        tree["dn-1-2"][3] = [1, 9]
        self.rewrite_gz("tree.json.gz", tree)
        self.fix_manifest_hash("tree", raw(tree))
        code, out = self.check()
        self.assertEqual(code, 1)
        self.assertIn("dn-1-2", out)

    def test_check_fails_when_node_names_unshipped_file(self):
        tree = json.loads(json.dumps(TREE))
        tree["dn-1-2"][5] = "dn-77"
        self.rewrite_gz("tree.json.gz", tree)
        self.fix_manifest_hash("tree", raw(tree))
        code, out = self.check()
        self.assertEqual(code, 1)
        self.assertIn("dn-1-2", out)

    def test_check_fails_when_reading_count_differs(self):
        path = self.assets / "manifest.json"
        m = json.loads(path.read_text(encoding="utf8"))
        m["readings"] = 4
        path.write_text(json.dumps(m), encoding="utf8")
        code, out = self.check()
        self.assertEqual(code, 1)
        self.assertIn("readings", out)


class Spans(unittest.TestCase):
    def test_display_ranges_cover_every_entry_once(self):
        flat = [e for p in BOOK["pages"] for e in p["pali"]["entries"]]
        analysis = tool.analyse(TREE, {"dn-9": BOOK})
        self.assertEqual(analysis.readings, 3)
        self.assertEqual(analysis.parents_with_text, ["dn-1"])
        ranges = analysis.ranges["dn-9"]
        self.assertEqual([tuple(r) for r in ranges],
                         [("dn-1", 0, 5), ("dn-1-1", 5, 7), ("dn-1-2", 7, 9)])
        covered = [i for _, a, b in ranges for i in range(a, b)]
        self.assertEqual(covered, list(range(len(flat))))
        # Title before the first node and heading-only parents (sp, dn)
        # show at the top of the first reading.
        self.assertEqual(ranges[0][1], 0)


class Fixtures(Base):
    def test_fixtures_copy_and_filter(self):
        code, out = run([str(self.project), "--fixtures", str(self.clone)])
        self.assertEqual(code, 0, out)
        fx = self.project / "test" / "fixtures" / "tipitaka"
        self.assertEqual((fx / "markup_cases.json").read_bytes(), b'[{"in": "a"}]\n')
        cases = json.loads((fx / "beautify_cases.json").read_text(encoding="utf8"))
        self.assertEqual(len([c for c in cases if c["lang"] == "pali"]), 400)
        self.assertEqual(len([c for c in cases if c["lang"] == "sinh"]), 40)
        self.assertEqual(cases[0], {"lang": "pali", "text": "p0", "out": "P0"})
        readme = (fx / "README.md").read_text(encoding="utf8")
        commit = subprocess.run(["git", "-C", str(self.clone), "log", "-1", "--format=%H"],
                                capture_output=True, text=True, check=True).stdout.strip()
        self.assertIn(commit, readme)


if __name__ == "__main__":
    unittest.main()
