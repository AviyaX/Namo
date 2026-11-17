# Books: Ven. Rerukane Chandawimala Maha Nahimi's books — design

Date: 2026-11-17. Status: the owner asked for the book set on 2026-11-17 and
decided: all 23 books, bundled in the app ("inbuilt"), in a Library section
"Books – Rerukane Chandawimala Himi books", each with its cover image, the
covers taken from rerukanemahanahimi.lk/library.html (the owner, 2026-11-17).
The rest is the designer's. Builder check done the same day; its four
findings (the books are trees, the front matter, more block kinds, gzip) are
folded in below as the designer's calls.

## Intent

A person opens the Library, sees a shelf of the Thero's books with their
covers, taps one, sees its contents and where they left off, and reads it in
the app's own reader with the app's fonts, sizes and colours, offline.

## Sources (checked 2026-11-17)

- **Text:** pitaka.lk/books (pathnirvana — the same project as the app's
  pirith) carries 23 of the Thero's books as Unicode Sinhala HTML. Each
  book has an index page `https://pitaka.lk/books/<slug>/index.html` with a
  `book-head` (title and a `lead` sub-line), a `<details
  class="front-matter">` block (the foreword or publisher's notes, as
  paragraphs, sometimes a `div.gatha`), and a table of contents whose rows
  carry `data-level` 1–4 and link to one page per entry (`N.html` for a flat
  book, `3-2-1.html` for nested ones). Only ධර්ම විනිශ්චය is flat (101
  pages); the other 22 are two to four levels deep, about 2,900 pages in
  all (පට්ඨාන සන්නය: 13 top-level entries, 324 pages). A page holds `<main
  class="page prose">` with a `<div class="page-title"><h1>`, then
  paragraphs, `div.gatha` verse blocks (one `<p>` per line), `p.subhead`,
  `<ol>`/`<ul>` lists, `<b>`/`<em>` emphasis, and on a parent page a `<nav
  class="subheadings toc">` of its children. Some parent pages have text of
  their own before their children; some have none. The page invites
  sharing "ධර්ම දානය පිණිස" and names the publisher, ශ්‍රී චන්දවිමල
  ධර්මපුස්තක සංරක්ෂණ මණ්ඩලය (Sri Chandawimala Dhamma Treatises Preservation
  Board, Pokunuwita). No formal licence; the same terms the app already
  keeps for tipitaka.lk apply: text unchanged, source credited, errors
  reported to the source, a sync tool kept in the repository.
- **Covers:** the Board's own site, rerukanemahanahimi.lk (library.html,
  fed by `/api/books`), serves a cover per book (`/uploads/covers/
  cover_*.png`, about 380 × 567 px, 20–50 KB). Its PDFs are scans without
  text and are not used.
- **Size:** ධර්ම විනිශ්චය (240 printed pages) is 0.83 MB of text; the 23
  books total about 6,200 printed pages, so about 21 MB of JSON before
  compression, about 1 MB of covers. Bundled, as the owner chose; gzipped
  like the Tripitaka, which brings the bundle to a few MB. Measured after
  the build; if the arm64 package grows by more than 12 MB the
  hosted-download route (as for recordings) is the fallback to propose.
- **Permissions to ask before publishing:** the Board (the books and the
  covers) and pathnirvana (the digitised text). Release-checklist lines as
  for the other sources.

The 23 slugs, in pitaka.lk's order: bauddhayage-athpotha,
dharma-winishchaya, paramitha-prakaranaya, suvisi-gunaya,
abhidharmaye-mulika-karunu, abhidharma-margaya, chathurarya-sathya,
punyopadeshaya, shasanavatharanaya, bodhi-pakshika-dharma,
patichcha-samuppada-vivaranaya, upasampada-sheelaya, ubhaya-prathimokshaya,
wanchaka-dharma, vidarshana-bhavana-kramaya, keles-1500, pohoya-dinaya,
bodhi-poojawa, chaththalisakara-vipassana, vinaya-karma,
sathipttana-bhavana-kramaya, nirvana-vinishchaya, pattana-pakarana-sannaya.

## Goals

- All 23 books readable offline, page by page in the book's own order, text
  exactly as pitaka.lk publishes it, front matter included.
- A shelf in the Library with covers and Sinhala titles; a book page with
  the cover, the contents and "Continue reading"; nested contents open as
  lists the way the Tripitaka's do; a reader that remembers the place per
  book.
