# Rerukane Chandawimala Books Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bundle the 23 books of Ven. Rerukane Chandawimala Maha Nahimi from pitaka.lk, with the Board's covers, as a Books shelf in the Library with a contents drill-down and a prose reader that remembers the place.

**Architecture:** A Python tool (`tools/sync_books.py`) turns the cached pitaka.lk pages into one gzipped JSON per book (a flat list of pages in reading order, each with a level and blocks) plus `index.json` and the covers; `--check` validates the bundle offline. In the app, `lib/books/` holds the model (with the contents tree derived from page levels), a lazy repository modelled on the Tripitaka's, a per-book saved place, and four screens: the shelf inside the Library page, the book page and the contents list as Library-branch routes, and a full-screen reader. The Library search gains a Books group.

**Tech Stack:** Flutter 3.47 / Dart 3.13, Riverpod 3, go_router 18, `archive` (gunzip, already a dependency), Python 3 stdlib (`html.parser`, `gzip`, `hashlib`, `urllib`).

**Spec:** `docs/superpowers/specs/2026-11-17-rerukane-books-design.md`

## Global Constraints

- Text unchanged: no character of the pitaka.lk text is added, removed or altered, except collapsing runs of whitespace inside a paragraph to one space. List numbers are never written into the text. Anything the parser cannot keep verbatim fails the fetch rather than being dropped or changed.
- Content reaches the app only through `tools/sync_books.py`; nothing under `assets/books/` is hand-edited. The cache is `source_material/pitaka_lk_books/<slug>/index.html` and `<slug>/<href>` (one file per TOC link, named by the href), ignored by git; a cached file is never fetched again.
- The 23 slugs, in this order: bauddhayage-athpotha, dharma-winishchaya, paramitha-prakaranaya, suvisi-gunaya, abhidharmaye-mulika-karunu, abhidharma-margaya, chathurarya-sathya, punyopadeshaya, shasanavatharanaya, bodhi-pakshika-dharma, patichcha-samuppada-vivaranaya, upasampada-sheelaya, ubhaya-prathimokshaya, wanchaka-dharma, vidarshana-bhavana-kramaya, keles-1500, pohoya-dinaya, bodhi-poojawa, chaththalisakara-vipassana, vinaya-karma, sathipttana-bhavana-kramaya, nirvana-vinishchaya, pattana-pakarana-sannaya.
- Files: `assets/books/index.json` (plain JSON), `assets/books/<slug>.json.gz` (gzip level 9, mtime 0), `assets/books/covers/<slug>.png`; `bytes` and `sha256` in the index are of the `.gz` file as shipped. Nothing else under `assets/books/`.
- Network: User-Agent `namo-app-build/1.0`, 200 ms between requests, timeout 60 s, three retries with growing waits. Never the owner's or the account's names in any request.
- Routes: `Routes.book(id) = '/library/book/<id>'`, `Routes.bookContents(id, n) = '/library/book/<id>/contents/<n>'` (children of the Library branch, `namoPage`), `Routes.bookReader(id, n) = '/library/book/<id>/read/<n>'` (a top-level route after the shell, like `/tipitaka/read/:key`). Navigation by `context.go`; each full-screen or branch-child screen wraps itself in `PopScope(canPop: false, ...)` and goes to its parent on Back.
- Keys: `books-shelf`, `book-<slug>` (shelf card), `book-continue`, `book-row-<n>`, `book-row-own-<n>`, `book-hit-<slug>` (search), `book-prev`, `book-next`, `book-reader-top-bar`, `sources-books`. Store key `namo.books.places.v1`.
- Copy, verbatim: shelf heading "පොත්" with sub-line "රේරුකානේ චන්දවිමල හිමියන්ගේ පොත්"; search group heading "Books"; buttons "Start reading" / "Continue reading"; contents heading "Contents"; tooltips "Back", "Previous page", "Next page", "Reading settings"; credit lines "Text: pitaka.lk" and "Published by the Sri Chandawimala Dhamma Treatises Preservation Board"; errors "The books could not be opened." and "The book could not be opened." with action "Try again". No middle dots or other characters outside the bundled fonts (`tools/check_ui_glyphs.py` must stay at exit 0).
- Design rules (`test/quality/design_rules_test.dart`): no raw colour outside `lib/design/tokens.dart`; `textMuted` only under `lib/design/`; no `Card(`, `ListTile(`, `ElevatedButton`…; sizes via `NamoType` (no `size:` in `namoText(` calls, no `fontSize:` below 12); every `Duration(milliseconds:` outside tokens is allow-listed with a reason. `readingStyle(ReadingLanguage.sinhala, fontScale: settings.fontScale, lineSpacing: settings.lineSpacing, color: p.text)` for prose.
- Tests: `pumpApp`/`openReal` keep working for every existing test; `openReal` gains `AssetBytes? books` and serves a tiny fixture by default so no quality test reads the 23-book bundle. Every task ends with `/c/Users/Dell/develop/flutter/bin/flutter analyze` clean and the task's named suites green; the full `flutter test` runs in Tasks 5 and 6. One flutter or git command at a time; never `git add -A`; commits by name with trailer `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- Android, iOS and web from one code base; nothing per platform changes for assets. The size is measured in Task 6 (arm64 split APK before: 53,975,660 bytes at 000f892).

## Review Focus

1. A link or saved place to a page that is not a reading page (an empty parent, or `n` out of range) must open the next reading page, never a blank screen — Task 5 (`'a non-reading n redirects to the next reading page'`, `'an n past the end goes to the book page'`).
2. A saved place whose `n` no longer exists after a content update (fewer pages) must fall back to "Start reading" at page 1, not crash — Task 4 (`'a saved place past the end reads as Start reading'`).
3. A missing or corrupt cover must show the placeholder, not an exception — Task 4 (`'a cover that fails to load shows the placeholder'`).
4. A book file that fails to unpack or parse must show the error state with Try again and recover on the next attempt — Task 3 (`'a failed load is forgotten so the next call retries'`) and Task 5 (`'a book that cannot be opened shows Try again'`).
5. Long titles, a `list` page and a `gatha` page at 320 px and 2.0× text must not overflow — Task 6 (overflow matrix rows for the shelf, book page, contents list and both reader pages).

