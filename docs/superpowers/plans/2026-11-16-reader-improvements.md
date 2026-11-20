# Reader Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In a pirith, make "scroll by itself" and "chant" two unmistakable buttons; give the recording a speed control that is remembered; add a "Side by side" layout (Pali left, Sinhala right) for gatha readings and pirith, offered only for Pali with Sinhala.

**Architecture:** Three small, mostly independent changes to the existing reader. (1) The chanting bar (`ReaderBottomBar`) gets a recording row (restart · slider · speed) and a control row (previous · Scroll · Chant · next) with captions. (2) `AppSettings` gains `chantSpeed`; `ChantPlayer` gains `setSpeed`; the reader passes the setting to the bar and the player. (3) `TwoLanguageLayout` gains `sideBySide`; `buildReaderItems` emits a verse-pair item and flags pirith blocks; `ReaderBody` draws both as two columns; the choosers show the third segment and refuse it for other language pairs; the pirith sheet shows a two-segment chooser.

**Tech Stack:** Flutter 3.47.9 at `/c/Users/Dell/develop/flutter/bin/flutter` (not on PATH), flutter_riverpod 3, just_audio ^0.10.6 (`setSpeed`), material_symbols_icons. No new packages.

**Spec:** `docs/superpowers/specs/2026-11-16-reader-improvements-design.md`. Read it first; where this plan and the spec disagree, the spec wins.

## Global Constraints

- Nothing under `lib/tipitaka/` changes. No content file changes.
- Keys the tests find controls by stay exactly: `reader-prev`, `reader-next`, `reader-autoscroll`, `chant-play`, `chant-restart`, `chant-slider`, `reader-play`; new: `chant-speed`.
- Exact interface strings: captions `Scroll` and `Chant`; speed labels `0.75×`, `1×`, `1.25×`, `1.5×` (U+00D7, which both label fonts have); tooltips unchanged (`Start auto-scroll` / `Pause auto-scroll` / `Resume auto-scroll`, `Play chanting` / `Pause chanting`, `Restart chanting`); layout segment `Side by side`; pirith segments `Meaning below` and `Side by side`; refusal `Side by side needs Pali and Sinhala.`; disabled hint stays `Needs two languages`.
- Speeds: exactly `[0.75, 1.0, 1.25, 1.5]`; cycle order 1 → 1.25 → 1.5 → 0.75 → 1; default 1.0; JSON key `chantSpeed`.
- Side by side applies only when the two chosen languages are exactly Pali and Sinhala (either order). Otherwise everything behaves as "Verse by verse" while the saved value is kept. Pali is drawn on the left whichever was chosen first.
- Pirith blocks: two passages side by side when the screen is wide (`>= NamoSizes.wideBreakpoint`, not a unit kept line by line — as today) **or** the layout is side by side (any width, units included).
- Design rules: no raw colours outside `lib/design/tokens.dart`; text styles via `NamoType` / `readingStyle`; spacing via `NamoSpace`; no Material default buttons. Every new UI string passes `python -I -X utf8 tools/check_ui_glyphs.py .`.
- Tests are added or updated, never deleted. `flutter analyze` clean. Test output pristine.
- Commands, from the worktree root, one flutter or git command at a time:
  - tests: `/c/Users/Dell/develop/flutter/bin/flutter test <path>`; whole suite `/c/Users/Dell/develop/flutter/bin/flutter test`; analyze: `/c/Users/Dell/develop/flutter/bin/flutter analyze`
  - glyphs: `python -I -X utf8 tools/check_ui_glyphs.py .`
  - commit: `git add <files by name>` (never `-A`), then `git -c user.name="Avishka Induwara" -c user.email="v.g.a.induwara@gmail.com" commit -q -m "<subject>" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"`. Never push.
- Do not play sound, do not start a web server, do not touch ports 8765 or 8766.

## Review Focus

1. **A saved `chantSpeed` that is not one of the four values** (1.1, 3, a string): snapped to the nearest allowed value or 1.0, never an odd label or a crash. Test in Task 1 (`settings_test`).
2. **Speed tapped before the first play**: the saved speed reaches the player before the recording plays, and a load does not reset it. Tests in Task 3 (`pirith_chanting_test`).
3. **Side by side saved, then English chosen**: the reader shows verse by verse, the chooser shows "Verse by verse" selected, nothing thrown; choosing Pali and Sinhala again brings side by side back. Tests in Task 4 (`effectiveLayout`) and Task 7 (chooser).
4. **A pirith at 320 px with 2.0× device text under side by side**: no overflow, the chanted phrase is marked in both passages, a tap on a line still finds it. Tests in Task 6 (`phrase_block_test`).
5. **A verse with only one of the two texts under side by side**: shown full width as a single verse; the gap rules around it are the usual ones. Tests in Tasks 5 and 6.

---

### Task 1: Chant speed in the settings and the player

**Files:**
- Modify: `lib/settings/settings.dart`
- Modify: `lib/audio/chant_player.dart`
- Modify: `test/support/fake_chant_player.dart`
- Test: `test/settings/settings_test.dart`

**Interfaces:**
- Produces, in `AppSettings`:
  - `static const chantSpeeds = [0.75, 1.0, 1.25, 1.5];`
  - `final double chantSpeed;` (constructor default `1.0`; `copyWith`, `toJson` key `chantSpeed`, `fromJson` via `snapChantSpeed`)
  - `static double snapChantSpeed(Object? v)`: a finite `num` → the nearest value of `chantSpeeds` (ties go to the lower); anything else → `1.0`.
  - `static double nextChantSpeed(double v)`: the value after `snapChantSpeed(v)` in `chantSpeeds`, wrapping from `1.5` to `0.75`.
- Produces, in `SettingsController`: `void setChantSpeed(double v)` (stores `snapChantSpeed(v)`).
- Produces, in `ChantPlayer`: `Future<void> setSpeed(double speed);` — "Playback rate; 1 is the recording's own. Kept across loads; never throws."
- Produces, in `FakeChantPlayer`: `double speed = 1.0;` and `final speeds = <double>[];` — `setSpeed` sets the first and appends to the second.

- [ ] **Step 1: Write the failing tests**

In `test/settings/settings_test.dart`, add to the existing `defaults` test `expect(s.chantSpeed, 1.0);`, add to the round-trip test a `n.setChantSpeed(1.25)` and `expect(s.chantSpeed, 1.25)`, and add:

