# pitaka.lk book pages (test fixtures for `tools/sync_books.py`)

Real pages saved unchanged from https://pitaka.lk/books/ on 2026-11-17.
ධර්ම දානය පිණිස — no formal licence; text unchanged.
Books by Ven. Rerukane Chandawimala Maha Nahimi, published by the Sri
Chandawimala Dhamma Treatises Preservation Board; digitised by pitaka.lk.

`flat/` is ධර්ම විනිශ්චය (one level of contents):

- `flat/index.html`: https://pitaka.lk/books/dharma-winishchaya/index.html
- `flat/1.html`: https://pitaka.lk/books/dharma-winishchaya/1.html

`nested/` is අභිධර්ම මාර්ගය (three levels of contents). The files keep their
real names, so the index's links point at them; the tests use only the rows
whose file is here.

- `nested/index.html`: https://pitaka.lk/books/abhidharma-margaya/index.html
- `nested/2.html`: https://pitaka.lk/books/abhidharma-margaya/2.html (a parent with no text of its own)
- `nested/2-4.html`: https://pitaka.lk/books/abhidharma-margaya/2-4.html (`p.subhead`, `<ol>`)
- `nested/6.html`: https://pitaka.lk/books/abhidharma-margaya/6.html (a parent with text and children)
- `nested/6-12.html`: https://pitaka.lk/books/abhidharma-margaya/6-12.html (`div.gatha`, `p.subhead`, an empty `<p>`)
- `nested/8-1-1.html`: https://pitaka.lk/books/abhidharma-margaya/8-1-1.html (level 3, `<b>` inside paragraphs)

No page of the 23 books has `<h2>`/`<h3>` inside its main text (survey of
2026-11-17), so the heading mapping is tested on a short made-up snippet in
the test file instead.

Pages for the kinds added after the survey, under folders named after their
book, with their real names:

- `abhidharmaye-mulika-karunu/12.html`: https://pitaka.lk/books/abhidharmaye-mulika-karunu/12.html (`ol.footnotes`, one `<p>` per note, `<sup><a class="footnote-ref">`)
- `shasanavatharanaya/7.html`: https://pitaka.lk/books/shasanavatharanaya/7.html (a footnote with two `<p>`s)
- `abhidharma-margaya/5-5.html`: https://pitaka.lk/books/abhidharma-margaya/5-5.html (`table.collapse`, `<br>` inside cells)
- `abhidharma-margaya/2-7.html`: https://pitaka.lk/books/abhidharma-margaya/2-7.html (`ol.enum` with `span.li-num` labels, then a plain `<ol>`)
- `bodhi-poojawa/28-2.html`: https://pitaka.lk/books/bodhi-poojawa/28-2.html (an `<img>` alone in a `<p>`)
- `punyopadeshaya/39-25.html`: https://pitaka.lk/books/punyopadeshaya/39-25.html (an `<img>` inside `<b>` in a `<p>`)
- `bauddhayage-athpotha/6-7.html`: https://pitaka.lk/books/bauddhayage-athpotha/6-7.html (`<li>`s each holding a `div.gatha`)
- `pattana-pakarana-sannaya/6-2.html`: https://pitaka.lk/books/pattana-pakarana-sannaya/6-2.html (an `<ol>` nested in a `<ul>`'s `<li>`)
- `pohoya-dinaya/21-1.html`: https://pitaka.lk/books/pohoya-dinaya/21-1.html (the `<suli>` typo around a footnote mark, `<ol start="34">`, footnotes)
- `punyopadeshaya/39-23.html`: https://pitaka.lk/books/punyopadeshaya/39-23.html (table cells each holding a `<p>`, kept as the cell's lines)
