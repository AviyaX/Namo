# Tripitakaya — design

Date: 2026-11-12. Status: approved by the owner on 2026-11-12 ("build").

## Intent

The owner wants the whole Tripitaka inside Namo, in Pali and Sinhala, the
way thripitakaya.org offers it: a tree of folders (Pitaka → Nikaya → Vagga →
Sutta) and a reading view with a පාලි / සිංහල switch. It gets its own
bottom tab, so the bar reads Home · Library · Tripitaka · Saved · Settings.
All of the text is inside the app; nothing is fetched while the app runs.

The words come from tipitaka.lk's public repository
(`github.com/pathnirvana/tipitaka.lk`), which holds the same Buddha Jayanti
Pali text and Sinhala translation that thripitakaya.org shows (checked on
the Brahmajala Sutta, 2026-11-12) and publishes them under a licence that
allows redistribution.

## Goals

- A fifth tab that opens the Tripitaka: three pitakas at the top, then one
  level at a time down to a sutta.
- Every text of the three pitakas that the source holds can be reached and
  read, in Pali, in Sinhala, or both.
- Finding a sutta by name.
- Reading comfort as in the rest of the app: text size, line spacing,
  theme, progress, previous / next, the place remembered, bookmarks that
  show up in Saved.
- Works fully offline on Android, iOS and web from the same code.
- The source's licence terms are met (below) and can be shown to be met.

## Non-goals (this version)

- Searching inside the text of the suttas (names only for now).
- The commentaries (`atta-*`) and other books (`anya-*`) in the source.
- Audio, auto-scroll, flows, "today's gatha" picks from the Tripitaka.
- English translation, Roman-script Pali.
- The source's dictionary, word alignment, place and people data, and the
  meanings of footnote abbreviations.
- Changes to Home or the Library.

## Anti-goals (these would make it a failure)

- Any change to the wording of the source text: no corrections, no
  normalising, no trimming, no re-ordering. Not even an obvious typo.
- Any text typed or generated rather than read from the source files.
- Any network request at run time; any ad, payment or donation prompt.
- A text in the source that cannot be reached from the tree.
- Presenting the app as tipitaka.lk's or thripitakaya.org's own, or copying
  either site's artwork.
- Any existing feature breaking, or a control that does nothing.
- The app's start getting slower because of the Tripitaka (nothing of it
  is loaded until the tab is opened).

## Constraints

- Licence (`LICENSE.md` in the source repository; Creative Commons
  Attribution-NoDerivatives 4.0 with added conditions):
  1. credit tipitaka.lk / pitaka.lk;
  2. no modifications; errors are reported to path.nirvana@gmail.com, not
     fixed here;
  3. an automated script keeps the text in sync with their repository.
- Flutter, one code base. One new package is allowed: `archive` (pure
  Dart), only to unpack gzip the same way on all three platforms.
- Fonts stay as they are (NotoSansSinhala for all Sinhala-script text).
- Tests are added, none deleted; analyze stays clean; the four existing
  content and glyph checks stay green.
- Wide screens (840 px and up) keep the side rail.
- `source_material/` stays untracked.

## Approaches considered

1. **The source's book files unchanged, compressed, plus the source's own
   tree file.** One file is unpacked when a sutta in it is opened. No
   database. Sync is a copy. *Chosen by the owner.*
2. **A database built into the app**, giving full-text search. New
   platform-specific packages (different on web), a much larger install,
   the most risk across three platforms. Can be added later over 1.
3. **One small file per sutta.** Slightly faster opening, but thousands of
   files and our own cutting-up of the source, which is harder to keep
   provably unchanged and in sync.

## The data

**What is shipped** (`assets/tipitaka/`):

| File | What |
|---|---|
| `text/<name>.json.gz` | each source file `public/static/text/<name>.json` whose name starts `vp-`, `dn-`, `mn-`, `sn-`, `an-`, `kn-` or `ap-` (190 files, 15,156 pages, about 170 MB unpacked, about 15.5 MB packed, measured 2026-11-12); gzip of the source bytes, nothing else |
| `tree.json.gz` | the source's `public/static/data/tree.json`, unchanged, gzipped |
| `manifest.json` | source repository, commit id and date, for every file its name and the SHA-256 of its unpacked bytes, the number of readings, and the keys of the parents that hold text of their own |
| `LICENSE.md` | the source's licence file, copied |

