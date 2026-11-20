# Buddha Wandanawa: Nottingham Booklet Sections Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the Buddha Wandanawa reading from 19 sections / 28 verses to 33 sections / 114 verses with the Shanthi Vihara (Nottingham) booklet's material, in the booklet's order, every line traceable to a source page.

**Architecture:** A new PyMuPDF extractor converts the booklet's FM-font Sinhala and groups each page into units (Pali, Roman, English); `tools/build_content.py` gains an `ORDER` list and tables that place units into new sections, extra verses, Roman Pali and three English lines, reuses two Sinhala meanings from the paritha.org booklet, and gates the booklet's Pali against the app's through an allow-list of known variants. The Dart model gains per-verse `source`/`sinhala_source` and section `notes`; the Sources page lists section-level checks.

**Tech Stack:** Python 3 standard library + PyMuPDF (`fitz`, already used) + `tools/fm_to_unicode.py`; Flutter 3.47.9 / Dart 3.13.7; the project's existing tests.

**Spec:** `docs/superpowers/specs/2026-11-17-evening-puja-sections-design.md`

## Global Constraints

- No religious text is typed from memory. Every `pali_si`, `pali_roman`, `sinhala` and `english` string in the content JSON comes from a file under `content/extracted/` through a table of (page, index) references in `build_content.py`. Hand-typed strings in the builder are limited to: the `" – "` joiner of the two-part headings, the check notes, the `PALI_VARIANTS` descriptions, and source records. Test expectations may copy strings that the extraction produced.
- Existing content is preserved exactly: every existing verse keeps its `pali_si`, `sinhala`, `english`, `english_source`, `english_kind`, `notes` and `corrections`; only ids, numbers, position and `pali_roman` change. Old → new section ids: s01→s02, s02→s03, s03→s04, s04→s05, s05→s06, s06→s07, s07→s09, s08→s10, s09→s11, s10→s12, s11→s13, s12→s14, s13→s15, s14→s16, s15→s17, s16→s18, s17→s19, s18→s22, s19→s20 (verse numbers unchanged).
- Final shape: 33 sections, verse counts in order `5 1 1 1 5 5 5 8 1 3 1 1 2 2 1 1 1 1 1 3 1 4 4 11 5 6 7 3 1 1 5 6 11` (114). Headings of the new sections are the booklet's own, converted: s01 තෙරුවන් නමස්කාර කිරීම, s08 සියල්ල එකට සිහි කිරීම, s21 මියගිය ඤාතීන්ට පින් අනුමෝදන් කිරීම, s23 ප්‍රාර්ථනා, s24 බුද්ධානුස්සතිය, s25 මෙත්තානුස්සතිය, s26 අසුභානුස්සතිය, s27 මරණානුස්සතිය, s28 අට්ඨ මහා සංවේග වත්ථු, s29 පටිච්ච සමුප්පාදය – අනුලෝම, s30 පටිච්ච සමුප්පාදය – පටිලෝම, s31 නිවැරදි පිළිසරණ යෑම, s32 තිලකුණු මෙනෙහි කිරීම, s33 මෛත්‍රී භාවනාව. If the converter yields a different spelling for one of these, the test is wrong, not the converter: report it, do not retype the heading.
- Source record for the booklet: `{"name": "Shanthi Vihara, Nottingham — Evening Puja and Chanting", "locator": "evening_puja_and_chanting.pdf (supplied by the app's owner, 2026-11-17), printed page N", "collected": "2026-11-17", "translator": "not named by the source"}`; English kind `translation`.
- Checks: new sections s01, s08, s21, s23–s33 are `needs checking` with the section note `Converted from the booklet's FM font; to be read against printed page N.` (N–M when a section spans pages) and their verses `needs checking` with no notes; s05–s07 are `needs checking` with the note `Verses 2–5 converted from the booklet's FM font; to be read against printed pages N–M.`, their first verses stay `checked against source`; the existing four verse notes stay.
- `PALI_VARIANTS` gate: for every existing verse the booklet prints, converted booklet Pali is compared with the app's `pali_si` after normalisation (remove whitespace, punctuation `.,;:!?"'–-()`, U+200D, U+200C); a difference must be listed as `(verse id, "minor"|"wording", description)` or the build fails naming both texts. `pali_roman` is filled for a match or a `minor` row, left `None` for `wording`. Known rows to start from (verify, do not assume): s05-v1 minor (සාරථී/සාරථි, භගවාතී/භගවාති), s06-v1 minor (සන්දිට්ඨිකො/සන්දිට්ඨිකෝ), s10-v1 minor (නිසින්නෝච/නිසින්නෝව), s10-v2 minor (මහාබෝධී/මහා බෝධි), s20-v3 wording (the booklet ends "සුපටිපන්න අනුත්තර").
- Content reaches the app only through `tools/`; `python -I -X utf8 tools/build_content.py . --check` must pass after the rebuild, as must `build_pirith.py . --check`, `build_samantha_patthana.py . --check`, `sync_tipitaka.py . --check`, `sync_hosted_audio.py . --check`, and `check_ui_glyphs.py .` (exit 0).
- Flutter: `C:\Users\Dell\develop\flutter\bin\flutter` (Git Bash `/c/Users/Dell/develop/flutter/bin/flutter`), not on PATH; `flutter test` (2537 at the base) and `flutter analyze` clean before every commit that touches Dart. Python tools: `python -I -X utf8 ...` from the repo root. One flutter/git command at a time in the folder.
- Design rules: no raw colours, no Material default widgets, `textMuted` only inside `lib/design/`, type via `NamoType`, no `Duration(milliseconds:` outside tokens.
- Git: never `git add -A`; name the files. Commit trailer `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- The Tripitaka (`lib/tipitaka/`), pirith and Samantha Pattana content are untouched.

## Review Focus

1. **Two verses merged into one unit** when a page has no blank line between them: the extractor's grouping must start a new unit at every run of `pali_si` lines. Test in Task 1 (synthetic page, two Pali runs → two units).
2. **A conversion problem on a used page** (`⟦x⟧` in any text) must fail the build, never ship. Test in Task 3 (`conversion_problems` non-empty for a used page → `BuildError`).
3. **The renumbering drops or duplicates an existing verse**: the multiset of existing `pali_si` texts must be unchanged after the move. Test in Task 3 (baseline comparison through the id map).
4. **A `wording` variant with Roman filled** would make search match words the screen does not show. Test in Task 3 (`s20-v3` has `pali_roman == None`; a `minor` row has Roman).
5. **A section check row with no notes, or a verse row inside a section that also has a row**: the Sources page must render both kinds without duplicating or crashing. Test in Task 2 (fake library with a section row and a verse row).

---

### Task 1: The Nottingham extractor

**Files:**
- Create: `tools/extract_nottingham_booklet.py`, `tools/test_extract_nottingham_booklet.py`, `content/extracted/nottingham_booklet.json`, `content/review/05_evening_puja_nottingham.md`
- Read: `tools/extract_booklet.py` (pattern), `tools/fm_to_unicode.py` (`convert`, `is_fm` pattern), `source_material/evening_puja_nottingham/inspect.txt`

**Interfaces:**
- Produces (Python, importable without side effects; `main()` guarded):
  ```python
  SOURCE_FILE = "evening_puja_and_chanting.pdf (supplied by the app's owner, 2026-11-17)"
  def is_fm(font: str) -> bool                              # font name after '+' starts with 'FM'
  def merge_baselines(lines: list[dict], tolerance: float = 1.0) -> list[dict]
      # input/output items: {"y": float, "spans": [{"x": float, "font": str, "size": float, "flags": int, "text": str}]}
      # lines whose y agree within tolerance are merged into one, spans sorted by x
  def line_text(spans: list[dict]) -> str                    # FM spans converted with fm_to_unicode.convert after
      # removing a space that precedes a Sinhala vowel sign or virama inside the joined FM text; other spans as printed;
      # adjacent spans joined without added spaces; result stripped
  def classify(spans: list[dict], text: str) -> str          # one of: heading, subheading, pali_si, roman, english, note, break, other
  def units_of(lines: list[dict]) -> list[dict]              # lines = [{"kind", "text", ...}] of one page →
      # [{"index": int, "heading": str | None, "pali_si": [str], "roman": [str], "english": [str], "notes": [str]}]
  def extract(pdf_path: str) -> dict                         # the whole JSON structure
  def main() -> None                                         # Usage: python -I -X utf8 tools/extract_nottingham_booklet.py <pdf> <out_json> <out_md>
  ```
- Classification rules (from the design's text-layer notes): drop a line whose text is only digits/whitespace or a page number at y > 780; `heading` when an FM span of size ≥ 20 stands alone on the line or the line has a `Calibri-Bold` span ≥ 18 whose text is upper case plus a `Calibri` 24 span (the English title; the Sinhala FM heading is on its own line just above and is kept as its own `heading` line with the English attached as `heading_en` when the next line is that English title); `subheading` when the line mixes an FM span with a `Calibri-BoldItalic` span (the offering titles) — keep the FM part as text and the English in `heading_en`; `note` when the text starts with `(` and ends with `)`; `pali_si` when every text-bearing span is FM; `roman` when the spans are `Calibri-Bold` with the bold flag and size ≥ 15 and the text is not bracketed; `english` when the spans are `Calibri`/`Calibri-Italic` regular of size ≤ 13; `break` for an empty line; `other` for anything else (reported in the review).
- Units: walk a page's lines in order; a `heading`/`subheading` line starts a unit with `heading` set and no Pali; a `pali_si` line starts a new unit when the previous line was not `pali_si` (so consecutive Pali lines stay together); `roman` and `english` lines attach to the current unit; a `note` attaches to the current unit; `break` and `other` do nothing. A `roman` or `english` line with no current unit opens one with empty Pali (page 4 starts mid-section).
- JSON: `{"source": {"file": SOURCE_FILE, "sha256": "<of the PDF>", "pages": 34, "fonts": [...], "note": "Converted from FM Bindumathi with tools/fm_to_unicode.py; nothing corrected"}, "conversion_problems": [{"pdf_page", "line", "problem"}], "pages": [{"pdf_page": n, "printed_page": n, "lines": [{"kind", "font", "size", "text", "heading_en"?}], "units": [...]}]}`. Printed page equals PDF page in this booklet (the page number is printed at the foot).
- Review `.md`: a heading per page, then every line as `| kind | text |`, then the units with their Pali/Roman/English line counts, then the conversion problems; begins with the same note as `content/review/01_sinhala_pali_booklet_paritha.md` about being a machine copy for a person to check.

- [ ] **Step 1: Write the failing tests**

`tools/test_extract_nottingham_booklet.py` (unittest, no PDF needed except the last test):
- `test_merge_baselines_joins_justified_words`: three lines at y 391.3 with spans x 70 "Viññāṇa", x 150 "paccayā", x 240 "nāma-rūpan," → one line, text order by x.
- `test_line_text_converts_fm_and_joins_without_spaces`: spans `[FM "nqoaOx kudñ"]` → `"බුද්ධං නමාමි"`; spans `[FM "b;sm s fida"]` → `"ඉතිපි සෝ"` (the space before the vowel sign removed); mixed `[Calibri-Bold "Buddhan namāmi"]` unchanged.
- `test_classify_each_kind`: FM 19 → `pali_si`; Calibri-Bold 17 bold "Buddhan namāmi" → `roman`; Calibri 12 "Homage to the Buddha" → `english`; Calibri-Bold 16 "(Bow)" → `note`; FM 20 alone → `heading`; FM 19 + Calibri-BoldItalic 15 → `subheading`; empty → `break`.
- `test_units_split_at_each_pali_run` (Review Focus 1): lines `pali, pali, roman, english, pali, roman, english` → two units with Pali line counts 2 and 1.
- `test_units_heading_starts_a_unit`: `heading, pali, roman, english` → two units, the first with `heading` set and empty `pali_si`.
- `test_page_numbers_and_digit_marks_are_dropped`: a line "3" at y 785 and an FM line "1" at size 11 produce no line.
- `test_real_pdf_page_3` (skipped when the PDF is absent): `extract(...)["pages"][2]` has a unit whose `pali_si == ["බුද්ධං නමාමි"]`, `roman == ["Buddhan namāmi"]`, `english == ["Homage to the Buddha"]`, `notes == ["(Bow)"]`; `conversion_problems` is empty.

- [ ] **Step 2: Run them to see them fail**

Run: `python -I -X utf8 tools/test_extract_nottingham_booklet.py`
Expected: FAIL (module not found).

- [ ] **Step 3: Implement the extractor**

Follow `extract_booklet.py`'s structure (`rawdict`, `sys.path` insert for `fm_to_unicode`). Compute the sha256 of the PDF for the source record.

- [ ] **Step 4: Run the tests and the extraction**

Run: `python -I -X utf8 tools/test_extract_nottingham_booklet.py` → PASS.
Run: `python -I -X utf8 tools/extract_nottingham_booklet.py source_material/evening_puja_nottingham/evening_puja_and_chanting.pdf content/extracted/nottingham_booklet.json content/review/05_evening_puja_nottingham.md`
Expected: writes both; `conversion_problems` is empty (if not, list them in the report; do not patch the converter in this task). Spot-check in the review file: page 3 has units for the four bows, Sādhu, Namo tassa ×3, Buddham/Dhammam saranam; page 25 has one unit with 7 Pali lines; page 34 has the three Uddhaṃ units and the Sādu line as `other` or a Pali-less unit.

- [ ] **Step 5: Commit**

```bash
git add tools/extract_nottingham_booklet.py tools/test_extract_nottingham_booklet.py content/extracted/nottingham_booklet.json content/review/05_evening_puja_nottingham.md
git commit -m "Tools: extract the Nottingham evening puja booklet into units"
```

---

### Task 2: Dart model and Sources page: per-verse sources, section notes, section check rows

**Files:**
- Modify: `lib/content/model.dart` (`Verse` 101–183, `Section` 262–311), `lib/settings/sources_screen.dart` (`_collectChecks` 136–166)
- Test: `test/content/model_test.dart`, `test/settings/sources_screen_test.dart`

**Interfaces:**
- Produces:
  ```dart
  // Verse
  final SourceRecord? source;          // JSON 'source', null when absent
  final SourceRecord? sinhalaSource;   // JSON 'sinhala_source'
  SourceRecord sourceOr(Section section) => source ?? section.source;
  // Section
  final List<String> notes;            // JSON 'notes', [] when absent
  // sources_screen.dart: _collectChecks adds, before a section's verse rows,
  // ('check-section-${section.id}', 'Section ${section.number}', section.notes)
  // when section.check == CheckStatus.needsChecking && section.notes.isNotEmpty;
  // verse rows unchanged (a verse with needsChecking and no notes still gets a row only if its notes are non-empty — change the verse rule to require non-empty notes).
  ```
  The whole-reading rule stays. Rendering of `_CheckRow` unchanged.

- [ ] **Step 1: Write the failing tests**

`test/content/model_test.dart`: `'a verse reads its own source and sinhala_source'` (JSON with both → non-null records; without → null; `sourceOr(section)` falls back); `'a section reads its notes'` (`['a']`; absent → `[]`).
`test/settings/sources_screen_test.dart`: using the file's fake-library pattern, `'a section that needs checking with notes gets one row; its verses without notes get none'` (expect `keyed('check-section-s01')` once, no `check-s01-v1`), and `'a verse with notes still gets its row under a section row'` (Review Focus 5: both keys present, in that order).

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/content/model_test.dart test/settings/sources_screen_test.dart`
Expected: compile errors / rows not found.

- [ ] **Step 3: Implement**

Parse the new fields in `fromJson` next to `englishSource`; add the fields to the constructors with defaults; update `_collectChecks` as specified.

- [ ] **Step 4: Run the suites**

Run: `flutter test test/content test/settings test/quality/design_rules_test.dart` → PASS; `flutter analyze` → clean. The real content has none of the new fields yet, so nothing else changes.

- [ ] **Step 5: Commit**

```bash
git add lib/content/model.dart lib/settings/sources_screen.dart test/content/model_test.dart test/settings/sources_screen_test.dart
git commit -m "Content model: per-verse sources, section notes, section check rows"
```

---

### Task 3: The builder: order, new sections, extra verses, Roman Pali, variants; the content file; the count tests

**Files:**
- Modify: `tools/build_content.py`, `tools/test_build_content.py`
- Regenerate: `assets/content/namaskaraya_to_pin_dima.json`
- Modify tests that pin the old shape: `test/content/content_repository_test.dart` (19→33, numbers 1..33), `test/content/model_test.dart` (28→114; "none has Roman Pali" → the listed verses have it; English cover per section with the new numbers; sources; the four verses that need checking with their new ids plus the new sections), `test/content/flow_ids_content_test.dart` (should pass unchanged), `test/quality/real_content_reader_test.dart` (33 headings, last heading `මෛත්‍රී භාවනාව`), `test/library/library_screen_test.dart` (33), `test/home/today_test.dart` (the id list: the same 19 verses under their new ids — new verses are `needs checking` and therefore not eligible), `test/home/featured_card_test.dart` (`sectionCountLabel(33)`), `test/quality/overflow_test.dart:354` (`sections[2].heading` is now section 3's heading; keep the intent), `test/settings/sources_screen_test.dart` (counts: correction rows unchanged at 16, check rows 4 verse + 17 section = 21, card count recomputed; ගච්චාමි/ගච්ඡාමි still once each)

**Interfaces:**
- Consumes: Task 1's JSON (`pages[].units[]` with `index`), Task 2's fields.
- Produces in `build_content.py`:
  ```python
  NOTTINGHAM_NAME = "Shanthi Vihara, Nottingham — Evening Puja and Chanting"
  NOTTINGHAM_FILE = "evening_puja_and_chanting.pdf (supplied by the app's owner, 2026-11-17)"
  NOTTINGHAM_COLLECTED = "2026-11-17"
  ORDER: list[tuple[str, object]]   # 33 entries in final order: ("namo", <namo heading index 0-16>) | ("booklet", 18|19) | ("nottingham", "<key>")
  NOTTINGHAM_SECTIONS: dict[str, dict]   # key -> {"heading": (page, unit_index) | [(page, unit_index), (page, unit_index)] joined with " – ", "pages": "N" | "N–M", "verses": [[(page, unit_index), ...], ...]}  one inner list per verse (several units when a verse spans units, e.g. the three Imāya lines)
  NOTTINGHAM_VERSES_INTO: dict[str, list[list[tuple[int, int]]]]   # new section id (s05/s06/s07) -> four verses as unit lists
  NOTTINGHAM_ROMAN: dict[str, list[tuple[int, int]]]   # new verse id -> units whose roman fills pali_roman (stanzas joined with "\n\n")
  NOTTINGHAM_ENGLISH: dict[str, list[tuple[int, int]]] # {"s19-v1": [...], "s22-v2": [...], "s22-v3": [...]}
  PARITHA_SINHALA: dict[str, tuple[int, tuple[int, int]]]   # new verse id -> (printed page, (small_from, small_to)): s08-v6/v7/v8 from printed page 3, s23-v1 from printed page 38
  PALI_VARIANTS: list[tuple[str, str, str]]   # (new verse id, "minor"|"wording", description)
  def _normalise_pali(text: str) -> str
  def _nottingham_unit(pages: dict, page: int, index: int) -> dict
  def _nottingham_sections(nott: dict) -> dict[str, dict]
  def _apply_nottingham(sections_by_key: dict, nott: dict) -> None   # extra verses, roman, english, variants gate
  ```
  `build()` assembles `sections_by_key` from the three origins, then walks `ORDER` to number them; ids are assigned from the final position before the id-keyed tables (`MAHAMEVNAWA`, `BRISBANE`, `NEEDS`, `BOOKLET_VERSES`, `CORRECTIONS` scopes) apply — rewrite those tables to the new ids (Global Constraints map) rather than translating at run time. A verse built from a unit: `pali_si = "\n".join(unit["pali_si"])` per unit, units joined by `"\n\n"`; `pali_roman` and `english` likewise from `roman`/`english`; `sinhala = None` unless `PARITHA_SINHALA` provides it (then also `sinhala_source` = the paritha record with its printed page); verse `source` set only for the s05–s07 extras; `check`/`notes` per Global Constraints; `english_source` = the Nottingham record with the unit's page, `english_kind = "translation"`. A unit with empty `english` leaves `english = None` (none expected; report any).

- [ ] **Step 1: Rewrite the tool tests first**

In `tools/test_build_content.py`: `HEADINGS` (33, the Global Constraints list merged with the existing 19 in the new order), `VERSES` (the 33 counts), the id-keyed constants (`NO_ENGLISH`, `BRISBANE`, `NEEDS`, `EXPLANATION`, counts) under the new ids, and new tests: `test_order_follows_the_booklet` (s20 forgiveness, s21 relatives, s22 devas, s23 aspirations), `test_new_sections_sources_and_checks` (source name, locator page, `needs checking`, the note text, verses `needs checking` with empty notes), `test_extra_verses_carry_their_source` (s05–s07 v2–v5 have `source` naming Nottingham; v1 has none), `test_roman_filled_where_listed` (every id in `NOTTINGHAM_ROMAN` and every new verse has `pali_roman`; s20-v3 has none; the old `test_no_roman_pali` is replaced), `test_three_english_from_the_booklet` (s19-v1, s22-v2, s22-v3 with Nottingham `english_source`), `test_paritha_sinhala_reused` (s08-v6..v8 and s23-v1 have `sinhala` and `sinhala_source` naming paritha.org pages 3 and 38), `test_variants_are_listed_and_gate` (a copy of the built data with one `pali_si` altered on a booklet-printed verse makes `build` raise `BuildError`; achieve this by monkeypatching the loaded namo data or by calling the gate function directly on a modified verse), `test_conversion_problem_fails_the_build` (Review Focus 2: inject a `⟦x⟧` into a used unit → `BuildError`), `test_existing_verses_unchanged_through_the_map` (Review Focus 3: for each old id in the baseline, the new id's `pali_si` and `sinhala` are equal; the multiset of old `pali_si` equals the multiset over the mapped ids), and keep `test_file_is_reproducible`.

- [ ] **Step 2: Run them to see them fail**

Run: `python -I -X utf8 tools/test_build_content.py`
Expected: FAIL (19 sections, missing names).

- [ ] **Step 3: Implement the builder changes and regenerate**

Derive the unit indices for every table from `content/review/05_evening_puja_nottingham.md` against the design's section table. Then:

```bash
python -I -X utf8 tools/build_content.py .
python -I -X utf8 tools/build_content.py . --check
python -I -X utf8 tools/test_build_content.py
```
Expected: `wrote …`, `content file is up to date`, tests PASS. Record every `PALI_VARIANTS` row you had to add, with both texts, in your report.

- [ ] **Step 4: Update the Dart tests that pin the old shape, then run everything**

Edit the files listed above. Run: `flutter test` → all pass; `flutter analyze` → clean; `python -I -X utf8 tools/check_ui_glyphs.py .` → exit 0 (it also checks the content names).

- [ ] **Step 5: Commit**

```bash
git add tools/build_content.py tools/test_build_content.py assets/content/namaskaraya_to_pin_dima.json test/content/content_repository_test.dart test/content/model_test.dart test/quality/real_content_reader_test.dart test/library/library_screen_test.dart test/home/today_test.dart test/home/featured_card_test.dart test/quality/overflow_test.dart test/settings/sources_screen_test.dart
git commit -m "Buddha Wandanawa: 33 sections in the booklet's order, with Roman Pali"
```

---

### Task 4: Credits, README, release checklist

**Files:**
- Modify: `lib/settings/sources_screen.dart` (credits 27–34 and the "not connected" line 211), `README.md` (lines 8, 23–29, 31, 92), `docs/release-checklist.md`
- Test: `test/settings/sources_screen_test.dart`

- [ ] **Step 1: Write the failing test**

`sources_screen_test.dart`: the Sources page shows `'Shanthi Vihara, Nottingham'` and the sentence `'Namo is not made by, or connected with, namo.lk, pitaka.lk or Shanthi Vihara.'`; the `SelectableText` count stays 4 (the booklet has no address); the card count from Task 3 plus one.

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/settings/sources_screen_test.dart` → FAIL.

- [ ] **Step 3: Implement**

Credits: `_Credit('namo.lk', 'The first verses of sections 2–7 and sections 9–19.', 'https://namo.lk/buddha-puja/')`; paritha.org: `'… Sections 20 and 22, and the Sinhala of three verses in 8 and one in 23.'`; new `_Credit('Shanthi Vihara, Nottingham', 'Evening Puja and Chanting booklet: the Pali, Roman Pali and English of sections 1, 8, 21 and 23–33, verses 2–5 of sections 5–7, three English lines in 19 and 22, and the Roman Pali of the other sections.')` (no address). The "not connected" sentence as in Step 1.
README: line 8 `… (බුද්ධ වන්දනාව), 33 sections in Pali, Sinhala and English; Roman Pali is stored for search.`; Sources list: namo.lk and paritha.org lines with the new numbers; a new line for the Nottingham booklet (same words as the credit, plus "supplied by the owner"); the "not connected" line adds the vihara; Commands: the extractor command next to the content check.
Checklist: after the Samantha Pattana line, `- [ ] Buddha Wandanawa (sections and English from the Shanthi Vihara, Nottingham booklet "Evening Puja and Chanting"): do not publish the app or push the repository to a public place until the owner confirms the vihara's permission; then add "used with permission" to the Sources entry.` and an owner check: `- [ ] Buddha Wandanawa, owner checks: read sections 1, 5–8, 21, 23–33 in the app against the booklet's pages and clear their "needs checking" notes in tools/build_content.py.`

- [ ] **Step 4: Run the checks**

Run: `flutter test test/settings`, then `flutter test`, `flutter analyze`, `python -I -X utf8 tools/check_ui_glyphs.py .`, and every `--check` in Global Constraints.
Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add lib/settings/sources_screen.dart test/settings/sources_screen_test.dart README.md docs/release-checklist.md
git commit -m "Sources, README and checklist: the Nottingham booklet"
```

---

## Rulings taken while planning

- The Sādhu ×3 on page 3 is verse 5 of section 1; the closing Sādu ×3 on page 34 is not a verse.
- "(Three times)" becomes three identical lines in one verse, as the app's Namo tassa already is; "(Bow)" and "(Only chant verses for what you are offering)" are kept in the extraction's `notes` and not shown.
- The two-part headings of sections 29 and 30 join the booklet's two heading lines with " – ".
- Today's pool is unchanged in substance (new verses are `needs checking`); its test list moves to the new ids.
- The booklet PDF is tracked under `source_material/` like the other booklets (committed with the design).
