# First-Run Tips Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Four one-time pointers on the real screens (Settings tab for recordings, My flows, the reading-settings button, the Scroll and Chant pair), each dismissed by a tap, remembered, replayable from Settings, invisible to every existing test.

**Architecture:** A `TipsController` (Riverpod `Notifier`, persisted under `namo.tips.v1`) holds the seen set and the one active tip. `TipAnchor` wraps a control and registers its render box under a tip id; `TipHost` sits twice in the app (around the whole shell, and around the reader's Scaffold), decides after each frame which due tip may show, and draws the scrim with a cut-out and the bubble inside its own bounds. Tests get `tipsAllowedProvider` off by default through `pumpApp`.

**Tech Stack:** Flutter 3.47.9 / Dart 3.13.7, Riverpod 3, the app's design tokens and widgets (`FloatingBar` look, `PrimaryButton`, `NamoMotion`), `CustomPainter`, `CustomSingleChildLayout`.

**Spec:** `docs/superpowers/specs/2026-11-17-first-run-tips-design.md`

## Global Constraints

- Design rules (tests enforce them): no raw colour outside `lib/design/tokens.dart` (the scrim colour is `NamoPalette.pictureScrim.withValues(alpha: 0.55)` — `withValues` on a token is allowed; `Color(0x…)`/`Colors.*` are not); no Material default widgets (`Card(`, `ListTile(`, `ElevatedButton`, …); `textMuted` only inside `lib/design/`; type via `NamoType`; no `Duration(milliseconds:` outside `tokens.dart` (use `NamoMotion.of(context, NamoMotion.open)` for the fade, nothing else animates).
- Copy, verbatim (title · body; button "Got it"):
  - recordings: Recordings · Recordings download by themselves over Wi-Fi after install. Settings shows the progress under Recordings.
  - myFlows: My flows · Choose the sections you chant, in your order, and read them as one.
  - readerSettings: Languages and layout · Choose Pali, Sinhala or English here, and how two languages sit together.
  - scrollChant: Scroll and Chant · Scroll moves the text by itself. Chant plays the recording and follows the words.
  - Settings row: "Show the tips again"; its snackbar: "The tips will show again."; scrim semantics label: "Dismiss tip". All pass `tools/check_ui_glyphs.py`.
- Keys: `tip-scrim`, `tip-bubble`, `tip-got-it`, `tips-reset`. Existing keys untouched (`nav-settings`, `new-flow`, `my-flows`, `reader-settings`, `reader-autoscroll`, `chant-play`, …).
- One tip at a time app-wide; `Tip.recordings` never due on the web; a tip shows only when its anchors are laid out and fully inside the host's bounds, `ModalRoute.of(context)?.isCurrent == true`, `tipsAllowedProvider` is true, and the host's `canShow(tip)` is true; dismissal (tap, Got it, Back, Escape) marks seen; a host disposed or gated off while its tip is active withdraws it (not seen).
- `pumpApp` and `openReal` override `tipsAllowedProvider` to `false` unless called with `tips: true`; the four tests that build `ProviderScope(child: NamoApp())` directly get the same override. No existing test may change its assertions.
- The reader's gate: nothing playing (`_chant.value.status != ChantStatus.playing`), auto-scroll stopped (`_autoScroll.status == AutoScrollStatus.stopped` or the equivalent getter), and for `scrollChant` the recording's status is `downloaded` or the store has no entry (`store.snapshot.value.of(readingId)?.availability ?? Availability.downloaded`).
- Flutter at `C:\Users\Dell\develop\flutter\bin\flutter` (Git Bash `/c/Users/Dell/develop/flutter/bin/flutter`), not on PATH; `flutter test` (2542 at the base), `flutter analyze` clean, glyph check exit 0 before every commit. One flutter/git command at a time per folder. Never `git add -A`; name the files. Commit trailer `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- Android, iOS and web from one code base; the web build is checked in Task 4.

## Review Focus

1. **A tap on the cut-out must not activate the control underneath** (a person tapping "Chant" through the hole would start a recording while the tip is dismissed). Test in Task 2: a tap at the anchor's centre dismisses and the anchor's `onTap` counter stays 0.
2. **Two hosts alive at once** (the shell host and the reader host while the reader route is pushed): only the current route's host may show; the shell's tip must not appear under the reader. Test in Task 2 (modal route gating) and Task 3 (opening a reader from Home with the recordings tip still due shows no tip under the reader, and the tip appears on return).
3. **Reduced motion**: the tip appears in one frame with no running animations, and `pumpAndSettle` finishes. Test in Task 2.
4. **Large text at 320 px**: the bubble must stay inside the screen and readable, above or below the cut-out, at 2.0× device text. Test in Task 4 (overflow matrix with each tip up).
5. **The store changes while the reader is open**: a pirith opened before its recording arrived must show Scroll and Chant when the store later marks it downloaded (without reopening). Test in Task 3.

---

### Task 1: The tips model, controller and test switch

**Files:**
- Create: `lib/tips/tips.dart`, `test/tips/tips_test.dart`
- Modify: `test/support/pump_app.dart`, `test/quality/quality_support.dart` (`openReal`), `test/library/library_screen_test.dart` (the two direct `ProviderScope` builds), `test/home/home_header_test.dart`, `test/home/gatha_card_test.dart`

**Interfaces:**
- Produces:
  ```dart
  // lib/tips/tips.dart
  enum Tip {
    recordings('Recordings', 'Recordings download by themselves over Wi-Fi after install. Settings shows the progress under Recordings.'),
    myFlows('My flows', 'Choose the sections you chant, in your order, and read them as one.'),
    readerSettings('Languages and layout', 'Choose Pali, Sinhala or English here, and how two languages sit together.'),
    scrollChant('Scroll and Chant', 'Scroll moves the text by itself. Chant plays the recording and follows the words.');
    const Tip(this.title, this.body);
    final String title, body;
  }
  const tipsKey = 'namo.tips.v1';           // JSON {"seen": ["recordings", ...]}
  class TipsState {
    const TipsState({this.seen = const {}, this.active});
    final Set<Tip> seen; final Tip? active;
    TipsState copyWith({Set<Tip>? seen, Tip? active, bool clearActive = false});
    Map<String, dynamic> toJson();           // seen names, sorted
    factory TipsState.fromJson(Object? json); // forgiving: unknown names ignored, garbage → empty
  }
  class TipsController extends Notifier<TipsState> {
    TipsController({bool web = kIsWeb});
    bool isDue(Tip t);                       // !seen.contains(t) && (t != Tip.recordings || !web)
    bool request(Tip t);                     // false unless isDue(t) && active == null; then active = t, true
    void dismiss();                          // active → seen, active = null, save
    void withdraw(Tip t);                    // active == t → active = null, no save of seen
    void resetAll();                         // seen = {}, active = null, save
  }
  final tipsProvider = NotifierProvider<TipsController, TipsState>(TipsController.new);
  final tipsAllowedProvider = Provider<bool>((_) => true);
  ```
  `pumpApp(..., bool tips = false)` and `openReal(..., bool tips = false)` add `tipsAllowedProvider.overrideWithValue(tips)` to their own override lists (not through the caller's list).

- [ ] **Step 1: Write the failing tests**

`test/tips/tips_test.dart` (plain `test()`s on a `ProviderContainer` with `keyValueStoreProvider` overridden by an `InMemoryKeyValueStore`, like `test/settings/settings_test.dart`'s `containerOn`):
- `'every tip is due at first; recordings is not due on the web'` (build the controller with `web: true` via `tipsProvider.overrideWith(() => TipsController(web: true))`).
- `'request makes a due tip active and refuses a second one'`.
- `'dismiss marks the active tip seen and saves it'` (the store holds `{"seen":["myFlows"]}`; a new container on the same store reads it back; `isDue(myFlows)` is false).
- `'withdraw clears the active tip without marking it seen'`.
- `'resetAll forgets everything and saves'`.
- `'garbage in the store gives an empty state'`.

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/tips/tips_test.dart`
Expected: compile errors.

- [ ] **Step 3: Implement `lib/tips/tips.dart` and the test switch**

Controller pattern as `SavedController` (`build()` reads and parses; `_set` writes). Add the `tips` parameter and override to `pumpApp` and `openReal`; add `tipsAllowedProvider.overrideWithValue(false)` to the four direct `ProviderScope` tests.

- [ ] **Step 4: Run the suites**

Run: `flutter test test/tips test/support test/library test/home test/quality/design_rules_test.dart` → PASS; `flutter analyze` → clean. (The four amended tests pass unchanged in behaviour: no tip code is wired yet.)

- [ ] **Step 5: Commit**

```bash
git add lib/tips/tips.dart test/tips/tips_test.dart test/support/pump_app.dart test/quality/quality_support.dart test/library/library_screen_test.dart test/home/home_header_test.dart test/home/gatha_card_test.dart
git commit -m "Tips: the seen set, the active tip, and the test switch"
```

---

### Task 2: Anchors and the host

**Files:**
- Create: `lib/tips/tip_anchor.dart`, `lib/tips/tip_host.dart`, `lib/tips/tip_bubble.dart`, `test/tips/tip_host_test.dart`

**Interfaces:**
- Consumes: Task 1.
- Produces:
  ```dart
  // lib/tips/tip_anchor.dart
  class TipAnchors extends ChangeNotifier {           // registry
    List<GlobalKey> keysFor(Tip tip);
    void register(Tip tip, GlobalKey key); void unregister(Tip tip, GlobalKey key);
  }
  final tipAnchorsProvider = ChangeNotifierProvider<TipAnchors>((_) => TipAnchors());
  class TipAnchor extends ConsumerStatefulWidget {
    const TipAnchor({super.key, required this.tip, required this.child});
    // wraps child in a KeyedSubtree(GlobalKey); registers in initState/didUpdateWidget, unregisters in dispose
  }

  // lib/tips/tip_host.dart
  class TipHost extends ConsumerStatefulWidget {
    const TipHost({super.key, required this.tipsFor, required this.child, this.canShow, this.reevaluateOn = const []});
    final List<Tip> Function() tipsFor;
    final Widget child;
    final bool Function(Tip tip)? canShow;
    final List<Listenable> reevaluateOn;
  }
  // State: schedules _evaluate() after every build (post-frame), on ScrollEndNotification (NotificationListener around child),
  // when any reevaluateOn fires, and when tipAnchorsProvider changes. _evaluate(): if a tip of this host is active → keep;
  // else, if tipsAllowed && ModalRoute.of(context)?.isCurrent == true: for the first tip in tipsFor() with isDue, anchors non-empty,
  // every anchor's rect (RenderBox.localToGlobal against the host's RenderBox) fully inside the host's bounds, and canShow(tip) != false:
  // request(tip). While a tip of this host is active and the gate turns false (route no longer current, canShow false, anchors gone)
  // → withdraw. dispose → withdraw if active is ours.
  // Build: Stack[ NotificationListener(child) wrapped in ExcludeSemantics(excluding: active), if active: Positioned.fill(_TipLayer) ].
  // _TipLayer: PopScope(canPop: false, onPopInvokedWithResult → dismiss) + CallbackShortcuts({Escape: dismiss}) + Focus(autofocus) +
  //   GestureDetector(behavior: opaque, onTap: dismiss) + CustomPaint(_ScrimPainter(cutout)) + CustomSingleChildLayout(_BubbleLayout) → TipBubble.
  //   Fade with AnimatedOpacity(duration: NamoMotion.of(context, NamoMotion.open)).
  Rect unionRect(Iterable<Rect> rects);
  Rect cutoutFor(Rect anchorsUnion);  // inflate 6, radius NamoRadius.md (painter)
  class BubbleLayoutDelegate extends SingleChildLayoutDelegate {
    BubbleLayoutDelegate({required this.cutout, required this.margin, required this.gap});  // margin NamoSpace.lg, gap NamoSpace.md
    // below the cut-out when cutout.bottom + gap + childHeight <= size.height - margin, else above; x centred on the cut-out, clamped to [margin, size.width - margin - childWidth]
  }

  // lib/tips/tip_bubble.dart
  class TipBubble extends StatelessWidget {
    const TipBubble({super.key = const ValueKey('tip-bubble'), required this.tip, required this.onGotIt});
    // FloatingBar look (surface, border hairline, floatShadow, NamoRadius.lg), max width 360, padding NamoSpace.lg,
    // Semantics(container: true, liveRegion: true, label: '${tip.title}. ${tip.body}') over Column[title NamoType.label(p.text), body NamoType.body(p.text), PrimaryButton(key: tip-got-it, 'Got it')]
  }
  ```

- [ ] **Step 1: Write the failing tests**

`test/tips/tip_host_test.dart` with a fake page: a `MaterialApp(theme: namoTheme(...))` whose home is `TipHost(tipsFor: () => [Tip.myFlows], child: Scaffold(body: ...))` containing a `TipAnchor(tip: Tip.myFlows, child: Pressable(key: 'target', onTap: () => taps++, ...))` placed by a `Positioned`/`Align` the test controls; a `ProviderScope` with `keyValueStoreProvider` in-memory and `tipsAllowedProvider` true. Tests:
- `'a due tip appears after the first frame with a bubble below the control'` (bubble top > anchor bottom).
- `'near the bottom the bubble goes above'` (anchor placed at the bottom; bubble bottom < anchor top).
- `'at 320 px the bubble stays inside the screen'` (anchor at the right edge; bubble rect within the view with ≥16 px margins).
- `'two anchors are covered by one cut-out'` (Tip.scrollChant with two anchors; `cutoutFor(unionRect)` covers both; use the painter's exposed cutout via a test hook or `BubbleLayoutDelegate` input — assert the bubble is centred between them).
- `'a tap on the scrim dismisses and marks seen'`, `'Got it dismisses and marks seen'`.
- `'a tap on the control through the cut-out dismisses and does not activate it'` (Review Focus 1: `taps == 0`).
- `'Back dismisses without popping'` (push the host page over another route; `t.binding.handlePopRoute()`; the host page is still there, tip gone, seen).
- `'Escape dismisses'` (`sendKeyEvent(LogicalKeyboardKey.escape)`).
- `'an anchor scrolled out of view waits; scrolling it in shows the tip'` (anchor inside a `ListView` below the fold; no bubble; `drag` then `pumpAndSettle` → bubble).
- `'a host that is disposed withdraws without marking seen'` (pump a different widget; `tipsProvider` has `active == null`, `seen` empty).
- `'nothing shows while a modal route is on top'` (push a dialog route before the first frame settles; no bubble; pop → bubble).
- `'one tip at a time across two hosts'` (two hosts with different due tips in one tree: exactly one bubble; after dismissal the other appears).
- `'reduced motion: appears in one frame with no running animations'` (Review Focus 3: `accessibilityFeaturesTestValue = FakeAccessibilityFeatures(disableAnimations: true)`; after one `pump()` the bubble is there; `t.hasRunningAnimations` is false; `pumpAndSettle` returns).
- `'tips off: nothing shows'` (`tipsAllowedProvider` false).
- `BubbleLayoutDelegate` unit tests: below/above/clamp arithmetic with fixed sizes; `unionRect`.

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/tips/tip_host_test.dart`
Expected: compile errors.

- [ ] **Step 3: Implement the three files**

As in Interfaces. `_ScrimPainter` paints `Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), Path()..addRRect(RRect.fromRectAndRadius(cutout, Radius.circular(NamoRadius.md))))` with `pictureScrim.withValues(alpha: 0.55)`; `shouldRepaint` on cutout change. Measure anchors in `_evaluate` with `RenderBox.localToGlobal(Offset.zero, ancestor: hostBox) & box.size`, skipping boxes that are not attached or have zero size.

- [ ] **Step 4: Run the tests, the design rules and the analyzer**

Run: `flutter test test/tips test/quality/design_rules_test.dart` → PASS; `flutter analyze` → clean; `python -I -X utf8 tools/check_ui_glyphs.py .` → exit 0.

- [ ] **Step 5: Commit**

```bash
git add lib/tips/tip_anchor.dart lib/tips/tip_host.dart lib/tips/tip_bubble.dart test/tips/tip_host_test.dart
git commit -m "Tips: anchors, host, scrim and bubble"
```

---

### Task 3: Placing the four tips

**Files:**
- Modify: `lib/design/widgets/app_shell.dart` (`AppShell.build`, `_Destination` for the Settings tab in bar and rail), `lib/flows/my_flows_part.dart`, `lib/reader/reader_screen.dart` (the `Scaffold` in `build`, `_TopBar`), `lib/reader/reader_bottom_bar.dart` (`_chantRows`)
- Test: `test/tips/tips_screens_test.dart` (new)

**Interfaces:**
- Consumes: Tasks 1–2; `FakeRecordingStore` (`test/support/fake_recording_store.dart`), `openReal(..., tips: true, recordingStore:)`, `realLibrary`, `mangalaReadingId`, `realReadingId`, `realFlowsStore`.
- Produces: `AppShell` wraps its `Scaffold` (bar layout) and its `Row` (rail layout) in `TipHost(tipsFor: () => switch (shell.currentIndex) { TabIndex.home => [Tip.recordings], TabIndex.library => [Tip.myFlows], _ => const [] }, child: …)`; the Settings `_Destination` is wrapped in `TipAnchor(tip: Tip.recordings)` in both `_Bar` and `_Rail`. `MyFlowsPart`: the empty-state `SurfaceCard`, or the `new-flow` `QuietButton` when flows exist, wrapped in `TipAnchor(tip: Tip.myFlows)`. Reader: `TipHost(tipsFor: () => [Tip.readerSettings, if (recording != null && recording.timed) Tip.scrollChant], canShow: _canShowTip, reevaluateOn: [_chant, _autoScroll, if (store != null) store.snapshot], child: Scaffold(...))`, with `bool _canShowTip(Tip tip)` per Global Constraints; `_TopBar`'s `reader-settings` `NamoIconButton` in `TipAnchor(tip: Tip.readerSettings)`; in `_chantRows` both `_LabelledRound`s wrapped in `TipAnchor(tip: Tip.scrollChant)` (the keys stay where they are).

- [ ] **Step 1: Write the failing tests**

`test/tips/tips_screens_test.dart`, all through `openReal(..., tips: true)` with the real library:
- `'Home shows the Recordings tip once over the tab bar'` (bubble with title "Recordings"; the `nav-settings` destination lies inside the cut-out: compute from `tester.getRect(find.byKey(const ValueKey('nav-settings')))` against the bubble position; tap the scrim; reopen Home through a second `openReal` on the same store map (`storeExtras: {tipsKey: '{"seen":["recordings"]}'}` or by reading the store back) → no bubble).
- `'on the web Home shows no Recordings tip'` (override `tipsProvider` with `TipsController(web: true)`).
- `'Library shows My flows pointing at the card, or at New flow when flows exist'` (two cases; the second with `storeExtras: realFlowsStore(t)`; the anchor rect contains the card / the `new-flow` button).
- `'the recordings tip does not appear under a reader opened from Home'` (Review Focus 2: open Home with tips on but do not dismiss; navigate to a reader via the router; no bubble titled "Recordings"; the reader's own "Languages and layout" bubble appears; go back → Home's tip appears).
- `'a gatha reader shows Languages and layout pointing at the settings button'` (`realReadingId`; bubble; the cut-out contains `reader-settings`).
- `'a pirith with its recording downloaded shows Languages and layout, then Scroll and Chant'` (`mangalaReadingId`, `FakeRecordingStore()` default downloaded; dismiss the first; the second's cut-out contains both `reader-autoscroll` and `chant-play`).
- `'a pirith whose recording is still waiting shows only the first tip until the store marks it downloaded'` (Review Focus 5: `FakeRecordingStore` with `waiting` for the reading; after dismissing the first, no second bubble; `store.set(id, downloaded)`; pump → the second appears).
- `'no tip appears while chanting'` (tips on, but tap `chant-play` first via `openChanting`-style flow with the first tip dismissed: with `_chant` playing, `scrollChant` does not appear; pause → appears).
- `'openChanting still works with tips on after dismissing'` (reuse `openChanting` from `quality_support` with a `tips: true` variant if it takes one; otherwise dismiss the two tips then tap `chant-play` and assert playing).

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/tips/tips_screens_test.dart`
Expected: no bubbles found.