- Reading uses the app's Sinhala reading style, text size and line spacing
  from Settings, dark and light themes; previous/next at the foot walk the
  whole book in reading order.
- Library search finds books by title.
- Android, iOS and web from one code base; the whole check list keeps
  passing (overflow at 320 px / 2.0×, accessibility, design rules, glyphs).

## Non-goals

- The other 25 books on pitaka.lk, the English translations, or the scanned
  PDFs.
- Audio, bookmarks inside books, highlighting, search inside a book's text,
  Today picks from books, Home cards for books (a later step).
- Keeping inline emphasis (`<b>`, `<em>`) — the characters are kept, the
  styling is not, in this version.
- Downloading books on demand (bundled by the owner's choice; the fallback
  is noted above).

## Anti-goals

- Changing a single character of the text; presenting the books as the
  app's own; showing a cover without the Board's credit.
- Loading all 23 books into memory at start-up.

## Constraints

- Content reaches the app only through `tools/`: a sync tool writes the
  book files; `--check` validates them; the JSON is never hand-edited.
- Design rules, `NamoType`/`readingStyle`, no Material default widgets.
- Riverpod 3; go_router routes under the Library branch so the shelf, book
  page and contents lists keep the tab bar context as the Tripitaka screens
  do (the reader itself is a full-screen route like `/read/:id`).
- The library gate pattern (`LibraryGate`) for loading states.

## Approaches considered

1. **Bundle the text (chosen).** Simple offline story; a few MB more in the
   package once gzipped; parsed lazily per book.
2. **Host on R2 and download like recordings.** Smallest install; needs the
   store's machinery for text (verified files, "not downloaded" states);
   kept as the fallback if the size measured in 1 is too much.
3. **Open pitaka.lk in a web view.** No offline reading, no app fonts;
   rejected.

For the reader: reuse the Tripitaka reader (built for Pali/Sinhala columns
and node trees) was considered and rejected; a small prose reader is
simpler and fits the books' shape (headings, paragraphs, verse blocks,
lists).

For the nested books, three ways to show the contents were weighed: one
flat list of every page indented by level (over 300 rows for the largest
book); a drill-down like the Tripitaka's list screens (chosen — the pattern
exists, each list stays short, and the reader walks the pages linearly
anyway); or only the top-level entries with everything below joined into
one long chapter (loses the way the printed book is organised).

## How it works

### Content files

- `assets/books/index.json`: `{"schema": 1, "author": {"si": "රේරුකානේ චන්දවිමල මහා නාහිමි", "en": "Ven. Rerukane Chandawimala Maha Nahimi"}, "publisher": {"si": "ශ්‍රී චන්දවිමල ධර්මපුස්තක සංරක්ෂණ මණ්ඩලය", "en": "Sri Chandawimala Dhamma Treatises Preservation Board"}, "source": {"name": "pitaka.lk", "url": "https://pitaka.lk/books/", "fetched": "2026-11-17"}, "books": [{"id": "<slug>", "title": "<Sinhala title from the index page>", "subtitle": "<the lead sub-line, or null>", "chapters": <count of level-1 entries, front matter excluded>, "pages": <count of reading pages>, "file": "assets/books/<slug>.json.gz", "bytes": <size of the .gz file>, "sha256": "<of the .gz file>", "cover": "assets/books/covers/<slug>.png", "cover_source": "https://rerukanemahanahimi.lk/uploads/covers/cover_<n>.png"}]}`.
- `assets/books/<slug>.json.gz`: gzip of `{"id", "title", "subtitle", "source": {"url": "https://pitaka.lk/books/<slug>/index.html", "fetched"}, "pages": [{"n": 1, "key": "front" | "3-2-1", "level": 1, "title": "<from the index page's TOC, or the front matter's summary>", "url": ".../3-2-1.html", "blocks": [...]}]}`.
  - `pages` is flat, in reading order: the front matter first (`key:
    "front"`, `level: 1`, title from the `<summary>`), then the TOC's rows
    in document order (depth first). `n` is 1-based in that order. The
    contents tree is derived: a page's children are the pages that follow
    it with `level` one deeper, up to the next page at its own level or
    shallower.
  - A **reading page** is a page with at least one block. A parent page
    with no text of its own has `blocks: []` and is a contents node only.
  - Block kinds: `heading` (`h2`/`h3` inside the main text; the page's own
    `<h1>` is the page title and is not repeated), `subhead` (`p.subhead`),
    `para` (`<p>`; whitespace collapsed to single spaces; inline tags
    flattened to their text), `gatha` (`div.gatha`; `lines: [...]`, one per
    child `<p>` or per `<br>`-separated run), `list` (`<ol>`/`<ul>`;
    `ordered: true|false`, `items: [...]`; item numbers are **not** written
    into the text — the reader draws them, as the browser does). Any other
    element inside the main text fails the fetch loudly; the builder adds a
    kind only after seeing the structure in the survey (below) and records
    the tag, an example page and the mapping in the tool's `KINDS` table.
