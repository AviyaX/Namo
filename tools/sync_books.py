"""Turn the pitaka.lk pages of Ven. Rerukane Chandawimala's books into the app's book files, and check them.

Usage (from anywhere; <project> is the project folder):
  python -I -X utf8 tools/sync_books.py <project> [--fetch] [--survey] [--check] [--covers]

  --fetch    For each of the 23 books, read the index page and every page its
             contents link to from <project>/source_material/pitaka_lk_books/
             <slug>/, downloading only what is not there yet (User-Agent
             namo-app-build/1.0, a pause between requests). Parse them and
             write <project>/assets/books/<slug>.json.gz (gzip level 9, mtime
             0) and assets/books/index.json, then run --check.
  --survey   No network. Count every (tag, class) inside the main text of the
             cached pages (and the front matter of the index pages); print
             tag<TAB>class<TAB>count<TAB>first page, most frequent first.
  --check    No network. Prints OK and exits 0, or one line per problem and
             exits 1.
  --covers   Download the covers listed in COVERS to assets/books/covers/.

The text is never altered: tags are dropped, runs of HTML white space become
one space, and that is all, with one deliberate omission: the website's
back-link arrow at the end of each footnote (see _footnotes). A structure the parser does not know stops the
fetch with the page and the tag. Standard library only. The downloaded pages
are untrusted data: they are parsed, never run.
"""
import argparse
import datetime
import gzip
import hashlib
import html.parser
import json
import pathlib
import re
import time
import urllib.parse
import urllib.request

SLUGS = [
    "bauddhayage-athpotha",
    "dharma-winishchaya",
    "paramitha-prakaranaya",
    "suvisi-gunaya",
    "abhidharmaye-mulika-karunu",
    "abhidharma-margaya",
    "chathurarya-sathya",
    "punyopadeshaya",
    "shasanavatharanaya",
    "bodhi-pakshika-dharma",
    "patichcha-samuppada-vivaranaya",
    "upasampada-sheelaya",
    "ubhaya-prathimokshaya",
    "wanchaka-dharma",
    "vidarshana-bhavana-kramaya",
    "keles-1500",
    "pohoya-dinaya",
    "bodhi-poojawa",
    "chaththalisakara-vipassana",
    "vinaya-karma",
    "sathipttana-bhavana-kramaya",
    "nirvana-vinishchaya",
    "pattana-pakarana-sannaya",
]
BASE_URL = "https://pitaka.lk/books/"
USER_AGENT = "namo-app-build/1.0"
PAUSE_SECONDS = 0.2
SCHEMA = 1
AUTHOR = {"si": "රේරුකානේ චන්දවිමල මහා නාහිමි", "en": "Ven. Rerukane Chandawimala Maha Nahimi"}
PUBLISHER = {"si": "ශ්‍රී චන්දවිමල ධර්මපුස්තක සංරක්ෂණ මණ්ඩලය", "en": "Sri Chandawimala Dhamma Treatises Preservation Board"}
# slug -> (official title as the Board's /api/books lists it, cover URL); filled in Task 2.
COVERS: dict[str, tuple[str, str]] = {}

BLOCK_TAGS = {"p": "para", "h2": "heading", "h3": "heading", "h4": "heading", "ol": "list", "ul": "list"}
INLINE_TAGS = {"b", "strong", "i", "em", "u", "span", "a", "sup", "sub", "br", "suli"}   # flattened to their text; <br> is a line break; "suli" is a typo in pohoya-dinaya/21-1.html
SKIP_TAGS_IN_MAIN = {"nav", "dialog", "button", "script", "svg", "style"}        # plus div.page-title

TEXT_KINDS = ("heading", "subhead", "para")
KINDS = TEXT_KINDS + ("gatha", "list", "footnotes", "table", "image")
MARKERS = ("number", "bullet", "none")
VOID_TAGS = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr"}
NAME_RE = re.compile(r"^[0-9A-Za-z][0-9A-Za-z-]*$")
SPACE_RE = re.compile(r"[ \t\n\r\f]+")       # HTML white space; no-break and zero-width characters are text
MARKUP_RE = re.compile(r"<|&(?:#[0-9]+|#[xX][0-9a-fA-F]+|[A-Za-z]+);")
PNG_HEADER = b"\x89PNG\r\n\x1a\n"
BREAK = "\x00"                               # stands for <br> until the text is cleaned
BACK_LINK = "\u2191"                          # the website's "back to the text" arrow at the end of a footnote


