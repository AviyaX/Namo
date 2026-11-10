<!-- Record of how the first-release plan was carried out: the working ledger, copied unchanged when the plan was finished on 2026-11-10. Lines marked "Ruling:" are decisions the builder took on the owner's behalf; lines marked "minor (deferred)" are small points left open (some were dealt with later in the final fix wave — see final-fix-report.md beside this file). -->

# SDD ledger — plan: docs/superpowers/plans/2026-11-10-namo-first-release.md

Spec: docs/superpowers/specs/2026-11-10-gatha-app-first-release-design.md
Branch: first-release (created from main at ad52ff9, in place, no worktree)
Flutter: /c/Users/Dell/develop/flutter/bin/flutter ; Python: python -I -X utf8
Baseline at ad52ff9: flutter test 1/1 pass (scaffold test), flutter analyze clean.
Models: implementers sonnet (opus for Tasks 4, 9, 10, 11); reviewers sonnet (opus for 4, 10, 11); final review fable.
Owner reports: plain words, short; screenshots after Stage 1 (Task 3) and Stage 4 (Task 10).

## Rulings before Task 1

- Ruling: work on a branch in place instead of a separate worktree — one owner, no remote, owner has this folder open in the editor and is not technical — if wrong, the branch can be moved into a worktree later at no cost.
- Ruling: Mahamevnawa `english_source.translator` is exactly `not named by the source`; "name Mahamevnawa" in Task 4's test means the `name` field — design line 194 and Task 6's test say so — if wrong, one string in the build script.
- Ruling: the screen keys `ValueKey('screen-home|library|saved|settings')` made in Task 3 must survive Tasks 5, 7, 14 (which rewrite those screens) — Task 3's router test depends on them — carried in those dispatches.
- Ruling: `chantPlayerProvider` (Task 12) must not be read when a reading has no recording — the just_audio plugin is absent in widget tests and every earlier reader test would break — carried in Task 12's dispatch.
- Ruling: stage checks (analyze, test, content check, web build, Chrome look) are run by the controller, not by implementers; implementers run analyze + test only.

## Pre-flight scan

Pairs sharing a file or interface:

| Tasks | Produces vs consumes | Found |
|---|---|---|
| 1 → 3 | `NamoApp` (MaterialApp) → Task 3 makes it a router app | agree |
| 1 → 9 | `namoText`, `NamoFonts`, `NamoSizes.readingColumn` → `readingStyle` | agree |
| 1 ↔ 2 | both edit `pubspec.yaml` (deps/fonts vs icon/splash config) | different sections; sequential |
| 2 → 14 | `assets/branding/namo_icon_square.png` → Sources page | agree |
| 3 → 5, 9, 14 | `Routes`, `routerProvider`, `pumpApp`, `NotFoundScreen` | agree; Task 3 defines path helpers, routes added in 5 (category, contents, reader placeholder), 9 (reader), 14 (sources) |
| 3 → 5, 7, 14 | placeholder screens with `screen-*` keys → rewritten | keys must be kept (ruling above) |
| 4 → 5, 6 | JSON shape → `fromJson` | agree; translator ruling above |
| 4 → 6, 14 | NEEDS = 4 verses, 15 correction rows + 1 heading | agree after ad52ff9 edits |
| 5 → 6 | minimal model + `testLibrary()` description → full model | agree |
| 6 → 7 | `ReadingLanguage` created in 6, `LanguageSelection` added to same file in 7 | agree |
| 6, 7 → 8 | `coverOf`, `text`, `LanguageSelection`, `TwoLanguageLayout` | agree |
| 7 → 9, 14 | `LanguageChooser`, `LayoutChooser`, `settingsProvider`; `settings_screen_test.dart` extended in 14 | agree |
| 7 → 10, 13 | `KeyValueStore`, keys `namo.*.v1` | agree |
| 8 → 9, 10 | `ReaderItem` list → body, capture/restore | agree |
| 9 → 10, 11, 12 | `ReaderBodyState.extents()`, controller, bottom bar slots | agree |
| 10 → 11 | restore calls `syncToPage()` | agree (11 adds the call) |
| 10 → 13 | controllers load from store; 13 makes loading tolerant | agree |
| 11 → 12 | `engine.play()` on audio start | agree |
| 10, 13 → 14 | `savedProvider`, `positionProvider.lastReadingId` | agree |

Per task, own text against itself:

| Task | Found |
|---|---|
| 1 | tests match interfaces; OK |
| 2 | no Dart tests; verification by grep, build and looking at the PNG; OK |
| 3 | tests need `screen-*` keys on placeholders (implied, not stated) — told to implementer |
| 4 | corrections list has 15 rows, COUNTS comment says 15; NEEDS has 4; OK |
| 5 | bundled-asset test in `testWidgets` needs `runAsync` or plain `test` with binding — implementer's choice |
| 6 | OK |
| 7 | OK |
| 8 | OK |
| 9 | favourite/play buttons exist but are wired later; must still carry labels (Global Constraints) |
| 10 | OK |
| 11 | OK |
| 12 | see chantPlayerProvider ruling |
| 13 | OK |
| 14 | OK |
| 15 | 216 overflow cases with real fonts; may be slow, not a conflict |

No task mandates anything the review rubric calls a defect (test bodies shown as `...` are outlines to be written out, not empty tests).

