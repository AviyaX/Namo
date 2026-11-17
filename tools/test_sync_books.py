"""Tests for tools/sync_books.py.

Run: python -I -X utf8 tools/test_sync_books.py
(-I leaves this folder off the import path, so the tool is loaded by file path.)
The pages under tools/test_data/pitaka_lk_books/ are real pitaka.lk pages, saved
unchanged (see the README there). No test touches the network: every opener
below is a fake.
"""
import contextlib
import gzip
import importlib.util
import io
import json
import pathlib
import re
import shutil
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
_SPEC = importlib.util.spec_from_file_location("sync_books", ROOT / "tools" / "sync_books.py")
tool = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(tool)

FIX = ROOT / "tools" / "test_data" / "pitaka_lk_books"
FETCHED = "2026-11-17"
NESTED_SLUG = "abhidharma-margaya"


def read(path):
    return path.read_text(encoding="utf8")


def kinds(blocks):
    return [b["kind"] for b in blocks]


def no_network(*args, **kwargs):
    raise AssertionError("the network was used")


class FakeResponse:
    def __init__(self, body):
        self._body = body

    def read(self):
        return self._body

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


def nested_book():
    """The nested fixture book, built from the rows whose page file is in the fixture."""
    index = tool.parse_index(read(FIX / "nested" / "index.html"))
    rows = [r for r in index["toc"] if (FIX / "nested" / r["href"]).is_file()]
    index = dict(index, toc=rows)
    pages = {r["href"]: read(FIX / "nested" / r["href"]) for r in rows}
    return tool.build_book(NESTED_SLUG, index, pages, FETCHED)


def para(text):
    return {"kind": "para", "text": text}


def small_book(slug):
    """A made-up three-page book: front matter, a parent without text, its child."""
    url = tool.BASE_URL + slug + "/"
    return {
        "id": slug,
        "title": "Title " + slug,
        "subtitle": None,
        "source": {"url": url + "index.html", "fetched": FETCHED},
        "pages": [
            {"n": 1, "key": "front", "level": 1, "title": "Front", "url": url + "index.html", "blocks": [para("a")]},
            {"n": 2, "key": "1", "level": 1, "title": "One", "url": url + "1.html", "blocks": []},
            {"n": 3, "key": "1-1", "level": 2, "title": "One one", "url": url + "1-1.html",
             "blocks": [para("b"), {"kind": "gatha", "lines": ["x", "y"]},
                        {"kind": "list", "ordered": True, "start": 1, "items": ["i"]}]},
        ],
    }


def make_project(base, mutate=None):
    books = [small_book(slug) for slug in tool.SLUGS]
    if mutate:
        mutate(books[0])
    tool.write_bundle(base, books, FETCHED)
    return base