class SyncError(Exception):
    pass


def cache_dir(project):
    return pathlib.Path(project) / "source_material" / "pitaka_lk_books"


def assets_dir(project):
    return pathlib.Path(project) / "assets" / "books"


def pack_bytes(data):
    return gzip.compress(data, 9, mtime=0)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


# ---------------------------------------------------------------- network


def _request(url):
    return urllib.request.Request(url, headers={"User-Agent": USER_AGENT})


def _fetch(url, opener):
    last = None
    for attempt in range(4):
        try:
            with opener(_request(url), timeout=60) as response:
                return response.read()
        except OSError as exc:
            last = exc
            if attempt < 3:
                time.sleep(2 * (attempt + 1))
    raise SyncError("%s: %s" % (url, last))


def fetch_text(url, opener=urllib.request.urlopen):
    try:
        return _fetch(url, opener).decode("utf8")
    except UnicodeDecodeError as exc:
        raise SyncError("%s: not UTF-8 (%s)" % (url, exc))


def cached_page(cache, slug, name, opener=urllib.request.urlopen):
    if not NAME_RE.match(slug) or not name.endswith(".html") or not NAME_RE.match(name[:-5]):
        raise SyncError("%s/%s: not a page name this tool fetches" % (slug, name))
    path = pathlib.Path(cache) / slug / name
    if path.is_file():
        return path.read_text(encoding="utf8")
    text = fetch_text(BASE_URL + slug + "/" + name, opener)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf8")
    time.sleep(PAUSE_SECONDS)
    return text


# ---------------------------------------------------------------- HTML


class _Element:
    def __init__(self, tag, attrs):
        self.tag = tag
        self.attrs = attrs
        self.children = []

    @property
    def cls(self):
        return " ".join((self.attrs.get("class") or "").split())

    def has_class(self, *names):
        return set(names) <= set(self.cls.split())

    def iter(self):
        for child in self.children:
            if isinstance(child, _Element):
                yield child
                yield from child.iter()

    def find(self, tag, *classes):
        for el in self.iter():
            if el.tag == tag and el.has_class(*classes):
                return el
        return None


