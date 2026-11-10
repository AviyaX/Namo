# Namo First Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Namo, a free offline Buddhist prayer-book app for Android, iOS and web, holding one reading of 19 sourced sections with a reader, language choice, auto-scroll, optional audio and saved progress.

**Architecture:** One Flutter codebase with no platform-specific branches. Content is one JSON asset made by a Python script from four stored source extracts and read through a repository interface. State lives in Riverpod notifiers that save through one small key-value interface (in memory until Stage 7, then shared_preferences). The reader lays the whole reading out in one scroll view; position is stored as section + verse + fraction, never pixels.

**Tech Stack:** Flutter 3.47.9 / Dart 3.13.7, flutter_riverpod, go_router, shared_preferences, just_audio, material_symbols_icons; dev: flutter_launcher_icons, flutter_native_splash; Python 3.13 (stdlib, plus PyMuPDF and Pillow already installed) for content and asset scripts.

**Spec:** `docs/superpowers/specs/2026-11-10-gatha-app-first-release-design.md` (the design; section numbers below such as "§5.3" refer to it). The owner's original brief is `docs/superpowers/specs/2026-11-09-owner-spec.md`; where they differ the design wins.

## Global Constraints

- **No religious text is typed, remembered, generated or "improved".** Verse text reaches the app only through `tools/build_content.py` reading `content/extracted/*.json`. Dart and Python tests may quote short strings that this plan quotes; nothing longer.
- App name shown to users: `Namo`. Dart package and folder stay `buddhist_gatha`. App IDs stay `com.example.buddhist_gatha` in this plan (they change before publishing, never to namo.lk's domain).
- Totally free: no ads, payments, donation prompts, analytics or network calls. The app makes no network request at run time.
- Palette, exact: ivory `#F5F1E8`, sand `#E8E0D2`, gold `#A88B5B`, forest `#354638`, charcoal `#292A26`. No gradients, no coloured cards, elevation 0 everywhere, hairline (1 px) borders, corner radius at most 8.
- Fonts are bundled, never fetched: Noto Sans Sinhala (Sinhala and Pali in Sinhala letters), Noto Serif (Roman Pali), Lora (English and interface). Every `TextStyle` in the app carries `fontFamilyFallback: ['NotoSansSinhala']`, so Flutter web never downloads a fallback font.
- Android, iOS and web change together: no `Platform.is…` or `kIsWeb` branches in `lib/`. Only the web build can be run on this machine; say so in every stage report.
- Languages: one or two of Sinhala, English, Pali; never three, never none. "Pali" shows the Sinhala-letter Pali.
- No text-to-speech and no generated chanting. The only audio file is a development tone, labelled as a placeholder, never offered in a release build.
- Every control: a screen-reader label and a touch area of at least 48 × 48. No sideways overflow at any setting.
- Run Flutter as `/c/Users/Dell/develop/flutter/bin/flutter` (it is not on PATH; written `flutter` below). Run Python as `python -I -X utf8`, with scripts as files, never inline.
- Git: commit locally after every task with the repo's identity (Avishka Induwara, v.g.a.induwara@gmail.com). Never push. End commit messages with `Co-Authored-By: Claude <noreply@anthropic.com>`.
- Add packages with `flutter pub add <name>` (or `--dev`); do not hand-write version numbers.

## Review Focus

Conditions the design implies but does not spell out, most likely first. Each has a test in the task named.

1. **A chosen language has no text for a verse or a whole section** (English is missing for sections 9, 14, 16, 17 and three single verses). Expected: the heading shows one quiet line, the verses show the other language or nothing, nothing crashes, and position restore still lands in that section. → Task 8, Task 10.
2. **Saved data is damaged or from an older shape** (broken JSON, an unknown language code, three saved languages, a bookmark for a section that no longer exists). Expected: the app starts with defaults for the bad part and keeps the good part. → Task 7, Task 13.
3. **A long gap between frames during auto-scroll** (browser tab in the background, phone unlocked again). Expected: the page moves by at most 100 ms' worth, never jumps. → Task 11.
4. **The user scrolls by something other than touch while auto-scroll runs** (mouse wheel, keyboard, scrollbar on web). Expected: auto-scroll pauses and does not pull the page back. → Task 11.
5. **A web address that names nothing** (`#/read/unknown`, `#/library/reading/x`, `?section=s99`). Expected: a plain "not found" page with a way home, or the reader opened at the top; never a red error screen. → Task 3, Task 9.

## File Map

| Path | Responsibility |
|---|---|
| `tools/build_content.py`, `tools/test_build_content.py` | Build and check the content file |
| `tools/make_icon_square.py`, `tools/make_placeholder_tone.py` | Icon with filled corners; development tone |
| `assets/content/namaskaraya_to_pin_dima.json` | The content (script output, never edited by hand) |
| `assets/fonts/`, `assets/branding/`, `assets/audio_dev/` | Fonts with licences; icon; placeholder tone |
| `lib/main.dart`, `lib/app.dart`, `lib/router.dart` | Start-up; `NamoApp`; routes and tab shell |
| `lib/design/{tokens,theme,typography}.dart`, `lib/design/widgets/` | Colours, themes, text styles, shared widgets |
| `lib/content/{model,content_repository}.dart` | Content model; repository interface and asset loader |
| `lib/storage/key_value_store.dart` | Storage interface, in-memory and shared_preferences versions |
| `lib/settings/{reading_language,settings,settings_screen,sources_screen}.dart` | Language rule; settings state; screens |
| `lib/home/home_screen.dart`, `lib/library/{library_screen,reading_contents_screen}.dart` | Home and Library tabs |
| `lib/reader/{reader_items,reader_screen,reader_body,reader_bottom_bar,reader_settings_sheet,reading_position,position_controller,auto_scroll}.dart` | The reader |
| `lib/saved/{saved,saved_screen}.dart` | Bookmarks and favourites |
| `lib/audio/{audio_catalogue,chant_player,audio_controls}.dart` | Audio |
| `test/` mirrors `lib/`; `test/support/` holds fakes and the test content | Tests |

## Stage Check

Run at the end of every stage (after Tasks 3, 5, 7, 10, 11, 12, 14, 15), before starting the next:

1. `flutter analyze` → "No issues found!"
2. `flutter test` → "All tests passed!"
3. From Stage 2 on: `python -I -X utf8 tools/build_content.py . --check` → `content file is up to date`.
4. `flutter build web`, serve `build/web` on localhost, open it in Chrome and look at every screen the stage touched, at 390 × 844 and 1280 × 800, in light and dark.
5. Report to the owner in plain words: what was built, what was seen, what could not be checked (Android, iOS). Attach screenshots after Stage 1 and Stage 4. Continue unless the owner objects.

---

## Stage 1: Design system and navigation

### Task 1: Packages, fonts, colours, type and themes

**Files:**
- Modify: `pubspec.yaml`, `lib/main.dart`; Delete: `test/widget_test.dart`
- Create: `assets/fonts/` (font files, `OFL-*.txt`, `README.md`), `lib/design/tokens.dart`, `lib/design/typography.dart`, `lib/design/theme.dart`, `lib/app.dart`
- Test: `test/design/theme_test.dart`

**Interfaces:**
- Produces:
  - `abstract final class NamoColors { static const ivory = Color(0xFFF5F1E8), sand = Color(0xFFE8E0D2), gold = Color(0xFFA88B5B), forest = Color(0xFF354638), charcoal = Color(0xFF292A26); }`
  - `class NamoPalette extends ThemeExtension<NamoPalette>` with `Color background, surface, divider, text, textQuiet, heading, accent`; `static const light`, `static const dark`; `static NamoPalette of(BuildContext)`.
  - `abstract final class NamoFonts { static const sinhala = 'NotoSansSinhala', romanPali = 'NotoSerif', english = 'Lora'; }`
  - `TextStyle namoText(String family, {required double size, required Color color, double height = 1.4, int weight = 400})`: sets `fontWeight` and `fontVariations: [FontVariation.weight(weight)]` (the fonts are variable fonts) and the Sinhala fallback.
  - `ThemeData namoTheme(Brightness brightness)`; `class NamoApp extends ConsumerWidget` (a `MaterialApp` titled `'Namo'` for now; Task 3 makes it a router app).
  - `abstract final class NamoSizes { static const readingColumn = 680.0, wideBreakpoint = 840.0, touchTarget = 48.0; }`
- Values: light palette = background ivory, surface sand, divider sand, text charcoal, textQuiet `#5F5E57`, heading forest, accent gold. Dark palette (my call, shown to the owner at the stage check) = background `#1E1F1C`, surface `#292A26`, divider `#3A3B36`, text `#E8E0D2`, textQuiet `#B5AD9E`, heading `#A9BFA9`, accent `#C9AE7C`. Gold is never used for text in the light theme (its contrast on ivory is under 3:1). Heading size 20, interface body 16; nothing larger than 22.

- [ ] **Step 1:** `flutter pub add flutter_riverpod go_router shared_preferences just_audio material_symbols_icons`, `flutter pub add --dev flutter_launcher_icons flutter_native_splash`, `flutter pub remove cupertino_icons`.
- [ ] **Step 2:** Download the variable TTFs and each `OFL.txt` from `https://raw.githubusercontent.com/google/fonts/main/ofl/{notosanssinhala,notoserif,lora}/` (list a folder with `https://api.github.com/repos/google/fonts/contents/ofl/<family>` if a name differs; upright and italic for Lora and Noto Serif, upright for Sinhala). Save under `assets/fonts/` with plain names (`NotoSansSinhala.ttf`, `Lora.ttf`, `Lora-Italic.ttf`, `NotoSerif.ttf`, `NotoSerif-Italic.ttf`, `OFL-<Family>.txt`). Write `assets/fonts/README.md` with each file's source URL and sha256. Declare the three families and the licence files in `pubspec.yaml`.
- [ ] **Step 3: Write the failing tests** in `test/design/theme_test.dart`:

```dart
test('palette holds the five spec colours', () {
  expect(NamoColors.ivory.toARGB32(), 0xFFF5F1E8);   // and sand, gold, forest, charcoal likewise
  expect(NamoPalette.light.background, NamoColors.ivory);
  expect(NamoPalette.light.text, NamoColors.charcoal);
});
test('text roles meet contrast in both themes', () {
  for (final p in [NamoPalette.light, NamoPalette.dark]) {
    expect(contrastRatio(p.text, p.background), greaterThanOrEqualTo(7.0));
    expect(contrastRatio(p.heading, p.background), greaterThanOrEqualTo(4.5));
    expect(contrastRatio(p.textQuiet, p.background), greaterThanOrEqualTo(4.5));
  }
  expect(contrastRatio(NamoPalette.dark.accent, NamoPalette.dark.background), greaterThanOrEqualTo(4.5));
});
test('every theme text style uses a bundled family and the Sinhala fallback', () {
  for (final b in Brightness.values) {
    final t = namoTheme(b).textTheme;
    for (final s in [t.titleLarge, t.titleMedium, t.bodyLarge, t.bodyMedium, t.labelLarge, t.bodySmall]) {
      expect(s!.fontFamily, NamoFonts.english);
      expect(s.fontFamilyFallback, contains(NamoFonts.sinhala));
      expect(s.fontSize, lessThanOrEqualTo(22));
    }
  }
});
test('themes are flat', () {
  final t = namoTheme(Brightness.light);
  expect(t.appBarTheme.elevation, 0);
  expect(t.cardTheme.elevation, 0);
  expect(t.extension<NamoPalette>(), NamoPalette.light);
});
```

`contrastRatio(Color a, Color b)` is a WCAG helper defined in the test file from `Color.computeLuminance()`.

- [ ] **Step 4:** Run `flutter test test/design/theme_test.dart` → fails to compile (names not defined).
- [ ] **Step 5:** Implement `tokens.dart`, `typography.dart`, `theme.dart`, `app.dart`; `main.dart` becomes `void main() => runApp(const ProviderScope(child: NamoApp()));`. Register each `OFL-*.txt` with `LicenseRegistry.addLicense` in `main.dart`. Delete the scaffold's `test/widget_test.dart`.
- [ ] **Step 6:** Run `flutter test` and `flutter analyze` → pass, no issues.
- [ ] **Step 7:** Commit: "Stage 1: fonts, colours, type and themes".

### Task 2: Name, icon and start-up screen

**Files:**
- Create: `tools/make_icon_square.py`, `assets/branding/namo_icon_square.png`, `assets/branding/README.md`
- Modify: `pubspec.yaml` (`flutter_launcher_icons`, `flutter_native_splash` sections; `assets/branding/` asset), `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`, `web/index.html`, `web/manifest.json`, `README.md`

**Interfaces:**
- Produces: `assets/branding/namo_icon_square.png` (1254 × 1254, no transparency), used by the icon tools and, in Task 14, by the Sources page. The corner colour's hex, written into `assets/branding/README.md`.

- [ ] **Step 1:** Write `tools/make_icon_square.py <src_png> <out_png>`: take the median colour of the opaque pixels within 12 px of the transparent corners' edge, lay the icon over a square of that colour, save without an alpha channel, print the hex. Nothing else in the picture changes.
- [ ] **Step 2:** Run it on `design/branding/namo_icon_owner_supplied.png`. The script also prints the result's size and mode, which must be `(1254, 1254) RGB`. Open the PNG with the Read tool and confirm the corners blend with no visible seam.
- [ ] **Step 3:** Configure `flutter_launcher_icons` (android, ios with `remove_alpha_ios: true`, web with `generate: true`; `image_path` = the square icon; web `background_color` and `theme_color` = the printed hex) and `flutter_native_splash` (`color` = the printed hex, `image` = the square icon, android, ios and web on). Run `dart run flutter_launcher_icons` and `dart run flutter_native_splash:create`. An Android adaptive icon is left until a device is available to look at it.
- [ ] **Step 4:** Set the shown name to `Namo`: `android:label`, `CFBundleDisplayName`, `CFBundleName`, `<title>`, `apple-mobile-web-app-title`, manifest `name` and `short_name`. Replace `README.md` with ten lines: what Namo is, that it is free, where the content comes from (point to the design), how to run tests and the content check.
- [ ] **Step 5: Verify.** `grep -rn "buddhist_gatha" android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist web/index.html web/manifest.json` shows only identifiers (bundle/package IDs), no shown name. `flutter build web` succeeds; `build/web/favicon.png` and `build/web/icons/Icon-192.png` show the Namo icon.
- [ ] **Step 6:** Commit: "Stage 1: app name, icon and start-up screen".

### Task 3: Routes, the four tabs and the wide layout

**Files:**
- Create: `lib/router.dart`, `lib/design/widgets/app_shell.dart`, `lib/design/widgets/not_found.dart`, placeholder screens `lib/home/home_screen.dart`, `lib/library/library_screen.dart`, `lib/saved/saved_screen.dart`, `lib/settings/settings_screen.dart`
- Modify: `lib/app.dart`
- Test: `test/router_test.dart`, `test/support/pump_app.dart`

**Interfaces:**
- Produces:
  - `abstract final class Routes { static const home = '/', library = '/library', saved = '/saved', settings = '/settings', sources = '/settings/sources'; static String category(String id) => '/library/category/$id'; static String contents(String readingId) => '/library/reading/$readingId'; static String reader(String readingId, {String? sectionId}); }` — reader is `/read/<readingId>` with an optional `?section=<id>`.
  - `final routerProvider = Provider<GoRouter>(...)`; a `StatefulShellRoute.indexedStack` with four branches (Home, Library, Saved, Settings). The reader route sits outside the shell (no tabs over the text). `errorBuilder` shows `NotFoundScreen`.
  - `class AppShell` : bottom `NavigationBar` under 840 wide, `NavigationRail` at 840 and over. Tab labels exactly `Home`, `Library`, `Saved`, `Settings`.
  - `class NotFoundScreen` : text `This page could not be found.` and a button `Go to Home`.
  - `Future<void> pumpApp(WidgetTester t, {List<Override> overrides = const [], String? location, Size size = const Size(390, 844)})` in `test/support/pump_app.dart`, used by every later widget test.

- [ ] **Step 1: Write the failing tests:**

```dart
testWidgets('four tabs switch screens', (t) async {
  await pumpApp(t);
  for (final label in ['Home', 'Library', 'Saved', 'Settings']) {
    await t.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
    await t.pumpAndSettle();
    expect(find.byKey(ValueKey('screen-${label.toLowerCase()}')), findsOneWidget);
  }
});
testWidgets('wide screens move the tabs to the side', (t) async {
  await pumpApp(t, size: const Size(1280, 800));
  expect(find.byType(NavigationRail), findsOneWidget);
  expect(find.byType(NavigationBar), findsNothing);
});
testWidgets('an unknown address shows the not-found page, not an error', (t) async {
  await pumpApp(t, location: '/no/such/place');
  expect(find.text('This page could not be found.'), findsOneWidget);
  await t.tap(find.text('Go to Home'));
  await t.pumpAndSettle();
  expect(find.byKey(const ValueKey('screen-home')), findsOneWidget);
  expect(t.takeException(), isNull);
});
```

- [ ] **Step 2:** Run `flutter test test/router_test.dart` → fails (not defined).
- [ ] **Step 3:** Implement. Icons come from `material_symbols_icons` at weight 300 (thin line); the selected tab uses `heading` colour, no indicator pill fill other than `surface`.
- [ ] **Step 4:** Run `flutter test` → pass.
- [ ] **Step 5:** Commit: "Stage 1: routes, four tabs, wide layout". Then run the **Stage Check** and send the owner screenshots of the empty tabs, light and dark, phone and wide.

---

## Stage 2: Home screen and the category

### Task 4: The content build script and the content file

**Files:**
- Create: `tools/build_content.py`, `tools/test_build_content.py`, `assets/content/namaskaraya_to_pin_dima.json`, `.gitattributes`
- Modify: `pubspec.yaml` (asset `assets/content/`), `content/review/00_START_HERE.md` (one line pointing to the built file), the design's §5.3 only if Step 1 finds a conversion fault
- Read: `content/extracted/{namo_lk,paritha_booklet,mahamevnawa_vandana,yasodhara_vandana}.json`, `content/review/04_english_booklet_yasodhara.md`

**Interfaces:**
- Produces the content file, shape:

```json
{"schema": 1,
 "categories": [{"id": "cat-namaskaraya", "title": "Namaskaraya to Deviyanta Pin Dima", "subtitle": "<heading 1> – <heading 18>",
   "readings": [{"id": "namaskaraya", "title": "Namaskaraya to Deviyanta Pin Dima", "audio": null,
     "sections": [{"id": "s01", "number": 1, "heading": "…", "check": "…",
       "source": {"name": "…", "locator": "…", "collected": "2026-11-09", "translator": "not named by the source"},
       "corrections": [],
       "verses": [{"id": "s01-v1", "pali_si": "…", "pali_roman": null, "sinhala": "…", "english": "… or null",
         "english_source": {"name": "…", "locator": "…", "collected": "…", "translator": "…"},
         "english_kind": "translation | explanation | null", "check": "…", "notes": [],
         "corrections": [{"field": "pali_si", "from": "…", "to": "…", "count": 1, "reason": "…"}]}]}]}]}]}
```

  `check` is one of `unchecked`, `checked against source`, `needs checking`. Lines inside a field are separated by `\n`, stanzas by `\n\n`. `english_source` is null when `english` is null.
- Produces in Python: `build(root: pathlib.Path) -> dict`, `render(data: dict) -> bytes` (UTF-8, `ensure_ascii=False`, `indent=1`, `\n` line ends, final newline), `main()` for `python -I -X utf8 tools/build_content.py <project_root> [--check]`. `--check` builds in memory, compares with the file, prints `content file is up to date` or exits 1 naming the first differing verse.

**Rules the script follows (all from §5):**

- *Sections 1–17:* walk the blocks of the `buddha-puja` item in `namo_lk.json`. A `heading` block opens a section (drop the leading `\d+\.\s*`); stop at the heading `Related Resources`. Each `pali` block with the `sinhala_meaning` block after it is one verse. A second `sinhala_meaning` in a row (the `සාධූ` line, block 59) joins the verse before it after `\n\n`. Strip only leading and trailing spaces of each line.
- *Sections 18–19:* from `paritha_booklet.json`, printed pages 37 and 38, by line index. `large` lines join with `\n` into `pali_si`; `small` lines join with a space into `sinhala`. Assert each index has the stated kind before using it.

| Verse | Page | `large` lines | `small` lines |
|---|---|---|---|
| s18-v1 | 37 | 2–3 | 5–6 |
| s18-v2 | 37 | 8–9 | 11–12 |
| s18-v3 | 37 | 14–15 | 17–18 |
| s18-v4 | 37 | 20–21, 23–24, 26–27 (three stanzas, joined by `\n\n`) | 29–30 |
| s19-v1 | 37 | 34–35 | 37–38 |
| s19-v2 | 38 | 0–1 | 3–4 |
| s19-v3 | 38 | 6–7 | 9–11 |

  Page 37 line 0 must be the subheading `දෙවියන්ට පින්දීම` and line 32 `තෙරුවන් සමාකර ගැනීම`. Section 18's heading becomes the owner's spelling by inserting the space (`පින්දීම` → `පින් දීම`), recorded in the section's `corrections` with reason `owner's spelling`. Page 38 lines from 13 on (the closing verse) are not used.
- *Corrections:* exactly the table in §5.3, each scoped to its source (namo.lk rows to sections 1–17, booklet rows to 18–19), applied to `pali_si` and `sinhala`, each recorded on the verse where it applied with its count. `ම විසින්` matches only where `ම` is a whole word. After building, the total count per row must equal the number in §5.3 (ගච්චාමි 9, විඡ්ඡාචරණ 1, සමාදියාමී 4, සුමාමේරය 1, ධානේසු 1, අධිවාසේ තුනෝ 1, බෝදි 1, රුස්කර 3, පුණ්ය 3, භූතයා් 1, ම විසින් 3, සාසණ 1, පුංඤ්ඤකෙත්තං 1, අනුත්ථරං 1, දේවානාගා 3); otherwise exit with an error naming the row. If a count is off because §5.3 counted lines this release leaves out (the closing verse), stop, correct the number in §5.3 with a note, and tell the owner in the stage report. Never loosen the check.
- *English from Mahamevnawa* (`right_column` lines whose `y` lies in the range, bold lines skipped; lines join with `\n`; a gap over 22 pt between lines becomes `\n\n`; a range that crosses a page continues with `\n`). The script asserts the first and last line of each range against the anchors given.

| Verse | Page and y range | Starts with | Ends with | Kind |
|---|---|---|---|---|
| s01-v1 | p2, 123.7–199.0 | `Homage to the Blissful One` | `Fully Enlightened One.` | translation |
| s02-v1 | p2, 259.5–410.1 | `I go to the Buddha for refuge.` | `A third time, I go to the Sangha for refuge.` | translation |
| s03-v1 | p2, 470.6–606.1 | `I undertake the training rule to abstain from killing` | `intoxicants and harmful drugs.` | translation |
| s04-v1 | p3, 123.6–500.8 | `Such indeed is the Blessed One:` | `holds these great, extra-ordinary qualities.` | explanation |
| s05-v1 | p4, 123.9–320.2 | `"Svakkhato" -` | `the wise to understand and realize.` | explanation |
| s06-v1 | p4, 389.7–661.2 | (read from the file) | `hospitality, worthy of respect and worship.` | explanation |
| s18-v4 | p16, 665.7 → p17, 253.0 | (read from the file) | `long protect myself and others.` | translation |
| s19-v1 | p17, 639.3–684.4 | `If, due to negligence, I have done some` | `Perfect one of vast wisdom.` | translation |
| s19-v2 | p18, 102.1–147.3 | (read from the file) | `Visible and unaffected by time.` | translation |
| s19-v3 | p18, 177.4–226.6 | (read from the file) | `Practising well and supreme.` | translation |

  "(read from the file)": print the range once, copy its first line into the anchor list, and confirm the bold Pali heading above it is the right passage. s18-v4 must come out as three stanzas.
- *English from the Brisbane booklet* (`yasodhara_vandana.json`; the non-bold lines of one block, in `y` order, from the line that starts with the first anchor through the line that starts with the last; lines made only of dashes are dividers and are skipped). All are `translation`, translator `prepared by Cynthia Gunawardana`.

| Verse | Page | First line starts | Last line starts |
|---|---|---|---|
| s07-v1 | 8 | `I salute every chetiya` | `And all images of the Buddha.` |
| s08-v1 | 9 | `Seated at whose base,` | `That very bodhi tree do I adore` |
| s08-v2 | 9 | `These great trees of enlightenment` | `May there be homage to you.` |
| s10-v1 | 10 | `With lights brightly shining` | `(*three worlds` (the printed footnote, kept as a last paragraph after `\n\n`) |
| s11-v1 | 10 | `With perfumed incense,` | `Who dispels the darkness` |
| s11-v2 | 10 | `Fragrant of voice and form,` | `With fragrance I worship.` |
| s12-v1 | 9 | `This mass of flowers fresh` | `I offer at the sacred lotus` |
| s12-v2 | 9 | `I worship the Buddha with these flowers;` | `Our body will undergo decay.` |
| s13-v1 | 11 | `O Lord! The blessed one` | `Out of great compassion on us.` |
| s15-v1 | 11 | the English under the heading "Gilan Pasa" (block 3; read its first and last lines from the file, and keep its printed note in brackets as a last paragraph) | |
| s18-v1 | 12 | `May all devas share this merit` | `Of happiness and prosperity.` |

- *No English:* s08-v3, s09-v1, s14-v1, s16-v1, s17-v1, s18-v2, s18-v3. `pali_roman` is null for every verse.
- *Needs checking* (each with a note carrying the wording from §5.2 / §5.3): s11-v1 (second line; and the English's last line), s12-v2 (`ලභාමි මොක්ඛං` against "cha hothu mokkam"), s18-v4 (`ලෝක සාසනං` against "sasanam"), s19-v3 (ending against "Supatipanna anuttara"). Every other verse is `checked against source`. A section's `check` is `needs checking` if any of its verses is.
- *Sources:* sections 1–17 name `namo.lk`, locator `https://namo.lk/buddha-puja/`, collected `2026-11-09`; 18–19 name the paritha.org booklet with its URL and printed page; English records name the booklet and page.

- [ ] **Step 1: Check the booklet against the printed page.** For each of `රුස්කර`, `ම විසින්`, `සාසණ`, `පුංඤ්ඤකෙත්තං`, `අනුත්ථරං`, `දේවානාගා`, run `python -I tools/fm_line_probe.py source_material/sinhala_pali_paritha_org/Booklet-1.pdf <39 or 40> <hex of the word> <scratchpad png>` and read the image. Then compare page 38 (PDF page 40) lines 0–11 with the page image, line by line. If the print shows the right spelling, the fault is in the conversion: fix `tools/fm_to_unicode.py`, re-run `tools/extract_booklet.py`, and take the row out of §5.3. Write what was found, one line per word, into the commit message.
- [ ] **Step 2: Write the failing tests** in `tools/test_build_content.py` (`unittest`; load `build_content.py` by path with `importlib`, since `-I` leaves the script folder off the path):

```python
HEADINGS = [...]            # the 19 headings, copied from the table in §5.1 of the design
VERSES = [1,1,1,1,1,1,1,3,1,1,2,2,1,1,1,1,1,4,3]
NO_ENGLISH = {"s08-v3","s09-v1","s14-v1","s16-v1","s17-v1","s18-v2","s18-v3"}
BRISBANE = {"s07-v1","s08-v1","s08-v2","s10-v1","s11-v1","s11-v2","s12-v1","s12-v2","s13-v1","s15-v1","s18-v1"}
NEEDS = {"s11-v1","s12-v2","s18-v4","s19-v3"}
COUNTS = {...}              # the 15 rows above: printed form -> count

def test_sections(self):      # [s["heading"] for s in sections] == HEADINGS; numbers 1..19; ids s01..s19
def test_verse_counts(self):  # [len(s["verses"]) for s in sections] == VERSES   (28 verses)
def test_english_presence(self):   # english is None exactly for NO_ENGLISH; english_source None exactly there
def test_english_sources(self):    # "Cynthia Gunawardana" in translator exactly for BRISBANE; the other 10 name Mahamevnawa
def test_english_kind(self):       # "explanation" exactly for s04-v1, s05-v1, s06-v1
def test_anchors(self):            # s01-v1 english starts "Homage to the Blissful One"; s07-v1 starts "I salute every chetiya";
                                   # s18-v1 starts "May all devas share this merit"; s19-v3 ends "Practising well and supreme."
def test_no_roman_pali(self):      # pali_roman is None for all 28
def test_pali_and_sinhala_everywhere(self):   # both non-empty for all 28
def test_stanzas(self):            # s18-v4 pali_si and english each split on "\n\n" into 3; s17-v1 sinhala ends "\n\nසාධූ! සාධූ! සාධූ!"
def test_corrections_are_the_listed_ones(self):  # sum of count per "from" over all verses == COUNTS exactly (same keys)
def test_printed_slips_are_gone(self):     # none of the namo.lk "from" forms occurs in sections 1-17 text, none of the booklet forms in 18-19
def test_needs_checking(self):     # check == "needs checking" exactly for NEEDS, each with at least one note
def test_nothing_from_outside(self):   # "Related Resources" absent; no heading starts with a digit; "With Devas" absent
def test_file_is_reproducible(self):   # render(build(root)) == render(build(root)) == bytes of the asset file
```

- [ ] **Step 3:** Run `python -I -X utf8 tools/test_build_content.py` → fails (no `build_content.py`).
- [ ] **Step 4:** Implement `build_content.py` to the rules above. Add `.gitattributes` with `assets/content/*.json text eol=lf` and `content/extracted/*.json text eol=lf`. Run the script to write the asset; add `assets/content/` to `pubspec.yaml`.
- [ ] **Step 5:** Run the tests → all pass. Run `python -I -X utf8 tools/build_content.py . --check` → `content file is up to date`.
- [ ] **Step 6:** Read the built file once from top to bottom beside `content/review/03_namo_lk_all_pages.md` and the two English review files: every English text sits under the Pali it translates.
- [ ] **Step 7:** Commit: "Stage 2: build the content file from the stored sources".

### Task 5: Loading the content; Home, Library and the contents list

**Files:**
- Create: `lib/content/model.dart`, `lib/content/content_repository.dart`, `lib/library/reading_contents_screen.dart`, `lib/design/widgets/list_row.dart`, `test/support/test_content.dart`
- Modify: `lib/home/home_screen.dart`, `lib/library/library_screen.dart`, `lib/router.dart`
- Test: `test/content/content_repository_test.dart`, `test/library/library_flow_test.dart`

**Interfaces:**
- Produces (only what these screens need; Task 6 completes the model):
  - `class Section { final String id; final int number; final String heading; }`, `class Reading { final String id, title; final List<Section> sections; }`, `class Category { final String id, title, subtitle; final List<Reading> readings; }`, `class Library { final List<Category> categories; Reading? reading(String id); Category? categoryOf(String readingId); Category? category(String id); }`, each with `factory …fromJson(Map<String, dynamic>)`.
  - `abstract interface class ContentRepository { Future<Library> load(); }`; `class AssetContentRepository implements ContentRepository { AssetContentRepository(AssetBundle bundle, {String path = 'assets/content/namaskaraya_to_pin_dima.json'}); }` — throws `FormatException` when `schema` is not 1.
  - `final contentRepositoryProvider = Provider<ContentRepository>(...)`, `final libraryProvider = FutureProvider<Library>(...)`.
  - `test/support/test_content.dart`: `Library testLibrary()` and `class FakeContentRepository implements ContentRepository`. Its text is plainly made up (`'pali 1'`, `'sinhala 1'`, `'english 1'`): one category, one reading `r1`, three sections `s01`–`s03`; `s01` has two verses with all three languages, `s02` one verse with no English, `s03` two verses of which only the first has English and is marked `explanation`.
  - Screens: Home shows `Namo` and the category row; Library lists categories → `Routes.category(id)` lists readings → `Routes.contents(readingId)` lists sections as `ListRow`s numbered 1–n. Tapping a section goes to `Routes.reader(readingId, sectionId: id)` (the reader arrives in Task 9; until then that route shows a placeholder screen with the text `The reader arrives in Stage 4.`).

- [ ] **Step 1: Write the failing tests:**

```dart
testWidgets('the bundled content loads: 1 category, 1 reading, 19 sections', (t) async {
  final lib = await AssetContentRepository(rootBundle).load();
  final r = lib.categories.single.readings.single;
  expect(lib.categories.single.title, 'Namaskaraya to Deviyanta Pin Dima');
  expect(r.sections.length, 19);
  expect(r.sections.map((s) => s.number), List.generate(19, (i) => i + 1));
  expect(lib.reading('namaskaraya'), same(r));
  expect(lib.reading('nope'), isNull);
});
test('a file with another schema number is refused', () { /* schema 2 -> throwsFormatException */ });
testWidgets('Home -> category -> reading -> contents list shows every section', (t) async {
  await pumpApp(t, overrides: [contentRepositoryProvider.overrideWithValue(FakeContentRepository())]);
  // tap the category on Home, then the reading; expect three rows with the fake headings, numbered 1-3
});
testWidgets('a contents address for an unknown reading shows not-found', (t) async { /* location: Routes.contents('nope') */ });
testWidgets('content that fails to load shows a plain message, not an error screen', (t) async { /* repository that throws -> "The text could not be loaded." */ });
```

- [ ] **Step 2:** Run → fail. **Step 3:** Implement. **Step 4:** `flutter test` → pass.
- [ ] **Step 5:** Commit: "Stage 2: load the content; Home, Library, contents list". Run the **Stage Check**; in Chrome confirm the 19 headings render in Noto Sans Sinhala with no boxes or broken conjuncts (look closely at `චෛත්‍ය` and `ආරාධනාව`).

---

## Stage 3: Content model and language selection

### Task 6: The full content model

**Files:**
- Create: `lib/settings/reading_language.dart`
- Modify: `lib/content/model.dart`, `test/support/test_content.dart`
- Test: `test/content/model_test.dart`

**Interfaces:**
- Consumes: the JSON shape from Task 4.
- Produces:
  - `enum ReadingLanguage { sinhala('si', 'Sinhala'), english('en', 'English'), pali('pi', 'Pali'); final String code, label; static ReadingLanguage? fromCode(String) }` in `lib/settings/reading_language.dart` (created here, completed in Task 7).
  - `enum CheckStatus { unchecked, checkedAgainstSource, needsChecking }` parsed from the three strings in the file; an unknown string parses as `unchecked`.
  - `enum EnglishKind { translation, explanation }`
  - `class SourceRecord { final String name, locator, collected, translator; }`, `class Correction { final String field, from, to, reason; final int count; }`
  - `class Verse { final String id; final String? paliSi, paliRoman, sinhala, english; final SourceRecord? englishSource; final EnglishKind? englishKind; final CheckStatus check; final List<String> notes; final List<Correction> corrections; String? text(ReadingLanguage l); }` — `text` returns `sinhala`, `english` or `paliSi`; an empty or whitespace-only string reads as null. The four fields are stored separately and never derived from each other.
  - `Section` gains `SourceRecord source`, `CheckStatus check`, `List<Correction> corrections`, `List<Verse> verses`, and `LanguageCover coverOf(ReadingLanguage l)` with `enum LanguageCover { all, part, none }`.
  - `Reading` gains `RecordingInfo? audio` (`class RecordingInfo { final String asset, label; final Map<String, Duration> sectionCues; }`), null in this release.

- [ ] **Step 1: Write the failing tests** against the bundled file:

```dart
// loaded once in setUpAll via AssetContentRepository(rootBundle)
test('every verse has Pali and Sinhala; none has Roman Pali', ...);          // 28 verses
test('English cover per section', () {
  expect(sec(1).coverOf(ReadingLanguage.english), LanguageCover.all);
  expect(sec(8).coverOf(ReadingLanguage.english), LanguageCover.part);
  expect(sec(18).coverOf(ReadingLanguage.english), LanguageCover.part);
  for (final n in [9, 14, 16, 17]) { expect(sec(n).coverOf(ReadingLanguage.english), LanguageCover.none); }
  expect(sec(9).coverOf(ReadingLanguage.pali), LanguageCover.all);
});
test('sections 4-6 English is marked as an explanation', ...);
test('English carries its own source', () {
  expect(verse('s07-v1').englishSource!.translator, contains('Cynthia Gunawardana'));
  expect(verse('s01-v1').englishSource!.translator, 'not named by the source');
  expect(verse('s09-v1').englishSource, isNull);
});
test('four verses need checking and say why', ...);   // s11-v1, s12-v2, s18-v4, s19-v3; notes not empty
test('corrections are read with from, to, count and reason', ...);   // s02-v1 has a correction with count 9
test('text() treats an empty string as missing', ...);   // Verse.fromJson with "english": "  " -> text(english) == null
```

- [ ] **Step 2:** Run → fail. **Step 3:** Implement; fill in `testLibrary()` to match its description in Task 5. **Step 4:** `flutter test` → pass.
- [ ] **Step 5:** Commit: "Stage 3: full content model".

### Task 7: The language rule, settings state, and language and layout in Settings

**Files:**
- Create: `lib/storage/key_value_store.dart`, `lib/settings/settings.dart`
- Modify: `lib/settings/reading_language.dart`, `lib/settings/settings_screen.dart`, `lib/app.dart` (theme mode from settings)
- Test: `test/settings/reading_language_test.dart`, `test/settings/settings_test.dart`, `test/settings/settings_screen_test.dart`

**Interfaces:**
- Produces:
  - `abstract interface class KeyValueStore { String? read(String key); Future<void> write(String key, String value); Future<void> remove(String key); }`, `class InMemoryKeyValueStore implements KeyValueStore`, `final keyValueStoreProvider = Provider<KeyValueStore>((_) => InMemoryKeyValueStore());` (Task 13 overrides it with saved storage; nothing else changes).
  - `enum ToggleOutcome { changed, refusedThird, refusedLast }`
  - `class LanguageSelection { const LanguageSelection(this.languages); final List<ReadingLanguage> languages; static const initial = LanguageSelection([ReadingLanguage.pali, ReadingLanguage.sinhala]); (LanguageSelection, ToggleOutcome) toggle(ReadingLanguage l); bool has(ReadingLanguage l); static LanguageSelection fromCodes(List<Object?> codes); }` — order is the order chosen and is the order shown. `fromCodes` drops unknown and repeated codes, keeps the first two, and returns `initial` if none remain.
  - `enum TwoLanguageLayout { section, verse }`
  - `class AppSettings { languages = LanguageSelection.initial, layout = TwoLanguageLayout.verse, fontScale = 1.0 (0.85–1.6), lineSpacing = 1.6 (1.3–2.2), scrollSpeed = 22.0 (6–60, logical pixels per second), autoScrollWithAudio = false, themeMode = ThemeMode.system; copyWith; Map<String, dynamic> toJson(); factory AppSettings.fromJson(Object? json); }` — `fromJson` takes each field alone: a missing, wrongly typed or out-of-range value falls back to that field's default (numbers are clamped), and the others are kept.
  - `class SettingsController extends Notifier<AppSettings>` with `ToggleOutcome toggleLanguage(ReadingLanguage)`, `setLayout`, `setFontScale`, `setLineSpacing`, `setScrollSpeed`, `setAutoScrollWithAudio`, `setThemeMode`; reads key `namo.settings.v1` in `build()` and writes it on every change. `final settingsProvider = NotifierProvider<SettingsController, AppSettings>(...)`.
  - `class LanguageChooser extends ConsumerWidget` and `class LayoutChooser extends ConsumerWidget` in `settings_screen.dart`, reused by the reader's sheet in Task 9. Messages, exact: `Two languages at most. Switch one off first.` and `One language always stays on.` (shown in a `SnackBar`). `LayoutChooser` is disabled, with the hint `Needs two languages`, when one language is chosen. Layout labels: `Section by section`, `Verse by verse`.
- The defaults (Pali with Sinhala, verse by verse) are my call: it is how namo.lk shows the text.

- [ ] **Step 1: Write the failing tests:**

```dart
test('a third language is refused', () {
  final (s, o) = LanguageSelection.initial.toggle(ReadingLanguage.english);
  expect(o, ToggleOutcome.refusedThird);
  expect(s.languages, [ReadingLanguage.pali, ReadingLanguage.sinhala]);
});
test('the last language cannot be switched off', ...);        // [sinhala].toggle(sinhala) -> refusedLast, unchanged
test('switching off then on puts the language second', ...);  // [pali, sinhala] -pali-> [sinhala] +english-> [sinhala, english]
test('fromCodes repairs bad saved values', () {
  expect(LanguageSelection.fromCodes(['si', 'en', 'pi']).languages, [ReadingLanguage.sinhala, ReadingLanguage.english]);
  expect(LanguageSelection.fromCodes(['xx', 7, null]).languages, LanguageSelection.initial.languages);
  expect(LanguageSelection.fromCodes(['en', 'en']).languages, [ReadingLanguage.english]);
});
test('settings survive a round trip through the store', ...);   // change every field in container A; container B on the same store reads them all
test('damaged saved settings fall back field by field', () {
  // store holds '{"fontScale": "big", "lineSpacing": 9, "layout": "section", "languages": ["en"]}'
  // -> fontScale 1.0, lineSpacing 2.2, layout section, languages [english]
  // store holds 'not json' -> all defaults, no throw
});
testWidgets('Settings: choosing a third language shows the message and changes nothing', ...);
testWidgets('Settings: layout chooser is disabled with one language', ...);
```

- [ ] **Step 2:** Run → fail. **Step 3:** Implement; `NamoApp` now watches `settingsProvider` for `themeMode`. **Step 4:** `flutter test` → pass.
- [ ] **Step 5:** Commit: "Stage 3: language rule, settings state, language and layout in Settings". Run the **Stage Check**.

---

## Stage 4: Reader screen

### Task 8: What the reader shows, in order (both layouts)

**Files:**
- Create: `lib/reader/reader_items.dart`
- Test: `test/reader/reader_items_test.dart`

**Interfaces:**
- Consumes: `Reading`, `Section.coverOf`, `Verse.text`, `LanguageSelection`, `TwoLanguageLayout`.
- Produces:
  - `sealed class ReaderItem { String get sectionId; String? get verseId; }`
  - `class HeadingItem extends ReaderItem { final Section section; final List<String> notes; }` (`verseId` is null)
  - `class VerseTextItem extends ReaderItem { final String sectionId, verseId; final ReadingLanguage language; final String text; final bool secondary; }` — `secondary` is true for the second chosen language (drawn in the quiet colour).
  - `List<ReaderItem> buildReaderItems(Reading reading, LanguageSelection selection, TwoLanguageLayout layout)` — a pure function.
- Rules: per section, one `HeadingItem`, then its verse texts. *Verse layout:* each verse in the first language, then the same verse in the second. *Section layout:* all verses in the first language, then all in the second. With one language the two layouts give the same list. A verse with no text in a language gives no item for that language. Heading notes, exact wording: `<Language> is not yet available for this section.` when cover is `none`; `<Language> is not yet available for part of this section.` when `part`; and, when English is chosen and any verse of the section is an `explanation`, `The English here explains each quality; it is not a line-by-line translation.`

- [ ] **Step 1: Write the failing tests** on `testLibrary()` (kinds written as `H(s01)`, `V(s01-v1, pi)`):

```dart
test('verse layout pairs each verse', ...);
  // [pali, sinhala], verse -> H s01, V v1 pi, V v1 si, V v2 pi, V v2 si, H s02, ...
test('section layout groups by language', ...);
  // [pali, sinhala], section -> H s01, V v1 pi, V v2 pi, V v1 si, V v2 si, ...
test('one language gives the same list in both layouts', ...);
test('a section with no English shows its heading, a note and the other language', () {
  // [english, pali], verse: s02 -> HeadingItem with notes ['English is not yet available for this section.'], then V s02-v1 pi only
});
test('only English chosen and none available leaves the heading and its note', ...);   // [english]: s02 -> exactly one item
test('partial English is noted and the missing verse is skipped', ...);   // s03 -> note '... for part of this section.'; no V s03-v2 en
test('explanation English is labelled', ...);   // s03 notes contain the explanation line when english chosen, not otherwise
test('the second language is marked secondary', ...);
```

- [ ] **Step 2:** Run → fail. **Step 3:** Implement. **Step 4:** Run → pass. **Step 5:** Commit: "Stage 4: reader item list for both layouts".

### Task 9: The reader screen

**Files:**
- Create: `lib/reader/reader_screen.dart`, `lib/reader/reader_body.dart`, `lib/reader/reader_bottom_bar.dart`, `lib/reader/reader_settings_sheet.dart`
- Modify: `lib/router.dart` (the real reader route), `lib/design/typography.dart`
- Test: `test/reader/reader_screen_test.dart`

**Interfaces:**
- Consumes: `buildReaderItems`, `settingsProvider`, `libraryProvider`, `LanguageChooser`, `LayoutChooser`, `Routes.reader`.
- Produces:
  - `TextStyle readingStyle(ReadingLanguage l, {required double fontScale, required double lineSpacing, required Color color})` — base sizes: Sinhala and Pali 18, English 17, in their bundled families; size = base × `fontScale`; `height` = `lineSpacing`.
  - `class ReaderScreen extends ConsumerStatefulWidget { const ReaderScreen({required this.readingId, this.sectionId}); }`
  - `class ReaderBody` : one `SingleChildScrollView` holding a `Column` of every item, capped at `NamoSizes.readingColumn` wide and centred. The whole reading is laid out at once (about 50 items), so every item has a known position; revisit when a reading passes a few hundred verses. Exposes, through its `GlobalKey<ReaderBodyState>`: `List<({double top, double height})> extents()`, `double offsetOfSection(String sectionId)`, and the `ScrollController` it was given.
  - Keys: `ValueKey('heading-<sectionId>')`, `ValueKey('verse-<verseId>-<languageCode>')`, `ValueKey('reader-prev')`, `ValueKey('reader-next')`, `ValueKey('reader-settings')`.
- Behaviour:
  - Top bar: back, the reading's title with the category title beneath in the quiet colour, a favourite button (wired in Task 10), the reader-settings button.
  - Bottom bar: previous section, a play button (wired in Task 11), next section, and a 2-px progress line (wired in Task 10). Previous goes to the start of the current section, or to the section before if already within 8 px of its start; next goes to the following heading. Both are disabled at the ends.
  - Settings sheet (a modal bottom sheet over the reader): `LanguageChooser`, `LayoutChooser`, a font-size slider (`0.85`–`1.6`, labelled `Text size`), a line-spacing slider (`1.3`–`2.2`, `Line spacing`), and room for Task 11's speed control and Task 10's `Back to the beginning`.
  - `sectionId` in the address scrolls to that heading after the first layout; an unknown `sectionId` opens at the top; an unknown `readingId` shows `NotFoundScreen`.
  - Text is selectable nowhere and wraps everywhere (`softWrap: true`); no item sets a fixed width.

- [ ] **Step 1: Write the failing tests** (fake content, in-memory store):

```dart
testWidgets('shows the title, the category beneath, and every section heading', ...);
testWidgets('opening at ?section=s02 puts that heading at the top', ...);   // its top is within 1 px of the body's top
testWidgets('unknown section opens at the top; unknown reading shows not-found', ...);   // t.takeException() isNull
testWidgets('next and previous move between headings and disable at the ends', ...);
testWidgets('the sheet changes text size and line spacing at once', (t) async {
  // drag 'Text size' to max -> the Text under ValueKey('verse-s01-v1-pi') has fontSize 18 * 1.6; settingsProvider.fontScale == 1.6
});
testWidgets('switching languages in the sheet while reading does not throw', (t) async {
  // open the sheet; by toggling, pass through every single language and every pair (9 states), scrolled to the middle of the reading
  // after each toggle: pumpAndSettle, expect(t.takeException(), isNull), and at least one heading is on screen
});
testWidgets('switching layout swaps the order of items', ...);   // verse -> section: V s01-v2 pi now precedes V s01-v1 si
```

- [ ] **Step 2:** Run → fail. **Step 3:** Implement. **Step 4:** `flutter test` → pass. **Step 5:** Commit: "Stage 4: reader screen, previous/next, reader settings sheet".

### Task 10: Position, progress, bookmarks and favourites

**Files:**
- Create: `lib/reader/reading_position.dart`, `lib/reader/position_controller.dart`, `lib/saved/saved.dart`
- Modify: `lib/reader/reader_screen.dart`, `lib/reader/reader_body.dart`, `lib/reader/reader_bottom_bar.dart`, `lib/reader/reader_settings_sheet.dart`
- Test: `test/reader/reading_position_test.dart`, `test/saved/saved_test.dart`, `test/reader/reader_position_test.dart`

**Interfaces:**
- Consumes: `ReaderItem`, `ReaderBodyState.extents()`, `KeyValueStore`.
- Produces:
  - `class ReadingPosition { final String readingId, sectionId; final String? verseId; final double fraction; toJson; static ReadingPosition? fromJson(Object?); }` — "which item is at the top and how far into it" (0–1).
  - `ReadingPosition? capturePosition({required String readingId, required List<ReaderItem> items, required List<({double top, double height})> extents, required double scrollOffset})` — the item is the last one whose `top` ≤ `scrollOffset`.
  - `double offsetForPosition({required ReadingPosition position, required List<ReaderItem> items, required List<({double top, double height})> extents, required double maxScrollExtent})` — target item: the first `VerseTextItem` with that `verseId`; if there is none, that section's `HeadingItem` (fraction taken as 0); if the section is unknown, 0. Result clamped to `0…maxScrollExtent`.
  - `double progressOf(double offset, double maxScrollExtent)` — 0 when `maxScrollExtent` ≤ 0, else clamped 0–1.
  - `class ReadingProgress { final ReadingPosition position; final double progress; }`; `class PositionState { final Map<String, ReadingProgress> byReading; final String? lastReadingId; }`; `class PositionController extends Notifier<PositionState> { void save(ReadingPosition p, double progress); void clear(String readingId); }` on key `namo.position.v1`; `final positionProvider`.
  - `class Bookmark { final String readingId, sectionId; }`; `class SavedState { final List<Bookmark> bookmarks; final Set<String> favourites; bool isBookmarked(String readingId, String sectionId); bool isFavourite(String readingId); }`; `class SavedController extends Notifier<SavedState> { void toggleBookmark(String readingId, String sectionId); void toggleFavourite(String readingId); }` on key `namo.saved.v1`; `final savedProvider`. Newest bookmark first.
- Behaviour in the reader:
  - Position is saved 400 ms after scrolling stops, when the app goes to the background (`AppLifecycleListener`), and on leaving the reader.
  - Opening the reader without `sectionId` restores the saved position; with `sectionId` it goes to that section.
  - When languages, layout, text size, line spacing or the window width change: capture the position in the settings listener (the old layout is still on screen), then restore it in the next frame.
  - The progress line shows `progressOf`. `Back to the beginning` in the sheet jumps to 0 and clears the saved position.
  - Each heading has a bookmark button (label `Bookmark this section` / `Remove bookmark`, filled gold mark when on); the top bar's favourite button (`Add to favourites` / `Remove from favourites`).

- [ ] **Step 1: Write the failing tests:**

```dart
// reading_position_test.dart — pure, with made-up extents
test('captures the item at the top and the fraction into it', ...);
  // items H s01 (0,40), V v1 pi (40,100), V v1 si (140,60); offset 90 -> (s01, v1, 0.5)
test('restores to the same verse after its height changes', ...);
  // same position, V v1 pi now (40,200) -> 140
test('restores to the verse when the layout moved it', ...);   // section layout extents -> offset of first item for v1
test('a verse with nothing to show falls back to its section heading', ...);
  // position (s02, s02-v1) but items have only H s02 -> top of H s02
test('an unknown section restores to 0; results are clamped to the page', ...);
test('progress is 0 on a page that does not scroll', () => expect(progressOf(0, 0), 0));

// saved_test.dart
test('bookmarks toggle per section and several can exist in one reading', ...);
test('favourites toggle per reading', ...);
test('saved items survive a new container on the same store', ...);

// reader_position_test.dart — widget
testWidgets('changing text size keeps the same verse at the top', (t) async {
  // scroll so s02-v1 is at the top; set fontScale 1.6; pumpAndSettle; top of ValueKey('verse-s02-v1-pi') within 2 px of the body's top
});
testWidgets('switching to a language the section lacks keeps the reader in that section', (t) async {
  // at s02-v1; choose only English -> heading-s02 is at the top; no exception
});
testWidgets('leaving and reopening the reader restores the position', ...);
testWidgets('bookmark and favourite buttons toggle and announce their state', ...);   // semantics labels change
testWidgets('Back to the beginning returns to the top and clears the saved position', ...);
```

- [ ] **Step 2:** Run → fail. **Step 3:** Implement. **Step 4:** `flutter test` → pass.
- [ ] **Step 5:** Commit: "Stage 4: reading position, progress, bookmarks, favourites". Run the **Stage Check** and send the owner reader screenshots: Pali + Sinhala in both layouts, English + Pali at section 9 (the "not yet available" line), light and dark, phone and wide.

---

## Stage 5: Auto-scroll

### Task 11: The scroll engine and its controls

**Files:**
- Create: `lib/reader/auto_scroll.dart`
- Modify: `lib/reader/reader_screen.dart`, `lib/reader/reader_bottom_bar.dart`, `lib/reader/reader_settings_sheet.dart`
- Test: `test/reader/auto_scroll_test.dart`, `test/reader/reader_auto_scroll_test.dart`

**Interfaces:**
- Consumes: the reader's `ScrollController`; `AppSettings.scrollSpeed`.
- Produces:

```dart
enum AutoScrollStatus { stopped, running, paused, finished }

class AutoScrollEngine extends ChangeNotifier {
  AutoScrollEngine({required ScrollController controller, required double speed});
  static const slow = 12.0, normal = 22.0, fast = 36.0, minSpeed = 6.0, maxSpeed = 60.0;   // logical pixels per second
  static const maxStep = Duration(milliseconds: 100);
  AutoScrollStatus get status;
  double get speed;  set speed(double v);   // clamped; may change while running
  void play();        // from the page's current offset; when finished, from the top
  void pause();
  void reset();       // jump to 0, status stopped
  void syncToPage();  // the page was moved on purpose (previous/next, a restore): carry on from where it now is
  void onFrame(Duration sinceLastFrame);   // called once per screen frame by the reader's Ticker
}
```

- How it moves (the part the signature does not settle): the engine keeps its own `double _target`, set from `controller.offset` on `play()` and `syncToPage()`. Each frame, while running: if `(controller.offset - _target).abs() > 1.0`, something else moved the page → `pause()` and return. Otherwise `_target += speed × min(sinceLastFrame, maxStep)` in seconds; if `_target ≥ maxScrollExtent`, jump to `maxScrollExtent` and set `finished`; else `controller.jumpTo(_target)`. No `Timer` anywhere. The preset speeds are my call, to be tuned by eye at the stage check.
- Reader wiring: one `Ticker` runs only while `status == running`. A `Listener` over the body calls `pause()` on `onPointerDown`. Previous/next and the position restore of Task 10 call `syncToPage()` so they do not pause it. The play button's label is `Start auto-scroll`, `Pause auto-scroll` or `Resume auto-scroll`. The sheet gains `Scroll speed`: three choices `Slow`, `Normal`, `Fast` and a slider `6`–`60`; a slider value that is not a preset shows `Custom`. Changing it writes `settingsProvider.scrollSpeed` and the engine's speed at once. `Back to the beginning` also calls `reset()`.

- [ ] **Step 1: Write the failing tests:**

```dart
// auto_scroll_test.dart — a real ScrollController on a 5000-px page in a testWidgets body; frames fed by hand
testWidgets('moves by speed x time, keeping sub-pixel progress', (t) async {
  // speed 6; play(); 60 frames of 16 ms -> offset closeTo(5.76, 0.01)
});
testWidgets('a speed change applies from the next frame with no jump', ...);   // 1 s at 12 then 1 s at 36 -> 48
testWidgets('pause holds the page; play resumes from where the page now is', ...);   // pause, jumpTo(900), play, 1 s at 22 -> 922
testWidgets('a long gap between frames moves at most 100 ms of distance', (t) async {
  // speed 60; onFrame(const Duration(seconds: 30)) -> offset closeTo(6.0, 0.01)
});
testWidgets('scrolling by other means pauses and is not pulled back', (t) async {
  // running at 22; controller.jumpTo(400); onFrame(16 ms) -> status paused, offset 400
});
testWidgets('stops by itself at the end; play then starts again from the top', ...);
testWidgets('reset returns to the top and stops', ...);
testWidgets('speed is clamped to 6-60', ...);

// reader_auto_scroll_test.dart
testWidgets('the play button starts scrolling and a touch on the text pauses it at once', (t) async {
  // tap play; pump 1 s of frames -> offset > 0; t.startGesture on the body -> label is 'Resume auto-scroll'; offset unchanged after another second
});
testWidgets('a mouse-wheel scroll pauses it', ...);   // t.sendPointerSignal / PointerScrollEvent
testWidgets('next section does not pause auto-scroll', ...);
testWidgets('speed can be changed from the sheet while scrolling', ...);
testWidgets('changing text size while scrolling keeps the verse and keeps scrolling', ...);
```

- [ ] **Step 2:** Run → fail. **Step 3:** Implement. **Step 4:** `flutter test` → pass.
- [ ] **Step 5:** Commit: "Stage 5: auto-scroll". Run the **Stage Check**; in Chrome watch a full pass at Slow, Normal and Fast and report whether the motion is even and whether the presets suit a chanting pace.

---

## Stage 6: Audio architecture

### Task 12: Catalogue, player, controls and the development tone

**Files:**
- Create: `lib/audio/audio_catalogue.dart`, `lib/audio/chant_player.dart`, `lib/audio/audio_controls.dart`, `tools/make_placeholder_tone.py`, `assets/audio_dev/placeholder_tone_not_a_chant.wav`, `assets/audio_dev/README.md`, `test/support/fake_chant_player.dart`
- Modify: `pubspec.yaml` (asset), `lib/reader/reader_screen.dart`, `lib/reader/reader_bottom_bar.dart`
- Test: `test/audio/audio_catalogue_test.dart`, `test/audio/reader_audio_test.dart`

**Interfaces:**
- Consumes: `Reading.audio` (`RecordingInfo?`), `AutoScrollEngine.play()`, `AppSettings.autoScrollWithAudio`.
- Produces:
  - `class Recording { final String readingId, asset, label; final bool placeholder; final Map<String, Duration> sectionCues; }`
  - `abstract interface class AudioCatalogue { Recording? recordingFor(String readingId); }`
  - `class ContentAudioCatalogue implements AudioCatalogue { ContentAudioCatalogue(Library library); }` — answers from `Reading.audio`; null for every reading in this release.
  - `class DevPlaceholderCatalogue implements AudioCatalogue { DevPlaceholderCatalogue(AudioCatalogue real); }` — where `real` has nothing, gives the tone with `placeholder: true` and label `Development placeholder tone (not a chant)`.
  - `AudioCatalogue chooseCatalogue({required AudioCatalogue real, required bool debugBuild, required bool devAudioFlag})` — the placeholder catalogue only when both are true. The provider passes `kDebugMode` and `const bool.fromEnvironment('NAMO_DEV_AUDIO')`. `final audioCatalogueProvider`.
  - `enum ChantStatus { idle, loading, ready, playing, paused, completed, failed }`; `class ChantState { final ChantStatus status; final Duration position; final Duration? duration; }`
  - `abstract interface class ChantPlayer { ChantState get state; Stream<ChantState> get states; Future<void> load(Recording r); Future<void> play(); Future<void> pause(); Future<void> restart(); Future<void> seek(Duration to); Future<void> dispose(); }` — "resume" is `play()` after `pause()`. `load` never throws: a file that cannot be opened gives `failed`.
  - `class JustAudioChantPlayer implements ChantPlayer` (the only file that imports just_audio); `class FakeChantPlayer implements ChantPlayer` in `test/support/` with `void advance(Duration d)` and a `failOnLoad` flag; `final chantPlayerProvider = Provider.autoDispose<ChantPlayer>(...)`.
  - `class AudioControls extends ConsumerWidget` — play/pause (`Play recording` / `Pause recording`), restart (`Restart recording`), elapsed and total time; shows the recording's label when `placeholder` is true; on `failed` shows `The recording could not be played.` and no buttons.
- Behaviour: the bottom bar shows `AudioControls` only when `recordingFor(readingId)` is not null. Audio and auto-scroll do not touch each other, with one exception: when the player goes to `playing` and `autoScrollWithAudio` is on, the reader calls `engine.play()`. Pausing either leaves the other running. Section cue times and lock-screen controls are not built.
- The tone: `tools/make_placeholder_tone.py <out_wav>` writes 20 s of a quiet 220 Hz sine, mono, 8 kHz, 8-bit (about 160 KB), with the standard library's `wave`. `assets/audio_dev/README.md` says what it is and that it is never offered in a release build.

- [ ] **Step 1: Write the failing tests:**

```dart
test('the bundled content has no recording', ...);   // ContentAudioCatalogue(realLibrary).recordingFor('namaskaraya') == null
test('the placeholder is chosen only in a debug build with the flag on', () {
  for (final (debug, flag, expected) in [(true, true, true), (true, false, false), (false, true, false), (false, false, false)]) {
    final c = chooseCatalogue(real: empty, debugBuild: debug, devAudioFlag: flag);
    expect(c.recordingFor('r1') != null, expected);
  }
});
test('a real recording is never replaced by the placeholder', ...);
testWidgets('with no recording the reader shows no audio controls', ...);   // find.byType(AudioControls) findsNothing
testWidgets('with a recording: play, pause, resume, restart', ...);   // FakeChantPlayer; statuses and labels follow
testWidgets('the placeholder is labelled as one', ...);   // 'Development placeholder tone (not a chant)' visible
testWidgets('audio and auto-scroll run alone and together', ...);   // audio playing + scroll stopped; scroll running + audio paused; both
testWidgets('"start auto-scroll with audio" starts the scroll when audio starts, and only then', ...);
testWidgets('a recording that fails to load shows the message; auto-scroll still works', ...);
```

- [ ] **Step 2:** Run → fail. **Step 3:** Implement; generate the tone with the script. **Step 4:** `flutter test` → pass.
- [ ] **Step 5:** Run in Chrome with `flutter run -d chrome --dart-define=NAMO_DEV_AUDIO=true`: the labelled tone plays, pauses, resumes and restarts. Without the flag: no audio controls.
- [ ] **Step 6:** Commit: "Stage 6: audio catalogue, player interface, controls, development tone". Run the **Stage Check**.

---

## Stage 7: Persistence and reading progress

### Task 13: Saved storage and restore on start-up

**Files:**
- Modify: `lib/storage/key_value_store.dart`, `lib/main.dart`, `lib/reader/position_controller.dart`, `lib/saved/saved.dart`
- Test: `test/storage/restart_test.dart`

**Interfaces:**
- Consumes: `KeyValueStore`, the three keys `namo.settings.v1`, `namo.saved.v1`, `namo.position.v1`.
- Produces: `class SharedPrefsKeyValueStore implements KeyValueStore { SharedPrefsKeyValueStore(SharedPreferences prefs); }`. `main()` awaits `SharedPreferences.getInstance()` and overrides `keyValueStoreProvider`; if that fails, the app starts on the in-memory store (nothing is saved, nothing crashes).
- `SavedController` and `PositionController` load like `AppSettings.fromJson`: entry by entry, dropping any that are malformed. Bookmarks, favourites and positions that name a reading or section the content no longer has are kept in storage but not shown (filtering is done where they are displayed, in Task 14, and by `offsetForPosition`'s fallback).

- [ ] **Step 1: Write the failing tests** (`SharedPreferences.setMockInitialValues({})`; "restart" = a new `ProviderContainer` on a new `SharedPrefsKeyValueStore` over the same mock):

```dart
test('settings, bookmarks, favourites, position and progress survive a restart', ...);
  // set languages [english, pali], layout section, fontScale 1.3, lineSpacing 2.0, scrollSpeed 36, autoScrollWithAudio true, dark theme;
  // bookmark r1/s02; favourite r1; position (r1, s02, s02-v1, 0.25) progress 0.4 -> restart -> all equal
test('each damaged key falls back alone', () {
  // namo.saved.v1 = '{"bookmarks": [{"readingId": "r1"}, {"readingId": "r1", "sectionId": "s02"}, 5], "favourites": "x"}'
  //   -> one bookmark (r1/s02), no favourites
  // namo.position.v1 = '[]' -> empty state;  namo.settings.v1 = '{' -> defaults;  none throws, and good keys are still read
});
testWidgets('the app starts and opens the reader with a bookmark for a section that no longer exists', ...);   // no exception
testWidgets('the reader reopens at the saved verse after a restart', ...);
```

- [ ] **Step 2:** Run → fail. **Step 3:** Implement. **Step 4:** `flutter test` → pass. **Step 5:** Commit: "Stage 7: saved storage and restore".

### Task 14: The Saved tab, Continue reading, the rest of Settings, and Sources

**Files:**
- Create: `lib/settings/sources_screen.dart`
- Modify: `lib/saved/saved_screen.dart`, `lib/home/home_screen.dart`, `lib/settings/settings_screen.dart`, `lib/router.dart`
- Test: `test/saved/saved_screen_test.dart`, `test/home/home_screen_test.dart`, `test/settings/settings_screen_test.dart`, `test/settings/sources_screen_test.dart`

**Interfaces:**
- Consumes: `savedProvider`, `positionProvider`, `settingsProvider`, `libraryProvider`, `Routes`, `assets/branding/namo_icon_square.png`.
- Produces:
  - **Saved:** two lists headed `Bookmarks` and `Favourites`. A bookmark row shows the section heading with the reading title beneath and opens the reader at that section; a favourite row opens the reader at its saved position. Each row has a remove button. Entries whose reading or section is not in the content are not shown. Empty states: `No bookmarks yet.` / `No favourites yet.`
  - **Home:** when `lastReadingId` is set and exists, a `Continue reading` row with the reading's title, the heading of the saved section and the progress as a thin line; it opens the reader at the saved position. Otherwise the row is absent.
  - **Settings:** in order — `Languages`, `Layout`, `Text size`, `Line spacing`, `Scroll speed` (the same control as the reader sheet), `Start auto-scroll when a recording starts`, `Theme` (`Light`, `Dark`, `Same as device`), `Sources`. Every one writes through `SettingsController`.
  - **Sources** (`Routes.sources`): the icon at 96 px; `Namo is free. It has no ads and nothing to buy.`; `Namo is not made by, or connected with, namo.lk.`; then the four credits of §5.6, each with its name, what it supplied and its address as selectable text (`https://namo.lk/buddha-puja/`; `https://www.paritha.org/wp-content/uploads/2019/11/Booklet-1.pdf`; `https://www.mahamevnawa.ca/uploads/1/0/7/1/107195823/vandana_v1.pdf`; the Brisbane booklet has no address and is credited by title, author and temple). Addresses are shown as text to copy, not opened, so the app needs no browser plugin. Below: `Corrections` — a list built from the content file of every correction (printed form → used form, section, reason), and `Still to be checked` — the notes of every verse marked `needs checking`. Last: `Font licences`, which opens Flutter's `showLicensePage`.

- [ ] **Step 1: Write the failing tests:**

```dart
testWidgets('Saved lists bookmarks and favourites and opens the reader at the bookmark', ...);
testWidgets('Saved hides entries the content no longer has and shows the empty lines', ...);
testWidgets('Home shows Continue reading only after something was read, and reopens at that place', ...);
testWidgets('every Settings control changes the saved setting', ...);   // one expectation per field of AppSettings
testWidgets('choosing Dark changes the app theme at once', ...);
testWidgets('Sources names all four sources and says the app is not connected with namo.lk', (t) async {
  // expects the two exact sentences above, 'namo.lk', 'paritha.org', 'Mahamevnawa', 'Cynthia Gunawardana'
});
testWidgets('Sources lists the corrections and the open checks from the content', ...);   // with the bundled file: 15 distinct corrections + 1 heading; 4 verses to check
```

- [ ] **Step 2:** Run → fail. **Step 3:** Implement. **Step 4:** `flutter test` → pass.
- [ ] **Step 5:** Commit: "Stage 7: Saved tab, Continue reading, Settings, Sources". Run the **Stage Check**; in Chrome: change every setting, bookmark two sections, read to the middle, reload the page, and confirm everything is as it was left.

---

## Stage 8: Tests, refinement and platform validation

### Task 15: Accessibility, overflow, wide screens and builds

**Files:**
- Create: `test/quality/accessibility_test.dart`, `test/quality/overflow_test.dart`, `test/quality/real_content_reader_test.dart`
- Modify: whatever the tests show to be wrong

**Interfaces:**
- Consumes: every screen; `pumpApp`; the bundled content.

- [ ] **Step 1: Write the tests:**

```dart
// accessibility_test.dart — for each of: Home, Library, contents list, reader, reader sheet, Saved, Settings, Sources; light and dark
testWidgets('<screen> meets tap-target, label and contrast guidelines', (t) async {
  final handle = t.ensureSemantics();
  await expectLater(t, meetsGuideline(androidTapTargetGuideline));    // 48 x 48
  await expectLater(t, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(t, meetsGuideline(textContrastGuideline));
  handle.dispose();
});

// overflow_test.dart — real bundled content and real fonts (loaded with FontLoader from assets/fonts)
for (final size in [Size(320, 568), Size(390, 844), Size(1280, 800)])
  for (final scale in [0.85, 1.6])
    for (final deviceTextScale in [1.0, 2.0])
      for (final selection in <every single language and every ordered pair>)   // 3 + 6
        for (final layout in TwoLanguageLayout.values)
          testWidgets('reader does not overflow: ...', (t) async {
            // pump the reader; scroll from top to bottom in viewport-sized steps; expect(t.takeException(), isNull) at each step
          });
// the same sizes for every other screen, with deviceTextScale 2.0

// real_content_reader_test.dart
testWidgets('the real reading shows 19 headings and reaches the end', ...);   // 'තෙරුවන් සමාකර ගැනීම' found after scrolling to the bottom
testWidgets('English + Pali shows the not-available line on sections 9, 14, 16 and 17 only (whole section)', ...);
testWidgets('on a wide screen the text column is at most 680 wide and centred', ...);
```

- [ ] **Step 2:** Run → note every failure. **Step 3:** Fix in the screens (wrap, flexible rows, padding to 48, labels); do not weaken a test. **Step 4:** `flutter test` → pass.
- [ ] **Step 5:** `grep -rnE "Platform\.is|kIsWeb|dart:io|package:http|url_launcher" lib/` → no matches. `grep -rn "Timer" lib/reader/auto_scroll.dart` → no matches.
- [ ] **Step 6:** `flutter build web --release` succeeds; note the size of `build/web`. Serve it and, with the network tab open in Chrome, confirm no request leaves localhost (no font or icon is fetched).
- [ ] **Step 7:** `flutter doctor`: if an Android toolchain is now present, `flutter build apk --debug` and run it on a device or emulator; otherwise say plainly in the report that Android and iOS have not been built or run.
- [ ] **Step 8:** Commit: "Stage 8: accessibility, overflow and wide-screen checks". Run the **Stage Check** and give the owner the closing report: what works, what was looked at, what is still open (below).

---

## Still open after this plan (for the owner, not for a task)

- English for sections 9, 14, 16, 17, the third Bodhi verse and two of the එත්තාවතා verses; Roman-letter Pali for everything.
- The four verses marked "needs checking" (listed on the Sources page), one of which only the owner or a monk can settle: the second line of the first incense verse in section 11.
- Settled by the owner on 2026-11-10: `ඨානේසු` in section 7 and `සුරාමේරය` in section 3 are correct (both are in the corrections list); the Mahamevnawa English stays for sections 4–6.
- Android build (needs the Android toolchain), iOS build (needs a Mac), an Android adaptive icon, permanent app IDs, courtesy notes to the four sources, store publishing, web hosting and offline web.
- Real chanting recordings; section cue times; lock-screen controls.

