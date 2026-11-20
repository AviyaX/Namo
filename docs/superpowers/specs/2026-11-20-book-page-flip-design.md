# Book page flipping — design

Date: 2026-11-20. Owner: Avishka Induwara. Status: draft for the owner's approval.

## Why

The owner wants the Rerukane books (Library → Books) to feel like a real
book: text on fixed, screen-sized pages, turned by dragging a page corner
that curls under the finger, the way an EPUB reader feels. Today each book
"page" is one web page from the source site (some several screens long),
read by scrolling, with previous/next buttons at the bottom.

## Goals

- A **Pages** way of reading books: each source page is cut into
  screen-sized pages that fit the current text size, line spacing, screen
  size and orientation.
- Turning is a **page curl drawn by the app** that follows the finger: drag
  from the right edge to turn forward, from the left edge to turn back.
  Let go past half-way and the turn completes; before, the page falls back.
- **Arrow buttons at the bottom** turn the page with the same curl.
- Readers **pick Pages or Scroll** in the book reader's settings sheet.
  The choice is saved once for all books.
- Pages **flow across chapters**: turning past the last page of a source
  page opens the first page of the next reading page; turning back from the
  first page opens the last page of the previous one.
- A **page counter** within the current source page, e.g. "12 of 40"
  (a short sub-page may show "1 of 1"). *Builder's call, confirmed in the
  design: counting a whole top-level chapter would need all its sub-pages
  cut first.*
- **Place kept by position in the text, not page number**, so a different
  text size, phone or orientation reopens at the same passage.
- Android, iPhone and web stay in step (owner's standing rule).

## Non-goals

- No EPUB (or any other) export or file sharing. The books stay bundled and
  are read only inside Namo (permissions from the Board are still to be
  asked).
- The chants, pirith, Samantha Pattana and Tripitaka readers keep
  scrolling. Their recordings and auto-scroll follow the text line by line.
- No two-page spread on wide screens in this round (one page, centred in
  the existing reading column).

On wide screens (web, tablets) the page is drawn as a paper sheet in the
reading column, with its own soft shadow and a surface colour token, and
the drag and tap edges are the sheet's edges, not the window's. On phones
the sheet fills the width and its edges are the screen's. *My call: a curl
needs a visible edge to lift.*
- No change to the book texts, the contents screen or the shelf.

## Anti-goals (failure even if it "works")

- Losing the reader's place when the text size changes or the app reopens.
- A line, verse or footnote cut off, hidden or shown twice at a page break.
- A curl that stutters on a mid-range Android phone or on the web.
- Pages that a screen-reader or keyboard user cannot turn.
- Ignoring the phone's "remove animations" setting.

## Approaches considered

1. **Ready-made curl package** (`turn_page_transition`, BSD-3, all three
   platforms, last release 2025-08-06). Quickest, but one maintainer and no
   control over screen readers, keyboard or reduced motion.
2. **Draw our own curl** — chosen by the owner. The app paints the lifted
   corner, the paper's back and the shadow from page snapshots. More work,
   but it meets Namo's own tests (48-point touch targets, semantics,
   reduced motion) and has no outside dependency.
3. **GPU shader curl.** Most realistic; dropped as riskiest on the web and
   older phones.

In all three the app cuts pages itself; that is most of the work.

## How it works (decided)

### The setting

- New saved setting `bookReadingMode`: `pages` | `scroll`. **Default:
  `pages`** (the owner asked for this feel). Stored with the other settings.
- Shown in the book reader's settings sheet as a two-way chooser labelled
  "Pages" / "Scroll", above text size. Only the book reader shows it.

### Cutting into pages (pagination)

- Input: one source page's blocks (heading, subhead, paragraph, gatha,
  list, footnotes, table, image), the text style (size, spacing, fonts) and
  the page box (reading column width × the height between the top bar and
  the bottom bar, minus padding).
- Output: a list of screen pages; each is a list of **slices**: a whole
  block, or a range of lines of a paragraph / list item.
- Measured with the same text layout the reader already uses
  (`TextPainter`, same fonts and lead widths), so what is measured is what
  is drawn.