---

### Task 1: The sync tool and its tests

**Files:**
- Create: `tools/sync_books.py`, `tools/test_sync_books.py`, `tools/test_data/pitaka_lk_books/README.md`, `tools/test_data/pitaka_lk_books/flat/index.html`, `tools/test_data/pitaka_lk_books/flat/1.html`, `tools/test_data/pitaka_lk_books/nested/index.html`, `tools/test_data/pitaka_lk_books/nested/1.html`, `tools/test_data/pitaka_lk_books/nested/1-1.html`, `tools/test_data/pitaka_lk_books/nested/2.html`, `tools/test_data/pitaka_lk_books/nested/2-1.html`, `tools/test_data/pitaka_lk_books/nested/2-1-1.html`
- Modify: nothing in the app

**Interfaces:**
- Consumes: the cache at `source_material/pitaka_lk_books/<slug>/` (already populated for most pages; the tool fetches whatever is missing).
- Produces:
  ```python
  # tools/sync_books.py — stdlib only; usage in the docstring:
  #   python -I -X utf8 tools/sync_books.py <project> [--fetch] [--survey] [--check] [--covers]
  SLUGS: list[str]                      # the 23, in order (Global Constraints)
  BASE_URL = "https://pitaka.lk/books/"
  USER_AGENT = "namo-app-build/1.0"
  PAUSE_SECONDS = 0.2
  SCHEMA = 1
  AUTHOR = {"si": "රේරුකානේ චන්දවිමල මහා නාහිමි", "en": "Ven. Rerukane Chandawimala Maha Nahimi"}
  PUBLISHER = {"si": "ශ්‍රී චන්දවිමල ධර්මපුස්තක සංරක්ෂණ මණ්ඩලය", "en": "Sri Chandawimala Dhamma Treatises Preservation Board"}
  COVERS: dict[str, tuple[str, str]]    # slug -> (official title as the Board's /api/books lists it, cover URL); filled in Task 2
  BLOCK_TAGS = {"p": "para", "h2": "heading", "h3": "heading", "h4": "heading", "ol": "list", "ul": "list"}
  INLINE_TAGS = {"b", "strong", "i", "em", "u", "span", "a", "sup", "sub", "br"}   # flattened to their text; <br> is a line break
  SKIP_TAGS_IN_MAIN = {"nav", "dialog", "button", "script", "svg", "style"}        # plus div.page-title
  class SyncError(Exception): ...

  def cache_dir(project) -> pathlib.Path      # project/source_material/pitaka_lk_books
  def assets_dir(project) -> pathlib.Path     # project/assets/books
  def fetch_text(url, opener=urllib.request.urlopen) -> str      # UA header, timeout 60, 3 retries (sleep 2, 4, 6), raises SyncError
  def cached_page(cache, slug, name, opener=...) -> str          # reads cache/slug/name, else fetches BASE_URL+slug+"/"+name, writes it, sleeps PAUSE_SECONDS
  def parse_index(html) -> dict   # {"title", "subtitle" (lead text or None), "front": {"title": <summary text>, "blocks": [...]} | None, "toc": [{"key": "3-2-1", "href": "3-2-1.html", "level": 1-4, "title": ...}, ...]}
  def parse_page(html, where) -> list[dict]   # blocks of <main class="page prose">; raises SyncError(f"{where}: unknown <tag class=...>") on anything outside the sets
  def build_book(slug, index, pages_html: dict[str, str], fetched: str) -> dict   # the book JSON (pages with n, key, level, title, url, blocks)
  def survey(cache) -> dict[tuple[str, str], tuple[int, str]]    # (tag, class) inside <main> across every cached page -> (count, first page path)
  def pack_bytes(data: bytes) -> bytes        # gzip.compress(data, 9, mtime=0)
  def sha256(data: bytes) -> str
  def write_bundle(project, books: list[dict], fetched) -> dict   # writes <slug>.json.gz and index.json; returns the index
  def check(project) -> list[str]             # problems, never raises on bad data; [] when fine
  def fetch_covers(project, opener=...) -> list[str]   # Task 2 fills COVERS; writes covers/<slug>.png after checking the PNG header; returns problems
  def main(argv=None) -> int
  ```
  Block shapes: `{"kind": "heading"|"subhead"|"para", "text": str}`, `{"kind": "gatha", "lines": [str, ...]}`, `{"kind": "list", "ordered": bool, "start": int, "items": [str, ...]}`. `p.subhead` → `subhead`; `div.gatha` → `gatha` (one line per child `<p>`, a `<br>` inside a `<p>` also splits; empty lines dropped); other `div` classes → `SyncError`. In a `para`, runs of whitespace collapse to one space and the text is stripped; a `<br>` becomes `\n`. A `<li>` holding a block element raises `SyncError`. An `<ol start="k">` keeps `k`, else `start` is 1. The page's own `div.page-title` is skipped (the TOC title is the page title); a page with no `main.page.prose` raises `SyncError`. The front matter is page 1 with `key: "front"`, `level: 1`, `url: <index url>`, only when its body has at least one block.

- [ ] **Step 1: Save the fixtures**

Copy real pages from the cache into `tools/test_data/pitaka_lk_books/`: `flat/` = `dharma-winishchaya` (index.html and 1.html); `nested/` = six pages of one nested book chosen so that the set has a parent page with its own text and children, a parent with no text, a `div.gatha`, an `<ol>` or `<ul>`, a `p.subhead` and an `h2`/`h3` (use `--survey` output from Step 5 to find them; `keles-1500` or `vinaya-karma` are candidates). Rename the nested book's files to the fixture names above only if their hrefs are rewritten to match; otherwise keep the real names and adjust the test. `README.md` records each file's source URL, the fetch date and "ධර්ම දානය පිණිස — no formal licence; text unchanged".

