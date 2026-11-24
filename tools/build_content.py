"""Build the app's content file, assets/content/namaskaraya_to_pin_dima.json,
from the text already stored in content/extracted/ (design §5).

Usage: python -I -X utf8 tools/build_content.py <project_root> [--check]

Every line of verse comes out of the stored sources by the rules below. The only
changes made to it are the spelling corrections of design §5.3, each applied the
number of times §5.3 gives; any other count, or a missing anchor, stops the build.
(The one other change: a Nottingham booklet line marked "(Three times)" loses the bracketed
instruction printed after its Pali and stands three times instead; see THREE_TIMES_NOTE.)
--check builds in memory and compares with the file instead of writing it.
"""
from __future__ import annotations

import hashlib
import importlib.util
import json
import pathlib
import re
import sys

OUTPUT = pathlib.Path("assets/content/namaskaraya_to_pin_dima.json")
# Written by tools/assemble_wandana_audio.py: each recorded section's file, label and verse times.
AUDIO_TIMES = pathlib.Path("content/wandana_audio.json")
HOSTED = pathlib.Path("hosted")
TITLE = "Buddha Wandanawa"
SUBTITLE = "බුද්ධ වන්දනාව"
NOT_NAMED = "not named by the source"
BRISBANE_TRANSLATOR = "prepared by Cynthia Gunawardana"
CHECKED = "checked against source"
NEEDS_CHECKING = "needs checking"

NAMO_SLUG = "buddha-puja"
NAMO_LOCATOR = "https://namo.lk/buddha-puja/"
NAMO_COLLECTED = "2026-11-09"
NAMO_STOP_HEADING = "Related Resources"
BOOKLET_NAME = "paritha.org booklet (Wandana Gatha)"
BOOKLET_COLLECTED = "2026-11-09"
MAHAMEVNAWA_NAME = "Mahamevnawa \"Vandana\" booklet (Mahamevna Bhavana Asapuwa, Markham ON)"
MAHAMEVNAWA_COLLECTED = "2026-11-09"
BRISBANE_NAME = ("\"Daily Buddha Vandana\", Yasodhara Dhamma School, "
                 "Sri Lankarama Maha Viharaya, Ellen Grove, Brisbane")
BRISBANE_COLLECTED = "2026-11-10"
NOTTINGHAM_NAME = "Shanthi Vihara, Nottingham — Evening Puja and Chanting"
NOTTINGHAM_FILE = "evening_puja_and_chanting.pdf (supplied by the app's owner, 2026-11-17)"
NOTTINGHAM_COLLECTED = "2026-11-17"

# The reading's 33 sections in the Nottingham booklet's order: ("namo", heading index on the
# namo.lk page), ("booklet", the paritha.org section 18 or 19 of design §5.1) or
# ("nottingham", a key of NOTTINGHAM_SECTIONS). Section numbers and ids follow this list.
ORDER: list[tuple[str, object]] = [
    ("nottingham", "bowing"),
    ("namo", 0), ("namo", 1), ("namo", 2), ("namo", 3), ("namo", 4), ("namo", 5),
    ("nottingham", "recollection"),
    ("namo", 6), ("namo", 7), ("namo", 8), ("namo", 9), ("namo", 10), ("namo", 11), ("namo", 12),
    ("namo", 13), ("namo", 14), ("namo", 15), ("namo", 16),
    ("booklet", 19),
    ("nottingham", "relatives"),
    ("booklet", 18),
    ("nottingham", "aspirations"),
    ("nottingham", "buddhanussati"),
    ("nottingham", "mettanussati"),
    ("nottingham", "asubhanussati"),
    ("nottingham", "marananussati"),
    ("nottingham", "samvega"),
    ("nottingham", "anuloma"),
    ("nottingham", "patiloma"),
    ("nottingham", "true_refuge"),
    ("nottingham", "three_characteristics"),
    ("nottingham", "metta"),
]

# The Nottingham booklet's units, by (printed page, unit index) in content/extracted/
# nottingham_booklet.json (listed page by page in content/review/05_evening_puja_nottingham.md).
# A verse is a list of units: its Pali is the units' Pali, its Roman their Roman and its English
# their English (lines joined by "\n" within a unit, units by "\n\n"; a unit with none adds nothing,
# so a verse whose Pali ends one page and whose Roman starts the next is one verse; a unit with no
# Pali continues the unit before it and adds no break, see _unit_lines).
# Two heading units are joined by HEADING_JOINER. A section's printed pages are those of its
# verses' units (_pages_of).
NOTTINGHAM_SECTIONS: dict[str, dict] = {
    "bowing": {"heading": (3, 0),
               "verses": [[(3, 1)], [(3, 2)], [(3, 3)], [(3, 4)], [(3, 5)]]},
    "recollection": {"heading": (9, 0),
                     "verses": [[(9, 1)], [(9, 2)], [(9, 3)], [(9, 4)], [(10, 0)], [(10, 1)], [(10, 2)],
                                [(11, 0)]]},
    "relatives": {"heading": (14, 5), "verses": [[(14, 6)]]},
    "aspirations": {"heading": (16, 2),
                    "verses": [[(16, 3)], [(16, 4), (16, 5), (16, 6)], [(16, 7), (17, 0)], [(17, 1)]]},
    "buddhanussati": {"heading": (17, 2),
                      "verses": [[(17, 3)], [(17, 4)], [(17, 5)], [(18, 0)], [(18, 1)], [(18, 2)], [(18, 3)],
                                 [(18, 4), (19, 0)], [(19, 1)], [(19, 2)], [(19, 3)]]},
    "mettanussati": {"heading": (19, 4),
                     "verses": [[(19, 5), (20, 0)], [(20, 1)], [(20, 2)], [(20, 3)], [(20, 4)]]},
    "asubhanussati": {"heading": (21, 0),
                      "verses": [[(21, 1)], [(21, 2)], [(21, 3)], [(21, 4)], [(21, 5), (22, 0)], [(22, 1)]]},
    "marananussati": {"heading": (22, 2),
                      "verses": [[(22, 3)], [(22, 4)], [(22, 5)], [(23, 0)], [(23, 1)], [(23, 2)], [(23, 3)]]},
    "samvega": {"heading": (24, 0), "verses": [[(24, 1)], [(24, 2)], [(24, 3)]]},
    "anuloma": {"heading": [(25, 0), (25, 1)], "verses": [[(25, 2)]]},
    "patiloma": {"heading": [(25, 0), (26, 0)], "verses": [[(26, 1)]]},
    "true_refuge": {"heading": (27, 0),
                    "verses": [[(27, 1)], [(27, 2)], [(27, 3)], [(27, 4)], [(28, 0)]]},
    "three_characteristics": {"heading": (28, 1),
                              "verses": [[(28, 2)], [(28, 3)], [(28, 4)], [(29, 0)], [(29, 1)], [(29, 2)]]},
    "metta": {"heading": (29, 3),
              "verses": [[(29, 4)], [(30, 0)], [(30, 1)], [(30, 2)], [(30, 3), (31, 0)], [(31, 1)],
                         [(31, 2), (32, 0)], [(32, 1), (33, 0)], [(33, 1)], [(33, 2)], [(34, 0)]]},
}
HEADING_JOINER = " – "
# A unit carrying this note is chanted three times: its Pali line loses the printed instruction in
# brackets at its end and, like its Roman line, stands three times in the verse (as Namo tassa does).
THREE_TIMES_NOTE = "(Three times)"
# The booklet's printed pages whose English is prose set to the page width: each unit's English is
# re-set with _reflow_wrapped (whitespace only). Pages 3-16 keep the booklet's lines, one English
# line to a Pali line.
NOTTINGHAM_PROSE_PAGES = range(17, 35)