class _TreeBuilder(html.parser.HTMLParser):
    """Builds a small element tree; keeps a stack of open tags, closes to the matching one."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.root = _Element("#document", {})
        self.stack = [self.root]

    def handle_starttag(self, tag, attrs):
        el = _Element(tag, dict(attrs))
        self.stack[-1].children.append(el)
        if tag not in VOID_TAGS:
            self.stack.append(el)

    def handle_startendtag(self, tag, attrs):
        self.stack[-1].children.append(_Element(tag, dict(attrs)))

    def handle_endtag(self, tag):
        for i in range(len(self.stack) - 1, 0, -1):
            if self.stack[i].tag == tag:
                del self.stack[i:]
                return

    def handle_data(self, data):
        self.stack[-1].children.append(data)


def _tree(text):
    builder = _TreeBuilder()
    builder.feed(text)
    builder.close()
    return builder.root


def _skipped(el):
    return el.tag in SKIP_TAGS_IN_MAIN or (el.tag == "div" and el.has_class("page-title"))


def _unknown(where, el):
    return SyncError('%s: unknown <%s class="%s">' % (where, el.tag, el.cls))


def _clean(raw):
    """Collapse HTML white space and strip; BREAK marks become line breaks."""
    return "\n".join(SPACE_RE.sub(" ", part).strip(" ") for part in raw.split(BREAK)).strip("\n")


def _inline(el, where, block):
    """The raw text of an element whose children may only be inline."""
    return _inline_children(el.children, where, block)


def _inline_children(children, where, block):
    out = []
    for child in children:
        if isinstance(child, str):
            out.append(child)
        elif child.tag in SKIP_TAGS_IN_MAIN:
            continue
        elif child.tag == "br":
            out.append(BREAK)
        elif child.tag in INLINE_TAGS:
            out.append(_inline(child, where, block))
        elif child.tag in BLOCK_TAGS or child.tag in ("div", "li"):
            raise SyncError("%s: <%s> holds a block <%s>" % (where, block, child.tag))
        else:
            raise _unknown(where, child)
    return "".join(out)


def _gatha_raw(children, where):
    raw = []
    for child in children:
        if isinstance(child, _Element) and child.tag == "p" and not child.cls:
            raw += [BREAK, _inline(child, where, "p"), BREAK]
        elif isinstance(child, _Element) and child.tag in INLINE_TAGS and child.tag != "br":
            raw.append(_gatha_raw(child.children, where))
        else:
            raw.append(_inline_children([child], where, "div"))
    return "".join(raw)


def _gatha(el, where):
    """One line per <p> and per <br>-separated run. Text and inline tags between the
    <p>s are lines too (suvisi-gunaya/19.html leaves four lines outside, split by <br>),
    and so are <p>s inside an inline tag (suvisi-gunaya/28-4.html has a <b> around three)."""
    lines = _clean(_gatha_raw(el.children, where)).split("\n")
    return {"kind": "gatha", "lines": [line for line in lines if line]}


def _item_text(li, where):
    """A list item's text: inline runs, plus the lines of a div.gatha inside it
    (bauddhayage-athpotha/6-7.html) and the items of a list nested in it
    (pattana-pakarana-sannaya/6-2.html), each as further lines joined by "\\n"."""
    parts, run = [], []

    def flush():
        if run:
            parts.append(_clean(_inline_children(run, where, "li")))
            run.clear()

    for child in li.children:
        if isinstance(child, _Element) and child.tag == "div" and child.cls == "gatha":
            flush()
            parts += _gatha(child, where)["lines"]
        elif isinstance(child, _Element) and child.tag in ("ol", "ul") and child.cls in ("", "enum"):
            flush()
            parts += _list(child, where)["items"]
        else:
            run.append(child)
    flush()
    return "\n".join(part for part in parts if part)


def _list(el, where):
    items = []
    for child in el.children:
        if isinstance(child, str):
            if child.strip(" \t\n\r\f"):
                raise SyncError("%s: text outside an item in a list" % where)
        elif child.tag == "li" and not child.cls:
            items.append(_item_text(child, where))
        else:
            raise _unknown(where, child)
    start = el.attrs.get("start") if el.tag == "ol" else None
    try:
        start = int(start) if start is not None else 1
    except ValueError:
        raise SyncError('%s: <ol start="%s"> is not a number' % (where, start))
    # ol.enum, e.g. abhidharma-margaya/2-7.html: each <li> starts with the source's own
    # <span class="li-num">(1)</span>, kept in the text, so the reader draws no marker.
    marker = "none" if el.cls == "enum" else "number" if el.tag == "ol" else "bullet"
    return {"kind": "list", "marker": marker, "start": start, "items": items}


def _is_back_link(el):
    href = el.attrs.get("href") or ""
    return el.tag == "a" and href.startswith("#footnote-ref") and _plain_text(el) == BACK_LINK


def _footnotes(el, where):
    """ol.footnotes, e.g. abhidharmaye-mulika-karunu/12.html: one item per <li>; its <p>s
    (two in shasanavatharanaya/7.html) are lines.

    The one deliberate omission in this tool: each note ends with the website's back-link
    <a href="#footnote-ref-N">\u2191</a>, navigation rather than the book's text, so that
    trailing arrow and the white space before it are left out of the item."""
    items = []
    for child in el.children:
        if isinstance(child, str):
            if child.strip(" \t\n\r\f"):
                raise SyncError("%s: text outside a footnote" % where)
        elif child.tag == "li" and not child.cls:
            lines = []
            for part in child.children:
                if isinstance(part, _Element) and part.tag == "p" and not part.cls:
                    lines.append(_clean(_inline(part, where, "p")))
                elif isinstance(part, _Element) or part.strip(" \t\n\r\f"):
                    raise SyncError("%s: a footnote holds something besides <p>" % where)
            item = "\n".join(line for line in lines if line)
            if any(_is_back_link(e) for e in child.iter()):
                item = re.sub(r"[ \t\n\r\f]*" + BACK_LINK + "$", "", item)
            items.append(item)
        else:
            raise _unknown(where, child)
    return {"kind": "footnotes", "items": items}


def _table(el, where):
    """<table>, and table.collapse (abhidharma-margaya/5-5.html): rows of cell text."""
    trs = []
    for child in el.children:
        if isinstance(child, _Element) and child.tag in ("thead", "tbody", "tfoot") and not child.cls:
            trs += child.children
        else:
            trs.append(child)
    rows, header = [], False
    for tr in trs:
        if isinstance(tr, str):
            if tr.strip(" \t\n\r\f"):
                raise SyncError("%s: text outside a table row" % where)
            continue
        if tr.tag != "tr" or tr.cls:
            raise _unknown(where, tr)
        cells = []
        for cell in tr.children:
            if isinstance(cell, str):
                if cell.strip(" \t\n\r\f"):
                    raise SyncError("%s: text outside a table cell" % where)
            elif cell.tag in ("td", "th") and not cell.cls:
                cells.append(cell)
            else:
                raise _unknown(where, cell)
        if not rows:
            header = bool(cells) and all(c.tag == "th" for c in cells)
        rows.append([_cell_text(c, where) for c in cells])
    return {"kind": "table", "header": header, "rows": rows}


def _cell_text(cell, where):
    """A cell's text; its <p>s (punyopadeshaya/39-23.html, keles-1500/2.html) are lines
    joined by "\\n", as in a list item. Any other block inside a cell raises."""
    parts, run = [], []

    def flush():
        if run:
            parts.append(_clean(_inline_children(run, where, cell.tag)))
            run.clear()

    for child in cell.children:
        if isinstance(child, _Element) and child.tag == "p" and not child.cls:
            flush()
            parts.append(_clean(_inline(child, where, "p")))
        else:
            run.append(child)
    flush()
    return "\n".join(part for part in parts if part)


def _image(el):
    return {"kind": "image", "src": el.attrs.get("src") or "", "alt": _clean(el.attrs.get("alt") or "")}


def _paragraph_images(el, where):
    """The images of a <p> that holds nothing but images, inline tags and white space
    (bodhi-poojawa/28-2.html; inside a <b> in punyopadeshaya/39-25.html); [] if it has none."""
    images = [e for e in el.iter() if e.tag == "img"]
    if not images:
        return []
    for e in el.iter():
        if e.tag not in INLINE_TAGS and e.tag != "img":
            raise _unknown(where, e)
    if any(isinstance(c, str) and c.strip(" \t\n\r\f") for e in [el, *el.iter()] for c in e.children):
        raise SyncError("%s: an <img> shares its paragraph with text" % where)
    return [_image(e) for e in images]


def _subheads(el, where):
    """div.subhead: its own text, or one subhead per child <p>."""
    if not any(isinstance(c, _Element) and c.tag == "p" for c in el.children):
        return [el]
    for child in el.children:
        if isinstance(child, str):
            if child.strip(" \t\n\r\f"):
                raise SyncError("%s: text beside the paragraphs of a div.subhead" % where)
        elif child.tag != "p" or child.cls:
            raise _unknown(where, child)
    return [c for c in el.children if isinstance(c, _Element)]


def _blocks(root, where):
    blocks = []
    for el in root.children:
        if isinstance(el, str):
            if el.strip(" \t\n\r\f"):
                raise SyncError("%s: text outside a block" % where)
            continue
        if _skipped(el):
            continue
        kind = BLOCK_TAGS.get(el.tag)
        texts = [el]
        if el.tag == "div" and el.cls == "gatha":
            block = _gatha(el, where)
            if block["lines"]:
                blocks.append(block)
        elif kind == "list" and (not el.cls or (el.tag == "ol" and el.cls == "enum")):
            blocks.append(_list(el, where))
        elif el.tag == "ol" and el.cls == "footnotes":
            blocks.append(_footnotes(el, where))
        elif el.tag == "table" and el.cls in ("", "collapse"):
            blocks.append(_table(el, where))
        elif el.tag == "img":
            blocks.append(_image(el))
        elif el.tag == "p" and not el.cls and _paragraph_images(el, where):
            blocks += _paragraph_images(el, where)
            kind = None
        elif el.tag == "p" and el.cls == "subhead":
            kind = "subhead"
        elif el.tag == "div" and el.cls == "subhead":
            # e.g. chaththalisakara-vipassana/3-2.html (<p> inside), suvisi-gunaya/3-8.html (bare text).
            kind = "subhead"
            texts = _subheads(el, where)
        elif el.tag == "div" and el.cls in ("centered", "largefont"):
            # Layout wrappers around ordinary blocks: bodhi-poojawa/index.html (front matter),
            # sathipttana-bhavana-kramaya/9.html (a div.subhead inside), vinaya-karma/3-1.html.
            blocks += _blocks(el, where)
        elif el.tag == "p" and el.cls == "centered":
            kind = "para"         # e.g. abhidharma-margaya/10-18.html; the centring is not kept
        elif el.tag == "h5" and not el.cls:
            kind = "heading"      # e.g. pattana-pakarana-sannaya/7-4-2-1.html
        elif kind is None or el.cls:
            raise _unknown(where, el)
        if kind in TEXT_KINDS:
            for part in texts:
                text = _clean(_inline(part, where, part.tag))
                if text:
                    blocks.append({"kind": kind, "text": text})
    return blocks


def _resolve_images(blocks, url, where):
    """Image sources become absolute URLs, resolved against the page they are on."""
    for block in blocks:
        if block["kind"] == "image":
            if url is None and not re.match(r"https?://", block["src"]):
                raise SyncError("%s: an image with a relative src and no page URL" % where)
            block["src"] = urllib.parse.urljoin(url or "", block["src"])
    return blocks


def _plain_text(el):
    """Text of a title element, leaving out icons and buttons."""
    out = []
    for child in el.children:
        if isinstance(child, str):
            out.append(child)
        elif child.tag not in SKIP_TAGS_IN_MAIN:
            out.append(_plain_text(child))
    return SPACE_RE.sub(" ", "".join(out)).strip(" ")


def parse_index(text, url=None):
    """url: the index page's address, against which front-matter images are resolved."""
    root = _tree(text)
    head = root.find("div", "book-head")
    h1 = head.find("h1") if head else None
    if h1 is None or not _plain_text(h1):
        raise SyncError("index: no book title (div.book-head h1)")
    lead = head.find("p", "lead")
    subtitle = (_plain_text(lead) or None) if lead else None

    front = None
    details = root.find("details", "front-matter")
    if details is not None:
        summary = details.find("summary")
        body = details.find("div", "front-body")
        blocks = _blocks(body, "index front matter") if body is not None else []
        _resolve_images(blocks, url, "index front matter")
        if blocks:
            front = {"title": _plain_text(summary) if summary else "", "blocks": blocks}

    nav = root.find("nav", "toc")
    if nav is None:
        raise SyncError("index: no contents (nav.toc)")
    toc = []
    for row in nav.iter():
        if row.tag != "div" or not row.has_class("toc-row"):
            continue
        link = row.find("a")
        href = link.attrs.get("href", "") if link else ""
        if not href.endswith(".html") or not NAME_RE.match(href[:-5]):
            raise SyncError('index: contents row with link "%s"' % href)
        try:
            level = int(row.attrs.get("data-level", ""))
        except ValueError:
            raise SyncError("index: contents row %s without a data-level" % href)
        toc.append({"key": href[:-5], "href": href, "level": level, "title": _plain_text(link)})
    return {"title": _plain_text(h1), "subtitle": subtitle, "front": front, "toc": toc}


