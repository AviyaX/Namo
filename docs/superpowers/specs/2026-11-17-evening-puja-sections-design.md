# Buddha Wandanawa: the Nottingham booklet's sections — design

Date: 2026-11-17. Status: the owner asked for this on 2026-11-17 ("Build the
booklet has our does not as sections. And correct order is booklet"); the
decisions below are the designer's, taken without a further round of
questions. Builder check done the same day; its three findings (no new
verses in the merit-to-devas section, an allow-list for the booklet's Pali
variants, section-level checking) are folded in.

## Intent

The owner compared the app's first topic, Buddha Wandanawa (19 sections, 28
verses, from namo.lk and the paritha.org booklet), with "Evening Puja and
Chanting" by Shanthi Vihara, Nottingham (34 pages: Pali in Sinhala script,
Roman Pali with diacritics, English; no Sinhala meaning). Two instructions:

1. Add to Buddha Wandanawa every section the booklet has and the app lacks.
2. The order of the closing sections follows the booklet: forgiveness, then
   merit to departed relatives, then merit to devas, then aspirations.

Everything the app has today stays, including the sections the booklet lacks
(the third Bodhi verse, the invitation to the Buddha pūjā, the first incense
verse, the food offering, the betel offering) and every Sinhala meaning.

## Goals

- Buddha Wandanawa becomes one reading of 33 sections in the booklet's order,
  with every line traceable to a named source page.
- The new material carries Pali in Sinhala script (converted from the
  booklet's legacy FM font), Roman Pali, and English, exactly as printed.
- Sinhala meaning appears wherever a source the app already credits has the
  verse (the paritha.org booklet has three groups); nowhere is a meaning
  written by hand.
- Roman Pali, which the app stores but does not show, is filled from the
  booklet for every verse the booklet prints, old and new (search uses it).
- The build stays reproducible from the repository: a new extractor, the
  extraction JSON, and tables in `tools/build_content.py`; `--check` and the
  tool tests keep passing.
- Android, iOS and web unchanged in code; only content and the Sources page
  change.

## Non-goals

- Changing the reader (no instruction lines such as "(Bow)", no display of
  Roman Pali).
- Writing or paraphrasing any Sinhala meaning or English.
- Correcting the booklet's Pali or English spellings beyond font-conversion
  artefacts (see Corrections).
- Audio for this topic.
- A separate "Evening Puja" topic (the owner chose to extend the existing
  one).

## Anti-goals

- A line in the app that cannot be pointed to on a page of a named source.
- Presenting the booklet as the app's own work, or the app as the vihara's.
- Publishing the vihara's English without their permission.

## Constraints

- Content reaches the app only through `tools/`; the content JSON is written
  by `build_content.py` and compared byte for byte by `--check`.
- Every verse has `pali_si`; `sinhala` and `english` may be null (the reader
  then notes "Sinhala is not yet available for this section."). Sections
  have one `source`; this design adds an optional per-verse `source` for the
  few verses that join an existing section from another source.
- Fonts: the booklet's Sinhala is in FM Bindumathi; `tools/fm_to_unicode.py`
  converts it (self-test green; sample lines from pages 3, 5, 25, 29 convert
  cleanly). The PDF's text layer sometimes splits a word with a space before
  a combining sign ("බුද ්ධා"); the extractor joins spans without inserting
  spaces, as `extract_booklet.py` does.
- Repository rules: `source_material/` holds the booklet like the other
  three booklets (tracked); no `git add -A`; `python -I -X utf8`; downloaded
  data is never executed.
- Licence/permission: the booklet carries no licence. Traditional Pali is
  not anyone's; the English renderings and the compilation are Shanthi
  Vihara's. The release checklist gets the same "not before permission is
  confirmed; then 'used with permission'" line the other sources have, and
  the Sources page credits the vihara.
- Tests that pin 19 sections or 28 verses (tool tests, `content_repository`,
  `model`, `real_content_reader`, `library_screen`, `today`, `featured_card`,
  `overflow`, `sources_screen` counts) change to the new numbers.

## Approaches considered

1. **A second reading "Evening Puja" beside Buddha Wandanawa.** Keeps the
   namo.lk reading untouched; duplicates fourteen sections. Rejected by the
   owner's instruction (extend, and in the booklet's order).
2. **Replace Buddha Wandanawa by the booklet.** Loses every Sinhala meaning
   and five sections. Rejected.
