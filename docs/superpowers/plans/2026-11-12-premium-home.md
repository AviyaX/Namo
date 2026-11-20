# Premium Home and Shared Look Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild Home in the arrangement of `design/mockups/home_dark.png` and give the whole app the same palette, card style and pill bottom bar, in light and dark.

**Architecture:** Shared look lives in `lib/design/` (palette, `SurfaceCard`, `FloatingBar`, `AppShell`, new `marks.dart`), so other screens change without layout edits. Home is recomposed from small widgets in `lib/home/`, each reading existing providers (`positionProvider`, `savedProvider`, `settingsProvider`, `flowsProvider`). No new packages, no new stored data.

**Tech Stack:** Flutter 3.47.9 (`/c/Users/Dell/develop/flutter/bin/flutter`), flutter_riverpod, go_router, material_symbols_icons; Python 3 + Pillow 12 for the one-off picture conversion.

**Spec:** `docs/superpowers/specs/2026-11-11-premium-home-design.md` (read it; where the mockup and the spec disagree the spec wins).

## Global Constraints

- No new dependencies, no new fonts. No network request at run time.
- No control that does nothing. No bell, no profile icon.
- No religious text typed by hand: verse and heading text comes only from `assets/content/*.json` through the existing model. Interface labels (English) are allowed: "Namaskara", "Tisarana", "Pancha Sila", "Buddha Guna", "Quick Access", "Collections", "FEATURED COLLECTION", "TODAY'S GATHA", "Buddhist Prayers · Chanting".
- Every existing feature stays reachable; existing tests are updated to the new design, never deleted without a replacement that covers the same behaviour.
- All text meets 4.5:1 contrast (3:1 for titles 24 px and up) on what it sits on, in both themes.
- Keep existing widget keys and semantics labels unless the task says otherwise (tests and screen readers depend on them).
- `NamoMotion.of(context, …)` for every animation (reduce-motion gives zero).
- Never run two flutter or git commands at the same time in one folder. Never `git add -A`; add files by name. Never use port 8766.
- Commit with `git -c user.name="Avishka Induwara" -c user.email="v.g.a.induwara@gmail.com" commit`, message ending `Co-Authored-By: Claude <noreply@anthropic.com>`. Do not push.
- Checks before each commit: `flutter analyze 2>&1 | tail -1` shows "No issues found!"; the task's own tests pass. Full suite (`flutter test`, about 5 minutes) is run by Task 1 (baseline) and Task 9 only, plus any task whose targeted runs suggest wider breakage; otherwise run the test files for the folders touched (`test/home test/design test/quality` and others named in the task).
- Python is run as `python -I -X utf8`.

## Review Focus

1. Text size 200% on a 320 px wide phone: nothing on Home clipped or overflowing (featured page, Quick Access labels, bottom bar).
2. First launch (no remembered place, no flows, no bookmarks): no progress lines, button says "Begin"/"Open", no empty gaps.
3. Light theme: words over `hero_light.jpg` and `header_light.jpg` stay readable.
4. A content file missing section `s01`–`s04`, or a topic with no readings: Home still builds; the card is simply absent or inert.
5. Remembered reading that no longer exists (stale id in storage): carousel and Collections show no progress and do not throw.

Each is pinned by a test in the task named in brackets below: 1 [Task 9], 2 [Tasks 6, 8], 3 [Tasks 5, 6], 4 [Task 8], 5 [Task 6].

---

### Task 1: Pictures

**Files:**
- Create: `tools/convert_ui_pictures.py`, `assets/pictures/hero_dark.jpg`, `hero_light.jpg`, `header_dark.jpg`, `header_light.jpg`
- Replace: `assets/pictures/buddha_wandanawa.jpg`, `assets/pictures/pirith.jpg`
- Delete: `assets/pictures/home_banner.jpg`
- Modify: `pubspec.yaml`, `lib/home/card_art.dart`, `docs/pictures.md`, `lib/settings/sources_screen.dart` only if its picture credit names files or counts
- Test: `test/home/card_art_test.dart`, `test/home/featured_card_test.dart`, `test/home/home_screen_test.dart` (picture assertions only)

**Interfaces:**
- Produces in `card_art.dart`:
  - `const Map<String, ({String dark, String light})> heroPictures` = `{'cat-namaskaraya': (dark: 'assets/pictures/hero_dark.jpg', light: 'assets/pictures/hero_light.jpg')}`
  - `const ({String dark, String light}) headerPictures` = `(dark: 'assets/pictures/header_dark.jpg', light: 'assets/pictures/header_light.jpg')`
  - `TopicPicture` keeps its constructor; `wide: true` is renamed `hero: true` and picks `heroPictures[categoryId]` by `Theme.of(context).brightness`, falling back to `cardPictures`. `widePictures` is removed.