def _main_text(root):
    for el in root.iter():
        if el.tag == "main" and el.has_class("page", "prose"):
            return el
    return None


def parse_page(text, where, url=None):
    """where: "<slug>/<page>.html"; url: the page's address (default BASE_URL + where)."""
    main = _main_text(_tree(text))
    if main is None:
        raise SyncError("%s: no main.page.prose" % where)
    return _resolve_images(_blocks(main, where), url or BASE_URL + where, where)


def build_book(slug, index, pages_html, fetched):
    base = BASE_URL + slug + "/"
    pages = []
    if index["front"]:
        pages.append({"n": 1, "key": "front", "level": 1, "title": index["front"]["title"],
                      "url": base + "index.html", "blocks": index["front"]["blocks"]})
    for row in index["toc"]:
        where = slug + "/" + row["href"]
        if row["href"] not in pages_html:
            raise SyncError("%s: page not read" % where)
        pages.append({"n": len(pages) + 1, "key": row["key"], "level": row["level"], "title": row["title"],
                      "url": base + row["href"],
                      "blocks": parse_page(pages_html[row["href"]], where, base + row["href"])})
    return {"id": slug, "title": index["title"], "subtitle": index["subtitle"],
            "source": {"url": base + "index.html", "fetched": fetched}, "pages": pages}