- [ ] **Step 2: Write the failing tests**

`tools/test_sync_books.py` (docstring and file-path import as `tools/test_sync_tipitaka.py`; `FIX = ROOT / "tools" / "test_data" / "pitaka_lk_books"`; no network — every `opener` is a fake that raises if called):
- `test_parse_index_flat`: 101 TOC rows, all level 1, keys `"1"`…`"101"`, titles non-empty, `front["title"]` is the summary text, `front["blocks"]` non-empty.
- `test_parse_index_nested_levels`: the nested index's rows carry the `data-level` values in document order; a row's `key` is its href without `.html`.
- `test_parse_page_kinds`: the fixture pages give exactly the expected block kinds in order (list them per fixture file); a `gatha` has its lines; a `list` has `ordered`, `start` and `items`; no item text starts with a number followed by `.` that the source does not contain.
- `test_parse_page_keeps_text`: for one paragraph, the block text equals the fixture's text with whitespace collapsed (compare against a literal taken from the fixture file).
- `test_parse_page_rejects_unknown`: a page with `<table>` inside `<main>` raises `SyncError` naming the tag; a page without `main.page.prose` raises.
- `test_build_book_reading_order`: `n` is 1..N, page 1 is `front`, the TOC pages follow in order with their levels; a parent with no text has `blocks == []`; `url` is `BASE_URL + slug + "/" + href`.
- `test_cached_page_does_not_fetch_when_present`: with a file in a temp cache, the fake opener is not called; when absent, it is called once with the `User-agent` header equal to `USER_AGENT` and the file is written.
- `test_pack_and_index`: `write_bundle` on a temp project writes `<slug>.json.gz` and `index.json`; `bytes`/`sha256` match the `.gz` file; `chapters` counts level-1 non-front pages; `pages` counts pages with blocks; `file` and `cover` paths as in the spec; gzip of the same input twice is byte-identical.
- `test_check_rules`: `check()` on the temp project is `[]`; then each of these makes it non-empty with a line naming the file: a missing `.gz`; a wrong `bytes`; an extra file under `assets/books/`; a page with no title; a page both without blocks and without children; `n` out of order; an unknown block kind; a text containing `<`; a level jump of two; a missing cover (when `covers/` exists for the others).
- `test_survey_counts`: over the fixture directory, `survey` reports `("p", "")`, `("div", "gatha")` and at least one of `("ol", "")`/`("ul", "")`, each with a first-page path.
- `test_main_requires_a_mode`: `main([str(tmp)])` returns 2 and prints the usage line (or `argparse` error) — pick one and assert it.

- [ ] **Step 3: Run them to see them fail**

Run: `python -I -X utf8 tools/test_sync_books.py`
Expected: FAIL (module not found).

- [ ] **Step 4: Implement `tools/sync_books.py`**

`html.parser.HTMLParser` subclass that tracks a stack of open tags, enters `main` only when its class holds `page` and `prose`, skips `SKIP_TAGS_IN_MAIN` subtrees and `div.page-title`, and turns each block element into a block. Modes: `--fetch` (indexes and pages via `cached_page`, then `build_book` for every slug, then `write_bundle`), `--survey` (prints a table `tag class count first-page`), `--check` (prints one problem per line and returns 1, else `OK`), `--covers` (Task 2). `main` uses `argparse` like `sync_tipitaka.py` and errors without a mode.

- [ ] **Step 5: Run the tests and the survey on the real cache**

Run: `python -I -X utf8 tools/test_sync_books.py` → OK.
Run: `python -I -X utf8 tools/sync_books.py . --survey` → the table. Every `(tag, class)` row must be in `BLOCK_TAGS`, `INLINE_TAGS`, `SKIP_TAGS_IN_MAIN`, `div.gatha`, `p.subhead`, `div.page-title`, `li`, or a wrapper the parser already skips. Any other row: if its text can be kept verbatim as one of the five kinds (for example `p` with another class, or `h5`), add the mapping to the tool with a comment naming an example page and a test; if it would need text dropped or changed (tables, images, footnotes), stop and report DONE_WITH_CONCERNS with the row and the example page.

- [ ] **Step 6: Commit**

```bash
git add tools/sync_books.py tools/test_sync_books.py tools/test_data/pitaka_lk_books
git commit -m "Books: sync tool for the pitaka.lk books"
```

---

### Task 2: The bundle, the covers and the asset checks

**Files:**
- Create: `assets/books/index.json`, `assets/books/<slug>.json.gz` × 23, `assets/books/covers/<slug>.png` × 23, `test/quality/books_assets_test.dart`
- Modify: `tools/sync_books.py` (`COVERS`), `pubspec.yaml` (assets), `tools/check_tipitaka_glyphs.py` (+ `tools/test_check_tipitaka_glyphs.py`), `.gitignore` (already holds `source_material/pitaka_lk_books/`; verify)

**Interfaces:**
- Consumes: Task 1's tool.
- Produces: the shipped bundle; `tools/check_tipitaka_glyphs.py` also reads `assets/books/index.json` (titles, subtitles) and every `assets/books/*.json.gz` (page titles, block `text`/`lines`/`items`).

- [ ] **Step 1: Fill `COVERS`**

Fetch `https://rerukanemahanahimi.lk/api/books` once (with `fetch_text`) into `source_material/pitaka_lk_books/_board_api_books.json`. Match each slug's pitaka.lk title to the Board's title by hand (spellings differ slightly between the sites); write `COVERS[slug] = (official_title, cover_url)` with the cover URL exactly as the API gives it (`/uploads/covers/cover_<n>.png` made absolute). List every pairing in your report; a slug you cannot match with confidence stays out of `COVERS` and goes in the report.

- [ ] **Step 2: Write the failing asset test**