3. *Chosen:* **Merge into the one reading.** New sections for the booklet's
   groups, the booklet's extra verses added inside the three vandanā sections
   and the merit-to-devas section with a per-verse source, the closing
   sections re-ordered, Sinhala meaning from the paritha.org booklet where it
   has the verse.

For the vandanā extensions, a variant was to add three new sections
("Buddha vandanā, continued") instead of per-verse sources. Rejected: the
reader would show two headings for one act of homage.

## How it works

### The reading after the change (33 sections)

Headings for new sections are the booklet's own Sinhala headings, converted
from the FM font. "B" = the Nottingham booklet, with its printed page.

| # | Heading (source) | Verses | From |
|---|---|---|---|
| 1 | තෙරුවන් නමස්කාර කිරීම (B3) | Buddhan namāmi; Dhamman namāmi; Sanghan namāmi; Ahan vandāmi sabbadā (4 one-line verses); Sādhu ×3 as a fifth | B3 |
| 2 | නමස්කාරය | as today | namo.lk; Roman from B3 |
| 3 | තිසරණ සරණයාම | as today | namo.lk; Roman from B3–4 |
| 4 | පංචශීලය සමාදන්වීම | as today | namo.lk; Roman from B4–5 |
| 5 | බුදු ගුණ සිහි කිරීම | v1 as today; v2 Buddhan jīvita pariyantan; v3 Yē ca buddhā; v4 Natthi mē saranan; v5 Uttamangēna | v1 namo.lk (Roman B5); v2–v5 B5–6 |
| 6 | දහම් වැඳීම | v1 as today; v2–v5 the Dhamma counterparts | namo.lk; B6–7 |
| 7 | සඟුන් වැඳීම | v1 as today; v2–v5 the Sangha counterparts | namo.lk; B7–8 |
| 8 | සියල්ල එකට සිහි කිරීම (B9) | Buddha dhamma ca paccēka; Tisaranan tilakkhanūpētan; Tisaranañca sire thātu; Buddhē sakarunē vandē; Namāmi satthunovāda; Namāmi Buddhan guṇa; Namāmi Dhamman; Namāmi Sanghan | B9–11; Sinhala for the three Namāmi verses from the paritha.org booklet, printed page 3 (its "තෙරුවන් වන්දනාව") |
| 9 | චෛත්‍ය වන්දනාව | as today | namo.lk; Roman B11 |
| 10 | බෝධි වන්දනාව | as today (3 verses) | namo.lk; Roman B11–12 for v1–v2 |
| 11 | බුද්ධ පූජා ආරාධනාව | as today | namo.lk |
| 12 | පහන් පූජාව | as today | namo.lk; Roman B12 |
| 13 | සුවඳ දුම් පූජාව | as today | namo.lk; Roman B12 for v2 |
| 14 | මල් පූජාව | as today | namo.lk; Roman B12–13 |
| 15 | පැන් පූජාව | as today | namo.lk; Roman B13 |
| 16 | ආහාර පූජාව | as today | namo.lk |
| 17 | ගිලන්පස පූජාව | as today | namo.lk; Roman B13 |
| 18 | දැහැත් පූජාව | as today | namo.lk |
| 19 | සියල්ල එකවිට පූජා කිරීම | as today | namo.lk; Roman and English from B13–14 |
| 20 | තෙරුවන් සමාකර ගැනීම | as today (was 19) | paritha.org; Roman B14 |
| 21 | මියගිය ඤාතීන්ට පින් අනුමෝදන් කිරීම (B14) | Idan mē ñātīnan hotu, three lines (the booklet's "Three times") | B14 |
| 22 | දෙවියන්ට පින් දීම | v1–v4 as today (was 18); v4 already holds all three Ākāsaṭṭhā stanzas (sāsanan, dēsanan, man paran) with one Sinhala meaning, so nothing is added | paritha.org; English for v2, v3 from B15; Roman for v4 from the three booklet units on B15–16, one stanza each, separated by blank lines like the Pali |
| 23 | ප්‍රාර්ථනා (B16) | Iminā puñña kammēna; Imāya dhammānudhamma ×3 (one verse of three lines); Addhāya imāya; Idan mē puñña kamman | B16–17; Sinhala for Iminā puñña from paritha.org printed page 38 (lines after the ❖ divider) |
| 24 | බුද්ධානුස්සතිය (B17) | 11 verses as printed (Buddhānussati mettā ca … Dissamānopi) | B17–19 |
| 25 | මෙත්තානුස්සතිය (B19) | 5 verses | B19–20 |
| 26 | අසුභානුස්සතිය (B21) | 6 verses | B21–22 |
| 27 | මරණානුස්සතිය (B22) | 7 verses | B22–23 |
| 28 | අට්ඨ මහා සංවේග වත්ථු (B24) | 3 verses | B24 |
| 29 | පටිච්ච සමුප්පාදය – අනුලෝම (B25) | 1 verse (the whole formula) | B25 |
| 30 | පටිච්ච සමුප්පාදය – පටිලෝම (B26) | 1 verse | B26 |
| 31 | නිවැරදි පිළිසරණ යෑම (B27) | 5 verses | B27–28 |
| 32 | තිලකුණු මෙනෙහි කිරීම (B28) | 3 + 3 verses (the three characteristics, then Appakā, Yē ca kho, Kaṇhaṃ) | B28–29 |
| 33 | මෛත්‍රී භාවනාව (B29) | 11 verses (the eight paragraphs of the chant, then the three Uddhaṃ yāva verses); the closing Sādu ×3 is not a verse | B29–34 |

Verse counts per section, in order: 5 1 1 1 5 5 5 8 1 3 1 1 2 2 1 1 1 1 1 3 1 4 4 11 5 6 7 3 1 1 5 6 11 = 114 verses.

Sādhu ×3 after section 1 is kept because the booklet prints it inside that
section; the closing "Sādu! Sādu! Sādu!" on page 34 is the booklet's end mark
and is dropped (designer's call).

What stays exactly as today: every existing `pali_si`, `sinhala`, `english`,
`english_source`, note and correction; only `number`, `id` and position
change for the moved sections, and `pali_roman` is filled.

### Section and verse ids

Ids follow position as today: `s01`…`s33`, verses `sNN-vM`. Saved places,
bookmarks and "Today" refer to ids, so a person's bookmark on today's s18
(merit to devas) would point at the new s18 (betel). This is a one-time
renumbering before release; no migration (designer's call, the app has not
shipped). "Today" eligibility (`lib/home/today.dart`) is recomputed from the
content and its test list is rewritten.

### Sources, per section and per verse

- Section `source` as today for existing sections. New sections:
  `{"name": "Shanthi Vihara, Nottingham — Evening Puja and Chanting", "locator": "evening_puja_and_chanting.pdf (supplied by the app's owner, 2026-11-17), printed page N", "collected": "2026-11-17", "translator": "not named by the source"}`.
- New per-verse field `source` (same shape), set only on verses whose Pali
  comes from a different source than their section: s05–s07 v2–v5 (the
  booklet, inside namo.lk sections). The Dart `Verse` gains `source`
  (`SourceRecord?`, JSON `source`); `Verse.sourceOr(section)` returns the
  verse's own or the section's. Nothing in the reader shows it.
- English per verse through `english_source`/`english_kind` as today;
  booklet English is kind `translation`, translator "not named by the
  source".
- Sinhala from the paritha.org booklet for the verses listed above keeps
  that source's name in the verse `source` where the section is a booklet
  section (s08 Namāmi verses: Pali from B, Sinhala from paritha.org — the
  verse `source` names the booklet and a new `sinhala_source` field names
  paritha.org with its printed page). Dart reads `sinhala_source` into
  `Verse.sinhalaSource` (`SourceRecord?`), not shown.

### Extraction: `tools/extract_nottingham_booklet.py`

Usage: `python -I -X utf8 tools/extract_nottingham_booklet.py <pdf> <out_json> <out_md>`
(same shape of command as the other extractors). PyMuPDF `rawdict`; spans
in FM fonts (`is_fm`) are converted with `fm_to_unicode.convert`, with spans
of one line joined without added spaces; other spans are kept as printed.
Each line gets a kind from its font and size:

- `heading`: the boxed titles (Calibri-Bold large, or BodoniMT) and the
  FM-font heading on the same line; the Sinhala heading and the English
  heading are kept as two fields of one heading line.
- `pali_si`: an FM-font line.
- `roman`: a Calibri-Bold line (the Roman Pali).
- `english`: a regular Calibri line of small size.
- `note`: an italic or bracketed line such as "(Bow)", "(Three times)",
  "(Only chant verses for what you are offering)".
- `break`: a blank line.

Output `content/extracted/nottingham_booklet.json`: `source{file, sha256,
pages, fonts, note}`, `conversion_problems`, `pages[{pdf_page,
printed_page, lines[{kind, font, size, text}]}]`, and `units`: the
extractor groups each page's lines into units in reading order — one unit =
the consecutive `pali_si` lines, then the `roman` lines, then the `english`
lines that follow, until the next `pali_si` or heading — with
`{page, index, heading?, pali_si, roman, english, notes}`. Headings start a
new unit list entry with `heading` set. Review `.md` lists every page's
lines with their kinds so a person can check the grouping.

`build_content.py` gains `NOTTINGHAM_SECTIONS`: for each new section, the
heading unit (page, index) and the list of verse units (page, index) in
order; `NOTTINGHAM_VERSES_INTO`: the extra verses that join s05–s07;
`NOTTINGHAM_ROMAN`: for every existing verse that the booklet prints, the
unit(s) whose `roman` fills `pali_roman` (several units for a multi-stanza
verse such as s22-v4); `NOTTINGHAM_ENGLISH`: the three existing verses whose
English comes from the booklet (s19-v1, s22-v2, s22-v3). Multi-line Roman and English keep the booklet's line breaks; a
verse printed as two half-lines joined by " - " is kept as printed.
`PARITHA_SINHALA`: the paritha.org lines (printed page, line indices) for
the Namāmi verses (printed page 3) and Iminā puñña (printed page 38),
reusing `_booklet_line`.

What the PDF's text layer looks like (checked on pages 3, 12 and 25 with
`rawdict`), so the extractor's rules are not guesses:

- Pali in Sinhala script: font `FMBindumathix`, size 17–19. Sinhala
  headings: the same font at size 20, alone on the line (and, for the
  offering sub-headings, `FMBindumathix` 19–25 together with an English
  `Calibri-BoldItalic` 15 label on one line).
- Roman Pali: `Calibri-Bold` 15–18 with the bold flag. "(Bow)" is the same
  style; a line whose text is only a bracketed word is a `note`.
- English: `Calibri` 12 regular (sometimes with a stray bold or italic span
  of the same text).
- Section titles in English: `Calibri-Bold` 18 upper case, preceded by a
  `Calibri` 24 span; "(Only chant verses …)" is `Calibri` 16 in brackets.
- Justified Roman lines are split by the text layer into several "lines"
  with the same baseline (page 25: "Viññāṇa", "paccayā", "nāma-rūpan" …).
  The extractor merges lines whose baselines agree within 1 pt, in x
  order, before classifying.
- Stray `FMBindumathix` lines of size 6–12 whose text is only a digit
  ("1") are paragraph marks; they are dropped.
- A Sinhala word is sometimes split by a space before a combining sign in
  the layer ("b;sm s fida"); the converter is given the joined span text
  with those spaces removed when the next character is a vowel sign or
  virama. Section order is a single list `ORDER` of 33 entries, each
naming its origin (`namo:<heading>`, `booklet:<n>`, `nottingham:<key>`).

### Corrections and checks

- The FM conversion is checked three ways: the converter's self-test; the
  extractor's `conversion_problems` must be empty for the pages used (a
  `⟦x⟧` anywhere fails the build); and, for every existing verse the
  booklet also prints, the build compares the converted booklet Pali with
  the app's `pali_si` after normalisation (whitespace, punctuation,
  zero-width joiners removed). The booklet and namo.lk do differ in places
  (checked: නිසින්නෝච/නිසින්නෝව, සාරථී/සාරථි, භගවාතී/භගවාති,
  සන්දිට්ඨිකො/සන්දිට්ඨිකෝ, මහාබෝධී/මහා බෝධි; and the third forgiveness
  verse ends "පුඤ්ඤක්ඛෙත්තං අනුත්තරං" in the app but "සුපටිපන්න අනුත්තර" in
  the booklet). So the comparison is gated by an allow-list
  `PALI_VARIANTS` in `build_content.py`: `(verse id, class, what differs)`
  with class `minor` (vowel length, a word split, a single letter) or
  `wording` (different words). A difference that is not listed fails the
  build with both texts in the message, so a conversion error can never
  slip in as a "variant". The app's `pali_si` never changes.