# The booklet's verses 2-5 of the Buddha, Dhamma and Sangha vandanā, added after the namo.lk verse.
NOTTINGHAM_VERSES_INTO: dict[str, list[list[tuple[int, int]]]] = {
    "s05": [[(5, 5)], [(5, 6)], [(6, 0)], [(6, 1)]],
    "s06": [[(6, 4)], [(6, 5)], [(7, 0)], [(7, 1)]],
    "s07": [[(8, 1)], [(8, 2)], [(8, 3)], [(8, 4)]],
}

# The owner's clearing table: the booklet sections read against the printed booklet and found right.
# A key of NOTTINGHAM_SECTIONS or of NOTTINGHAM_VERSES_INTO ("s05", "s06", "s07"). A section listed
# here loses its note and its booklet verses are "checked against source" (a verse note of NEEDS
# still keeps its section "needs checking"). To clear a section, add its key and rebuild.
NOTTINGHAM_CHECKED: frozenset[str] = frozenset()

# Existing verses the booklet also prints: the units whose Roman fills pali_roman. Their Pali is
# compared with the app's (see PALI_VARIANTS).
NOTTINGHAM_ROMAN: dict[str, list[tuple[int, int]]] = {
    "s02-v1": [(3, 6)],
    "s03-v1": [(3, 7), (3, 8), (4, 0), (4, 1), (4, 2), (4, 3), (4, 4), (4, 5), (4, 6)],
    "s04-v1": [(4, 8), (4, 9), (5, 0), (5, 1), (5, 2)],
    "s05-v1": [(5, 4)],
    "s06-v1": [(6, 3)],
    "s07-v1": [(7, 3), (8, 0)],
    "s09-v1": [(11, 2)],
    "s10-v1": [(11, 4)],
    "s10-v2": [(11, 5), (12, 0)],
    "s12-v1": [(12, 3)],
    "s13-v2": [(12, 5)],
    "s14-v1": [(12, 7)],
    "s14-v2": [(13, 0)],
    "s15-v1": [(13, 2)],
    "s17-v1": [(13, 4)],
    "s19-v1": [(13, 6), (14, 0)],
    "s20-v1": [(14, 2)],
    "s20-v2": [(14, 3)],
    "s20-v3": [(14, 4)],
    "s22-v1": [(15, 1)],
    "s22-v2": [(15, 2)],
    "s22-v3": [(15, 3)],
    "s22-v4": [(15, 4), (15, 5), (16, 0), (16, 1)],
}
# Existing verses without English whose English comes from the booklet.
NOTTINGHAM_ENGLISH: dict[str, list[tuple[int, int]]] = {
    "s19-v1": [(13, 6), (14, 0)],
    "s22-v2": [(15, 2)],
    "s22-v3": [(15, 3)],
}
# Sinhala meanings reused from the paritha.org booklet: verse -> (printed page, (first, last small line)).
PARITHA_SINHALA: dict[str, tuple[int, tuple[int, int]]] = {
    "s08-v6": (3, (10, 12)),
    "s08-v7": (3, (21, 23)),
    "s08-v8": (3, (36, 38)),
    "s23-v1": (38, (18, 19)),
}
NEW_SECTION_NOTE = "Converted from the booklet's FM font; to be read against {pages}."
EXTENDED_SECTION_NOTE = "Verses 2–5 converted from the booklet's FM font; to be read against {pages}."

# Where the booklet's Pali differs from the app's for a verse both print (after _normalise_pali).
# (verse id, "minor" | "partial" | "wording", what differs, booklet hash). minor: vowel length, a
# word split, a single letter; partial: the booklet prints the app's first lines and not the rest
# (checked); wording: different words. The hash is the first 8 hex digits of the sha256 of the
# booklet's normalised Pali (_pali_hash), so a row covers only the text it was written for. A
# difference not listed here stops the build. The app's Pali is never changed; pali_roman is filled
# for a match, a minor or a partial variant and left empty for wording.
PALI_VARIANTS: list[tuple[str, str, str, str]] = [
    ("s04-v1", "partial", "the app ends with a sixth line, තිසරණේන සද්ධිං පංචසීලං සමාදියාමි, "
                          "which the booklet does not print", "5d5093e4"),
    ("s05-v1", "minor", "සාරථී/සාරථි, භගවාතී/භගවාති (vowel length)", "a5fe8022"),
    ("s06-v1", "minor", "සන්දිට්ඨිකො/සන්දිට්ඨිකෝ, ඕපනයිකො/ඕපනයිකෝ, වේදිතබ්බො/වේදිතබ්බෝ, "
                        "විඤ්ඤුහීති/විඤ්ඤූහීති (vowel length)", "3f096e67"),
    ("s07-v1", "minor", "භගවතො/භගවතෝ (four times, vowel length); ආහුනෙයියෝ/ආහුනෙය්‍යෝ, "
                        "පාහුනෙයියෝ/පාහුනෙය්‍යෝ, දක්ඛිනෙයියෝ/දක්ඛිණෙය්‍යෝ, "
                        "අඤ්ජලිකරණීයෝ/අඤ්ජලිකරණීය්‍යෝ (a single letter or sign)", "06c44ce2"),
    ("s10-v1", "minor", "නිසින්නෝච/නිසින්නෝව (a single letter)", "5d443d90"),
    ("s10-v2", "minor", "මහාබෝධී/මහා බෝධි (a word split and vowel length), තෙ/තේ (vowel length)",
     "eb5cd60b"),
    ("s12-v1", "wording", "the app begins ගන්ධ තේල පදිත්තේන (the owner's correction, 2026-11-23); "
                          "the booklet begins ඝණසාරප්ප දිත්තේන", "ca99e96f"),
    ("s14-v2", "minor", "ලභාමි/ලබාමි (a single letter), ඉදම්මේ/ඉදං මේ (a word split)", "7027547c"),
    ("s20-v3", "wording", "the app ends පුඤ්ඤක්ඛෙත්තං අනුත්තරං; the booklet ends සුපටිපන්න අනුත්තර",
     "ef8a7c3a"),
]
PALI_PUNCTUATION = ".,;:!?\"'–-()"

