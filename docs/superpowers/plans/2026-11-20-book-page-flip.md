# Book Page Flipping Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Read the bundled Rerukane books on screen-sized pages turned by an app-drawn page curl that follows the finger, with Pages/Scroll chosen in the reader's settings.

**Architecture:** A pure paginator cuts one source page ("chapter") into screen pages of slices (whole blocks, line ranges, table rows), measured with the same `TextPainter` styles the reader draws with. A chapter-stream controller keeps the current chapter and its two neighbours cut and moves a cursor across chapter edges. A `PageCurl` widget turns snapshots of the current and next page with a painter. The existing book reader becomes a shell that shows the old scroll view or the new pages view.

**Tech Stack:** Flutter 3.47.9 (`/c/Users/Dell/develop/flutter/bin/flutter`), Riverpod 3, go_router. No new packages.

**Spec:** `docs/superpowers/specs/2026-11-20-book-page-flip-design.md`

## Global Constraints

- Books only; chants, pirith, Samantha Pattana and Tripitaka readers unchanged.
- Setting `bookReadingMode`: `pages` | `scroll`, default `pages`, JSON key `"bookReadingMode"`; unknown or missing value reads as `pages`.
- Chooser labels exactly "Pages" / "Scroll", shown only in the book reader's settings sheet, above text size.
- Pages-mode bottom bar: "Previous page" / "Next page" buttons (keys `book-page-prev` / `book-page-next`), count text `"$i of $n"` (key `book-page-count`) within the current source page. Scroll mode keeps today's bar unchanged (keys `book-prev` / `book-next`, `"$index / $total"`).
- Screen-reader announcement after a turn: `"Page $i of $n"`.
- Never break mid-line; no single orphan/widow line when a paragraph has 4 or more lines; a heading/subhead never ends a page; gatha whole when it fits; table/picture moves to next page when it doesn't fit the rest; a table taller than a page breaks between rows with its header row repeated (when `header` is true); a picture taller than a page is scaled to fit; tables never scroll sideways in Pages mode (shrunk to the column width).
- A turn completes when released past half the page width or flung faster than 700 logical px/s in the turn's direction; otherwise it falls back.
- Tap turns in the outer fifth of each side. Keys: Left/Right arrow, Page Up/Page Down.
- `MediaQuery.disableAnimationsOf(context)` true → pages change with no curl.
- The curl carries across chapters; only the current chapter and its previous/next reading pages stay cut. The address updates to `Routes.bookReader(id, n)` with no route transition.
- On width ≥ `NamoSizes.wideBreakpoint` (840) the page is a sheet in the reading column (max `NamoSizes.readingColumn` 680) with a shadow; the drag/tap edges are the sheet's.
- Saved places: old entries (`n`, `key`, `offset`) still open; Pages mode converts an offset-only place to the page holding that offset.
- Text is never changed. Android, iPhone and web stay in step.
- Git: identity `Avishka Induwara <v.g.a.induwara@gmail.com>`; commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; never `git add -A`; never push.
- One flutter command at a time per folder.

## Review Focus

1. **Text size changed mid-chapter** — the reader stays on the page holding the same passage, not page 1 and not a page number. (Task 6 test `re-cut keeps the passage`.)
2. **Turning back across a chapter edge** — lands on the previous chapter's *last* page, even when that chapter is the longest. (Task 6 test `previous from first page lands on last page of previous chapter`.)
3. **A slice that loses or repeats text** — the concatenation of every page's text equals the chapter's text for paragraphs split over pages. (Task 3 test `no text lost or repeated`.)
4. **Drag that starts in the middle of the page** — does not turn (only the edge regions start a drag); a vertical swipe never turns. (Task 5 test `a drag from the middle does nothing`.)
5. **Device back / browser back after crossing chapters** — leaves to the contents of the chapter now shown, not the one first opened. (Task 7 test `back after crossing goes to the new chapter's parent`.)

---

### Task 1: The Pages/Scroll setting and its chooser

**Files:**
- Modify: `lib/settings/settings.dart`, `lib/settings/choosers.dart`, `lib/reader/reader_settings_sheet.dart`
- Test: `test/settings/settings_test.dart`, `test/settings/choosers_test.dart`

**Interfaces:**
- Produces: `enum BookReadingMode { pages, scroll }` with `String get label` ("Pages", "Scroll"); `AppSettings.bookReadingMode` (default `BookReadingMode.pages`); `SettingsController.setBookReadingMode(BookReadingMode v)`; `class BookReadingModeChooser extends ConsumerWidget` (key `ValueKey('book-reading-mode')`); `showReaderSettingsSheet(..., bool bookMode = false)` and `ReaderSettingsSheet.bookMode`.