- Rules:
  - Paragraphs and list items may break between lines, never mid-line.
    Keep at least 2 lines at the bottom and top of a break when the
    paragraph is long enough (no single orphan or widow line).
  - A heading or subhead never sits alone at the foot of a page; it moves
    to the next page with the start of what follows.
  - A gatha verse block stays whole when it fits a page; a verse taller
    than a page breaks between its lines.
  - A table or picture taller than the space left moves to the next page;
    taller than a whole page, it is scaled down to fit one page.
  - Tables in Pages mode never scroll sideways (that would fight the edge
    drag, and snapshots cannot scroll). A wide table (today some short-cell
    grids keep their natural width and scroll) is shrunk to the column
    width. A table taller than a page breaks between rows and repeats its
    header row on each page, instead of shrinking to unreadable text.
    *My call: the 14 bundled tables include a 9-column grid and an 18-row
    table with long cells; breaking by rows keeps them readable at large
    text.*
  - Footnotes stay at the end of the chapter, as now, paginated like
    paragraphs.
  - The source page's title starts its first page.
- Cutting must not freeze the screen on the longest chapter (about 64,000
  characters): the first page shows as soon as it is cut, the rest follow.
- Re-cut when text size, line spacing, theme fonts, screen size or
  orientation change; the reader stays at the same passage.

### Place

- A place becomes: source page `n` + its `key` (as now) + a **text
  position**: block index and character offset of the first thing on the
  shown page. The old scroll `offset` is still read and written, so Scroll
  mode and existing saved places keep working.
- A saved place with only a scroll offset (everyone upgrading, since Pages
  is the default) is converted: lay the chapter out as the scroll column
  would, find the block and character at that offset, and open the page
  holding it. *My call: the anti-goal says no one loses their place on
  reopening.*
- Switching mode keeps the passage: Scroll → Pages opens the page holding
  the first visible line; Pages → Scroll scrolls to the first line of the
  page that was shown.

### Turning

- **Drag**: from the right edge region forward, the left edge region back.
  The curl follows the finger; release past half the page width (or a fast
  fling) completes the turn, otherwise it falls back.
- **Tap** in the outer fifth of either side also turns (common in readers),
  with the curl animating on its own.
- **Arrow buttons** in the bottom bar: "Previous page" / "Next page",
  48-point targets, with the counter "12 of 40" between them. At the very
  start or end of the book the arrow is disabled.
- **Scroll mode keeps today's bottom bar unchanged** (chapter arrows
  `book-prev` / `book-next` and the book-wide count). In Pages mode the bar
  has the page arrows and page count instead; jumping a whole chapter is
  through the contents (the top bar's way back), and the top bar shows the
  chapter title. *My call: one bar with both page and chapter arrows does
  not fit 320 wide at large text.*
- **Keyboard**: Left/Right arrows and Page Up/Page Down turn pages (web and
  hardware keyboards).
- **Screen readers**: the page's text is read in order; the page has
  "next page" and "previous page" actions and announces "Page 12 of 40"
  after a turn.
- **Reduced motion** (`MediaQuery.disableAnimations`): pages change
  instantly with no curl.
- **The curl carries straight across chapters** (owner's choice,
  2026-11-20). Turning past the last page of a source page curls into the
  first page of the next reading page with no screen change; turning back
  from the first page curls into the previous chapter's last page. So:
  - The reader cuts the neighbouring reading pages ahead of time (the
    next one in order, and the previous one in full, since going back
    lands on its last page), in the background, before the reader reaches
    an edge. If a neighbour is not ready when the reader gets there, the
    arrow and drag wait briefly with a quiet progress mark rather than
    jump.
  - The reading screen outlives the chapter change: the address updates
    to the new source page in place (no route transition, the curl's
    state and the cut neighbours kept), so the browser's address, the
    back button and the contents still name the right page.
  - Only the current chapter and its two neighbours are kept cut; others
    are dropped as the reader moves on.

### The curl (drawn by the app)

- The current page and the page underneath are painted from snapshots taken
  when a turn starts, so the curl animates pictures, not live text.
- Paint: the flat part of the turning page clipped along the fold line, the
  page's back as a lightly tinted mirror of its edge, a soft shadow on the
  page underneath along the fold, and a highlight on the curl.
- Colours come from the app's theme tokens so light and dark themes look
  right.
- Target: 60 frames a second on a mid-range Android phone and on the web.

## Constraints

- Flutter 3.47.9, Riverpod 3, go_router; no new package for the curl.
- Keep Android, iPhone and web in step.
- Text is never changed; every line still comes from the bundled source.
- Existing tests (overflow at 320 wide with large text, semantics, 48-point
  targets) keep passing and cover the new screens.
- Saved places from the current version still open.

## Left to the builder

- The exact curl geometry and shading, within the look above.
- How cutting is spread over frames or a background isolate.
- How snapshots are cached and freed.
- The size of the edge regions for drag and tap.