# Lines further apart than this (in PDF points) start a new stanza.
STANZA_GAP = 22.0

# Design §5.3. (source, printed form, corrected form, places, reason)
CORRECTIONS = [
    ("namo", "ගච්චාමි", "ගච්ඡාමි", 9, "20 uses elsewhere on namo.lk, 9 in the booklet"),
    ("namo", "විඡ්ඡාචරණ", "විජ්ජාචරණ", 1, "18 elsewhere on namo.lk, 4 in the booklet"),
    ("namo", "සමාදියාමී", "සමාදියාමි", 4,
     "10 elsewhere on namo.lk, 5 in the booklet; the page itself uses it twice"),
    ("namo", "සුමාමේරය", "සුරාමේරය", 1,
     "namo.lk's own \"ten precepts\" page and the booklet both print සුරාමේරය; "
     "the page's own Sinhala meaning for the line says සුරාපානය"),
    ("namo", "ධානේසු", "ඨානේසු", 1,
     "the owner's word, 2026-11-10 (\"ඨානේසු is the correct\"); namo.lk's own Sinhala meaning "
     "says \"in all places\" and the Brisbane booklet prints \"Sabbatane\""),
    ("namo", "අධිවාසේ තුනෝ", "අධිවාසේතු නෝ", 1,
     "spacing only; the page itself prints it this way 3 times, the booklet 11"),
    ("namo", "බෝදි", "බෝධි", 1, "9 times on the page itself, 15 elsewhere on namo.lk, 13 in the booklet"),
    ("namo", "ඝනසාරප්ප දිත්තේන", "ගන්ධ තේල පදිත්තේන", 1,
     "the owner's word, 2026-11-23 (\"ගන්ධ තේල පදිත්තේන … exact same, only the first changes\"): "
     "Ven. Na Uyane Ariyadhamma Thero chants the lamp offering this way, and his recording plays it"),
    ("booklet", "රුස්කර", "රැස්කර", 3, "රැස් 6 times elsewhere in the booklet and 8 on namo.lk"),
    ("booklet", "පුණ්ය", "පුණ්‍ය", 3, "the booklet's own other use; namo.lk"),
    ("booklet", "භූතයා්", "භූතයෝ", 1, "3 times elsewhere in the booklet, 2 on namo.lk"),
    ("booklet", "ම විසින්", "මා විසින්", 3, "5 elsewhere in the booklet, 42 on namo.lk"),
    ("booklet", "සාසණ", "සාසන", 1, "8 elsewhere in the booklet, 5 on namo.lk"),
    ("booklet", "පුංඤ්ඤකෙත්තං", "පුඤ්ඤක්ඛෙත්තං", 1, "2 elsewhere in the booklet, 6 on namo.lk"),
    ("booklet", "අනුත්ථරං", "අනුත්තරං", 1, "3 elsewhere in the booklet, 10 on namo.lk"),
    ("booklet", "දේවානාගා", "දේවා නාගා", 3, "spacing only; both sources print two words elsewhere"),
]
# Forms that match only as a whole word (here: ම must not be the end of a longer word).
WHOLE_WORD = {"ම විසින්"}
SINHALA_LETTER = "඀-෿‍"

# The paritha.org booklet's sections 18-19 of design §5.1 (now s22 and s20, see ORDER), by
# printed page and line index (Task 4).
BOOKLET_SECTION_HEADINGS = {18: (37, 0), 19: (37, 32)}
BOOKLET_HEADING_SPELLING = ("පින්දීම", "පින් දීම", "owner's spelling")
BOOKLET_VERSES = [
    # (verse id, printed page, large-line stanzas, small lines)
    ("s22-v1", 37, [(2, 3)], (5, 6)),
    ("s22-v2", 37, [(8, 9)], (11, 12)),
    ("s22-v3", 37, [(14, 15)], (17, 18)),
    ("s22-v4", 37, [(20, 21), (23, 24), (26, 27)], (29, 30)),
    ("s20-v1", 37, [(34, 35)], (37, 38)),
    ("s20-v2", 38, [(0, 1)], (3, 4)),
    ("s20-v3", 38, [(6, 7)], (9, 11)),
]

# English from the Mahamevnawa PDF: right-column lines within the y ranges.
# (verse id, [(pdf page, y from, y to), ...], first line starts with, last line ends with, kind)
MAHAMEVNAWA = [
    ("s02-v1", [(2, 123.7, 199.0)], "Homage to the Blissful One", "Fully Enlightened One.", "translation"),
    ("s03-v1", [(2, 259.5, 410.1)], "I go to the Buddha for refuge.",
     "A third time, I go to the Sangha for refuge.", "translation"),
    ("s04-v1", [(2, 470.6, 606.1)], "I undertake the training rule to abstain from killing",
     "intoxicants and harmful drugs.", "translation"),
    ("s05-v1", [(3, 123.6, 500.8)], "Such indeed is the Blessed One:",
     "holds these great, extra-ordinary qualities.", "explanation"),
    ("s06-v1", [(4, 123.9, 320.2)], "\"Svakkhato\" -", "the wise to understand and realize.", "explanation"),
    ("s07-v1", [(4, 389.7, 661.2)], "\"Supatipanno\" - The Order of the Blessed One are",
     "hospitality, worthy of respect and worship.", "explanation"),
    ("s22-v4", [(16, 665.7, float("inf")), (17, 0.0, 253.0)], "May mighty deities and nagas",
     "long protect myself and others.", "translation"),
    ("s20-v1", [(17, 639.3, 684.4)], "If, due to negligence, I have done some",
     "Perfect one of vast wisdom.", "translation"),
    ("s20-v2", [(18, 102.1, 147.3)], "If, due to negligence, I have done some",
     "Visible and unaffected by time.", "translation"),
    ("s20-v3", [(18, 177.4, 226.6)], "If, due to negligence, I have done some",
     "Practising well and supreme.", "translation"),
]

# Sections 2-7 are prose set in a narrow column and are re-set as sentences; the others are verse,
# whose line breaks are the translator's and stay.
MAHAMEVNAWA_PROSE = {"s02-v1", "s03-v1", "s04-v1", "s05-v1", "s06-v1", "s07-v1"}

