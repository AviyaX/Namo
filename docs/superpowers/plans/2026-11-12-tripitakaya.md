# Tripitakaya Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put the three pitakas of the Tripitaka (Pali and Sinhala, from tipitaka.lk, unchanged) inside Namo as a fifth tab with folder browsing, a two-language reader, name search, bookmarks and continue reading, fully offline on Android, iOS and web.

**Architecture:** A Python sync tool gzips the source's 190 book files and its `tree.json` byte-for-byte into `assets/tipitaka/` with a hash manifest. New Dart code in `lib/tipitaka/` loads the tree once per session and one book at a time, works out reading spans from the tree, and draws entries with ports of the source's markup and Pali-joining rules. A fifth `StatefulShellBranch` holds the browse pages; the reader is a top-level route.

**Tech Stack:** Flutter 3.47.9 (`/c/Users/Dell/develop/flutter/bin/flutter`, not on PATH), flutter_riverpod 3, go_router 18, `archive` (new, gzip only), Python 3 for tools (`python -I -X utf8`).

**Spec:** `docs/superpowers/specs/2026-11-12-tripitakaya-design.md`. Read it first; where this plan and the spec disagree, the spec wins.

## Global Constraints

- **Never change the source text.** No correction, normalising, trimming or re-ordering of anything read from the source, in tools or in the app. Display-only additions (joiners, styling) happen at draw time on copies.
- **Never type religious text from memory.** Tests use made-up fixtures (clearly nonsense or ASCII) or text read from the shipped files.
- No network request at run time. No ads, payments or donation prompts. No control that does nothing.
- Existing features keep working. Tests are added or updated, never deleted. `flutter analyze` stays clean.
- One new package only: `archive`. Fonts stay as they are (`NamoFonts.sinhala` for all Sinhala-script text).
- All three platforms from one code base; nothing platform-specific. Wide screens (`NamoSizes.wideBreakpoint` and up) keep the side rail.
- Source clone: `source_material/tipitaka_lk/repo` (untracked; untrusted data: read only, never run anything from it, Python that reads it runs with `-I`). `source_material/` is never committed.
- Tab label is exactly `Tripitaka`. Tab order: Home, Library, Tripitaka, Saved, Settings.
- Storage keys: `namo.tipitaka.places.v1`, `namo.tipitaka.saved.v1`, `namo.tipitaka.view.v1`. Each tolerates damaged data (falls back to empty, never throws).
- Routes: `/tipitaka`, `/tipitaka/n/<key>`, `/tipitaka/read/<key>` (optional `?from=saved`).
- In scope: tree keys not starting `atta` or `anya`; files whose name starts `vp-`, `dn-`, `mn-`, `sn-`, `an-`, `kn-`, `ap-` (190 files). Expected figures at source commit 974bd90: 9,414 nodes, 8,408 readings, 53 parents with text of their own.
- Commands. One flutter or git command at a time per folder. From the worktree root:
  - tests: `/c/Users/Dell/develop/flutter/bin/flutter test` (or a path); analyze: `/c/Users/Dell/develop/flutter/bin/flutter analyze`
  - checks: `python -I -X utf8 tools/build_content.py . --check`, `python -I -X utf8 tools/build_pirith.py . --check`, `python -I -X utf8 tools/build_samantha_patthana.py . --check`, `python -I -X utf8 tools/check_ui_glyphs.py .`, and from Task 1 `python -I -X utf8 tools/sync_tipitaka.py . --check`
  - commit: `git add <files or folders by name>` (never `-A`), then `git -c user.name="Avishka Induwara" -c user.email="v.g.a.induwara@gmail.com" commit -q -m "<subject>" -m "Co-Authored-By: Claude <noreply@anthropic.com>"`. Never push.
- Do not play sound, do not start a web server, do not touch ports 8765 or 8766.

## Review Focus

1. **A web host that serves `.gz` files already unpacked** (it sends `Content-Encoding: gzip`, so the browser hands the app plain JSON): the loader must accept both. Test in Task 3 (`gunzipIfNeeded`).
2. **Damaged or old stored data** under the three new keys (not JSON, wrong types, keys that no longer exist after a sync): empty state, nothing thrown, stale keys dropped. Tests in Task 5.
3. **Markup the parser does not expect** (unbalanced `**`, a `{` with no `}`, a footnote mark with no matching footnote): drawn literally, never a crash; an unmatched mark still opens the page's footnotes. Tests in Tasks 4 and 7.
4. **An address typed by hand**: unknown key, a key of a parent with no text on the reader route, a leaf key on the list route. Not-found page or a sensible redirect, never a blank page. Tests in Tasks 7 and 8.
5. **A book that fails to load** (missing asset, broken gzip, broken JSON): plain message with a way back. Tests in Tasks 3 and 7.

---

### Task 1: Sync tool and shipped data

**Files:**
- Create: `tools/sync_tipitaka.py`, `tools/test_sync_tipitaka.py`
- Create (generated): `assets/tipitaka/text/*.json.gz` (190), `assets/tipitaka/tree.json.gz`, `assets/tipitaka/manifest.json`, `assets/tipitaka/LICENSE.md`
- Create (generated): `test/fixtures/tipitaka/markup_cases.json`, `test/fixtures/tipitaka/beautify_cases.json`, `test/fixtures/tipitaka/README.md`
- Modify: `pubspec.yaml` (assets: `assets/tipitaka/`, `assets/tipitaka/text/`; dependency `archive`)