Unpacking any shipped file gives the source's bytes exactly; the check
tool proves it against the manifest.

**Source format** (fully described in the clone at
`source_material/tipitaka_lk/repo`: `dev-docs/data-pipeline.md`,
`build/tree.ts`, `shared/markup.ts`, `shared/beautify.ts`):

- A book file is `{filename, pages: [{pageNum, pali: {entries, footnotes},
  sinh: {entries, footnotes}}]}`. The Pali and Sinhala `entries` of a page
  pair up by index. An entry is `{type, text, level?}` with type
  `centered`, `heading`, `paragraph`, `gatha` or `unindented`.
- `tree.json` maps a key (for example `dn-1-1`) to
  `[paliName, sinhalaName, level, [pageIndex, entryIndex], parentKey,
  fileName]`. Keys starting `atta` or `anya` are ignored by the app.
  Children are ordered by the number at the end of their key, as the
  source does (`dfsOrder` in `build/tree.ts`).
- 9,414 nodes are in scope, 8,355 of them leaves, up to seven levels deep;
  the longest list has 90 items.

**What a reading is.** A node's own text runs from its start position to
the start of the next node in the same file (or the file's end; the exact
rule is under "Answers to a builder's questions"). A leaf opens as a reading of its own text. A node with children
lists its children; if its own text holds more than headings (true of 53
nodes), the list starts with a row that opens that text. Title lines
that belong to no reading of their own are shown at the top of the
reading that follows them, so nothing is unreachable.

**Sync tool** (`tools/sync_tipitaka.py`, run as
`python -I -X utf8 tools/sync_tipitaka.py . …`):

- `--from <clone>` packs the files from a local clone of the source into
  `assets/tipitaka/` and rewrites the manifest; `--fetch` first updates a
  sparse clone under `source_material/tipitaka_lk/` itself.
- `--check` (no network) confirms every shipped file unpacks to the
  manifest's hash, that the set of files matches the manifest, that every
  in-scope tree node points at an existing file and entry, and that every
  entry belongs to exactly one reading. It joins the project's check list
  and `docs/release-checklist.md`.
- It never edits text. Downloaded files are read as data only.

A second check reports any character in the shipped text that the bundled
fonts cannot draw. It reports; it does not alter the text.

## The app

New code lives in `lib/tipitaka/`. The gatha reader, Library and Home are
not changed.

**Loading.** The tree is unpacked and parsed the first time the tab is
opened and kept for the session. A book file is unpacked and parsed when a
reading in it is opened; a few recently used books stay in memory. Parsing
runs off the main thread where the platform allows. While loading, a
quiet progress mark shows; a file that fails to load gives a plain message
with a way back, not a blank page.

**Bottom bar and rail.** Five tabs: Home, Library, Tripitaka, Saved,
Settings (the new one third). Same style as now. On a 320 px wide phone
and at 200% text no label is cut off or broken inside a word; the bar may
tighten its margins to manage that.

**Tab's first page** (`/tipitaka`): title "ත්‍රිපිටකය" with "Tripitaka"
under it; a search field; a "Continue reading" card when a place is
remembered (sutta name, where it sits, progress); then three large cards
for the pitakas, each with its Sinhala name from the tree, an English
interface label (Vinaya Pitaka, Sutta Pitaka, Abhidhamma Pitaka) and how
many texts it holds. The cards use the shared card look and drawn marks,
no new pictures.

**List pages** (`/tipitaka/n/<key>`, inside the tab so the bar stays):
the node's name as title; a breadcrumb line of its ancestors, each one
tappable, scrolling sideways if long; then its children as rows: the
Sinhala name, the Pali name under it, and either the number of texts
inside or, for a leaf, nothing but the chevron. A leaf that has been
opened shows its progress line. The five nikayas also carry an English
interface label (Digha, Majjhima, Samyutta, Anguttara, Khuddaka Nikaya).
Names are shown as the tree gives them. Back goes one level up, the same
on every platform and after a web reload. Lists are built lazily.