```dart
test('chant speed snaps to the nearest allowed value', () {
  expect(AppSettings.snapChantSpeed(1.1), 1.0);
  expect(AppSettings.snapChantSpeed(1.2), 1.25);
  expect(AppSettings.snapChantSpeed(3), 1.5);
  expect(AppSettings.snapChantSpeed(0.1), 0.75);
  expect(AppSettings.snapChantSpeed(0.875), 0.75); // a tie goes down
  expect(AppSettings.snapChantSpeed('fast'), 1.0);
  expect(AppSettings.snapChantSpeed(null), 1.0);
  expect(AppSettings.snapChantSpeed(double.nan), 1.0);
});

test('the next chant speed cycles 1, 1.25, 1.5, 0.75, 1', () {
  var s = 1.0;
  final seen = <double>[];
  for (var i = 0; i < 5; i++) {
    s = AppSettings.nextChantSpeed(s);
    seen.add(s);
  }
  expect(seen, [1.25, 1.5, 0.75, 1.0, 1.25]);
  expect(AppSettings.nextChantSpeed(1.1), 1.25); // snapped first
});

test('a damaged saved chant speed falls back alone', () {
  final s = AppSettings.fromJson({'chantSpeed': 'x', 'fontScale': 1.2});
  expect(s.chantSpeed, 1.0);
  expect(s.fontScale, 1.2);
  expect(AppSettings.fromJson({'chantSpeed': 1.5}).chantSpeed, 1.5);
  expect(jsonDecode(jsonEncode(const AppSettings(chantSpeed: 1.25).toJson()))['chantSpeed'], 1.25);
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `/c/Users/Dell/develop/flutter/bin/flutter test test/settings/settings_test.dart`
Expected: compile errors naming `chantSpeed`, `snapChantSpeed`, `nextChantSpeed`.

- [ ] **Step 3: Implement the setting**

In `lib/settings/settings.dart` add the field, constants and the two static functions to `AppSettings` (constructor, `copyWith`, `toJson`, `fromJson` — `fromJson` reads `chantSpeed: snapChantSpeed(json['chantSpeed'])`), and `setChantSpeed` to `SettingsController`, in the style of `setScrollSpeed`.

- [ ] **Step 4: Add `setSpeed` to the player and the fake**

In `lib/audio/chant_player.dart`: add `Future<void> setSpeed(double speed);` to `ChantPlayer`. In `JustAudioChantPlayer`: a field `double _speed = 1;`; `setSpeed` stores it and calls `await _player.setSpeed(speed)` inside `try { } catch (_) { }`; in `load`, after a successful `setAsset` (same `gen`, not failed) call `await _player.setSpeed(_speed)` in the same guarded way, before `_loading = false`.

In `test/support/fake_chant_player.dart`: `double speed = 1.0; final speeds = <double>[];` and
```dart
@override
Future<void> setSpeed(double speed) async {
  this.speed = speed;
  speeds.add(speed);
}
```
Any other `ChantPlayer` implementations in `test/` (search `implements ChantPlayer`) get the same two lines.

- [ ] **Step 5: Run the tests and analyze**

Run: `/c/Users/Dell/develop/flutter/bin/flutter test test/settings test/audio test/reader` then `/c/Users/Dell/develop/flutter/bin/flutter analyze`
Expected: all pass; analyze clean.

- [ ] **Step 6: Commit**

```bash
git add lib/settings/settings.dart lib/audio/chant_player.dart test/support/fake_chant_player.dart test/settings/settings_test.dart
git -c user.name="Avishka Induwara" -c user.email="v.g.a.induwara@gmail.com" commit -q -m "Chant speed setting and player speed" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 2: The chanting bar: recording row and labelled Scroll and Chant buttons

**Files:**
- Modify: `lib/reader/reader_bottom_bar.dart`
- Modify: `lib/reader/chant_bar.dart`
- Test: `test/reader/chant_bar_test.dart`, `test/quality/overflow_test.dart`

**Interfaces:**
- Consumes: `AppSettings.nextChantSpeed` (Task 1).
- Produces, in `chant_bar.dart`:
  - `String speedLabel(double speed)` → `'0.75×'`, `'1×'`, `'1.25×'`, `'1.5×'` (no trailing zeros, then `×`).
  - `class ChantSpeedButton extends StatelessWidget { const ChantSpeedButton({super.key = const ValueKey('chant-speed'), required this.speed, required this.onPressed}); final double speed; final VoidCallback? onPressed; }` — a `Pressable` with `semanticLabel: 'Chanting speed ${speedLabel(speed)}'`, `hint: 'Tap for ${speedLabel(AppSettings.nextChantSpeed(speed))}'`, `excludeChildSemantics: true`, at least 48×48, showing `speedLabel(speed)` centred in `NamoType.label(p.text)` (`p.textMuted` when `onPressed` is null).
