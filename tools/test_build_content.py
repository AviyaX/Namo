"""Tests for tools/build_content.py.

Run: python -I -X utf8 tools/test_build_content.py
(-I leaves this folder off the import path, so the build script is loaded by file path.)
"""
import collections
import copy
import importlib.util
import json
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
_SPEC = importlib.util.spec_from_file_location("build_content", ROOT / "tools" / "build_content.py")
build_content = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(build_content)

ASSET = ROOT / "assets" / "content" / "namaskaraya_to_pin_dima.json"
BASELINE = ROOT / "tools" / "test_data" / "content_before_reflow_a448a3c.json"

# The 33 headings in the booklet's order (design, "The reading after the change"); the new ones are
# the Nottingham booklet's own headings as the extraction converted them.
HEADINGS = ['තෙරුවන් නමස්කාර කිරීම', 'නමස්කාරය', 'තිසරණ සරණයාම', 'පංචශීලය සමාදන්වීම',
            'බුදු ගුණ සිහි කිරීම', 'දහම් වැඳීම', 'සඟුන් වැඳීම', 'සියල්ල එකට සිහි කිරීම',
            'චෛත්‍ය වන්දනාව', 'බෝධි වන්දනාව', 'බුද්ධ පූජා ආරාධනාව', 'පහන් පූජාව', 'සුවඳ දුම් පූජාව',
            'මල් පූජාව', 'පැන් පූජාව', 'ආහාර පූජාව', 'ගිලන්පස පූජාව', 'දැහැත් පූජාව',
            'සියල්ල එකවිට පූජා කිරීම', 'තෙරුවන් සමාකර ගැනීම', 'මියගිය ඤාතීන්ට පින් අනුමෝදන් කිරීම',
            'දෙවියන්ට පින් දීම', 'ප්‍රාර්ථනා', 'බුද්ධානුස්සතිය', 'මෙත්තානුස්සතිය', 'අසුභානුස්සතිය',
            'මරණානුස්සතිය', 'අට්ඨ මහා සංවේග වත්ථු', 'පටිච්ච සමුප්පාදය – අනුලෝම',
            'පටිච්ච සමුප්පාදය – පටිලෝම', 'නිවැරදි පිළිසරණ යෑම', 'තිලකුණු මෙනෙහි කිරීම',
            'මෛත්‍රී භාවනාව']
VERSES = [5, 1, 1, 1, 5, 5, 5, 8, 1, 3, 1, 1, 2, 2, 1, 1, 1, 1, 1, 3, 1, 4, 4, 11, 5, 6, 7, 3, 1, 1, 5, 6, 11]
# Old section id -> new section id (verse numbers unchanged).
OLD_TO_NEW = {"s01": "s02", "s02": "s03", "s03": "s04", "s04": "s05", "s05": "s06", "s06": "s07",
              "s07": "s09", "s08": "s10", "s09": "s11", "s10": "s12", "s11": "s13", "s12": "s14",
              "s13": "s15", "s14": "s16", "s15": "s17", "s16": "s18", "s17": "s19", "s18": "s22",
              "s19": "s20"}
NAMO_NUMBERS = {2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19}
BOOKLET_NUMBERS = {20, 22}
NO_ENGLISH = {"s01-v5", "s10-v3", "s11-v1", "s16-v1", "s18-v1"}
BRISBANE = {"s09-v1", "s10-v1", "s10-v2", "s12-v1", "s13-v1", "s13-v2", "s14-v1", "s14-v2",
            "s15-v1", "s17-v1", "s22-v1"}
MAHAMEVNAWA = {"s02-v1", "s03-v1", "s04-v1", "s05-v1", "s06-v1", "s07-v1", "s22-v4",
               "s20-v1", "s20-v2", "s20-v3"}
NEEDS = {"s13-v1", "s14-v2", "s22-v4", "s20-v3"}
EXPLANATION = {"s05-v1", "s06-v1", "s07-v1"}
NOTTINGHAM_ENGLISH = {"s19-v1", "s22-v2", "s22-v3"}
# New sections -> the booklet's printed page(s).
NEW_SECTIONS = {"s01": "3", "s08": "9–11", "s21": "14", "s23": "16–17", "s24": "17–19", "s25": "19–20",
                "s26": "21–22", "s27": "22–23", "s28": "24", "s29": "25", "s30": "26", "s31": "27–28",
                "s32": "28–29", "s33": "29–34"}