# English from the Brisbane booklet: non-bold lines of one block, first anchor through last anchor.
# (verse id, pdf page, block, first line starts with, last line starts with)
BRISBANE = [
    ("s09-v1", 8, 4, "I salute every chetiya", "And all images of the Buddha."),
    ("s10-v1", 9, 1, "Seated at whose base,", "That very bodhi tree do I adore"),
    ("s10-v2", 9, 1, "These great trees of enlightenment", "May there be homage to you."),
    ("s12-v1", 10, 1, "With lights brightly shining", "(*three worlds"),
    ("s13-v1", 10, 2, "With perfumed incense,", "Who dispels the darkness"),
    ("s13-v2", 10, 2, "Fragrant of voice and form,", "With fragrance I worship."),
    ("s14-v1", 9, 1, "This mass of flowers fresh", "I offer at the sacred lotus"),
    ("s14-v2", 9, 2, "I worship the Buddha with these flowers;", "Our body will undergo decay."),
    ("s15-v1", 11, 2, "O Lord! The blessed one", "Out of great compassion on us."),
    ("s17-v1", 11, 3, "O Lord! The blessed one", "from noon to the following morning"),
    ("s22-v1", 12, 1, "May all devas share this merit", "Of happiness and prosperity."),
]

# Verses marked "needs checking", with the wording of design §5.2 / §5.3.
NEEDS = {
    "s13-v1": [
        "namo.lk prints the second line as \"සුගන්ධිනාහං ගන්ධේන – පූජයාමි තථාගතං\", the same line as "
        "in the next verse. The Brisbane booklet reads \"Pujaye Pujaniyanam tam / Puja bhajana "
        "muttamam\", and namo.lk's own Sinhala meaning translates that reading. No stored source has "
        "that line in Sinhala letters, so the Pali stays as namo.lk prints it and is not changed "
        "without the owner's word.",
        "The Brisbane English for this verse also ends with a line that belongs to the lamp verse "
        "(\"Who dispels the darkness\"); it is kept as printed.",
    ],
    "s14-v2": [
        "The app's Pali reads \"ලභාමි මොක්ඛං\" (the paritha.org booklet reads the same); the "
        "Brisbane booklet reads \"cha hothu mokkam\" and translates that.",
    ],
    "s22-v4": [
        "The app's Pali reads \"ලෝක සාසනං\"; Mahamevnawa reads \"sasanam\". (The Brisbane booklet "
        "reads \"loka sasanam\", as the app does.)",
    ],
    "s20-v3": [
        "The app's Pali ends \"පුඤ්ඤක්ඛෙත්තං අනුත්තරං\"; Mahamevnawa ends \"Supatipanna anuttara\".",
    ],
}


class BuildError(Exception):
    pass


def _load(root: pathlib.Path, name: str) -> dict:
    with open(root / "content" / "extracted" / f"{name}.json", encoding="utf-8") as f:
        return json.load(f)


def _strip_lines(text: str) -> str:
    return "\n".join(line.strip(" ") for line in text.split("\n"))


def _verse(verse_id: str | None, pali_si: str, sinhala: str | None) -> dict:
    return {"id": verse_id, "source": None, "pali_si": pali_si, "pali_roman": None, "sinhala": sinhala,
            "sinhala_source": None, "english": None, "english_source": None, "english_kind": None,
            "check": CHECKED, "notes": [], "corrections": []}


def _namo_sections(namo: dict) -> list[dict]:
    items = [it for it in namo["items"] if it["slug"] == NAMO_SLUG]
    if len(items) != 1:
        raise BuildError(f"namo.lk: expected one item {NAMO_SLUG!r}, found {len(items)}")
    source = {"name": "namo.lk", "locator": NAMO_LOCATOR, "collected": NAMO_COLLECTED, "translator": NOT_NAMED}
    sections: list[dict] = []
    blocks = items[0]["blocks"]
    i = 0
    while i < len(blocks):
        block = blocks[i]
        role, text = block["role"], block["text"]
        if role == "heading":
            heading = re.sub(r"^\d+\.\s*", "", text.strip(" "))
            if heading == NAMO_STOP_HEADING:
                break
            sections.append({"heading": heading, "source": source, "corrections": [], "verses": [],
                             "origin": "namo"})
            i += 1
        elif role == "pali":
            if not sections:
                raise BuildError(f"namo.lk block {i}: Pali before the first heading")
            if i + 1 >= len(blocks) or blocks[i + 1]["role"] != "sinhala_meaning":
                raise BuildError(f"namo.lk block {i}: Pali not followed by a Sinhala meaning")
            verses = sections[-1]["verses"]
            verse_id = f"s{len(sections):02d}-v{len(verses) + 1}"
            verses.append(_verse(verse_id, _strip_lines(text), _strip_lines(blocks[i + 1]["text"])))
            i += 2
        elif role == "sinhala_meaning":
            # a second Sinhala meaning in a row joins the verse before it
            if not sections or not sections[-1]["verses"]:
                raise BuildError(f"namo.lk block {i}: Sinhala meaning with no verse before it")
            verse = sections[-1]["verses"][-1]
            verse["sinhala"] += "\n\n" + _strip_lines(text)
            i += 1
        else:
            raise BuildError(f"namo.lk block {i}: unexpected role {role!r}")
    else:
        raise BuildError(f"namo.lk: heading {NAMO_STOP_HEADING!r} not found")
    return sections


def _booklet_line(pages: dict, page: int, index: int, kind: str) -> str:
    line = pages[page][index]
    if line["kind"] != kind:
        raise BuildError(f"booklet page {page} line {index}: expected {kind!r}, found {line['kind']!r}")
    return line["text"]


def _booklet_sections(booklet: dict) -> dict[int, dict]:
    pages = {p["printed_page"]: p["lines"] for p in booklet["pages"] if p["printed_page"] in (37, 38)}
    url = booklet["source"]["url"]
    sections = {}
    for number, (page, index) in BOOKLET_SECTION_HEADINGS.items():
        heading = _booklet_line(pages, page, index, "subheading")
        locator = f"{url}, printed page 37" if number == 18 else f"{url}, printed pages 37–38"
        sections[number] = {
            "heading": heading,
            "source": {"name": BOOKLET_NAME, "locator": locator, "collected": BOOKLET_COLLECTED,
                       "translator": NOT_NAMED},
            "corrections": [], "verses": [], "origin": "booklet"}
    printed, corrected, reason = BOOKLET_HEADING_SPELLING
    heading = sections[18]["heading"]
    if heading.count(printed) != 1:
        raise BuildError(f"section 18 heading {heading!r} does not contain {printed!r} once")
    sections[18]["heading"] = heading.replace(printed, corrected)
    sections[18]["corrections"].append(
        {"field": "heading", "from": printed, "to": corrected, "count": 1, "reason": reason})
    for verse_id, page, stanzas, (small_from, small_to) in BOOKLET_VERSES:
        pali = "\n\n".join(
            "\n".join(_booklet_line(pages, page, k, "large") for k in range(a, b + 1)) for a, b in stanzas)
        sinhala = " ".join(_booklet_line(pages, page, k, "small") for k in range(small_from, small_to + 1))
        origin, number = ORDER[int(verse_id[1:3]) - 1]
        if origin != "booklet":
            raise BuildError(f"{verse_id}: ORDER puts no paritha.org section at that number")
        sections[number]["verses"].append(_verse(verse_id, pali, sinhala))
    return sections