- `pali_roman` is filled from the booklet for a matching verse and for a
  `minor` variant (the Roman is the booklet's own transliteration of its
  own spelling; "sārati" under "සාරථී" is tolerated). For a `wording`
  variant it stays null, so search never matches words the screen does
  not show. The extractor's review `.md` lists every difference, old and
  new text side by side, for the owner.
- Roman and English are copied as printed, including the booklet's own
  inconsistencies ("sārati", "bagavāti", "Ētēna/Ēthēna", "Dasova hasmi",
  "Sādu"). No correction rows for them; the Sources page already says
  English is "as given". On the booklet's prose pages (17–34) the English
  is re-set as paragraphs, whitespace only and guarded, as the Mahamevnawa
  English already is; pages 3–16 keep the booklet's line breaks (ruled
  2026-11-17).
- Checking the new material is recorded per section, not per verse, so
  the Sources page does not grow by ninety rows. The section schema gains
  `notes` (a list, like a verse's); the Dart `Section` reads it
  (`Section.notes`) and the Sources page's "Still to be checked" lists one
  row per section whose check is `needs checking`, showing its notes, as
  well as the per-verse rows it lists today. The new sections (1, 8, 21,
  23–33) are `needs checking` with the note "Converted from the booklet's
  FM font; to be read against printed page N."; their verses are
  `needs checking` without notes. Sections 5–7 are `needs checking` with
  the note "Verses 2–5 converted from the booklet's FM font; to be read
  against printed pages N–M."; their first verses stay `checked`. That is
  17 section rows plus the 4 verse rows that exist today. The owner clears
  a section by reading it in the app, and the build flips it to checked
  (a row removed from the table).

### Sources page, README, checklist

- Sources page: a new `_Credit('Shanthi Vihara, Nottingham', 'Evening Puja
  and Chanting booklet: the Pali, Roman Pali and English of sections 1, 8,
  21 and 23–33, verses 2–5 of sections 5–7, three English lines in 19 and
  22, and the Roman Pali of the other sections.')` without an address (a
  printed booklet supplied by the owner). The namo.lk and paritha.org lines
  name their new section numbers (namo.lk: 2–7 first verses, 9–19;
  paritha.org: 20 and 22, and the Sinhala of three verses in 8 and 23). The
  "not connected with" line adds the vihara.
- README "Sources": the same facts; the Commands line gains the extractor.
- `docs/release-checklist.md`: "Buddha Wandanawa (sections and English from
  the Shanthi Vihara, Nottingham booklet): do not publish the app … until
  the owner confirms the vihara's permission; then add 'used with
  permission' to the Sources entry." Plus the owner check: read the new
  sections in the app against the booklet and clear their notes.