# ---------------------------------------------------------------- survey


def _page_order(path):
    parts = path.stem.split("-")
    return (0, [int(p) for p in parts], "") if all(p.isdigit() for p in parts) else (1, [], path.name)


def _count(el, counts, page):
    for child in el.children:
        if isinstance(child, str):
            continue
        key = (child.tag, child.cls)
        count, first = counts.get(key, (0, page))
        counts[key] = (count + 1, first)
        if not _skipped(child):
            _count(child, counts, page)


def survey(cache):
    counts = {}
    for book in sorted(p for p in pathlib.Path(cache).iterdir() if p.is_dir()):
        for path in sorted(book.glob("*.html"), key=_page_order):
            root = _tree(path.read_text(encoding="utf8"))
            if path.name == "index.html":
                details = root.find("details", "front-matter")
                text = details.find("div", "front-body") if details else None
            else:
                text = _main_text(root)
            if text is not None:
                _count(text, counts, book.name + "/" + path.name)
    return counts


# ---------------------------------------------------------------- bundle


def _entry(book, gz):
    pages = book["pages"]
    slug = book["id"]
    return {
        "id": slug,
        "title": book["title"],
        "subtitle": book["subtitle"],
        "chapters": sum(1 for p in pages if p["level"] == 1 and p["key"] != "front"),
        "pages": sum(1 for p in pages if p["blocks"]),
        "file": "assets/books/%s.json.gz" % slug,
        "bytes": len(gz),
        "sha256": sha256(gz),
        "cover": "assets/books/covers/%s.png" % slug,
        "cover_source": COVERS[slug][1] if slug in COVERS else None,
    }


