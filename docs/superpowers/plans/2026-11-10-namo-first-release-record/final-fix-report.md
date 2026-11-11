# Final fix wave — report

Status: **DONE_WITH_CONCERNS** (all 18 items fixed; concerns at the end are about things only the web build / a phone can show).

Range: `48eee81..a9ab89e` on `first-release` (15 commits, local only, nothing pushed). Only the web build can be run on this machine; Android and iOS were not built.

## Items

| # | Item | Result | Commit | Covering test |
|---|------|--------|--------|---------------|
| 1 | Remembered place keeps the language | fixed | `a8faf2b` | `test/reader/reading_position_test.dart`, `test/reader/reader_position_test.dart` |
| 2 | System Back from the reader | fixed | `acc5763` | `test/reader/reader_back_test.dart` (10 tests) |
| 3 | Keep the screen on (`wakelock_plus`) | fixed | `7398a76` | `test/reader/reader_awake_test.dart` (6 tests) |
| 4 | Save throttle while moving | fixed | `64725b3` | `test/reader/reader_auto_scroll_test.dart` "while the page keeps moving…" |
| 5 | Start at the very end | fixed | `2877491` | `test/reader/auto_scroll_test.dart` "play with the page already at the very end…" |
| 6 | Thin-line icons | fixed | `48171e5` | `test/design/icons_test.dart` (3 tests); updated `reader_position_test.dart`, `saved_screen_test.dart` |
| 7 | `web/manifest.json` orientation | fixed | `5be5010` | `test/quality/web_manifest_test.dart` |
| 8 | Python baseline as a file | fixed | `41a6983` | `tools/test_build_content.py` (run without git on PATH) |
| 9 | README | fixed | `e49a4c9` | (text) |
| 10 | Design §5.2 wording | fixed | `fa80792` | (text) |
| 11 | Theme test, 15 roles | fixed | `4419e66` | `test/design/theme_test.dart` |
| 12 | Python test, whole-word `ම විසින්` | fixed | `41a6983` | `test_whole_word_correction` |
| 13 | Home wide grid test | fixed | `d96cffb` | `test/home/home_screen_test.dart` "at 1280x800 the cards wrap…" |
| 14 | `card_art.dart` `sync` comment | fixed | `1180e25` | (comment) |
| 15 | `dart format` | done | in each commit | `dart format --output=none --set-exit-if-changed` on all 30 touched Dart files: 0 changed |
| 16 | Library reading heading family | fixed | `a29d6e6` | `library_screen_test.dart` "a reading heading uses the same family…" |
| 17 | Missing Library tests | fixed | `a29d6e6` | `library_screen_test.dart` (3 new tests, 1 extended) |
| 18 | Home card focus / hover / press | fixed | `a9ab89e` | `reading_card_test.dart` "focused by keyboard…" |

## Detail and TDD evidence

### 1 — remembered place and language (`a8faf2b`)
`ReadingPosition` gains an optional `language` (`ReadingLanguage?`), stored as `"language": "si"` only when set; `fromJson` ignores a missing, non-string or unknown code, so data under `namo.position.v1` saved before still loads (tested). `capturePosition` records the language of a `VerseTextItem` at the top. `offsetForPosition` now prefers the same verse **and** language, then the first item of the verse (same fraction), then the section heading — keeping the fraction only when the heading itself was at the top (closes the Task 10 deferred item); else 0.
- RED (field added, logic not yet): `flutter test test/reader/reading_position_test.dart` → 4 failures: "captures which language is at the top" `Expected: ReadingLanguage.sinhala Actual: <null>`; both "second-language item … verse layout / section layout" same; "a heading at the top keeps its fraction" `Expected: <60> Actual: <0.0>`.
- RED (widget, old lib stashed): `flutter test test/reader/reader_position_test.dart` → "the second language at the top stays at the top through text size and layout changes" `verse-s02-v1-si should be at the top, Actual: <58.0>`; "leaving and reopening…" `verse-s01-v2-si should be at the top, Actual: <41.0>`. (The latter test previously asserted the old, wrong `-pi` landing; it now expects `-si`.)
- GREEN: `flutter test test/reader/` → `+68: All tests passed!`
- Tests added: language capture; `-si` at top in verse layout (text grows) and in section layout (and switching layout); stored language no longer chosen → first item of the verse; heading keeps its fraction; JSON round trip with language; old data without language loads; bad language values dropped.

