# Books that read like a printed book — design (short)

Date: 2026-11-24. Branch `bana`. Owner approved the mockups
(https://claude.ai/artifact/Tgq95Bu7pQcEQH7Un9H6hU, version 5): "build it".

## Why

The owner wants reading a Rerukane book to feel like reading a printed book, not
text on a screen. The reference is the Board's printed books (e.g. පොහොය දිනය PDF):
black ink, a book face, indented paragraphs with no gaps, the page number and a
running title at the top.

## Decided (owner)

- Chapter title: large, brown, centred, with a small flourish under it (the
  mockup's title), a little way down the page.
- Text: Abhaya Libre (OFL, after the classic Sinhala printing type), black ink on
  the cream paper (light ink on dark paper), justified, first line of each
  paragraph indented, no gap between paragraphs.
- Running head at the top: page number in the outer corner, the book's title on a
  left-hand page and the chapter's title on a right-hand page; no number at the foot.
- Left and right pages: the spine shadow and the wider inner margin swap sides.
- Phone or tablet sideways: two pages side by side, the spine in the middle; a turn
  moves on two pages.
- Text size as in the mockup (the reader's size setting still applies).

## Approaches

1. **Restyle in place (chosen).** Keep the paginator, the curl and the frame; change
   the styles, the gaps and the marks, and add the spread as a layout of two cut
   pages with the right page turning. Smallest change to proven code.
2. Render pages to images (PDF-like). Loses search marks, text size, dark paper.
3. A separate print-mode reader. Duplicates the paginator and the curl.

## Designer's calls

- The indent is a run of no-break spaces before the paragraph text, added when it
  is measured and drawn and never stored: saved places and search marks keep their
  character positions (the lead is mapped out). No-break spaces were measured to
  keep a steady indent under justification (an em space collapses at a line start).
- Paragraph-to-paragraph gap is 0; every other block keeps its gap. One function
  gives the gap for Pages mode, Scroll mode and the place maths.
- Side of a single page: odd page numbers are right-hand pages, even are left.
  In the spread the left page is the current page and the right the next; the
  right page curls (its turn shows the page after the spread); the left page
  changes when the turn ends.
- The spread is used when the page area is wider than tall and at least 600 px wide.
- The flourish is drawn by the app (no glyph needed from a font).
- Scroll mode gets the same type, title and paragraphs; the running head is for
  Pages mode only.

## Non-goals

Matching the printed book's page breaks or page numbers (our text is pitaka.lk's);
changing the chants, pirith or Tripitaka readers.