class ParseIndexTest(unittest.TestCase):
    def test_parse_index_flat(self):
        index = tool.parse_index(read(FIX / "flat" / "index.html"))
        self.assertEqual(index["title"], "ධර්ම විනිශ්චය")
        self.assertEqual(index["subtitle"], "රේරුකානේ චන්දවිමල හිමි")
        toc = index["toc"]
        self.assertEqual(len(toc), 101)
        self.assertEqual({r["level"] for r in toc}, {1})
        self.assertEqual([r["key"] for r in toc], [str(i) for i in range(1, 102)])
        self.assertEqual([r["href"] for r in toc], ["%d.html" % i for i in range(1, 102)])
        self.assertTrue(all(r["title"] for r in toc))
        self.assertEqual(toc[0]["title"], "හැඳින්වීම.")
        self.assertEqual(index["front"]["title"], "පොත ගැන")
        self.assertTrue(index["front"]["blocks"])
        self.assertEqual(index["front"]["blocks"][3], {"kind": "subhead", "text": "ලේකම්ගේ සටහන්...."})
        self.assertEqual(index["front"]["blocks"][-1]["kind"], "gatha")

    def test_parse_index_nested_levels(self):
        raw = read(FIX / "nested" / "index.html")
        index = tool.parse_index(raw)
        want_levels = [int(x) for x in re.findall(r'<div class="toc-row" data-level="(\d)">', raw)]
        want_hrefs = re.findall(r'<div class="toc-row" data-level="\d">.*?<a href="([^"]+)"', raw)
        self.assertEqual(len(want_levels), 151)
        self.assertEqual([r["level"] for r in index["toc"]], want_levels)
        self.assertEqual([r["href"] for r in index["toc"]], want_hrefs)
        self.assertEqual([r["key"] for r in index["toc"]], [h[:-5] for h in want_hrefs])
        self.assertEqual(index["toc"][1]["key"], "2")
        self.assertEqual(index["toc"][2]["key"], "2-1")
        self.assertIn("8-1-1", [r["key"] for r in index["toc"] if r["level"] == 3])
        self.assertEqual(index["title"], "අභිධර්ම මාර්ගය")
        self.assertEqual(index["front"]["title"], "පොත ගැන")

    def test_parse_index_without_front_matter_text(self):
        raw = ('<main class="page"><div class="book-head"><h1>T</h1></div>'
               '<details class="front-matter"><summary>S</summary><div class="front-body prose">\n</div></details>'
               '<nav class="toc"><div class="toc-item" id="1"><div class="toc-row" data-level="1">'
               '<a href="1.html">One</a></div></div></nav></main>')
        index = tool.parse_index(raw)
        self.assertIsNone(index["front"])
        self.assertIsNone(index["subtitle"])
        self.assertEqual(index["toc"], [{"key": "1", "href": "1.html", "level": 1, "title": "One"}])