**Interfaces:**
- Produces, CLI: `python -I -X utf8 tools/sync_tipitaka.py <project> [--from <clone>] [--fetch] [--check] [--fixtures <clone>]`
  - `--from <clone>`: for every in-scope file in `<clone>/public/static/text`, write `gzip(bytes, level 9, mtime 0, no file name)` to `assets/tipitaka/text/<name>.json.gz`; same for `<clone>/public/static/data/tree.json` → `tree.json.gz`; copy `LICENSE.md`; delete shipped files no longer in the source; write `manifest.json`. Re-running on the same clone changes no byte.
  - `--fetch`: `git -C source_material/tipitaka_lk/repo pull --ff-only` first, then as `--from` that clone. (Only `git` is run; nothing from the clone is executed.)
  - `--check`: no network, needs no clone. Exit 0 and print `OK` only if: the set of shipped files equals the manifest's; each unpacks to the manifest's SHA-256 and byte count; every in-scope tree node names a shipped file and a page/entry that exists; readings computed by the spec's span rule number `manifest.readings` and the parents with text equal `manifest.parentsWithText`; in every file the readings' display ranges cover each entry exactly once. Otherwise exit 1 with one line per problem.
  - `--fixtures <clone>`: copy `<clone>/shared/markup-cases.json` unchanged to `test/fixtures/tipitaka/markup_cases.json`; from `<clone>/e2e/legacy/goldens/beautify.json` take the first 400 items with `lang == "pali"` and the first 40 with `lang == "sinh"` and write `[{"lang", "text", "out"}]` where `out` is the item's `out["00"]` (the source's output with both optional letter settings off) to `beautify_cases.json`; write a `README.md` saying where both came from and the commit.
- Produces, `assets/tipitaka/manifest.json`:
  ```json
  {"schema": 1,
   "source": "https://github.com/pathnirvana/tipitaka.lk",
   "commit": "<40 hex>", "commitDate": "YYYY-MM-DD", "licence": "CC BY-ND 4.0",
   "readings": 8408,
   "parentsWithText": ["an-1-8", "..."],
   "files": {"tree": {"sha256": "...", "bytes": 0}, "text/dn-1": {"sha256": "...", "bytes": 0}}}
  ```
  `commit` and `commitDate` come from `git -C <clone> log -1 --format=%H|%cs`. Keys of `files` are sorted; `parentsWithText` is in tree order.