- [ ] Step 1: Run the full suite once for a baseline (expect 1889 pass); record the number in the report.
- [ ] Step 2: Write `tools/convert_ui_pictures.py SRC_DIR DEST_DIR`: for each of `hero_dark, hero_light, header_dark, header_light, buddha_wandanawa, pirith` open `SRC_DIR/<name>.png`, convert to RGB, downscale so the longest side is at most 1600 (never upscale), save `DEST_DIR/<name>.jpg` quality 85, progressive, no metadata; print name, pixels, bytes, SHA-1. Missing source file is an error naming the file.
- [ ] Step 3: Run it: `python -I -X utf8 tools/convert_ui_pictures.py /c/Users/Dell/develop/buddhist_gatha/source_material/ui_pictures assets/pictures`. Open two outputs with the Read tool to confirm they are the right scenes.
- [ ] Step 4: Update tests first: `heroPictures`/`headerPictures` values as above; `widePictures` gone; every listed asset exists on disk and is listed in `pubspec.yaml`; `home_banner.jpg` is not referenced anywhere under `lib/`. Run, see fail.
- [ ] Step 5: Implement in `card_art.dart` and `pubspec.yaml`; update callers of `wide:` (`featured_card.dart`).
- [ ] Step 6: `docs/pictures.md`: new entries (supplied by the owner 2026-11-11, generated with ChatGPT from the owner's own mockup; pixels, bytes, SHA-1 from Step 3; use), note the two replaced files and that `home_banner.jpg` is no longer bundled; list `continue_thumb.png`, `statue_tall_warm.png`, `statue_tall_dark.png` as kept in source material, unused.
- [ ] Step 7: Tests pass, analyze clean, commit.

### Task 2: Palette, cards, overlines

**Files:**
- Modify: `lib/design/tokens.dart`, `lib/design/widgets/surface_card.dart`, `lib/design/widgets/page_header.dart` (Overline), `lib/design/typography.dart` (overline style only), `lib/design/theme.dart` if it names colours directly
- Test: `test/design/palette_test.dart`, `test/design/widgets/surface_card_test.dart`, `test/design/widgets/page_header_test.dart`, `test/quality/design_rules_test.dart`

**Interfaces:**
- `NamoPalette` values exactly as the spec's table. New field `final Color frame` (dark `Color(0x8CD2B26C)`, light `Color(0x738A6A2C)`), in constructor, `copyWith`, `lerp`.
- `NamoRadius.card = 20.0` added; `SurfaceCard` default radius becomes `NamoRadius.card`.
- `SurfaceCard` gains `bool framed = false` (border colour `p.frame` instead of `p.border`) and paints a vertical gradient `p.surface` → `p.backgroundAlt`. `leadingLine` stays.
- `Overline` gains `bool accent = false`: gold colour, upper-cased text for display with the original string as the semantics label, letter spacing 2.0.

- [ ] Step 1: Tests: palette values; for both palettes contrast ≥ 4.5 for `text`, `textSecondary`, `sage`, `gold` on `background`, `backgroundAlt` and `surface`, `textMuted` ≥ 3.0, `onSage` on `sage` ≥ 4.5 (reuse the contrast helper already in `palette_test.dart`); `SurfaceCard(framed: true)` border is `frame`; `Overline('Today\'s gatha', accent: true)` shows `TODAY'S GATHA` and has semantics label `Today's gatha`. Run, see fail.
- [ ] Step 2: Implement. If a spec colour fails a contrast test, move that colour's lightness the least amount that passes and note the final value in the report.
- [ ] Step 3: Run `flutter test test/design test/quality test/settings test/saved test/library`; fix tests that assert old colour values or radius by updating them to the new tokens (never by loosening what they check). `design_rules_test.dart` may forbid gradients or radii: read it and change the rule to allow exactly what this task adds.
- [ ] Step 4: Analyze clean, commit.

### Task 3: Pill bottom bar

**Files:**
- Modify: `lib/design/widgets/floating_bar.dart`, `lib/design/widgets/app_shell.dart`
- Test: `test/design/widgets/floating_bar_test.dart`, `test/design/widgets/app_shell_test.dart`

**Interfaces:**
- `FloatingBar` gains `bool pill = false`: radius 999 instead of `NamoRadius.lg`. The reader's bars keep the default.
- `_Destination`: active = fill `p.sage`, icon and label `p.onSage`, radius 999 in the bar and `NamoRadius.sm` in the rail; inactive unchanged (`p.textSecondary`, no fill). Icon over label, keys `nav-home` etc., `_labelScaler`, min height and semantics unchanged.

- [ ] Step 1: Tests: active tab decoration colour is `sage` and its label colour `onSage` in both themes; inactive has no fill; bar radius is 999; existing text-scale tests still pass unchanged.
- [ ] Step 2: Implement, run the two test files plus `test/quality`, analyze, commit.

### Task 4: Drawn marks

**Files:**
- Create: `lib/design/marks.dart`
- Test: `test/design/marks_test.dart`

**Interfaces (Produces):**
- `enum NamoMark { lotus, leaf, palms, wheel, lotusBud, seated }`
- `class NamoMarkIcon extends StatelessWidget { const NamoMarkIcon(this.mark, {super.key, this.size = 28, this.color, this.strokeWidth = 1.5, this.semanticLabel}); }` — a `CustomPaint` of line work in `color ?? palette.gold`; excluded from semantics when `semanticLabel` is null.
- `class LeafWatermark extends StatelessWidget { const LeafWatermark({super.key, this.opacity = 0.10}); }` — a large bodhi leaf (heart shape with a drawn-out tip, midrib and side veins) filling its box, always excluded from semantics.

Drawing notes: paths are built in a 24 × 24 unit box and scaled; round caps and joins; symmetric about the vertical centre line. lotus = three to five petals over a short base curve; palms = two hands joined, pointing up; wheel = circle, hub, eight spokes with small knobs outside the rim; lotusBud = three petals with two side leaves; seated = seated figure outline (head, shoulders, crossed legs base). Compare each against the mockup.

- [ ] Step 1: Tests: each `NamoMark` builds at 16, 28 and 64 without throwing; `shouldRepaint` false for equal inputs; with `semanticLabel` the label is in the semantics tree, without it nothing is; golden-free.
- [ ] Step 2: Implement (no golden files; the marks are looked at in the running app after Task 9). Run `test/design`, analyze, commit.

### Task 5: Home header and search

**Files:**
- Create: `lib/home/home_header.dart`
- Modify: `lib/home/home_screen.dart`, `lib/router.dart`, `lib/library/library_screen.dart`, `lib/design/widgets/search_field.dart`, `lib/design/widgets/namo_page.dart`
- Test: `test/home/home_header_test.dart`, `test/router_test.dart`, `test/library/library_search_test.dart`, `test/home/home_screen_test.dart`

**Interfaces:**
- `Routes.librarySearch = '/library?focus=search'`.
- `LibraryScreen` gains `final bool focusSearch` (from `state.uri.queryParameters['focus'] == 'search'`); when true on first build or when it turns true, it requests focus on the search field once, after the frame. `SearchField` gains an optional `FocusNode? focusNode` (uses its own when null).
- `NamoPage` gains `Widget? backdrop`: painted behind the scroll content, pinned to the top of the scrolling column (it scrolls away with the content), full column width.
- `HomeHeader({required DateTime now})`: Row of `NamoMarkIcon(NamoMark.lotus, size: 40)`, "Namo" wordmark (still `Semantics(header: true)`), trailing search `IconButton` (key `home-search`, tooltip and label "Search the library", `Symbols.search_rounded`) → `context.go(Routes.librarySearch)`; under the wordmark the tagline `Buddhist Prayers · Chanting` (caption style, `textSecondary`); then the greeting as now.
- Home's backdrop: `headerPictures` by brightness, height `min(width / 3, 240)` plus the top inset, `BoxFit.cover`, `Alignment.topRight`, with a bottom gradient to `p.background` over the lowest 40%, excluded from semantics, `errorBuilder` → nothing.

- [ ] Step 1: Tests: header shows mark, "Namo", tagline, greeting; no widget with a notifications icon exists on Home; tapping `home-search` lands on `/library?focus=search` and the Library's search field has focus; visiting `/library` plain does not focus it; pressing the Library tab again resets as before; header text contrast against the palette background (the text sits on the faded part) — assert the backdrop's gradient ends in `p.background` at full opacity; backdrop picture missing → Home still builds.
- [ ] Step 2: Implement; run `test/home test/library test/router_test.dart test/design`; analyze; commit.

### Task 6: Featured carousel

**Files:**
- Create: `lib/home/featured_carousel.dart`, `lib/home/topic_progress.dart`
- Modify: `lib/home/featured_card.dart`, `lib/home/home_screen.dart`, `lib/design/widgets/progress_line.dart`
- Test: `test/home/topic_progress_test.dart`, `test/home/featured_carousel_test.dart`, `test/home/featured_card_test.dart`

**Interfaces (Produces):**
- `topic_progress.dart`:
  - `class TopicResume { const TopicResume({required this.reading, required this.progress}); final Reading reading; final double progress; }`
  - `TopicResume? topicResume(Category c, PositionState s)` — one reading: that reading if `s.byReading` has it; several: the reading whose id is `s.lastReadingId` if it is in `c` and has an entry; otherwise null. A stale id gives null.
  - `enum FeaturedAction { continueReading, begin, open, none }` and `FeaturedAction featuredAction(Category c, PositionState s)` — `none` when no readings; `continueReading` when `topicResume` is non-null; `begin` for one reading; `open` for several.
  - `int startTopicIndex(Library l, PositionState s)` — index of the category holding `s.lastReadingId`, else 0.
- `FeaturedCard` (one page): overline `Overline('Featured collection', accent: true)`; title; `category.subtitle`; count; for a several-reading resume a caption with `reading.title`; button label `Continue` / `Begin` / `Open` (PrimaryButton with a play icon for Continue/Begin); when resuming, at the lower right `NN% complete` over a `ProgressLine(height: 4, rounded)`. Tap: continueReading → `Routes.reader(resume.reading.id, from: ReaderFrom.home)`; begin → reader of the single reading; open → `Routes.category(id)`. Picture: `TopicPicture(categoryId, hero: true)`, `Alignment.centerRight`; words on the left over a left-to-right scrim (`PictureWords`, `TextSide.left`) at all widths; phone height `max(words, width * 0.5)`, wide `width / 3`. Semantics label as now plus the button label and percent.
- `ProgressLine` gains `bool rounded = false`.
- `FeaturedCarousel({required Library library})`: `PageView` over all categories, `initialPage: startTopicIndex(...)` (read once), dots below (key `featured-dots`, active dot `gold`, others `border`, 6 px), wrapped in `Semantics(label: 'Featured collections', value: 'Page n of N', onIncrease/onDecrease)`; left/right arrow keys move a page when it has focus. Height follows the tallest page (measure pages offstage or use a fixed-aspect box that grows with text scale — builder's choice, but no clipping at 200% text). One category: no dots, no paging.

- [ ] Step 1: Unit tests for `topic_progress.dart`: all four actions; stale `lastReadingId`; last-read reading in another topic → `open`/`begin`; `startTopicIndex` for none/first/third.
- [ ] Step 2: Widget tests: first launch → page 1 "Begin", no `ProgressLine`, no "% complete"; remembered Buddha Wandanawa at 0.34 → "Continue", "34% complete"; last read a pirith → carousel starts on Pirith, shows that pirith's title and "Continue"; swipe changes semantics value to "Page 2 of 3"; reduce-motion: `onIncrease` jumps without animation; light theme uses `hero_light.jpg`, dark `hero_dark.jpg`; the scrim behind the first text line is at least `pictureFadeAtText` strong in both themes (existing `PictureWords` test pattern).
- [ ] Step 3: Implement; update `featured_card_test.dart` to the new card (keep its picture-fallback tests). In `home_screen.dart` replace `FeaturedCard(category: first)` with the carousel. Run `test/home test/pirith test/samantha_patthana test/quality`; analyze; commit.

### Task 7: Today's gatha card

**Files:**
- Modify: `lib/home/gatha_card.dart`
- Test: `test/home/gatha_card_test.dart`

**Interfaces:**
- `GathaCard` becomes a `ConsumerWidget` with the same constructor plus `required String topicTitle`. `SurfaceCard(framed: true)`; header row: `NamoMarkIcon(lotus, size: 20)`, `Overline("Today's gatha", accent: true)`, spacer, bookmark `IconButton` (key `gatha-bookmark`; `Symbols.bookmark_rounded`, filled when `savedProvider.isBookmarked(reading.id, section.id)`; tooltip/label "Bookmark this section" / "Remove bookmark"; calls `toggleBookmark`). Texts exactly as now (`gathaTexts`, keys `gatha-text-$i`, `readingStyle`). A short gold rule, then caption `'$topicTitle · ${pick.section.heading}'`. `SecondaryButton`-style pill "Read in context" with book icon and arrow (same route as now). `LeafWatermark` positioned at the right, behind the text, not hit-testable.
- `home_screen.dart` passes `topicTitle: library.categoryOf(pick.reading.id)?.title ?? ''` (omit the "· " when empty).

- [ ] Step 1: Tests: existing text/selection tests keep passing; bookmark toggles and the section then appears via `savedProvider`; caption shows topic and heading; watermark is not in semantics; English text appears only when the verse has English and the selection includes it (existing behaviour, assert it explicitly); 200% text scale at 320 px wide: no overflow.
- [ ] Step 2: Implement; run `test/home test/saved`; analyze; commit.

### Task 8: Quick Access, Collections, Home order

**Files:**
- Create: `lib/home/quick_access.dart`, `lib/home/collections_row.dart`
- Modify: `lib/home/home_screen.dart`, `lib/home/continue_card.dart`
- Delete: `lib/home/section_strip.dart` and its tests' section-strip cases (replace with Quick Access cases)
- Test: `test/home/quick_access_test.dart`, `test/home/collections_row_test.dart`, `test/home/home_screen_test.dart`

**Interfaces:**
- `quick_access.dart`: `const quickAccess = [(label: 'Namaskara', sectionId: 's01', mark: NamoMark.palms), (label: 'Tisarana', sectionId: 's02', mark: NamoMark.wheel), (label: 'Pancha Sila', sectionId: 's03', mark: NamoMark.lotusBud), (label: 'Buddha Guna', sectionId: 's04', mark: NamoMark.seated)]`; `QuickAccess({required Category category})` — title row "Quick Access" (header semantics) + `TextAction` "See all" → `Routes.category(category.id)`; cards for the entries whose section exists in `category.readings.first`; each a `SurfaceCard` (key `quick-${sectionId}`) with mark, label (`cardTitle`), `section.heading` (Sinhala caption, centred, wraps); tap → `Routes.reader(reading.id, sectionId: …, from: ReaderFrom.home)`; semantics label `'$label, ${section.heading}'`. Layout: four equal columns when the row is at least 328 px wide, else a 2 × 2 grid; equal heights per row. No entries → widget builds nothing.
- `collections_row.dart`: `CollectionsRow({required List<Category> categories})` — all categories; title row "Collections" + "See all" → `Routes.library`; cards keep key `collection-${c.id}` and `Routes.category` tap; each shows title, `subtitle`, book icon + count, and when `featuredAction == continueReading` **and the topic has one reading** a rounded `ProgressLine` with `NN%`. Phone: sideways `EqualHeightRow` as now, card width 220. Wide: three `Expanded` cards.
- `continue_card.dart`: `hasContinue` unchanged; Home shows `ContinueCard` only when `isFlowId(position.lastReadingId)`.
- Home order — phone: header, carousel, continue card (flow only), gatha, Quick Access, flows row, Collections. Wide: carousel; then a Row of gatha and (flow) continue card when both exist, else whichever exists; Quick Access; flows row; Collections.

- [ ] Step 1: Tests: four cards with labels and the headings taken from the test content; a library whose first reading lacks `s03` shows three cards; empty category shows no Quick Access block; "See all" routes; 2 × 2 at 320 px; Collections shows all three topics, progress only on a one-reading topic with a remembered place, none on first launch; ContinueCard absent when last read is a library reading, present for a flow; block order on phone and wide (compare top offsets by key).
- [ ] Step 2: Implement; rewrite the affected parts of `home_screen_test.dart` (917 lines; keep every behaviour it checks that still exists, by key). `grep -rn "section_strip\|SectionStrip" lib test` returns nothing afterwards. Run `test/home test/pirith test/samantha_patthana test/quality test/flows`; analyze; commit.

### Task 9: Whole-app checks

**Files:**
- Modify: `test/quality/overflow_test.dart`, `test/quality/accessibility_test.dart`, `test/quality/reduced_motion_test.dart`, `docs/release-checklist.md`
- Fix whatever these find, in the file that owns it.

- [ ] Step 1: Add Home cases: sizes 320×640, 412×915, 1280×800 × text scale 1.0 and 2.0 × light and dark → no overflow errors; tap targets ≥ 48 for `home-search`, `gatha-bookmark`, quick cards, dots' increase/decrease actions reachable; semantics traversal order equals the visual order of blocks; reduce-motion → no running animation after a page change.
- [ ] Step 2: Run the full suite, `flutter analyze`, `python -I -X utf8 tools/build_content.py . --check`, `tools/build_pirith.py . --check`, `tools/check_ui_glyphs.py .`, `tools/build_samantha_patthana.py . --check`. All green; report the test count.
- [ ] Step 3: `docs/release-checklist.md`: add owner lines — look at Home in light and dark on a phone; supply the new Samantha Pattana picture; confirm picture credit wording.
- [ ] Step 4: Commit.