# Sections 5-7 -> the printed page(s) of their verses 2-5 (s07's four are all on page 8).
EXTENDED_SECTIONS = {"s05": "5–6", "s06": "6–7", "s07": "8"}
PARITHA_PAGES = {"s08-v6": 3, "s08-v7": 3, "s08-v8": 3, "s23-v1": 38}
# The rows of §5.3: printed form -> number of places.
NAMO_COUNTS = {'ගච්චාමි': 9, 'විඡ්ඡාචරණ': 1, 'සමාදියාමී': 4, 'සුමාමේරය': 1, 'ධානේසු': 1,
               'අධිවාසේ තුනෝ': 1, 'බෝදි': 1, 'ඝනසාරප්ප දිත්තේන': 1}
# Owner's corrections made after the baseline was frozen: (verse id, printed, corrected).
LATER_CORRECTIONS = {"s12-v1": ("ඝනසාරප්ප දිත්තේන", "ගන්ධ තේල පදිත්තේන")}
BOOKLET_COUNTS = {'රුස්කර': 3, 'පුණ්ය': 3, 'භූතයා්': 1, 'ම විසින්': 3, 'සාසණ': 1,
                  'පුංඤ්ඤකෙත්තං': 1, 'අනුත්ථරං': 1, 'දේවානාගා': 3}
COUNTS = {**NAMO_COUNTS, **BOOKLET_COUNTS}


def new_id(old_id):
    return OLD_TO_NEW[old_id[:3]] + old_id[3:]


def pages_phrase(pages):
    return f"printed pages {pages}" if "–" in pages else f"printed page {pages}"


def baseline_of(field):
    """Every verse's `field` from the content file committed at a448a3c, before the reflow,
    keyed by the old ids.

    BASELINE is that file exactly as `git show a448a3c:...` gives it, kept in the
    repository so these tests do not need the commit (a squash or a shallow clone)."""
    data = json.loads(BASELINE.read_bytes().decode("utf-8"))
    return {v["id"]: v[field] for s in data["categories"][0]["readings"][0]["sections"]
            for v in s["verses"]}


class BuildContentTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = build_content.build(ROOT)
        cls.sections = cls.data["categories"][0]["readings"][0]["sections"]
        cls.verses = [v for s in cls.sections for v in s["verses"]]
        cls.by_id = {v["id"]: v for v in cls.verses}
        cls.mapped = {new_id(old) for old in baseline_of("pali_si")}
        cls.new_verses = {v["id"] for v in cls.verses} - cls.mapped

    def section_text(self, numbers):
        return "\n".join(v[field] or "" for s in self.sections if s["number"] in numbers
                         for v in s["verses"] for field in ("pali_si", "sinhala"))

    def test_sections(self):
        self.assertEqual([s["heading"] for s in self.sections], HEADINGS)
        self.assertEqual([s["number"] for s in self.sections], list(range(1, 34)))
        self.assertEqual([s["id"] for s in self.sections], [f"s{n:02d}" for n in range(1, 34)])
        for s in self.sections:
            self.assertEqual([v["id"] for v in s["verses"]],
                             [f"{s['id']}-v{k}" for k in range(1, len(s["verses"]) + 1)])

    def test_order_follows_the_booklet(self):
        self.assertEqual(len(build_content.ORDER), 33)
        headings = {s["id"]: s["heading"] for s in self.sections}
        self.assertEqual(headings["s20"], "තෙරුවන් සමාකර ගැනීම")
        self.assertEqual(headings["s21"], "මියගිය ඤාතීන්ට පින් අනුමෝදන් කිරීම")
        self.assertEqual(headings["s22"], "දෙවියන්ට පින් දීම")
        self.assertEqual(headings["s23"], "ප්‍රාර්ථනා")
        self.assertEqual(build_content.ORDER[19], ("booklet", 19))
        self.assertEqual(build_content.ORDER[21], ("booklet", 18))

    def test_title_and_subtitle(self):
        category = self.data["categories"][0]
        reading = category["readings"][0]
        self.assertEqual((category["id"], reading["id"]), ("cat-namaskaraya", "namaskaraya"))
        self.assertEqual(category["title"], "Buddha Wandanawa")
        self.assertEqual(reading["title"], "Buddha Wandanawa")
        self.assertEqual(category["subtitle"], "බුද්ධ වන්දනාව")

    def test_verse_counts(self):
        self.assertEqual([len(s["verses"]) for s in self.sections], VERSES)
        self.assertEqual(len(self.verses), 114)
        self.assertEqual(len(self.mapped), 28)
        self.assertEqual(len(self.new_verses), 86)

    def test_english_presence(self):
        self.assertEqual({v["id"] for v in self.verses if v["english"] is None}, NO_ENGLISH)
        self.assertEqual({v["id"] for v in self.verses if v["english_source"] is None}, NO_ENGLISH)
        self.assertEqual({v["id"] for v in self.verses if v["english_kind"] is None}, NO_ENGLISH)

    def test_english_sources(self):
        with_english = [v for v in self.verses if v["english"] is not None]
        brisbane = {v["id"] for v in with_english if "Cynthia Gunawardana" in v["english_source"]["translator"]}
        self.assertEqual(brisbane, BRISBANE)
        mahamevnawa = {v["id"] for v in with_english if "Mahamevnawa" in v["english_source"]["name"]}
        self.assertEqual(mahamevnawa, MAHAMEVNAWA)
        nottingham = [v for v in with_english if v["id"] not in BRISBANE | MAHAMEVNAWA]
        self.assertEqual(len(nottingham), 114 - len(NO_ENGLISH) - len(BRISBANE) - len(MAHAMEVNAWA))
        for v in with_english:
            if v["id"] not in BRISBANE:
                self.assertEqual(v["english_source"]["translator"], "not named by the source", v["id"])
        for v in nottingham:
            self.assertEqual(v["english_source"]["name"], build_content.NOTTINGHAM_NAME, v["id"])
            self.assertRegex(v["english_source"]["locator"],
                             r"^evening_puja_and_chanting\.pdf \(supplied by the app's owner, 2026-11-17\), "
                             r"printed page \d+$", v["id"])
            self.assertEqual(v["english_source"]["collected"], "2026-11-17", v["id"])

    def test_section_pages_come_from_the_units(self):
        self.assertEqual(build_content._pages_of([[(8, 1)], [(8, 4)]]), "8")
        self.assertEqual(build_content._pages_of([[(16, 3)], [(16, 7), (17, 0)], [(17, 1)]]), "16–17")
        for spec in build_content.NOTTINGHAM_SECTIONS.values():
            self.assertNotIn("pages", spec)
        self.assertFalse(hasattr(build_content, "EXTENDED_PAGES"))
        self.assertEqual(self.sections[6]["notes"],
                         ["Verses 2–5 converted from the booklet's FM font; to be read against printed page 8."])

    def test_english_locator_is_the_page_that_supplied_it(self):
        def page(verse_id):
            return self.by_id[verse_id]["english_source"]["locator"].rsplit(" ", 1)[1]

        self.assertEqual(page("s23-v3"), "17")  # Pali on page 16, Roman and English on page 17
        self.assertEqual(page("s19-v1"), "14")  # Pali on page 13, Roman and English on page 14
        self.assertEqual(page("s24-v8"), "19")
        self.assertEqual(page("s33-v7"), "31")  # English starts on page 31 and runs on to 32

    def test_english_kind(self):
        self.assertEqual({v["id"] for v in self.verses if v["english_kind"] == "explanation"}, EXPLANATION)
        others = {v["english_kind"] for v in self.verses if v["english"] is not None and v["id"] not in EXPLANATION}
        self.assertEqual(others, {"translation"})

    def test_anchors(self):
        self.assertTrue(self.by_id["s02-v1"]["english"].startswith("Homage to the Blissful One"))
        self.assertTrue(self.by_id["s09-v1"]["english"].startswith("I salute every chetiya"))
        self.assertTrue(self.by_id["s22-v1"]["english"].startswith("May all devas share this merit"))
        self.assertTrue(self.by_id["s20-v3"]["english"].endswith("Practising well and supreme."))

    def test_three_english_from_the_booklet(self):
        self.assertEqual(set(build_content.NOTTINGHAM_ENGLISH), NOTTINGHAM_ENGLISH)
        for verse_id in NOTTINGHAM_ENGLISH:
            v = self.by_id[verse_id]
            self.assertTrue(v["english"], verse_id)
            self.assertEqual(v["english_source"]["name"], build_content.NOTTINGHAM_NAME, verse_id)
            self.assertEqual(v["english_kind"], "translation", verse_id)
        self.assertTrue(self.by_id["s22-v2"]["english"].startswith("All the merits, thus, accumulated by us,"))

    def test_pali_and_sinhala_everywhere(self):
        for v in self.verses:
            self.assertTrue(v["pali_si"].strip(), v["id"])
            if v["id"] in self.mapped or v["id"] in PARITHA_PAGES:
                self.assertTrue(v["sinhala"].strip(), v["id"])
            else:
                self.assertIsNone(v["sinhala"], v["id"])

    def test_paritha_sinhala_reused(self):
        self.assertEqual({k: page for k, (page, _) in build_content.PARITHA_SINHALA.items()}, PARITHA_PAGES)
        for verse_id, page in PARITHA_PAGES.items():
            v = self.by_id[verse_id]
            self.assertTrue(v["sinhala"].strip(), verse_id)
            self.assertEqual(v["sinhala_source"]["name"], "paritha.org booklet (Wandana Gatha)", verse_id)
            self.assertTrue(v["sinhala_source"]["locator"].endswith(f", printed page {page}"), verse_id)
        for v in self.verses:
            if v["id"] not in PARITHA_PAGES:
                self.assertIsNone(v["sinhala_source"], v["id"])

    def test_extra_verses_carry_their_source(self):
        extras = {f"{s}-v{k}" for s in EXTENDED_SECTIONS for k in range(2, 6)}
        for v in self.verses:
            if v["id"] in extras:
                self.assertEqual(v["source"]["name"], build_content.NOTTINGHAM_NAME, v["id"])
                self.assertRegex(v["source"]["locator"], r", printed page \d+$", v["id"])
                self.assertEqual(v["source"]["translator"], "not named by the source", v["id"])
            else:
                self.assertIsNone(v["source"], v["id"])
        for section_id in EXTENDED_SECTIONS:
            self.assertEqual(self.by_id[f"{section_id}-v1"]["check"], "checked against source")

    def test_new_sections_sources_and_checks(self):
        by_section = {s["id"]: s for s in self.sections}
        for section_id, pages in NEW_SECTIONS.items():
            s = by_section[section_id]
            self.assertEqual(s["source"], {
                "name": "Shanthi Vihara, Nottingham — Evening Puja and Chanting",
                "locator": f"evening_puja_and_chanting.pdf (supplied by the app's owner, 2026-11-17), "
                           f"{pages_phrase(pages)}",
                "collected": "2026-11-17", "translator": "not named by the source"}, section_id)
            self.assertEqual(s["check"], "needs checking", section_id)
            self.assertEqual(s["notes"], [f"Converted from the booklet's FM font; to be read against "
                                          f"{pages_phrase(pages)}."], section_id)
            for v in s["verses"]:
                self.assertEqual((v["check"], v["notes"]), ("needs checking", []), v["id"])
        for section_id, pages in EXTENDED_SECTIONS.items():
            s = by_section[section_id]
            self.assertEqual(s["check"], "needs checking", section_id)
            self.assertEqual(s["notes"], [f"Verses 2–5 converted from the booklet's FM font; to be read "
                                          f"against {pages_phrase(pages)}."], section_id)
            self.assertEqual(s["source"]["name"], "namo.lk", section_id)
        for s in self.sections:
            if s["id"] not in NEW_SECTIONS and s["id"] not in EXTENDED_SECTIONS:
                self.assertEqual(s["notes"], [], s["id"])
        self.assertEqual(sum(1 for s in self.sections if s["notes"]), 17)

    def test_owner_clears_a_section(self):
        self.assertEqual(build_content.NOTTINGHAM_CHECKED, frozenset())
        saved = build_content.NOTTINGHAM_CHECKED
        build_content.NOTTINGHAM_CHECKED = frozenset({"metta", "s05"})
        try:
            cleared = build_content.build(ROOT)
        finally:
            build_content.NOTTINGHAM_CHECKED = saved
        sections = {s["id"]: s for s in cleared["categories"][0]["readings"][0]["sections"]}
        for section_id in ("s33", "s05"):
            s = sections[section_id]
            self.assertEqual((s["check"], s["notes"]), ("checked against source", []), section_id)
            for v in s["verses"]:
                self.assertEqual((v["check"], v["notes"]), ("checked against source", []), v["id"])
        # Everything else is the build without the table.
        expected = copy.deepcopy(self.data)
        for s in expected["categories"][0]["readings"][0]["sections"]:
            if s["id"] in ("s33", "s05"):
                s.update({"check": "checked against source", "notes": []})
                for v in s["verses"]:
                    v["check"] = "checked against source"
        self.assertEqual(cleared, expected)
        build_content.NOTTINGHAM_CHECKED = frozenset({"no_such_section"})
        try:
            with self.assertRaises(build_content.BuildError):
                build_content.build(ROOT)
        finally:
            build_content.NOTTINGHAM_CHECKED = saved

    def test_roman_filled_where_listed(self):
        wording = {row[0] for row in build_content.PALI_VARIANTS if row[1] == "wording"}
        self.assertIn("s20-v3", wording)
        self.assertIsNone(self.by_id["s20-v3"]["pali_roman"])
        minor = {row[0] for row in build_content.PALI_VARIANTS if row[1] == "minor"}
        self.assertIn("s05-v1", minor)
        self.assertTrue(self.by_id["s05-v1"]["pali_roman"])  # a minor variant keeps its Roman
        partial = {row[0] for row in build_content.PALI_VARIANTS if row[1] == "partial"}
        self.assertEqual(partial, {"s04-v1"})
        # A partial variant has Roman for the lines the booklet prints: here the five precepts, one
        # unit each (the fifth printed over two lines), with no blank line among them.
        s04 = self.by_id["s04-v1"]["pali_roman"]
        self.assertNotIn("\n\n", s04)
        self.assertEqual(len(s04.split("\n")), 6)
        self.assertTrue(s04.startswith("Pānātipātā"))
        for v in self.verses:
            listed = v["id"] in build_content.NOTTINGHAM_ROMAN and v["id"] not in wording
            if listed or v["id"] in self.new_verses:
                self.assertTrue(v["pali_roman"] and v["pali_roman"].strip(), v["id"])
            else:
                self.assertIsNone(v["pali_roman"], v["id"])

    def test_page_break_continues_the_unit(self):
        # A unit with no Pali (the Roman and English running on after a page break) continues the
        # unit before it, so it adds no stanza break the Pali does not have.
        extras = {f"{s}-v{k}" for s in EXTENDED_SECTIONS for k in range(2, 6)}
        checked = 0
        for s in self.sections:
            for v in s["verses"]:
                if s["id"] in NEW_SECTIONS or v["id"] in extras:
                    checked += 1
                    breaks = v["pali_si"].count("\n\n")
                    for field in ("english", "pali_roman"):
                        self.assertLessEqual((v[field] or "").count("\n\n"), breaks, f"{v['id']} {field}")
        self.assertEqual(checked, 86)
        for verse_id in ("s33-v7", "s33-v8"):
            self.assertNotIn("\n\n", self.by_id[verse_id]["english"], verse_id)

    def test_roman_follows_the_pali_layout(self):
        def stanzas(text):
            return [stanza.split("\n") for stanza in text.split("\n\n")]

        # An existing verse: the Roman takes the app's stanza breaks.
        s03 = stanzas(self.by_id["s03-v1"]["pali_roman"])
        self.assertEqual([len(st) for st in s03], [3, 3, 3])
        self.assertTrue(all(line.strip() for st in s03 for line in st))
        self.assertEqual([len(st) for st in stanzas(self.by_id["s22-v4"]["pali_roman"])], [2, 2, 2])
        # A new verse of one-line units: one line each, no blank line.
        for field in ("pali_si", "pali_roman", "english"):
            lines = self.by_id["s23-v2"][field].split("\n")
            self.assertEqual(len(lines), 3, field)
            self.assertTrue(all(line.strip() for line in lines), field)

    def test_variants_are_listed_and_gate(self):
        for verse_id, kind, description, digest in build_content.PALI_VARIANTS:
            self.assertIn(kind, ("minor", "partial", "wording"), verse_id)
            self.assertIn(verse_id, build_content.NOTTINGHAM_ROMAN, verse_id)
            self.assertTrue(description.strip(), verse_id)
            self.assertRegex(digest, r"^[0-9a-f]{8}$", verse_id)
        original = build_content._namo_sections

        def altered(namo):
            sections = original(namo)
            verse = sections[12]["verses"][0]  # the water offering (new s15), printed in the booklet
            verse["pali_si"] = verse["pali_si"].replace("පානීයං", "පානියං")
            return sections

        build_content._namo_sections = altered
        try:
            with self.assertRaises(build_content.BuildError) as caught:
                build_content.build(ROOT)
        finally:
            build_content._namo_sections = original
        message = str(caught.exception)
        self.assertIn("s15-v1", message)
        self.assertIn("පානියං", message)  # the app's (altered) text
        self.assertIn("පානීයං", message)  # the booklet's text

    def test_a_variant_row_covers_only_its_booklet_text(self):
        """A listed verse whose booklet text changes (say, after a converter change) fails the build."""
        original = build_content._load

        def load(root, name):
            data = original(root, name)
            if name == "nottingham_booklet":
                data = copy.deepcopy(data)
                page = next(p for p in data["pages"] if p["printed_page"] == 5)
                unit = page["units"][4]  # Itipi so (s05-v1, a minor variant)
                unit["pali_si"][0] = unit["pali_si"][0].replace("අරහං", "අරහන්")
            return data

        build_content._load = load
        try:
            with self.assertRaises(build_content.BuildError) as caught:
                build_content.build(ROOT)
        finally:
            build_content._load = original
        message = str(caught.exception)
        self.assertIn("s05-v1", message)
        self.assertIn("අරහන්", message)  # the booklet's changed text
        self.assertIn("ඉතිපි සෝ භගවා අරහං", message)  # the app's text

    def test_partial_must_be_the_first_lines(self):
        app = "අ\nආ\n\nඉ"
        variant = build_content._pali_variant
        rows = build_content.PALI_VARIANTS
        try:
            for booklet, ok in (("අ\nආ", True), ("අ", True), ("ආ", False), ("අ ඉ", False)):
                build_content.PALI_VARIANTS = [("x", "partial", "test", build_content._pali_hash(booklet))]
                if ok:
                    self.assertEqual(variant("x", app, booklet), "partial", booklet)
                else:
                    with self.assertRaises(build_content.BuildError, msg=booklet):
                        variant("x", app, booklet)
        finally:
            build_content.PALI_VARIANTS = rows

    def test_conversion_problem_fails_the_build(self):
        original = build_content._load

        def with_problem(mark_unit):
            def load(root, name):
                data = original(root, name)
                if name == "nottingham_booklet":
                    data = copy.deepcopy(data)
                    page = next(p for p in data["pages"] if p["printed_page"] == 24)
                    if mark_unit:
                        page["units"][1]["pali_si"][0] += "⟦x⟧"
                    else:
                        data["conversion_problems"] = [{"pdf_page": 24, "line": 3, "problem": "⟦x⟧"}]
                return data
            return load

        for mark_unit in (True, False):
            build_content._load = with_problem(mark_unit)
            try:
                with self.assertRaises(build_content.BuildError) as caught:
                    build_content.build(ROOT)
            finally:
                build_content._load = original
            message = str(caught.exception)
            self.assertIn("page 24", message, mark_unit)
            self.assertIn("⟦x⟧", message, mark_unit)

    def test_stanzas(self):
        self.assertEqual(len(self.by_id["s22-v4"]["pali_si"].split("\n\n")), 3)
        self.assertEqual(len(self.by_id["s22-v4"]["english"].split("\n\n")), 3)
        self.assertTrue(self.by_id["s19-v1"]["sinhala"].endswith("\n\nසාධූ! සාධූ! සාධූ!"))
        self.assertEqual(len(self.by_id["s01-v1"]["pali_si"].split("\n")), 1)

    def test_corrections_are_the_listed_ones(self):
        totals = {}
        for v in self.verses:
            for c in v["corrections"]:
                totals[c["from"]] = totals.get(c["from"], 0) + c["count"]
        self.assertEqual(totals, COUNTS)

    def test_printed_slips_are_gone(self):
        namo_text = self.section_text(NAMO_NUMBERS)
        booklet_text = self.section_text(BOOKLET_NUMBERS)
        for form in NAMO_COUNTS:
            self.assertNotIn(form, namo_text)
        for form in BOOKLET_COUNTS:
            self.assertNotIn(form, booklet_text)

    def test_needs_checking(self):
        needs = NEEDS | self.new_verses
        self.assertEqual({v["id"] for v in self.verses if v["check"] == "needs checking"}, needs)
        for v in self.verses:
            if v["id"] in NEEDS:
                self.assertGreaterEqual(len(v["notes"]), 1, v["id"])
            else:
                self.assertEqual(v["notes"], [], v["id"])
                if v["id"] not in needs:
                    self.assertEqual(v["check"], "checked against source", v["id"])
        for s in self.sections:
            expected = "needs checking" if any(v["id"] in needs for v in s["verses"]) else "checked against source"
            self.assertEqual(s["check"], expected, s["id"])

    def english(self, verse_id):
        return self.by_id[verse_id]["english"]

    def test_reflow_short_sections(self):
        line = "Homage to the Blissful One, the Worthy One, the Fully Enlightened One."
        self.assertEqual(self.english("s02-v1").split("\n"), [line] * 3)
        self.assertEqual(len(self.english("s03-v1").split("\n")), 11)
        lines = self.english("s04-v1").split("\n")
        self.assertEqual(len(lines), 5)
        self.assertEqual(lines[0], "I undertake the training rule to abstain from killing living beings.")
        self.assertEqual(lines[-1], "I undertake the training rule to abstain from intoxicants and harmful drugs.")

    def test_reflow_explanations(self):
        s05 = self.english("s05-v1").split("\n")
        self.assertEqual(len(s05), 10)
        self.assertEqual(s05[0], "Such indeed is the Blessed One:")
        self.assertEqual(s05[1], '"Araham" - eradicated greed, hatred, delusion, craving, and is free of all taints.')
        self.assertTrue(all(ln.startswith('"') for ln in s05[1:]))
        s06 = self.english("s06-v1").split("\n")
        self.assertEqual(len(s06), 6)
        self.assertTrue(all(ln.startswith('"') for ln in s06))
        s07 = self.english("s07-v1").split("\n")
        self.assertEqual(len(s07), 5)
        self.assertEqual(s07[2], '"Nayapatipanno" - The Noble Order understands the First Noble Truth '
                                 'and are practising to eradicate suffering')
        self.assertTrue(s07[4].startswith("In Buddha’s Order are the 8 kinds of individuals:"))
        self.assertIn("the position of Once-Returner, the Once-Returner; the one striving to reach "
                      "the Non- returner position", s07[4])

    def test_verse_english_keeps_its_lines(self):
        base = baseline_of("english")
        for old_id in ("s07-v1", "s08-v1", "s10-v1", "s18-v4", "s19-v1"):
            self.assertEqual(self.english(new_id(old_id)), base[old_id], old_id)

    def test_footnote_is_one_line(self):
        self.assertTrue(self.english("s17-v1").endswith(
            "\n\n(Gilan pasa – permissible food & drinks for Buddhist monks and nuns from noon to the "
            "following morning such as fruit juices, sugar candy)"))
        self.assertEqual(len(self.english("s17-v1").split("\n")), 6)

    def test_reflow_changes_only_whitespace(self):
        base = baseline_of("english")
        checked = 0
        for old_id, old_english in base.items():
            v = self.by_id[new_id(old_id)]
            if old_english is None:
                if v["id"] not in NOTTINGHAM_ENGLISH:
                    self.assertIsNone(v["english"], v["id"])
                continue
            checked += 1
            self.assertEqual(re.sub(r"\s+", "", v["english"]), re.sub(r"\s+", "", old_english), v["id"])
        self.assertEqual(checked, 21)

    def test_existing_verses_unchanged_through_the_map(self):
        for field in ("pali_si", "sinhala", "english_source", "english_kind", "notes", "corrections"):
            base = baseline_of(field)
            self.assertEqual(len(base), 28)
            for old_id, value in base.items():
                verse_id = new_id(old_id)
                if field in ("english_source", "english_kind") and verse_id in NOTTINGHAM_ENGLISH:
                    self.assertIsNone(value, old_id)  # the booklet fills an English that was missing
                    continue
                actual = self.by_id[verse_id][field]
                if verse_id in LATER_CORRECTIONS and field in ("pali_si", "corrections"):
                    printed, corrected = LATER_CORRECTIONS[verse_id]
                    if field == "pali_si":
                        self.assertEqual(actual, value.replace(printed, corrected), verse_id)
                    else:
                        self.assertEqual([c["from"] for c in actual], [c["from"] for c in value] + [printed])
                    continue
                self.assertEqual(actual, value, f"{old_id} -> {verse_id} {field}")
        base = baseline_of("pali_si")
        later = {new_id(k): v for k, v in base.items()}
        for verse_id, (printed, corrected) in LATER_CORRECTIONS.items():
            later[verse_id] = later[verse_id].replace(printed, corrected)
        self.assertEqual(collections.Counter(later.values()),
                         collections.Counter(self.by_id[k]["pali_si"] for k in later))

    def test_reflow_function(self):
        reflow = build_content._reflow_prose
        self.assertEqual(reflow('A b\nc.\nd e\n\nf\n"g" h-\ni j'), 'A b c.\nd e\n\nf\n"g" h-i j')
        with self.assertRaises(build_content.BuildError):
            build_content._check_whitespace_only("a b", "a c")

    def test_nottingham_prose_pages_reflowed(self):
        self.assertEqual(build_content.NOTTINGHAM_PROSE_PAGES, range(17, 35))
        # Page 19-20: a line ending mid-sentence joins the next.
        self.assertEqual(self.english("s25-v1").split("\n"), [
            "Having compared oneself with others, have a desire for the happiness of all living beings.",
            "Having seen it, one should develop loving kindness towards all living beings."])
        # Page 10 (before the prose pages): the booklet's lines stay, one English line per Pali line.
        self.assertEqual(self.english("s08-v5").split("\n"), [
            "Homage to the teachings of the Buddha, - to earnestness the last exhortation,",
            "to all the shrines, -  to my preceptors and teachers",
            "By dint of this salutation, - may my mind be free from evil."])
        # A verse line that starts with a capital letter stays a line.
        self.assertEqual(len(self.english("s31-v2").split("\n")), 2)

    def test_nottingham_reflow_function(self):
        reflow = build_content._reflow_wrapped
        self.assertEqual(reflow("all living\nbeings.\nHaving seen it;\nthen more,\nAnd (so)\nend"),
                         "all living beings.\nHaving seen it;\nthen more,\nAnd (so) end")
        self.assertEqual(reflow("a,\nb\n\nc\nd"), "a, b\n\nc d")
        with self.assertRaises(build_content.BuildError):
            build_content._check_whitespace_only("all living beings.", "all living beings,")

    def test_whole_word_correction(self):
        """ම විසින් is corrected only where ම stands alone, never at the end of a longer word."""
        row = next(r for r in build_content.CORRECTIONS if r[1] == "ම විසින්")
        printed, corrected = row[1], row[2]
        letter = chr(0x0D9A)  # a Sinhala letter, to make ම the end of a longer word
        alone = f"{printed}\n{printed}"
        inside = f"{letter}{printed}"
        verse = {"pali_si": inside, "sinhala": alone, "corrections": []}
        totals = {printed: 0}
        build_content._correct(verse, [row], totals)
        self.assertEqual(verse["sinhala"], f"{corrected}\n{corrected}")
        self.assertEqual(verse["pali_si"], inside)
        self.assertEqual(totals[printed], 2)
        self.assertEqual([(c["field"], c["count"]) for c in verse["corrections"]], [("sinhala", 2)])

    def test_normalise_pali(self):
        self.assertEqual(build_content._normalise_pali("අ, ආ – (ඉ)‍.\n ඊ!‌"), "අආඉඊ")

    def test_nothing_from_outside(self):
        rendered = build_content.render(self.data).decode("utf-8")
        self.assertNotIn("Related Resources", rendered)
        self.assertNotIn("With Devas", rendered)
        self.assertNotIn("⟦", rendered)
        self.assertNotIn("සාදු! සාදු! සාදු!", rendered)
        for s in self.sections:
            self.assertFalse(s["heading"][:1].isdigit(), s["heading"])
            self.assertNotIn("  ", s["heading"])

    def test_file_is_reproducible(self):
        first = build_content.render(build_content.build(ROOT))
        second = build_content.render(build_content.build(ROOT))
        self.assertEqual(first, second)
        self.assertEqual(first, ASSET.read_bytes())


if __name__ == "__main__":
    unittest.main()