- [ ] **Step 1: Write the failing tests**

```dart
test('bookReadingMode defaults to pages and round-trips', () {
  expect(const AppSettings().bookReadingMode, BookReadingMode.pages);
  final s = const AppSettings().copyWith(bookReadingMode: BookReadingMode.scroll);
  expect(AppSettings.fromJson(s.toJson()).bookReadingMode, BookReadingMode.scroll);
  expect(AppSettings.fromJson({'bookReadingMode': 'sideways'}).bookReadingMode,
      BookReadingMode.pages);
});
testWidgets('the book reader sheet shows Pages / Scroll above text size', ...);
  // showReaderSettingsSheet(textOnly: true, bookMode: true): finds 'Pages' and 'Scroll';
  // the chooser's top is above the text-size slider's top; tapping 'Scroll'
  // sets settingsProvider.bookReadingMode to scroll.
testWidgets('the Tripitaka sheet has no Pages / Scroll', ...);
  // textOnly: true, bookMode: false → find.text('Pages') findsNothing.
```

- [ ] **Step 2: Run, expect FAIL** — `flutter test test/settings/settings_test.dart test/settings/choosers_test.dart`.
- [ ] **Step 3: Implement.** Field read like `themeMode` (`asNameMap()` with default). Chooser uses `SegmentedSelector<BookReadingMode>` like `ThemeChooser`. In the sheet, when `bookMode`, insert `SettingLabel('Reading')` + chooser + gap before `SliderSetting.textSize`.
- [ ] **Step 4: Run, expect PASS**; also `flutter analyze`.
- [ ] **Step 5: Commit** `feat(books): Pages or Scroll setting for the book reader`.

### Task 2: Text-position places

**Files:**
- Modify: `lib/books/book_places.dart`
- Test: `test/books/book_places_test.dart` (create if absent)

**Interfaces:**
- Produces: `@immutable class BookSpot { const BookSpot(this.block, this.char); final int block; final int char; }` with `==`, `hashCode`, `compareTo` (block then char), `static const start = BookSpot(0, 0)` (block `-1` is reserved for the title: `BookSpot.title = BookSpot(-1, 0)`). `BookPlace.spot` (`BookSpot?`). `BookPlacesController.remember(id, n:, key:, offset:, BookSpot? spot)`. JSON: `"spot": [block, char]`.

- [ ] **Step 1: Failing tests**

```dart
test('a place with a spot round-trips', () {
  final p = BookPlaces.fromJson({'b': {'n': 3, 'key': '1-2', 'offset': 10.0, 'spot': [2, 140]}});
  expect(p.of('b')!.spot, const BookSpot(2, 140));
  expect(BookPlaces.fromJson(p.toJson()).of('b')!.spot, const BookSpot(2, 140));
});
test('an old place without a spot still reads', () {
  expect(BookPlaces.fromJson({'b': {'n': 3, 'offset': 10}}).of('b')!.spot, isNull);
});
test('a damaged spot is dropped alone', () {
  final p = BookPlaces.fromJson({'b': {'n': 3, 'offset': 0, 'spot': ['x', -1]}});
  expect(p.of('b')!.n, 3);
  expect(p.of('b')!.spot, isNull);
});
```

- [ ] **Step 2: FAIL. Step 3: Implement** (a spot whose numbers are not ints, `block < -1` or `char < 0` is dropped). **Step 4: PASS. Step 5: Commit** `feat(books): places remember a text position`.

### Task 3: Shared block drawing and the paginator

**Files:**
- Create: `lib/books/book_blocks.dart` (moved out of `book_reader_screen.dart`: `_block` → `BookBlockView`, `_LeadRows` → `LeadRows`, `_BookTable` → `BookTable`, `_lineWidth` → `lineWidth`, plus `BookTextStyles` and `leadWidth`)
- Create: `lib/books/pagination/book_paginator.dart`
- Modify: `lib/books/book_reader_screen.dart` (use `BookBlockView`; behaviour unchanged)
- Test: `test/books/book_paginator_test.dart`