def write_bundle(project, books, fetched):
    out = assets_dir(project)
    out.mkdir(parents=True, exist_ok=True)
    entries = []
    for book in books:
        gz = pack_bytes(json.dumps(book, ensure_ascii=False, separators=(",", ":")).encode("utf8"))
        (out / (book["id"] + ".json.gz")).write_bytes(gz)
        entries.append(_entry(book, gz))
    index = {"schema": SCHEMA, "author": AUTHOR, "publisher": PUBLISHER,
             "source": {"name": "pitaka.lk", "url": BASE_URL, "fetched": fetched}, "books": entries}
    (out / "index.json").write_text(json.dumps(index, ensure_ascii=False, indent=1) + "\n", encoding="utf8")
    return index


# ---------------------------------------------------------------- check


def _text_problems(where, text):
    if not isinstance(text, str) or not text:
        return ["%s: empty or missing text" % where]
    if MARKUP_RE.search(text):
        return ["%s: markup left in the text: %r" % (where, text[:60])]
    return []


def _strings_problems(where, what, items):
    if not isinstance(items, list) or not items:
        return ["%s: %s without items" % (where, what)]
    return [p for item in items for p in _text_problems(where, item)]


def _block_problems(where, block):
    kind = block.get("kind") if isinstance(block, dict) else None
    if kind in TEXT_KINDS:
        return _text_problems(where, block.get("text"))
    if kind == "gatha":
        return _strings_problems(where, "gatha", block.get("lines"))
    if kind == "list":
        problems = []
        if block.get("marker") not in MARKERS or not isinstance(block.get("start"), int):
            problems.append("%s: list without a known marker and a start" % where)
        return problems + _strings_problems(where, "list", block.get("items"))
    if kind == "footnotes":
        return _strings_problems(where, "footnotes", block.get("items"))
    if kind == "table":
        rows = block.get("rows")
        problems = [] if isinstance(block.get("header"), bool) else ["%s: table without a header flag" % where]
        if not isinstance(rows, list) or not rows or not all(isinstance(r, list) and r for r in rows):
            return problems + ["%s: table with no rows or an empty row" % where]
        for cell in (c for r in rows for c in r):
            if not isinstance(cell, str):
                problems.append("%s: table cell is not text" % where)
            elif MARKUP_RE.search(cell):
                problems.append("%s: markup left in the text: %r" % (where, cell[:60]))
        return problems
    if kind == "image":
        problems = []
        if not isinstance(block.get("src"), str) or not re.match(r"https?://[^/]+/", block["src"]):
            problems.append("%s: image src %r is not an absolute URL" % (where, block.get("src")))
        alt = block.get("alt")
        if not isinstance(alt, str):
            problems.append("%s: image without alt text field" % where)
        elif MARKUP_RE.search(alt):
            problems.append("%s: markup left in the text: %r" % (where, alt[:60]))
        return problems
    return ["%s: unknown block kind %r" % (where, kind)]