class ParsePageTest(unittest.TestCase):
    def blocks(self, folder, name):
        return tool.parse_page(read(FIX / folder / name), folder + "/" + name)

    def test_parse_page_kinds(self):
        self.assertEqual(kinds(self.blocks("flat", "1.html")), ["para"] * 9)
        self.assertEqual(kinds(self.blocks("nested", "2.html")), [])
        self.assertEqual(kinds(self.blocks("nested", "2-4.html")),
                         ["para"] * 2 + ["subhead"] + ["para"] * 11 + ["subhead", "list"])
        self.assertEqual(kinds(self.blocks("nested", "6.html")), ["para"])
        self.assertEqual(kinds(self.blocks("nested", "6-12.html")),
                         ["para"] * 5 + ["subhead", "gatha", "para", "gatha"] + ["para"] * 8)
        self.assertEqual(kinds(self.blocks("nested", "8-1-1.html")), ["para"] * 8)

        gathas = [b for b in self.blocks("nested", "6-12.html") if b["kind"] == "gatha"]
        self.assertEqual(len(gathas[0]["lines"]), 5)
        self.assertEqual(gathas[0]["lines"][0], "1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17")
        self.assertEqual(gathas[1]["lines"][0], "න ද ම ජ ජ ජ ජ ජ චු")
        self.assertEqual(len(gathas[1]["lines"]), 4)

        lst = self.blocks("nested", "2-4.html")[-1]
        self.assertEqual(lst["ordered"], True)
        self.assertEqual(lst["start"], 1)
        self.assertEqual(len(lst["items"]), 14)
        self.assertEqual(lst["items"][0], "පරමාර්ථ සතර මොනවා ද?")
        # The source's items carry no numbers; the reader draws them.
        self.assertFalse([i for i in lst["items"] if re.match(r"\d+\.", i)])

    def test_parse_page_keeps_text(self):
        # 8-1-1.html line 47, its <b>...</b> flattened to the text (escaped so the
        # zero-width joiners are visible).
        want = ("රූප - ශබ්ද - ගන්ධ - රස - "
                "ස්ප්‍ර‍ෂ්ටව්‍ය "
                "යන පඤ්ච කාමයන් ගැන "
                "ඇති ආශාව වූ ඖදාරික "
                "ලෝභය කාමාශ්‍ර‍ව "
                "නම් වේ.")
        self.assertEqual(self.blocks("nested", "8-1-1.html")[1], para(want))

    def test_parse_page_whitespace_breaks_and_headings(self):
        # Made up: no real page has <h2>/<h3> in its main text (see the fixture README).
        html = ('<main class="page prose"><div class="page-title"><h1>T</h1></div>'
                '<h2>Head  two</h2><h3>three</h3>'
                '<p>  a\n  <em>b</em>\tc <br> d </p>'
                '<div class="gatha"><p> x <br>y</p><p> </p><p>z</p></div>'
                '<ol start="4"><li> one <b>1</b></li><li>two</li></ol><ul><li>u</li></ul>'
                '<nav class="subheadings toc"><a href="1-1.html">c</a></nav></main>')
        self.assertEqual(tool.parse_page(html, "x"), [
            {"kind": "heading", "text": "Head two"},
            {"kind": "heading", "text": "three"},
            {"kind": "para", "text": "a b c\nd"},
            {"kind": "gatha", "lines": ["x", "y", "z"]},
            {"kind": "list", "ordered": True, "start": 4, "items": ["one 1", "two"]},
            {"kind": "list", "ordered": False, "start": 1, "items": ["u"]},
        ])

    def test_parse_page_survey_mappings(self):
        # Shapes found by the survey of 2026-11-17, cut down from the pages named in the tool.
        html = ('<main class="page prose">'
                '<h5>(හේතුමූලක ආරම්මණ දුකය)</h5>'
                '<div class="subhead">\n  <p>දුක් ඇතිවීමට</p>\n  <p>දෙවනුව</p>\n</div>'
                '<div class="subhead">පිනෙන් පව ගෙවීම </div>'
                '<div class="centered">\n  <p><b>මහාචාර්‍ය්‍ය</b></p>\n'
                '  <div class="subhead">\n    <p>රේරුකානේ</p>\n  </div>\n</div>'
                '<div class="largefont">\n  <p>“සුණාතු මෙ භන්තෙ සඞ්ඝො.</p>\n</div>'
                '<p class="centered">චිරං තිට්ඨතු සද්ධම්මෝ.</p>'
                '<ol class="enum">\n  <li><span class="li-num">(1)</span>පළමු <b>සිත</b> උපදී.</li>\n'
                '  <li><span class="li-num">(2)</span>දෙවන</li>\n</ol>'
                '</main>')
        self.assertEqual(tool.parse_page(html, "x"), [
            {"kind": "heading", "text": "(හේතුමූලක ආරම්මණ දුකය)"},
            {"kind": "subhead", "text": "දුක් ඇතිවීමට"},
            {"kind": "subhead", "text": "දෙවනුව"},
            {"kind": "subhead", "text": "පිනෙන් පව ගෙවීම"},
            {"kind": "para", "text": "මහාචාර්‍ය්‍ය"},
            {"kind": "subhead", "text": "රේරුකානේ"},
            {"kind": "para", "text": "“සුණාතු මෙ භන්තෙ සඞ්ඝො."},
            {"kind": "para", "text": "චිරං තිට්ඨතු සද්ධම්මෝ."},
            {"kind": "list", "ordered": False, "start": 1, "items": ["(1)පළමු සිත උපදී.", "(2)දෙවන"]},
        ])

    def test_parse_page_gatha_with_loose_lines(self):
        # suvisi-gunaya/19.html: lines left outside the <p>, split by <br>;
        # suvisi-gunaya/11-4.html: an empty <b> between two lines.
        html = ('<main class="page prose"><div class="gatha">\n'
                '  <p><b>චත්තාරො ච පටිපන්නා<br>\nචත්තාරො ච ඵලෙ ඨිතා</b></p>\n  \n'
                '  යජමානානං මනුස්සානං<br>\n  කාරොතං ඔපධිකං පුඤ්ඤං <br>\n  සංඝෙ දින්නං මහප්ඵලං.<p></p>\n'
                '</div><div class="gatha"><p>a</p><b>\n  </b><p><b>b</b></p></div>'
                # suvisi-gunaya/28-4.html: a <b> around three of the lines.
                '<div class="gatha"><p><b>c</b></p><b>\n  <p>d</p>\n  <p>e</p>\n  </b><p>f</p></div></main>')
        self.assertEqual(tool.parse_page(html, "x"), [
            {"kind": "gatha", "lines": ["චත්තාරො ච පටිපන්නා", "චත්තාරො ච ඵලෙ ඨිතා", "යජමානානං මනුස්සානං",
                                        "කාරොතං ඔපධිකං පුඤ්ඤං", "සංඝෙ දින්නං මහප්ඵලං."]},
            {"kind": "gatha", "lines": ["a", "b"]},
            {"kind": "gatha", "lines": ["c", "d", "e", "f"]},
        ])

    def test_parse_page_rejects_what_cannot_be_kept(self):
        # Footnotes, tables and images stay unknown until there is a way to keep them whole.
        for inner, tag in [('<ol class="footnotes"><li id="footnote-1"><p> x <a href="#r">↑</a></p></li></ol>',
                            '<ol class="footnotes">'),
                           ('<table class="collapse"><tbody><tr><td>තී</td></tr></tbody></table>',
                            '<table class="collapse">'),
                           ('<p><img src="images/a.png" alt="චක්‍රය"></p>', '<img class="">'),
                           ('<ol><li>x<suli><a class="footnote-ref">[1]</a></suli></li></ol>', '<suli class="">')]:
            with self.assertRaisesRegex(tool.SyncError, "unknown " + re.escape(tag)):
                tool.parse_page('<main class="page prose">%s</main>' % inner, "x")

    def test_parse_page_rejects_unknown(self):
        table = '<main class="page prose"><p>a</p><table><tr><td>x</td></tr></table></main>'
        with self.assertRaisesRegex(tool.SyncError, r"book/3\.html: unknown <table"):
            tool.parse_page(table, "book/3.html")
        with self.assertRaisesRegex(tool.SyncError, r"x: .*main\.page\.prose"):
            tool.parse_page('<main class="page"><p>a</p></main>', "x")
        with self.assertRaisesRegex(tool.SyncError, r"unknown <div class=\"other\">"):
            tool.parse_page('<main class="page prose"><div class="other"><p>a</p></div></main>', "x")
        with self.assertRaisesRegex(tool.SyncError, r"<li> holds a block <p>"):
            tool.parse_page('<main class="page prose"><ol><li><p>a</p></li></ol></main>', "x")