**Interfaces:**
- Produces:
  - `class BookTextStyles { prose, strong, heading, caption, title; TextScaler scaler; TextDirection direction; static BookTextStyles of(BuildContext, AppSettings) }` — the one source of styles for drawing and measuring.
  - `double leadWidth(List<String?> labels, TextStyle style, double minLead, TextScaler scaler, TextDirection dir)` — used by `LeadRows` and the paginator.
  - `class BookTable` gains `bool fitWidth` (true: never scrolls sideways, shrinks to width) and `bool repeatHeader`, `int fromRow`, `int toRow`.
  - `sealed class PageSlice` with `TitleSlice()`, `BlockSlice(int block)`, `LinesSlice(int block, int item, int charStart, int charEnd)` (item 0 for a paragraph; list/footnote item index; gatha line index range uses `GathaSlice(int block, int fromLine, int toLine)`), `TableSlice(int block, int fromRow, int toRow, bool repeatHeader)`, `ImageSlice(int block, double scale)`. Each slice has `BookSpot get spot` (its first character) and `double top` (its y within the page).
  - `class ScreenPage { final List<PageSlice> slices; BookSpot get start; }`
  - `class PageBox { final double width, height; }`
  - `Iterable<ScreenPage> paginate(BookPage page, BookTextStyles styles, PageBox box)` — a lazy `sync*` generator so callers can take the first page then the rest in chunks.
  - `int pageIndexOf(List<ScreenPage> pages, BookSpot spot)` — the last page whose `start <= spot`.
  - `BookSpot spotAtOffset(BookPage page, BookTextStyles styles, double width, double offset)` — lays the chapter out as the scroll column does (title, `NamoSpace.lg`, blocks separated by `NamoSpace.md`) and returns the spot of the first line at or below `offset`.
- Gaps on a page match the scroll view: title then `NamoSpace.lg`, then `NamoSpace.md` between slices.
- `LinesSlice` text is `text.substring(charStart, charEnd)` drawn with the same style and width; line ends come from `TextPainter.computeLineMetrics` + `getLineBoundary`.

- [ ] **Step 1: Failing tests** (use `loadBundledFonts`; styles from `BookTextStyles` with `TextScaler.noScaling`; box 360×640 unless stated)

```dart
test('a short chapter is one page starting with its title', ...);
  // pages.length == 1; pages[0].slices.first is TitleSlice.
test('no text lost or repeated', ...);
  // a chapter of 30 long paragraphs at fontScale 1.6: joining every LinesSlice/BlockSlice
  // text per block, in order, equals each paragraph's text exactly.
test('no page is taller than the box', ...);
  // for each page, laying out its slices (sum of heights + gaps) <= box.height.
test('no single orphan or widow line', ...);
  // every paragraph split across pages has >= 2 lines on each side when it has >= 4 lines.
test('a heading never ends a page', ...);
  // no page's last slice is a heading/subhead BlockSlice.
test('a gatha that fits stays whole', ...);
test('a tall table breaks between rows and repeats its header', ...);
  // a 40-row table with header: TableSlices cover rows 1..39 once each, every
  // TableSlice after the first has repeatHeader == true.
test('a picture taller than the page is scaled to fit', ...);
  // ImageSlice.scale < 1 and its drawn height <= box.height.
test('pageIndexOf finds the page holding a spot', ...);
test('spotAtOffset 0 is the title; past the end is the last line', ...);
test('the scroll view still draws the same', ...);
  // widget test: the existing book reader tests in test/books pass unchanged.
```

- [ ] **Step 2: FAIL. Step 3: Implement** — move the drawing code first (run `flutter test test/books` green), then the paginator. **Step 4: PASS** `flutter test test/books`. **Step 5: Commit** `refactor(books): shared block drawing` then `feat(books): cut a chapter into screen pages`.

### Task 4: Drawing one screen page

**Files:**
- Create: `lib/books/pagination/screen_page_view.dart`
- Test: `test/books/screen_page_view_test.dart`

**Interfaces:**
- Consumes: Task 3 slices, `BookBlockView`, `LeadRows`, `BookTable`.
- Produces: `class ScreenPageView extends StatelessWidget { ScreenPageView({required BookPage chapter, required ScreenPage page, required BookTextStyles styles, required bool sheet}) }` — draws the slices top to bottom with the paginator's gaps, inside a `PageSheet` (paper colour `NamoPalette.surface`, shadow, `NamoRadius.sm` corners) when `sheet`, else full-bleed on `p.background`. Wraps itself in a `RepaintBoundary` (snapshots in Task 5).

- [ ] **Step 1: Failing tests** — `draws exactly the slices' text` (find.text for a LinesSlice substring); `no overflow at 320 wide with fontScale 1.6` (paginate at that size, pump each page, `tester.takeException()` is null); `the title is a header for screen readers`.
- [ ] **Steps 2–5** as usual. Commit `feat(books): draw a screen page`.

### Task 5: The page curl