**Search.** Typing in the field replaces the page with matching nodes (any
level), best first, at most 50, each with its path as a caption. A name
matches on its Sinhala name or its Pali name, ignoring joiners, spaces and
punctuation. Typing in Latin letters also works: each Pali name gets a
plain a–z search key by mechanical transliteration (never displayed), so
"brahmajala" finds බ්‍රහ්මජාලසුත්තං. No result gives the shared empty
state.

**Reader** (`/tipitaka/read/<key>`, full screen like the gatha reader):

- Top: back, the sutta's name, a bookmark button, and the settings button
  (the existing text size, line spacing and theme controls).
- A three-way switch: පාලි · සිංහල · both. On a phone "both" shows each
  Pali entry followed by its Sinhala; on a wide screen it shows two
  columns with paired entries level with each other, as thripitakaya.org
  does. The choice is remembered. First-run default: both on wide
  screens, සිංහල on phones.
- Entries are drawn by type: `centered` centred, `heading` as a heading
  sized by its level, `paragraph` as a paragraph, `gatha` as verse with
  its line breaks kept, `unindented` flush left.
- Markup in the text is drawn, not shown raw, following the source's
  `shared/markup.ts`: `**bold**`, `__underline__`, `~~struck~~`,
  `##marked##`, `$$editorial$$`, `{n}` footnote marks. A footnote mark is
  a small raised number; tapping it shows that page's footnote in a sheet.
- Pali letters are joined for display the way the source site does it by
  default (`shared/beautify.ts`: rakaransaya, yansaya and its common
  conjuncts). This happens only while drawing; the stored text is not
  touched.
- Where the source has no Sinhala for an entry (1,660 of the 15,156
  pages have none, nearly all in the Patthana), the සිංහල view shows the
  Pali entry with a quiet note that the source has no Sinhala here.
- A thin progress line; at the end, previous and next buttons naming the
  neighbouring readings in tree order (crossing books).
- The place is remembered per reading (entry and how far into it) and
  restored on return; the most recent 200 are kept.
- Long texts are built lazily so the largest (the Patthana) opens without
  a freeze.

**Saved.** The bookmark button saves the reading. The Saved tab gains a
"Tripitaka" group listing them (name and path, newest first); tapping
opens the reader; Back from there returns to Saved. Stored under its own
key, so existing saved data is untouched.

**Storage keys** (new, each tolerant of damaged data as the existing ones
are): `namo.tipitaka.places.v1` (places and the last-read reading),
`namo.tipitaka.saved.v1` (bookmarks), `namo.tipitaka.view.v1` (the
language switch).

**Sources page.** A new entry: the Tripitaka text is the Buddha Jayanti
Tripitaka Pali text and its Sinhala translation as published by
tipitaka.lk (repository address), under CC BY-ND 4.0, unmodified, with the
date of the version shipped (from the manifest); that Namo is not
connected to tipitaka.lk; and that errors in the text should be reported
to path.nirvana@gmail.com. `docs/` gets a short note on how to re-sync.

## Edge cases the builder must cover

- 320 px phone, 1280 px window, 200% text, both themes, reduce motion.
- Screen reader: tabs, breadcrumbs, rows ("name, n texts"), the language
  switch, footnote marks.
- A key in the address that does not exist: the not-found page.
- A remembered place or bookmark whose key is gone after a sync: dropped
  quietly.
- Opening a reading straight from a web address (no tree loaded yet).
- Books that put a heading after its text (`headingAtEndKeys` in the
  source): reading spans follow the tree's positions, not the headings.
- Pali-only books (seven files, all `ap-pat*`): the reader shows Pali
  alone with one note at the top instead of a note on every entry; the
  switch stays but සිංහල and "both" show the same Pali.

## Answers to a builder's questions

- **File sizes.** The largest book is `ap-pat.json` at 2.9 MB unpacked,
  then `kn-mn-6.json` at 2.0 MB; the average is 0.9 MB. No file is big
  enough to need a different loading method on web: unpack and parse
  there in one go, yielding to the frame before and after. Target: a
  reading shows within about a second on a mid-range phone, and the
  loading mark appears at once.
