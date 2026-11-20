# Books that look like a book — short design

Date: 2026-11-21. Owner: Avishka Induwara. Builds on the page-flip branch
(`book-page-flip`, design `2026-11-20-book-page-flip-design.md`).

## Why

The owner tried the page-flip build: turning works, but the page does not
look like a book, so a first-time reader won't guess the pages turn. Text
should also be justified, as in a printed book.

## Goals (owner's choices, from mockups)

- **Bound-book look (mockup B)** for book pages: the page sits in a book
  cover (brown, rounded, soft shadow), with a spine shadow down the left
  edge of the page, a thin gold rule around the page, the page number at
  the foot, and a lifted (dog-eared) corner at the bottom right.
- **Paper choice**: books default to **cream paper** even though the app
  is dark by default. A new "Paper" chooser in the book reader's settings
  sheet offers **Cream** (default) or **Dark** (dark page `surface`,
  dark-brown cover, gold rule at 60%). Saved once for all books.
- **Justified text**: book paragraphs and list/footnote item text are
  justified; headings, gatha verses and tables keep their own alignment.
- **First-time hint**: the first time a book is opened in Pages mode, the
  lifted corner gently peels back and settles once. Never again after
  that; replayed by Settings → "Show the tips again"; skipped when the
  phone's animations are off.

## Decided

- The look (cover, gold rule, paper colour, justified text) applies in
  both Pages and Scroll mode, so a book looks the same either way
  (my call; owner agreed to the playback). The spine shadow, page number
  and lifted corner are Pages-mode only (they belong to a page).
- **Justification approach (owner chose 2):** a paragraph is laid out once
  in full, justified, at the page width; each page draws only the lines
  that belong to it (painting the full layout clipped and shifted to its
  line range). So the last line before a page break is justified like the
  rest, and line breaks stay exactly what the page cutter measured
  (justification never changes where lines break). The paragraph's own
  last line stays ragged, as in print.
- Paper colours are theme tokens (new tokens for cream paper, cover,
  dark cover, spine shadow, gold rule) so the design-rules test holds.
- The cover and paper inset reduce the page box; the paginator is given
  the box inside them, so nothing overflows.
- The peel uses the existing curl painter driven a short way (to about
  a 15% lift) and back, about 1.2 s, once; it is a tip in the existing
  tips system (`Tip` + `tipsProvider`), so "Show the tips again" resets it.
- Stacked page edges (mockup A) are not included.

## Non-goals

- No change to chants, pirith, Samantha Pattana or Tripitaka readers.
- No change to the app's own theme default (stays dark).
- No two-page spread.

## Constraints

As the page-flip design: text never changed; Android, iPhone and web in
step; no overflow at 320 wide with large text; 48-point targets; existing
saved places keep working; reduced motion respected.

## Left to the builder

Exact cover margins, radius, shadow strength, spine-shadow width and the
peel's curve, within the mockup's look.