**Files:**
- Create: `lib/books/curl/curl_geometry.dart`, `lib/books/curl/page_curl.dart`
- Test: `test/books/curl_geometry_test.dart`, `test/books/page_curl_test.dart`

**Interfaces:**
- Produces:
  - `class CurlGeometry { static CurlGeometry forward(Size page, Offset finger); static CurlGeometry backward(Size page, Offset finger); Path frontVisible; Path backFlap; Line fold; double progress /* 0..1 */ }` — pure functions of size and finger.
  - `class PageCurl extends StatefulWidget { PageCurl({required Widget current, required Widget? next, required Widget? previous, required VoidCallback onTurnedForward, required VoidCallback onTurnedBack, required PageCurlController controller}) }`
  - `class PageCurlController extends ChangeNotifier { Future<void> turnForward(); Future<void> turnBack(); bool get turning; }` — used by arrows, taps and keys.
- Behaviour: drag starts only within 15% of the page width from the left/right edge (minimum 48 px); a mostly vertical drag (|dy| > |dx| at slop) is ignored. Snapshots via `RenderRepaintBoundary.toImageSync` of `current` and the target page when the drag starts; painted with `CustomPainter` (front clipped by `frontVisible`, `backFlap` drawn as the mirrored snapshot tinted with `NamoPalette.surface` at 85% opacity, shadow along `fold` on the page beneath, highlight gradient on the flap). Release rule and 700 px/s fling from Global Constraints. Animation duration `NamoMotion.of(context, NamoMotion.open)` (zero under reduced motion: callback fires, no painting). `next == null` → forward drag/tap does nothing (end of book), same for `previous`.

- [ ] **Step 1: Failing tests**

```dart
test('a finger at the right edge folds nothing; at the left edge the page is turned', ...);
  // forward(Size(360,640), Offset(360, 600)).progress == 0; Offset(0, 600) → 1.
test('the fold is the perpendicular bisector of corner and finger', ...);
testWidgets('drag past half completes the turn', ...);   // onTurnedForward called once
testWidgets('drag short of half falls back', ...);       // not called; current still shown
testWidgets('a fast short fling completes', ...);        // 60 px at 1000 px/s
testWidgets('a drag from the middle does nothing', ...);
testWidgets('a vertical swipe does nothing', ...);
testWidgets('reduced motion turns at once with no curl painted', ...);
testWidgets('no next page: forward does nothing', ...);
testWidgets('controller.turnForward animates and calls back', ...);
```

- [ ] **Steps 2–5.** Commit `feat(books): page curl that follows the finger`.

### Task 6: The chapter stream

**Files:**
- Create: `lib/books/pagination/chapter_stream.dart`
- Test: `test/books/chapter_stream_test.dart`