### 2 — system Back (`acc5763`)
Mechanism chosen: **a `from` value in the reader's address** plus a `PopScope` on the reader. `Routes.reader(id, {sectionId, from})` adds `from=home` or `from=saved`; `enum ReaderFrom { home, saved }` lives in `router.dart`. Home cards (one-reading category) and the Home `Continue reading` row pass `ReaderFrom.home`; Saved's bookmark and favourite rows pass `ReaderFrom.saved`; Library section rows and addresses pass nothing. `_back()` still pops if it can, otherwise `go`es to Home / Saved / `Routes.contents(readingId)` (Library with the reading's list open). The reader's `Scaffold` is wrapped in `PopScope(canPop: false, onPopInvokedWithResult: (didPop, _) { if (!didPop) _back(); })`, so the arrow and the system Back do the same thing.
Why: every link keeps using `context.go`, so the browser address always names the page (a reload or a shared link keeps working, and go_router's `push` does not update the web URL by default); no platform check; one code path for Android, iOS and web; no change to the shell's branch set-up. An unknown `from` value is ignored (Library).
- RED: `flutter test test/reader/reader_back_test.dart` → 8 of 10 failed: all five system-Back cases left the reader on screen (`Found 1 widget with type "ReaderBody"`), and the arrow from Home card / Continue reading / Saved went to the Library (`Found 0 widgets with key [<'screen-home'>]` / `screen-saved`). The arrow from a Library row and by address already passed.
- GREEN: `+10: All tests passed!`
- The test sends the system Back with `tester.binding.handlePopRoute()`; each of the four cases (Home card, Home Continue reading, Library row, Saved bookmark + Saved favourite, by address) is run for both the system Back and the arrow.

### 3 — keep the screen on (`7398a76`)
`flutter pub add wakelock_plus` → `wakelock_plus: ^1.8.2` (plus its dependencies in `pubspec.lock`: `wakelock_plus_platform_interface`, `package_info_plus`, `package_info_plus_platform_interface`, `win32`, `dbus` etc.). `flutter pub get` changed no tracked file other than `pubspec.yaml` / `pubspec.lock` (the plugin registrants are git-ignored).
`lib/reader/screen_awake.dart`: `abstract interface class ScreenAwake { hold(); release(); }`, `WakelockScreenAwake` (calls `WakelockPlus.enable/disable`, every error swallowed), `screenAwakeProvider`. The reader reads it in `initState` and holds the screen while `autoScroll == running || audio == playing` (`_updateAwake` on every auto-scroll status change and every audio state); it releases when both stop, in `_toBackground` (at once, without waiting for the player's pause event) and in `dispose`. Calls are de-duplicated (`_holdingAwake`).
Tests: `test/support/fake_screen_awake.dart` records calls; `pumpApp` now always overrides `screenAwakeProvider` with a fresh fake (new optional `screenAwake:` parameter), so no test touches the plugin.
- RED: `flutter test test/reader/reader_awake_test.dart` → 5 failures (`Expected: ['hold'] Actual: []`, etc.); the plugin-failure test passed.
- GREEN: `+6: All tests passed!` — held on Start; released on pause by button and by a touch on the text; released on reaching the end; released on leaving the reader; released on going to the background (and not re-held on resume); held while the recording plays (also across scroll start/stop), released when it is paused and when it plays to the end; `WakelockScreenAwake().hold()/release()` complete without throwing when the platform does not answer.
- No-network check (from the package source, not a build): the web part loads `packages/wakelock_plus/assets/no_sleep.js` through `ui_web.assetManager.getAssetUrl`, i.e. from the app's own files; the script contains only `data:` URIs, no outside address. `package_info_plus` is used only by the package's Linux part; nothing in the app calls it (its web part fetches `version.json` only when `PackageInfo.fromPlatform()` is called). **The controller should confirm in the web build that no outside request is made and that `no_sleep.js` is served from the app.**

### 4 — save throttle (`64725b3`)
Kept the 400 ms "still" timer (restarted by every scroll); added `_movingSaveTimer`, started by the first scroll after a save and not restarted, firing `_save` after 2.5 s. `_save`, `_saveLater` and Back to the beginning cancel both (`_cancelSaveTimers`). Saving is never skipped while auto-scroll runs. (`extents()` per frame was left as is; not in the brief.)
- RED: new test with a counting store, 390×400 window → `Expected: <1> Actual: <0>` at line 284 (no save after 3 s of auto-scroll).
- GREEN: `flutter test test/reader/` → `+85: All tests passed!` — 0 writes after 1 s, 1 after 3 s (progress > 0), 2 after 6 s (progress grew), 3 after pausing (one save once still).

### 5 — Start at the very end (`2877491`)
`AutoScrollEngine.play()` jumps to 0 when finished **or** when the page already sits at `maxScrollExtent` (and the page can scroll).
- RED: `flutter test test/reader/auto_scroll_test.dart` → `Expected: <0> Actual: <4400.0>`.
- GREEN: `+10`-file run, full suite `+479: All tests passed!` Tested from stopped and from paused.

### 6 — thin-line icons (`48171e5`)
Reader top bar (`arrow_back_rounded`, `favorite_rounded`, `tune_rounded`), bookmark (`bookmark_rounded`), bottom bar (`skip_previous_rounded`, `play_arrow_rounded`/`pause_rounded`, `skip_next_rounded`), audio (`play_circle_rounded`/`pause_circle_rounded`, `replay_rounded`), sheet (`vertical_align_top_rounded`), Saved (`close_rounded`), Settings (`check_rounded`): all `Symbols.*_rounded`, `weight: 300`. Bookmark and favourite show state by `fill: 1` (on) / `fill: 0` (off); colours unchanged. Tooltips, labels, keys, sizes and constraints unchanged. Not changed (outside the listed screens): Sources' automatic AppBar back arrow, and the Home card's `Symbols.spa` lotus (weight 200, existing design).
- RED: `flutter test test/design/icons_test.dart` → 3 failures (`Expected: 'MaterialSymbolsRounded' Actual: 'MaterialIcons'`; `Expected: IconData(U+0E8E7) Actual: IconData(U+0E0F1)`).
- GREEN: full suite `+482: All tests passed!`

### 7 — manifest orientation (`5be5010`)
Removed `"orientation": "portrait-primary"`.
- RED: `flutter test test/quality/web_manifest_test.dart` → `Some tests failed.` GREEN: `+1: All tests passed!`

### 8 — Python baseline file (`41a6983`)
`tools/test_data/content_before_reflow_a448a3c.json` written by `git show a448a3c:assets/content/namaskaraya_to_pin_dima.json > …` (never typed). Byte check: `cmp` → identical; the committed blob id equals the one at `a448a3c` (`0f7459679c0aa02cd1fa7ccf12df0ddf3d25e627` for both). `.gitattributes` gets `tools/test_data/*.json text eol=lf` like the other content JSON. `baseline()` reads the file; `subprocess` import removed.
- RED: tests run with git removed from PATH, from a scratch folder → `FAILED (errors=3)` (`FileNotFoundError: [WinError 2]`).
- GREEN: same run without git → `Ran 23 tests … OK`.

### 9 — README (`e49a4c9`)
Rewritten short: Buddha Wandanawa; Home picture cards; Library opening sections in place; the reader keeping the screen on; the four sources exactly as the Sources page names them plus the picture credit; the namo.lk disclaimer; `docs/superpowers/specs`, `docs/superpowers/plans`, `docs/pictures.md`; the existing commands and build flag.

### 10 — design §5.2 (`fa80792`)
"for four of the six verses of section 18" → "for two of the four verses of section 18" (matches NO_ENGLISH: s18-v2, s18-v3).

### 11 — theme test (`4419e66`)
Loops over all 15 `TextTheme` roles in both brightnesses: family Lora, fallback NotoSansSinhala, size ≤ 22. Not a behaviour change; passed on first run (`+4: All tests passed!`).

### 12 — whole-word test (`41a6983`)
`test_whole_word_correction` runs `_correct` on a synthetic verse: the printed form standing alone (twice) is corrected; the same form preceded by a Sinhala letter (`chr(0x0D9A)`, built from its code point, not typed text) is left alone; totals and the correction record are checked. Not a behaviour change; shown to guard it by a scratch mutation (`WHOLE_WORD = set()`) → `FAILED (failures=1)` (the longer word was changed).

### 13 — wide grid test (`d96cffb`)
The `if` is gone. At the pinned 1280×800 three cards fit a row: the test asserts the third is on the first row, the fourth starts the second row at the left edge, and the row gap is 16.

### 14 — `sync` comment (`1180e25`)
Comment above `frameBuilder`: `sync` is true when the picture was already decoded (image cache), so it is shown at once with no one-frame gradient flash.

### 15 — formatting
`dart format` run on every Dart file touched in this wave, including `test/home/reading_card_test.dart` and `test/library/library_screen_test.dart`; the latter's `app.dart` import moved into order by hand. Some touched files had older formatting, so their diffs include formatter re-wrapping (`router.dart`, `settings_screen.dart`, `reading_card.dart`, `home_screen.dart`, `card_art.dart`, the two test files). No other files were reformatted.

### 16 — reading heading family (`a29d6e6`)
The heading above each reading in a multi-reading category uses `NamoFonts.sinhala`, the family the section rows beneath it use (Noto Sans Sinhala covers all printable ASCII — checked with fontTools — so a Latin title draws without any fallback font).
- RED: `Expected: 'NotoSansSinhala' Actual: 'Lora'`. GREEN: library tests `+25: All tests passed!`

### 17 — Library tests (`a29d6e6`)
New: "the Home card opens the list again after the person closed it"; "several categories can be open at once" (and closing one leaves the other); "the list opens and closes over 200 ms" (clip height at 100 ms is between 0 and full, full at 200 ms; closing likewise, gone at 200 ms). Extended "with animations disabled the list opens at once" to close at once too, with no frame scheduled. Behaviour unchanged, so these passed once correct; a scratch mutation (200 → 400 ms) made the 200 ms test fail (`Expected: <75.0> Actual: <150.0>`), then reverted.

### 18 — Home card focus / hover / press (`a9ab89e`)
Tabs until the primary focus is inside the `ReadingCard`, then expects the overlay Material to paint a rect in `NamoPalette.light.focus`; a mouse hover and a press-and-release raise no exception (the release opens the reader). Scratch mutation (`focusColor: p.surface`) → the test fails; reverted (`git checkout`).

## Final checks (at `a9ab89e`)

- `flutter analyze` → `No issues found! (ran in 4.2s)`
- `flutter test` → `02:04 +488: All tests passed!` (was 461 at `48eee81`)
- `python -I -X utf8 tools/test_build_content.py` → `Ran 23 tests … OK`
- `python -I -X utf8 tools/build_content.py . --check` → `content file is up to date`
- `grep -rnE "Platform\.is|kIsWeb|dart:io|package:http|url_launcher" lib/` → no matches
- `grep -rn "Timer" lib/reader/auto_scroll.dart` → no matches
- No content JSON, `content/extracted/` or content build output changed; no religious text typed. `screen-*` keys and every semantics label/tooltip unchanged.

## Files changed

lib: `reader/reading_position.dart`, `reader/reader_screen.dart`, `reader/screen_awake.dart` (new), `reader/auto_scroll.dart`, `reader/reader_body.dart`, `reader/reader_bottom_bar.dart`, `reader/reader_settings_sheet.dart`, `audio/audio_controls.dart`, `router.dart`, `home/home_screen.dart`, `home/reading_card.dart`, `home/card_art.dart`, `saved/saved_screen.dart`, `settings/settings_screen.dart`, `library/library_screen.dart`.
test: `reader/reading_position_test.dart`, `reader/reader_position_test.dart`, `reader/reader_back_test.dart` (new), `reader/reader_awake_test.dart` (new), `reader/reader_auto_scroll_test.dart`, `reader/auto_scroll_test.dart`, `design/icons_test.dart` (new), `design/theme_test.dart`, `quality/web_manifest_test.dart` (new), `saved/saved_screen_test.dart`, `library/library_screen_test.dart`, `home/home_screen_test.dart`, `home/reading_card_test.dart`, `support/pump_app.dart`, `support/fake_screen_awake.dart` (new).
other: `pubspec.yaml`, `pubspec.lock`, `web/manifest.json`, `tools/test_build_content.py`, `tools/test_data/content_before_reflow_a448a3c.json` (new), `.gitattributes`, `README.md`, `docs/superpowers/specs/2026-11-10-gatha-app-first-release-design.md`.

## Concerns

1. **Web build not run** (by instruction). The controller should check in the release web build: no outside request (in particular that `wakelock_plus` loads `assets/packages/wakelock_plus/assets/no_sleep.js` from the app), the new rounded icons draw from the bundled Material Symbols Rounded font (variable `fill`/`weight` axes render as expected on the web), and the browser Back still behaves (the reader address may now carry `from=home|saved`).
2. `wakelock_plus` brings `package_info_plus` (and `win32`, `dbus`) as transitive dependencies; nothing calls them, but they add to the package set. On Android the plugin uses the window's keep-screen-on flag (no new permission expected) — check the merged manifest at the first Android build.
3. In `_toBackground` the screen is released at once while the recording's paused state arrives later from the player; if a player ever failed to pause, the screen would stay released while it plays (the app is hidden then, so harmless).
4. Fallback for a stored language no longer shown keeps the stored fraction on the verse's first text (proportional place), rather than its top — a judgement call; tested either way it is explicit.
5. Formatter re-wrapping in a few files touched for small changes makes those diffs larger than the change itself (item 15 asked for it).