def _correct(verse: dict, scope_rows: list[tuple], totals: dict) -> None:
    for _, printed, corrected, _, reason in scope_rows:
        if printed in WHOLE_WORD:
            pattern = re.compile(f"(?<![{SINHALA_LETTER}]){re.escape(printed)}")
        else:
            pattern = re.compile(re.escape(printed))
        for field in ("pali_si", "sinhala"):
            new_text, count = pattern.subn(corrected, verse[field])
            if count:
                verse[field] = new_text
                verse["corrections"].append(
                    {"field": field, "from": printed, "to": corrected, "count": count, "reason": reason})
                totals[printed] += count


def _join_by_gap(lines: list[tuple[int, float, str]]) -> str:
    """Join (page, y, text) lines with \\n; a gap over STANZA_GAP on one page becomes \\n\\n."""
    out = lines[0][2]
    for (page_a, y_a, _), (page_b, y_b, text) in zip(lines, lines[1:]):
        out += ("\n\n" if page_a == page_b and y_b - y_a > STANZA_GAP else "\n") + text
    return out


def _check_whitespace_only(before: str, after: str) -> None:
    if re.sub(r"\s+", "", before) != re.sub(r"\s+", "", after):
        raise BuildError("reflowing English changed more than line breaks and spaces")


def _reflow_prose(text: str) -> str:
    """Re-set column-wrapped prose as sentences: a source line starts a new line only when it is the
    first of its paragraph, follows a line ending in '.' or ':', or itself starts with a double quote.
    Otherwise it joins the line before with one space, or with none after a letter and '-'."""
    paragraphs = []
    for paragraph in text.split("\n\n"):
        out = ""
        for k, line in enumerate(paragraph.split("\n")):
            if k == 0:
                out = line
            elif out.endswith((".", ":")) or line.startswith('"'):
                out += "\n" + line
            elif re.search(r"[^\W\d_]-$", out):
                out += line
            else:
                out += " " + line
        paragraphs.append(out)
    result = "\n\n".join(paragraphs)
    _check_whitespace_only(text, result)
    return result


def _reflow_wrapped(text: str) -> str:
    """Join the lines of a paragraph that the booklet's page width broke mid-sentence: a line that
    ends without '.', '!', '?', ':' or ';' and is followed by a line starting with a lower-case
    letter joins it with one space. Other line breaks stay (the booklet's verse lines)."""
    paragraphs = []
    for paragraph in text.split("\n\n"):
        lines: list[str] = []
        for line in paragraph.split("\n"):
            if lines and not lines[-1].endswith((".", "!", "?", ":", ";")) and line[:1].islower():
                lines[-1] += " " + line
            else:
                lines.append(line)
        paragraphs.append("\n".join(lines))
    result = "\n\n".join(paragraphs)
    _check_whitespace_only(text, result)
    return result


def _join_footnote(text: str) -> str:
    """Join each paragraph that is a '( ... )' footnote into one line."""
    paragraphs = []
    for paragraph in text.split("\n\n"):
        lines = paragraph.split("\n")
        if lines[0].startswith("(") and lines[-1].endswith(")"):
            paragraph = " ".join(lines)
        paragraphs.append(paragraph)
    result = "\n\n".join(paragraphs)
    _check_whitespace_only(text, result)
    return result


def _mahamevnawa_english(maha: dict) -> dict:
    pages = {p["pdf_page"]: p["right_column"] for p in maha["pages"]}
    url = maha["source"]["url"]
    result = {}
    for verse_id, ranges, first, last, kind in MAHAMEVNAWA:
        lines = []
        for page, y_from, y_to in ranges:
            lines += [(page, ln["y"], ln["text"]) for ln in sorted(pages[page], key=lambda ln: ln["y"])
                      if y_from <= ln["y"] <= y_to and not ln["bold"]]
        if not lines or not lines[0][2].startswith(first):
            raise BuildError(f"{verse_id}: Mahamevnawa range does not start with {first!r}")
        if not lines[-1][2].endswith(last):
            raise BuildError(f"{verse_id}: Mahamevnawa range does not end with {last!r}")
        first_page, last_page = ranges[0][0], ranges[-1][0]
        where = f"PDF page {first_page}" if first_page == last_page else f"PDF pages {first_page}–{last_page}"
        text = _join_by_gap(lines)
        if verse_id in MAHAMEVNAWA_PROSE:
            text = _reflow_prose(text)
        result[verse_id] = (text, kind, {
            "name": MAHAMEVNAWA_NAME, "locator": f"{url}, {where}", "collected": MAHAMEVNAWA_COLLECTED,
            "translator": NOT_NAMED})
    return result


def _is_divider(text: str) -> bool:
    stripped = text.strip()
    return bool(stripped) and set(stripped) <= {"-"}


def _brisbane_english(yaso: dict) -> dict:
    pages = {p["pdf_page"]: p["lines"] for p in yaso["pages"]}
    file_name = yaso["source"]["file"].split(" (")[0]
    result = {}
    for verse_id, page, block, first, last in BRISBANE:
        lines = sorted((ln for ln in pages[page]
                        if ln["block"] == block and not ln["bold"] and not _is_divider(ln["text"])),
                       key=lambda ln: ln["y"])
        starts = [k for k, ln in enumerate(lines) if ln["text"].startswith(first)]
        ends = [k for k, ln in enumerate(lines) if ln["text"].startswith(last)]
        if len(starts) != 1 or len(ends) != 1 or ends[0] < starts[0]:
            raise BuildError(f"{verse_id}: Brisbane anchors {first!r} .. {last!r} not found once, in order, "
                             f"on page {page} block {block}")
        chosen = [(page, ln["y"], ln["text"]) for ln in lines[starts[0]:ends[0] + 1]]
        result[verse_id] = (_join_footnote(_join_by_gap(chosen)), "translation", {
            "name": BRISBANE_NAME, "locator": f"{file_name}, PDF page {page}", "collected": BRISBANE_COLLECTED,
            "translator": BRISBANE_TRANSLATOR})
    return result


def _normalise_pali(text: str) -> str:
    """The Pali with whitespace, punctuation and zero-width joiners removed, for comparing sources."""
    return re.sub(f"[\\s{re.escape(PALI_PUNCTUATION)}‍‌]", "", text)


def _nottingham_pages(nott: dict) -> dict:
    return {p["printed_page"]: p for p in nott["pages"]}


def _nottingham_unit(pages: dict, page: int, index: int) -> dict:
    units = pages[page]["units"] if page in pages else []
    if not 0 <= index < len(units) or units[index]["index"] != index:
        raise BuildError(f"Nottingham booklet printed page {page}: no unit {index}")
    unit = units[index]
    for field in ("heading", "pali_si", "roman", "english", "notes"):
        value = unit[field]
        for text in ([value] if isinstance(value, str) else value or []):
            if "⟦" in text:
                raise BuildError(f"Nottingham booklet printed page {page} unit {index}: conversion problem "
                                 f"in {field}: {text!r}")
    return unit