def _page_problems(name, pages):
    problems = []
    previous = 0
    for i, page in enumerate(pages):
        where = "%s: page %d" % (name, i + 1)
        if page.get("n") != i + 1:
            problems.append("%s: n is %s" % (where, page.get("n")))
        title = page.get("title")
        if not isinstance(title, str) or not title.strip():
            problems.append("%s: no title" % where)
        if page.get("key") == "front" and i != 0:
            problems.append("%s: the front matter is not page 1" % where)
        level = page.get("level")
        if not isinstance(level, int) or not 1 <= level <= 4:
            problems.append("%s: level %r is not 1-4" % (where, level))
            level = previous
        elif level > previous + 1:
            problems.append("%s: level jumps from %d to %d" % (where, previous, level))
        previous = level
        blocks = page.get("blocks")
        if not isinstance(blocks, list):
            problems.append("%s: no block list" % where)
            blocks = []
        for block in blocks:
            problems += _block_problems(where, block)
        following = pages[i + 1].get("level") if i + 1 < len(pages) else None
        has_children = isinstance(following, int) and isinstance(level, int) and following > level
        if not blocks and not has_children:
            problems.append("%s: neither blocks nor children" % where)
    return problems


def _book_problems(out, entry, with_covers):
    slug = entry.get("id")
    name = "%s.json.gz" % slug
    problems = []
    if entry.get("file") != "assets/books/" + name:
        problems.append("%s: index.json gives file %r" % (name, entry.get("file")))
    if entry.get("cover") != "assets/books/covers/%s.png" % slug:
        problems.append("%s: index.json gives cover %r" % (name, entry.get("cover")))
    if with_covers:
        cover = out / "covers" / (slug + ".png")
        if not cover.is_file():
            problems.append("covers/%s.png: missing" % slug)
        elif not cover.read_bytes().startswith(PNG_HEADER):
            problems.append("covers/%s.png: not a PNG" % slug)
    path = out / name
    if not path.is_file():
        return problems + ["%s: missing" % name]
    gz = path.read_bytes()
    if len(gz) != entry.get("bytes"):
        problems.append("%s: %d bytes, index.json says %s" % (name, len(gz), entry.get("bytes")))
    if sha256(gz) != entry.get("sha256"):
        problems.append("%s: sha256 differs from index.json" % name)
    try:
        book = json.loads(gzip.decompress(gz).decode("utf8"))
    except (OSError, EOFError, ValueError) as exc:
        return problems + ["%s: cannot be unpacked (%s)" % (name, exc)]
    pages = book.get("pages") if isinstance(book, dict) else None
    if not isinstance(pages, list) or not pages or not all(isinstance(p, dict) for p in pages):
        return problems + ["%s: no pages" % name]
    for field in ("id", "title", "subtitle"):
        if book.get(field) != entry.get(field):
            problems.append("%s: %s differs from index.json" % (name, field))
    problems += _page_problems(name, pages)
    chapters = sum(1 for p in pages if p.get("level") == 1 and p.get("key") != "front")
    reading = sum(1 for p in pages if p.get("blocks"))
    if chapters != entry.get("chapters"):
        problems.append("%s: %d chapters, index.json says %s" % (name, chapters, entry.get("chapters")))
    if reading != entry.get("pages"):
        problems.append("%s: %d reading pages, index.json says %s" % (name, reading, entry.get("pages")))
    return problems