## Tasks
Task 1: dispatched (BASE ad52ff9, implementer sonnet)
Task 1: implementer DONE at 718e41d (agent a182cc8f5d4ffe46f); review dispatched (sonnet)
Task 1: ⚠️ items resolved by controller — font sha256 all match README; commit subject matches; test evidence in report.
Task 1: minor (deferred): theme_test checks 6 of 15 text roles (brief's list); a loop over all would guard "every TextStyle".
Task 1: minor (deferred): namoText weight→FontWeight rounds non-multiples of 100 down silently (typography.dart).
Task 1: minor (deferred): ElevatedButton colours come from generated ColorScheme, not the palette; NavigationBar/ListTile/TextField/Chip/SnackBar not yet themed flat — later tasks that use them must theme them.
Task 1: complete (commits ad52ff9..718e41d, review clean)
Task 2: dispatched (BASE 718e41d, implementer sonnet)
Task 2: implementer DONE at 0e216fc (agent a9533ffd9225cc869); review dispatched (sonnet)
Task 2: review (agent a566b68d1409a93ef) — spec ❌, 1 Important: ios project.pbxproj lines 445 and 503 ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS changed YES → AppIcon by the icon tool (confirmed by controller with git diff).
Task 2: ⚠️ items resolved by controller — dev deps were added in Task 1 (present in pubspec at 718e41d); square icon viewed by controller (1254 px, corners blend, faint gold outline at top is from the owner's image); build/test claims rest on report, stage check re-runs them after Task 3.
Task 2: minor (deferred): web/index.html line 97 — splash tool added a viewport meta with maximum-scale=1.0, user-scalable=no; Flutter web sets its own viewport at run time and may warn about an existing tag — check console at stage check, remove if it warns (Task 15 accessibility pass).
Task 2: minor (deferred): ios/Runner/Info.plist re-indented by the tool (126 changed lines for 2 real changes); index.html/manifest.json lost trailing newline.
Task 2: minor (deferred): tools/make_icon_square.py has no __main__ guard; per-pixel loops are slow (one-off tool).
Task 2: minor (deferred): re-running flutter_launcher_icons may re-break the pbxproj setting — check `grep ASSETCATALOG ios/Runner.xcodeproj/project.pbxproj` after any re-run.
Task 2: fix round 1/5 (1 addressed, 0 open — pbxproj setting put back to YES; commits 0e216fc..d92cea5)
Task 2: complete (commits 718e41d..d92cea5, review clean)
Task 3: dispatched (BASE d92cea5, implementer sonnet)
Task 2: implementer agent a9533ffd9225cc869; Task 3 implementer agent ab6d4869f6ed12611
Task 3: implementer DONE at a39e875; review dispatched (sonnet)
Task 3: review (agent a7bce27364d0e20f8) — spec ✅, approved, no Critical/Important.
Task 3: ⚠️ items resolved by controller — flutter test 7/7 at a39e875 (theme_test included); NamoSizes.wideBreakpoint = 840.0 (tokens.dart:14); theme.dart `style` helper checked (see next line if it fails).
Task 3: minor (deferred): not_found.dart and router.dart import each other — move Routes to its own file or give NotFoundScreen an onHome callback.
Task 3: minor (deferred): app_shell.dart repeats labelType already set in the theme; `_tabs` could be const; hard-coded SizedBox(height: 16) in not_found.dart.
Task 3: minor (deferred): wide layout has no SafeArea/left inset for the rail (matters on tablets with cut-outs; Task 15).
Task 3: minor (deferred): no test asserts rail tap-target size or tab semantics labels (Task 15 accessibility pass).
Task 3: complete (commits d92cea5..a39e875, review clean)
Stage 1 check (controller, at a39e875): analyze clean; test 7/7; web build OK; Chrome 390x844 and 1280x800, light and dark — tabs, rail, not-found page all look right. FOUND: the web build makes 3 outside requests at start-up — canvaskit.js + canvaskit.wasm from www.gstatic.com (default CDN) and Roboto woff2 from fonts.gstatic.com (engine's default fallback font). Breaks Global Constraint "no network request at run time".
Ruling: add Task 3b (not in the plan) — build web with `--no-web-resources-cdn` (README + every later stage check), and declare a font family named `Roboto` in pubspec that points at the bundled assets/fonts/Lora.ttf so the web engine does not download Roboto — the plan never covered the web engine's own downloads — if wrong: one pubspec block and one README line to undo. Stage Check command from now on: `flutter build web --no-web-resources-cdn`; shot.mjs must print no OUTSIDE-REQUEST.
Task 3b: dispatched (BASE a39e875, implementer sonnet)
Task 3b: implementer DONE at 1721a57 (agent afaf30d7a51b9718f); review dispatched (sonnet)
Note: generic reviewer/implementer template text now lives in reviewer-rules.md and implementer-rules.md in this workspace; dispatches point at them.
Task 3b: review (agent a3f880a61acf1948d) — spec ✅, approved, no Critical/Important.
Task 3b: ⚠️ items resolved by controller — commit 1721a57 author Avishka Induwara, Co-Authored-By trailer present; controller re-ran analyze (clean), test (7/7), `flutter build web --no-web-resources-cdn` (OK) and shot.mjs on all five pages: every page "(no console errors, no outside requests)".
Task 3b: minor (deferred): the Roboto alias has no italic entry (fallback path only; italic would be slanted upright Lora).
Task 3b: complete (commits a39e875..1721a57, review clean)
Stage 1 check (controller, at 1721a57): PASSED — analyze clean, test 7/7, web build OK, five pages in Chrome with no outside requests. Not checked: Android, iOS.
Task 4: dispatched (BASE 1721a57, implementer opus)
Task 4: implementer agent a95f86e9450abbf82 (opus)
Task 4: implementer DONE at c498985; review dispatched (opus)
Task 4: reviewer agent aae228d8144f3a2e5 (opus)
Task 4: review (agent aae228d8144f3a2e5) — spec ✅, approved, no Critical/Important. Reviewer traced s18–s19 against booklet line indices, the namo.lk walk (61 blocks), Brisbane and Mahamevnawa English, and ran --check.
Task 4: ⚠️ items resolved by controller — commit c498985 author Avishka Induwara, trailer present, per-word Step 1 findings are in the commit body; report has the Step 1 table (six words, PDF pp. 39–40, all misprints in the booklet itself, rows stay) and the page-38 line comparison; controller re-ran the 14 Python tests (OK) and --check (up to date).
Task 4: minor (deferred): build_content.py checks only the kind (subheading) of booklet p.37 lines 0 and 32, not their text against the §5.1 headings (test_sections catches it after the fact).
Task 4: minor (deferred): no direct test for the whole-word `ම විසින්` rule (a ම ending a longer word must be left alone).
Task 4: minor (deferred, plan-mandated, for the owner at Stage 4): English keeps the PDF's line wraps (`\n` inside sentences, e.g. s01-v1 "the\nFully Enlightened One.", s04–s06 prose, "Once-\nReturner") — on a phone this may show hard breaks mid-sentence. Look at it at the Stage 4 reader screenshots; if ugly, rule a build-script change (join wrapped prose lines) as a follow-up task.
Task 4: minor (deferred): design §5.2 line 123 says English is present "for four of the six verses of section 18"; the brief and the build give section 18 four verses with English on 2 — fix the wording in the design file in the final wave.
Task 4: note — `python -I -X utf8 -m unittest tools/test_build_content.py` fails under -I; working forms: `python -I -X utf8 tools/test_build_content.py` or `-m unittest discover -s tools`.
Task 4: complete (commits 1721a57..c498985, review clean)
Task 5: dispatched (BASE c498985, implementer sonnet)
Task 5: implementer agent a0e396031d7eb62e1 (sonnet)
Task 5: implementer DONE_WITH_CONCERNS at f154e34 — concerns are observations, not blockers: tests written after the code (no RED run); testLibrary() has sections only (Task 5 model has no verse type — Task 6 must add the s01–s03 verses the Task 5 brief describes); two unlisted files added (lib/library/library_gate.dart, lib/library/category_screen.dart); libraryProvider has `retry: (_, _) => null` so a load failure shows the message. Review dispatched (sonnet).
Task 5: review (agent af068e49bcfd83223) — spec ✅, approved, no Critical/Important.
Task 5: ⚠️ items resolved by controller — analyze clean, test 14/14, content --check up to date at f154e34; Chrome look done (below); helpers unchanged since Task 3.
Task 5: minor (deferred): contents → reader uses context.go to a route outside the shell, so the placeholder has no back button — Task 9 must give the reader a working back (push, or a leading back button that goes to Routes.contents). Carry in Task 9 dispatch.
Task 5: minor (resolved, no change): ListRow subtitle uses the Sinhala font — the category subtitle IS Sinhala (seen in Chrome), so it is right.
Task 5: minor (deferred): row number is gold (accent) 16 px on ivory — likely under 4.5:1 contrast; it is in the spoken label; Task 15 accessibility pass.
Task 5: minor (deferred): no test for an unknown category address (CategoryScreen → NotFoundScreen).
Task 5: complete (commits c498985..f154e34, review clean)
Stage 2 check (controller, at f154e34): PASSED — analyze clean, test 14/14, content check up to date, web build OK, 8 pages in Chrome with no console errors and no outside requests; 19 headings render in Noto Sans Sinhala with no boxes; චෛත්‍ය and ආරාධනාව look right at 3x. Not checked: Android, iOS.
Task 6: dispatched (BASE f154e34, implementer sonnet, agent a1a15f55b646b7369)
Task 6: implementer DONE at e64a516; review dispatched (sonnet)
Task 6: review (agent a8a93bc4e5d995724) — spec ✅, approved, no Critical/Important.
Task 6: ⚠️ items resolved by controller — analyze clean and flutter test 24/24 at e64a516 (re-run by controller). Content file uses two check strings ("checked against source" ×39, "needs checking" ×8); `unchecked` is only the fallback.
Task 6: minor (deferred): empty SourceRecord literal written twice in model.dart — add SourceRecord.empty.
Task 6: minor (deferred): a wrongly typed element inside `notes` or `corrections` throws (only missing fields are tolerated); zero-verse section coverOf untested; Correction.count defaults to 1 when missing (not in spec).
Task 6: minor (deferred): formatter restyled some Task 5 code in model.dart and test_content.dart (harmless churn).
Task 6: complete (commits f154e34..e64a516, review clean)
Task 7: dispatched (BASE e64a516, implementer sonnet)
Task 7: implementer agent a19536663383da21d (sonnet)
Task 7: implementer DONE at 90e147b; review dispatched (sonnet)
Task 7: review (agent a84db5f6cb71f4530) — spec ✅, approved, no Critical/Important.
Task 7: ⚠️ items resolved by controller — fontFamilyFallback [NamoFonts.sinhala] is in typography.dart:20; analyze clean, test 42/42, web build OK at 90e147b; snack bar seen in Chrome (palette surface, readable text).
Task 7: controller's Chrome look found a real gap — with one language the layout chooser is greyed but the hint `Needs two languages` is semantics-only, not visible (brief: "disabled, with the hint"). Entered the fix loop; implementer a19536663383da21d resumed.
Task 7: minor (deferred): SettingsController drops the Future from store.write — Task 13's saved store must handle a failed write (carry in Task 13 dispatch).
Task 7: minor (deferred): language rows expose `selected`, not `checked`, to screen readers; focusColor not set on chooser rows (keyboard focus overlay on web) — Task 15 accessibility pass.
Task 7: minor (deferred): the "layout chooser is disabled" test checks hint and no-change-on-tap, not the enabled state.
Task 7: minor (deferred): on wide screens the Settings rows stretch the full width (check mark at the far right edge); the contents list is centred in a column — constrain Settings to the reading column in Task 14 (carry in Task 14 dispatch).
Task 7: fix round 1/5 (1 addressed, 0 open — visible hint `Needs two languages`; commits 90e147b..ee76aa5)
Task 7: minor (deferred): the layout rows shift down one line when the hint appears — Task 15 may reserve the space or leave it
Task 7: complete (commits e64a516..ee76aa5, review clean)
Stage 3 check PASSED at ee76aa5: analyze clean, 43 tests, content file up to date, web build OK, Settings in Chrome phone/wide light/dark with no console errors or outside requests; visible hint seen in one-language-dark.png. Android/iOS not checked (no toolchain).
Task 8: dispatched, BASE ee76aa5, implementer sonnet
Task 8: DONE at e785c5e; review ✅ approved. ⚠️ resolved by controller: author Avishka Induwara with trailer; analyze clean, 51 tests; coverOf thresholds read (0 -> none, all -> all, else part).
Task 8: minor (deferred): one-language test uses Sinhala only; explanation note string duplicated in the test (private constant)
Task 8: complete (commits ee76aa5..e785c5e, review clean)
Task 9: dispatched, BASE e785c5e, implementer opus
Task 9: DONE_WITH_CONCERNS at 845849c (concerns were judgement calls: fixed 60% sheet height, last section padded to a screen, one-line title, jumps not animations, section-fraction place keeping) — treated as observations; review ✅ approved, no Critical/Important.
Task 9: ⚠️ resolved by controller: snack bar message seen above the sheet in Chrome (stage4/sheet-third-language.png); analyze clean, 61 tests, web build OK, reader pages no console errors or outside requests. ⚠️ top-bar overflow at large text scale not checked here — carried to Task 15's overflow cases.
Ruling: when a reading's title equals its category's title (true for the only reading), the reader top bar shows the title once (no repeated subtitle) — the same line twice with the first cut off looks broken on a phone — carried into the Task 10 dispatch; costs a one-line change back if the owner wants both.
Task 9: minor (deferred): top bar two-line title may overflow at 1.5x text scale (Task 15); sheet fixed at 60% height, no test that messages show over the sheet; aHeadingIsOnScreen may count a heading hidden behind the sheet; inert favourite/play tap test cannot fail (wired in Tasks 10/11); _updateButtons queued every build
Task 9: complete (commits e785c5e..845849c, review clean)
Task 10: dispatched, BASE 845849c, implementer opus
Task 10: DONE_WITH_CONCERNS at a448a3c (leave-save runs at end of the dispose frame, not inside dispose — Riverpod forbids provider changes during unmount; heart colours; ?section= saves that place) — judged by the reviewer; review ✅ approved, no Critical/Important.
Task 10: ⚠️ resolved by controller: last section still padded (s19 heading at top in stage4/k-s19-phone-light.png); leave-save accepted; `?section=` saving the place accepted (the person is reading there; fits Task 12 links).
Task 10: minor (deferred): heading-at-top position drops its fraction (brief-literal); one test chains 7 scenarios; bookmark button centred against a wrapped heading rather than its first line (Task 15 look); phone title cut with an ellipsis (carried to Task 11 dispatch: wrap to two lines)
Task 10: complete (commits 845849c..a448a3c, review clean)
Stage 4 check PASSED at a448a3c: analyze clean, 89 tests, content up to date, web build OK; reader in Chrome phone/wide, light/dark, both layouts, English+Pali at s08/s09, English-only s04/s07/s18, bookmark + favourite toggled; no console errors or outside requests. Android/iOS not checked.
Ruling: English from the Mahamevnawa PDF (s01-s06) keeps that PDF's column line wraps, which break mid-sentence on a phone (seen in stage4/g-english-only-s04-phone-light.png). Add Task 10b: the build script reflows those prose passages (whitespace only, no word changed); verse-form English from the Brisbane booklet keeps its lines — whitespace is not text; costs one build-script revert if the owner wants the PDF's lines.
Task 10b: dispatched, BASE a448a3c, implementer sonnet (brief written by controller: task-10b-brief.md)
Task 10b: implementer DONE_WITH_CONCERNS at 5af2220 — brief defect: rule 1 said "everything _mahamevnawa_english returns" but that function also returns the verse passages s18-v4 and s19-v1..v3, which the brief's expected results keep unchanged.
Ruling: only the Mahamevnawa prose (s01-v1..s06-v1, constant MAHAMEVNAWA_PROSE) is reflowed; Mahamevnawa verse (s18-v4, s19-v1..v3) keeps its lines — the brief's purpose and expected results both say so; rule 1's wording was the controller's slip — if wrong, those four verses keep line breaks the owner can ask to change later, no text is lost.
Task 10b: review (sonnet) — spec ✅, quality Approved. ⚠️ resolved by controller at 5af2220: python tests 21 OK, --check up to date, flutter analyze clean, flutter test 89 pass; full s04/s05/s06 strings read — match the brief.
Task 10b: minor (deferred): s02 "unchanged" asserted only by line count (tools/test_build_content.py:348) — final wave.
Task 10b: minor (deferred): baseline() shells out to `git show a448a3c:` so the Python tests need that commit reachable (fail in an exported tree) — final wave: keep a baseline another way or skip cleanly.
Task 10b: minor (deferred): MAHAMEVNAWA_PROSE includes s02-v1, which reflows to itself — harmless.
Task 10b: complete (commits a448a3c..5af2220, review clean)
Web rebuilt at 5af2220 and served; reflowed English seen in Chrome at s06, phone dark (scratchpad stage4b/english-pali-s06-phone-dark.png) — reads as sentences; no console errors, no outside requests.
Task 11: dispatched, BASE 5af2220, implementer opus. Carry-ins: title on a phone wraps to two lines (no ellipsis); Task 10's place-restore and previous/next call syncToPage.
Task 11: implementer DONE at ecf6e1b (109 tests); notes: wheel pauses at once (onPointerSignal), top bar 76 px for two-line title, presets to tune by eye. Reviewer opus dispatched.
Task 11: review (opus) — spec ✅, quality Approved. ⚠️ resolved by controller: ecf6e1b author Avishka Induwara <v.g.a.induwara@gmail.com> with Co-Authored-By trailer; titleLarge comes from the theme's style() helper (typography.dart:22 carries the Sinhala fallback); real title fits two lines at 390 px (stage5/normal-phone-light-3.png).
Task 11: minor (deferred): `Custom` line appears/disappears above the speed slider mid-drag, shifting the slider ~26 px (reader_settings_sheet.dart:182-196) — Task 15: reserve the space or move the label.
Task 11: minor (deferred): while running, every frame's jumpTo runs _onScroll → _updateButtons + _capture + recreates the 400 ms save timer (reader_screen.dart:212-240) — final wave: skip capture/save while running, capture once on stop.
Task 11: minor (deferred): changing reading in place pauses rather than stops, so the button could say Resume for an unstarted reading (reader_screen.dart:133) — final wave.
Task 11: minor (deferred): Start when already at the very end needs a second press — final wave: restart from the top when offset >= maxScrollExtent.
Task 11: minor (deferred): speed limits defined in both AutoScrollEngine and AppSettings.scrollSpeedRange — final wave.
Task 11: minor (deferred): top bar is 76 px for every reading; large text scale could overflow it — Task 15 (already carries the 1.5× top-bar item).
Task 11: complete (commits 5af2220..ecf6e1b, review clean)
Stage 5 check PASSED at ecf6e1b: analyze clean, 109 tests, content up to date, web build OK. Chrome, timed screenshots measured with scratchpad shift.mjs: Slow 24 px / 2 s, Normal 44 px / 2 s (4 intervals, identical), Fast 72 px / 2 s — exactly 12/22/36 px/s and even; touch pauses at once (0 px after), mouse wheel pauses, next-section keeps scrolling, speed change from the sheet applies while running, stops by itself at the end with the Start icon back; title wraps to two lines on a phone; speed control seen phone light + wide dark. No console errors, no outside requests. Not judged: how smooth it looks to the eye and whether the presets suit a chanting pace — owner to watch. Android/iOS not checked.
Task 12: dispatched, BASE ecf6e1b, implementer sonnet. Carry-in: chantPlayerProvider not read when a reading has no recording; brief Step 5 (run in Chrome with the dev flag) is the controller's.
Task 12: implementer DONE_WITH_CONCERNS at 7185bcb (125 tests) — concerns are observations (JustAudioChantPlayer untested by automation; tone WAV 160044 bytes bundled in release but never offered; Step 5 left to controller) → proceed to review (sonnet).
Task 12: review (sonnet) spec ✅ / quality Approved, no Critical/Important.
Task 12: ⚠️ resolved by controller — just_audio in Chrome (brief Step 5): debug web build with NAMO_DEV_AUDIO=true, screenshots stage6/a..f: plays (0:04/0:20, pause icon), pauses (time held at 0:04), resumes (0:07), restarts (back to 0:02 and playing), runs together with auto-scroll (page moved, both pause icons), completes (0:20/0:20, play icon back). Owner also heard the tone from the speakers. Release build: no audio controls. ⚠️ bottom-bar overflow at largest text scale with the placeholder label: not checked — Task 15.
Task 12: minor (deferred): 160 KB placeholder WAV is in the pubspec assets so it ships in release builds though never offered — owner told at Stage 6; final wave: decide whether to keep it out of release packages.
Task 12: minor (deferred): _bindAudio cancels a subscription / calls pause() from inside build — final wave: move to didChangeDependencies or a ref.listen.
Task 12: minor (deferred): failed message and placeholder label have no explicit Semantics and no large-text overflow test — Task 15.
Task 12: minor (deferred): JustAudioChantPlayer._publish maps ready with position > 0 to paused — final wave.
Task 12: minor (deferred, controller's own): on wide screens the audio row spans the full width instead of the reading column — Task 15.
Task 12: complete (commits ecf6e1b..7185bcb, review clean)
Stage 6 check PASSED at 7185bcb: analyze clean, 125 tests, content up to date, release web build OK (served on 8765): reader shows no audio controls, no console errors, no outside requests. Debug build with the flag (was on port 8791, now stopped): labelled tone row seen phone light + wide dark; play/pause/resume/restart/with-scroll/completed all seen. Not checked: Android/iOS; large text scale. Note: scratchpad shot.mjs now starts Chrome with --mute-audio (the test tone was audible to the owner).
Task 13: dispatched, BASE 7185bcb, implementer sonnet. Carry-ins: failed store.write must not crash or go unhandled (Task 7 minor, line 141); in-memory fallback if SharedPreferences fails.
Task 13: implementer DONE at ec15125 (131 tests) — review dispatched (sonnet).
Task 13: review (sonnet) spec ✅ / quality Approved, no Critical/Important.
Task 13: ⚠️ resolved by controller — tolerant loading: SavedState.fromJson (saved.dart:61-70) and PositionState.fromJson (position_controller.dart:30-67) check each entry's type and drop bad ones, jsonDecode failures caught (saved.dart:82, position_controller.dart:80); the damaged-key test (restart_test.dart:111) uses the brief's exact strings. TDD order: report only. Android/iOS: cannot run here.
Task 13: minor (deferred): KeyValueStore.save swallows write errors with no trace (key_value_store.dart ~17) — final wave: debugPrint in debug builds if tests stay quiet.
Task 13: minor (deferred): _FailingStore.remove never exercised; `await Future.delayed(Duration.zero)` before restart depends on mock write timing (restart_test.dart ~100) — final wave.
Task 13: complete (commits 7185bcb..ec15125, review clean)
Web rebuilt at ec15125 and checked in Chrome (stage7/1-before.png, 2-after-reload.png): language choice (Pali+English) and place in section 6 are the same after a fresh page load of /#/read/namaskaraya; no console errors, no outside requests. Owner told.
Task 14: dispatched, BASE ec15125, implementer sonnet. Carry-ins: keep screen-* keys; Settings constrained to the reading column on wide (Task 7 minor, line 144); scroll-speed control shared with the reader sheet, not copied.
Task 14: implementer DONE at e110019 (146 tests); noted: added 'The' before 'paritha.org booklet' in a credit name — review dispatched (sonnet).
Task 14: review (sonnet) spec ✅ / quality Approved, no Critical/Important (verdict line arrived on a second ask).
Task 14: ⚠️ resolved by controller — null-aware `?x` elements: analyze clean, 146 tests pass, release web build OK at e110019; bundled counts (16 corrections, 4 checks): asserted by the passing test on the real file. Web behaviour: checked in Chrome — CONFIRMED GAP: the Sources page makes an outside request to fonts.gstatic.com (Noto Sans Symbols) because the correction rows print the character "→" (sources_screen.dart:245), which none of the bundled fonts has. Breaks "no network request at run time"; offline it would show as an empty box. → fix loop.
Task 14: minor (deferred): wide-screen cap tested only for Settings, not Saved/Sources; no large-text-scale overflow test for Saved/Sources — Task 15.
Task 14: minor (deferred): no ordering test for several favourites; import order in settings_screen.dart — final wave.
Task 14: minor (deferred, controller's own): the auto-scroll-with-recording switch is very faint when off in the light theme (stage7b/settings-phone-light.png) — Task 15.
Task 14: fix round 1/5 (1 addressed, 0 open — Sources arrow character fetched an outside font; commits e110019..c1b5d76). Re-review (haiku): all addressed, no new Critical/Important. Controller confirmed in Chrome with a fresh browser profile: Sources makes no outside request (stage7c).
Task 14: minor (deferred): the "long forms wrap" test uses the bundled corrections, none of which is long; a single unbroken token wider than the row would still overflow (sources_screen.dart:256-268) — Task 15.
Task 14: complete (commits ec15125..c1b5d76, review clean)
Stage 7 check PASSED at c1b5d76: analyze clean, 148 tests, content up to date, release web build OK (served on 8765). Chrome: every setting changed (languages English+Pali, layout section, text 135%, line spacing 1.9, speed Fast, auto-scroll-with-recording on, theme Dark), two sections bookmarked, reading favourited, read into section 4 — after fresh page loads Settings, Saved (2 bookmarks newest first, 1 favourite), Home (Continue reading with section and progress line) and the reader (same place, dark, English+Pali) were all as left (stage7b c..f). Sources seen phone light + wide dark; empty Saved seen. No console errors, no outside requests on any page. Not checked: Android/iOS; large text scale on the new screens (Task 15).
Task 15: dispatched, BASE c1b5d76, implementer sonnet. Carry-ins: task-15-carry-ins.md (17 deferred minors from Tasks 2,3,5,7,9,10,11,12,14). Controller keeps brief steps 6-8 (build, serve, doctor/Android note, Stage Check, closing report).
Task 15: implementer DONE_WITH_CONCERNS at bf2900d (418 tests). Concerns are observations (a11y test uses test font not bundled fonts; gold accent 2.86:1 kept for non-text icons/progress lines; layout hint moved below rows; Sources addresses read as labels to screen readers; Android/iOS not built) — passed to the reviewer to weigh. Reviewer sonnet dispatched on review-c1b5d76..bf2900d.diff.
Task 15: review (sonnet): spec ✅, task quality Approved, no Critical/Important. ⚠️ resolved by controller: analyze clean, 418 tests pass, content up to date, 21 Python tests OK, both Step 5 greps empty (re-run at bf2900d).
Task 15: minor (deferred): Sources address lines are hidden from semantics and read by a plain label (screen-reader users cannot select/copy; no test of the new semantics) — a 48 px min-height on the selectable text would keep both (sources_screen.dart ~214-226) — final wave.
Task 15: minor (deferred): accessibility_test.dart runs without the bundled fonts (contrast guideline false alarms on thin text); add a direct contrast assertion for textQuiet on background/surface in light and dark — final wave.
Task 15: minor (deferred): reader_screen.dart _toolbarHeight and reader_body.dart firstLine hard-code the title/heading font sizes and line heights (can drift from the styles); top bar unchecked above 2.0x text; unrelated formatting churn in reader_screen.dart and audio_controls.dart; controls under the layout chooser still move one line when the hint appears.
Task 15: minor (deferred, for the owner): gold accent #A88B5B is 2.86:1 on ivory — kept for non-text marks (filled bookmark/favourite icons, 2 px progress lines; fill-vs-outline shape also carries the state); just under the 3:1 non-text guideline. Palette is the owner's spec.
Task 15: complete (commits c1b5d76..bf2900d, review clean)
Stage 8 check PASSED at bf2900d: analyze clean, 418 tests, content up to date, release web build OK (build/web 54 MB, served on 8765), flutter doctor: no Android SDK (Android and iOS not built or run). Chrome (muted): 13 pages at 390x844 and 1280x800, light and dark, plus 7 pages with the browser's text size doubled (incl. 320x568 reader) — no overflow, top bar grows with text, switch off-state visible, contents numbers readable, no console errors, no outside requests (stage8, stage8big).
Final review: dispatched on fable over ad52ff9..bf2900d (package review-ad52ff9..bf2900d.diff, report final-review.md).
Owner change (2026-11-10, mid-review): "we need to chnage the namaskraya to pin dima / Bhudda Wandanawa ( in sinhala also )" — rename the reading and its category to Buddha Wandanawa / බුද්ධ වන්දනාව. Dispatched as its own small commit on top of bf2900d (implementer sonnet); it will be covered by the fix wave's scoped re-review (FIX_BASE bf2900d).
Ruling: English title spelled "Buddha Wandanawa" (owner typed "Bhudda Wandanawa" in a hurried message); Sinhala "බුද්ධ වන්දනාව" (both words already appear in the sourced section headings 7–9); internal ids `namaskaraya` / `cat-namaskaraya` and the asset file name stay so links and saved bookmarks keep working — why: standard spelling, no stored data broken — cost if wrong: a one-line title change in tools/build_content.py and a rebuild.
Owner confirmed (2026-11-10, "yes exactly"): title Buddha Wandanawa / බුද්ධ වන්දනාව, shown everywhere the name appears; ids unchanged. The spelling ruling above is now the owner's decision.
Owner change (2026-11-10, with a screenshot of the Library card): "in libraye can we use list view as this and then one by one lidt view when click on this rther than go to new page" — Task 16 added (brief task-16-brief.md, written by the controller; not in the plan file). Queued behind the rename commit.
Ruling: Task 16 reading of the request — the Library card keeps its look and opens the numbered sections underneath in place; the category page and the contents page are removed; Home's category row and the reader's back button land on the Library with the list open; old addresses redirect — why: the owner asked for no new page, and leaving two unreachable screens would be dead code — cost if wrong: restore the two small screens (84 lines) from git and re-point two links.
Rename: DONE at 0cf4091 (418 Dart tests, 22 Python tests, content up to date; JSON diff = title x2 + subtitle only; controller checked). Web rebuilt and served. Review: covered by the later scoped re-review.
Task 16: dispatched, BASE 0cf4091, implementer sonnet (owner change: Library opens sections in place).
Owner change (2026-11-10, with screenshots of namo.lk's picture cards and banner): "in home can we use nice card style ratehr than list view like in the namo website / genarete nice ai images for tose" — Task 17 added (brief task-17-brief.md, written by the controller). Queued behind Task 16 (both touch home_screen.dart).
Ruling: Task 17 — the controller has no image-generation tool and namo.lk's photos must not be copied, so the card is built with a picture slot (cardPictures map, empty) and a drawn lotus panel in the palette that fills it until the owner supplies or approves pictures; card tap opens the reader for a one-reading category — why: gives the owner the card look now without inventing a picture source or breaking the no-network rule — cost if wrong: swap the panel for pictures (one map entry per picture plus the asset) or change the tap target (one line).
Final review: back (final-review.md). Verdict "ready to merge with fixes": no Critical; Important 1 remembered place ignores the language at the top; Important 2 system Back leaves the app from the reader (no PopScope); Important 3 nothing keeps the screen on during auto-scroll/recording. Minors to fix in the wave and a triage of the ledger's deferred items are in the file. Fix wave held until Tasks 16 and 17 are complete (both change what Important 2 and the README edit touch).
Task 16: implementer DONE_WITH_CONCERNS at 70df492 (426 tests). Concerns are observations (address-opened Library shows closed for one frame then animates; address bar shows plain /library once open and browser Back re-opens) — passed to the reviewer, not pre-judged. Review package review-0cf4091..70df492.diff, reviewer sonnet.
Task 16: review at 70df492 — spec ✅ (one soft deviation), quality "needs fixes". Important 1: address-opened Library shows closed for one frame then animates (brief: already open). Important 2: a post-frame callback is added on every build while the request is pending, so several context.replace calls can queue. Cannot-verify resolved by the controller: home_screen.dart:44 and reader_screen.dart:379 call Routes.category / Routes.contents directly (grep); web build at 70df492 succeeded; chevron glyph and browser Back to be seen in Chrome after the fix.
Task 16: minor (deferred): web Back returns to the ?open= entry and re-opens a list the user closed.
Task 16: minor (deferred): no tests for "Home row after the user closed the list reopens it", several categories open at once, and the 200 ms animation itself.
Task 16: minor (deferred): reading heading in a multi-reading category uses NamoFonts.english (library_screen.dart:278); real titles may be Sinhala.
Task 16: minor (deferred): report header says DONE while the hand-back said DONE_WITH_CONCERNS.
Task 16: fix round 1/5 (2 addressed, 0 open — first-frame open on an address request; request handled once; commits 70df492..1a363e1)
Task 16: minor (deferred): the "handled exactly once" test passed before the fix too (weak guard); import order in test/library/library_screen_test.dart:145.
Task 16: complete (commits 0cf4091..1a363e1, review clean)
Task 17: dispatched, BASE 1a363e1, implementer sonnet (owner change: Home cards with a picture panel).
Task 16 check at 1a363e1: content up to date, release web build OK and served on 8765; Chrome (muted, stage10): Library closed, opened by tap, closed again, opened by address (dark), old link at 1280x800, section tap opens the reader at that section, reader back lands on the open Library — no console errors, no outside requests; chevron draws from the bundled icon font.
Owner answer (2026-11-10): "use free to use photos and if you can genarete them generate them", then "or give me some propt to chat gpt to generate the images". The controller cannot generate images; a ChatGPT prompt is given to the owner in chat; a free photo goes in now.
Ruling: Task 18 picture — Wikimedia Commons "File:Samadhi Statue Anuradhapura.jpg" by "Price Zero", CC0 (checked through the Commons API: LicenseShortName CC0, AttributionRequired false, own work; original SHA-1 ed96c328…), cropped by the controller to 1600x900 (scratchpad pictures_out, SHA-1 cb3511bd…), credited on the Sources page anyway, recorded in docs/pictures.md — why: CC0 needs no permission and carries no share-alike duty, the statue is the best-known Sri Lankan meditation image, and its warm stone tones sit with the app's ivory and gold — cost if wrong: one asset file, one map entry and one credit to swap (the owner's own generated picture can replace it the same way).
Task 18 added (brief task-18-brief.md, written by the controller): bundle the picture, register it for the Home card, credit it on Sources. Queued behind Task 17.
Owner (2026-11-10): "Buddha wandana is tha topic other things in side of this is sub topics in futre we use pirith medidation as topics ill give you them" — a topic is a category (one Home card, one Library card), sections are sub-topics; Pirith and Meditation come later with content from the owner. Matches the model as built; one picture per topic.
Task 17: implementer DONE_WITH_CONCERNS at 5cfc630 (449 tests). Concerns: brief's panel gradient vs global-constraints "No gradients"; hover/pressed tint is the heading colour at 8%/10% in an overlay (tests tap the card, not its text); wide Home column 1040 px; dark lotus uses the palette's lighter gold.
Ruling: Task 17 panel gradient stands — the owner spec says "No bright gradients" and the design lists "bright gradients" as the thing to avoid; "No gradients" in global-constraints.md was the controller's own tightening; a soft blend between two neighbouring palette tones is inside the spec, and picture cards are the owner's explicit request (which also overrides "no coloured cards" for Home) — why: spec is the binding authority and the owner asked for the namo.lk card look — cost if wrong: one line to make the panel a flat palette colour.
Task 17: review dispatched (sonnet), range 1a363e1..5cfc630
Task 17: review back — spec ✅, quality Approved, no Critical/Important. Cannot-verify items resolved by the controller: title/subtitle styles equal ListRow's (list_row.dart:70-74: 18 p.text, Sinhala 14 p.textQuiet); card surface equals cardTheme (theme.dart:67-72: p.background, hairline, radius); NamoSizes.wideBreakpoint (840) is the same value app_shell.dart:30 uses for the rail; dark lotus #C9AE7C is the dark palette's accent (tokens.dart:56). Visual check is done at the next build (after Task 18).
Task 17: minor (deferred): hover/pressed tint is a computed alpha of p.heading, not an existing ink token, and hover/press/focus have no test (reading_card.dart:87-89)
Task 17: minor (deferred): look at the focus ring at the card's rounded corners (reading_card.dart:41-47)
Task 17: minor (deferred): on wide screens the Continue reading row stretches to the 1040 column (home_screen.dart:42,45) — look at it in the browser
Task 17: minor (deferred): .clamp on a double returns num (home_screen.dart:73-74), readability only
Task 17: minor (deferred): grid test's `if (c.dy > a.dy)` branch can skip its assertion (home_screen_test.dart ~150) — pin the viewport
Task 17: complete (commits 1a363e1..5cfc630, review clean)
Task 18: dispatched, BASE 5cfc630, implementer sonnet
Task 18: implementer DONE at 48eee81 (454 tests), no concerns; review dispatched (sonnet), range 5cfc630..48eee81
Task 18: review back — spec ✅, quality Approved, no Critical/Important. Cannot-verify resolved by the controller: committed picture SHA-1 is cb3511bd414ec5155b89b0bb9b75927132a2b85c (git show HEAD:… | sha1sum).
Task 18: minor (deferred): run dart format on test/home/reading_card_test.dart (indent of the "no picture" test, long lines)
Task 18: minor (deferred): one-line comment on why frameBuilder checks `sync` (card_art.dart)
Task 18: complete (commits 5cfc630..48eee81, review clean)
Browser check at 48eee81 (web build, Chrome, 390x844 and 1280x800, light and dark): Home card with the photograph, tap opens the reader, Continue reading row above the card, Sources shows Pictures credit before Corrections; every page: no console errors, no outside requests. Owner told.
Ruling: reader Back target — top-bar arrow and system Back both return to where the person came from (Home card or Continue row → Home; Library row → Library with the list open; Saved → Saved; opened by address → Library open) — why: Home cards now open the reader directly, so landing in the Library after Back would feel like being moved; the final review's Important 2 offered this as the better option — cost if wrong: a small routing change in the reader.
Ruling: keep-screen-on — add the wakelock_plus package behind a small interface with a no-op for tests, held only while auto-scroll runs or a recording plays — why: a 3-minute untouched auto-scroll that lets the phone sleep defeats the feature (final review Important 3); the package bundles its web helper, so no outside request is expected (checked in Chrome after the wave) — cost if wrong: one dependency to remove; native behaviour is unverified until the first Android/iOS build.
Ruling: no second whole-branch review for the commits after bf2900d (rename, Tasks 16–18) — why: each was task-reviewed clean and browser-checked, the rename was confirmed by the owner, and the fix wave's re-review covers the code where they meet the earlier work (reader Back, Home, Library) — cost if wrong: a cross-task problem in the Home/Library changes is found by the owner in use instead of by a reviewer.
Final fix wave: dispatched, FIX_BASE 48eee81, implementer opus, brief final-fix-brief.md (18 items: Important 1–3, review minors, Task 16–18 deferred minors)
Owner (2026-11-10): "here are several images" — five AI-generated pictures pasted in chat: pirith scene (1600x900), bodhi tree with stone seat (1600x900), stupa at dusk with lamps (1280x720), wide Buddha statue banner (1280x427), Buddha statue (1600x900). Controller prepared clean JPEGs in the scratchpad (owner_pictures/out). Two of them (pirith, Buddha statue) carry a faint tool mark in the top right corner — left as supplied; owner told.
Ruling: the Buddha statue picture (1600x900) goes on the Buddha Wandanawa card and replaces the Wikimedia photo (asset and credit removed; credit becomes "made for this app with an AI image tool"); pirith and bodhi-tree pictures are kept for the Pirith and Meditation topics, stupa picture spare; the wide banner is NOT put on Home yet — why: the owner generated them from the prompts given for exactly these slots; the banner shows the same statue as the card and would sit directly above it — cost if wrong: one registry line to point the card at a different picture; a banner is a small Home task if the owner wants it.
Task 19 added (brief task-19-brief.md): queued behind the final fix wave and its re-review.
Owner (2026-11-10): pasted "Namo – Complete Premium UI/UX Transformation" — a full redesign brief (dark-first palette #151714/#1C1F1B/#232720/#34382F, text #EAE6DC/#A9A698/#77776D, sage #A8B99F, gold #C6A879; serif titles + sans labels; floating bottom navigation; Home with featured picture, Continue Reading, Daily Gatha, collections; Library with search; reader with two-language selector; Saved; grouped Settings; gentle motion; keep every existing function; 8 phases). This is a NEW project, not part of this plan: it gets its own design doc and plan (brainstorming → writing-plans → subagent-driven) after this plan's fix wave, re-review and Task 19 are done. Its text is in the session transcript; save it to docs/superpowers/specs/2026-11-10-owner-redesign-brief.md once no implementer is working in the tree. It supersedes, for the redesign, the first spec's ivory palette and this plan's "elevation 0 / radius at most 8 / no gradients" lines.
Owner (2026-11-10): ran-by-request `npx skills add nextlevelbuilder/ui-ux-pro-max-skill --skill ui-ux-pro-max --agent claude-code` — installed at .claude/skills/ui-ux-pro-max (read first: offline Python search over design tables, no network); kept out of git through .git/info/exclude (.claude/, .agents/, skills-lock.json). For the redesign project, not this plan.
Final fix wave: implementer DONE_WITH_CONCERNS at a9ab89e (15 commits 48eee81..a9ab89e, 488 tests, Python 23, content up to date). All 18 items reported fixed. Concerns are observations: web build not run (controller checks outside requests / wakelock no_sleep.js / rounded icons / browser Back with from=); wakelock_plus pulls package_info_plus, win32, dbus (check merged Android manifest at first Android build); when the saved language is no longer shown the reader goes to the first text of that verse at the same fraction (implementer's call, matches brief A1); dart format re-wrapped other lines in touched files. Back mechanism chosen: `from=home|saved` on the reader address + PopScope calling _back().
Final fix wave: scoped re-review dispatched (opus), range 48eee81..a9ab89e
Final fix wave: re-review back (opus) — all 18 items ADDRESSED, no new Critical/Important breakage, no out-of-scope observations. Controller check at a9ab89e: analyze "No issues found!", 488 tests pass, Python 23 OK, content up to date, release web build OK.
Final fix wave: minor (deferred): after going to the background, a late `playing` event from the player can hold the screen again until the pause lands (reader_screen.dart _toBackground/_onAudio) — ignore _updateAwake while not resumed
Final fix wave: minor (deferred): the Library "200 ms" test accepts anything from just over 100 ms to 200 ms (library_screen_test.dart)
Final fix wave: minor (deferred): wakelock_plus brings http, http_parser, package_info_plus, dbus, win32, ffi_leak_tracker as transitive packages; nothing in lib/ imports them — check the merged Android manifest at the first Android build
Final fix wave: complete (commits 48eee81..a9ab89e, re-review clean, 3 minors deferred)
Task 19: dispatched, BASE a9ab89e, implementer sonnet
Browser check at a9ab89e (release web build served on 8765; muted Chrome, stage12): reader opened from the Home card shows thin rounded icons; top-bar Back from there lands on Home; reader opened from a Library row → Back lands on the Library with the list open; auto-scroll running in dark (pause shown); Saved light, Settings dark, reader at 1280x800 dark — every page: no console errors, no outside requests (wakelock_plus's no_sleep.js is in build/web/assets/packages/wakelock_plus and nothing was fetched from outside).
Task 19: implementer DONE at eaec4a4 (489 tests), no concerns; review dispatched (sonnet), range a9ab89e..eaec4a4
Task 19: review back — spec ✅, quality Approved, no Critical/Important. Cannot-verify resolved by the controller: committed SHA-1s equal the brief's table for all six files (git show HEAD:… | sha1sum); `_Credit` address is an optional positional and the address block is skipped when null (sources_screen.dart:13,223); analyze "No issues found!", 489 tests pass, content up to date at eaec4a4.
Task 19: minor (deferred): Sources test bounds the gap to Corrections with a bare 40 (sources_screen_test.dart); card semantics regex is generic (reading_card_test.dart); design/card_images/buddha_wandanawa.jpg duplicates the bundled file (brief-mandated)
Task 19: complete (commits a9ab89e..eaec4a4, review clean)
Browser check at eaec4a4 (release web build on 8765; stage13): Home card shows the owner's Buddha picture at 390x844 light/dark and 1280x800; Sources shows "Home card picture" under Pictures with no address and no gap — no console errors, no outside requests.