**Interfaces:**
- Consumes: `paginate`, `pageIndexOf`, `Book.previousReading/nextReading/readingPages`.
- Produces: `class ChapterStream extends ChangeNotifier`:
  - `ChapterStream({required Book book, required int n, required BookSpot? spot, required Iterable<ScreenPage> Function(BookPage) cut, Future<void> Function() yieldFrame = _nextFrame})`
  - `int get n` (current chapter), `int get index` (0-based page in chapter), `int? get count` (null until the chapter is fully cut), `ScreenPage? get current`, `ScreenPage? get peekNext`, `ScreenPage? get peekPrevious` (null at the book's ends or while the neighbour is not cut yet), `bool get waiting`.
  - `bool next()`, `bool previous()` — move the cursor; crossing changes `n` and returns true; return false at the book's ends.
  - `void recut(Iterable<ScreenPage> Function(BookPage) cut)` — re-cuts all three, keeps `current.start` spot.
  - `void jumpTo(int n, BookSpot? spot)`.
  - Cuts in chunks of 4 pages per `yieldFrame`, current chapter first, then next, then previous. Keeps only current ± 1 chapters.
- Tests run with a fake `cut` (fixed pages per chapter) and `yieldFrame` that completes immediately.

- [ ] **Step 1: Failing tests** — `opens at the page holding the spot`; `next on last page crosses to the next chapter's first page`; `previous from first page lands on last page of previous chapter`; `at the ends next/previous return false`; `count is null until the chapter is cut, then its length`; `re-cut keeps the passage` (spot on page 7 of 10-per-chapter, recut with 20-per-chapter → page holding the same spot); `only three chapters stay cut` (after 3 crossings, chapter 1's pages are released).
- [ ] **Steps 2–5.** Commit `feat(books): chapters cut ahead for continuous turning`.

### Task 7: Pages mode in the reader

**Files:**
- Create: `lib/books/book_pages_view.dart`
- Modify: `lib/books/book_reader_screen.dart`, `lib/router.dart`
- Test: `test/books/book_pages_view_test.dart`

**Interfaces:**
- Consumes: Tasks 1–6.
- Produces: `class BookPagesView extends ConsumerStatefulWidget { BookPagesView({required Book book, required int n, required ValueChanged<int> onChapter, required VoidCallback onBack}) }`.
- Router: in Pages mode the reader's page key is `ValueKey('book-read-$id')` and the screen key `ValueKey('book-reader-$id')`, so a chapter change updates the page in place (no transition, state kept); in Scroll mode both stay as today (`state.pageKey`, `ValueKey('book-reader-$id-$n')`). The route reads the mode with `ProviderScope.containerOf(context).read(settingsProvider)`.
- `BookReaderScreen` picks the view by `bookReadingMode`; Scroll keeps today's body and bar. `didUpdateWidget` with a new `n` not caused by the stream → `stream.jumpTo(n, null)`.
- Chapter crossed → `onChapter(n)` → `context.go(Routes.bookReader(id, n))`; place saved as `remember(id, n:, key:, offset: 0, spot: current.start)` after 400 ms still (as today's `_saveDelay`).
- Bottom bar (Pages): `NamoIconButton` keys and tooltips from Global Constraints; count `"${index + 1} of $count"` (while `count` is null: `"${index + 1}"`). Disabled at the book's ends. While the stream is `waiting`, the arrow shows `BookLoading`'s mark small and does nothing.
- Keyboard via `Shortcuts`/`Actions`: Left/PageUp → back, Right/PageDown → forward.
- Semantics: the page area has `onScrollLeft`/`onScrollRight`-free custom actions `CustomSemanticsAction(label: 'Next page')` and `'Previous page'`; after a turn `SemanticsService.sendAnnouncement(View.of(context), 'Page ${index + 1} of $count', dir)`.
- Tap zones: outer fifth of the page box each side.
- Opening: place with spot → that spot; place with offset only on this chapter → `spotAtOffset(...)`; else chapter start.
- Settings changes (font scale, line spacing) or size change → `stream.recut`.

- [ ] **Step 1: Failing tests** (`openReal(t, Routes.bookReader(tinyBookNestedId, 8), books: fakeAssets(tinyBooksWithLongBlocks()))`, size 390×844, fontScale 1.6 so page 8 spans several pages)

```dart
testWidgets('Pages is the default: page arrows and "1 of N"', ...);
testWidgets('next page arrow turns and the count moves', ...);
testWidgets('turning past the chapter end shows the next chapter with no route transition and updates the address', ...);
testWidgets('back after crossing goes to the new chapter\'s parent', ...);
testWidgets('Right arrow key and Page Down turn forward', ...);
testWidgets('screen reader: Next page action turns and "Page 2 of N" is announced', ...);
testWidgets('the place is saved by spot and reopens on the same page', ...);
testWidgets('an offset-only place opens on the page holding that offset', ...);
testWidgets('bigger text keeps the same passage on screen', ...);
testWidgets('Scroll mode keeps today\'s bar and keys', ...);
testWidgets('a wide window draws the page as a sheet in the reading column', ...); // 1280×900
```

- [ ] **Steps 2–5.** Commit `feat(books): read books page by page`.

### Task 8: Switching modes and the quality sweep

**Files:**
- Modify: `lib/books/book_reader_screen.dart`, `lib/books/book_pages_view.dart`
- Modify: `test/quality/overflow_test.dart` (add Pages-mode cases), `docs/release-checklist.md` (one line under Books: page flipping, manual check on a phone)
- Test: `test/books/book_mode_switch_test.dart`

**Interfaces:**
- Consumes: everything above. Scroll view exposes the first visible line's spot (via `spotAtOffset` on its current offset); Pages view exposes `current.start`.

- [ ] **Step 1: Failing tests** — `Scroll → Pages opens the page holding the first visible line`; `Pages → Scroll scrolls to the shown page's first line`; overflow at 320×568 with fontScale 1.6 in Pages mode for every page of `tinyBooksWithLongBlocks`, light and dark; every Pages-mode tap target ≥ 48×48.
- [ ] **Step 2: FAIL. Step 3: Implement. Step 4:** full suite `flutter test` green, `flutter analyze` clean, `flutter build web --release` succeeds, `flutter build apk --release --split-per-abi` succeeds.
- [ ] **Step 5: Commit** `feat(books): switching Pages and Scroll keeps the passage`.
