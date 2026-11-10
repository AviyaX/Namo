# Namo Premium Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every screen of Namo a calm, premium look in a dark and a light version, built from one shared design system, without changing what the app does.

**Architecture:** Design-system first. Colours, type, spacing, radii and motion live in `lib/design/` as named roles with a dark and a light value; shared components live in `lib/design/widgets/`; every screen is then rebuilt from those parts in the brief's order (navigation, Home, Library, Reader, Saved, Settings, motion). New behaviour is limited to pure-Dart helpers for the greeting, today's gatha and library search.

**Tech Stack:** Flutter 3.47.9 / Dart 3.13.7, flutter_riverpod 3, go_router 18, material_symbols_icons, shared_preferences. No new packages, no new fonts.

**Spec:** `docs/superpowers/specs/2026-11-10-premium-redesign-design.md` (the owner's brief, word for word: `docs/superpowers/specs/2026-11-10-owner-redesign-brief.md`)

## Global Constraints

- "This is a UI/UX redesign, NOT a request to rebuild the application's functionality. Preserve all existing functionality."
- No new packages and no new font files. Nothing is fetched at run time; fonts and pictures are bundled.
- No change to routes and addresses, saved-data keys (`namo.settings.v1`, `namo.saved.v1`, `namo.position.v1`) or their formats, the content file, the content model or the content build tool.
- Verse text is shown exactly as stored: never changed, shortened or re-typed. No religious text is written by hand anywhere, including tests (tests use the bundled content or Latin placeholder content from `test/support/test_content.dart` and `test/quality/quality_support.dart`).
- Existing widget keys (`screen-*`, `reader-*`, `setting-*`, `settings-column`, `saved-column`, `sources-*`, `open-<category id>`, `heading-*`, `verse-*`, `audio-*`), tooltips and accessibility labels stay as they are.
- Touch targets are at least 48 × 48.
- Every colour on screen comes from a `NamoPalette` role. No raw colour value outside `lib/design/tokens.dart`. `textMuted` is referenced only inside `lib/design/` (disabled control labels, decoration, control outlines) — never for text people need; placeholders and explanatory hints use `textSecondary`.
- State is never shown by colour alone (filled icon, pill, tick or thumb as well).
- Spacing values: 4, 8, 12, 16, 24, 32, 48 only. Radii: 12, 16, 24 only. No text smaller than 12.
- Flat: the only shadow is `NamoPalette.floatShadow`, under the floating navigation bar, the reader's floating bar and sheets.
- Icons: Material Symbols Rounded, weight 300; outline by default (`fill: 0`), filled (`fill: 1`) only for the active tab and saved states; sizes 20 and 24.
- Motion: press 120 ms; expand, selector thumb and tab fade 200 ms; page and sheet open 300 ms, close 200 ms; ease-out; no bounce or overshoot; all instant when `MediaQuery.disableAnimationsOf(context)` is true. Press feedback is a tint, never a change of size or position.
- Material's default `Card`, `DropdownButton`, `ElevatedButton`, `NavigationBar` and `NavigationRail` are not used on any screen.
- Tests: behaviour assertions are never deleted. A test that pins the old look is rewritten for the new look and keeps guarding the same behaviour.
- Every task ends with `flutter analyze` → `No issues found!` and `flutter test` → `All tests passed!` (Flutter at `/c/Users/Dell/develop/flutter/bin/flutter`).
- Commits: stage only the files the task names; git identity is the repo's local one (Avishka Induwara); every message ends with `Co-Authored-By: Claude <noreply@anthropic.com>`. Never push.
- The `ui-ux-pro-max` skill is guidance only; it never overrides the spec.

## Review Focus

1. **Very large system text on a small phone** (320 wide, 2.0× text): navigation labels, segmented selectors and the featured card must stay readable with no overflow or clipped label. Tests in Tasks 3, 4 and 6.
2. **Theme values stored by older builds or damaged** (`"system"`, missing, wrong type, unknown word): `"system"` stays system; everything else that is not a known mode gives dark; nothing throws. Test in Task 1.
3. **Search input that is not a word**: only spaces, only invisible joiners, one character, punctuation such as `(` `\` `*`, a 5,000-character paste. Search returns no rows, never throws, and the screen shows the topic list (too short) or the nothing-found state. Tests in Tasks 7 and 8.
4. **A second topic, a topic without a picture, a topic with several readings or none**: Home and Library must lay out with the drawn lotus panel, a Collections row and chips, and counts that read correctly ("1 section", "0 sections"). Tests in Tasks 6 and 8 with `severalCategories()`.
5. **Dates at the edges**: a device clock before 1970, the day daylight saving changes, 23:59 → 00:00. The gatha index is never negative, is the same all day, and changes at local midnight. Test in Task 5.

---

### Task 1: Design tokens, type styles, both themes, dark by default

**Files:**
- Modify: `lib/design/tokens.dart`, `lib/design/typography.dart`, `lib/design/theme.dart`, `lib/settings/settings.dart`
- Test: `test/design/palette_test.dart` (new), `test/design/type_test.dart` (new), `test/design/theme_test.dart` (rewrite the look assertions), `test/settings/settings_test.dart` (add)
- Modify as needed: any existing test that pins an old colour or the old default theme

**Interfaces:**
- Consumes: nothing.
- Produces (all in `lib/design/tokens.dart` unless noted):
  - `class NamoPalette extends ThemeExtension<NamoPalette>` with `Color` fields `background, backgroundAlt, surface, border, text, textSecondary, textMuted, sage, gold, onSage, shadow`; `static const dark`, `static const light`; `static NamoPalette of(BuildContext)`.
  - Getters: `Color get pressed` (`text` at 8 %), `Color get hovered` (`text` at 4 %), `Color get sageTint` (`sage` at 14 %), `List<BoxShadow> get floatShadow` (one shadow: `shadow`, blur 24, offset `(0, 8)`).
  - `static const onPicture = Color(0xFFEAE6DC)`, `static const pictureScrim = Color(0xFF151714)`.
  - Old-name getters kept **only until Task 14** so untouched screens compile: `divider → border`, `textQuiet → textSecondary`, `heading → text`, `accent → gold`, `focus → sageTint`. Mark them with a `// Old name, removed in Task 14` comment (no `@Deprecated`, the analyzer must stay clean). `NamoColors` is deleted in this task.
  - `abstract final class NamoSpace { xs = 4, sm = 8, md = 12, lg = 16, xl = 24, xxl = 32, xxxl = 48 }` (doubles).
  - `abstract final class NamoRadius { sm = 12, md = 16, lg = 24 }` (doubles).
  - `NamoSizes`: existing `readingColumn 680`, `wideBreakpoint 840`, `touchTarget 48`, plus `homeColumn = 1040.0`, `iconSmall = 20.0`, `icon = 24.0`, `navBarHeight = 64.0`, and `static double pageMargin(double width)` → `16` under 360, `20` under 840, `32` otherwise.
  - `abstract final class NamoMotion { press = 120 ms, quick = 200 ms, open = 300 ms, close = 200 ms; curve = Curves.easeOutCubic; static Duration of(BuildContext context, Duration d) }` — `of` returns `Duration.zero` when `MediaQuery.disableAnimationsOf(context)`.
  - In `lib/design/typography.dart`: `NamoFonts.serif = 'Lora'`, `NamoFonts.sans = 'NotoSansSinhala'` (existing three names stay); `namoText` gains optional `double? letterSpacing` and its fallback list becomes the other bundled families (`[NotoSansSinhala, Lora]` minus the family itself); `abstract final class NamoType` with static methods, each `TextStyle name(Color color)`: `wordmark, screenTitle, sectionTitle, sectionTitleSinhala, cardTitle, body, label, caption, overline`.
  - `ThemeData namoTheme(Brightness)` keeps its signature.
  - `AppSettings.themeMode` defaults to `ThemeMode.dark`.

Palette values (ARGB):

| Role | dark | light |
|---|---|---|
| background | `0xFF151714` | `0xFFF7F4EC` |
| backgroundAlt | `0xFF1C1F1B` | `0xFFEFEBE1` |
| surface | `0xFF232720` | `0xFFFDFBF6` |
| border | `0xFF34382F` | `0xFFD5CFC0` |
| text | `0xFFEAE6DC` | `0xFF22251F` |
| textSecondary | `0xFFA9A698` | `0xFF4F5248` |
| textMuted | `0xFF77776D` | `0xFF72736A` |
| sage | `0xFFA8B99F` | `0xFF4F6447` |
| gold | `0xFFC6A879` | `0xFF7F6130` |
| onSage | `0xFF151714` | `0xFFFDFBF6` |
| shadow | `0x4D000000` | `0x1F22251F` |

Type scale (`family, size / height, weight`): wordmark `Lora 28 / 1.2, 500`; screenTitle `Lora 26 / 1.25, 500`; sectionTitle `Lora 20 / 1.3, 500`; sectionTitleSinhala `NotoSansSinhala 20 / 1.3, 600`; cardTitle `Lora 18 / 1.3, 500`; body `sans 15 / 1.5, 400`; label `sans 14 / 1.3, 500`; caption `sans 13 / 1.4, 400`; overline `sans 12 / 1.3, 600, letterSpacing 0.8`.

- [ ] **Step 1: Write the failing tests**

`test/design/palette_test.dart`:
- `contrast(Color a, Color b)` helper (WCAG relative luminance).
- `dark palette is the owner's values` / `light palette values`: each role's `toARGB32()` equals the table above.
- For both palettes: each of `text, textSecondary, sage, gold` against each of `background, backgroundAlt, surface` is `>= 4.5`; `textMuted` against each is `>= 3.0`; `onSage` on `sage` is `>= 4.5`; `sage` (the focus ring) against each surface is `>= 3.0`.
- `NamoPalette.onPicture` against `NamoPalette.pictureScrim` is `>= 4.5`.
- `pressed` is `text` with alpha 0.08; `sageTint` is `sage` with alpha 0.14; `floatShadow` has one shadow with `blurRadius 24`, `offset Offset(0, 8)`.
- `lerp(other, 0)` equals this palette's values and `lerp(other, 1)` the other's, for every field.

`test/design/type_test.dart`: each `NamoType` style has exactly the family, size, height and weight of the scale (weight read from `fontVariations`), overline has `letterSpacing 0.8`, and no style is under 12.

`test/design/theme_test.dart`: `namoTheme(Brightness.dark).extension<NamoPalette>()` is `NamoPalette.dark` (same for light); `scaffoldBackgroundColor` is the palette's `background`; `splashFactory` is `NoSplash.splashFactory`; `NamoSizes.pageMargin(359) == 16`, `(360) == 20`, `(839) == 20`, `(840) == 32`.

`test/settings/settings_test.dart` (add; Review Focus 2):
- `const AppSettings().themeMode == ThemeMode.dark`.
- `AppSettings.fromJson({'themeMode': 'system'}).themeMode == ThemeMode.system`; `'light'` → light; `'dark'` → dark.
- `fromJson({})`, `fromJson({'themeMode': 7})`, `fromJson({'themeMode': 'sepia'})`, `fromJson('nonsense')` → `ThemeMode.dark`, none throws.
- A widget test with `NamoMotion.of`: under `MediaQuery(data: MediaQueryData(disableAnimations: true))` it returns `Duration.zero`; otherwise the duration given.

- [ ] **Step 2: Run them and see them fail**

Run: `/c/Users/Dell/develop/flutter/bin/flutter test test/design test/settings/settings_test.dart`
Expected: compile errors / failures naming the missing roles and `NamoType`.

- [ ] **Step 3: Implement**

Tokens and type as in Interfaces. `namoTheme` is rebuilt from the palette for the given brightness: scaffold and canvas `background`; `ColorScheme` built by hand from the roles (primary `sage`, onPrimary `onSage`, secondary `gold`, surface `surface`, onSurface `text`, outline `textMuted`, outlineVariant `border`) — no `fromSeed`; text theme from `NamoType`; `splashFactory: NoSplash.splashFactory`, `highlightColor` and `hoverColor` from `pressed` / `hovered`; app bar on `background` with no elevation and no scrolled-under tint; dividers 1 px `border`; icons weight 300 in `text`; sliders and switches with a `sage` active part, `border` inactive track and a `textMuted` outline; bottom sheets on `surface` with a 24 top radius; snack bars on `surface` with `text`; tooltips on `surface` with `text` and a `border` edge; focus colour `sageTint`. Existing screens keep compiling through the old-name getters and now draw in the new colours.

- [ ] **Step 4: Run the whole suite**

Run: `/c/Users/Dell/develop/flutter/bin/flutter analyze` → `No issues found!`
Run: `/c/Users/Dell/develop/flutter/bin/flutter test` → `All tests passed!` (rewrite any test that pinned an old colour or `ThemeMode.system` as the default; keep its behaviour assertion).

- [ ] **Step 5: Commit**

```bash
git add lib/design/tokens.dart lib/design/typography.dart lib/design/theme.dart lib/settings/settings.dart test/design test/settings/settings_test.dart <any other test you rewrote>
git commit -m "Design system: palette roles for dark and light, type scale, spacing, motion; dark by default"
```

---

### Task 2: Basic shared components

**Files:**
- Create in `lib/design/widgets/`: `pressable.dart`, `page_header.dart`, `surface_card.dart`, `buttons.dart`, `progress_line.dart`, `empty_state.dart`, `floating_bar.dart`, `namo_page.dart`
- Modify: `lib/design/widgets/list_row.dart`
- Test: `test/design/widgets/` — one test file per widget file above, plus `list_row_test.dart`

**Interfaces:**
- Consumes: Task 1 tokens and `NamoType`.
- Produces:
  - `Pressable({Key? key, required VoidCallback? onTap, required Widget child, BorderRadius borderRadius = const BorderRadius.all(Radius.circular(NamoRadius.sm)), String? semanticLabel, bool? selected, bool excludeChildSemantics = false})` — the one tappable primitive. At least 48 × 48. Press: a `pressed` tint fades in over `NamoMotion.press`. Pointer hover: `hovered` tint and a click cursor. Keyboard focus: a 2 px `sage` ring drawn inside the bounds; Enter and Space activate. `onTap == null`: no tint, no cursor, not focusable, announced as disabled. Semantics: `button: true`, `enabled`, `label` when given, `selected` when given. Never changes size or position.
  - `NamoIconButton({Key? key, required IconData icon, required String tooltip, required VoidCallback? onPressed, Color? color, bool filled = false, double size = NamoSizes.icon})` — a `Pressable` circle around an `Icon(weight: 300, fill: filled ? 1 : 0)` inside a `Tooltip`; default colour `text`, disabled colour `textMuted`. `find.byTooltip(tooltip)` finds it and tapping that calls `onPressed`.
  - `PrimaryButton({Key? key, required String label, required VoidCallback? onPressed, IconData? icon})` — `sage` fill, `onSage` label in `NamoType.label`, 48 high, radius 12.
  - `QuietButton({...same})` — no fill, 1 px `textMuted` outline, label in `text`.
  - `TextAction({...same})` — no fill or outline, label in `sage`, optional trailing icon 20; at least 48 high.
  - `PageHeader({Key? key, required String title, String? caption, Widget? trailing})` — title in `NamoType.screenTitle(text)` marked as a header for screen readers; caption in `NamoType.caption(textSecondary)`.
  - `Overline(String text, {Key? key, Color? color})` — `NamoType.overline`, default `textSecondary`; the string is shown as written (no upper-casing).
  - `SurfaceCard({Key? key, required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(NamoSpace.lg), double radius = NamoRadius.md, VoidCallback? onTap, String? semanticLabel, Color? leadingLine})` — `surface` fill, 1 px `border` edge, no shadow; `leadingLine` draws a 2 px line of that colour down the leading edge; with `onTap` the whole card is a `Pressable`.
  - `ProgressLine({Key? key, required double value, String semanticsLabel = 'Reading progress', double height = 2})` — `sage` on a `border` track; value clamped to 0–1; semantics identical to the progress line in today's `lib/reader/reader_bottom_bar.dart` (same label and value text).
  - `EmptyState({Key? key, required IconData icon, required String title, required String message, String? actionLabel, VoidCallback? onAction})` — outline icon 24 in `textSecondary` inside a 64 circle of `backgroundAlt`, title in `cardTitle`, message in `body(textSecondary)`, optional `PrimaryButton`; centred, max width 360.
  - `FloatingBar({Key? key, required Widget child, EdgeInsetsGeometry padding})` — `surface`, 1 px `border`, radius 24, `floatShadow`.
  - `NamoPage({Key? key, Key? columnKey, double maxWidth = NamoSizes.readingColumn, required List<Widget> children, ScrollController? controller})` — a `Scaffold` body with no app bar: one vertical scroll view, content centred in a column of at most `maxWidth` (the `ConstrainedBox` carries `columnKey`), side padding `NamoSizes.pageMargin(width)`, top padding = top safe area + 24, bottom padding = `MediaQuery.paddingOf(context).bottom` + 24 (the shell adds its floating bar to that padding in Task 4).
  - `ListRow` keeps every existing parameter (`title, subtitle, number, titleFamily, expanded, onTap, trailing`) and gains `Widget? leading` and `String? caption`. New look: built on `Pressable`; `number` in `gold`; title `cardTitle` (or `sectionTitleSinhala` at 18 when `titleFamily` is the Sinhala family); subtitle and caption in `textSecondary`; no divider of its own.

- [ ] **Step 1: Write the failing tests**

One group per widget. The assertions that matter:
- `Pressable`: 20 × 20 child still gives a 48 × 48 tap area; `onTap` fires on tap, on Enter and on Space when focused; with `onTap: null` nothing fires and semantics has `isEnabled == false`; after `tester.sendKeyEvent(LogicalKeyboardKey.tab)` the focused `Pressable` paints a ring in `palette.sage` (find the `DecoratedBox`/`CustomPaint` by key `pressable-focus-ring`); size of the widget is identical before, during and after a press; with `disableAnimations: true` the tint is at full strength after one `pump()`.
- `NamoIconButton`: `find.byTooltip('Back')` + tap calls `onPressed`; `filled: true` gives an `Icon` with `fill == 1`, otherwise `0`; weight 300.
- Buttons: `PrimaryButton` is 48 high, its fill is `palette.sage`, its label colour `palette.onSage`; disabled buttons do not fire.
- `PageHeader`: title has header semantics; caption absent when null.
- `SurfaceCard`: fill `surface`, border `border`, no `BoxShadow`; `onTap` fires and `semanticLabel` is announced as a button.
- `ProgressLine`: `value: 0.42` announces label `Reading progress` and the same value text today's reader announces for 42 %; values `-1` and `2` are clamped.
- `EmptyState`: shows title, message and the action; `onAction` fires; no action button when `actionLabel` is null.
- `NamoPage`: at 390 wide the column is 350 wide (20 margins); at 1280 wide it is `maxWidth`; with `MediaQueryData(padding: EdgeInsets.only(bottom: 100))` the last child can be scrolled so its bottom edge is at least 100 above the viewport bottom.
- `ListRow`: all old parameters still render; `leading` and `caption` render; the whole row is one button with the title as its label (keep whatever label rule the existing tests assert).
- Every widget pumps without overflow at 320 wide with `textScaler: TextScaler.linear(2)` in both themes (Review Focus 1).

- [ ] **Step 2: Run and see them fail** — `flutter test test/design/widgets` → compile errors for the missing widgets.

- [ ] **Step 3: Implement the widgets** as specified. Colours only through `NamoPalette.of(context)`; durations only through `NamoMotion.of(context, …)`.

- [ ] **Step 4: Run the whole suite** — analyze clean, all tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/design/widgets test/design/widgets
git commit -m "Shared components: pressable, buttons, page header, surface card, progress line, empty state, floating bar, page frame, editorial row"
```

---

### Task 3: Segmented selector and the three choosers

**Files:**
- Create: `lib/design/widgets/segmented_selector.dart`, `lib/settings/choosers.dart`
- Modify: `lib/settings/settings_screen.dart` (remove `_ChoiceRow`, `LanguageChooser`, `LayoutChooser`; use the new choosers in the same places), `lib/reader/reader_settings_sheet.dart` (import path only)
- Test: `test/design/widgets/segmented_selector_test.dart` (new), `test/settings/choosers_test.dart` (new), existing `test/settings/settings_screen_test.dart` and reader sheet tests adjusted

**Interfaces:**
- Consumes: `Pressable`, tokens; `settingsProvider`, `LanguageSelection.toggle`, `ToggleOutcome`, `TwoLanguageLayout`, `ReadingLanguage` (all existing).
- Produces:
  - `class Segment<T> { const Segment(this.value, this.label); final T value; final String label; }`
  - `SegmentedSelector<T>({Key? key, required List<Segment<T>> segments, required Set<T> selected, required ValueChanged<T> onPressed, bool multi = false, bool enabled = true, required String semanticLabel})`.
    - Track: `backgroundAlt`, radius 12, 4 inner padding; segments of equal width, each at least 48 high.
    - `multi: false`: a `surface` thumb with a 1 px `border` edge slides to the selected segment over `NamoMotion.quick`; selected label `text`, others `textSecondary`.
    - `multi: true`: each selected segment has a `sageTint` fill, a `sage` label and a leading tick (`Symbols.check_rounded`, 20, `sage`).
    - `enabled: false`: labels `textMuted`, no response, segments announced as disabled.
    - Labels are centred and may wrap to two lines; when any label still does not fit its segment at the current text scale (measure with a `TextPainter`), the segments stack in a column instead of a row.
    - Semantics: the group carries `semanticLabel`; each segment has the same flags today's `_ChoiceRow` gives its rows (read it before deleting it: button, label, checked or selected state, enabled) so existing semantics tests keep passing.
    - `onPressed(value)` is called for every tap on an enabled segment, selected or not. The selector holds no state.
  - In `lib/settings/choosers.dart`, each a `ConsumerWidget` with a const constructor and no parameters: `LanguageChooser` (segments Pali, Sinhala, English in that order, `multi: true`; a refused toggle shows today's messages exactly as today: "Two languages at most. Switch one off first." / "One language always stays on."), `LayoutChooser` (the two `TwoLanguageLayout` labels; disabled with the line "Needs two languages" in `textSecondary` when one language is chosen, as today), `ThemeChooser` (Dark, Light, Same as device → `ThemeMode.dark/light/system`).

- [ ] **Step 1: Write the failing tests**

`segmented_selector_test.dart`:
- one-of-many: tapping the second of three calls `onPressed` with its value; after rebuilding with it selected and `pumpAndSettle`, the thumb's rect equals the second segment's rect; mid-animation (`pump(100 ms)`) the thumb is between the two; with `disableAnimations: true` it is at the end after one `pump()`.
- multi: selected segments show `Symbols.check_rounded`; unselected do not.
- disabled: taps call nothing; semantics `isEnabled == false`.
- every segment is at least 48 high; the three segments are equal in width in the row layout.
- semantics: each segment is a button with its label and checked state.
- no overflow and no ellipsis for the label sets `['Pali','Sinhala','English']`, `['Dark','Light','Same as device']`, `['Section by section','Verse by verse']` at 360 × 1.0, 360 × 1.5, 320 × 2.0, in both themes; at 320 × 2.0 `['Dark','Light','Same as device']` is stacked (segments share the same left edge).

`choosers_test.dart` (through `pumpApp` or a small harness with a `ProviderScope`):
- `LanguageChooser`: starting from Pali + Sinhala, tapping English shows "Two languages at most. Switch one off first." and the stored selection is unchanged; tapping Sinhala then Pali shows "One language always stays on."; tapping Sinhala then English stores `[pi, en]`.
- `LayoutChooser`: disabled with "Needs two languages" when one language is chosen; otherwise tapping stores the layout.
- `ThemeChooser`: tapping Light stores `themeMode: light` under `namo.settings.v1` and the app's `Theme.of(context).brightness` becomes light; Same as device stores `system`; Dark stores `dark`.

- [ ] **Step 2: Run and see them fail.**

- [ ] **Step 3: Implement** the selector and the choosers; replace the old rows in Settings and the reader sheet (their layout is rebuilt in Tasks 10 and 12 — here only the controls change).

- [ ] **Step 4: Run the whole suite** — analyze clean, all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/design/widgets/segmented_selector.dart lib/settings/choosers.dart lib/settings/settings_screen.dart lib/reader/reader_settings_sheet.dart test/design/widgets/segmented_selector_test.dart test/settings/choosers_test.dart <adjusted tests>
git commit -m "Segmented selector; language, layout and theme choosers use it"
```

---

### Task 4: Floating navigation bar, side rail and tab cross-fade

**Files:**
- Create: `lib/design/widgets/fade_indexed_stack.dart`
- Modify: `lib/design/widgets/app_shell.dart`, `lib/router.dart` (the shell route only), and the bottom padding of the four tab screens' scroll views (`lib/home/home_screen.dart`, `lib/library/library_screen.dart`, `lib/saved/saved_screen.dart`, `lib/settings/settings_screen.dart`) so content clears the bar
- Test: `test/design/widgets/app_shell_test.dart` (new), `test/design/widgets/fade_indexed_stack_test.dart` (new), `test/router_test.dart` (must keep passing)

**Interfaces:**
- Consumes: `FloatingBar`, `Pressable`, tokens.
- Produces:
  - `FadeIndexedStack({Key? key, required int index, required List<Widget> children})` — keeps every child mounted (state and scroll positions survive); on an index change the outgoing child fades out and the incoming fades in together over `NamoMotion.quick`; children that are not showing are offstage, have tickers off, and are out of the semantics tree and focus order.
  - `lib/router.dart`: the shell route becomes `StatefulShellRoute(builder: …AppShell…, navigatorContainerBuilder: (context, shell, children) => FadeIndexedStack(index: shell.currentIndex, children: children), branches: <unchanged>)`. Routes, branch order and `AppShell({required StatefulNavigationShell shell})` do not change.
  - `AppShell` under 840 wide: `Scaffold(extendBody: true, …)` whose bottom bar is a `FloatingBar` 16 from each side, 12 above the bottom safe area (12 above the screen edge when there is none), `NamoSizes.navBarHeight` high (it grows with the text scale; never clips its labels). Because of `extendBody`, the pages see the bar's full height in `MediaQuery.padding.bottom`.
  - From 840 wide: a rail on `backgroundAlt`, 88 wide, with a 1 px `border` line on its inner edge, inside the left safe area; destinations stacked from the top with 8 between them.
  - Destination (both layouts), in today's order with today's labels and icons (Home `home`, Library `menu_book`, Saved `bookmark`, Settings `settings`): a `Pressable` at least 48 × 48 with key `nav-<label lower-case>`; inactive: outline icon 24 and 12 px label in `textSecondary`; active: filled icon and label in `sage` on a `sageTint` pill (radius 12). Semantics: label = the tab's name, `button`, `selected` for the active one.
  - Pressing the active tab returns it to its first page: `shell.goBranch(index, initialLocation: index == shell.currentIndex)` (unchanged).

- [ ] **Step 1: Write the failing tests**

`fade_indexed_stack_test.dart`: a child's `State` survives switching away and back (a counter keeps its value); the hidden child is not hit-testable and not in semantics; mid-switch both children have an opacity strictly between 0 and 1; with `disableAnimations: true` the switch is complete after one `pump()`.

`app_shell_test.dart` (with `pumpApp`):
- at 390 × 844: four destinations with labels Home, Library, Saved, Settings in that order; each tap area at least 48 × 48; the bar's rect is 16 from the left and right edges; no `NavigationBar` widget in the tree.
- the active destination is `selected` in semantics and its `Icon` has `fill == 1`; the others `fill == 0`.
- tapping Library shows `screen-library`; scroll Settings down, go to Home, come back: the scroll offset is kept.
- from Settings → Sources, pressing the Settings destination returns to `screen-settings`.
- at 840 × 600 and 1280 × 800: the destinations are in a vertical rail at the left and no `NavigationRail` widget is in the tree; at 844 × 390 (phone landscape) the rail is used.
- for each of the four tabs at 390 × 844 and at 320 × 568: after scrolling to the end, the bottom edge of the last widget in the page is above the top edge of the bar.
- at 320 × 568 with 2.0× text, no overflow and each label is fully laid out (Review Focus 1).

- [ ] **Step 2: Run and see them fail.**

- [ ] **Step 3: Implement.** The four screens get `MediaQuery.paddingOf(context).bottom` added to their scroll padding (they are rebuilt on `NamoPage` in later tasks, which already does this).

- [ ] **Step 4: Run the whole suite** — analyze clean, all pass (rewrite tests that looked for `NavigationBar`/`NavigationDestination` to look for the `nav-*` keys or the labels; keep what they asserted).

- [ ] **Step 5: Commit**

```bash
git add lib/design/widgets/app_shell.dart lib/design/widgets/fade_indexed_stack.dart lib/router.dart lib/home/home_screen.dart lib/library/library_screen.dart lib/saved/saved_screen.dart lib/settings/settings_screen.dart test/design/widgets/app_shell_test.dart test/design/widgets/fade_indexed_stack_test.dart <adjusted tests>
git commit -m "Navigation: floating bar on phones, restyled rail on wide screens, tab cross-fade that keeps each tab's state"
```

---

### Task 5: Greeting and today's gatha (logic only)

**Files:**
- Create: `lib/home/today.dart`
- Test: `test/home/today_test.dart`

**Interfaces:**
- Consumes: `Library`, `Reading`, `Section`, `Verse`, `CheckStatus` (`lib/content/model.dart`), `ReadingLanguage`, `LanguageSelection`.
- Produces:
  - `final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);`
  - `String greetingFor(DateTime now)` → `'Good morning'` for 05:00–11:59, `'Good afternoon'` for 12:00–16:59, `'Good evening'` otherwise.
  - `class GathaPick { const GathaPick(this.reading, this.section, this.verse); final Reading reading; final Section section; final Verse verse; }`
  - `List<GathaPick> eligibleGathas(Library library)` — in content order (categories, readings, sections, verses). A verse is eligible when all hold: `check == CheckStatus.checkedAgainstSource`; `paliSi` is not null and has at most 4 lines (split on `'\n'`); none of `paliSi, paliRoman, sinhala, english` is longer than 320 characters (`runes.length`; a missing text counts as 0).
  - `int dayNumber(DateTime now)` → whole days from 1 January 1970 to the calendar date of `now` as the device shows it: `DateTime.utc(now.year, now.month, now.day).difference(DateTime.utc(1970)).inDays` (so daylight-saving shifts cannot move it).
  - `GathaPick? gathaForDay(Library library, DateTime now)` → `null` when nothing is eligible, else `eligible[dayNumber(now) % eligible.length]` with a non-negative remainder.
  - `List<(ReadingLanguage, String)> gathaTexts(Verse verse, LanguageSelection selection)` → the chosen languages, in chosen order, that the verse has text for (`verse.text(l)`); if that is empty, `[(ReadingLanguage.pali, <the verse's Pali text>)]`.

- [ ] **Step 1: Write the failing tests** (`today_test.dart`)

- greeting: 04:59 → evening, 05:00 → morning, 11:59 → morning, 12:00 → afternoon, 16:59 → afternoon, 17:00 → evening, 00:00 → evening.
- with the bundled content (`realLibrary` from `test/quality/quality_support.dart`): the eligible verse ids are exactly `s01-v1, s07-v1, s08-v1, s08-v2, s08-v3, s09-v1, s10-v1, s11-v2, s12-v1, s13-v1, s14-v1, s15-v1, s16-v1, s17-v1, s18-v1, s18-v2, s18-v3, s19-v1, s19-v2` in that order (if the ids in the file are spelled differently, match the same 19 verses and say so in the report); none has `check != checkedAgainstSource`.
- with placeholder content: a verse with 5 Pali lines, one with a 321-character English text, one marked `needsChecking`, one `unchecked`, and one with no Pali are all left out; a 4-line, 320-character verse is in.
- `gathaForDay`: the same pick at 00:00 and 23:59 of one date; a different index the next date; over `eligible.length` consecutive dates every eligible verse appears exactly once; `null` for an empty library.
- edges (Review Focus 5): `dayNumber(DateTime(1969, 12, 31)) == -1` and `gathaForDay` for that date returns the last eligible verse (no negative index, no throw); `dayNumber(DateTime(1970, 1, 1, 23, 59)) == 0`; two instants on the same calendar date 23 hours apart give the same day number.
- `gathaTexts`: chosen `[sinhala, english]` on a verse without English → only Sinhala; chosen `[english]` on a verse without English → the Pali; chosen order is kept; the strings are identical to the stored ones.

- [ ] **Step 2: Run and see them fail** — `flutter test test/home/today_test.dart`.
- [ ] **Step 3: Implement `lib/home/today.dart`.**
- [ ] **Step 4: Run the whole suite** — analyze clean, all pass.
- [ ] **Step 5: Commit**

```bash
git add lib/home/today.dart test/home/today_test.dart
git commit -m "Home logic: greeting by time of day, today's gatha chosen by the date from checked short verses"
```

---

### Task 6: Home screen

**Files:**
- Create: `lib/home/continue_card.dart`, `lib/home/featured_card.dart`, `lib/home/gatha_card.dart`, `lib/home/section_strip.dart`, `assets/pictures/home_banner.jpg` (a byte-for-byte copy of `design/card_images/home_banner.jpg`)
- Modify: `lib/home/home_screen.dart` (rewrite), `lib/home/card_art.dart`, `pubspec.yaml` (asset line), `lib/settings/sources_screen.dart` (`_pictureCredits`), `docs/pictures.md`
- Delete: `lib/home/reading_card.dart`, `test/home/reading_card_test.dart` (its behaviour assertions move to `test/home/featured_card_test.dart`)
- Test: `test/home/home_screen_test.dart` (rewrite the look, keep behaviour), `test/home/featured_card_test.dart`, `test/home/gatha_card_test.dart`, `test/settings/sources_screen_test.dart` (credit)

**Interfaces:**
- Consumes: Task 2 widgets, `today.dart`, `positionProvider`, `settingsProvider`, `libraryProvider`/`LibraryGate`, `Routes`, `readingStyle`.
- Produces (in `lib/home/card_art.dart`):
  - `cardPictures` (existing) and new `const Map<String, String> widePictures = {'cat-namaskaraya': 'assets/pictures/home_banner.jpg'}` and `const Map<String, String> featuredOverlines = {'cat-namaskaraya': 'Buddha Vandana'}`.
  - `TopicPicture({Key? key, required String categoryId, bool wide = false, BoxFit fit = BoxFit.cover, Alignment alignment = Alignment.center})` — the bundled picture (the wide one when `wide` and one exists), decoded no larger than needed (`cacheWidth` from the laid-out width × device pixel ratio, capped at 1600); for a topic with no picture, the drawn lotus panel restyled: `backgroundAlt` ground, lotus lines in `gold` at low strength. Pictures are decoration: excluded from semantics.
  - `TopicThumbnail({Key? key, required String categoryId, double size = 56})` — a square `TopicPicture` with radius 12.
  - `const pictureFadeAtText = 0.70` and `const pictureFadeAtBottom = 0.90` — the least strength of `NamoPalette.pictureScrim` behind the first line of text on a picture, and at the picture's bottom edge.
  - `int sectionCount(Category c)` and `String sectionCountLabel(int n)` → `'1 section'` / `'N sections'` (shared with Library, Task 8).

Layout decisions:
- `HomeScreen` keeps key `screen-home`, is built on `NamoPage` with `maxWidth` 680 under 840 wide and `NamoSizes.homeColumn` from 840. Blocks are 32 apart (24 under 360 wide).
- Header: "Namo" in `NamoType.wordmark(text)`, the greeting from `greetingFor(ref.watch(clockProvider)())` in `body(textSecondary)`. No settings button.
- Continue reading (`ContinueCard`): only when today's rule shows it; a tappable `SurfaceCard` with `TopicThumbnail` 56, `Overline('Continue reading')`, the reading title in `cardTitle`, the Sinhala heading of the remembered section in `caption(textSecondary)`, a `ProgressLine` and the percent as text. Same destination and the same accessibility label as today's `_ContinueReading`.
- Featured (`FeaturedCard`, first category): radius 24, clipped. Under 840: full column width, height = `min(width, 420)`, picture `cover`, centred. From 840: the wide picture, full column width, aspect 3 : 1, text block on the left half. On the picture, all in `NamoPalette.onPicture`: `Overline` from `featuredOverlines` (absent for a topic without one), title in Lora 26, subtitle in Noto Sans Sinhala 15, `sectionCountLabel`, and a `PrimaryButton` "Begin" — "Continue" when a place is remembered for that topic's reading. The scrim is a gradient of `pictureScrim`: under 840 from 0 at the top of the card to at least `pictureFadeAtText` at the top of the text block and `pictureFadeAtBottom` at the bottom edge; from 840 the same strengths running from the right of the text block to the left edge. The card and the button both open what today's card opens (the reader, at the remembered place when there is one); the card's accessibility label stays today's (`'<title>, <subtitle>, <count>'`). If the text block would not fit the picture (large text), the card grows taller; it never clips or overflows.
- Today's gatha (`GathaCard`): `SurfaceCard(leadingLine: gold)` with `Overline("Today's gatha")`, then for each `(language, text)` of `gathaTexts` a `Text` in `readingStyle(language, fontScale: 1.0, lineSpacing: 1.6, color: first ? text : textSecondary)` 12 apart, then the section heading in `caption(textSecondary)`, then `TextAction('Read in context')` → `context.go(Routes.reader(reading.id, sectionId: section.id, from: ReaderFrom.home))`. Absent when `gathaForDay` is `null`.
- Section row (`SectionStrip`): header row with the title `'In ${category.title}'` in `sectionTitle` and `TextAction('See all')` → `context.go(Routes.category(category.id))`; then a sideways-scrolling row of cards for the sections of the topic's first reading: each 148 wide, `SurfaceCard` with the number in `gold` and the Sinhala heading (at most 3 lines), opening the reader at that section (`from: ReaderFrom.home`). The row's cards are all as tall as the tallest (no fixed height, so large text cannot overflow); a card that receives keyboard focus is scrolled into view. Absent when the topic has no sections.
- Collections: only when `library.categories.length >= 2`: title "Collections" and a sideways row of picture cards (200 × 148, radius 16, `TopicPicture`, title and `sectionCountLabel` on the scrim as on the featured card) for every category after the first, each opening `Routes.category(id)`.
- From 840 wide: featured banner, then Continue reading and Today's gatha side by side with 24 between (the gatha takes the full width when there is nothing to continue), then the section row, then Collections.
- Loading and failure: `LibraryGate` as today.
- `pubspec.yaml` lists `assets/pictures/home_banner.jpg`. `_pictureCredits` gains an entry for it worded like the existing picture's (supplied by the owner on 2026-11-10, made with an AI image tool). `docs/pictures.md` moves `home_banner.jpg` to "Bundled" with its size and SHA-1 (`c8f5705c0528d81867d9d4e7ab9e429d75e2d9b6`), saying it is used for the Home banner on wide screens.

- [ ] **Step 1: Write the failing tests**

`home_screen_test.dart` (clock overridden through `clockProvider`):
- shows "Namo" and "Good morning" at 08:00, "Good evening" at 21:00.
- fresh start: no "Continue reading"; the featured button says "Begin"; tapping it opens the reader for the first reading.
- after reading (a stored position): "Continue reading" card with the reading title and a percent; the featured button says "Continue"; tapping the continue card opens the reader at the remembered section (keep the existing test's assertions and accessibility label).
- bundled content: the featured card shows "Buddha Vandana", "Buddha Wandanawa", the subtitle taken from the library object (do not type Sinhala in the test), and "19 sections".
- Today's gatha: for a fixed date the card's texts equal `gathaTexts(gathaForDay(...).verse, selection)` string for string; "Read in context" opens the reader at that section; with English only chosen and a verse lacking English, the Pali is shown.
- section row: one card per section of the first reading; tapping the third opens the reader at the third section; "See all" opens the Library with the topic open (`open-<id>` present).
- one category: no "Collections"; `severalCategories()`: "Collections" with three cards, and the cards without a picture show the lotus panel (no `Image` inside them) (Review Focus 4). A category with no readings shows "0 sections" and has no section row and a disabled featured button.
- at 1280 × 800: the featured card uses `assets/pictures/home_banner.jpg`; Continue reading and Today's gatha share a row.
- the last block can be scrolled above the navigation bar at 390 × 844.
- no overflow at 320 × 568 with 2.0× text, at 360, 390, 840, 1280 wide with 1.0× and 1.5× text, in both themes, with bundled fonts loaded (Review Focus 1).

`featured_card_test.dart`: text on the picture is `NamoPalette.onPicture` in both themes; worst-case contrast of `onPicture` over `pictureScrim` at strength `pictureFadeAtText` laid on pure white is at least 4.5 (compute it in the test); the card's semantics label is `'<title>, <subtitle>, <count>'`.

`sources_screen_test.dart`: a credit line for the Home banner picture is present.

- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement** the screen and its parts, add the asset, credit and `docs/pictures.md` entry. Confirm the copy is identical: `sha1sum assets/pictures/home_banner.jpg` → `c8f5705c0528d81867d9d4e7ab9e429d75e2d9b6`.
- [ ] **Step 4: Run the whole suite** — analyze clean, all pass.
- [ ] **Step 5: Commit**

```bash
git add lib/home pubspec.yaml assets/pictures/home_banner.jpg lib/settings/sources_screen.dart docs/pictures.md test/home test/settings/sources_screen_test.dart <adjusted tests>
git commit -m "Home: header and greeting, continue reading, featured picture card, today's gatha, section row, collections"
```

---

### Task 7: Library search (logic only)

**Files:**
- Create: `lib/library/search.dart`
- Test: `test/library/search_test.dart`

**Interfaces:**
- Consumes: content model, `ReadingLanguage`, `LanguageSelection`.
- Produces:
  - `const searchMinLength = 2;`
  - `String foldForSearch(String s)` — lower-cases; maps Latin letters with diacritics to their base letters through an explicit table that covers at least `ā ī ū ṅ ñ ṭ ḍ ṇ ḷ ṃ ṁ ś ṣ ṛ` and their capitals plus the precomposed Latin-1 accented vowels; removes U+200D and U+200C; turns every run of whitespace (including line breaks and U+00A0) into one space; trims. Sinhala letters are left as they are.
  - `class SearchHit { final Category category; final Reading reading; final Section section; final String? line; final ReadingLanguage? lineLanguage; final bool lineLanguageChosen; }`
  - `List<SearchHit> searchLibrary(Library library, String query, LanguageSelection selection)`:
    - folded query shorter than `searchMinLength` characters (runes) → `[]`.
    - plain "contains" on folded text; the query is never treated as a pattern.
    - one hit per matching section, in content order. A section matches when the folded query is contained in: its category's title or subtitle, its reading's title, its own heading, or any text of any of its verses (`paliSi`, `paliRoman`, `sinhala`, `english`).
    - `line`: `null` unless a verse text matched. Language order: the chosen languages in chosen order, then Pali, Sinhala, English (Pali means `paliSi` then `paliRoman`). For the first language in that order with a matching verse (verses in content order): the first stored line (split on `'\n'`) whose folded form contains the query; if the match only exists across a line break, the first line of that verse text. The line is returned exactly as stored apart from trimming spaces at its ends. `lineLanguage` is that language; `lineLanguageChosen` says whether it is one of the chosen ones.

- [ ] **Step 1: Write the failing tests** (`search_test.dart`)

With placeholder content (Latin text, including Roman Pali words with diacritics such as `Saṅgha`, `Buddhaṃ`):
- `foldForSearch('  Saṅgha\n  VANDĀMI ')` → `'sangha vandami'`; joiners removed (`'a‍b‌c'` → `'abc'`).
- `sangha`, `SANGHA` and `saṅgha` all find the section whose verse has `Saṅgha`.
- a heading match gives a hit with `line == null`; a verse match gives the stored line, unchanged.
- two verses and a heading of one section match → one hit.
- a category-title match returns every section of that category, in order.
- language order: the query matches the English and the Pali of a section; chosen `[english]` → `lineLanguage == english`, `lineLanguageChosen == true`; chosen `[sinhala]` → `lineLanguage == pali`, `lineLanguageChosen == false`.
- a match across a line break (`'end of one\nstart of two'`, query `one start`) → the hit's line is `'end of one'`.
- Review Focus 3: queries `''`, `' '`, `'a'`, `'‍‍‍'`, `'(('`, `'\\'`, `'.*'`, `'[a-'` and a 5,000-character string return `[]` or literal matches only and never throw; `'.*'` does not match everything.

With the bundled content (`realLibrary`; take query strings from the library object, never typed by hand):
- the first three characters of a section's Sinhala heading find that section.
- a word taken from a verse's `paliSi` finds that verse's section and the hit's line contains it.
- a word taken from a verse's `english` finds its section, also when upper-cased.
- every hit's `line`, when not null, is a line of one of that section's stored verse texts.

- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement `lib/library/search.dart`.**
- [ ] **Step 4: Run the whole suite** — analyze clean, all pass.
- [ ] **Step 5: Commit**

```bash
git add lib/library/search.dart test/library/search_test.dart
git commit -m "Library search logic: folded contains-search over titles, headings and verses in all languages"
```

---

### Task 8: Library screen with search

**Files:**
- Create: `lib/design/widgets/search_field.dart`, `lib/design/widgets/choice_chips.dart`
- Modify: `lib/library/library_screen.dart` (rewrite the look; keep the open/close logic and `_settle`)
- Test: `test/library/library_screen_test.dart`, `test/library/library_flow_test.dart` (keep behaviour, adjust look), `test/library/library_search_test.dart` (new), `test/design/widgets/search_field_test.dart` (new)

**Interfaces:**
- Consumes: `NamoPage`, `PageHeader`, `ListRow`, `TopicThumbnail`, `sectionCount`, `sectionCountLabel`, `EmptyState`, `searchLibrary`, `searchMinLength`, `openCategoriesProvider`, `settingsProvider`.
- Produces:
  - `SearchField({Key? key, required TextEditingController controller, required String label, ValueChanged<String>? onChanged})` — `backgroundAlt` fill, radius 12, 48 high (grows with text scale), leading `Symbols.search_rounded` 20 in `textSecondary`, the label as hint text in `textSecondary` and as the accessibility label, input text in `body(text)`, a `NamoIconButton(Symbols.close_rounded, tooltip: 'Clear search')` only while there is text (it empties the field and calls `onChanged('')`), a 2 px `sage` ring when focused; never autofocuses.
  - `ChoiceChips<T>({Key? key, required List<Segment<T>> options, required T selected, required ValueChanged<T> onSelected})` — a wrapping row of pills (radius 12, at least 48 high tap area): selected pill `sageTint` fill, `sage` label and a tick; others a 1 px `textMuted` outline and `textSecondary` label; each a button with selected state.

Screen decisions:
- `LibraryScreen({openCategory, openReading})` keeps its constructor and key `screen-library`; built on `NamoPage`.
- `PageHeader(title: 'Library', caption: '<n> collection(s) · <m> section(s)')` — `'1 collection'` / `'N collections'`, sections through `sectionCountLabel`, counted from the library.
- `SearchField(label: 'Search the library')`, field key `library-search`. The query lives in the screen's state only.
- Chips only when there are two or more categories: "All" then each category title; choosing one shows only that category's row; the choice is not stored.
- Topic rows: `ListRow(leading: TopicThumbnail, title, subtitle (Sinhala), caption: sectionCountLabel, trailing: chevron that turns when open)`. Opening and closing in place, the 200 ms expand (instant with reduced motion), the remembered open set, and `Column(key: ValueKey('open-<id>'))` stay exactly as they are. Section rows: `ListRow(number, title: heading in the Sinhala family, trailing: Symbols.chevron_right_rounded 20 in textSecondary)` → the reader at that section (as today).
- While the folded query has at least `searchMinLength` characters: the chips and topic list are replaced by the results, key `library-results`: one `ListRow` per `SearchHit` (number, Sinhala heading, and — when `line` is not null — the line under it in `readingStyle` at 15, `textSecondary`, at most two lines with an ellipsis, preceded by the language's `label` in `caption` when `lineLanguageChosen` is false) → the reader at that section. With no hits: `EmptyState(icon: Symbols.search_off_rounded, title: 'No results for “<query as typed, trimmed>”', message: 'Try a word from a section title or a verse.')`.
- Arriving with `openCategory`/`openReading`: opens that topic once as today, and also empties the search field and resets the chip to "All".

- [ ] **Step 1: Write the failing tests**

`search_field_test.dart`: not focused on first build; typing shows the clear button; `find.byTooltip('Clear search')` empties the field and calls `onChanged('')`; semantics label is the given label; no overflow at 320 × 2.0.

`library_search_test.dart` (through `pumpApp(location: '/library')`):
- one character typed: the topic list is still shown; two characters that match: `library-results` replaces it.
- bundled content: typing the first three characters of the third section's heading (taken from `realLibrary`) shows a row for that section; tapping it opens the reader at that section (`heading-<section id>` on screen).
- a query matching a verse shows that verse's line under the heading; when the matching language is not a chosen one, its language name is shown.
- a query with no match shows the title `No results for “zzzz”` and "Try a word from a section title or a verse."
- queries `'  '`, `'(('`, `'\\'` and a 5,000-character paste do not throw (Review Focus 3).
- clearing the field brings the topic list back with the same topics open as before.
- with a query typed, navigating to `/library?open=<category id>` empties the field and shows that topic open.
- the query is not written to the key-value store.
- header caption: bundled content → `1 collection · 19 sections`; `severalCategories()` → `4 collections · <counted> sections`; chips present only in the second case; choosing a chip leaves only that topic's row (Review Focus 4).

Existing Library tests keep passing: expand in place, remembered open state, opening from an address, section rows opening the reader.

Overflow: the screen at 320 × 2.0 and at 360, 390, 840, 1280 × 1.0/1.5, both themes, with a topic open and with results showing.

- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the whole suite** — analyze clean, all pass.
- [ ] **Step 5: Commit**

```bash
git add lib/library/library_screen.dart lib/design/widgets/search_field.dart lib/design/widgets/choice_chips.dart test/library test/design/widgets/search_field_test.dart
git commit -m "Library: page header with counts, search with results and nothing-found state, editorial topic and section rows"
```

---

### Task 9: Reader chrome

**Files:**
- Modify: `lib/reader/reader_screen.dart` (top bar and scaffold only), `lib/reader/reader_body.dart` (heading, verse spacing, bottom space), `lib/reader/reader_bottom_bar.dart`, `lib/audio/audio_controls.dart`
- Test: `test/reader/reader_screen_test.dart` and the other `test/reader/*` and `test/audio/*` files (keep every behaviour assertion; adjust look assertions), `test/reader/reader_chrome_test.dart` (new)

**Interfaces:**
- Consumes: `NamoIconButton`, `ProgressLine`, `FloatingBar`, tokens, `NamoType`.
- Produces: no new public API. `ReaderBottomBar` keeps `onPrevious, onNext, onPlay, autoScroll, audio`; its `progress` parameter moves to the top bar (the screen passes the same value to a `ProgressLine` there).

Decisions (behaviour untouched: position saving, back handling, screen-awake, auto-scroll and pause-on-touch, audio link, bookmarks, favourites):
- Top bar on `background`, no shadow, inside the top safe area: `NamoIconButton(Symbols.arrow_back_rounded, tooltip: 'Back')`; the reading title in `label(textSecondary)`, one line, ellipsis; the favourite button — `Symbols.favorite_rounded`, outline in `text` when off, filled in `gold` when on, today's tooltips; the settings button — `Symbols.tune_rounded`, key `reader-settings`, tooltip 'Reading settings'.
- Directly under the top bar, full width: `ProgressLine(value: <today's progress value>)` — label 'Reading progress' as today.
- Section heading: the number in `gold` (`sectionTitle` size), the heading in `sectionTitleSinhala(text)`, the bookmark `NamoIconButton(Symbols.bookmark_rounded)` at the trailing edge — outline when off, filled `gold` when on, tooltips 'Bookmark this section' / 'Remove bookmark' — and a 1 px `border` line beneath. Notes keep their wording, in `caption(textSecondary)`. Keys `heading-<section id>` and `verse-<verse id>-<language code>` stay on the same widgets the position logic measures.
- Verse text: first language `text`, second `textSecondary` (as today); 24 between verses, 12 between the two languages of one verse; 32 above a section heading that is not the first.
- Control bar: a `FloatingBar` 16 from each side and 12 above the bottom safe area, at most 680 wide, centred. Row: previous (`reader-prev`), a round 56 `sage` button with an `onSage` icon for auto-scroll (`reader-play`, today's three-state tooltips), next (`reader-next`). With a recording, `AudioControls` sits above that row inside the same bar, separated by a 1 px `border` line; without one it is absent (as today). `AudioControls` is restyled with the same parts (keys `audio-play`, `audio-restart`, tooltips and the failure message unchanged).
- The text list's bottom padding is the bar's measured height + 12 + the bottom safe area + 24, so the last line can be brought fully above the bar; the bar floats over the text (the list is not shortened).

- [ ] **Step 1: Write the failing tests** (`reader_chrome_test.dart`, bundled content)

- top bar: Back, favourite and 'Reading settings' are found by tooltip and are at least 48 × 48; no `AppBar` shadow (`elevation == 0` or no `AppBar`).
- the progress line's top edge equals the top bar's bottom edge, it spans the full width, and semantics label 'Reading progress' is present exactly once.
- favourite off → icon `fill == 0`; after tapping → `fill == 1` and colour `palette.gold`; same for a section's bookmark.
- `reader-play` is 56 × 56 with fill `palette.sage`; `reader-prev` and `reader-next` at least 48 × 48.
- after scrolling to the end, the bottom of the last verse text is above the top of the control bar; at 390 × 844 and 844 × 390.
- with the fake recording from the existing audio tests: `audio-play` is inside the floating bar, above `reader-play`; without a recording there is no `audio-play`.
- no overflow at 320 × 2.0 and at 360, 390, 840, 1280 × 1.0/1.5 in both themes.

Every existing reader and audio test keeps passing (position, back, awake, auto-scroll, previous/next, bookmarks, favourites).

- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the whole suite** — analyze clean, all pass.
- [ ] **Step 5: Commit**

```bash
git add lib/reader/reader_screen.dart lib/reader/reader_body.dart lib/reader/reader_bottom_bar.dart lib/audio/audio_controls.dart test/reader test/audio
git commit -m "Reader: quiet top bar with progress line, section heading with gold number, floating control bar"
```

---

### Task 10: Reading settings sheet and setting controls

**Files:**
- Create: `lib/design/widgets/sheet_frame.dart`
- Modify: `lib/reader/reader_settings_sheet.dart`, `lib/settings/setting_controls.dart`
- Test: `test/reader/reader_settings_sheet_test.dart` (new or the existing sheet tests), `test/design/widgets/sheet_frame_test.dart` (new), `test/settings/settings_screen_test.dart` (must keep passing)

**Interfaces:**
- Consumes: choosers (Task 3), `QuietButton`, tokens.
- Produces:
  - `SheetFrame({Key? key, required String title, required List<Widget> children})` — `surface`, top radius 24, `floatShadow`, a 32 × 4 grab handle in `border` colour, the title in `sectionTitle(text)` as a header, scrollable content at most 680 wide, 20 side padding, bottom padding = bottom safe area + 24; never taller than 90 % of the screen.
  - `showReaderSettingsSheet(context, {required onBackToBeginning})` keeps its signature.
  - `lib/settings/setting_controls.dart`: `SliderSetting` and `ScrollSpeedControl` keep their constructors, keys, labels and semantics; new look — label in `label(text)`, current value in `caption(textSecondary)`, slider with `sage` active track and thumb on a `border` track; the scroll-speed choices (Slow / Normal / Fast as today) become a `SegmentedSelector` above the fine slider if that is what today's control offers (keep exactly the choices and values it has). New `SettingLabel(String text, {String? hint})` — a row label in `label(text)` with an optional hint in `caption(textSecondary)`; `SettingsHeading` stays until Task 12 removes it.

Sheet content, in order, 24 apart: `SettingLabel('Languages')` + `LanguageChooser`; `SettingLabel('When two languages show')` + `LayoutChooser`; text size (`reader-text-size`); line spacing (`reader-line-spacing`); scroll speed (`reader-scroll-speed`); `QuietButton('Back to the beginning')` calling `onBackToBeginning` as today.

- [ ] **Step 1: Write the failing tests**

- the sheet shows the title "Reading settings" and the controls in the order above (compare vertical positions).
- the three sliders are found by their keys and still change `settingsProvider` (existing assertions).
- "Back to the beginning" calls the callback and closes the sheet as today.
- choosing a third language inside the sheet shows "Two languages at most. Switch one off first." visibly (not hidden behind the sheet).
- `SheetFrame`: top corners radius 24; content scrolls when taller than the screen (pump at 390 × 500 with 1.5× text, scroll to "Back to the beginning", tap it); no overflow at 320 × 2.0, both themes.

- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the whole suite** — analyze clean, all pass.
- [ ] **Step 5: Commit**

```bash
git add lib/design/widgets/sheet_frame.dart lib/reader/reader_settings_sheet.dart lib/settings/setting_controls.dart test/reader test/design/widgets/sheet_frame_test.dart test/settings
git commit -m "Reading settings sheet: sheet frame, segmented choices, restyled sliders"
```

---

### Task 11: Saved screen

**Files:**
- Modify: `lib/saved/saved_screen.dart`
- Test: `test/saved/saved_screen_test.dart`

**Interfaces:**
- Consumes: `NamoPage`, `PageHeader`, `Overline`, `ListRow`, `TopicThumbnail`, `NamoIconButton`, `EmptyState`, `savedProvider`, `Routes`.
- Produces: no new public API. `SavedScreen` keeps key `screen-saved`; the column keeps key `saved-column`.

Decisions:
- `PageHeader(title: 'Saved')`.
- Both groups empty: only `EmptyState(icon: Symbols.bookmark_rounded, title: 'Nothing saved yet', message: 'Bookmark a section or favourite a reading and it will wait for you here.', actionLabel: 'Open the Library', onAction: () => context.go(Routes.library))`.
- Otherwise two groups, 32 apart, each headed by `Overline('Bookmarks · <count>')` / `Overline('Favourites · <count>')`:
  - Bookmark rows: `ListRow(number: <section number>, title: <Sinhala section heading>, subtitle: <reading title>, trailing: remove button)`.
  - Favourite rows: `ListRow(leading: TopicThumbnail(<the reading's category>), title: <reading title>, subtitle: <category subtitle>, trailing: remove button)`.
  - Remove buttons are `NamoIconButton`s with today's icons and tooltips. Rows open the reader exactly as today (`from: ReaderFrom.saved`).
  - An empty group shows today's line ("No bookmarks yet." / "No favourites yet.") in `body(textSecondary)`.
- Saved entries whose reading or section no longer exists are handled as today.

- [ ] **Step 1: Write the failing tests**

- nothing saved: "Nothing saved yet", the message, and "Open the Library", which shows `screen-library`; neither "No bookmarks yet." nor "No favourites yet." is shown.
- only a bookmark: the bookmark row and "No favourites yet."; only a favourite: the reverse.
- group labels show the counts (`Bookmarks · 2`).
- existing assertions kept: rows open the reader at the right place; remove buttons (by tooltip) remove and persist; back from the reader returns to Saved.
- the last row can be scrolled above the navigation bar; no overflow at 320 × 2.0 and the standard widths in both themes.

- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the whole suite** — analyze clean, all pass.
- [ ] **Step 5: Commit**

```bash
git add lib/saved/saved_screen.dart test/saved/saved_screen_test.dart
git commit -m "Saved: page header, grouped editorial rows with counts, one calm empty state"
```

---

### Task 12: Settings groups, Sources, not-found, loading and error

**Files:**
- Modify: `lib/settings/settings_screen.dart`, `lib/settings/setting_controls.dart` (add `SettingsGroup`, remove `SettingsHeading`), `lib/settings/sources_screen.dart`, `lib/design/widgets/not_found.dart`, `lib/library/library_gate.dart`
- Test: `test/settings/settings_screen_test.dart`, `test/settings/sources_screen_test.dart`, `test/router_test.dart` (not-found), `test/library/library_screen_test.dart` or wherever the loading/error states are tested

**Interfaces:**
- Consumes: `NamoPage`, `PageHeader`, `SurfaceCard`, choosers, `SliderSetting`, `ScrollSpeedControl`, `SettingLabel`, `ListRow`, `EmptyState`, `PrimaryButton`, `audioCatalogueProvider`, `libraryProvider`.
- Produces: `SettingsGroup({Key? key, required IconData icon, required String label, required List<Widget> children})` — a `SurfaceCard` (radius 16) with a header row (outline icon 20 in `textSecondary`, label in `overline(textSecondary)`) and its children separated by 1 px `border` lines; the label is a header for screen readers.

Settings (`screen-settings`, column key `settings-column`, `PageHeader(title: 'Settings')`), groups 16 apart, in this order:

| Group (icon) | Contents |
|---|---|
| Appearance (`Symbols.palette_rounded`) | `SettingLabel('Theme')` + `ThemeChooser` |
| Reading (`Symbols.menu_book_rounded`) | text size (`setting-text-size`); line spacing (`setting-line-spacing`); `SettingLabel('When two languages show')` + `LayoutChooser` |
| Languages (`Symbols.translate_rounded`) | `LanguageChooser`; caption "Choose one or two." |
| Audio (`Symbols.graphic_eq_rounded`) | a switch row with today's label "Start auto-scroll when a recording starts" (same semantics as today's switch: one merged toggle with that label); caption "No recordings are included yet." while no reading has a recording by the same lookup the reader uses |
| Auto-scroll (`Symbols.swipe_vertical_rounded`) | scroll speed (`setting-scroll-speed`) |
| About Namo (`Symbols.info_rounded`) | the line "Free. No ads. Works offline." in `body(textSecondary)`; `ListRow(title: 'Sources', trailing: chevron)` → `Routes.sources` |

The switch is a custom-styled Material `Switch` (track `sage` when on, `border` when off with a `textMuted` outline) in a 48-high pressable row; no `SwitchListTile`.

Sources (`screen-sources`, `sources-column`, `sources-icon`, `correction-*`, `check-*` keys kept): `NamoPage` with a back `NamoIconButton` (tooltip 'Back') above `PageHeader(title: <today's title>)`; each credit block a `SurfaceCard`; every word of every credit, statement and check list unchanged.

Not found: `EmptyState` with today's wording and its "Go to Home" action. Loading: a centred 24 progress ring in `sage` with today's semantics; error: `EmptyState` with today's wording and retry action (if today has one).

- [ ] **Step 1: Write the failing tests**

- each of the six group labels is on screen, in order; each control is inside its group (`find.descendant(of: group, matching: control key or label)`): `setting-text-size`, `setting-line-spacing` and the layout chooser in Reading; the language chooser in Languages; the switch in Audio; `setting-scroll-speed` in Auto-scroll; the theme chooser in Appearance; "Sources" in About Namo.
- "Choose one or two." and "Free. No ads. Works offline." are shown; "No recordings are included yet." is shown with the bundled content and hidden when the audio catalogue is overridden with a recording.
- existing assertions kept: every control still changes and stores its setting; the switch toggles by tapping its label; "Sources" opens `screen-sources`; Sources' texts and keys; not-found shows its wording and "Go to Home" works.
- no `SwitchListTile`, `Card` or `AppBar` in Settings.
- the last group can be scrolled above the navigation bar; no overflow at 320 × 2.0 and the standard widths in both themes for Settings, Sources and not-found.

- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the whole suite** — analyze clean, all pass.
- [ ] **Step 5: Commit**

```bash
git add lib/settings lib/design/widgets/not_found.dart lib/library/library_gate.dart test/settings test/router_test.dart <adjusted tests>
git commit -m "Settings in six groups; Sources, not-found, loading and error states restyled"
```

---

### Task 13: Motion, system bars, splash and web colours

**Files:**
- Create: `lib/design/transitions.dart`
- Modify: `lib/router.dart` (page builders for pages outside the tab roots), `lib/reader/reader_settings_sheet.dart` (sheet animation), `lib/app.dart`, `pubspec.yaml` (`flutter_native_splash.color`), `web/index.html`, `web/manifest.json`, and the splash files the tool regenerates under `android/`, `ios/`, `web/`
- Test: `test/design/transitions_test.dart` (new), `test/quality/reduced_motion_test.dart` (new), `test/quality/web_manifest_test.dart` (colours), `test/app_chrome_test.dart` (new)

**Interfaces:**
- Consumes: `NamoMotion`, `NamoPalette`.
- Produces: `Page<T> namoPage<T>({required LocalKey key, required Widget child, required BuildContext context})` in `lib/design/transitions.dart` — a `CustomTransitionPage`: entering fades in and rises 12 px over `NamoMotion.open` (300 ms), leaving fades out over `NamoMotion.close` (200 ms), ease-out, both zero when `MediaQuery.disableAnimationsOf(context)`.

Decisions:
- The reader and Sources routes use `pageBuilder: (context, state) => namoPage(key: state.pageKey, child: …, context: context)`. Tab roots keep their cross-fade (Task 4). Routes, paths and parameters do not change.
- The settings sheet opens in 300 ms and closes in 200 ms (ease-out), instantly with reduced motion (`sheetAnimationStyle`).
- `NamoApp`: inside `MaterialApp.router(builder: …)`, where `Theme.of(context)` is the theme in use, wrap the app in `AnnotatedRegion<SystemUiOverlayStyle>` — transparent status bar, status-bar and navigation-bar icon brightness opposite to the theme's brightness, `systemNavigationBarColor: palette.background` — and in `Title(title: 'Namo', color: palette.background)` so the browser's theme colour follows the theme in use.
- Splash and web: `#2B3837` → `#151714` in `pubspec.yaml`, `web/index.html` and `web/manifest.json` (`background_color` and `theme_color`). Run `dart run flutter_native_splash:create`, then check `grep -n ASSETCATALOG ios/Runner.xcodeproj/project.pbxproj`: `ASSETCATALOG_COMPILER_APPICON_NAME` must still be `AppIcon` in every build configuration (the tool has broken it before; restore it if changed). If the tool rewrites `web/index.html`, confirm the page still has no outside requests and still carries the app's own loading markup.

- [ ] **Step 1: Write the failing tests**

- `transitions_test.dart`: pushing a `namoPage` — at 150 ms the page's opacity is between 0 and 1 and it is offset down by less than 12 and more than 0; settled at 300 ms; popping settles within 200 ms; with `disableAnimations: true` both are complete after one `pump()`.
- `reduced_motion_test.dart` (app pumped with `disableAnimations: true`): after one `pump()` following each action the end state is reached — switching tab, opening a Library topic, opening the reader, opening the settings sheet, moving a segmented selector.
- `app_chrome_test.dart`: with the dark theme the nearest `AnnotatedRegion<SystemUiOverlayStyle>` value has `systemNavigationBarColor == NamoPalette.dark.background` and light status-bar icons; after choosing Light in Settings, `NamoPalette.light.background` and dark icons; with "Same as device" and `platformBrightness` light → the light values.
- `web_manifest_test.dart`: `background_color` and `theme_color` are `#151714`; `web/index.html` no longer contains `2B3837`; `pubspec.yaml`'s splash colour is `#151714`.

- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement**, run the splash tool, do the iOS check.
- [ ] **Step 4: Run the whole suite** — analyze clean, all pass; `flutter build web --no-web-resources-cdn` succeeds.
- [ ] **Step 5: Commit**

```bash
git add lib/design/transitions.dart lib/router.dart lib/reader/reader_settings_sheet.dart lib/app.dart pubspec.yaml web android ios test/design/transitions_test.dart test/quality test/app_chrome_test.dart
git commit -m "Motion: page and sheet transitions, instant with reduced motion; system bars follow the theme; dark splash on all platforms"
```

---

### Task 14: Clean-up and standing design rules

**Files:**
- Modify: `lib/design/tokens.dart` (remove the old-name getters), any file still using them, `test/quality/overflow_test.dart`, `test/quality/accessibility_test.dart`
- Create: `test/quality/design_rules_test.dart`, `tools/check_ui_glyphs.py`, `tools/test_check_ui_glyphs.py`
- Delete: any widget or helper left unused by the redesign (name each in the report)

**Interfaces:**
- Consumes: everything above.
- Produces: `python -I -X utf8 tools/check_ui_glyphs.py .` — prints `all interface characters are in NotoSansSinhala` or lists the characters of English interface strings that the label font lacks (those are drawn in Lora by the fallback) and exits 0 either way; exits 1 only when a listed character is in neither bundled font.

- [ ] **Step 1: Write the failing tests**

`design_rules_test.dart` (reads the files under `lib/` as text):
- no `Color(0x`, `Color.fromARGB`, `Color.fromRGBO` and no `Colors.` other than `Colors.transparent` outside `lib/design/tokens.dart`.
- `textMuted` appears only in files under `lib/design/`.
- none of `divider`, `textQuiet`, `heading`, `accent`, `focus` is read from a palette anywhere (`\.(divider|textQuiet|heading|accent|focus)\b` after a palette expression — or simply: the getters no longer exist and `NamoColors` appears nowhere).
- none of `Card(`, `ElevatedButton`, `DropdownButton`, `NavigationBar(`, `NavigationRail(`, `SwitchListTile`, `ListTile(` appears under `lib/`.
- no `size:` argument to `namoText` and no `fontSize:` below 12 under `lib/`.
- every `Duration(milliseconds:` under `lib/` outside `lib/design/tokens.dart` is listed in an allow-list in the test with a reason (auto-scroll ticks, position-save debounce and the like) — motion durations come from `NamoMotion`.

`overflow_test.dart`: every screen — Home (fresh and with a remembered place), Library (closed, a topic open, search results, nothing found), Reader (one and two languages, settings sheet open), Saved (empty and filled), Settings, Sources, not-found — at 360 × 800, 390 × 844, 840 × 900, 1280 × 800 and 844 × 390, each at 1.0× and 1.5× text, in both themes, with the bundled fonts loaded: no overflow error and no exception.

`accessibility_test.dart`: Flutter's `androidTapTargetGuideline`, `iOSTapTargetGuideline`, `labeledTapTargetGuideline` and `textContrastGuideline` pass on Home, Library, Reader, Saved and Settings in both themes (extend what exists; if `textContrastGuideline` flags text drawn over the picture, check that text against the scrim by calculation instead and say so in the test).

`tools/test_check_ui_glyphs.py`: the string extractor finds single- and double-quoted Dart string literals and skips imports and keys; a character missing from a font's cmap is reported; the real project run exits 0.

- [ ] **Step 2: Run and see them fail** (the getters still exist; some screens may still break a rule).
- [ ] **Step 3: Fix what the rules find**, remove the old-name getters and unused code, write the glyph tool.
- [ ] **Step 4: Run everything**

```bash
/c/Users/Dell/develop/flutter/bin/flutter analyze          # No issues found!
/c/Users/Dell/develop/flutter/bin/flutter test             # All tests passed!
python -I -X utf8 tools/test_build_content.py              # OK
python -I -X utf8 tools/test_check_ui_glyphs.py            # OK
python -I -X utf8 tools/check_ui_glyphs.py .               # exit 0
python -I -X utf8 tools/build_content.py . --check         # content file is up to date
/c/Users/Dell/develop/flutter/bin/flutter build web --no-web-resources-cdn
```

- [ ] **Step 5: Commit**

```bash
git add lib test tools/check_ui_glyphs.py tools/test_check_ui_glyphs.py
git commit -m "Clean-up: old palette names removed; standing tests for colour, type, motion and overflow rules in both themes"
```

---

## After the tasks (the controller, not an implementer)

1. Whole-branch review against the spec.
2. Inspect every screen in the browser in both themes at 360, 375, 390, 768, 840, 1024, 1280 and 1440 wide and in phone landscape; fix what is uneven.
3. Walk `.claude/skills/ui-ux-pro-max/references/pro-rules.md` as the last gate and record the result.
4. Report to the owner in plain words what is visible at http://127.0.0.1:8765/ and what is still theirs to decide.