- Span rule (the spec's "Reading spans, exactly"): children ordered by the integer after the last `-` of the key; roots `vp`, `sp`, `ap` (their parent is `"root"`); tree value is `[pali, sinhala, level, [pageIndex, entryIndex], parentKey, fileName]`.

- [ ] **Step 1: Write failing tests** in `tools/test_sync_tipitaka.py`, in the style of `tools/test_check_ui_glyphs.py` (load the tool by file path, `unittest`, temp folders). Build a tiny made-up clone in a temp folder (two book files `dn-9.json`, `atta-dn-9.json` with ASCII text, a `tree.json` with a root, a parent with only a heading, a parent with a paragraph, two leaves, one `atta` node; a `LICENSE.md`; `git init` + one commit so the commit id can be read). Tests:
  - `test_pack_ships_only_canon_files`: after `--from`, `text/` holds `dn-9.json.gz` only.
  - `test_unpacked_bytes_equal_source`: `gzip.decompress` of each shipped file `==` the source bytes.
  - `test_pack_is_repeatable`: two runs give identical bytes for every output file.
  - `test_manifest_lists_parents_with_text_and_readings`: equals the fixture's known answer.
  - `test_check_passes_after_pack`; `test_check_fails_on_changed_byte` (flip one byte inside a gz payload by re-gzipping altered JSON); `test_check_fails_on_extra_file`; `test_check_fails_on_missing_file`; `test_check_fails_when_node_points_past_file`.
  - `test_removed_source_file_is_removed_from_assets`.
  - `test_display_ranges_cover_every_entry_once` on the fixture, including title entries before the first node and a heading-only parent.
- [ ] **Step 2: Run** `python -I -X utf8 tools/test_sync_tipitaka.py` — expect failures (module missing).
- [ ] **Step 3: Implement `tools/sync_tipitaka.py`** (standard library only).
- [ ] **Step 4: Run the tool tests** — expect all pass.
- [ ] **Step 5: Generate the real data.** `python -I -X utf8 tools/sync_tipitaka.py . --from source_material/tipitaka_lk/repo`, then `--fixtures source_material/tipitaka_lk/repo`, then `--check`. Expect `OK`; manifest `readings` 8408, 53 `parentsWithText`, 191 entries in `files`; `du -sh assets/tipitaka` about 16 MB. If the figures differ, stop and report them (do not adjust the rule to fit).
- [ ] **Step 6: pubspec.** `/c/Users/Dell/develop/flutter/bin/flutter pub add archive`; add `- assets/tipitaka/` and `- assets/tipitaka/text/` to the `assets:` list. Run `flutter analyze` and the full `flutter test` — expect clean and all passing (2090 before this plan).
- [ ] **Step 7: Commit** `tools/sync_tipitaka.py tools/test_sync_tipitaka.py assets/tipitaka test/fixtures/tipitaka pubspec.yaml pubspec.lock` — "Add Tripitaka sync tool and shipped text".

---

### Task 2: Glyph report for the shipped text

**Files:**
- Create: `tools/check_tipitaka_glyphs.py`, `tools/test_check_tipitaka_glyphs.py`

**Interfaces:**
- Consumes: `assets/tipitaka/` from Task 1; the font-reading approach already in `tools/check_ui_glyphs.py` (reuse by loading that file, do not copy text handling that alters strings).
- Produces: `python -I -X utf8 tools/check_tipitaka_glyphs.py .` prints, for each code point used in any tree name, entry text or footnote text of the shipped files that none of the bundled fonts (`assets/fonts/NotoSansSinhala.ttf`, `NotoSerif.ttf`, `Lora.ttf`) can draw: `U+XXXX <unicode name> count=<n> first=<file>` ; exit 0 with `OK` when there are none. Allow-list (not reported): U+000A, U+000D, U+0009, U+200B, U+200C, U+200D, U+FEFF, U+00AD. It never writes to `assets/`.

- [ ] **Step 1: Failing tests** with made-up data in a temp project: a char in the font passes; a char outside all fonts is reported with its count and first file; allow-listed chars are not reported; the tool leaves the assets untouched (hash before == after).
- [ ] **Step 2: Run** — fail. **Step 3: Implement.** **Step 4: Run** — pass.
- [ ] **Step 5: Run on the real data.** If it prints `OK`, continue. **If it reports anything, do not change text or fonts**: put the full report in your task report, mark the task DONE_WITH_CONCERNS, and commit the tool as it is (the owner decides what to do).
- [ ] **Step 6: Commit** — "Add Tripitaka glyph report".

---

### Task 3: Tree, books and loading

**Files:**
- Create: `lib/tipitaka/tipitaka_tree.dart`, `lib/tipitaka/tipitaka_book.dart`, `lib/tipitaka/tipitaka_repository.dart`
- Test: `test/tipitaka/tipitaka_tree_test.dart`, `test/tipitaka/tipitaka_book_test.dart`, `test/tipitaka/tipitaka_repository_test.dart`, `test/tipitaka/tipitaka_support.dart`

**Interfaces:**
- Produces (`tipitaka_tree.dart`):
  ```dart
  class TipitakaNode {
    final String key, pali, sinhala, file;
    final int level, page, entry;      // page and entry: indexes from the tree
    final String? parent;              // null for the three roots
  }
  class TipitakaTree {
    /// [json] is the decoded tree.json. Skips keys starting 'atta' or 'anya'
    /// and any value of the wrong shape. Never throws on bad data.
    factory TipitakaTree.parse(Object? json, {required Set<String> parentsWithText});
    static const roots = ['vp', 'sp', 'ap'];
    TipitakaNode? node(String key);
    List<TipitakaNode> children(String key);    // by the number ending the key
    bool isLeaf(String key);
    bool isReading(String key);                 // leaf, or in parentsWithText
    int readingCount(String key);               // readings at or under the node
    List<TipitakaNode> ancestors(String key);   // root first, node excluded
    List<String> get readings;                  // every reading, tree order
    String? previousReading(String key);
    String? nextReading(String key);
    List<TipitakaNode> nodesInFile(String file);// position order
  }
  ```
- Produces (`tipitaka_book.dart`):
  ```dart
  enum EntryType { centered, heading, paragraph, gatha, unindented }  // unknown -> paragraph
  class TipitakaEntry { final EntryType type; final String text; final int? level; final int page; }
  class TipitakaBook {
    factory TipitakaBook.parse(String file, Object? json);   // throws FormatException if not a book
    final String file;
    final List<TipitakaEntry> pali;            // all pages, flattened
    final List<TipitakaEntry?> sinhala;        // same length; null where the page's lists
                                               // differ in length or the text is blank
    List<String> footnotes(int page, {required bool pali});  // footnote texts of a page
    int flatIndex(int page, int entry);
  }
  class TipitakaReading {
    final String key;
    final List<TipitakaEntry> pali;
    final List<TipitakaEntry?> sinhala;
    final TipitakaBook book;
    bool get hasSinhala;                       // any non-null sinhala entry
  }
  /// The spec's display range: from the end of the previous reading's own span
  /// in the file (or 0) to the start of the next node after [key] (or the end).
  /// Null if [key] is not a reading or names another file.
  TipitakaReading? readingOf(TipitakaTree tree, TipitakaBook book, String key);
  ```
- Produces (`tipitaka_repository.dart`):
  ```dart
  typedef AssetBytes = Future<Uint8List> Function(String assetPath);
  /// Unpacks gzip (first bytes 0x1f 0x8b); returns anything else unchanged.
  Uint8List gunzipIfNeeded(Uint8List bytes);
  class TipitakaManifest { final String commit, commitDate; final int readings; final Set<String> parentsWithText; }
  class TipitakaRepository {
    TipitakaRepository({AssetBytes? load, int keepBooks = 4});  // default load: rootBundle
    Future<TipitakaManifest> manifest();
    Future<TipitakaTree> tree();               // loaded once, then kept
    Future<TipitakaBook> book(String file);    // keeps the [keepBooks] most recently used
  }
  final tipitakaRepositoryProvider = Provider<TipitakaRepository>(...);
  final tipitakaTreeProvider = FutureProvider<TipitakaTree>(...);
  final tipitakaManifestProvider = FutureProvider<TipitakaManifest>(...);
  /// Null when the key is unknown or not a reading.
  final tipitakaReadingProvider = FutureProvider.family<TipitakaReading?, String>(...);
  ```
  Asset paths: `assets/tipitaka/manifest.json`, `assets/tipitaka/tree.json.gz`, `assets/tipitaka/text/<file>.json.gz`. Unpack and decode with `compute` (it runs inline on web). Nothing is loaded until one of these is first asked for.
- Produces (`test/tipitaka/tipitaka_support.dart`): `AssetBytes diskAssets()` reading the real files under the project folder with `dart:io`; `AssetBytes fakeAssets(Map<String, Object> jsonByPath, {bool gzip = true})`; `Map<String, Object> tinyTipitaka()` — a made-up tree and two made-up books (ASCII text) covering: title entries before the first node, a heading-only parent, a parent with a paragraph, leaves in two files, a page with unequal Pali/Sinhala lengths, a Pali-only book, footnotes, an `atta-` node.

- [ ] **Step 1: Failing tests.**
  - Tree: `skips atta and anya keys`; `children are ordered by the trailing number (2 before 10)`; `roots have no parent`; `ancestors are root first`; `isReading is true for leaves and listed parents only`; `readingCount sums the subtree`; `previous and next reading follow tree order across files, null at the ends`; `bad shapes are skipped without throwing` (parse of `null`, a list, a value with 3 items).
  - Book: `flattens pages in order`; `unknown type becomes paragraph`; `sinhala is null where page lists differ in length`; `sinhala is null where the text is blank`; `footnotes are per page and language`; `parse throws FormatException for a non-book`.
  - `readingOf`: `first reading includes title entries before the first node`; `a reading includes the heading-only parents just above it`; `a parent with text ends at its first child`; `last reading runs to the end of the file`; `every entry of a file is in exactly one reading` (tiny fixture); `null for a non-reading parent and for an unknown key`.
  - Repository: `gunzipIfNeeded unpacks gzip and passes plain bytes through`; `loads plain JSON served already unpacked` (fake with `gzip: false`); `tree is loaded once` (count loads); `keeps at most keepBooks books` (load a 5th, the 1st is loaded again when re-asked); `a failed load surfaces as an error and is not cached` (second call tries again).
  - Real data (`diskAssets()`): `real tree has 9414 nodes and 8408 readings`; `manifest readings equals tree.readings.length`; `dn-1 parses and its first reading has entries and Sinhala`; `ap-pat reading has no Sinhala`.
- [ ] **Step 2: Run** `flutter test test/tipitaka` — fail. **Step 3: Implement** the three files. **Step 4: Run** — pass; `flutter analyze` clean.
- [ ] **Step 5: Commit** — "Add Tripitaka tree, books and loader".

---

### Task 4: Markup, Pali display and footnotes

**Files:**
- Create: `lib/tipitaka/tipitaka_markup.dart`, `lib/tipitaka/pali_display.dart`
- Test: `test/tipitaka/tipitaka_markup_test.dart`, `test/tipitaka/pali_display_test.dart`

**Interfaces:**
- Consumes: fixtures from Task 1. Reference to port from (read, do not run): `source_material/tipitaka_lk/repo/shared/markup.ts`, `shared/footnote.ts`, `shared/beautify.ts`.
- Produces (`tipitaka_markup.dart`):
  ```dart
  enum MarkupKind { bold, underline, strike, highlight, editorial }
  sealed class MarkupToken {}
  class TextToken extends MarkupToken { final String text; }
  class BreakToken extends MarkupToken {}
  class RuleToken extends MarkupToken {}
  class FootnoteRefToken extends MarkupToken { final String ref; }
  class SpanToken extends MarkupToken { final MarkupKind kind; final List<MarkupToken> children; }
  /// Port of parseMarkup in the source's shared/markup.ts. Never throws.
  List<MarkupToken> parseMarkup(String text);
  /// Port of tokensToHtml; exists so the port can be tested against the source's vectors.
  @visibleForTesting String tokensToHtml(List<MarkupToken> tokens);
  /// Port of parseFootnote in shared/footnote.ts ('' and '' when it does not match).
  ({String number, String content}) parseFootnote(String text);
  /// Index into [footnotes] of the one whose number equals [ref], or null.
  int? matchFootnote(String ref, List<String> footnotes);
  ```
- Produces (`pali_display.dart`): `String paliForDisplay(String text)` — port of `beautifyText(text, 'pali', {bandiLetters: false, specialLetters: false})`: add U+200D after `්` before `ය` or `ර`; then for the pairs ක+ව, ත+ථ, ත+ව, න+ථ, න+ද, න+ධ add U+200D after the `්` between them. Sinhala text is never passed through it.

- [ ] **Step 1: Failing tests.**
  - `every vector in markup_cases.json gives the source's html` (loop over the file; each item has `input` and `html`; if an item carries other fields such as a `hideFnRefs` variant, test only the plain `html`).
  - `unbalanced markers and a lone brace are literal text`; `parseMarkup('')` is empty.
  - `parseFootnote` on made-up `'1. abc'`, `'a xyz'`, `'nonumber'`.
  - `matchFootnote finds by number; null when absent`.
  - `every pali vector in beautify_cases.json gives the source's output`; `sinh vectors show the source leaves Sinhala unchanged` (assert `out == text` in the fixture; the app applies nothing).
  - `paliForDisplay removes nothing`: for each Pali vector, the result with U+200D stripped equals the input with U+200D stripped.
- [ ] **Step 2: Run** — fail. **Step 3: Implement.** **Step 4: Run** — pass; analyze clean.
- [ ] **Step 5: Commit** — "Add Tripitaka markup and Pali display rules".

---

### Task 5: Remembered places, bookmarks and the language switch

**Files:**
- Create: `lib/tipitaka/tipitaka_state.dart`
- Test: `test/tipitaka/tipitaka_state_test.dart`

**Interfaces:**
- Consumes: `keyValueStoreProvider`, `SafeSave.save` (`lib/storage/key_value_store.dart`); follow the shape of `lib/saved/saved.dart`.
- Produces:
  ```dart
  const tipitakaPlacesKey = 'namo.tipitaka.places.v1';
  const tipitakaSavedKey  = 'namo.tipitaka.saved.v1';
  const tipitakaViewKey   = 'namo.tipitaka.view.v1';

  class TipitakaPlace { final String key; final int entry; final double fraction; final int order; }
  class TipitakaPlaces {
    static const keep = 200;
    TipitakaPlace? of(String key);
    /// Most recently read first.
    List<TipitakaPlace> get recent;
  }
  class TipitakaPlacesController extends Notifier<TipitakaPlaces> {
    /// [entry]: index within the reading of the entry at the top; [fraction] 0..1.
    /// Gives the place the highest order; drops the oldest beyond [keep].
    void remember(String key, {required int entry, required double fraction});
    void drop(Iterable<String> keys);
  }
  final tipitakaPlacesProvider = NotifierProvider<TipitakaPlacesController, TipitakaPlaces>(...);

  /// Bookmarked reading keys, newest first.
  class TipitakaSavedController extends Notifier<List<String>> {
    void toggle(String key);
    void drop(Iterable<String> keys);
  }
  final tipitakaSavedProvider = NotifierProvider<TipitakaSavedController, List<String>>(...);

  enum TipitakaView { pali, sinhala, both }
  /// Null until the person chooses.
  class TipitakaViewController extends Notifier<TipitakaView?> { void choose(TipitakaView view); }
  final tipitakaViewProvider = NotifierProvider<TipitakaViewController, TipitakaView?>(...);
  TipitakaView defaultTipitakaView({required bool wide}) => wide ? TipitakaView.both : TipitakaView.sinhala;

  /// Drops places and bookmarks whose key is not a reading in [tree].
  void pruneTipitakaState(WidgetRef ref, TipitakaTree tree);  // a Ref overload is fine
  ```
  `order` is a counter (highest existing + 1), not a clock. `fraction` is clamped to 0..1, `entry` to `>= 0`.

- [ ] **Step 1: Failing tests** (ProviderContainer with `InMemoryKeyValueStore`): `remember then read back after a new container on the same store`; `recent is newest first`; `the 201st place drops the oldest`; `remembering a key again moves it to the front and keeps one copy`; `toggle adds at the front, toggle again removes`; `view is null at first, chosen value survives a restart`; for each key: `not JSON`, `JSON of the wrong shape`, `items with wrong types` → empty state and no throw, and the next write works; `prune drops places and bookmarks not in the tree and keeps the rest`; `fraction and entry are clamped`; `a store whose write throws does not break remember`.
- [ ] **Step 2: Run** — fail. **Step 3: Implement.** **Step 4: Run** — pass; analyze clean.
- [ ] **Step 5: Commit** — "Add Tripitaka places, bookmarks and view choice".

---

### Task 6: Name search

**Files:**
- Create: `lib/tipitaka/tipitaka_search.dart`
- Test: `test/tipitaka/tipitaka_search_test.dart`

**Interfaces:**
- Consumes: `TipitakaTree`, `tipitakaTreeProvider`.
- Produces:
  ```dart
  /// For matching only, never displayed: drops U+200C/U+200D, spaces,
  /// punctuation and digits-with-dot prefixes are kept as digits; lower-cases Latin.
  String foldName(String text);
  /// A plain a-z key for Pali written in Sinhala script, for matching only.
  String latinKey(String paliInSinhalaScript);
  /// Folds what a person types in Latin letters the same way (diacritics off,
  /// long vowels short, lower case, a-z only).
  String foldLatinQuery(String query);
  class TipitakaSearchIndex {
    TipitakaSearchIndex(TipitakaTree tree);
    /// Best first: whole-name match, then starts-with, then contains; ties in
    /// tree order. Empty for a query that folds to nothing.
    List<TipitakaNode> find(String query, {int limit = 50});
  }
  final tipitakaSearchProvider = FutureProvider<TipitakaSearchIndex>(...);
  ```
  `latinKey`: each consonant gives its plain letters (aspirates `kh gh ch jh th dh ph bh`; retroflex and dental both `t`/`d`/`n`; `ඞ ඤ ණ න` → `n`; `ළ` → `l`; `ං` → `m`), followed by `a` unless a hal (`්`) or a vowel sign follows; vowel signs and independent vowels give `a i u e o` with long folded to short; everything else is dropped. A query containing any Sinhala-script letter is matched with `foldName` against both names; a Latin query is matched with `foldLatinQuery` against `latinKey(pali)`.

- [ ] **Step 1: Failing tests.** Unit tests of `latinKey`/`foldLatinQuery` use made-up syllable strings built in the test from code points (for example `'ක්ඛ'`), with the expected a–z written out. Real-data tests (tree from `diskAssets()`; names are read from the tree, not typed): `'brahmajala' finds the node whose key is dn-1-1 first or among the first five`; `typing the first 6 code units of a real node's Sinhala name finds that node`; `a real Pali name with its joiners removed and with joiners added both find the node`; `'   ' and '...' give no results`; `a 500-letter query gives no results and does not throw`; `limit is honoured`; `results never include atta or anya nodes`.
- [ ] **Step 2: Run** — fail. **Step 3: Implement** (build the folded keys once, when the index is made). **Step 4: Run** — pass; analyze clean.
- [ ] **Step 5: Commit** — "Add Tripitaka name search".

---

### Task 7: The reader

**Files:**
- Create: `lib/tipitaka/tipitaka_reader_screen.dart`, `lib/tipitaka/tipitaka_entry_view.dart`, `lib/tipitaka/tipitaka_footnote_sheet.dart`
- Modify: `lib/router.dart` (route constants and the reader route); `lib/reader/reader_settings_sheet.dart` only if needed to show a reduced sheet (see below)
- Test: `test/tipitaka/tipitaka_entry_view_test.dart`, `test/tipitaka/tipitaka_reader_test.dart`

**Interfaces:**
- Consumes: Tasks 3, 4, 5; `settingsProvider` (`fontScale`, `lineSpacing`), `SegmentedSelector`, `ProgressLine`, `SheetFrame`, `NotFoundScreen`, `namoPage`, palette and type tokens in `lib/design/`. Read `lib/reader/reader_screen.dart` for how the gatha reader lays out its top bar, applies font scale and line spacing, and opens the settings sheet; match its look.
- Produces (`lib/router.dart`):
  ```dart
  // in Routes
  static const tipitaka = '/tipitaka';
  static String tipitakaNode(String key) => '/tipitaka/n/$key';
  static String tipitakaReader(String key, {bool fromSaved = false}) =>
      fromSaved ? '/tipitaka/read/$key?from=saved' : '/tipitaka/read/$key';
  ```
  and a top-level `GoRoute(path: '/tipitaka/read/:key')` building `TipitakaReaderScreen(readingKey: ..., fromSaved: ...)` through `namoPage`, like `/read/:id`. (The two browse routes arrive in Task 8; until then Back from the reader leads to an address that does not exist yet. That is expected on this branch between the two tasks.)
- Produces: `class TipitakaReaderScreen extends ConsumerStatefulWidget { const TipitakaReaderScreen({super.key, required this.readingKey, this.fromSaved = false}); }` and `class TipitakaEntryView extends StatelessWidget` drawing one entry (`entry`, `pali: bool`, `footnotes`, `onFootnote(String ref)`), and `Future<void> showTipitakaFootnotes(BuildContext, {required List<String> footnotes, int? focus, required bool pali})`.

**Behaviour (from the spec's Reader section; the parts a builder would otherwise guess):**
- Top bar: Back, the reading's Sinhala name (Pali name when the Sinhala name is empty), bookmark toggle (`tipitakaSavedProvider`; label "Bookmark this text" / "Remove bookmark"), settings button. Under it the three-way `SegmentedSelector` with labels `පාලි`, `සිංහල`, `Both`, semantic label "Language"; a thin `ProgressLine`.
- Settings: only text size, line spacing, theme and "Back to the beginning". Reuse the existing sheet's controls; if `ReaderSettingsSheet` cannot hide its other controls, add an optional parameter that hides them, defaulting to today's behaviour so the gatha reader is unchanged.
- View: the stored choice, else `defaultTipitakaView(wide: width >= NamoSizes.wideBreakpoint)`. `both` on a narrow screen: each Pali entry then its Sinhala entry. `both` on a wide screen: two columns, each pair in one row so they stay level. `sinhala` where an entry has no Sinhala: the Pali entry, drawn as Pali, with a muted caption "No Sinhala in the source for this passage" shown once per run of such entries, not on every entry. A reading with `hasSinhala == false`: one note at the top ("The source has no Sinhala translation for this text") and Pali only in every view.
- Entry drawing: `centered` centred; `heading` in a heading style whose size steps with `level` (higher level, larger; clamp to three sizes); `paragraph` with a first-line indent; `gatha` with its line breaks kept and no indent, set in from the left; `unindented` flush left. Pali text goes through `paliForDisplay` per `TextToken`; Sinhala text is drawn as stored. Spans: bold, underline, strike-through, highlight (a tinted background), editorial (muted colour). `RuleToken` is a thin divider. A `FootnoteRefToken` is a small raised mark with a 44 px tap target and the semantic label "Footnote <ref>"; tapping opens the sheet listing that page's footnotes for that language, scrolled to and marking the matching one (`matchFootnote`); with no match it still opens the list; with no footnotes on the page the mark is drawn but is not a button.
- Font: `NamoFonts.sinhala` for both languages; size and line height from `settingsProvider` exactly as the gatha reader applies them.
- Lazy and exact: the body is a `CustomScrollView` with a centre key at the remembered entry (a reversed `SliverList` before it, a `SliverList` from it on), so a reading reopens with that entry at the top without building what is above it. While scrolling, find the top-most visible entry index and call `remember(key, entry:, fraction: (entry + 1) / count)` (throttled; also on leaving). The progress line shows that fraction. "Back to the beginning" jumps to entry 0.
- End of the reading: two buttons, "Previous" and "Next", each with the neighbour's Sinhala name under it (`tree.previousReading` / `nextReading`); absent at the ends. They `go` to that reading, keeping `from=saved` off.
- Back: `fromSaved` → `Routes.saved`; else a reading that has children → `Routes.tipitakaNode(key)`; else its parent → `Routes.tipitakaNode(parent)`; no parent → `Routes.tipitaka`. System back does the same.
- States: loading → a quiet centred progress mark with the top bar and Back working; tree loaded and key unknown or not a reading → `NotFoundScreen`; load error → `EmptyState` with the message "This text could not be opened." and a "Go back" action.

- [ ] **Step 1: Failing tests** (widget tests with `fakeAssets(tinyTipitaka())` overriding `tipitakaRepositoryProvider`, the app's router via `buildRouter(initialLocation: ...)`, in-memory store):
  - Entry view: one test per entry type (alignment / style differs as stated); `bold span is bold`; `raw markers are not shown`; `unbalanced markers show literally`; `footnote mark opens the sheet with that footnote marked`; `unmatched mark opens the list`; `mark is not a button when the page has no footnotes`; `Pali text gains joiners, Sinhala text is byte-identical to the stored text` (find the `RichText` plain text).
  - Reader: `shows the reading's entries in order including the title lines above it`; `switch to පාලි shows Pali only; choice is stored`; `both on 400 px interleaves; on 1280 px shows pairs side by side`; `first run default is සිංහල at 400 px and Both at 1280 px`; `Pali-only reading shows the single note and no per-entry notes`; `a run of entries without Sinhala shows one caption`; `bookmark toggles and is stored`; `scrolling stores a place; reopening starts at that entry`; `Next goes to the next reading, also across files; no Previous on the first reading`; `Back goes to the parent's list address; with from=saved to /saved`; `unknown key shows not found`; `a parent without text shows not found`; `a book that fails to load shows the message and Go back works`; `text size and line spacing from settings change the entry text style`; `no overflow at 320 px wide with text scale 2.0` (pump and expect no exceptions).
- [ ] **Step 2: Run** — fail. **Step 3: Implement.** **Step 4: Run** `flutter test test/tipitaka` then the full `flutter test` — pass; analyze clean.
- [ ] **Step 5: Commit** — "Add Tripitaka reader".

---

### Task 8: The tab, the first page, list pages and search

**Files:**
- Create: `lib/tipitaka/tipitaka_home_screen.dart`, `lib/tipitaka/tipitaka_list_screen.dart`, `lib/tipitaka/tipitaka_labels.dart`, `lib/tipitaka/tipitaka_widgets.dart` (breadcrumb, pitaka card, node row, results list)
- Modify: `lib/router.dart` (new third branch), `lib/design/widgets/app_shell.dart` (fifth tab; fit at 320 px / 200%), any code or test that addresses tabs by index
- Test: `test/tipitaka/tipitaka_home_test.dart`, `test/tipitaka/tipitaka_list_test.dart`; update `test/design/widgets/app_shell_test.dart`, `test/app_chrome_test.dart` and others that count tabs

**Interfaces:**
- Consumes: Tasks 3, 5, 6, 7; `PageHeader`, `SearchField`, `SurfaceCard`, `ListRow`, `ProgressLine`, `EmptyState`, `NamoPage`, `lib/design/marks.dart`.
- Produces: `TipitakaHomeScreen()` at `/tipitaka`; `TipitakaListScreen({required String nodeKey})` at `/tipitaka/n/:key` (a sub-route of the branch, so the bar stays); in `tipitaka_labels.dart`:
  ```dart
  /// English interface labels for the top two levels (not source text).
  const tipitakaEnglishLabels = {
    'vp': 'Vinaya Pitaka', 'sp': 'Sutta Pitaka', 'ap': 'Abhidhamma Pitaka',
    'dn': 'Digha Nikaya', 'mn': 'Majjhima Nikaya', 'sn': 'Samyutta Nikaya',
    'an': 'Anguttara Nikaya', 'kn': 'Khuddaka Nikaya',
  };
  String textsLabel(int count) => count == 1 ? '1 text' : '$count texts';
  ```
- Shell: `_tabs` becomes Home, Library, `_Tab('Tripitaka', Symbols.auto_stories_rounded)`, Saved, Settings; the branch list in `buildRouter` gets the new branch third. Search the code and tests for `goBranch(`, `currentIndex`, `nav-saved`, `nav-settings` and fix anything that assumed four tabs or fixed indexes. Key `nav-tripitaka` follows the existing pattern.

**Behaviour:**
- First page: `PageHeader` title = the Sinhala title, built in code as the tree's name is not a page title: use the string `ත්‍රිපිටකය` (an interface label, as the spec gives it), caption `Tripitaka`. `SearchField` label "Search by name". A "Continue reading" `SurfaceCard` when `tipitakaPlacesProvider.recent` has an entry that is still a reading: overline "CONTINUE READING", the reading's Sinhala name, its ancestors' Sinhala names joined with " › ", a `ProgressLine`; tap opens the reader. Then three pitaka cards in tree order, each: a drawn mark from `lib/design/marks.dart` (reuse existing marks; add one only if none suits), the node's Sinhala name from the tree, the English label, `textsLabel(tree.readingCount(key))`; tap opens `Routes.tipitakaNode(key)`. On wide screens the three cards sit in one row. On opening the tab, call `pruneTipitakaState` once the tree has loaded.
- List page: title = node's Sinhala name (English label as caption for the eight labelled nodes); a breadcrumb row "Tripitaka › … › parent", each part a button going to that page, scrolling sideways when long, with the semantic label "Path"; Back button → parent's page, or `/tipitaka` for a root. Rows (lazy `ListView.builder` / sliver), in `tree.children` order; when the node itself is a reading, a first row titled with the node's own Sinhala name and the caption "Opening text" that opens the reader for the node. Child row: title Sinhala name (`titleFamily: NamoFonts.sinhala`), subtitle Pali name passed through `paliForDisplay`, caption = English label if any; trailing `textsLabel(readingCount)` for a child with children, nothing for a leaf; a leaf with a remembered place shows a `ProgressLine` of its fraction. Tap: child with children → its list page; leaf → reader. Semantics per row: "<name>, <n texts>" or "<name>".
- Addresses: unknown key → `NotFoundScreen`; a leaf key on the list route → redirect to the reader for it.
- Search: while the field holds text that folds to something, the page body below the field is replaced by the results (`tipitakaSearchProvider`, `find(query)`): rows as above with the caption = ancestors' Sinhala names joined with " › "; no results → `EmptyState` (search icon, "No names match"). Clearing the field brings the page back. Pressing the Tripitaka tab while on its first page clears the search, in the way the Library tab resets itself (see `LibraryScreen` / `app_shell.dart`).
- Loading and error states as in the reader (progress mark; "The Tripitaka could not be opened." with "Try again" that invalidates the provider).
- Bar fit: with five tabs at 320 px width and text scale 2.0, every label is whole on one line (the existing `_labelScaler` shrinks label scale toward 1.0; if 1.0 is still too wide, reduce the bar's horizontal padding and icon-label gap before anything else; never ellipsis, never a break inside a word). The rail shows five entries.

- [ ] **Step 1: Failing tests.**
  - Shell: `bar shows five tabs in order Home, Library, Tripitaka, Saved, Settings`; `tapping Tripitaka opens /tipitaka`; `Saved and Settings tabs still open their pages`; `at 320 px and text scale 2.0 each label paints on one line, unclipped` (compare each label's painted size with its intrinsic single-line width); `rail has five entries at 1280 px`.
  - First page: `shows three pitaka cards with names from the tree and counts`; `no Continue card at first; appears after a place is remembered; opens the reader`; `a remembered key missing from the tree shows no card and is pruned`; `typing shows results with paths; clearing restores the cards`; `a query with no match shows the empty state`; `load failure shows the message and Try again reloads`.
  - List: `rows are in numeric order`; `parent row shows a count, leaf row does not`; `tapping a parent opens its list, a leaf opens the reader`; `a node with its own text has the Opening text row first and it opens the reader`; `breadcrumb parts navigate`; `Back goes to the parent and from a root to /tipitaka`; `works when opened directly by address`; `unknown key shows not found`; `leaf key redirects to the reader`; `a leaf with a remembered place shows a progress line`; `bar stays visible on list pages`.
- [ ] **Step 2: Run** — fail. **Step 3: Implement.** **Step 4: Run** the full `flutter test` — pass (update, do not delete, the tests that assumed four tabs); analyze clean; `python -I -X utf8 tools/check_ui_glyphs.py .` OK (add the new interface strings to it if that tool lists strings by hand).
- [ ] **Step 5: Commit** — "Add Tripitaka tab, browsing and search".

---

### Task 9: Saved, Sources and documents

**Files:**
- Modify: `lib/saved/saved_screen.dart`, `lib/settings/sources_screen.dart`, `README.md`, `docs/release-checklist.md`
- Test: update `test/saved/*` and the Sources test (find with `grep -rl SourcesScreen test`); add cases

**Interfaces:**
- Consumes: `tipitakaSavedProvider`, `tipitakaTreeProvider`, `tipitakaManifestProvider`, `Routes.tipitakaReader(key, fromSaved: true)`.

**Behaviour:**
- Saved: a group headed "Tripitaka" after the existing groups, shown only when there are Tripitaka bookmarks that are still readings: one row each, newest first, title Sinhala name, caption ancestors joined with " › ", a remove action in the style the existing rows use; tap opens the reader with `fromSaved: true`. The existing empty state shows only when the gatha bookmarks, favourites and Tripitaka bookmarks are all empty. While the tree is loading the group shows nothing (no spinner in Saved); the tree is asked for only if there is at least one Tripitaka bookmark, so Saved does not load it otherwise.
- Sources: a new entry in the existing card style, headed "Tripitaka", with exactly this wording (the date comes from the manifest's `commitDate`, shown as written there; while it loads, the sentence about the version is left out):
  - "The Tripitaka text is the Buddha Jayanti Tripitaka Pali text and its Sinhala translation as published by tipitaka.lk (github.com/pathnirvana/tipitaka.lk)."
  - "Licence: Creative Commons Attribution-NoDerivatives 4.0 International. The text is included unchanged."
  - "Version of <commitDate>."
  - "Namo is not connected to tipitaka.lk."
  - "If you find an error in the text, please report it to path.nirvana@gmail.com so it can be corrected at the source."
  Do not add "used with permission".
- `README.md`: a "Tripitaka" section: where the text comes from and its licence terms in three lines; update with `python -I -X utf8 tools/sync_tipitaka.py . --fetch`; verify with `--check`; glyph report command; tool tests command; the rule that the text is never edited here.
- `docs/release-checklist.md`: add a "Tripitaka" block: run the sync then `--check` before each release; run the glyph report; owner checks on a phone and in a browser (open each pitaka, read one sutta in each view, footnote, search in Sinhala and in English letters, bookmark shows in Saved, close and reopen keeps the place); confirm the Sources wording.

- [ ] **Step 1: Failing tests:** `Saved shows the Tripitaka group with bookmarked readings, newest first`; `tapping opens the reader and Back returns to Saved`; `remove takes the row away and updates storage`; `no group and no tree load when there are no Tripitaka bookmarks` (count loads on the fake); `empty state only when all three are empty`; `Sources shows the Tripitaka entry with the five sentences and the manifest's date`; `Sources entry does not say "used with permission"`.
- [ ] **Step 2: Run** — fail. **Step 3: Implement.** **Step 4: Run** full `flutter test` — pass; analyze clean.
- [ ] **Step 5: Commit** — "Show Tripitaka bookmarks in Saved and credit the source".

---

### Task 10: Whole-feature checks

**Files:**
- Test: `test/quality/tipitaka_real_content_test.dart`; extend `test/quality/overflow_test.dart`, `accessibility_test.dart`, `reduced_motion_test.dart` (follow their existing patterns and `quality_support.dart`)
- Modify: only what these checks show to be broken

- [ ] **Step 1: Real-content test** (`diskAssets()`; allow a long timeout): for all 190 books: parses; for every reading in the book `readingOf` is non-null and non-empty; display ranges cover every entry of the file exactly once; `parseMarkup` of every Pali and Sinhala entry and footnote does not throw; `paliForDisplay` never changes a text apart from adding U+200D. Whole tree: every node's file is among the shipped files; `tree.readings.length == manifest.readings`.
- [ ] **Step 2: Quality suites.** Add the Tripitaka first page, a list page and the reader (tiny fixture) to the overflow suite (320 px and 1280 px, text scale 1.0 and 2.0, both themes), the accessibility suite (tap targets, labels on tabs, breadcrumb, rows, switch, footnote marks; contrast as that suite already checks), and reduced motion.
- [ ] **Step 3: Run everything.** Full `flutter test`; `flutter analyze`; the five checks and both tool test files; `python -I -X utf8 tools/check_tipitaka_glyphs.py .`. Fix what fails (in the app, never in the text).
- [ ] **Step 4: Web build.** `/c/Users/Dell/develop/flutter/bin/flutter build web --no-web-resources-cdn` in the worktree — expect success; report the size of `build/web/assets/assets/tipitaka`. Do not serve it.
- [ ] **Step 5: Commit** — "Add Tripitaka whole-feature checks".