- `assets/books/covers/<slug>.png`: the Board's cover as served, re-encoded
  only if larger than 400 px wide (then scaled to 400 wide); never cropped
  or recoloured.

### Tool: `tools/sync_books.py`

Usage: `python -I -X utf8 tools/sync_books.py <root> [--fetch | --survey | --check | --covers]`.

- `--fetch`: for each slug, download the index page, read its TOC (rows with
  `data-level` and hrefs) and the front matter, download every linked page
  into `source_material/pitaka_lk_books/<slug>/` (untracked cache; polite
  200 ms between requests; User-Agent `namo-app-build/1.0`; a page already
  in the cache is not fetched again), parse them into the book JSON, gzip
  it, and rewrite `index.json` with counts, sizes and hashes. The parser is
  a small `html.parser` subclass that collects `<main class="page prose">`
  only, skips `nav.pager`, `nav.subheadings`, the settings dialog and the
  page-title block, maps the block kinds above, and fails loudly on an
  unknown structure. A page with no `main.page.prose` fails the fetch.
- `--survey`: over the cache, counts every tag/class pair found inside the
  main text across all pages and prints the table with one example page per
  pair. The first build task runs it; the `KINDS` table is made from it.
- `--covers`: download the 23 covers by a hand-kept map slug → official
  cover URL (from `/api/books`; the map lives in the tool with the official
  title beside each entry), check the PNG header, write
  `assets/books/covers/<slug>.png`.
