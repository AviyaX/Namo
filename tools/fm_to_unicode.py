"""Convert text typed in the legacy "FM" Sinhala fonts (FM Abhaya, FM Bindumathi,
FM Samantha ...) into standard Unicode Sinhala.

Why this exists: older Sri Lankan PDFs do not store Sinhala letters. They store
Latin characters (for example "kfuda ;iai") and rely on a special font to draw
them as Sinhala. Copying text out of such a PDF therefore gives gibberish. This
module maps each legacy character to the Sinhala letter it draws and puts vowel
signs into Unicode order.

Every entry in LEGACY_MAP was confirmed by looking at how the character is
actually drawn in the source PDF (see tools/fm_analyze.py and tools/fm_zoom.py).
The conversion is deliberately faithful: it does not correct spelling, so a
misprint in the source stays a misprint in the output.
"""
from __future__ import annotations

import re

ZWJ = "‍"

# Private-use placeholders used only while converting.
PRE_E = ""      # kombuva (ෙ), typed BEFORE its consonant in legacy text
LIG_HAL = ""    # the hal inside a ready-made conjunct glyph (e.g. න්ද)
RAKAR = ""      # rakaransaya  ්‍ර
YANSA = ""      # yansaya      ්‍ය
REPHA_YA = ""   # one glyph: repha over the previous letter + yansaya (ආර්ය්‍ය)
SANYAKA = ""    # turns the following ද / ග / ඩ / ජ / බ into ඳ / ඟ / ඬ / ඦ / ඹ

LEGACY_MAP = {
    " ": " ", "!": "ෟ", '"': ",", "#": "ඃ", "%": RAKAR, "'": ".", "+": "ූ",
    ",": "ල", "-": "-", ".": "ග", "/": "රැ",
    "0": "0", "1": "1", "2": "2", "3": "3", "4": "4",
    "5": "5", "6": "6", "7": "7", "8": "8", "9": "9",
    ":": "ථ", ";": "ත", "<": "ළ", "=": "ු", ">": "ඝ", "?": "රෑ", "@": "?",
    "A": "්", "B": "ඊ", "C": "ක" + LIG_HAL, "D": "ෘ", "E": "ෑ", "F": "ත්",
    "G": "ඨ", "H": YANSA, "I": "ෂ", "J": "න" + LIG_HAL, "K": "ණ",
    "L": "ඛ", "M": "ඵ", "N": "භ", "O": "ධ", "P": "ඡ", "Q": "ූ", "S": "ී",
    "T": "ඔ", "U": "ඹ", "V": "ඪ", "W": "උ", "X": "ඞ", "Y": "ශ",
    "[": "ඤ", "`": SANYAKA,
    "a": "්", "b": "ඉ", "c": "ජ", "d": "ා", "e": "ැ", "f": PRE_E, "g": "ට",
    "h": "ය", "i": "ස", "j": "ව", "k": "න", "l": "ක", "m": "ප", "n": "බ",
    "o": "ද", "p": "ච", "q": "ු", "r": "ර", "s": "ි", "t": "එ", "u": "ම",
    "v": "ඩ", "w": "අ", "x": "ං", "y": "හ",
    "{": "ඥ", "|": "ඳ", "~": "ඬ",
    "¡": ".",        # ¡
    "¢": "ඳි",       # ¢
    "¥": "දූ",       # ¥
    "¦": ";",        # ¦
    "§": "දී",       # §
    "¨": "ලු",       # ¨
    "ª": "ඳූ",       # ª
    "®": "ඣ",        # ®
    "¯": "ඣි",       # ¯
    "³": "★",        # ³
    "´": "ඕ",        # ´
    "¾": "ර්",       # ¾  (repha)
    "¿": "ළු",       # ¿
    "À": "ඨි",       # À
    "Ä": "ඛ්",       # Ä
    "Å": "ඛි",       # Å
    "Æ": "ලූ",       # Æ
    "Ç": "ඛී",       # Ç
    "È": "දි",       # È
    "É": "ච්",       # É
    "Ê": "ජ්",       # Ê
    "Ë": "ක" + LIG_HAL + "ෂ",  # Ë
    "Í": "රී",       # Í
    "Ñ": "චි",       # Ñ
    "Ò": "ථි",       # Ò
    "Ó": "ථී",       # Ó
    "Ô": "ජී",       # Ô
    "Õ": "ඟ",        # Õ
    "Ö": "චී",       # Ö
    "Ø": "ඤා",       # Ø
    "Ù": "ඞ්",       # Ù
    "Ü": "ට්",       # Ü
    "ß": "රි",       # ß
    "à": "ටී",       # à
    "á": "ටි",       # á
    "â": "ඩ්",       # â
    "ä": "ඩි",       # ä
    "æ": "!",        # æ
    "è": "ධ්",       # è
    "ê": "ධි",       # ê
    "ë": "ධී",       # ë
    "ì": "බි",       # ì
    "í": "බ්",       # í
    "î": "බී",       # î
    "ï": "ම්",       # ï
    "ð": "ජි",       # ð
    "ñ": "මි",       # ñ
    "ó": "මී",       # ó
    "õ": "ව්",       # õ
    "ö": "ඹී",       # ö
    "÷": "ඳු",       # ÷
    "ø": "ද" + RAKAR,  # ø
    "ù": "වී",       # ù
    "ú": "වි",       # ú
    "û": "ඤු",       # û
    "ü": "ඤූ",       # ü
    "ý": "ඡි",       # ý
    "þ": "ජ්",       # þ
    "ÿ": "දු",       # ÿ
    "œ": REPHA_YA,   # œ
}