def _pages_of(verses: list[list[tuple[int, int]]]) -> str:
    """The printed page, or first–last pages, of the units of `verses`."""
    pages = [page for refs in verses for page, _ in refs]
    first, last = min(pages), max(pages)
    return str(first) if first == last else f"{first}–{last}"


def _printed(pages: str) -> str:
    return f"printed {'pages' if '–' in pages else 'page'} {pages}"


def _nottingham_locator(pages: str) -> str:
    return f"{NOTTINGHAM_FILE}, {_printed(pages)}"


def _nottingham_source(pages: str) -> dict:
    return {"name": NOTTINGHAM_NAME, "locator": _nottingham_locator(pages),
            "collected": NOTTINGHAM_COLLECTED, "translator": NOT_NAMED}


def _three_times(lines: list[str], strip_instruction: bool, where: str) -> list[str]:
    if len(lines) != 1:
        raise BuildError(f"{where}: a unit chanted three times should have one line, found {len(lines)}")
    line = lines[0]
    if strip_instruction:
        match = re.fullmatch(r"(.*\S)\s*\([^()]*\)", line)
        if not match:
            raise BuildError(f"{where}: no instruction in brackets at the end of {line!r}")
        line = match.group(1)
    return [line] * 3


def _unit_lines(pages: dict, refs: list[tuple[int, int]]) -> dict[str, list[list[str]]]:
    """The Pali, Roman and English lines of the units `refs`, one list per unit that has the field.
    A unit with no Pali after the first (the Roman and English running on after a page break)
    continues the unit before it: its lines are added to that unit's Roman and English. A unit's
    English from a page in NOTTINGHAM_PROSE_PAGES is re-set with _reflow_wrapped."""
    merged: list[dict] = []
    for page, index in refs:
        unit = _nottingham_unit(pages, page, index)
        if unit["heading"] is not None:
            raise BuildError(f"Nottingham booklet printed page {page} unit {index} is a heading, not a verse")
        pali, roman = unit["pali_si"], unit["roman"]
        if THREE_TIMES_NOTE in unit["notes"]:
            where = f"Nottingham booklet printed page {page} unit {index}"
            pali, roman = _three_times(pali, True, where), _three_times(roman, False, where)
        lines = {"pali_si": list(pali), "roman": list(roman), "english": list(unit["english"]),
                 "english_page": page if unit["english"] else None}
        if not pali and merged:
            merged[-1]["roman"] += lines["roman"]
            merged[-1]["english"] += lines["english"]
            merged[-1]["english_page"] = merged[-1]["english_page"] or lines["english_page"]
        else:
            merged.append(lines)
    for unit in merged:
        unit.update({field: [line.strip(" ") for line in unit[field]] for field in ("pali_si", "roman", "english")})
        if unit["english"] and unit["english_page"] in NOTTINGHAM_PROSE_PAGES:
            unit["english"] = _reflow_wrapped("\n".join(unit["english"])).split("\n")
    return {field: [unit[field] for unit in merged if unit[field]] for field in ("pali_si", "roman", "english")}


def _english_page(pages: dict, refs: list[tuple[int, int]]) -> int:
    """The printed page of the first of the units `refs` that has English."""
    return next(page for page, index in refs if _nottingham_unit(pages, page, index)["english"])


def _unit_texts(pages: dict, refs: list[tuple[int, int]]) -> dict:
    """The Pali, Roman and English of the units `refs`, each None when no unit has it. Lines join with
    "\n" inside a unit; units join with "\n" when each of them is one Pali line (the three Imāya
    lines), otherwise with "\n\n"."""
    joiner = "\n" if all(len(_nottingham_unit(pages, *ref)["pali_si"]) == 1 for ref in refs) else "\n\n"
    return {field: joiner.join("\n".join(lines) for lines in units) if units else None
            for field, units in _unit_lines(pages, refs).items()}


def _first_lines_covered(app_pali: str, booklet_pali: str) -> int | None:
    """How many of the app's (non-blank) Pali lines the booklet's Pali is, from the first; None when
    it is not a run of the app's first lines."""
    app_lines = [_normalise_pali(line) for line in app_pali.split("\n") if line.strip()]
    booklet = _normalise_pali(booklet_pali)
    for k in range(1, len(app_lines) + 1):
        if "".join(app_lines[:k]) == booklet:
            return k
    return None


def _mirror_lines(units: list[list[str]], app_pali: str, covered: int) -> str | None:
    """The Roman `units` laid out like the app's first `covered` Pali lines, with a blank line wherever
    the app's Pali has one: line for line when the Roman has `covered` lines, else unit for line when
    there are `covered` units (a unit's own lines kept). None when neither count fits."""
    lines = [line for unit in units for line in unit]
    if len(lines) == covered:
        items = lines
    elif len(units) == covered:
        items = ["\n".join(unit) for unit in units]
    else:
        return None
    out, rest = [], list(items)
    for line in app_pali.split("\n"):
        if not rest:
            break
        out.append(rest.pop(0) if line.strip() else "")
    return "\n".join(out)


def _nottingham_verse(pages: dict, refs: list[tuple[int, int]], checked: bool) -> dict:
    texts = _unit_texts(pages, refs)
    if texts["pali_si"] is None:
        raise BuildError(f"Nottingham booklet units {refs}: no Pali")
    verse = _verse(None, texts["pali_si"], None)
    verse["pali_roman"] = texts["roman"]
    verse["check"] = CHECKED if checked else NEEDS_CHECKING
    if texts["english"] is not None:
        verse["english"] = texts["english"]
        verse["english_source"] = _nottingham_source(str(_english_page(pages, refs)))
        verse["english_kind"] = "translation"
    return verse


def _nottingham_heading(pages: dict, ref) -> str:
    refs = ref if isinstance(ref, list) else [ref]
    parts = []
    for page, index in refs:
        heading = _nottingham_unit(pages, page, index)["heading"]
        if not heading:
            raise BuildError(f"Nottingham booklet printed page {page} unit {index} is not a heading")
        parts.append(re.sub(r" {2,}", " ", heading.strip(" ")))
    return HEADING_JOINER.join(parts)


def _nottingham_sections(nott: dict) -> dict[str, dict]:
    pages = _nottingham_pages(nott)
    unknown = NOTTINGHAM_CHECKED - set(NOTTINGHAM_SECTIONS) - set(NOTTINGHAM_VERSES_INTO)
    if unknown:
        raise BuildError(f"NOTTINGHAM_CHECKED names sections the booklet does not add: {sorted(unknown)}")
    sections = {}
    for key, spec in NOTTINGHAM_SECTIONS.items():
        checked = key in NOTTINGHAM_CHECKED
        printed_pages = _pages_of(spec["verses"])
        sections[key] = {
            "heading": _nottingham_heading(pages, spec["heading"]),
            "source": _nottingham_source(printed_pages),
            "notes": [] if checked else [NEW_SECTION_NOTE.format(pages=_printed(printed_pages))],
            "corrections": [], "origin": "nottingham",
            "verses": [_nottingham_verse(pages, refs, checked) for refs in spec["verses"]]}
    return sections