- `--check` (offline; joins the project's check list): `index.json` lists
  exactly the 23 slugs; every `.gz` exists with the listed `bytes` and
  `sha256` and unpacks to valid JSON; every page has a title and either
  blocks or children (no page is both empty and childless); the front
  matter is page 1; `n` is 1..N in order; every block kind is known; no
  text contains `<`, `&nbsp;`-style leftovers or a leading list number
  that the source does not have; every cover exists and is a PNG; nothing
  else is under `assets/books/`.
- Tests in `tools/test_sync_books.py` on fixture HTML
  (`tools/test_data/pitaka_lk_books/`: one nested index with front matter
  and a four-level TOC, one flat index, chapter pages covering every block
  kind including a parent with text and a parent without, saved from the
  real site): TOC and front-matter parsing, reading order and `n`, block
  mapping, the failure on unknown structure, gzip round trip, the `--check`
  rules, no network.
- `tools/check_tipitaka_glyphs.py` gains the book files (or a sibling check)
  so every character in the books is in the bundled Sinhala font.

### App: `lib/books/`

- `book_model.dart`: `BookSummary` (id, title, subtitle, chapters, pages,
  file, cover, sources), `Book` (id, title, subtitle, pages:
  `List<BookPage>`; `childrenOf(n)`, `topLevel`, `readingPages`,
  `nextReading(n)`, `previousReading(n)`), `BookPage` (n, key, level, title,
  blocks: `List<BookBlock>`; `hasText`), `BookBlock` (kind, text, lines,
  items, ordered).
- `books_repository.dart`: `booksIndexProvider = FutureProvider<BooksIndex>`
  (reads `index.json` once); `bookProvider =
  FutureProvider.family<Book, String>` (reads one `.json.gz` when opened;
  unpacked and parsed in `compute`, as the Tripitaka repository does).
- `book_places.dart`: `BookPlace(n, offset)` per book id under
  `namo.books.places.v1` (controller like `SavedController`); updated as the
  reader scrolls (debounced through the existing position pattern) and on
  leaving.
- Screens:
  - **Shelf** (`books_part.dart`, inside the Library page after My flows and
    before the topic rows): `Overline('පොත්', header: true)` — the owner's
    section name rendered as a heading "Books" with the sub-line
    "රේරුකානේ චන්දවිමල හිමියන්ගේ පොත්"; a grid of cover cards (3 per row from
    320 px, 4 from 600, 6 on wide), each `Pressable` with the cover
    (`Image.asset`, `BoxFit.cover`, rounded `NamoRadius.sm`, a hairline
    border) and the title in `NamoType.readingTitle` below, two lines max
    with ellipsis; semantic label "<title>, book". Keys `books-shelf`,
    `book-<slug>`.
  - **Book page** (`book_screen.dart`, route `/library/book/:id`): cover
    (max 160 px wide), title, subtitle in caption when present, "<n>
    chapters", a `PrimaryButton` "Continue reading" (or "Start reading")
    that opens the saved page (or page 1); then the contents: the front
    matter row, then the level-1 pages as `ListRow`s with the title; a row
    whose page has children shows a chevron and opens the contents list for
    it; a row whose page has no children opens the reader. The credit line
    at the foot: "Text: pitaka.lk · Published by the Sri Chandawimala Dhamma
    Treatises Preservation Board" (two short lines in `NamoType.caption`).
  - **Contents list** (`book_contents_screen.dart`, route
    `/library/book/:id/contents/:n`, in the Library branch like the
    Tripitaka's list screens): top bar with the parent page's title; if
    that page has text of its own, a first row with the same title that
    opens the reader at it; then its children with the same row rules as
    the book page (chevron and drill down, or open the reader). Keys
    `book-row-<n>`.
  - **Book reader** (`book_reader_screen.dart`, route
    `/library/book/:id/:n`, full-screen like the reader; `n` must be a
    reading page, otherwise it redirects to the next reading page): top bar
    with Back, the book title (one line) and the page's title under it;
    body: the page title in `NamoType.sectionTitleSinhala`, `heading`
    blocks at the section size, `subhead` at the label size, `para` in the
    Sinhala `readingStyle` with the Settings text size and line spacing,
    `gatha` indented by `NamoSpace.xl` and kept line by line, `list` with
    the number or a bullet drawn in a fixed-width lead and the item text
    beside it; a bottom `FloatingBar` with Previous · "<i> / <total reading
    pages>" · Next (keys `book-prev`, `book-next`), stepping through reading
    pages only; the saved place restores the scroll offset. The screen is
    not kept awake (reading, not chanting).
- Library search: `search.dart` also matches book titles and opens the book
  page; results group "Books".
- Sources page: a new credit block for the books (text: pitaka.lk; books
  and covers: the Board; "Namo is not connected with either"); README
  "Sources" and "Commands" gain the tool; release checklist gains the two
  permission lines and owner checks (open three books on a phone including
  a nested one, continue reading restores the place, covers look right in
  dark and light).

### Tests

- Tool tests as above; `--check` in the check list.
- Dart: model parsing and the derived tree (`childrenOf`, reading-page
  navigation skipping empty parents); repository loads lazily (index only
  at start — a test asserts no `.gz` is read on Home); places round trip;
  shelf (23 covers, titles, tap opens the book page), book page (chapter
  count, Continue label states, chevron rows, credit), contents list (own
  text row shown only when the parent has text), reader (blocks of every
  kind rendered in order, list numbers drawn not in the text, prev/next at
  the ends disabled, empty parents skipped, place saved on scroll and
  restored, a non-reading `n` redirects), search finds a book; overflow
  matrix (shelf at 320×568 2.0×, book page, contents list, reader with a
  `gatha` and a `list` page) and accessibility guidelines; design rules;
  glyph check over the books.

### Size, for the record

Measured in the final task: package sizes before and after; `assets/books/`
total, gzipped and unpacked.

## Left to the builder

- The grid card's exact proportions and the cover placeholder when an
  image fails to load (a tinted rectangle with the first letter).
- The debounce used for saving the place (reuse the reader's position
  controller pattern).
- The `KINDS` table after the survey, within the kinds named above; a new
  kind only for a structure the survey shows, never a change to the text.

## Open with the owner (defaults taken)

- Section title and sub-line wording ("පොත්" / "රේරුකානේ චන්දවිමල හිමියන්ගේ පොත්").
- Covers are the Board's images from rerukanemahanahimi.lk/library.html, as
  the owner asked, credited; if the Board prefers otherwise, the placeholder
  card is the fallback.
- Nested books open as drill-down lists (the Tripitaka's pattern) rather
  than one long indented list — the designer's call.
- The front matter (foreword) is included as the book's first page — the
  designer's call, from "text exactly as published".
- Bundled as asked; the hosted fallback only if the measured growth is
  larger than 12 MB on arm64.
