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
                        {"kind": "list", "marker": "number", "start": 1, "items": ["i"]},
                        {"kind": "table", "header": True, "rows": [["h"], [""]]},
                        {"kind": "image", "src": url + "images/p.png", "alt": ""},
                        {"kind": "footnotes", "items": ["n"]}]},
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
        self.assertEqual(lst["marker"], "number")
        self.assertEqual(lst["start"], 1)
        self.assertEqual(len(lst["items"]), 14)
        self.assertEqual(lst["items"][0], "පරමාර්ථ සතර මොනවා ද?")
        # The source's items carry no numbers; the reader draws them.
        self.assertFalse([i for i in lst["items"] if re.match(r"\d+\.", i)])

    def test_parse_page_keeps_text(self):
        # 8-1-1.html line 47, its <b>...</b> flattened to the text (escaped so the
        # zero-width joiners are visible).
        want = ("\u0dbb\u0dd6\u0db4 - \u0dc1\u0db6\u0dca\u0daf - \u0d9c\u0db1\u0dca\u0db0 - \u0dbb\u0dc3 - "
                "\u0dc3\u0dca\u0db4\u0dca\u200d\u0dbb\u200d\u0dc2\u0dca\u0da7\u0dc0\u0dca\u200d\u0dba \u0dba\u0db1 "
                "\u0db4\u0da4\u0dca\u0da0 \u0d9a\u0dcf\u0db8\u0dba\u0db1\u0dca \u0d9c\u0dd0\u0db1 "
                "\u0d87\u0dad\u0dd2 \u0d86\u0dc1\u0dcf\u0dc0 \u0dc0\u0dd6 \u0d96\u0daf\u0dcf\u0dbb\u0dd2\u0d9a "
                "\u0dbd\u0ddd\u0db7\u0dba \u0d9a\u0dcf\u0db8\u0dcf\u0dc1\u0dca\u200d\u0dbb\u200d\u0dc0 "
                "\u0db1\u0db8\u0dca \u0dc0\u0dda.")
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
            {"kind": "list", "marker": "number", "start": 4, "items": ["one 1", "two"]},
            {"kind": "list", "marker": "bullet", "start": 1, "items": ["u"]},
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
            {"kind": "list", "marker": "none", "start": 1, "items": ["(1)පළමු සිත උපදී.", "(2)දෙවන"]},
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

    def test_parse_page_new_kinds(self):
        # Real pages for the kinds added after the survey (see the fixture README).
        cases = {
            ("abhidharmaye-mulika-karunu", "12.html"): ["para"] * 22 + ["gatha"] + ["para"] * 7 + ["footnotes"],
            ("shasanavatharanaya", "7.html"): ["para"] * 8 + ["footnotes"],
            ("abhidharma-margaya", "5-5.html"): ["para"] * 11 + ["subhead", "table"] + ["para"] * 5,
            ("abhidharma-margaya", "2-7.html"): ["list", "para", "para", "list"],
            ("bodhi-poojawa", "28-2.html"): ["image"] + ["para"] * 6 + ["list"] + ["para"] * 4,
            ("punyopadeshaya", "39-25.html"): ["image", "para", "para", "gatha", "para"],
            ("bauddhayage-athpotha", "6-7.html"): (["para"] * 8 + ["list"] + ["para"] * 3 + ["list", "para", "list"]
                                                   + ["para"] * 5),
            ("pattana-pakarana-sannaya", "6-2.html"): (["para"] * 34 + ["subhead", "para", "para", "subhead"]
                                                       + ["para"] * 5
                                                       + (["gatha", "para", "para"] * 7)[:-1]
                                                       + ["para", "gatha", "para", "gatha", "para", "para", "gatha",
                                                          "para", "gatha", "para", "para", "para", "list", "para",
                                                          "gatha", "para", "gatha", "para", "para", "para", "subhead",
                                                          "para"]),
            ("pohoya-dinaya", "21-1.html"): ["list", "subhead", "list", "para", "para", "footnotes"],
        }
        for (book, name), want in cases.items():
            self.assertEqual(kinds(self.blocks(book, name)), want, name)

        notes = self.blocks("abhidharmaye-mulika-karunu", "12.html")[-1]["items"]
        self.assertEqual(len(notes), 2)
        self.assertTrue(notes[0].startswith("අංගුත්තර අටුවා."), notes[0])
        self.assertTrue(notes[0].endswith("↑"), notes[0])          # the back-link's own text is kept
        two = self.blocks("shasanavatharanaya", "7.html")[-1]["items"]
        self.assertEqual(len(two), 1)
        self.assertEqual(two[0].count("\n"), 1)                     # two <p>s, two lines

        table = self.blocks("abhidharma-margaya", "5-5.html")[12]
        self.assertFalse(table["header"])
        self.assertEqual([len(r) for r in table["rows"]], [9, 9])
        self.assertEqual(table["rows"][0][0], "තී\nооо\n1")
        self.assertEqual(table["rows"][1][8], "භ\nооо\n..")

        enum, _, _, plain = self.blocks("abhidharma-margaya", "2-7.html")
        self.assertEqual((enum["marker"], enum["start"], len(enum["items"])), ("none", 1, 8))
        self.assertTrue(all(i.startswith("(%d)" % (n + 1)) for n, i in enumerate(enum["items"])))
        self.assertEqual((plain["marker"], plain["start"], len(plain["items"])), ("number", 1, 7))
        self.assertFalse([i for i in plain["items"] if re.match(r"\d+\.", i)])

        image = self.blocks("bodhi-poojawa", "28-2.html")[0]
        self.assertEqual(image["src"], "https://pitaka.lk/books/bodhi-poojawa/images/377a05be20.png")
        self.assertTrue(image["alt"].startswith("දැති සහිත"), image["alt"])
        inside_b = self.blocks("punyopadeshaya", "39-25.html")[0]
        self.assertEqual(inside_b["src"], "https://pitaka.lk/books/punyopadeshaya/images/75000eeb95.png")

        verses = self.blocks("bauddhayage-athpotha", "6-7.html")[12]
        self.assertEqual(verses["marker"], "number")
        self.assertEqual(len(verses["items"]), 4)
        self.assertEqual([i.count("\n") for i in verses["items"]], [1, 1, 1, 1])   # a two-line gatha per item
        self.assertEqual(verses["items"][0].split("\n")[1], "ජායන්ති තත්ථ පාරොහා - අහො රත්තාන මච්චයෙ")

        nested = self.blocks("pattana-pakarana-sannaya", "6-2.html")[75]
        self.assertEqual((nested["marker"], len(nested["items"])), ("bullet", 1))
        self.assertEqual(len(nested["items"][0].split("\n")), 9)    # the nine items of the inner <ol>

        first, _, second, _, _, notes = self.blocks("pohoya-dinaya", "21-1.html")
        self.assertTrue([i for i in first["items"] if "[1]" in i])   # the <suli> footnote mark, flattened
        self.assertEqual((second["start"], len(second["items"])), (34, 17))
        self.assertEqual(len(notes["items"]), 1)

    def test_parse_page_new_kinds_made_up(self):
        html = ('<main class="page prose">'
                '<table><thead><tr><th>A</th><th> B </th></tr></thead><tbody><tr><td>1</td><td></td></tr></tbody></table>'
                '<img src="/books/x/images/p.png">'
                '<ul><li>top <ol class="enum"><li>(i) a</li></ol><div class="gatha"><p>l1</p><p>l2</p></div></li></ul>'
                '</main>')
        self.assertEqual(tool.parse_page(html, "x/3.html"), [
            {"kind": "table", "header": True, "rows": [["A", "B"], ["1", ""]]},
            {"kind": "image", "src": "https://pitaka.lk/books/x/images/p.png", "alt": ""},
            {"kind": "list", "marker": "bullet", "start": 1, "items": ["top\n(i) a\nl1\nl2"]},
        ])
        self.assertEqual(tool.parse_page('<main class="page prose"><img src="i.png"></main>', "y/1.html",
                                         "https://example.org/z/1.html")[0]["src"], "https://example.org/z/i.png")

    def test_parse_page_rejects_unknown(self):
        with self.assertRaisesRegex(tool.SyncError, r"book/3\.html: unknown <table class=\"wide\">"):
            tool.parse_page('<main class="page prose"><p>a</p><table class="wide"><tr><td>x</td></tr></table></main>',
                            "book/3.html")
        with self.assertRaisesRegex(tool.SyncError, r"unknown <form"):
            tool.parse_page('<main class="page prose"><form>x</form></main>', "x")
        with self.assertRaisesRegex(tool.SyncError, r"x: .*main\.page\.prose"):
            tool.parse_page('<main class="page"><p>a</p></main>', "x")
        with self.assertRaisesRegex(tool.SyncError, r"unknown <div class=\"other\">"):
            tool.parse_page('<main class="page prose"><div class="other"><p>a</p></div></main>', "x")
        with self.assertRaisesRegex(tool.SyncError, r"<li> holds a block <p>"):
            tool.parse_page('<main class="page prose"><ol><li><p>a</p></li></ol></main>', "x")
        with self.assertRaisesRegex(tool.SyncError, r"an <img> shares its paragraph with text"):
            tool.parse_page('<main class="page prose"><p>a <img src="i.png"></p></main>', "x/1.html")

    def test_parse_page_rejects_a_cell_holding_a_block(self):
        # A real page: its table cells hold <p>s (reported; six more pages like it).
        with self.assertRaisesRegex(tool.SyncError, r"punyopadeshaya/39-23\.html: <td> holds a block <p>"):
            self.blocks("punyopadeshaya", "39-23.html")


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
            book["pages"][2]["blocks"].append({"kind": "chart", "text": "x"})
        self.assert_named(self.problems(unknown_kind), gz, "unknown block")

        def markup(book):
            book["pages"][2]["blocks"][0]["text"] = "a <b>b</b>"
        self.assert_named(self.problems(markup), gz, "markup")

        def markup_in_list(book):
            book["pages"][2]["blocks"][2]["items"][0] = "&nbsp;x"
        self.assert_named(self.problems(markup_in_list), gz, "markup")

        def empty_footnote(book):
            book["pages"][2]["blocks"][5]["items"] = [""]
        self.assert_named(self.problems(empty_footnote), gz, "empty")

        def empty_row(book):
            book["pages"][2]["blocks"][3]["rows"].append([])
        self.assert_named(self.problems(empty_row), gz, "empty row")

        def relative_image(book):
            book["pages"][2]["blocks"][4]["src"] = "images/p.png"
        self.assert_named(self.problems(relative_image), gz, "absolute")

        def old_list(book):
            block = book["pages"][2]["blocks"][2]
            block["ordered"] = block.pop("marker") == "number"
        self.assert_named(self.problems(old_list), gz, "marker")

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
        for key in [("ol", "footnotes"), ("ol", "enum"), ("table", "collapse"), ("img", ""), ("suli", "")]:
            self.assertIn(key, table)
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