# ` before ඞ draws a plain ඞ in this font (seen in සක්‍යපුඞගවං), so it maps to itself.
SANYAKA_FORMS = {"ද": "ඳ", "ග": "ඟ", "ඩ": "ඬ", "ජ": "ඦ", "බ": "ඹ", "ඞ": "ඞ"}

# The key C is a half letter. What it becomes depends on the letter typed after it,
# because the font draws the pair as ONE letter:
#   C + ෂ      -> ක්ෂ            (අක්ෂර)
#   C + ද...   -> ඤ...           (the pair is drawn as ඤ: ඤෙය්‍යධම්මා, සබ්බඤ්ඤු)
#   C + ධ...   -> ඣ...           (the pair is drawn as ඣ: අජ්ඣත්තික, ඣාපිතා)
HALF_KA_PAIRS = {"ද": "ඤ", "ධ": "ඣ"}

CONS = "ක-ෆ"                # U+0D9A .. U+0DC6
VOWEL_MARKS = "්ාැෑිීුූෘෟ"   # marks that can sit between a consonant and a late-typed ්‍ර / ්‍ය
_CONJ = f"[{RAKAR}{YANSA}]"
_CLUSTER = f"[{CONS}](?:{LIG_HAL}[{CONS}])*{_CONJ}*"

_RE_LATE_CONJ = re.compile(f"([{CONS}])([{VOWEL_MARKS}]+)({_CONJ}+)")
_RE_PRE_E = re.compile(f"({PRE_E}+)({_CLUSTER})")
_RE_REPHA_YA = re.compile(f"([{CONS}]){REPHA_YA}")

_COMPOSE = [
    ("ෙෙ", "ෛ"),
    ("ෝ", "ෝ"),
    ("ො", "ො"),
    ("ේ", "ේ"),
    ("ෞ", "ෞ"),
    ("ෘෘ", "ෲ"),
    ("අා", "ආ"),
    ("අැ", "ඇ"),
    ("අෑ", "ඈ"),
    ("උෟ", "ඌ"),
    ("එ්", "ඒ"),
    ("ඔ්", "ඕ"),
    ("ඔෟ", "ඖ"),
]