class BuildBookTest(unittest.TestCase):
    def test_build_book_reading_order(self):
        book = nested_book()
        self.assertEqual(book["id"], NESTED_SLUG)
        self.assertEqual(book["title"], "අභිධර්ම මාර්ගය")
        self.assertEqual(book["source"], {"url": tool.BASE_URL + NESTED_SLUG + "/index.html", "fetched": FETCHED})
        pages = book["pages"]
        self.assertEqual([p["n"] for p in pages], list(range(1, len(pages) + 1)))
        self.assertEqual(pages[0]["key"], "front")
        self.assertEqual(pages[0]["level"], 1)
        self.assertEqual(pages[0]["title"], "පොත ගැන")
        self.assertEqual(pages[0]["url"], tool.BASE_URL + NESTED_SLUG + "/index.html")
        self.assertTrue(pages[0]["blocks"])
        self.assertEqual([p["key"] for p in pages[1:]], ["2", "2-4", "6", "6-12", "8-1-1"])
        self.assertEqual([p["level"] for p in pages[1:]], [1, 2, 1, 2, 3])
        self.assertEqual(pages[1]["blocks"], [])
        self.assertTrue(pages[3]["blocks"])
        for p in pages[1:]:
            self.assertEqual(p["url"], tool.BASE_URL + NESTED_SLUG + "/" + p["key"] + ".html")
            self.assertTrue(p["title"])