def _nottingham_used_pages() -> set[int]:
    refs = [ref for spec in NOTTINGHAM_SECTIONS.values()
            for ref in ([spec["heading"]] if isinstance(spec["heading"], tuple) else spec["heading"])]
    refs += [ref for spec in NOTTINGHAM_SECTIONS.values() for verse in spec["verses"] for ref in verse]
    refs += [ref for verses in NOTTINGHAM_VERSES_INTO.values() for verse in verses for ref in verse]
    refs += [ref for table in (NOTTINGHAM_ROMAN, NOTTINGHAM_ENGLISH) for units in table.values() for ref in units]
    return {page for page, _ in refs}


def _check_conversion(nott: dict) -> None:
    printed = {p["pdf_page"]: p["printed_page"] for p in nott["pages"]}
    used = _nottingham_used_pages()
    for problem in nott["conversion_problems"]:
        if printed.get(problem["pdf_page"]) in used:
            raise BuildError(f"Nottingham booklet: conversion problem on a page the reading uses: PDF page "
                             f"{problem['pdf_page']} line {problem['line']}: {problem['problem']}")


def _pali_variant(verse_id: str, app_pali: str, booklet_pali: str) -> str | None:
    """None when the booklet's Pali is the app's; the PALI_VARIANTS class when it differs and is listed."""
    rows = [row for row in PALI_VARIANTS if row[0] == verse_id]
    if len(rows) > 1:
        raise BuildError(f"{verse_id}: listed {len(rows)} times in PALI_VARIANTS")
    both = f"\n  app:     {app_pali!r}\n  booklet: {booklet_pali!r}"
    same = _normalise_pali(app_pali) == _normalise_pali(booklet_pali)
    if same and rows:
        raise BuildError(f"{verse_id}: listed in PALI_VARIANTS but the booklet's Pali is the app's")
    if not rows:
        if not same:
            raise BuildError(f"{verse_id}: the Nottingham booklet's Pali differs from the app's and is not "
                             f"listed in PALI_VARIANTS{both}")
        return None
    _, kind, _, digest = rows[0]
    if _pali_hash(booklet_pali) != digest:
        raise BuildError(f"{verse_id}: the booklet's Pali is not the text its PALI_VARIANTS row was written "
                         f"for (hash {_pali_hash(booklet_pali)}, the row says {digest}){both}")
    if kind == "partial":
        covered = _first_lines_covered(app_pali, booklet_pali)
        if covered is None or covered == sum(1 for line in app_pali.split("\n") if line.strip()):
            raise BuildError(f"{verse_id}: listed as partial but the booklet's Pali is not the app's first "
                             f"lines{both}")
    elif kind not in ("minor", "wording"):
        raise BuildError(f"{verse_id}: unknown variant class {kind!r}")
    return kind


def _pali_hash(text: str) -> str:
    """The first 8 hex digits of the sha256 of the normalised Pali (PALI_VARIANTS' fourth element)."""
    return hashlib.sha256(_normalise_pali(text).encode("utf-8")).hexdigest()[:8]


def _section_of(sections_by_key: dict, section_id: str) -> dict:
    return sections_by_key[ORDER[int(section_id[1:]) - 1]]


def _apply_nottingham(sections_by_key: dict, nott: dict) -> None:
    """The booklet's extra verses in s05-s07, Roman Pali behind the variants gate, and three English."""
    pages = _nottingham_pages(nott)
    for section_id, verses in NOTTINGHAM_VERSES_INTO.items():
        section = _section_of(sections_by_key, section_id)
        if section["origin"] != "namo" or len(section["verses"]) != 1:
            raise BuildError(f"{section_id}: expected one namo.lk verse before the booklet's")
        checked = section_id in NOTTINGHAM_CHECKED
        for refs in verses:
            verse = _nottingham_verse(pages, refs, checked)
            verse["id"] = f"{section_id}-v{len(section['verses']) + 1}"
            verse["source"] = _nottingham_source(str(refs[0][0]))
            section["verses"].append(verse)
        section["notes"] = [] if checked else [
            EXTENDED_SECTION_NOTE.format(pages=_printed(_pages_of(verses)))]
    verses = {v["id"]: v for s in sections_by_key.values() for v in s["verses"]}
    unknown = {row[0] for row in PALI_VARIANTS} - set(NOTTINGHAM_ROMAN)
    if unknown:
        raise BuildError(f"PALI_VARIANTS rows for verses the booklet does not print: {sorted(unknown)}")
    for verse_id, refs in NOTTINGHAM_ROMAN.items():
        verse = verses[verse_id]
        texts = _unit_texts(pages, refs)
        if texts["pali_si"] is None or texts["roman"] is None:
            raise BuildError(f"{verse_id}: units {refs} lack Pali or Roman")
        kind = _pali_variant(verse_id, verse["pali_si"], texts["pali_si"])
        if kind == "wording":
            continue
        # The Roman takes the app's Pali layout (its stanza breaks) when the line counts allow it.
        roman_units = _unit_lines(pages, refs)["roman"]
        covered = (_first_lines_covered(verse["pali_si"], texts["pali_si"]) if kind == "partial"
                   else sum(1 for line in verse["pali_si"].split("\n") if line.strip()))
        mirrored = _mirror_lines(roman_units, verse["pali_si"], covered)
        verse["pali_roman"] = mirrored if mirrored is not None else "\n\n".join(
            "\n".join(unit) for unit in roman_units)
    for verse_id, refs in NOTTINGHAM_ENGLISH.items():
        verse = verses[verse_id]
        if verse["english"] is not None:
            raise BuildError(f"{verse_id}: already has English")
        english = _unit_texts(pages, refs)["english"]
        if english is None:
            raise BuildError(f"{verse_id}: units {refs} have no English")
        source = _nottingham_source(str(_english_page(pages, refs)))
        verse.update({"english": english, "english_source": source,
                      "english_kind": "translation"})


def _apply_paritha_sinhala(sections_by_key: dict, booklet: dict) -> None:
    url = booklet["source"]["url"]
    pages = {p["printed_page"]: p["lines"] for p in booklet["pages"]}
    verses = {v["id"]: v for s in sections_by_key.values() for v in s["verses"]}
    for verse_id, (page, (small_from, small_to)) in PARITHA_SINHALA.items():
        verse = verses[verse_id]
        if verse["sinhala"] is not None:
            raise BuildError(f"{verse_id}: already has a Sinhala meaning")
        verse["sinhala"] = " ".join(_booklet_line(pages, page, k, "small") for k in range(small_from, small_to + 1))
        verse["sinhala_source"] = {"name": BOOKLET_NAME, "locator": f"{url}, printed page {page}",
                                   "collected": BOOKLET_COLLECTED, "translator": NOT_NAMED}


