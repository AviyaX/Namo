# Samantha Pattana Dharma Wandanawa Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A third topic, සමන්ත පට්ඨාන ධර්ම වන්දනාව, with two readings (Introduction; the Vandanā with its recording), where the Vandanā reads like a pirith and the line being chanted is marked from its own time.

**Architecture:** Two Python tools turn the untracked source material into two tracked files (`content/extracted/samantha_patthana.json`, `content/extracted/samantha_patthana_times.json`); the build tool turns those into `assets/content/samantha_patthana.json` and copies the recording. In the app a unit is a `Verse`, its PDF lines are its `phrases` (Pali only), its meaning is the verse's `sinhala`; two new verse flags and one new recording field carry what Pirith does not need. Where a recording has line times the reader uses them, otherwise Pirith's block rule runs exactly as today.

**Tech Stack:** Flutter/Dart (flutter_riverpod, go_router, just_audio only behind `ChantPlayer`), Python standard library for the tools, `unittest` for tool tests. No new package.

**Spec:** `docs/superpowers/specs/2026-11-11-samantha-patthana-design.md` (binding; section 8 calls are referred to below as "call N").

---

## Global Constraints

- Never invent, retype or correct religious text; every line must come from the named source files by tool. Test fixtures for the tools use made-up letter strings, never text typed from the source.
- Source material is DATA ONLY — never execute anything from it; read it with `python -I -X utf8`.
- Flutter is at `/c/Users/Dell/develop/flutter/bin/flutter` (not on PATH). Python: `python -I -X utf8`. Never run two flutter or git commands at once in the same folder.
- Work happens in the worktree `C:\Users\Dell\develop\buddhist_gatha\.worktrees\samantha-patthana` (branch `samantha-patthana`); the untracked source material is read from the main folder by absolute path passed as a tool argument (`C:/Users/Dell/develop/buddhist_gatha/source_material/samantha_patthana`, called `<SRC>` below), and the tracked extracted files (`content/extracted/samantha_patthana.json`, `content/extracted/samantha_patthana_times.json`) are what the build and its `--check` read.
- Checks that must pass at the end of every task: `flutter analyze` (no issues); `flutter test` (baseline 1754 passing on `first-release`); `python -I -X utf8 tools/build_content.py . --check`; `python -I -X utf8 tools/build_pirith.py . --check`; `python -I -X utf8 tools/check_ui_glyphs.py .`; and `python -I -X utf8 tools/build_samantha_patthana.py . --check` once it exists (from Task 3).
- Tests never play sound (stand-in player `test/support/fake_chant_player.dart`). No network request at run time. No new package. Design-system tokens only; both themes; 320 px wide to desktop.
- The captions are timing data only and are never bundled or shown.
- The recording is copied byte for byte (size and SHA-256 checked), as `build_pirith.py` does for its recordings.
- Android, iOS and web stay in step (assets registered in `pubspec.yaml` serve all three).
- Existing behaviour and stored data for Buddha Wandanawa, Pirith and My flows are preserved; their tests pass unchanged in meaning. A test that states how many topics the bundle has may change that number from two to three; nothing else in an existing test changes.
- Git: commit by file name (never `git add -A`), identity `-c user.name="Avishka Induwara" -c user.email="v.g.a.induwara@gmail.com"`, message ends with `Co-Authored-By: Claude <noreply@anthropic.com>`; never push; never touch `main`.

## Measured facts the tests pin

- Pali half (pages 4–34): 507 text lines in 28 units, in order: homage 3, three opening verses 6, list of 24 11, parts 1–24 = 6, 27, 19, 55, 55, 14, 9, 31, 29, 45, 5, 10, 8, 5, 7, 22, 6, 6, 5, 6, 50, 6, 6, 50, closing 5. A part's lines include its numbered heading line and its two worship-verse lines.
- Sinhala half (pages 35–56): 385 text lines: homage 4, list 9, parts 1–24 = 4, 26, 14, 43, 43, 12, 6, 23, 22, 43, 3, 7, 5, 3, 5, 15, 4, 4, 3, 4, 37, 4, 4, 37, closing 1. The three opening verses have none.
- In `converted/pages/page-NN.txt` line 1 is the printed page number; `structure.json` line numbers are 1-based; a unit runs from its start to the next unit's start (`ends_before`). Blank lines inside a unit are not lines of text.
- Introduction: the body of `introduction_owner_supplied.md` after the `---` line; 3 paragraphs separated by blank lines (253, 617 and 1054 characters).
- Recording `audio/hYXyO3o7Iac.m4a`: 46,219,957 bytes, SHA-256 `fe3bdcda759cbd18e4e2e0bfc739d25301622b217f84995ac9c5e5bdc61b2c20`, 2856 s (47:36).
- Captions `audio/captions/si-orig.json3`: `events[]` with `tStartMs`, `dDurationMs`, `segs[{utf8, tOffsetMs?}]`; 2,171 non-blank words.
- Timing baseline (rough in-order letter match: Sinhala letters only, hal kirima and anusvara stripped, `difflib.SequenceMatcher` over the concatenated letters): 79% of letters matched, 437 of 507 lines timed, no step backwards; the misses are in long runs of near-identical sentences (PDF pages 9–10).

