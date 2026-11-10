# Final whole-branch review — Namo first release

Range reviewed: `ad52ff9..bf2900d` on `first-release` (20 commits, Tasks 1–15 plus 3b and 10b).
Reviewer: one reviewer, no subagents. The diff was too large for one pass, so it was reviewed in passes: (1) spec, plan and ledger; (2) content pipeline and content file; (3) design, router, shell, list screens; (4) reader, position, auto-scroll, audio; (5) storage, Saved, Settings, Sources; (6) `android/`, `ios/`, `web/`, `pubspec.yaml`; (7) cross-task seams and the owner's standing rules.

Two things to know before reading:

- **HEAD moved during the review.** The branch is now past `bf2900d` (rename commit `0cf4091`, Task 16 in progress in the working tree, Task 17 queued). This review covers `bf2900d` only, read from an exported copy (`git archive bf2900d`) so the checkout was never touched. All `file:line` references are to `bf2900d`. Where a fix overlaps Task 16 (navigation) it is marked.
- Paths are relative to `C:\Users\Dell\develop\buddhist_gatha`. Nothing was built or run; the controller's checks at `bf2900d` (analyze, 418 tests, content check, 21 Python tests, web build seen in Chrome) were taken as given.

### Strengths

- **The owner's rules hold in the code, not only in the tests.** `lib/` has no platform check (`kIsWeb`, `Platform.`, `dart:io`), no network or link-opening package, and no donation, payment or advert text. The Android main manifest asks for no internet permission. Source addresses are shown as text and never opened.
- **No network on the web, checked character by character.** I compared every character in the content file (headings, Pali, Sinhala, English, notes, corrections, titles) and every non-ASCII character in the app's own wording against the bundled fonts: all are covered by Lora or Noto Sans Sinhala. The built licence page text (1,630 notices) uses only 10 non-ASCII characters, all in Lora, so the licence page will not fetch a font either. The `Roboto` → Lora alias and the `--no-web-resources-cdn` build flag (Task 3b) close the engine's own downloads. The Task 14 arrow fix (icon font instead of "→") is still in place.
- **The app does not pass itself off as namo.lk.** The Sources page says in plain words "Namo is free. It has no ads and nothing to buy." and "Namo is not made by, or connected with, namo.lk."; every source is credited; corrections and the four "needs checking" verses are listed openly.
- **No religious text is invented.** The content file is produced only by `tools/build_content.py` from `content/extracted/*.json`; each correction is recorded with original, replacement and reason; missing languages stay empty and are announced by a quiet note rather than filled in; the Task 10b reflow is guarded by a test that only whitespace changed.
- **Storage is tolerant.** Settings, saved items and position all load defensively (bad JSON, wrong types, unknown ids), writes never throw into the UI, and there is an in-memory fallback if storage is unavailable.
- **Clean seams.** Audio sits behind `AudioCatalogue` / `ChantPlayer`; the reader's position logic is pure functions over items and extents; the auto-scroll engine is separate from the screen; settings controls are shared between Settings and the reader sheet rather than copied.
- **Accessibility work is real.** Labels and 48-px targets on controls, `checked` semantics on choosers, a live region for the audio failure message, top bar that grows with text size, 216 overflow cases.
- **iOS project setting from Task 2 is still correct** (`ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES` at `ios/Runner.xcodeproj/project.pbxproj:324, 445, 503`). I found nothing in `android/` or `ios/` that would obviously stop a first build.

### Issues

#### Critical (Must Fix)

None.

#### Important (Should Fix)

**1. The remembered place ignores which language's text was at the top of the screen**
`C:\Users\Dell\develop\buddhist_gatha\lib\reader\reading_position.dart:47–67` (capture) and `:71–94` (restore)