- **Licence condition 3** reads "an automated script or another easy
  manual method". A script run by hand before each release meets it; no
  scheduled job is added. The release checklist gets the step "run the
  sync, then the check".
- **Reading spans, exactly** (measured on the real data, 2026-11-12).
  Flatten a file's entries in page order. Take the in-scope nodes of the
  file and sort them by start position (page, then entry), ties in tree
  order; in every file this is also tree order. A node's own span is the
  entries from its start up to the next node's start, or to the file's
  end. A node is a **reading** if it is a leaf, or if its own span holds
  a `paragraph`, `gatha` or `unindented` entry with text (53 parents;
  the sync tool lists them in the manifest so the app need not open
  books to know). That gives 8,408 readings. What a reading shows runs
  from the end of the previous reading's own span in the file (or the
  file's start) to the end of its own span. So the title lines of the
  parents above it (1,101 `heading` and `centered` entries in all) and
  the few title entries that 54 files carry before their first node
  appear at the top of the reading that follows them, and every entry
  of every file is shown in exactly one reading. No file ends with a
  node that is not a reading. A parent's children may sit in other
  files (559 do); spans are worked out per file, so that changes
  nothing. The heading-at-end books need no special handling.
- **Pairing.** Pali and Sinhala entries pair by index on every page
  except in the seven Pali-only `ap-pat*` files, whose Sinhala lists are
  empty. A page whose two lists differ in length is treated as having no
  Sinhala.
- **Footnotes** belong to a page and a language. A mark in an entry
  points into that page's list for that language (`shared/footnote.ts`
  in the source shows the matching). Two readings that share a page each
  read from the same list.
- **Back** on list pages means "go to the parent's page", not "pop", so
  it behaves the same after a reload or a deep link. Back from the reader
  goes to Saved if it was opened from Saved, otherwise to the list page
  of the reading's parent.
- **Places.** The 200 kept are the 200 most recently read. "Continue
  reading" points at the most recent of those whose key still exists.
- **Markup and joining must match the source**, not approximate it. The
  clone carries the source's own test vectors: `shared/markup-cases.json`
  and `e2e/legacy/goldens/beautify.json`. The Dart ports are tested
  against them (those vectors that apply to the default display options;
  copies go in `test/fixtures/tipitaka/` with a note of where they came
  from). Joining adds only invisible joiner characters at draw time, as
  the source's own site does; the stored and shipped bytes stay the
  source's. This is display, not modification.
- **Glyph check.** It must come back empty, apart from an allow-list of
  invisible format characters, for the check list to pass. If it finds a
  real letter the fonts cannot draw, the builder stops and reports it to
  the owner; no font is added and no text is changed without the owner.
- **Size limits.** None are set. About 16 MB is added to each platform's
  build; no deferred loading is needed.
- **Router.** The app uses go_router with a `StatefulShellRoute` of four
  branches (`lib/router.dart`) and the bar in
  `lib/design/widgets/app_shell.dart`; the new tab is a fifth branch in
  third place, and the reader is a top-level route like `/read/:id`.

## Left to the builder

Class and file layout inside `lib/tipitaka/`, spacing, the drawn marks on
the pitaka cards, how many books stay in memory, how matches are ranked,
the transliteration table for the search key, how tests are organised
(small made-up fixtures for unit tests, plus at least one test that reads
a real shipped book).

## Calls made by the designer, for the owner to check

- Tab label is "Tripitaka", not "Thripitakaya": five labels must fit
  across a phone, and the longer word does not.
- One new package (`archive`) so the text ships at about 16 MB instead of
  about 170 MB on every platform.
- Names in lists are tipitaka.lk's (for example "දික් සඟිය" where
  thripitakaya.org says "දීඝ නිකාය"), because the text may not be changed;
  English labels sit beside the top two levels.
- Phones open in සිංහල by default; wide screens in both.
- Commentaries are left out; search is by name only.
- The roughly 16 MB of packed text is committed to the repository.