- Produces, in `ReaderBottomBar`: two new parameters `this.chantSpeed = 1.0` (double) and `this.onChantSpeed` (`VoidCallback?`). With `chantState != null` the bar is:
  - **Recording row**: `Row(crossAxisAlignment: CrossAxisAlignment.center)` of `NamoIconButton(key: ValueKey('chant-restart'), icon: Symbols.replay_rounded, tooltip: 'Restart chanting', onPressed: loaded ? onChantRestart : null)`, `Expanded(child: _ChantPosition(...))` (slider or failure text, as today), `ChantSpeedButton(speed: chantSpeed, onPressed: onChantSpeed)`.
  - the divider (as today).
  - **Control row**: `Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start)` of previous (`reader-prev`, as today), the **Scroll** button, the **Chant** button, next (`reader-next`, as today).
  - **Scroll**: a `Column(mainAxisSize: MainAxisSize.min)` with `key: const ValueKey('reader-autoscroll')` holding (a) a `Tooltip` (message by `autoScroll` status, as today's `reader-autoscroll` tooltip) around a 56×56 `DecoratedBox` (`BoxShape.circle`; `color: running ? p.sage : p.surface`; `border: Border.all(color: p.sage, width: 1.5)`) around a `Pressable(onTap: onPlay, borderRadius: BorderRadius.circular(28), excludeChildSemantics: true)` with `Icon(Symbols.swipe_vertical_rounded, size: NamoSizes.icon, weight: 300, color: running ? p.onSage : p.sage)`, where `running = autoScroll == AutoScrollStatus.running`; (b) `SizedBox(height: NamoSpace.xs)`; (c) `ExcludeSemantics(child: Text('Scroll', maxLines: 1, softWrap: false, style: NamoType.caption(p.textSecondary)))`.
  - **Chant**: the existing `_ChantPlayButton` (its `Tooltip` keeps `key: const ValueKey('chant-play')`) in the same column shape with caption `'Chant'`.
  - The bar for `chantState == null` is unchanged.

- [ ] **Step 1: Update and add the tests**

In `test/reader/chant_bar_test.dart`, give `_bar` two optional parameters `double chantSpeed = 1.0, VoidCallback? onChantSpeed` passed through. Replace the test `five controls, left to right, with their names` with:

```dart
testWidgets('two rows: restart, slider, speed above; prev, Scroll, Chant, next below', (t) async {
  await t.pumpWidget(_app(_bar(const ChantState())));
  double x(String k) => t.getCenter(find.byKey(ValueKey(k))).dx;
  double y(String k) => t.getCenter(find.byKey(ValueKey(k))).dy;
  expect(x('chant-restart'), lessThan(x('chant-slider')));
  expect(x('chant-slider'), lessThan(x('chant-speed')));
  expect(x('reader-prev'), lessThan(x('reader-autoscroll')));
  expect(x('reader-autoscroll'), lessThan(x('chant-play')));
  expect(x('chant-play'), lessThan(x('reader-next')));
  expect(y('chant-slider'), lessThan(y('chant-play')));
  for (final tip in ['Previous section', 'Start auto-scroll', 'Play chanting', 'Restart chanting', 'Next section']) {
    expect(find.byTooltip(tip), findsOneWidget, reason: tip);
  }
  expect(find.text('Scroll'), findsOneWidget);
  expect(find.text('Chant'), findsOneWidget);
  expect(find.text('1×'), findsOneWidget);
  expect(t.getSize(find.byKey(const ValueKey('chant-play'))), const Size(56, 56));
  final scroll = find.descendant(of: find.byKey(const ValueKey('reader-autoscroll')), matching: find.byType(DecoratedBox)).first;
  expect(t.getSize(scroll), const Size(56, 56));
});

testWidgets('the Scroll button fills while auto-scroll runs', (t) async {
  await t.pumpWidget(_app(ReaderBottomBar(onPrevious: () {}, onNext: () {}, onPlay: () {},
      autoScroll: AutoScrollStatus.running, chantState: const ChantState(),
      onChantPlay: () {}, onChantRestart: () {})));
  expect(find.byTooltip('Pause auto-scroll'), findsOneWidget);
  final context = t.element(find.byKey(const ValueKey('reader-autoscroll')));
  final box = t.widget<DecoratedBox>(find.descendant(
      of: find.byKey(const ValueKey('reader-autoscroll')), matching: find.byType(DecoratedBox)).first);
  expect((box.decoration as BoxDecoration).color, NamoPalette.of(context).sage);
});

testWidgets('the speed button shows the speed, names the next one and calls back', (t) async {
  var taps = 0;
  await t.pumpWidget(_app(_bar(const ChantState(), chantSpeed: 1.25, onChantSpeed: () => taps++)));
  final handle = t.ensureSemantics();
  expect(find.text('1.25×'), findsOneWidget);
  final node = t.getSemantics(find.byKey(const ValueKey('chant-speed')));
  expect(node.label, 'Chanting speed 1.25×');
  expect(node.hint, 'Tap for 1.5×');
  await t.tap(find.byKey(const ValueKey('chant-speed')));
  expect(taps, 1);
  handle.dispose();
});

test('speed labels', () {
  expect([0.75, 1.0, 1.25, 1.5].map(speedLabel), ['0.75×', '1×', '1.25×', '1.5×']);
});
```

Add `'chant-speed'` to the list of keys checked for 48 px in the `fits 320 wide` loop, and in the `a failed load` test add `expect(find.byKey(const ValueKey('chant-speed')), findsOneWidget);` and the same for `chant-restart`. Import `package:buddhist_gatha/reader/auto_scroll.dart` and `package:buddhist_gatha/design/tokens.dart` as needed.

In `test/quality/overflow_test.dart` (also a Test file of this task), after the bottom-bar loop, add the pirith reader at every size with doubled device text:

```dart
for (final size in _sizes) {
  testWidgets('pirith reader does not overflow: ${size.width.round()}x${size.height.round()}, device text 2.0', (t) async {
    await openReal(t, Routes.reader(mangalaReadingId), size: size, deviceTextScale: 2.0,
        settings: const AppSettings(fontScale: 1.6));
    expect(t.takeException(), isNull);
    expect(find.text('Scroll'), findsOneWidget);
    expect(find.text('Chant'), findsOneWidget);
    await scrollThrough(t);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `/c/Users/Dell/develop/flutter/bin/flutter test test/reader/chant_bar_test.dart`
Expected: compile errors on `chantSpeed`, `speedLabel`; order assertions fail.

- [ ] **Step 3: Implement `speedLabel` and `ChantSpeedButton` in `lib/reader/chant_bar.dart`**

Import `../settings/settings.dart` for `AppSettings.nextChantSpeed` and `../design/widgets/pressable.dart`.

- [ ] **Step 4: Rebuild the chant layout in `lib/reader/reader_bottom_bar.dart`**

Replace `_chantRow` with the recording row and the control row described in Interfaces; add a private `_LabelledRound` (button + caption column) used for Scroll and Chant; add the two parameters. Keep `_PlayButton`, `_ChantPosition` and `_ChantPlayButton` as they are.

- [ ] **Step 5: Run the bar, pirith and quality tests**

Run: `/c/Users/Dell/develop/flutter/bin/flutter test test/reader/chant_bar_test.dart test/reader/pirith_chanting_test.dart test/reader/pirith_reader_test.dart test/reader/samantha_patthana_chanting_test.dart test/quality/overflow_test.dart test/quality/accessibility_test.dart`
Expected: all pass (the pirith tests find the same tooltips and keys). Then `/c/Users/Dell/develop/flutter/bin/flutter analyze` clean and `python -I -X utf8 tools/check_ui_glyphs.py .` exit 0 (`×` is in both label fonts).

- [ ] **Step 6: Commit**

```bash
git add lib/reader/reader_bottom_bar.dart lib/reader/chant_bar.dart test/reader/chant_bar_test.dart
git -c user.name="Avishka Induwara" -c user.email="v.g.a.induwara@gmail.com" commit -q -m "Chanting bar: labelled Scroll and Chant, restart and speed by the slider" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 3: The reader applies and cycles the speed

**Files:**
- Modify: `lib/reader/reader_screen.dart`
- Test: `test/reader/pirith_chanting_test.dart`

**Interfaces:**
- Consumes: `AppSettings.chantSpeed`, `AppSettings.nextChantSpeed`, `SettingsController.setChantSpeed` (Task 1); `ChantPlayer.setSpeed` (Task 1); `ReaderBottomBar.chantSpeed` / `onChantSpeed` (Task 2).
- Produces: nothing new outside the screen.

- [ ] **Step 1: Write the failing tests**

In `test/reader/pirith_chanting_test.dart` add (a `_container(t)` helper is `ProviderScope.containerOf(t.element(find.byType(MaterialApp)))`):

```dart
testWidgets('the speed button cycles, is saved, and reaches the player', (t) async {
  final player = await _open(t);
  final speed = find.byKey(const ValueKey('chant-speed'));
  expect(find.descendant(of: speed, matching: find.text('1×')), findsOneWidget);
  for (final (label, value) in [('1.25×', 1.25), ('1.5×', 1.5), ('0.75×', 0.75), ('1×', 1.0)]) {
    await t.tap(speed);
    await t.pump();
    expect(find.descendant(of: speed, matching: find.text(label)), findsOneWidget, reason: label);
    expect(player.speed, value);
    expect(_container(t).read(settingsProvider).chantSpeed, value);
  }
});

testWidgets('a saved speed is shown and applied before and after the first play', (t) async {
  final player = await _open(t, settings: const AppSettings(chantSpeed: 1.5));
  expect(find.text('1.5×'), findsOneWidget);
  expect(player.speed, 1.5);
  await t.tap(_play);
  await t.pump();
  expect(player.state.status, ChantStatus.playing);
  expect(player.speed, 1.5);
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `/c/Users/Dell/develop/flutter/bin/flutter test test/reader/pirith_chanting_test.dart`
Expected: the two new tests fail (`player.speed` stays 1.0; `1.5×` not found).

- [ ] **Step 3: Wire the reader**

In `lib/reader/reader_screen.dart`:
- In `_bindAudio`, right after `_player = player; _playerReading = readingId;`, when `player != null`: `unawaited(player.setSpeed(ref.read(settingsProvider).chantSpeed));`
- In the `ref.listen(settingsProvider, ...)` in `build`: `if (previous.chantSpeed != next.chantSpeed) unawaited(_player?.setSpeed(next.chantSpeed));`
- A method `void _cycleChantSpeed()` that reads the current `chantSpeed` and calls `setChantSpeed(AppSettings.nextChantSpeed(current))` on the notifier.
- Pass `chantSpeed: settings.chantSpeed, onChantSpeed: _cycleChantSpeed` to `ReaderBottomBar`.

- [ ] **Step 4: Run the tests and analyze**

Run: `/c/Users/Dell/develop/flutter/bin/flutter test test/reader` then `/c/Users/Dell/develop/flutter/bin/flutter analyze`
Expected: all pass; clean.

- [ ] **Step 5: Commit**

```bash
git add lib/reader/reader_screen.dart test/reader/pirith_chanting_test.dart
git -c user.name="Avishka Induwara" -c user.email="v.g.a.induwara@gmail.com" commit -q -m "Reader: chant speed applied to the player and cycled from the bar" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 4: The side-by-side layout value and its rule

**Files:**
- Modify: `lib/settings/reading_language.dart`
- Modify: `lib/settings/settings.dart`
- Test: `test/settings/reading_language_test.dart`, `test/settings/settings_test.dart`

**Interfaces:**
- Produces: `TwoLanguageLayout.sideBySide('Side by side')` as the third value (after `verse`).
- Produces, in `LanguageSelection`: `bool get isPaliAndSinhala` — true only for exactly two languages, Pali and Sinhala, either order.
- Produces, in `settings.dart`: `enum LayoutOutcome { changed, refusedPair }`; `AppSettings.effectiveLayout` getter (`layout == TwoLanguageLayout.sideBySide && !languages.isPaliAndSinhala ? TwoLanguageLayout.verse : layout`); `SettingsController.setLayout` now returns `LayoutOutcome` — `refusedPair` (nothing written) for `sideBySide` while `languages.isPaliAndSinhala` is false, else stores and returns `changed`.

- [ ] **Step 1: Write the failing tests**

In `test/settings/reading_language_test.dart`:
```dart
test('isPaliAndSinhala is true for that pair in either order only', () {
  const pi = ReadingLanguage.pali, si = ReadingLanguage.sinhala, en = ReadingLanguage.english;
  expect(const LanguageSelection([pi, si]).isPaliAndSinhala, isTrue);
  expect(const LanguageSelection([si, pi]).isPaliAndSinhala, isTrue);
  expect(const LanguageSelection([pi]).isPaliAndSinhala, isFalse);
  expect(const LanguageSelection([pi, en]).isPaliAndSinhala, isFalse);
  expect(const LanguageSelection([si, en]).isPaliAndSinhala, isFalse);
});
test('the layout values are section, verse, side by side', () {
  expect(TwoLanguageLayout.values.map((l) => l.label), ['Section by section', 'Verse by verse', 'Side by side']);
});
```
In `test/settings/settings_test.dart`:
```dart
test('side by side is refused for a pair that is not Pali and Sinhala', () {
  final store = InMemoryKeyValueStore();
  final c = containerOn(store); // the file's existing helper for a container on a store
  final n = c.read(settingsProvider.notifier);
  expect(n.setLayout(TwoLanguageLayout.sideBySide), LayoutOutcome.changed);
  expect(c.read(settingsProvider).layout, TwoLanguageLayout.sideBySide);
  n.toggleLanguage(ReadingLanguage.sinhala); // now Pali alone
  n.toggleLanguage(ReadingLanguage.english); // Pali + English
  expect(c.read(settingsProvider).layout, TwoLanguageLayout.sideBySide, reason: 'kept');
  expect(c.read(settingsProvider).effectiveLayout, TwoLanguageLayout.verse);
  expect(n.setLayout(TwoLanguageLayout.verse), LayoutOutcome.changed);
  expect(n.setLayout(TwoLanguageLayout.sideBySide), LayoutOutcome.refusedPair);
  expect(c.read(settingsProvider).layout, TwoLanguageLayout.verse);
});
test('effectiveLayout is the saved layout for Pali and Sinhala', () {
  const s = AppSettings(layout: TwoLanguageLayout.sideBySide);
  expect(s.effectiveLayout, TwoLanguageLayout.sideBySide);
  expect(AppSettings.fromJson({'layout': 'sideBySide'}).layout, TwoLanguageLayout.sideBySide);
});
```
(Use whatever helper the file already has to build a container on a store; if none, build one with `ProviderContainer(overrides: [keyValueStoreProvider.overrideWithValue(store)])`.)

- [ ] **Step 2: Run the tests to verify they fail**

Run: `/c/Users/Dell/develop/flutter/bin/flutter test test/settings`
Expected: compile errors on `sideBySide`, `isPaliAndSinhala`, `LayoutOutcome`, `effectiveLayout`.

- [ ] **Step 3: Implement**

Add the enum value and getter in `reading_language.dart`; `LayoutOutcome`, `effectiveLayout` and the new `setLayout` in `settings.dart`. The existing caller `LayoutChooser` ignores the return value for now (Task 7 uses it).

- [ ] **Step 4: Run the tests and analyze**

Run: `/c/Users/Dell/develop/flutter/bin/flutter test test/settings test/quality/overflow_test.dart` then `/c/Users/Dell/develop/flutter/bin/flutter analyze`
Expected: pass (the overflow suite now also runs the `sideBySide` layout, which until Task 6 draws like verse by verse); clean.

- [ ] **Step 5: Commit**

```bash
git add lib/settings/reading_language.dart lib/settings/settings.dart test/settings/reading_language_test.dart test/settings/settings_test.dart
git -c user.name="Avishka Induwara" -c user.email="v.g.a.induwara@gmail.com" commit -q -m "Layout: side by side value, its Pali-and-Sinhala rule" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 5: Reader items and saved places for side by side

**Files:**
- Modify: `lib/reader/reader_items.dart`
- Modify: `lib/reader/reading_position.dart`
- Modify: `lib/reader/reader_body.dart` (the minimal cases its exhaustive switches need; see Step 3)
- Test: `test/reader/reader_items_test.dart`, `test/reader/reading_position_test.dart`

**Interfaces:**
- Consumes: `TwoLanguageLayout.sideBySide`, `LanguageSelection.isPaliAndSinhala` (Task 4).
- Produces, in `reader_items.dart`:
  - `class VersePairItem extends ReaderItem { VersePairItem({required this.sectionId, required this.verseId, required this.pali, required this.sinhala}); final String sectionId; final String verseId; final String pali, sinhala; }` — one verse, Pali and Sinhala for two columns.
  - `PhraseBlockItem` gains `this.sideBySide = false` (`final bool sideBySide;`): the block's two passages go side by side at any width.
  - `buildReaderItems` behaviour: `final effective = layout == TwoLanguageLayout.sideBySide && !selection.isPaliAndSinhala ? TwoLanguageLayout.verse : layout;` used in place of `layout` throughout. Every `_block(...)` call passes `sideBySide: effective == TwoLanguageLayout.sideBySide`. For an ordinary section under `sideBySide`: for each verse, with `pi = v.text(ReadingLanguage.pali)` and `si = v.text(ReadingLanguage.sinhala)`: both non-null → `VersePairItem`; only `pi` → `VerseTextItem(language: pali, secondary: false)`; only `si` → `VerseTextItem(language: sinhala, secondary: true)`; neither → nothing.
- Produces, in `reading_position.dart`: `offsetForPosition` treats a `VersePairItem` with the saved verse id as the "same language" match whatever the saved language.

- [ ] **Step 1: Write the failing tests**

In `test/reader/reader_items_test.dart`, extend `_kinds` with `VersePairItem() => 'P(${i.verseId})'` and add:

```dart
test('side by side pairs Pali and Sinhala per verse, whichever was chosen first', () {
  const want = ['H(s01)', 'P(s01-v1)', 'P(s01-v2)', 'H(s02)', 'P(s02-v1)', 'H(s03)', 'P(s03-v1)', 'P(s03-v2)'];
  expect(_kinds(_build([_pali, _sinhala], TwoLanguageLayout.sideBySide)), want);
  expect(_kinds(_build([_sinhala, _pali], TwoLanguageLayout.sideBySide)), want);
  final pair = _build([_pali, _sinhala], TwoLanguageLayout.sideBySide)[1] as VersePairItem;
  expect((pair.pali, pair.sinhala), ('pali 1', 'sinhala 1'));
});

test('side by side with another pair is verse by verse', () {
  expect(_kinds(_build([_pali, _english], TwoLanguageLayout.sideBySide)),
      _kinds(_build([_pali, _english], TwoLanguageLayout.verse)));
  expect(_kinds(_build([_sinhala], TwoLanguageLayout.sideBySide)),
      _kinds(_build([_sinhala], TwoLanguageLayout.verse)));
});

test('a verse with one of the two texts is a single under side by side', () {
  const reading = Reading(id: 'r', title: 't', sections: [
    Section(id: 's', number: 1, heading: 'h', verses: [
      Verse(id: 's-v1', paliSi: 'p1', sinhala: 's1'),
      Verse(id: 's-v2', paliSi: 'p2'),
      Verse(id: 's-v3', sinhala: 's3'),
    ]),
  ]);
  final items = buildReaderItems(reading, const LanguageSelection([_pali, _sinhala]), TwoLanguageLayout.sideBySide);
  expect(_kinds(items), ['H(s)', 'P(s-v1)', 'V(s-v2, pi)', 'V(s-v3, si)']);
  expect((items[2] as VerseTextItem).secondary, isFalse);
  expect((items[3] as VerseTextItem).secondary, isTrue);
});

test('pirith blocks carry the side-by-side flag only under that layout with Pali and Sinhala', () {
  final phrased = Reading(id: 'x', title: 'x', sections: [
    Section(id: 'x-s', number: 1, heading: 'x', verses: [
      Verse(id: 'x-0', phrases: [Phrase(pali: 'pa', sinhala: 'sa', english: 'ea')]),
    ]),
  ]);
  PhraseBlockItem block(List<ReadingLanguage> l, TwoLanguageLayout layout) =>
      buildReaderItems(phrased, LanguageSelection(l), layout).whereType<PhraseBlockItem>().single;
  expect(block([_pali, _sinhala], TwoLanguageLayout.sideBySide).sideBySide, isTrue);
  expect(block([_sinhala, _pali], TwoLanguageLayout.sideBySide).sideBySide, isTrue);
  expect(block([_pali, _sinhala], TwoLanguageLayout.verse).sideBySide, isFalse);
  expect(block([_pali, _english], TwoLanguageLayout.sideBySide).sideBySide, isFalse);
});
```
(Check `Verse`'s and `Phrase`'s constructor parameter names in `lib/content/model.dart` and `test/support/test_content.dart` before writing; the test above follows `test_content.dart`.)

In `test/reader/reading_position_test.dart`, add a helper `VersePairItem pr(String verseId) => VersePairItem(sectionId: verseId.split('-').first, verseId: verseId, pali: 'p', sinhala: 's');` and:
```dart
test('a saved place in either language restores to the verse pair', () {
  final items = [h('s01'), pr('s01-v1'), pr('s01-v2')];
  final extents = [e(0, 40), e(40, 100), e(140, 100)];
  for (final language in [pi, si]) {
    final offset = offsetForPosition(
      position: ReadingPosition(readingId: 'r1', sectionId: 's01', verseId: 's01-v2', language: language, fraction: 0.5),
      items: items, extents: extents, maxScrollExtent: 1000);
    expect(offset, 190, reason: language.code);
  }
});
test('capturing on a pair records the verse and no language', () {
  final p = capturePosition(readingId: 'r1', items: [h('s01'), pr('s01-v1')], extents: [e(0, 40), e(40, 100)], scrollOffset: 60)!;
  expect((p.verseId, p.language), ('s01-v1', null));
});
```
(Match `ReadingPosition`'s constructor to the file; the existing tests show it.)

- [ ] **Step 2: Run the tests to verify they fail**

Run: `/c/Users/Dell/develop/flutter/bin/flutter test test/reader/reader_items_test.dart test/reader/reading_position_test.dart`
Expected: compile errors on `VersePairItem`, `sideBySide`.

- [ ] **Step 3: Implement in `reader_items.dart` and `reading_position.dart`**

Items as in Interfaces. In `offsetForPosition`, the `sameLanguage` search becomes: `(i is VerseTextItem && i.verseId == verseId && i.language == position.language) || (i is VersePairItem && i.verseId == verseId)`.

`reader_body.dart` will not compile until Task 6 adds the pair's view to its exhaustive switches; so in this task also add the minimal cases there: in `_gapAbove`, `VersePairItem() => switch (before) { VersePairItem() || VerseTextItem() => NamoSpace.xl, _ => NamoSpace.lg }` and make `VerseTextItem`'s inner switch give `NamoSpace.xl` when `before is VersePairItem`; in `_item`, `VersePairItem() => _VersePairView(...)` — create `_VersePairView` now with the real layout from Task 6's interface (it is small): `Padding(top: gap)` → `Row(crossAxisAlignment: CrossAxisAlignment.start)` → `Expanded(Text(item.pali, key: ValueKey('pair-${item.verseId}-pi'), softWrap: true, style: readingStyle(ReadingLanguage.pali, fontScale:, lineSpacing:, color: p.text)))`, `SizedBox(width: NamoSpace.lg)`, `Expanded(Text(item.sinhala, key: ValueKey('pair-${item.verseId}-si'), ..., color: p.textSecondary))`. Task 6 tests it.

- [ ] **Step 4: Run the tests and analyze**

Run: `/c/Users/Dell/develop/flutter/bin/flutter test test/reader test/quality/overflow_test.dart` then `/c/Users/Dell/develop/flutter/bin/flutter analyze`
Expected: pass; clean.

- [ ] **Step 5: Commit**

```bash
git add lib/reader/reader_items.dart lib/reader/reading_position.dart lib/reader/reader_body.dart test/reader/reader_items_test.dart test/reader/reading_position_test.dart
git -c user.name="Avishka Induwara" -c user.email="v.g.a.induwara@gmail.com" commit -q -m "Reader items: verse pairs and side-by-side blocks" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 6: Drawing side by side

**Files:**
- Modify: `lib/reader/reader_body.dart`
- Modify: `lib/reader/reader_screen.dart`
- Test: `test/reader/phrase_block_test.dart`, `test/quality/overflow_test.dart`, create `test/reader/side_by_side_test.dart`

**Interfaces:**
- Consumes: `VersePairItem`, `PhraseBlockItem.sideBySide` (Task 5), `AppSettings.effectiveLayout` (Task 4).
- Produces: `_PhraseBlockView` uses a row when `((wide && !item.keepLines) || item.sideBySide) && passages.length == 2`. The reader builds its items with `settings.effectiveLayout`. Text keys `pair-<verseId>-pi` and `pair-<verseId>-si` (from Task 5).

- [ ] **Step 1: Write the failing tests**

In `test/reader/phrase_block_test.dart`, give `_pump` a parameter `TwoLanguageLayout layout = TwoLanguageLayout.verse` passed to `buildReaderItems`, and add:

```dart
for (final scale in [1.0, 2.0]) {
  testWidgets('side by side at 320: the meaning is beside the phrases, text $scale', (t) async {
    await _pump(t, _reading(), [_pali, _sinhala], width: 320, dark: false, scale: scale,
        layout: TwoLanguageLayout.sideBySide);
    final phrase = t.getRect(_text('pali 0.0'));
    final meaning = t.getRect(_text('sinhala 0.0'));
    expect(meaning.top, closeTo(phrase.top, 0.5));
    expect(meaning.left, greaterThan(phrase.right - 0.5));
    expect(t.takeException(), isNull);
  });
}

testWidgets('side by side: the chanted phrase is marked in both passages', (t) async {
  final place = ValueNotifier<ChantPlace?>(const ChantPlace(block: 0, phrase: 1));
  addTearDown(place.dispose);
  await _pump(t, _reading(), [_pali, _sinhala], width: 320, dark: false, scale: 1,
      layout: TwoLanguageLayout.sideBySide, place: place);
  expect(markedIn(t, passage('x-0', 'pali')), [1]);
  expect(markedIn(t, passage('x-0', 'sinhala')), [1]);
  expect(find.byKey(const ValueKey('block-active')), findsOneWidget);
});

testWidgets('side by side: a unit has its lines left and its meaning right', (t) async {
  await _pump(t, units(), [_pali, _sinhala], width: 390, dark: false, scale: 1,
      layout: TwoLanguageLayout.sideBySide);
  final lines = t.getRect(passage('u-0', 'pali'));
  final meaning = t.getRect(passage('u-0', 'sinhala'));
  expect(meaning.top, closeTo(lines.top, 0.5));
  expect(meaning.left, greaterThan(lines.right - 0.5));
});
```
(`units()` is the helper the file's unit group already defines; place the last test inside that group. `ChantPlace`'s constructor: see `lib/audio/chant_timing.dart`.) In the same unit group, copy the file's existing test that taps a unit's second Pali line and checks the reported line, with `layout: TwoLanguageLayout.sideBySide` added, named `side by side: a tap on a line still finds it`.

In `test/quality/overflow_test.dart` (also a Test file of this task), extend Task 2's pirith loop with a second settings case, `AppSettings(fontScale: 1.6, layout: TwoLanguageLayout.sideBySide)`, named `..., side by side`.

Create `test/reader/side_by_side_test.dart`, pumping the app the way `test/reader/reader_settings_sheet_test.dart` does (`pumpApp` with `FakeContentRepository` and an `InMemoryKeyValueStore` pre-filled under `settingsKey` with `jsonEncode(const AppSettings(layout: TwoLanguageLayout.sideBySide).toJson())`, location `Routes.reader('r1')`):

```dart
testWidgets('Pali and Sinhala sit side by side, Pali left, top-aligned, Sinhala quiet', (t) async {
  await _open(t, const AppSettings(layout: TwoLanguageLayout.sideBySide));
  final pi = t.getRect(find.byKey(const ValueKey('pair-s01-v1-pi')));
  final si = t.getRect(find.byKey(const ValueKey('pair-s01-v1-si')));
  expect(si.top, closeTo(pi.top, 0.5));
  expect(pi.right, lessThanOrEqualTo(si.left));
  final context = t.element(find.byKey(const ValueKey('pair-s01-v1-si')));
  expect(t.widget<Text>(find.byKey(const ValueKey('pair-s01-v1-si'))).style!.color, NamoPalette.of(context).textSecondary);
  expect(t.widget<Text>(find.byKey(const ValueKey('pair-s01-v1-pi'))).style!.color, NamoPalette.of(context).text);
});

testWidgets('Sinhala chosen first still puts Pali on the left', (t) async {
  await _open(t, const AppSettings(layout: TwoLanguageLayout.sideBySide,
      languages: LanguageSelection([ReadingLanguage.sinhala, ReadingLanguage.pali])));
  expect(t.getRect(find.byKey(const ValueKey('pair-s01-v1-pi'))).left,
      lessThan(t.getRect(find.byKey(const ValueKey('pair-s01-v1-si'))).left));
});

testWidgets('with Pali and English the saved side by side draws verse by verse', (t) async {
  await _open(t, const AppSettings(layout: TwoLanguageLayout.sideBySide,
      languages: LanguageSelection([ReadingLanguage.pali, ReadingLanguage.english])));
  expect(find.byKey(const ValueKey('pair-s01-v1-pi')), findsNothing);
  expect(find.byKey(const ValueKey('verse-s01-v1-pi')), findsOneWidget);
  expect(find.byKey(const ValueKey('verse-s01-v1-en')), findsOneWidget);
  expect(t.takeException(), isNull);
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `/c/Users/Dell/develop/flutter/bin/flutter test test/reader/phrase_block_test.dart test/reader/side_by_side_test.dart`
Expected: the side-by-side assertions fail (meaning under the phrases; `pair-` keys not found because the reader still passes `settings.layout`).

- [ ] **Step 3: Implement**

In `_PhraseBlockView.build`, replace the row condition with `((wide && !item.keepLines) || item.sideBySide) && passages.length == 2`. In `reader_screen.dart`, `buildReaderItems(reading, settings.languages, settings.effectiveLayout)`.

- [ ] **Step 4: Run the reader and quality suites and analyze**

Run: `/c/Users/Dell/develop/flutter/bin/flutter test test/reader test/quality` then `/c/Users/Dell/develop/flutter/bin/flutter analyze`
Expected: pass, including the overflow suite's `sideBySide` runs at 320 px with 2.0× device text; clean.

- [ ] **Step 5: Commit**

```bash
git add lib/reader/reader_body.dart lib/reader/reader_screen.dart test/reader/phrase_block_test.dart test/reader/side_by_side_test.dart
git -c user.name="Avishka Induwara" -c user.email="v.g.a.induwara@gmail.com" commit -q -m "Reader draws Pali and Sinhala side by side" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 7: Choosers, the pirith sheet, and the checklist

**Files:**
- Modify: `lib/settings/choosers.dart`
- Modify: `lib/reader/reader_settings_sheet.dart`
- Modify: `lib/reader/reader_screen.dart` (the `showReaderSettingsSheet` call)
- Modify: `docs/release-checklist.md`
- Test: `test/settings/choosers_test.dart`, `test/settings/settings_screen_test.dart`, `test/reader/reader_settings_sheet_test.dart`, `test/reader/pirith_reader_test.dart`

**Interfaces:**
- Consumes: `LayoutOutcome`, `setLayout`, `effectiveLayout`, `TwoLanguageLayout.sideBySide` (Task 4).
- Produces, in `choosers.dart`: `LayoutChooser({super.key, this.pirith = false})`.
  - `pirith == false`: segments for all three `TwoLanguageLayout.values`; `selected: {settings.effectiveLayout}`; on press, `setLayout(l)`; on `LayoutOutcome.refusedPair` show `'Side by side needs Pali and Sinhala.'` with `ScaffoldMessenger` exactly as `LanguageChooser` shows its refusals.
  - `pirith == true`: two segments `Segment(TwoLanguageLayout.verse, 'Meaning below')`, `Segment(TwoLanguageLayout.sideBySide, 'Side by side')`; `selected: {effectiveLayout == sideBySide ? sideBySide : verse}`; pressing `verse` calls `setLayout(verse)` only when the saved layout is `sideBySide`; pressing `sideBySide` as above.
  - The `enabled` rule (two languages) and the visible `Needs two languages` text stay for both.
- Produces, in `reader_settings_sheet.dart`: `enum LayoutChooserKind { hidden, full, pirith }`; `showReaderSettingsSheet(..., LayoutChooserKind layoutChooser = LayoutChooserKind.full, ...)` and `ReaderSettingsSheet.layoutChooser` replace `showLayout`. The sheet shows `SettingLabel('When two languages show')` + `LayoutChooser(pirith: kind == pirith)` unless `hidden` (or `textOnly`).
- Reader call: `layoutChooser: reading.isPhrased ? LayoutChooserKind.pirith : ignoresLayout(reading) ? LayoutChooserKind.hidden : LayoutChooserKind.full`.

- [ ] **Step 1: Update and add the tests**

`test/settings/choosers_test.dart`, in the `LayoutChooser` group:
```dart
testWidgets('three segments; side by side stores for Pali and Sinhala', (t) async {
  final (c, _) = await _pump(t, const LayoutChooser());
  for (final l in ['Section by section', 'Verse by verse', 'Side by side']) {
    expect(_tapLabel(l), findsOneWidget, reason: l);
  }
  await t.tap(_tapLabel('Side by side'));
  await t.pump();
  expect(c.read(settingsProvider).layout, TwoLanguageLayout.sideBySide);
});

testWidgets('side by side is refused with the message for Pali and English', (t) async {
  final (c, _) = await _pump(t, const Column(children: [LanguageChooser(), LayoutChooser()]));
  await t.tap(_tapLabel('Sinhala'));
  await t.pump();
  await t.tap(_tapLabel('English'));
  await t.pump();
  await t.tap(_tapLabel('Side by side'));
  await t.pump();
  expect(find.text('Side by side needs Pali and Sinhala.'), findsOneWidget);
  expect(c.read(settingsProvider).layout, TwoLanguageLayout.verse);
});

testWidgets('the chooser shows the effective layout when the pair changes', (t) async {
  final (c, _) = await _pump(t, const Column(children: [LanguageChooser(), LayoutChooser()]));
  c.read(settingsProvider.notifier).setLayout(TwoLanguageLayout.sideBySide);
  await t.pump();
  await t.tap(_tapLabel('Sinhala'));
  await t.pump();
  await t.tap(_tapLabel('English'));
  await t.pump();
  expect(c.read(settingsProvider).layout, TwoLanguageLayout.sideBySide);
  // The thumb sits on Verse by verse: segment index 1 of the layout selector.
  final thumb = t.getRect(find.byKey(const ValueKey('selector-thumb')).last);
  final verse = t.getRect(_tapLabel('Verse by verse'));
  expect(thumb.left, lessThanOrEqualTo(verse.left));
  expect(thumb.right, greaterThanOrEqualTo(verse.right));
});

testWidgets('the pirith chooser has Meaning below and Side by side', (t) async {
  final (c, _) = await _pump(t, const LayoutChooser(pirith: true));
  expect(_tapLabel('Meaning below'), findsOneWidget);
  expect(_tapLabel('Side by side'), findsOneWidget);
  expect(_tapLabel('Verse by verse'), findsNothing);
  await t.tap(_tapLabel('Side by side'));
  await t.pump();
  expect(c.read(settingsProvider).layout, TwoLanguageLayout.sideBySide);
  await t.tap(_tapLabel('Meaning below'));
  await t.pump();
  expect(c.read(settingsProvider).layout, TwoLanguageLayout.verse);
  c.read(settingsProvider.notifier).setLayout(TwoLanguageLayout.section);
  await t.pump();
  await t.tap(_tapLabel('Meaning below'));
  await t.pump();
  expect(c.read(settingsProvider).layout, TwoLanguageLayout.section, reason: 'left alone');
});
```
`test/settings/settings_screen_test.dart`: in `layout chooser is disabled with one language`, loop over `['Section by section', 'Verse by verse', 'Side by side']`.
`test/reader/reader_settings_sheet_test.dart`: the test `without the layout choice (a pirith) the rest stays` becomes `without the layout choice (an introduction) the rest stays` using `layoutChooser: LayoutChooserKind.hidden`; add `the pirith sheet offers Meaning below and Side by side` with `layoutChooser: LayoutChooserKind.pirith` expecting `find.text('When two languages show')`, `find.text('Meaning below')`, `find.text('Side by side')` each `findsOneWidget` and `find.text('Verse by verse')` `findsNothing`.
`test/reader/pirith_reader_test.dart`: the test at ~line 103 becomes `the settings sheet offers Meaning below / Side by side in a pirith and the full choice in Buddha Wandanawa`: in the pirith expect `Meaning below` and `Side by side` present and `Verse by verse` absent; in Buddha Wandanawa expect `Verse by verse` and `Side by side` present.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `/c/Users/Dell/develop/flutter/bin/flutter test test/settings/choosers_test.dart test/reader/reader_settings_sheet_test.dart test/reader/pirith_reader_test.dart test/settings/settings_screen_test.dart`
Expected: compile errors on `pirith:`, `LayoutChooserKind`; the pirith sheet tests fail.

- [ ] **Step 3: Implement**

`LayoutChooser` as in Interfaces (one widget, a `pirith` flag); `LayoutChooserKind` and the sheet parameter; the reader's call. Remove `showLayout` entirely (search the repo for other callers).

- [ ] **Step 4: Release checklist**

Append to `docs/release-checklist.md`:
```
- [ ] Reader improvements, owner checks on a phone:
  - [ ] Open a pirith: press Scroll with no sound, then Chant; the captions "Scroll" and "Chant" read right.
  - [ ] Change the speed while chanting (1× → 1.25× → 1.5× → 0.75×); the highlight stays in step.
  - [ ] Choose Side by side (Settings, or the reader's sheet; in a pirith the sheet says "Meaning below" / "Side by side") and read a gatha and a pirith at your usual text size.
  - [ ] With Pali and English chosen, Side by side is refused with "Side by side needs Pali and Sinhala."
```

- [ ] **Step 5: Run the whole suite, analyze, glyphs**

Run, one at a time: `/c/Users/Dell/develop/flutter/bin/flutter test`; `/c/Users/Dell/develop/flutter/bin/flutter analyze`; `python -I -X utf8 tools/check_ui_glyphs.py .`
Expected: all tests pass; clean; exit 0.

- [ ] **Step 6: Commit**

```bash
git add lib/settings/choosers.dart lib/reader/reader_settings_sheet.dart lib/reader/reader_screen.dart docs/release-checklist.md test/settings/choosers_test.dart test/settings/settings_screen_test.dart test/reader/reader_settings_sheet_test.dart test/reader/pirith_reader_test.dart
git -c user.name="Avishka Induwara" -c user.email="v.g.a.induwara@gmail.com" commit -q -m "Layout chooser: side by side, pirith sheet choice, checklist" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

## After the tasks

The final whole-branch review also runs `/c/Users/Dell/develop/flutter/bin/flutter build web --no-web-resources-cdn` (web kept in step) and the content checks (`python -I -X utf8 tools/build_content.py . --check`, `tools/build_pirith.py . --check`, `tools/build_samantha_patthana.py . --check`, `tools/sync_tipitaka.py . --check`), which this plan does not touch and which must still pass.