class CachedPageTest(unittest.TestCase):
    def test_cached_page_does_not_fetch_when_present(self):
        with tempfile.TemporaryDirectory() as tmp:
            cache = pathlib.Path(tmp)
            (cache / "s").mkdir()
            (cache / "s" / "1.html").write_text("<p>ධම්ම</p>", encoding="utf8")
            self.assertEqual(tool.cached_page(cache, "s", "1.html", opener=no_network), "<p>ධම්ම</p>")

            calls = []

            def opener(request, timeout=None):
                calls.append(request)
                return FakeResponse("<p>බුද්ධ</p>".encode("utf8"))

            self.assertEqual(tool.cached_page(cache, "s", "2.html", opener=opener), "<p>බුද්ධ</p>")
            self.assertEqual(len(calls), 1)
            self.assertEqual(calls[0].full_url, tool.BASE_URL + "s/2.html")
            self.assertEqual(calls[0].get_header("User-agent"), tool.USER_AGENT)
            self.assertEqual((cache / "s" / "2.html").read_text(encoding="utf8"), "<p>බුද්ධ</p>")

    def test_cached_page_refuses_odd_names(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(tool.SyncError):
                tool.cached_page(pathlib.Path(tmp), "s", "../x.html", opener=no_network)


class BundleTest(unittest.TestCase):
    def test_pack_and_index(self):
        with tempfile.TemporaryDirectory() as tmp:
            project = pathlib.Path(tmp)
            book = nested_book()
            index = tool.write_bundle(project, [book], FETCHED)
            out = project / "assets" / "books"
            gz = out / (NESTED_SLUG + ".json.gz")
            self.assertTrue(gz.is_file())
            self.assertEqual(json.loads(read(out / "index.json")), index)
            self.assertEqual(json.loads(gzip.decompress(gz.read_bytes()).decode("utf8")), book)
            self.assertEqual(index["schema"], tool.SCHEMA)
            self.assertEqual(index["author"], tool.AUTHOR)
            self.assertEqual(index["publisher"], tool.PUBLISHER)
            self.assertEqual(index["source"], {"name": "pitaka.lk", "url": tool.BASE_URL, "fetched": FETCHED})
            entry, = index["books"]
            self.assertEqual(entry["id"], NESTED_SLUG)
            self.assertEqual(entry["title"], book["title"])
            self.assertEqual(entry["subtitle"], book["subtitle"])
            self.assertEqual(entry["bytes"], gz.stat().st_size)
            self.assertEqual(entry["sha256"], tool.sha256(gz.read_bytes()))
            self.assertEqual(entry["chapters"], 2)    # pages 2 and 6; the front matter is not counted
            self.assertEqual(entry["pages"], 5)       # all but the empty parent 2
            self.assertEqual(entry["file"], "assets/books/%s.json.gz" % NESTED_SLUG)
            self.assertEqual(entry["cover"], "assets/books/covers/%s.png" % NESTED_SLUG)
        data = json.dumps(book, ensure_ascii=False).encode("utf8")
        self.assertEqual(tool.pack_bytes(data), tool.pack_bytes(data))
        self.assertEqual(gzip.decompress(tool.pack_bytes(data)), data)


class CheckTest(unittest.TestCase):
    first = tool.SLUGS[0]

    def problems(self, mutate=None, after=None):
        with tempfile.TemporaryDirectory() as tmp:
            project = make_project(pathlib.Path(tmp), mutate)
            if after:
                after(project / "assets" / "books")
            return tool.check(project)

    def assert_named(self, problems, name, word):
        self.assertTrue([p for p in problems if name in p and word in p], problems)

    def test_check_rules(self):
        self.assertEqual(self.problems(), [])
        gz = self.first + ".json.gz"

        self.assert_named(self.problems(after=lambda out: (out / gz).unlink()), gz, "missing")

        def wrong_bytes(out):
            index = json.loads(read(out / "index.json"))
            index["books"][0]["bytes"] += 1
            (out / "index.json").write_text(json.dumps(index, ensure_ascii=False), encoding="utf8")
        self.assert_named(self.problems(after=wrong_bytes), gz, "bytes")

        self.assert_named(self.problems(after=lambda out: (out / "stray.txt").write_text("x")),
                          "stray.txt", "unexpected")

        def no_title(book):
            book["pages"][2]["title"] = ""
        self.assert_named(self.problems(no_title), gz, "no title")

        def empty_leaf(book):
            book["pages"][2]["blocks"] = []
        self.assert_named(self.problems(empty_leaf), gz, "neither blocks nor children")

        def out_of_order(book):
            book["pages"][2]["n"] = 7
        self.assert_named(self.problems(out_of_order), gz, "n is 7")

        def unknown_kind(book):
            book["pages"][2]["blocks"].append({"kind": "table", "text": "x"})
        self.assert_named(self.problems(unknown_kind), gz, "unknown block")

        def markup(book):
            book["pages"][2]["blocks"][0]["text"] = "a <b>b</b>"
        self.assert_named(self.problems(markup), gz, "markup")

        def markup_in_list(book):
            book["pages"][2]["blocks"][2]["items"][0] = "&nbsp;x"
        self.assert_named(self.problems(markup_in_list), gz, "markup")

        def level_jump(book):
            book["pages"][2]["level"] = 3
        self.assert_named(self.problems(level_jump), gz, "level")

        def front_not_first(book):
            book["pages"][0]["key"], book["pages"][1]["key"] = book["pages"][1]["key"], "front"
        self.assert_named(self.problems(front_not_first), gz, "front")

        png = b"\x89PNG\r\n\x1a\n" + b"rest"

        def covers_but_one(out):
            (out / "covers").mkdir()
            for slug in tool.SLUGS[1:]:
                (out / "covers" / (slug + ".png")).write_bytes(png)
        self.assert_named(self.problems(after=covers_but_one), "covers/%s.png" % self.first, "missing")

        def all_covers(out):
            covers_but_one(out)
            (out / "covers" / (self.first + ".png")).write_bytes(png)
        self.assertEqual(self.problems(after=all_covers), [])

        def not_png(out):
            all_covers(out)
            (out / "covers" / (self.first + ".png")).write_bytes(b"GIF89a")
        self.assert_named(self.problems(after=not_png), "covers/%s.png" % self.first, "PNG")

    def test_check_unreadable_index(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assert_named(tool.check(pathlib.Path(tmp)), "index.json", "cannot be read")


class SurveyTest(unittest.TestCase):
    def test_survey_counts(self):
        table = tool.survey(FIX)
        for key in [("p", ""), ("div", "gatha"), ("ol", ""), ("p", "subhead"), ("b", "")]:
            self.assertIn(key, table)
            count, first = table[key]
            self.assertGreater(count, 0)
            self.assertTrue((FIX / first).is_file(), first)
        self.assertEqual(table[("div", "gatha")][0], 4)   # both front matters 1 each, nested/6-12.html 2
        # Skipped subtrees are counted at their root only.
        self.assertIn(("nav", "subheadings toc"), table)
        self.assertNotIn(("h1", ""), table)
        self.assertNotIn(("use", ""), table)

    def test_survey_prints_a_table(self):
        with tempfile.TemporaryDirectory() as tmp:
            project = pathlib.Path(tmp)
            shutil.copytree(FIX / "nested", tool.cache_dir(project) / "nested")
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                self.assertEqual(tool.main([str(project), "--survey"]), 0)
            rows = [line.split("\t") for line in out.getvalue().splitlines()]
            self.assertIn(["div", "gatha", "3", "nested/6-12.html"], rows)   # index.html is read last
            counts = [int(r[2]) for r in rows]
            self.assertEqual(counts, sorted(counts, reverse=True))


class MainTest(unittest.TestCase):
    def test_main_requires_a_mode(self):
        err = io.StringIO()
        with tempfile.TemporaryDirectory() as tmp, contextlib.redirect_stderr(err):
            with self.assertRaises(SystemExit) as cm:
                tool.main([tmp])
        self.assertEqual(cm.exception.code, 2)
        self.assertIn("usage:", err.getvalue())
        self.assertIn("give at least one of --fetch, --survey, --check, --covers", err.getvalue())

    def test_main_check(self):
        with tempfile.TemporaryDirectory() as tmp:
            project = make_project(pathlib.Path(tmp))
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                self.assertEqual(tool.main([str(project), "--check"]), 0)
            self.assertEqual(out.getvalue(), "OK\n")
            (project / "assets" / "books" / "stray.txt").write_text("x")
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                self.assertEqual(tool.main([str(project), "--check"]), 1)
            self.assertIn("stray.txt", out.getvalue())


if __name__ == "__main__":
    unittest.main()