`test/quality/books_assets_test.dart` (reads files from disk like `tipitaka_real_content_test.dart`; `timeout: Timeout(Duration(minutes: 5))`):
- `'the index lists the 23 books in order with matching files'`: `index.json` has `schema == 1`, 23 entries whose `id`s equal the slug list; every `file` exists with the listed `bytes` and the listed `sha256` (`package:crypto`); every `cover` exists and starts with the PNG signature.
- `'every page has a title and text or children, levels never jump'`: decode every book with `gunzipIfNeeded`; `n` is 1..N; page 1 is `front`; each level is 1 or at most one deeper than the previous page's; a page without blocks has at least one child; no text contains `<`, `&nbsp;` or ` `.
- `'nothing else is bundled under assets/books/'`: `AssetManifest.loadFromAssetBundle(rootBundle)` names under `assets/books/` are exactly `index.json`, the 23 `.json.gz` and the 23 covers (`t.runAsync`).

- [ ] **Step 3: Build the bundle**

Run: `python -I -X utf8 tools/sync_books.py . --fetch` (uses the cache; fetches only what is missing) → writes `assets/books/`.
Run: `python -I -X utf8 tools/sync_books.py . --covers` → 23 PNGs (a cover wider than 400 px is scaled to 400 wide with `PIL` only if available; otherwise kept as served — report which).
Run: `python -I -X utf8 tools/sync_books.py . --check` → `OK`.
Add to `pubspec.yaml` assets: `- assets/books/` and `- assets/books/covers/`.
Extend `tools/check_tipitaka_glyphs.py`: a generator `book_texts(root)` chained into `texts()`; a test in `tools/test_check_tipitaka_glyphs.py` that a made-up book file with a character no font has is reported with its file label. Run: `python -I -X utf8 tools/check_tipitaka_glyphs.py .` → `OK` (or only `substituted` lines; a missing character is a stop-and-report).

- [ ] **Step 4: Run the tests**

Run: `/c/Users/Dell/develop/flutter/bin/flutter test test/quality/books_assets_test.dart test/quality/web_manifest_test.dart` → PASS; `python -I -X utf8 tools/test_sync_books.py` and `tools/test_check_tipitaka_glyphs.py` → OK.
Record in your report: total bytes of `assets/books/` (gzipped) and the sum of unpacked sizes.

- [ ] **Step 5: Commit**

```bash
git add assets/books pubspec.yaml tools/sync_books.py tools/check_tipitaka_glyphs.py tools/test_check_tipitaka_glyphs.py test/quality/books_assets_test.dart
git commit -m "Books: the 23 books, their covers and the asset checks"
```

---

### Task 3: Model, repository, places and the test fixture

**Files:**
- Create: `lib/books/book_model.dart`, `lib/books/books_repository.dart`, `lib/books/book_places.dart`, `test/books/books_support.dart`, `test/books/book_model_test.dart`, `test/books/books_repository_test.dart`, `test/books/book_places_test.dart`
- Modify: `test/quality/quality_support.dart` (`openReal(..., AssetBytes? books)`)

**Interfaces:**
- Consumes: `AssetBytes`, `gunzipIfNeeded` from `lib/tipitaka/tipitaka_repository.dart`; `KeyValueStore`, `keyValueStoreProvider`, `SafeSave` from `lib/storage/key_value_store.dart`; `fakeAssets` from `test/tipitaka/tipitaka_support.dart`.
- Produces:
  ```dart
  // lib/books/book_model.dart
  class BookSummary { const BookSummary({required this.id, required this.title, this.subtitle, required this.chapters, required this.pages, required this.file, required this.cover}); static BookSummary parse(Object? json); }
  class BooksIndex { const BooksIndex({required this.books, required this.fetched}); final List<BookSummary> books; final String fetched; BookSummary? byId(String id); static BooksIndex parse(Object? json); }   // FormatException on bad shape
  sealed class BookBlock { const BookBlock(); static BookBlock parse(Object? json); }
  class BookHeading extends BookBlock { final String text; }
  class BookSubhead extends BookBlock { final String text; }
  class BookPara extends BookBlock { final String text; }
  class BookGatha extends BookBlock { final List<String> lines; }
  class BookList extends BookBlock { final bool ordered; final int start; final List<String> items; }
  class BookPage { const BookPage({required this.n, required this.key, required this.level, required this.title, required this.url, required this.blocks}); bool get hasText => blocks.isNotEmpty; }
  class Book {
    const Book({required this.id, required this.title, this.subtitle, required this.pages});
    BookPage? page(int n);                       // null when n < 1 or n > pages.length
    List<BookPage> get topLevel;                 // level == 1, front included
    List<BookPage> childrenOf(int n);            // following pages at level+1 until a page at <= level
    BookPage? parentOf(int n);                   // nearest earlier page at level-1; null at level 1
    List<BookPage> get readingPages;             // hasText, in n order
    int readingIndexOf(int n);                   // 1-based position among readingPages; 0 when not a reading page
    int? nextReading(int n);                     // first reading page with n' > n, else null
    int? previousReading(int n);                 // last reading page with n' < n, else null
    int? firstReadingFrom(int n);                // n itself when it is a reading page, else nextReading(n), else previousReading(n)
    static Book parse(Object? json);             // FormatException on bad shape
  }

  // lib/books/books_repository.dart
  const booksIndexAsset = 'assets/books/index.json';
  Book parseBookBytes((String, Uint8List) input);                 // top-level, for compute
  class BooksRepository {
    BooksRepository({AssetBytes? load, bool inBackground = true, int keepBooks = 2});
    Future<BooksIndex> index();                   // cached; a failed load is forgotten
    Future<Book> book(String assetPath);          // keeps the keepBooks most recent; a failed load is forgotten
  }
  final booksRepositoryProvider = Provider<BooksRepository>((ref) => BooksRepository());
  final booksIndexProvider = FutureProvider<BooksIndex>(..., retry: _noRetry);
  final bookProvider = FutureProvider.autoDispose.family<Book, String>((ref, id) async { ... index.byId(id) ?? throw StateError('no book $id') ... }, retry: _noRetry);

  // lib/books/book_places.dart
  const bookPlacesKey = 'namo.books.places.v1';   // JSON {"<id>": {"n": 3, "offset": 120.5}}
  class BookPlace { const BookPlace({required this.n, required this.offset}); final int n; final double offset; }
  class BookPlaces { const BookPlaces([this.byBook = const {}]); final Map<String, BookPlace> byBook; BookPlace? of(String id); Map<String, dynamic> toJson(); factory BookPlaces.fromJson(Object? json); }  // damaged entries dropped
  class BookPlacesController extends Notifier<BookPlaces> { BookPlaces build(); void remember(String id, {required int n, required double offset}); }   // ref.mounted guard; _set writes
  final bookPlacesProvider = NotifierProvider<BookPlacesController, BookPlaces>(BookPlacesController.new);

  // test/books/books_support.dart
  const tinyBookFlatId = 'tiny-flat';             // 3 pages: front, "1", "2" — all with text
  const tinyBookNestedId = 'tiny-nested';         // front; "1" (level 1, text, children "1-1" text with a gatha and an h2, "1-2" text with an ordered list);
                                                  // "2" (level 1, NO text, children "2-1" text, "2-1-1" level 3 text with a subhead and an unordered list)
  Map<String, Object> tinyBooks();                // {'assets/books/index.json': {...}, 'assets/books/tiny-flat.json.gz': {...}, 'assets/books/tiny-nested.json.gz': {...}}  (covers point at 'assets/branding/namo_icon_square.png')
  ```
  `openReal(..., AssetBytes? books)` adds `booksRepositoryProvider.overrideWithValue(BooksRepository(load: books ?? fakeAssets(tinyBooks()), inBackground: false))`. All text in the fixture is made-up ASCII, not Dhamma text.