- What is wrong: capture stores the verse id and "how far into the item" of whatever item is at the top, but not its language. Restore always picks the *first* item with that verse id (`items.indexWhere(... i.verseId == position.verseId)`) and applies the stored fraction to *that* item's height.
- Why it matters: with the default two languages, about half the time the item at the top is the second-language text. Then reopening the reader, and every text-size, line-spacing, layout or width change (all go through `_keepPlace`), moves the page back to the first-language text of that verse. In sections 4–6 that is far from where the person was (s04-v1: Pali 124 characters, Sinhala 1,106, English 1,040), and in section layout it jumps back a whole language block. The design promises the place "stays correct after a font-size, spacing, language or screen-size change" (design line 266). A person dragging the text-size slider while reading the Sinhala meaning watches the page jump away.
- This is the plan's own instruction (plan line 533: "the first `VerseTextItem` with that `verseId`"), so the implementer followed the brief; the plan was wrong. No test puts a second-language item at the top (every case in `test/reader/reading_position_test.dart` and `reader_position_test.dart` uses a `…-pi` item).
- How to fix: add an optional language code to `ReadingPosition` (absent in old saved data → current behaviour, so `namo.position.v1` stays readable). On restore prefer the item with the same verse *and* language; fall back to the first item of the verse (language no longer shown), then the heading. While there, keep the fraction when a heading is the top item (ledger, Task 10) instead of dropping it. Add tests with a `…-si` item at the top in both layouts, and one where the stored language is no longer chosen.

**2. The system Back button leaves the app from the reader (Android), and Back from the reader ignores where the person came from**
`C:\Users\Dell\develop\buddhist_gatha\lib\router.dart:74–78`, `C:\Users\Dell\develop\buddhist_gatha\lib\reader\reader_screen.dart:375–381`, callers at `lib/home/home_screen.dart:86, 88`, `lib/saved/saved_screen.dart:54, 66`, `lib/library/reading_contents_screen.dart:34–35`

- What is wrong: the reader is a top-level route and every link to it uses `context.go`, so the reader is the only page on the stack. `_back()` handles only the top-bar arrow (`canPop` is always false, so it always goes to the contents list). There is no `PopScope`. On Android the system Back button or gesture therefore finds nothing to pop and closes the app. iOS has no edge-swipe back for the same reason (the arrow still works). On the web the browser's Back works.
- Why it matters: Back is the most used control on Android. A person reading who presses it expects the list, not the home screen of the phone. The design says "the back button works as expected" (line 244). Second, smaller effect: someone who opens a bookmark from Saved, or Continue reading from Home, and presses the arrow lands in the Library tab, not where they were.
- Not verifiable here (Android was never built); this is from reading go_router's behaviour, so it should be the first thing tried on a real phone.
- How to fix (platform-neutral, no platform check): wrap the reader's `Scaffold` in `PopScope(canPop: false, onPopInvokedWithResult: (didPop, _) { if (!didPop) _back(); })`. Add a widget test that sends a system pop (`tester.binding.handlePopRoute()`) and expects the list, not an exit. **Coordinate with Task 16**, which changes where Back lands; the `PopScope` should call whatever `_back()` becomes. Returning to the originating tab (Saved, Home) can be done by passing a `from` query value or by opening the reader with `push`; say which was chosen.

**3. Nothing keeps the screen on during auto-scroll or a recording**
`C:\Users\Dell\develop\buddhist_gatha\pubspec.yaml:30–40` (no wake-lock package), `C:\Users\Dell\develop\buddhist_gatha\lib\reader\reader_screen.dart:159–164` (`_toBackground` pauses both)