def build(root: pathlib.Path) -> dict:
    root = pathlib.Path(root)
    namo = _namo_sections(_load(root, "namo_lk"))
    if len(namo) != 17:
        raise BuildError(f"namo.lk: expected 17 sections, found {len(namo)}")
    booklet = _load(root, "paritha_booklet")
    nott = _load(root, "nottingham_booklet")
    _check_conversion(nott)
    sections_by_key = {("namo", k): section for k, section in enumerate(namo)}
    sections_by_key.update({("booklet", n): section for n, section in _booklet_sections(booklet).items()})
    sections_by_key.update({("nottingham", key): section for key, section in _nottingham_sections(nott).items()})
    if len(set(ORDER)) != len(ORDER) or set(ORDER) != set(sections_by_key):
        raise BuildError("ORDER must name every section once")
    sections = [sections_by_key[key] for key in ORDER]
    for number, section in enumerate(sections, start=1):
        for k, verse in enumerate(section["verses"], start=1):
            verse_id = f"s{number:02d}-v{k}"
            if section["origin"] == "booklet" and verse["id"] != verse_id:
                raise BuildError(f"BOOKLET_VERSES names {verse['id']}, which ORDER makes {verse_id}")
            verse["id"] = verse_id

    totals = {row[1]: 0 for row in CORRECTIONS}
    rows_by_origin = {origin: [row for row in CORRECTIONS if row[0] == origin] for origin in ("namo", "booklet")}
    for section in sections:
        for verse in section["verses"]:
            if section["origin"] in rows_by_origin:
                _correct(verse, rows_by_origin[section["origin"]], totals)
    for _, printed, corrected, expected, _ in CORRECTIONS:
        if totals[printed] != expected:
            raise BuildError(f"correction {printed!r} -> {corrected!r}: applied {totals[printed]} times, "
                             f"§5.3 says {expected}")

    english = {**_mahamevnawa_english(_load(root, "mahamevnawa_vandana")),
               **_brisbane_english(_load(root, "yasodhara_vandana"))}
    verses = {v["id"]: v for s in sections for v in s["verses"]}
    for verse_id, (text, kind, source) in english.items():
        if verse_id not in verses:
            raise BuildError(f"English for {verse_id}, which is not a verse")
        verses[verse_id].update({"english": text, "english_source": source, "english_kind": kind})
    for verse_id, notes in NEEDS.items():
        verses[verse_id]["check"] = NEEDS_CHECKING
        verses[verse_id]["notes"] = list(notes)
    _apply_nottingham(sections_by_key, nott)
    _apply_paritha_sinhala(sections_by_key, booklet)

    audio = _section_audio(root, sections)
    out_sections = []
    for number, section in enumerate(sections, start=1):
        check = NEEDS_CHECKING if any(v["check"] == NEEDS_CHECKING for v in section["verses"]) else CHECKED
        sid = f"s{number:02d}"
        out_sections.append({"id": sid, "number": number, "heading": section["heading"],
                             "check": check, "notes": section.get("notes", []), "source": section["source"],
                             "corrections": section["corrections"], "verses": section["verses"],
                             **({"audio": audio[sid]} if sid in audio else {})})
    return {"schema": 1, "categories": [{
        "id": "cat-namaskaraya", "title": TITLE, "subtitle": SUBTITLE,
        "readings": [{"id": "namaskaraya", "title": TITLE, "audio": None, "sections": out_sections}]}]}


def _mp4_duration_ms(data: bytes) -> int:
    """The recording's length, read as tools/build_pirith.py reads it."""
    spec = importlib.util.spec_from_file_location("build_pirith", pathlib.Path(__file__).with_name("build_pirith.py"))
    pirith = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(pirith)
    try:
        return pirith.mp4_duration_ms(data)
    except pirith.BuildError as e:
        raise BuildError(str(e))


def _section_audio(root: pathlib.Path, sections: list[dict]) -> dict[str, dict]:
    """Each recorded section's audio object, by section id (s01 ...)."""
    try:
        times = json.loads((root / AUDIO_TIMES).read_text(encoding="utf-8"))
    except (OSError, ValueError) as e:
        raise BuildError(f"cannot read {AUDIO_TIMES.as_posix()}: {e}")
    out = {}
    for number, section in enumerate(sections, start=1):
        sid = f"s{number:02d}"
        entry = times.pop(sid, None)
        if entry is None:
            continue
        if len(entry["block_times"]) != len(section["verses"]):
            raise BuildError(f"{sid}: {len(entry['block_times'])} verse times for {len(section['verses'])} verses")
        path = root / HOSTED / entry["path"]
        try:
            data = path.read_bytes()
        except OSError as e:
            raise BuildError(f"cannot read recording {path.as_posix()}: {e}")
        out[sid] = {"path": entry["path"], "label": entry["label"], "duration_ms": _mp4_duration_ms(data),
                    "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(),
                    "block_times": entry["block_times"]}
    if times:
        raise BuildError(f"{AUDIO_TIMES.as_posix()} names sections that do not exist: {sorted(times)}")
    return out


def render(data: dict) -> bytes:
    return (json.dumps(data, ensure_ascii=False, indent=1) + "\n").encode("utf-8")


def _first_difference(built: dict, path: pathlib.Path) -> str:
    try:
        stored = json.loads(path.read_text(encoding="utf-8"))
        stored_verses = {v["id"]: v for c in stored["categories"] for r in c["readings"]
                         for s in r["sections"] for v in s["verses"]}
    except (OSError, ValueError, KeyError, TypeError) as e:
        return f"cannot read {path}: {e}"
    for c in built["categories"]:
        for r in c["readings"]:
            for s in r["sections"]:
                for v in s["verses"]:
                    if stored_verses.get(v["id"]) != v:
                        return f"first differing verse: {v['id']}"
    return "the verses match; the difference is outside them (headings, sources or layout)"


def main() -> None:
    args = sys.argv[1:]
    check = "--check" in args
    args = [a for a in args if a != "--check"]
    if len(args) != 1:
        sys.exit("usage: python -I -X utf8 tools/build_content.py <project_root> [--check]")
    root = pathlib.Path(args[0])
    try:
        data = build(root)
    except BuildError as e:
        sys.exit(f"build_content: {e}")
    rendered = render(data)
    path = root / OUTPUT
    if check:
        if path.exists() and path.read_bytes() == rendered:
            print("content file is up to date")
            return
        sys.exit(f"content file is out of date ({_first_difference(data, path)}); "
                 f"run python -I -X utf8 tools/build_content.py {args[0]}")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(rendered)
    print(f"wrote {OUTPUT.as_posix()}")


if __name__ == "__main__":
    main()