## New interface strings (exact)

- Ids: category `cat-samantha-patthana`; readings `sp-introduction`, `sp-vandana`; each reading's one section `p`; units `u-homage`, `u-verses`, `u-list`, `u-part-1` … `u-part-24`, `u-closing`; Introduction verses `intro-1`, `intro-2`, `intro-3`.
- Names: category title `Samantha Pattana Dharma Wandanawa`, subtitle `සමන්ත පට්ඨාන ධර්ම වන්දනාව`, chip `Samantha Pattana`; reading and heading `Introduction`; Vandanā title and heading `සමන්ත පට්ඨාන ධර්ම වන්දනාව` (taken by the tool from `structure.json`'s `title_page` if it holds exactly this string, otherwise from a named constant copied from the spec; never typed into Dart), Roman `Samantha Pattana Dharma Wandanawa`.
- Recording label: `Chanted by Ven. Kiriwaththuduwe Ariyadassana Thero`.
- Files: `tools/build_samantha_patthana.py`, `tools/time_samantha_patthana.py`, `tools/test_build_samantha_patthana.py`, `tools/test_time_samantha_patthana.py`, `content/extracted/samantha_patthana.json`, `content/extracted/samantha_patthana_times.json`, `content/samantha_patthana_timing_report.md`, `assets/content/samantha_patthana.json`, `assets/audio/samantha_patthana/hYXyO3o7Iac.m4a`, `assets/pictures/samantha_patthana.jpg`.
- Asset JSON keys (new): category `short_title`; verse `keep_lines`, `always_shown`; audio `line_times`.
- Dart (new): `Category.shortTitle`, `Verse.keepLines`, `Verse.alwaysShown`, `RecordingInfo.lineTimes`, `Recording.lineTimes`, `placeAt(..., lineTimes:)`, `ChantFollow.lineStart(block, phrase)`, `listsReadings(Category)`, `readingCountLabel(int)`, `ReaderBody.onTapLine`.
- Widget keys: `reading-row-<reading id>` (Library rows of this topic), `check-reading-<reading id>` (Sources). Existing keys are reused unchanged: `block-<verse id>`, `block-active`, `passage-<verse id>-<language name>`, `pirith-row-<id>`.
- Interface text: `Previous reading`, `Next reading`, `2 readings` (from `readingCountLabel`), `Samantha Pattana`, and the Sources entry (Task 8).
- Tool messages: `samantha patthana content is up to date`, `wrote assets/content/samantha_patthana.json`.

## Review Focus

1. A line is dropped, joined, reordered or put in the wrong unit between the PDF pages and the app (parts differ only by number; blank lines sit inside units). → Task 1 tool test (every extracted line equals its page-file line; the per-unit counts above) and Task 3 content test (507 / 385 / 28, Introduction character for character).
2. The line mark steps backwards, or sits on a line whose time is missing or estimated wrongly (homage chanted three times; long runs on pages 9–10). → Task 2 invariants test on the committed times file and Task 4 sweep test over the real times.
3. Pirith reads or follows differently because the shared block view and `placeAt` changed (space-joined passage, length estimate inside a block). → Task 4 test "a recording without line times places exactly as before" and Task 5 test "a pirith block is unchanged"; every existing Pirith test untouched.
4. A meaning shows under the wrong unit, shows with Sinhala off, or a language choice leaves a reading empty (Introduction with Pali only; Vandanā with English only). → Task 5 reader tests, one per language choice.
5. Caption words, the PDF or anything else from the source material reaches the bundle, or the recording is fetched before play. → Task 3 tool `--check` (exactly one file in the audio folder, asset rendered only from the two tracked files) and Task 8 assets test.

---

### Task 1: Extract the text into a tracked file

**Files:**
- Create: `tools/build_samantha_patthana.py` (extract mode only in this task), `tools/test_build_samantha_patthana.py`, `content/extracted/samantha_patthana.json`

**Interfaces:**
- Consumes: `<SRC>/converted/structure.json`, `<SRC>/converted/pages/page-NN.txt`, `<SRC>/introduction_owner_supplied.md`.
- Produces: `python -I -X utf8 tools/build_samantha_patthana.py . --extract <SRC>` writes `content/extracted/samantha_patthana.json`:
  `{"source": {...page ranges, file names...}, "title": "<Sinhala title>", "introduction": ["<paragraph>", ×3], "units": [{"id": "u-part-4", "kind": "homage|verses|list|part|closing", "number": 4 (parts only), "pali": [{"page": 9, "line": 12, "text": "…"}], "sinhala": [{"page","line","text"}]}]}` — 28 units in the order above; `sinhala` is `[]` for `u-verses`. Rendered with `json.dumps(ensure_ascii=False, indent=1) + "\n"`, as `build_pirith.py` does. Functions `extract(src) -> dict` and `render(obj) -> str`; errors raise `BuildError`.

- [ ] Write `tools/test_build_samantha_patthana.py` (`unittest`, in the style of `tools/test_build_pirith.py`): (a) with a small made-up source folder in a temp dir (two units, a blank line inside one, a page break inside one) `extract` gives the lines in order, skips line 1 of each page and blank lines, and assigns each line to the unit whose range holds it; (b) a `structure.json` whose part numbers are not 1–24 in order, or whose ranges overlap or leave a text line outside every unit, raises `BuildError`; (c) on the committed `content/extracted/samantha_patthana.json`: 28 units with the ids above, the per-unit Pali and Sinhala counts above (507 and 385), three Introduction paragraphs of 253, 617 and 1054 characters, no line with leading or trailing whitespace; (d) when the folder named by environment variable `SAMANTHA_PATTHANA_SRC` exists, every extracted line equals the text at its `page`/`line` in the page files and `render(extract(src))` equals the committed file (skipped, with the reason printed, when the variable is unset).
- [ ] Run it; see it fail.
- [ ] Write the extract mode. Units come only from `structure.json`'s starts and `ends_before`; text comes only from the page files; the Introduction is the body after the first `---` line split on blank lines, nothing trimmed inside a paragraph.
- [ ] Run `python -I -X utf8 tools/build_samantha_patthana.py . --extract <SRC>`; then `SAMANTHA_PATTHANA_SRC=<SRC> python -I -X utf8 tools/test_build_samantha_patthana.py`; all pass.
- [ ] Global checks; commit the three files: `Samantha Pattana: extract the text into a tracked file`.

### Task 2: Line times from the captions

**Files:**
- Create: `tools/time_samantha_patthana.py`, `tools/test_time_samantha_patthana.py`, `content/extracted/samantha_patthana_times.json`, `content/samantha_patthana_timing_report.md`

**Interfaces:**
- Consumes: `content/extracted/samantha_patthana.json` (Task 1); `<SRC>/audio/captions/si-orig.json3` by absolute path.
- Produces: `python -I -X utf8 tools/time_samantha_patthana.py . <captions.json3>` writes
  `content/extracted/samantha_patthana_times.json` = `{"duration_ms": 2856000, "units": [{"id": "u-homage", "lines": [{"start_ms": 440, "end_ms": 5200, "how": "matched"}, …]}, …]}` — one entry per Pali line, same order and counts as Task 1's file, `how` is `matched` or `estimated`; and the report (below). Function `time_lines(units, events, duration_ms) -> list` is pure.

Requirements (the matching method is the implementer's):
- Every one of the 507 lines gets `start_ms` and `end_ms`. Starts never decrease across the whole file; each `end_ms` ≥ its `start_ms` and ≤ the next line's `start_ms`; the last `end_ms` ≤ 2,856,000.
- A line without a confident match is `estimated`: its time is interpolated between its nearest `matched` neighbours in proportion to the letter count of the lines between them (letters counted as in the baseline: Sinhala letters only).
- The homage is matched to its first chanting; the first line of `u-verses` must be matched after all three chantings (the report states its start time so the owner can check it by ear).
- Target: better than the baseline of 79% of letters and 437 of 507 lines matched. The report must state the achieved letters % and matched-line count beside the baseline, whatever they are; falling short is reported, not hidden.
- Report `content/samantha_patthana_timing_report.md`: achieved figures and baseline; start time of each of the 28 units; every estimated line as `unit id, line number in unit, page, line, start` (identified by position, the text is not copied in); the longest run of consecutive estimated lines.
- The captions' words are never written to either output.

- [ ] Write `tools/test_time_samantha_patthana.py`: (a) `time_lines` on made-up letter strings with made-up caption events: exact matches get the caption times; a line with no caption words between two matched lines is `estimated` and placed by letter count; two identical consecutive lines are not swapped; output never steps backwards even when a caption event is out of order; (b) on the committed times file with the committed extracted file: same unit ids and per-unit line counts, every invariant in the requirements, `how` only `matched|estimated`, matched count ≥ 437 (if the implementer could not reach it, this number is set to the achieved count and the shortfall is the first line of the report and of the task report); (c) the report names exactly the lines marked `estimated`; (d) neither output contains a caption word that is not also a substring of the Pali text (run only when `SAMANTHA_PATTHANA_SRC` is set).
- [ ] Run it; see it fail. Write the tool; generate both files from `<SRC>`; run the tests with and without `SAMANTHA_PATTHANA_SRC`.
- [ ] Global checks; commit the four files: `Samantha Pattana: line times from the captions`.

### Task 3: Build the asset, bring in the recording and picture, load it

**Files:**
- Modify: `tools/build_samantha_patthana.py`, `tools/test_build_samantha_patthana.py`, `tools/check_ui_glyphs.py`, `tools/test_check_ui_glyphs.py`, `lib/content/model.dart`, `lib/content/content_repository.dart`, `lib/audio/audio_catalogue.dart`, `lib/home/card_art.dart`, `pubspec.yaml`, `.gitignore`, `README.md`
- Create: `assets/content/samantha_patthana.json`, `assets/audio/samantha_patthana/hYXyO3o7Iac.m4a`, `assets/pictures/samantha_patthana.jpg` (a byte copy of `design/card_images/stupa_dusk.jpg`), `test/content/samantha_patthana_content_test.dart`
- Test (extend): `test/content/model_test.dart`, `test/content/content_repository_test.dart`, `test/content/pirith_content_test.dart` (category list only), `test/audio/audio_catalogue_test.dart`, `test/quality/quality_support.dart` (add `samanthaCategoryId`, `spIntroductionId`, `spVandanaId`), and any test that states the number of topics.

**Interfaces:**
- Consumes: the two tracked files from Tasks 1 and 2.
- Produces:
  - Tool: `tools/build_samantha_patthana.py <root> [--check] [--import-audio <dir>] [--extract <src>]`; `build(root) -> dict`; constants `CORRECTIONS = []` (rows `(from, to, expected count, reason)`, applied to line text at build, a row whose count does not match raises `BuildError`), `UNTIMED_UNITS = ("u-homage",)`, `RECORDING = "hYXyO3o7Iac.m4a"`, `RECORDING_BYTES = 46219957`, `RECORDING_SHA256`, `DURATION_MS = 2856000`.
  - Asset (schema 1, same keys as `pirith.json` unless listed): one category with `short_title`; reading `sp-introduction` = one section `p`, three verses each `{"id", "sinhala": <paragraph>, "always_shown": true, "check": "needs checking"}`; reading `sp-vandana` = `title_roman`, `audio`, one section `p`, 28 verses each `{"id", "keep_lines": true, "phrases": [one per Pali line, Pali only, the other languages as Pirith writes an absent one], "sinhala": <the unit's meaning lines joined with "\n"> (absent for `u-verses`), "check": "needs checking"}`.
  - `audio`: `asset`, `label`, `duration_ms`, `block_times` (seconds; unit start = its first line's start, unit end = the next unit's start, the last unit's end = its last line's end), `line_times` = one list per unit of start seconds or `null`; every line of a unit in `UNTIMED_UNITS` is `null`.
  - Dart: `Category.shortTitle` (String?, from `short_title`); `Verse.keepLines`, `Verse.alwaysShown` (bool, default false, carried by `withId`); `RecordingInfo.lineTimes` (`List<List<Duration?>>`, empty when the key is absent); `Recording.lineTimes` passed through by `ContentAudioCatalogue`; `AssetContentRepository.paths` gains `assets/content/samantha_patthana.json` third; `cardPictures['cat-samantha-patthana']`.

- [ ] Tool tests first (extend `tools/test_build_samantha_patthana.py`): build from made-up extracted and times files gives the shape above; a times file whose counts differ from the text raises; a correction row applies and a wrong count raises; `UNTIMED_UNITS` nulls exactly those lines and leaves the unit's block time; `--check` fails on a changed asset, a recording of the wrong size or checksum, and an extra file in `assets/audio/samantha_patthana/`; `--import-audio` refuses a file of the wrong size. On the committed asset: 507 phrases, 385 meaning lines, 28 units, `line_times` lengths equal phrase counts.
- [ ] Write build, `--check` and `--import-audio` following `build_pirith.py`'s `_check` and `import_audio`. Run `--import-audio <SRC>/audio`, then the build, then `--check`.
- [ ] Copy the picture (byte copy; test it is byte-equal to `design/card_images/stupa_dusk.jpg`); register `assets/audio/samantha_patthana/` and `assets/pictures/samantha_patthana.jpg` in `pubspec.yaml`; add `source_material/samantha_patthana/` to `.gitignore` with a comment like the Pirith one.
- [ ] Dart tests first: `model_test.dart` (the new fields parse, default when absent, `withId` keeps both flags); `audio_catalogue_test.dart` (`lineTimes` passed through; empty for a pirith); `content_repository_test.dart` (three files in order); new `samantha_patthana_content_test.dart` (the bundle's categories are Buddha Wandanawa, Pirith, Samantha Pattana; ids, names and chip as listed; per-unit phrase and meaning-line counts above; every phrase and meaning line equals the extracted file's line for its unit and position; the Introduction's three verses equal the extracted paragraphs; all 31 verses need checking; `audio.duration` 47:36; `blockTimes` has 28 entries, none null, starts non-decreasing; the homage's `lineTimes` are all null and every other line has one; no Pirith reading has line times).
- [ ] Then the Dart changes. Daily Gatha needs no change (`today.dart` already takes only checked verses with Pali text); extend `test/home/today_test.dart` with "no verse of Samantha Pattana is picked".
- [ ] `check_ui_glyphs.py`: also check this asset's `title`, `subtitle`, `short_title` and `title_roman` values against the same fonts as the Pirith names; extend its test.
- [ ] README: a "Samantha Pattana content" section in the shape of "Pirith content" (extract, time, build, check, import, where the originals live, tests).
- [ ] Global checks including the new `--check`; commit by name: `Samantha Pattana: built asset, recording, picture and model`.

### Task 4: Place the chanting by line times

**Files:**
- Modify: `lib/audio/chant_timing.dart`, `lib/reader/chant_follow.dart`
- Test (extend): `test/audio/chant_timing_test.dart`, `test/reader/chant_follow_test.dart`

**Interfaces:**
- Consumes: `Recording.lineTimes`, `blockTimes` (Task 3).
- Produces: `placeAt(position, times, paliLengths, {List<List<Duration?>> lineTimes = const []})`: the block is chosen exactly as today; when `lineTimes` has an entry for that block, `phrase` = the last line of the block whose time is non-null and ≤ position, or `-1` when there is none (the block is active, no line is marked); when it has none, today's length estimate. `ChantFollow({times, paliLengths, lineTimes})`; `ChantFollow.lineStart(block, phrase)` = that line's time, or `blockStart(block)` when it is null or out of range.

- [ ] Tests first: (a) a recording without line times gives the same `ChantPlace` as before for a table of positions (copy three cases from the existing tests, with `lineTimes` left out and with `const []`); (b) with line times: before the first line of a block → `-1`; at a line's start → that line; a null line is skipped and the earlier timed line stays; an all-null block → `-1` throughout; (c) with the bundled recording's real times, stepping the position from zero to the end in 500 ms steps, `(block, phrase)` never decreases, every timed line of every unit is reached, and the homage gives `(0, -1)` until `u-verses` starts; (d) `lineStart` for a timed line, a null line and a bad index.
- [ ] Implement; run; global checks; commit: `Chanting is placed by line times where a recording has them`.

### Task 5: The reader shows the two readings

**Files:**
- Modify: `lib/reader/reader_items.dart`, `lib/reader/reader_body.dart`, `lib/reader/reader_screen.dart`, `lib/reader/reader_bottom_bar.dart` (tooltips are already parameters; change only if needed)
- Create: `test/reader/samantha_patthana_reader_test.dart`
- Test (extend): `test/reader/reader_items_test.dart`, `test/reader/phrase_block_test.dart`

**Interfaces:**
- Consumes: `Verse.keepLines`, `Verse.alwaysShown`, `listsReadings` (define it here in `lib/home/card_art.dart` beside `isPirithTopic`: more than one reading and every reading has exactly one section).
- Produces: `PhraseBlockItem.keepLines` and `PhraseBlockItem.meaning` (String?); `ReaderBody.onTapLine` is added in Task 6.

Behaviour:
- **A unit (a `keepLines` verse)** is one `PhraseBlockItem`, keyed `block-<verse id>` as today. Its Pali passage (`passage-<verse id>-pali`) joins the phrases with `"\n"` instead of a space (one character, so the existing range arithmetic holds); a long line wraps. The meaning is one passage under it (`passage-<verse id>-sinhala`), the verse's `sinhala`, with its line breaks, in the secondary colour Pirith uses for a second language.
- **Language choice** (call 4): Pali chosen → the lines; Sinhala chosen → the meaning; English chosen → nothing for English, and if Pali is not also chosen the Pali lines are shown in its place (so English alone shows the Pali alone, English with Sinhala shows Pali then meaning); Sinhala alone shows the meaning alone. A unit with no meaning shows nothing for Sinhala. No "not yet available" note for this reading.
- **Heading of the Vandanā**: as a pirith's — title, Roman name, the credit line from `audio.label`, no bookmark button.
- **The Introduction (`alwaysShown` verses)**: each paragraph is a `VerseTextItem` in Sinhala, primary colour, whatever the language choice; no notes; heading without a bookmark button; the settings sheet hides the two-language layout choice as it does for a pirith; the bar is the plain one (no recording).
- **Previous / Next**: in a topic where `listsReadings` is true and the reader is not showing a flow, the bar's buttons go to the previous/next reading of the topic, as Pirith's do today. Pirith keeps `Previous pirith` / `Next pirith`; any other such topic uses `Previous reading` / `Next reading`. Generalise `_pirith` and `_neighbour` in `reader_screen.dart` to this rule without changing what a pirith does.
- Everything else (favourite, remembered place, auto-scroll, text size, line spacing, lazy list) is what a one-section pirith gets today.

- [ ] Tests first. `reader_items_test.dart`: the items for a made-up `keepLines` reading under each of Pali, Sinhala, English, Pali+Sinhala, English+Sinhala; the items for `alwaysShown` verses under Pali only and English only; a pirith's items are unchanged (existing cases untouched). `phrase_block_test.dart`: "a pirith block is unchanged" (its Pali passage text is the phrases joined by one space); a `keepLines` block's passage text is the phrases joined by `"\n"`; the meaning passage is absent with Pali only and present with Sinhala; a unit with no meaning has no Sinhala passage.
- [ ] `samantha_patthana_reader_test.dart` (bundled content through `openReal`): the Introduction under Pali only shows its three paragraphs, no note, the plain bar (no `chant-play`), and Next goes to the Vandanā (`Next reading`); the Vandanā shows title, Roman name and `Chanted by Ven. Kiriwaththuduwe Ariyadassana Thero`, has `chant-play`, and Previous goes to the Introduction; with Pali only no `passage-u-part-1-sinhala`, with Pali+Sinhala it is under `passage-u-part-1-pali` and inside `block-u-part-1`; with English only the Pali of `u-homage` shows; `u-verses` never has a Sinhala passage; a favourite and a remembered place survive a reopen as for a pirith; `test/reader/reader_settings_sheet_test.dart` gains "no layout choice for the Introduction".
- [ ] Implement; global checks; commit: `Reader: Samantha Pattana's units, meaning and Introduction`.

### Task 6: The line being chanted is marked and can be tapped

**Files:**
- Modify: `lib/reader/reader_body.dart`, `lib/reader/reader_screen.dart`
- Create: `test/reader/samantha_patthana_chanting_test.dart`
- Test (extend): `test/quality/quality_support.dart` (`openChanting` already takes `id`; add what the new tests need)

**Interfaces:**
- Consumes: `placeAt(..., lineTimes:)`, `ChantFollow.lineStart` (Task 4); the unit block (Task 5).
- Produces: `ReaderBody.onTapLine` (`void Function(int block, int phrase)?`), called for a pointer tap on a block; `onTapBlock` stays for Pirith and for the block's semantic tap action.

Behaviour (calls 8–11):
- `_bindAudio` gives `ChantFollow` the recording's `lineTimes`. The active unit gets `block-active` (Pirith's background); the active line gets Pirith's phrase mark over that line's range of the Pali passage; phrase `-1` marks nothing. With the Pali hidden (Sinhala alone) the unit background still shows and nothing is marked.
- Following scrolls to the marked line with the existing `offsetOfPhrase` (which already falls back to the block's top); `Follow the chanting`, hand-scroll pause, loading on first play, stopping on leaving and wake lock are untouched code paths.
- Once the chanting has been started, a tap on a line of a unit seeks to `lineStart(block, line)`; the line is found from the tap position in the Pali passage (a tap on the meaning or on padding, and the semantic tap action, seek to the unit's start). A pirith's tap still seeks to `blockStart`. Before the chanting has been started a tap does nothing, as today.

- [ ] Tests first (stand-in player, real times, no sound): moving the player to the middle of the third line of `u-part-1` marks exactly that line (the marked text equals that phrase) and `block-u-part-1` is `block-active`; stepping the player forward through a part, the marked line index never decreases; during the homage `block-u-homage` is active with no mark, and stays so at a position after the first chanting; the page follows when the marked line leaves the view and a hand drag shows `follow-chanting`; tapping the fifth line of `u-part-2` after play seeks the player to that line's time; tapping the homage seeks to the unit's start; tapping before play does not seek; with Sinhala alone the player plays, the unit is active and no mark exists; a pirith tap still seeks to its block start (existing test untouched).
- [ ] Implement; global checks; commit: `Reader: the chanted line of Samantha Pattana is marked and tappable`.

### Task 7: Library, Home, search, Saved, Continue

**Files:**
- Modify: `lib/library/library_screen.dart`, `lib/library/search.dart`, `lib/home/card_art.dart`, and only if a test below fails: `lib/home/continue_card.dart`, `lib/home/featured_card.dart`, `lib/home/home_screen.dart`, `lib/saved/saved_screen.dart`
- Create: `test/samantha_patthana/samantha_patthana_surfaces_test.dart`
- Test (extend): `test/library/library_screen_test.dart`, `test/library/search_test.dart`, `test/library/library_search_test.dart`, `test/home/home_screen_test.dart`

**Interfaces:**
- Consumes: `Category.shortTitle`, `listsReadings`, `cardPictures` (Tasks 3, 5).
- Produces: `readingCountLabel(int n)` (`1 reading` / `n readings`); `topicCountLabel` returns it for a topic where `listsReadings` is true and `isPirithTopic` is false.

Behaviour:
- **Library**: third topic after Pirith (call 15), thumbnail from the new picture, title and subtitle as listed, caption `2 readings`. The chip reads `c.shortTitle ?? c.title`, so `Samantha Pattana`; the other chips are unchanged. Open, it lists one row per reading: key `reading-row-<id>`, number from `numberOf`, title, Roman subtitle when there is one, caption `formatTime(duration)` only when the reading has a recording (`47:36` for the Vandanā, none for the Introduction — `formatTime(null)` must not be shown), tap opens the reader. Pirith's rows and keys are unchanged.
- **Home**: a third card with the picture and the same count label (call 15).
- **Search** (call 17): one hit per reading. The Vandanā is found by its names, any Pali line and any meaning line (a `keepLines` verse's `sinhala` joins what `_pirithHit` searches, under the Sinhala language rule it already applies); the Introduction by its name and its text; the topic's names find both. A hit row shows the reading's number in the topic and opens the reading. Pirith and Buddha Wandanawa hits are unchanged.
- **Saved** and **Continue Reading**: the Vandanā shows as a pirith does (Sinhala title, Roman name); the Introduction shows `Introduction` with the topic's subtitle (Saved) or its heading (Continue), which today's code already gives — tests prove it.

- [ ] Tests first: Library (order, chip label, count caption, two rows with keys, `47:36` on one and no time text on the other, tap opens each); search (a Pali line taken at test time from the bundled content finds only `sp-vandana`; a meaning line likewise; an Introduction word finds `sp-introduction`; `Samantha` finds both; one hit per reading; with Sinhala not chosen a meaning match names its language as existing hits do); Home (three cards, picture asset name, label); surfaces test (favourite both readings → Saved rows; open and leave the Vandanā → Continue card shows the Roman name; `Library` topic request by address opens it).
- [ ] Implement; global checks; commit: `Samantha Pattana in Library, Home, search and Saved`.

### Task 8: Sources, flows, whole-app checks, release notes

**Files:**
- Modify: `lib/settings/sources_screen.dart`, `docs/release-checklist.md`, `docs/pictures.md` (the new picture, if that file lists pictures in use)
- Create: `test/quality/samantha_patthana_assets_test.dart`
- Test (extend): `test/settings/sources_screen_test.dart`, `test/flows/add_sections_sheet_test.dart`, `test/reader/flow_reader_test.dart`, `test/quality/overflow_test.dart`, `test/quality/accessibility_test.dart`, `test/quality/reduced_motion_test.dart`

Behaviour:
- **Sources** (call 18): a new credit, title `Samantha Pattana Dharma Wandanawa`, text exactly: `Text: සමන්ත පට්ඨාන ධර්ම වන්දනාව, published by tipitaka.lk; converted to Unicode by tool; the Introduction as supplied by the app's owner. Chanting: Ven. Kiriwaththuduwe Ariyadassana Thero, from the channel Samata Dharmaya. No English meaning is included. Namo is not connected with tipitaka.lk or the channel.` (the Sinhala title is read from the loaded content, not typed in Dart). It never says "permission". The existing sentence about namo.lk and pitaka.lk is left as it is. The picture credit list gains the new card picture in the form the existing picture credits use.
- **Still to be checked**: a reading with one section whose every verse needs checking is one row — the reading's title, key `check-reading-<reading id>` — instead of one row per verse (31 rows all reading "Section 1"). Buddha Wandanawa's rows and keys (`check-<verse id>`) are unchanged; Pirith has none today, and a test fixes that it still has none.
- **Flows** (call 13): Add sections lists the two readings under the topic's title (today's one-section rule; test only). In a flow the Vandanā's units show as in its own reader — lines kept, meaning under the unit when Sinhala is on — and the Introduction's paragraphs always show; no recording button, no mark.
- **Release checklist**: one line, in the form of the Pirith line: do not publish or push publicly until the owner confirms permission for the tipitaka.lk text and the Samata Dharmaya recording, then add "used with permission" to the Sources entry; and two owner checks: the converted text (`REVIEW_converted_text.md`), and listening to the opening, a short part and part 4 with the timing report at hand (call 21: a drifting unit goes into `UNTIMED_UNITS`, then rebuild).

- [ ] Tests first: Sources (the entry's text, no "permission", the picture credit, the two `check-reading-…` rows, no `check-u-…` row, Buddha Wandanawa's rows as before, no overflow at the widths the file already uses); flows (both readings addable; a flow holding both shows Introduction text under Pali only and unit lines kept; no `chant-play`); `samantha_patthana_assets_test.dart` (the bundle has exactly one file under `assets/audio/samantha_patthana/` and it is the one the reading names; the picture is in the bundle; the asset JSON's keys are only the known ones, so nothing from the captions rode along); overflow (Library with the topic open, both readings, at 320 and the file's wide size, device text 1.0 and 2.0, Pali only / Pali+Sinhala / English only); accessibility, both themes (Library with the topic open, the Vandanā silent, chanting with a line marked, with `Follow the chanting` showing, a tappable unit at least 48 high); reduced motion (following the Vandanā jumps in one frame).
- [ ] Implement; global checks; commit: `Samantha Pattana: Sources, flows and whole-app checks`.

---

## After the tasks (controller)

- Run every global check once more on the branch; `flutter build web` and confirm in the browser at hand that no outside request is made, that the recording is requested only after play is pressed, and that the 46 MB `.m4a` plays and seeks (spec section 10).
- Give the owner: the timing report's figures and estimated lines, the 7 Introduction differences (listed, not applied), and the two release-checklist checks.
- Do not merge into `main`; do not push.

## Self-review (done)

- Spec coverage: calls 1–3 → Tasks 1, 3, 5; 4 → Task 5; 5 → Tasks 3, 7; 6 → Tasks 3, 5, 8; 7 → Tasks 1, 3, 5; 8–11 → Tasks 2, 4, 6; 12 → Task 5; 13 → Task 8; 14–15 → Tasks 3, 7; 16 → Task 3; 17 → Task 7; 18 → Task 8; 19–20 → Tasks 1–3; 21 → Tasks 3, 4, 8; 22 → Task 7. Section 11's acceptance points → Task 3 content test, Task 8 overflow, Task 6, the global constraint on existing tests, and the controller's browser check.
- Names used in later tasks (`lineTimes`, `keepLines`, `alwaysShown`, `shortTitle`, `listsReadings`, `lineStart`, `onTapLine`, `readingCountLabel`) are each produced by an earlier or the same task.