### Tests

- Tool: `tools/test_extract_nottingham_booklet.py` (kinds, FM joining, unit
  grouping on a synthetic page dict); `tools/test_build_content.py` updated
  to 33 sections and the new verse counts, order, per-verse sources,
  `pali_roman` present where listed, the three new English, the paritha
  Sinhala reuse, the Pali-equality check, and the checks/notes.
- Dart: `model_test` (per-verse `source`, `sinhalaSource`, `Section.notes`),
  the count tests listed under Constraints, `today_test`'s verse list,
  `sources_screen_test` (new credit, section check rows, counts),
  `real_content_reader_test` (33 headings, last heading "මෛත්‍රී භාවනාව"),
  glyph check on the new strings.

### Size

About 110 verses instead of 28; the JSON grows by roughly 60 KB. No effect
on the install size worth measuring.

## Left to the builder

- The exact font/size thresholds that separate `roman`, `english` and
  `note` lines in the PDF (inspect the `rawdict` of pages 3, 12, 25, 29).
- Whether "Sādhu Sādhu Sādhu" is a verse of section 1 or a line appended to
  the fourth verse (the booklet sets it alone, centred; a separate verse is
  the expectation).
- How the three "Imāya dhammānudhamma" lines and the Idan mē ñātīnan ×3 are
  laid out (one verse with three lines is the expectation).
- The review `.md` format.

## Open with the owner (defaults taken so the build can start)

- Shanthi Vihara's permission for the English: asked for in the checklist;
  the build does not wait for it, publication does.
- The booklet PDF is tracked under `source_material/evening_puja_nottingham/`
  like the three other booklets. Say if you would rather keep it out of the
  repository (then only the extraction JSON is tracked).
- New sections without Sinhala meaning show the note the app already uses
  ("Sinhala is not yet available for this section.").