def check(project):
    out = assets_dir(project)
    try:
        index = json.loads((out / "index.json").read_text(encoding="utf8"))
        entries = index["books"]
        ids = [e["id"] for e in entries]
    except (OSError, ValueError, KeyError, TypeError) as exc:
        return ["index.json: cannot be read (%s)" % exc]
    problems = []
    if index.get("schema") != SCHEMA:
        problems.append("index.json: schema %r, expected %d" % (index.get("schema"), SCHEMA))
    if ids != SLUGS:
        problems.append("index.json: the books are not the %d slugs in order" % len(SLUGS))
    with_covers = (out / "covers").is_dir()
    expected = {"index.json"} | {"%s.json.gz" % i for i in ids}
    if with_covers:
        expected |= {"covers/%s.png" % i for i in ids}
    for path in sorted(out.rglob("*")):
        rel = path.relative_to(out).as_posix()
        if path.is_file() and rel not in expected:
            problems.append("%s: unexpected file under assets/books/" % rel)
    for entry in entries:
        try:
            problems += _book_problems(out, entry, with_covers)
        except (OSError, ValueError, KeyError, TypeError, AttributeError) as exc:
            problems.append("%s.json.gz: cannot be checked (%s)" % (entry.get("id"), exc))
    return problems


# ---------------------------------------------------------------- covers


def fetch_covers(project, opener=urllib.request.urlopen):
    problems = []
    covers = assets_dir(project) / "covers"
    for slug in SLUGS:
        if slug not in COVERS:
            problems.append("%s: no cover URL in COVERS" % slug)
            continue
        try:
            data = _fetch(COVERS[slug][1], opener)
        except SyncError as exc:
            problems.append("%s: %s" % (slug, exc))
            continue
        if not data.startswith(PNG_HEADER):
            problems.append("%s: %s is not a PNG" % (slug, COVERS[slug][1]))
            continue
        covers.mkdir(parents=True, exist_ok=True)
        (covers / (slug + ".png")).write_bytes(data)
        time.sleep(PAUSE_SECONDS)
    return problems


# ---------------------------------------------------------------- main


def fetch_all(project, opener=urllib.request.urlopen):
    cache = cache_dir(project)
    fetched = datetime.date.today().isoformat()
    books = []
    for slug in SLUGS:
        index = parse_index(cached_page(cache, slug, "index.html", opener), BASE_URL + slug + "/index.html")
        pages = {row["href"]: cached_page(cache, slug, row["href"], opener) for row in index["toc"]}
        books.append(build_book(slug, index, pages, fetched))
    return write_bundle(project, books, fetched)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("project")
    ap.add_argument("--fetch", action="store_true")
    ap.add_argument("--survey", action="store_true")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--covers", action="store_true")
    args = ap.parse_args(argv)
    if not (args.fetch or args.survey or args.check or args.covers):
        ap.error("give at least one of --fetch, --survey, --check, --covers")
    project = pathlib.Path(args.project)
    code = 0
    if args.fetch:
        try:
            index = fetch_all(project)
        except SyncError as exc:
            print(exc)
            return 1
        print("wrote %d books to %s" % (len(index["books"]), assets_dir(project)))
    if args.covers:
        problems = fetch_covers(project)
        for line in problems:
            print(line)
        code = 1 if problems else code
    if args.survey:
        rows = sorted(survey(cache_dir(project)).items(), key=lambda kv: (-kv[1][0], kv[0]))
        for (tag, cls), (count, first) in rows:
            print("%s\t%s\t%d\t%s" % (tag, cls, count, first))
    if args.check or args.fetch:
        problems = check(project)
        for line in problems:
            print(line)
        if problems:
            return 1
        print("OK")
    return code


if __name__ == "__main__":
    raise SystemExit(main())