- [ ] **Step 1: Write the failing tests**

- `test/books/book_model_test.dart`: `'parses the index and every block kind'`; `'the tree is derived from levels'` (on `tinyBooks()`'s nested book: `topLevel` is front, "1", "2"; `childrenOf("1")` is "1-1", "1-2"; `childrenOf("2-1")` is "2-1-1"; `parentOf("2-1-1")` is "2-1"); `'reading navigation skips pages without text'` (`readingPages` excludes "2"; `nextReading(n of "1-2")` is n of "2-1"; `previousReading(n of "2-1")` is n of "1-2"; `firstReadingFrom(n of "2")` is n of "2-1"; `readingIndexOf` counts only reading pages); `'bad shapes throw FormatException'` (pages not a list; a block with an unknown kind; `n` out of order).
- `test/books/books_repository_test.dart` (fake `AssetBytes` that records requested paths): `'index is read once and books only when asked'`; `'a book is parsed from gzip and plain bytes alike'`; `'a failed load is forgotten so the next call retries'` (first call throws, second succeeds); `'only the two most recent books are kept'`; `'bookProvider fails for an unknown id'`.
- `test/books/book_places_test.dart` (`ProviderContainer` with an in-memory store): `'remember saves and reads back'`; `'damaged entries are dropped alone'`; `'garbage gives the empty state'`.

- [ ] **Step 2: Run them to see them fail**

Run: `/c/Users/Dell/develop/flutter/bin/flutter test test/books`
Expected: compile errors.

- [ ] **Step 3: Implement the three files and the fixture**

Repository as `TipitakaRepository` (`_started` forgetting failures, `compute` when `inBackground`, no end-of-frame wait). `BookBlock.parse` switches on `kind`.

- [ ] **Step 4: Run the tests and the analyzer**

Run: `/c/Users/Dell/develop/flutter/bin/flutter test test/books test/quality/design_rules_test.dart` → PASS; `flutter analyze` → clean.

- [ ] **Step 5: Commit**

```bash
git add lib/books/book_model.dart lib/books/books_repository.dart lib/books/book_places.dart test/books test/quality/quality_support.dart
git commit -m "Books: model, repository, places and the test fixture"
```

---

### Task 4: Shelf, book page, contents list and search

**Files:**
- Create: `lib/books/books_part.dart`, `lib/books/book_widgets.dart`, `lib/books/book_screen.dart`, `lib/books/book_contents_screen.dart`, `lib/books/book_search.dart`, `test/books/books_part_test.dart`, `test/books/book_screen_test.dart`, `test/books/book_contents_screen_test.dart`, `test/books/book_search_test.dart`
- Modify: `lib/router.dart` (`Routes.book`, `Routes.bookContents`, `Routes.bookReader`; two child routes of the Library branch), `lib/library/library_screen.dart` (`BooksPart` after `MyFlowsPart`; `_Results(books:)`), `test/router_test.dart`, `test/library/library_search_test.dart`

**Interfaces:**
- Consumes: Task 3; `ListRow`, `Pressable`, `PrimaryButton`, `Overline`, `PageHeader`, `NamoIconButton`, `EmptyState`, `NotFoundScreen`, `NamoPage`, `namoPage`; `foldForSearch` from `lib/library/search.dart`.
- Produces:
  ```dart
  // lib/router.dart
  static String book(String id) => '/library/book/$id';
  static String bookContents(String id, int n) => '/library/book/$id/contents/$n';
  static String bookReader(String id, int n) => '/library/book/$id/read/$n';   // the route itself is Task 5

  // lib/books/book_widgets.dart
  class BookLoading extends StatelessWidget {}                                 // the 24 px spinner as LibraryGate's
  class BookLoadError extends ConsumerWidget { const BookLoadError({super.key, required this.onRetry}); }   // EmptyState 'The book could not be opened.' / 'Try again'
  class BookCover extends StatelessWidget { const BookCover({super.key, required this.asset, required this.title, this.width}); }   // AspectRatio 2/3, ClipRRect NamoRadius.sm, hairline border p.border, Image.asset(fit: cover, errorBuilder: placeholder = p.backgroundAlt box with the title's first character in NamoType.sectionTitleSinhala(p.gold))
  Widget bookChevron(BuildContext context);                                    // Symbols.chevron_right_rounded, iconSmall, weight 300, p.textSecondary
  class BookPageRow extends ConsumerWidget { const BookPageRow({super.key, required this.book, required this.page, this.own = false}); }
      // ListRow(key: own ? 'book-row-own-<n>' : 'book-row-<n>', title: page.title, titleFamily: NamoFonts.sinhala,
      //   trailing: children.isEmpty ? chevron : Row[Text('${children.length}', caption) , chevron],
      //   onTap: own || children.isEmpty ? go(Routes.bookReader(id, book.firstReadingFrom(n)!)) : go(Routes.bookContents(id, n)))

  // lib/books/books_part.dart
  class BooksPart extends ConsumerWidget { const BooksPart({super.key = const ValueKey('books-shelf')}); }
      // Column: Padding(h: lg, Overline('පොත්', header: true)), Text sub-line in NamoType.caption(p.textSecondary) with NamoFonts.sinhala, SizedBox(sm),
      // LayoutBuilder → columns = width >= 600 ? 4 : 3; a Wrap or GridView.count(shrinkWrap, NeverScrollableScrollPhysics) of cards;
      // card = Pressable(key: ValueKey('book-<id>'), semanticLabel: '<title>, book', excludeChildSemantics: true, onTap: go(Routes.book(id)),
      //   child: Column[BookCover, SizedBox(xs), Text(title, NamoType.readingTitle(p.text), maxLines: 2, ellipsis)])
      // loading → SizedBox.shrink(); error → the heading plus Text('The books could not be opened.', caption)

  // lib/books/book_screen.dart
  class BookScreen extends ConsumerStatefulWidget { const BookScreen({super.key, required this.id}); }
      // NamoPage; back button (go Routes.library); Center(BookCover width 160); title Semantics(header) NamoType.sectionTitleSinhala(p.text);
      // subtitle caption when present; Text('<chapters> chapters', caption); PrimaryButton(key: 'book-continue', label: continueLabel, onPressed);
      // Overline('Contents', header: true); for p in book.topLevel: BookPageRow; foot: Text('Text: pitaka.lk', caption), Text('Published by the Sri Chandawimala Dhamma Treatises Preservation Board', caption)
      // continueLabel: place != null && book.page(place.n)?.hasText == true ? 'Continue reading' : 'Start reading'; onPressed goes to that n, else book.firstReadingFrom(1)
      // unknown id → NotFoundScreen; loading → BookLoading; error → BookLoadError(onRetry: invalidate bookProvider(id))

  // lib/books/book_contents_screen.dart
  class BookContentsScreen extends ConsumerStatefulWidget { const BookContentsScreen({super.key, required this.id, required this.n}); }
      // the page n with children; header = page.title; rows: if page.hasText → BookPageRow(own: true) first; then childrenOf(n);
      // Back → parentOf(n) == null ? Routes.book(id) : Routes.bookContents(id, parent.n); n unknown or childless → NotFoundScreen

  // lib/books/book_search.dart
  List<BookSummary> searchBooks(List<BookSummary> books, String query);   // foldForSearch on title and subtitle; [] under searchMinLength
  ```
  `_Results` in `library_screen.dart` takes `books: List<BookSummary>` and, when non-empty, renders `Overline('Books', header: true)` then `ListRow(key: ValueKey('book-hit-<id>'), title:, titleFamily: NamoFonts.sinhala, subtitle: subtitle, trailing: chevron, onTap: go(Routes.book(id)))` before the section hits; the empty state needs both lists empty (its text stays `No results for “<query>”`).

- [ ] **Step 1: Write the failing tests**

- `test/books/books_part_test.dart` (`openReal(t, Routes.library)`): `'the shelf shows every book with its title'` (two cards, keys `book-tiny-flat`, `book-tiny-nested`, semantics label `'<title>, book'`); `'a tap opens the book page'` (location `/library/book/tiny-flat`); `'a cover that fails to load shows the placeholder'` (fixture index with a cover path that does not exist; the first character is shown; `t.takeException()` null); `'the Library tab stays selected on the book page'`.
- `test/books/book_screen_test.dart`: `'shows cover, title, chapter count, Start reading and the contents'`; `'Continue reading when a place is saved'` (`storeExtras: {bookPlacesKey: '{"tiny-nested": {"n": 3, "offset": 0}}'}`; tap → location `/library/book/tiny-nested/read/3`); `'a saved place past the end reads as Start reading'` (`n: 99`); `'a row with children opens the contents list; a leaf opens the reader'`; `'Back goes to the Library'`; `'an unknown id shows Not found'`; `'a book that cannot be opened shows Try again'` (an `AssetBytes` that throws for the book file; after the tap, with the fake fixed, the book shows).
- `test/books/book_contents_screen_test.dart`: `'lists the page's own text first when it has text, then its children'` ("1": own row then "1-1", "1-2"); `'a parent without text has no own row'` ("2"); `'Back goes to the parent list or the book page'`; `'a childless n shows Not found'`.
- `test/books/book_search_test.dart`: `searchBooks` matches a title and a subtitle, folds case and ignores U+200D, returns `[]` for one character; and in `test/library/library_search_test.dart`: `'a book title shows under Books and opens the book page'`, `'no results needs both lists empty'`.
- `test/router_test.dart`: the three new paths resolve (`/library/book/x` → `BookScreen`, `/library/book/x/contents/2` → `BookContentsScreen`).

- [ ] **Step 2: Run them to see them fail**

Run: `/c/Users/Dell/develop/flutter/bin/flutter test test/books test/library/library_search_test.dart test/router_test.dart`
Expected: compile errors.

- [ ] **Step 3: Implement the screens, the routes and the search group**

Branch-child routes with `pageBuilder: namoPage(...)` as the `flow/:id` route; `n` parsed with `int.tryParse` (bad → `NotFoundScreen`). The `Routes.bookReader` route is Task 5; this task's navigations to it are asserted on the router location only.

- [ ] **Step 4: Run the tests, the design rules, the glyph check and the analyzer**

Run: `/c/Users/Dell/develop/flutter/bin/flutter test test/books test/library test/router_test.dart test/quality/design_rules_test.dart` → PASS; `flutter analyze` → clean; `python -I -X utf8 tools/check_ui_glyphs.py .` → exit 0.

- [ ] **Step 5: Commit**

```bash
git add lib/books/books_part.dart lib/books/book_widgets.dart lib/books/book_screen.dart lib/books/book_contents_screen.dart lib/books/book_search.dart lib/router.dart lib/library/library_screen.dart test/books test/library/library_search_test.dart test/router_test.dart
git commit -m "Books: shelf, book page, contents list and search"
```

---

### Task 5: The reader

**Files:**
- Create: `lib/books/book_reader_screen.dart`, `test/books/book_reader_screen_test.dart`
- Modify: `lib/router.dart` (top-level route `/library/book/:id/read/:n`), `test/quality/design_rules_test.dart` (allow-list entry), `test/router_test.dart`

**Interfaces:**
- Consumes: Tasks 3–4; `showReaderSettingsSheet(context, onBackToBeginning:, textOnly: true)` from `lib/reader/reader_settings_sheet.dart`; `settingsProvider`; `readingStyle`; `FloatingBar`, `NamoIconButton`.
- Produces:
  ```dart
  class BookReaderScreen extends ConsumerStatefulWidget {
    const BookReaderScreen({super.key, required this.id, required this.n});   // the route keys it ValueKey('book-reader-$id-$n')
  }
  // Route: GoRoute(path: '/library/book/:id/read/:n', pageBuilder: namoPage(... BookReaderScreen(key: ValueKey('book-reader-$id-$n'), id:, n:)))
  // Frame: PopScope(canPop: false) > Scaffold(backgroundColor: p.background, body: Column[_TopBar (key 'book-reader-top-bar': Back, book title one line NamoType.label(p.textSecondary), settings NamoIconButton tooltip 'Reading settings'),
  //   Expanded(SafeArea(top: false, SingleChildScrollView(controller: _scroll, padding: pageMargin + bottom clearance, child: Center(ConstrainedBox(maxWidth: NamoSizes.readingColumn, child: Column[
  //     Semantics(header: true, Text(page.title, NamoType.sectionTitleSinhala(p.text))), SizedBox(lg), ...blocks separated by SizedBox(md)])))))],
  //   bottomNavigationBar: SafeArea(Padding(all lg, FloatingBar(child: Row[NamoIconButton(key: 'book-prev', Symbols.chevron_left_rounded, 'Previous page', onPressed: prev == null ? null : go), Expanded(Center(Text('$i / $total', NamoType.caption(p.textSecondary)))), NamoIconButton(key: 'book-next', Symbols.chevron_right_rounded, 'Next page', ...)]))))
  // Blocks: BookPara → Text(text, prose) where prose = readingStyle(ReadingLanguage.sinhala, fontScale:, lineSpacing:, color: p.text);
  //   BookHeading → Text(text, prose.copyWith(fontSize: prose.fontSize! * 1.25, fontWeight: FontWeight.w600)); BookSubhead → prose.copyWith(fontWeight: FontWeight.w600);
  //   BookGatha → Padding(start: NamoSpace.xl, Column[for line: Text(line, prose)]); BookList → Column[for (i, item): Row(crossAxisAlignment: start, [SizedBox(width: NamoSpace.xxl, child: Text(ordered ? '${start + i}.' : '•', prose)), Expanded(Text(item, prose))])]
  // Place: const _saveDelay = Duration(milliseconds: 400) (allow-listed); on ScrollNotification → debounce → _places.remember(id, n:, offset: _scroll.offset);
  //   after the first frame: remember(id, n:, offset: 0) unless the saved place is this n, in which case jumpTo(offset.clamp(0, maxScrollExtent)); dispose hands the last place over post-frame.
  // Non-reading n: post-frame context.go(Routes.bookReader(id, book.firstReadingFrom(n)!)) or, when the book has no reading page, Routes.book(id). Unknown id → NotFoundScreen; loading → BookLoading; error → BookLoadError.
  // Back → parentOf(n) == null ? Routes.book(id) : Routes.bookContents(id, parent.n). Prev/Next → go(Routes.bookReader(id, m)); the new key restarts the screen at the top.
  // Screen not kept awake.
  ```

- [ ] **Step 1: Write the failing tests**

`test/books/book_reader_screen_test.dart` (`openReal(t, Routes.bookReader(tinyBookNestedId, n), ...)`):
- `'renders every block kind in order'` (page "2-1-1": subhead, para, unordered list with bullets; page "1-1": gatha lines and the h2 heading; page "1-2": ordered list shows `1.`, `2.` as separate texts while the item texts contain no numbers).
- `'the counter and the buttons step through reading pages only'` (from "1-2": Next goes to "2-1", not "2"; `'<i> / <total>'` counts reading pages; at the last reading page Next is disabled; at the first, Previous is disabled).
- `'a non-reading n redirects to the next reading page'` (open n of "2" → location `/library/book/tiny-nested/read/<n of 2-1>`).
- `'an n past the end goes to the book page'`.
- `'the place is saved on open and after scrolling, and restored'` (open; store holds `{"tiny-nested": {"n": .., "offset": 0}}`; a long page fixture or a small viewport; drag; `pump(500 ms)`; offset > 0 saved; reopen the same route → `_scroll.offset` equals the saved offset).
- `'Back goes to the parent contents list'` and `'...to the book page for a top-level page'`.
- `'text size and line spacing follow Settings'` (`settings: AppSettings(fontScale: 1.4)` → the para's style fontSize is 18 × 1.4).
- `'a book that cannot be opened shows Try again'`.
- `test/router_test.dart`: `/library/book/x/read/3` resolves to `BookReaderScreen` outside the shell (no tab bar).

- [ ] **Step 2: Run them to see them fail**

Run: `/c/Users/Dell/develop/flutter/bin/flutter test test/books/book_reader_screen_test.dart`
Expected: compile errors.

- [ ] **Step 3: Implement the reader and the route; allow-list the debounce**

Add to `allowed` in `test/quality/design_rules_test.dart`: `'lib/books/book_reader_screen.dart': 'the place-save debounce (400 ms) while scrolling; not drawn'`.

- [ ] **Step 4: Run the full suite, the analyzer and the glyph check**

Run: `/c/Users/Dell/develop/flutter/bin/flutter test` → all pass; `flutter analyze` → clean; `python -I -X utf8 tools/check_ui_glyphs.py .` → exit 0.

- [ ] **Step 5: Commit**

```bash
git add lib/books/book_reader_screen.dart lib/router.dart test/books/book_reader_screen_test.dart test/router_test.dart test/quality/design_rules_test.dart
git commit -m "Books: the reader"
```

---

### Task 6: Sources, docs, quality matrices and the size

**Files:**
- Modify: `lib/settings/sources_screen.dart` (`_BooksCreditBlock`, the "not connected" sentence), `README.md` (Sources, a "Books" section, Commands, Docs), `docs/release-checklist.md`, `docs/pictures.md`, `test/settings/sources_screen_test.dart`, `test/quality/overflow_test.dart`, `test/quality/accessibility_test.dart`

**Interfaces:**
- Consumes: Tasks 2–5.
- Produces: `_BooksCreditBlock` (key `sources-books`) after `_TipitakaCreditBlock`, sentences: "The books of Ven. Rerukane Chandawimala Maha Nahimi are the Unicode text published by pitaka.lk (pathnirvana) and are included unchanged.", "The books and their covers are published by the Sri Chandawimala Dhamma Treatises Preservation Board, Pokunuwita (rerukanemahanahimi.lk).", "Namo is not connected with pitaka.lk or the Board.", "If you find an error in a book, please report it to the publisher or to pitaka.lk so it can be corrected at the source."; the "not made by" sentence becomes "Namo is not made by, or connected with, namo.lk, pitaka.lk, Shanthi Vihara or the Sri Chandawimala Dhamma Treatises Preservation Board." in both `sources_screen.dart` and README.

- [ ] **Step 1: Write the failing tests**

- `test/settings/sources_screen_test.dart`: `'credits the books and the Board'` (key `sources-books`, the four sentences, the amended "not made by" sentence).
- `test/quality/overflow_test.dart`: a `booksScreens` list in the Tripitaka block's style — `('Books shelf', Routes.library, {})`, `('Book page', Routes.book(tinyBookNestedId), {})`, `('Book page with a place', Routes.book(tinyBookNestedId), {bookPlacesKey: '{"tiny-nested": {"n": 3, "offset": 0}}'})`, `('Book contents', Routes.bookContents(tinyBookNestedId, <n of "1">), {})`, `('Book reader (gatha)', Routes.bookReader(tinyBookNestedId, <n of "1-1">), {})`, `('Book reader (list)', Routes.bookReader(tinyBookNestedId, <n of "2-1-1">), {})` at 320×568 and 1280×800, text 1.0 and 2.0, light and dark; the fixture's nested book gets one title of 60 Sinhala-length ASCII characters so the two-line ellipsis is exercised.
- `test/quality/accessibility_test.dart`: the same six screens in the Tripitaka block's style (`Size(390, 1400)`, light and dark).

- [ ] **Step 2: Run them to see them fail**

Run: `/c/Users/Dell/develop/flutter/bin/flutter test test/settings/sources_screen_test.dart` → FAIL (sentences missing). The matrices may already pass; run them anyway and note the result.

- [ ] **Step 3: Implement the credit, the docs and the checklist**

README: a "Books" section modelled on "Tripitaka" (where it comes from, no formal licence and the terms kept, the cache, `--fetch`, `--survey`, `--check`, `--covers`, the glyph check, the tool tests, "The text is never edited here"); "Sources" bullet; "Commands" gains `python -I -X utf8 tools/sync_books.py . --check` and `python -I -X utf8 tools/test_sync_books.py`. `docs/release-checklist.md` gains: `- [ ] Books (text from pitaka.lk, covers from rerukanemahanahimi.lk): do not publish the app or push the repository to a public place until the owner confirms permission from the Sri Chandawimala Dhamma Treatises Preservation Board (books and covers) and from pathnirvana (the digitised text); then add "used with permission" to the Sources entry.` and an owner-checks entry (run `--check` and the glyph check before a release; open three books on a phone including a nested one; Continue reading restores the place; covers look right in dark and light; confirm the wording on the Sources page). `docs/pictures.md` gains a "Book covers" table (file, pixels, bytes, SHA-1, source URL, "published by the Board; permission pending") — print it with a small Python one-off, do not hand-type hashes.

- [ ] **Step 4: Run everything and measure**

Run: `/c/Users/Dell/develop/flutter/bin/flutter test` → all pass; `flutter analyze` → clean; `python -I -X utf8 tools/sync_books.py . --check` → `OK`; `python -I -X utf8 tools/check_tipitaka_glyphs.py .` and `tools/check_ui_glyphs.py .` → exit 0; `python -I -X utf8 tools/test_sync_books.py` → OK.
Run: `/c/Users/Dell/develop/flutter/bin/flutter build apk --split-per-abi` and record `app-arm64-v8a-release.apk`'s size in bytes against 53,975,660; record `assets/books/` gzipped total and unpacked total from Task 2. Put all three figures in your report and in the README "Books" section's size line.

- [ ] **Step 5: Commit**

```bash
git add lib/settings/sources_screen.dart README.md docs/release-checklist.md docs/pictures.md test/settings/sources_screen_test.dart test/quality/overflow_test.dart test/quality/accessibility_test.dart
git commit -m "Books: credits, docs, checklist and quality matrices"
```