- What is wrong: auto-scroll exists so a person can chant without touching the phone. Without touches the phone dims and locks at its screen timeout (commonly 30 seconds to 2 minutes); the app is then hidden and `_toBackground` pauses the scroll and the audio.
- Why it matters: on a phone, the headline hands-free feature stops by itself after about half a minute. It does not show in a desktop Chrome check, which is why eight stage checks did not see it.
- This is a gap in the plan and spec (neither mentions it), not an implementer miss.
- How to fix: hold a wake lock only while auto-scroll is running or a recording is playing; release on pause, stop, finish, leaving the reader and going to the background. `wakelock_plus` covers Android, iOS and web with one call and no platform check. Put it behind a small interface with a no-op for tests, as was done for the audio player. Check after the web build that it makes no outside request (its web part should load from the app's own files). If the owner would rather not add a package in this wave, say so plainly to the owner and make it the first follow-up before anything goes on a phone.

#### Minor (Nice to Have)

Fix in the wave:

- **Place is not saved while the page keeps moving.** `lib/reader/reader_screen.dart:281–294`: every scroll frame cancels and restarts the 400 ms save timer, so during an auto-scroll session nothing is saved until it stops, the app is hidden or the reader is left. If the app is killed mid-session it reopens where Play was pressed. Fix: throttle (save at most every 2–3 seconds while moving, plus the existing save on stop/hide/leave); compute `extents()` once per frame. Note the ledger's proposed fix ("skip capture/save while running") would make this worse.
- **Start at the very end needs two presses.** `lib/reader/auto_scroll.dart:61, 96–100`: pressing Start when already at the bottom finishes at once with nothing visible; only the second press goes back to the top. Fix: when stopped at `maxScrollExtent`, treat Start like the finished case.
- **Reader icons are bold, filled Material icons; the tabs are thin-line.** Owner spec line 49 and design line 286 ask for thin-line icons. Tabs use `Symbols.*_rounded` at weight 300 (`lib/design/widgets/app_shell.dart:14–17`), but the reader, bottom bar, audio row, Saved and Settings use `Icons.*` (`reader_screen.dart:434, 471, 481`; `reader_bottom_bar.dart:82, 95–96, 103`; `reader_body.dart:225`; `audio_controls.dart:87, 96`; `reader_settings_sheet.dart:74`; `saved_screen.dart:167`; `settings_screen.dart:139`). Fix: use the same Symbols family and weight; keep filled versus outline (`fill: 1`) for bookmark and favourite state.
- **Installed web app is locked to portrait.** `web/manifest.json:9` `"orientation": "portrait-primary"` although the app has a wide layout. Remove the line or use `"any"`.
- **Python tests need commit `a448a3c` to exist.** `tools/test_build_content.py:168–173` runs `git show a448a3c:…`. A squash merge, a fresh export or a shallow clone breaks the 21 tests. Fix: store the pre-reflow English as a small test-data file. Until then, merge with a normal merge or fast-forward, not a squash.
- **`README.md` is out of date.** It says the verses come "from namo.lk" only (the paritha.org booklet and the two English booklets are also sources) and that design and plan live in `.superpowers/` and `design/` (they are in `docs/superpowers/`). After the rename and Task 16 it will need one more pass anyway.
- **Design doc wording.** Design §5.2 line 123 says "four of the six verses of section 18"; the content has four verses with English on two (ledger, Task 4).
- **Theme test covers 6 of 15 text roles.** `test/design/theme_test.dart`: a loop over all roles would guard the rule that every style carries the Sinhala fallback, which is what stops a web font download (ledger, Task 1).

Leave for now (recorded so they are not lost):

- **Android 12+ splash and launcher icon.** `android/app/src/main/res/values-v31/styles.xml` and `values-night-v31/styles.xml` carry no splash colour or icon (no `android_12:` block under `flutter_native_splash` in `pubspec.yaml:136–141`), so most current phones will show the system default splash rather than `#2B3837`. There is no adaptive launcher icon (`flutter_launcher_icons` has no `adaptive_icon_*` keys, `pubspec.yaml:125–134`), so modern launchers will shrink the icon onto a plate. Neither breaks a build. Do both at the first Android build, where the result can be seen, and re-check the three `ASSETCATALOG` lines afterwards.
- **Audio seam, for the task that adds a real recording.** `Reading.fromJson` (`lib/content/model.dart:194–201`) never reads the JSON's `audio` key and `RecordingInfo` has no `fromJson`, so a recording named in the content file would be ignored silently. `_bindAudio` is called during build and the two audio providers are watched inside the nested `LibraryGate` builder (`reader_screen.dart:127–143, 412–418`); it works, but only by build timing. `JustAudioChantPlayer._publish` maps "ready with position > 0" to paused. None of this is reachable in a release build today (no recording exists). Fix all three together with the first real recording, keeping the rule that the player provider is not read when there is no recording.
- **Package weight.** Splash PNGs about 3.1 MB on Android; eight web splash images about 5.7 MB (light and dark are identical); `assets/branding/namo_icon_square.png` is 1.5 MB shown at 96 px; Noto Serif plus italic (4.3 MB) is bundled and loaded at web start-up but unused until Roman-script Pali exists (`NamoFonts.romanPali` is referenced nowhere else); the 160 KB placeholder tone ships in release. The plan asked for most of this; worth one tidy-up before publishing.
- Small things: `lib/storage/key_value_store.dart:15–19` drops write errors without a trace; `not_found.dart` and `router.dart` import each other; `Routes.reader` does not encode ids (ids are plain today); `_keepPlace` is not run when the device's own text size changes while the reader is open; `LibraryGate` shows a blank while loading and offers no retry after a failed load (the file is bundled, so a failure means a broken build); `pubspec.yaml` still has scaffold comments and a description mentioning pirith; `build/web/version.json` and the Dart package are still named `buddhist_gatha`; the web splash `<picture>` relies on the generated script to be removed.

### Triage of the ledger's deferred items

**Fix before merge**

- Task 10 — heading-at-top position drops its fraction → with Important 1.
- Task 5 — "reader must have a working back": the top-bar arrow was done in Task 9, the system Back was not → Important 2.

**Fix in the wave**

- Task 11 — per-frame capture and save-timer restart while auto-scroll runs → throttle, do not skip (Minor above).
- Task 11 — Start at the very end needs a second press.
- Task 10b — `baseline()` needs `git show a448a3c:` → keep the baseline as a file.
- Task 4 — design §5.2 line 123 wording.
- Task 4 — no direct test for the whole-word `ම විසින්` rule: one small Python test; it guards against changing a longer word in sacred text.
- Task 1 — theme test over all 15 text roles.

**Leave**

- Ruling: branch in place, no worktree — fine; note the working tree is now shared with Task 16.
- Ruling: Mahamevnawa translator recorded as "not named by the source" — correct and honest.
- Ruling: `screen-*` keys survive rewrites — held at `bf2900d`; Task 16 must keep them.
- Ruling: `chantPlayerProvider` not read without a recording — held (`reader_screen.dart:417`).
- Ruling: stage checks run by the controller — fine.
- Ruling: Task 3b (no CDN flag, `Roboto` → Lora) — holds; verified in the built font manifest. The offline promise depends on the build flag in the README.
- Ruling: reader shows the title once when reading and category titles match — fine; revisit after the rename if they differ.
- Rulings: Task 10b reflow of Mahamevnawa prose only — fine, whitespace-only and tested.
- Rulings after `bf2900d` (rename spelling, Task 16, Task 17) — outside this range; for the scoped re-review.
- Task 1 — `namoText` weight rounding; `ElevatedButton` colours and un-themed widgets.
- Task 2 — viewport meta in `web/index.html` (done in Task 15); `Info.plist` re-indent and lost trailing newlines; `make_icon_square.py` has no main guard; re-running the icon tool may re-break the pbxproj (correct now; re-check only if icons are regenerated).
- Task 3 — circular import; repeated `labelType`, `_tabs` not const, hard-coded gap; rail safe area and rail tap-target tests (both done in Task 15).
- Task 3b — `Roboto` alias has no italic.
- Task 4 — build checks only the kind of the two booklet heading lines; English line wraps (done in Task 10b); the `-m unittest` note.
- Task 5 — subtitle font (resolved); row-number contrast (done in Task 15); no test for an unknown category address (the page goes away in Task 16).
- Task 6 — duplicated empty `SourceRecord`; strict typing inside `notes`/`corrections`; formatter churn.
- Task 7 — dropped write future (done in Task 13); `selected` versus `checked` and focus colour (done in Task 15); disabled-state test; Settings width (done in Task 14); rows shifting when the hint appears.
- Task 8 — one-language test uses Sinhala only; note string duplicated in the test.
- Task 9 — top-bar overflow (done in Tasks 11 and 15); 60 % sheet height; `aHeadingIsOnScreen`; inert-tap test; `_updateButtons` each build.
- Task 10 — one test chains seven scenarios; bookmark alignment and title ellipsis (both done).
- Task 10b — s02 asserted by line count (the ledger's line number is stale; the file has 214 lines); `MAHAMEVNAWA_PROSE` includes s02-v1.
- Task 11 — "Custom" label shift (done in Task 15); reading change pauses rather than stops (cannot happen with one reading); speed limits defined twice (same values); fixed 76-px top bar (done in Task 15).
- Task 12 — placeholder tone in release packages (owner was told; see package weight); `_bindAudio` in build and `_publish` mapping (with the first real recording); audio semantics and row width (done in Task 15).
- Task 13 — silent write errors; `_FailingStore.remove` and the `Future.delayed` in the restart test.
- Task 14 — wide caps and large-text tests for Saved/Sources, faint switch, long-token row (all done in Task 15); favourites ordering test; import order.
- Task 15 — Sources addresses read by label only; accessibility test without bundled fonts; hard-coded `_toolbarHeight` / `firstLine` metrics; gold accent at 2.86:1 on ivory (owner's palette, non-text marks only, state also shown by shape) — tell the owner, do not change.

### Declined to judge

- App ids are still `com.example.*` and the Android release build is signed with debug keys — the plan defers publishing; must change before any store upload.
- The repository tracks the raw source material (namo.lk scrape, source PDFs) — not shipped in the app; matters only if the repository is made public.
- Permission or courtesy notes to namo.lk, paritha.org and the two translators — the design leaves this to the owner.
- Whether auto-scroll looks smooth and whether Slow/Normal/Fast suit a chanting pace — needs the owner's eye on a phone.
- The name "Namo" and the owner-supplied icon alongside namo.lk — the owner's choice; the Sources page carries the disclaimer.
- Commits after `bf2900d` (rename `0cf4091`, Task 16 in progress, Task 17 queued) — outside the range given.
- Audio continuing with the screen locked or the app in the background — a stated non-goal of the design.
- Installing the web app for offline use (service worker) — a stated non-goal.
- Whether the four "needs checking" verses and the 16 recorded corrections are doctrinally right — only someone who reads Pali and Sinhala can say; the app shows them openly.

### Recommendations

1. Run the one fix wave **after** Task 16 lands, not alongside it: Important 2 and the README edit both touch what Task 16 changes, and one implementer on a settled tree is safer than two on a moving one.
2. Order inside the wave: Important 1 (position) → Important 2 (Back) → Important 3 (wake lock) → save throttle and Start-at-end → icons → the text-only items.
3. Merge with a normal merge or fast-forward unless the `a448a3c` baseline has been replaced by a file.
4. Before any phone release, do a first Android build and try, in this order: system Back from the reader, auto-scroll for three minutes untouched, the splash and launcher icon, rotating the phone mid-reading. None of these has ever been run.
5. When the first real recording arrives, start with the audio seam items listed under "Leave for now".
6. Tell the owner two things in plain words: the gold accent is slightly under the usual contrast guide for small marks (their palette, their call), and Android and iOS have not been built at all.

### Assessment

**Ready to merge?** With fixes

**Reasoning:** The branch meets the spec's standing rules (free, offline, honest about its sources, no invented text, one code path for three platforms) and nothing found is a blocker, but three things a person on a phone would trip over — the place jumping to the wrong language's text, Back closing the app, and the screen locking mid-chant — should go into the one fix wave first. Android and iOS remain unbuilt, so the phone-side findings are from reading the code and need a first run on a device.