def convert(legacy: str, problems: list | None = None) -> str:
    """Convert one run of FM-font text to Unicode Sinhala.

    `problems`, if given, collects notes about anything that could not be
    converted cleanly, so nothing is silently guessed.
    """
    out = []
    i = 0
    n = len(legacy)
    while i < n:
        ch = legacy[i]
        nxt = legacy[i + 1] if i + 1 < n else ""
        # ර + ැ is drawn (and meant) as රු; ර + ෑ as රූ. Real රැ / රෑ are separate keys.
        if ch == "r" and nxt == "e":
            out.append("රු")
            i += 2
            continue
        if ch == "r" and nxt == "E":
            out.append("රූ")
            i += 2
            continue
        if ch == "C":
            mapped_next = LEGACY_MAP.get(nxt, "")
            if mapped_next and mapped_next[0] in HALF_KA_PAIRS:
                letter = HALF_KA_PAIRS[mapped_next[0]]
                # ඤ drawn touching a previous ඤ is the printed conjunct ඤ්ඤ
                if letter == "ඤ" and out and out[-1] == "ඤ":
                    out.append("්")
                out.append(letter + mapped_next[1:])
                i += 2
                continue
            if not mapped_next.startswith("ෂ") and problems is not None:
                problems.append(f"half-letter C followed by unexpected {nxt!r}")
        if ch == "`":
            mapped_next = LEGACY_MAP.get(nxt, "")
            if mapped_next and mapped_next[0] in SANYAKA_FORMS:
                out.append(SANYAKA_FORMS[mapped_next[0]] + mapped_next[1:])
                i += 2
                continue
            if problems is not None:
                problems.append(f"sanyaka mark before {nxt!r} could not be applied")
            out.append("⟦`⟧")
            i += 1
            continue
        mapped = LEGACY_MAP.get(ch)
        if mapped is None:
            if problems is not None:
                problems.append(f"unmapped character U+{ord(ch):04X} {ch!r}")
            out.append(f"⟦{ch}⟧")
        else:
            out.append(mapped)
        i += 1
    s = "".join(out)

    # repha + yansaya glyph: goes with the consonant typed just before it
    s = _RE_REPHA_YA.sub(lambda m: "ර්" + m.group(1) + YANSA, s)
    # ්‍ර / ්‍ය typed after a vowel sign (e.g. ශ + ී + ්‍ර) belong directly on the consonant.
    # If the only thing in between is a hal (ම් + ්‍ය), that hal is the conjunct's own: keep one.
    def _late_conj(m: re.Match) -> str:
        marks = "" if m.group(2) == "්" else m.group(2)
        return m.group(1) + m.group(3) + marks

    prev = None
    while prev != s:
        prev = s
        s = _RE_LATE_CONJ.sub(_late_conj, s)
    # kombuva typed before a consonant cluster moves after it
    s = s.replace(PRE_E + "එ", "ඓ")
    prev = None
    while prev != s:
        prev = s
        s = _RE_PRE_E.sub(lambda m: m.group(2) + "ෙ" * len(m.group(1)), s)
    if PRE_E in s:
        if problems is not None:
            problems.append("kombuva (ෙ) with no consonant after it")
        s = s.replace(PRE_E, "ෙ")
    for src, dst in _COMPOSE:
        s = s.replace(src, dst)
    # The booklet sometimes has a stray ි typed straight after ේ (ලැබේ + ි). In print the two
    # marks overlap and it reads as plain ේ, so that is what is kept. Each case is reported.
    stray = s.count("ේි")
    if stray:
        s = s.replace("ේි", "ේ")
        if problems is not None:
            problems.extend(["stray ි after ේ removed (it is invisible in the printed page)"] * stray)
    s = s.replace(LIG_HAL, "්")
    s = s.replace(RAKAR, "්" + ZWJ + "ර")
    s = s.replace(YANSA, "්" + ZWJ + "ය")
    return s


# Known-answer checks. The right-hand side is how the PDF visibly draws the
# legacy string on the left (checked against rendered pages), not text recalled
# from elsewhere.
_SELF_TEST = [
    ("kfuda ;iai N.jf;da wryf;da iïud iïnqoaOiai", "නමෝ තස්ස භගවතෝ අරහතෝ සම්මා සම්බුද්ධස්ස"),
    ("nqoaOx irKx .ÉPdñ", "බුද්ධං සරණං ගච්ඡාමි"),
    ("ÿ;shïms", "දුතියම්පි"),
    ("mdKd;smd;d fõruKS islaLdmox iudÈhdñ", "පාණාතිපාතා වේරමණී සික්ඛාපදං සමාදියාමි"),
    ("f;rejka", "තෙරුවන්"),
    ("YS% ioaO¾uh", "ශ්‍රී සද්ධර්මය"),
    ("j`Èñ", "වඳිමි"),
    ("Nd.Hj;a", "භාග්‍යවත්"),
    ("wdyqfkfhHda", "ආහුනෙය්‍යෝ"),
    ("wka;¾.;h", "අන්තර්ගතය"),
    ("wCIr", "අක්ෂර"),
    ("m%d¾:kd", "ප්‍රාර්ථනා"),
    ("fidrlï", "සොරකම්"),
    ("ffjr", "වෛර"),
    ("iq[aØ.df¾", "සුඤ්ඤාගාරේ"),
    ("wdhœ", "ආර්ය්‍ය"),
    ("bkaøÇ,hla", "ඉන්ද්‍රඛීලයක්"),
    ("tai", "ඒස"),
    ("iïHla", "සම්‍යක්"),
    (".sßudkJo", "ගිරිමානන්ද"),
    ("ll=iJOx", "කකුසන්ධං"),
    ("wÊCO;a;sl", "අජ්ඣත්තික"),
    ("fCohHOïud", "ඤෙය්‍යධම්මා"),
    ("iq[Cod.dr", "සුඤ්ඤාගාර"),
    ("ilHmq`X.jx", "සක්‍යපුඞගවං"),
    ("m`vqrla", "පඬුරක්"),
]


def self_test() -> list[str]:
    failures = []
    for legacy, expected in _SELF_TEST:
        got = convert(legacy)
        if got != expected:
            failures.append(f"{legacy!r}: expected {expected!r}, got {got!r}")
    return failures


if __name__ == "__main__":
    fails = self_test()
    print("self-test:", "all passed" if not fails else f"{len(fails)} FAILED")
    for f in fails:
        print("  ", f.encode("unicode_escape").decode("ascii"))