- [ ] **Step 3: Implement the placements**

As in Interfaces. In `app_shell.dart` the two `_Destination` sites need the anchor only for `TabIndex.settings`. In `reader_screen.dart` build the host around the existing `Scaffold` (inside `PopScope` so the host's own `PopScope` sits inside it and takes precedence while a tip is up; verify Back order in the test).

- [ ] **Step 4: Run the suites**

Run: `flutter test test/tips test/reader test/quality` then the full `flutter test` → PASS (2542 + new); `flutter analyze` → clean; glyph check → 0.

- [ ] **Step 5: Commit**

```bash
git add lib/design/widgets/app_shell.dart lib/flows/my_flows_part.dart lib/reader/reader_screen.dart lib/reader/reader_bottom_bar.dart test/tips/tips_screens_test.dart
git commit -m "Tips: Recordings, My flows, Languages and layout, Scroll and Chant in place"
```

---

### Task 4: Settings "Show the tips again", quality matrices, docs

**Files:**
- Modify: `lib/settings/settings_screen.dart` (About Namo group), `test/settings/settings_screen_test.dart`, `test/quality/overflow_test.dart`, `test/quality/accessibility_test.dart`, `test/quality/reduced_motion_test.dart`, `README.md`, `docs/release-checklist.md`

**Interfaces:**
- Produces: in the About Namo group after `Sources`: `ListRow(key: const ValueKey('tips-reset'), title: 'Show the tips again', onTap: () { ref.read(tipsProvider.notifier).resetAll(); ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(const SnackBar(content: Text('The tips will show again.'))); })` (the chooser files' snackbar pattern).

- [ ] **Step 1: Write the failing tests**

`settings_screen_test.dart`: `'Show the tips again forgets the seen tips and says so'` (seed the store with all four seen; tap `tips-reset`; the store's `tipsKey` reads `{"seen":[]}`; the snackbar text is found); the About group's control list in the existing "each control is inside its group" test gains the row.
`overflow_test.dart`: four `testWidgets` at `_sizes` × device text 2.0 with `tips: true`: Home with the Recordings tip up, Library with My flows up, the gatha reader with Languages and layout up, the pirith reader with Scroll and Chant up (dismiss the first); the file's no-overflow assertion plus `find.byKey(ValueKey('tip-bubble'))` inside the view.
`accessibility_test.dart`: Home with the Recordings tip up passes `expectGuidelines` (tap targets, labels, contrast) in light and dark.
`reduced_motion_test.dart`: Home with tips on under `disableAnimations`: after one `pump()` the bubble is present and `t.hasRunningAnimations` is false.

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/settings/settings_screen_test.dart test/quality/overflow_test.dart test/quality/accessibility_test.dart test/quality/reduced_motion_test.dart`
Expected: the new tests fail (row missing / bubble missing).

- [ ] **Step 3: Implement the row and fix anything the matrices reveal**

If a bubble overflows at 320 px / 2.0×, fix it in `TipBubble` or the delegate (never by loosening the test); report what changed.

- [ ] **Step 4: Docs and the whole check list**

README feature list: one sentence, `First-run tips point once at My flows, the reading settings and the Scroll and Chant buttons, and say that recordings download by themselves; Settings can show them again.` Release checklist, owner checks: `- [ ] First-run tips: on a fresh install the four tips appear in turn (Home → the Settings tab; Library → My flows; a gatha reader → the settings button; a pirith, once its recording has arrived → Scroll and Chant); each goes with one tap or Back; Settings → About Namo → "Show the tips again" brings them back; on the web the Recordings tip does not appear.`
Run: `flutter test` (full), `flutter analyze`, `python -I -X utf8 tools/check_ui_glyphs.py .`, `flutter build web --no-web-resources-cdn` → all green.

- [ ] **Step 5: Commit**

```bash
git add lib/settings/settings_screen.dart test/settings/settings_screen_test.dart test/quality/overflow_test.dart test/quality/accessibility_test.dart test/quality/reduced_motion_test.dart README.md docs/release-checklist.md
git commit -m "Tips: Show the tips again; overflow, accessibility and reduced-motion checks; docs"
```

---

## Rulings taken while planning

- The shell host wraps the whole shell (bar included) so the Settings tab can be the target and nothing behind a tip is tappable; the reader has its own host.
- `tipsAllowedProvider` is true in the app and false in tests by default; only the tips tests and the new quality cases turn it on.
- The bubble has no arrow; the cut-out's position is the pointer.
- Back and Escape dismiss the tip and stay on the screen; leaving a screen by code withdraws the tip (not seen).
