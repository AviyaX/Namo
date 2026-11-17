# First-run tips — design

Date: 2026-11-17. Status: the owner asked for a "how to use this app step by
step" on first use, said My flows must be covered and the rest is the
designer's pick, and chose approach 2 (pointers on the real screens).
Builder check done the same day; its four findings (the host must cover the
tab bar, tips hidden without a tap, waiting for the recording, waiting for
the control to be on screen) are folded in as the designer's calls.

## Intent

The first time a person reaches a screen, one small bubble points at a real
control and says in one sentence what it does. A tap anywhere dismisses it;
it never comes back unless the person asks for the tips again in Settings.
Four tips, each at the moment it matters:

1. **Recordings** — on Home at first launch, pointing at the Settings tab:
   recordings download by themselves; progress is under Settings.
2. **My flows** — on Library, pointing at the My flows card (or its "New
   flow" button when flows exist).
3. **Languages and layout** — in any reader, pointing at the reading-settings
   button in the top bar.
4. **Scroll and Chant** — in a pirith, pointing at the two round buttons.

## Goals

- A new person meets each tip once, where its control is, and can dismiss it
  with one tap; nothing else is blocked longer than that tap.
- The tips are gone after the first pass; "Show the tips again" in Settings
  brings them back.
- Works on phones, tablets (rail instead of bar) and the web; honours
  reduced motion; passes the app's overflow and accessibility checks at
  320 px with 2.0× text.
- No tip ever shows in a test that did not ask for one, so the 2,500
  existing tests stay as they are.

## Non-goals

- Welcome pages, a tutorial page, videos, or a tour of every feature.
- Tips for the Tripitaka, Saved, bookmarks, favourites, search, speed.
- Tips on the web for recordings (they stream there).
- Analytics of any kind about who dismissed what.

## Anti-goals

- A tip covering a control the person is trying to use, or appearing in the
  middle of chanting.
- A tip that shows on a hidden tab, or twice at once.
- A tip that keeps an animation ticking or a semantics node in the way.

## Constraints

- Design rules: no raw colours outside the tokens (the scrim is
  `NamoPalette.pictureScrim` with alpha, the bubble is `FloatingBar`'s look),
  no Material default widgets, type via `NamoType`, no
  `Duration(milliseconds:` outside `tokens.dart` (use `NamoMotion`),
  `textMuted` only in `lib/design/`.
- The five tabs are kept built in a `FadeIndexedStack`; hidden tabs have
  `TickerMode` off. The reader is its own route outside the shell.
- Key-value store holds strings; controllers follow the `SavedController`
  pattern (`build()` reads and parses, `_set` writes).
- Every quality test opens with an empty store (`openReal`, `pumpApp`), and
  several tap `chant-play`, `reader-settings`, `nav-library`, `new-flow`
  right after opening.
- Copy passes `tools/check_ui_glyphs.py`.

## Approaches considered

1. Welcome pages at first launch. 2. Pointers on the real screens
   (chosen by the owner). 3. A "How to use Namo" page shown once.
   See the conversation; 2 was recommended because each tip lands where its
   control is, and the app already has the bubble's look (`FloatingBar`).

Within 2, how a bubble finds its control: (a) `GlobalKey`s threaded into
private widgets; (b) *chosen:* a `TipAnchor` wrapper that registers the
control's render box under a tip id, so screens stay declarative and a tip
may union several anchors (Scroll and Chant are two buttons with a gap
between them that must stay as it is).

## How it works

### Model and state (`lib/tips/tips.dart`)

```dart
enum Tip { recordings, myFlows, readerSettings, scrollChant }
// title and body per tip (copy below); Tip.recordings is never due on the web
class TipsState { final Set<Tip> seen; final Tip? active; }
const tipsKey = 'namo.tips.v1';   // JSON {"seen": ["recordings", ...]}
class TipsController extends Notifier<TipsState> {
  bool isDue(Tip t);                 // !seen.contains(t) && (t != recordings || !web)
  bool request(Tip t);               // shows t if due and nothing is active; true when it became active
  void dismiss();                    // marks active as seen, clears active, saves
  void withdraw(Tip t);              // clears active if it is t, WITHOUT marking it seen (the screen went away)
  void resetAll();                   // clears seen (and active), saves
}
final tipsProvider = NotifierProvider<TipsController, TipsState>(...);
final tipsAllowedProvider = Provider<bool>((_) => true);   // tests override to false
```

Dismissed means seen; withdrawn means "not this time". The host dismisses
on a tap on the scrim, the cut-out or the button, and on Back (Android
button or gesture) and Escape (web, keyboard) while a tip is up — those are
caught by the host and do not leave the screen. The host withdraws when it
is disposed or when its gate turns false while the tip is active (the
screen was left by code, for example the reader's previous/next hand-over or
a `context.go`), so the tip returns the next time.

Copy (title · body · button "Got it"):

- recordings: **Recordings** · "Recordings download by themselves over Wi-Fi after install. Settings shows the progress under Recordings."
- myFlows: **My flows** · "Choose the sections you chant, in your order, and read them as one."
- readerSettings: **Languages and layout** · "Choose Pali, Sinhala or English here, and how two languages sit together."
- scrollChant: **Scroll and Chant** · "Scroll moves the text by itself. Chant plays the recording and follows the words."

### Anchors and host (`lib/tips/tip_anchor.dart`, `lib/tips/tip_host.dart`)

- `TipAnchor({required Tip tip, required Widget child})` wraps a control and
  registers its `GlobalKey` in `tipAnchorsProvider` (a `Map<Tip,
  List<GlobalKey>>`), unregistering on dispose. Several anchors for one tip
  are allowed; the host unions their rects.
- `TipHost({required List<Tip> Function() tipsFor, required Widget child,
  bool Function(Tip)? canShow, List<Listenable> reevaluateOn = const []})`
  is placed twice in the app: once in `AppShell` around the whole shell
  (page area and tab bar or rail together, so the scrim covers the bar and
  the Settings tab can be the target), with `tipsFor` returning
  `[Tip.recordings]` on the Home tab and `[Tip.myFlows]` on the Library tab
  (by `shell.currentIndex`), and once in the reader around its Scaffold
  (body and bottom bar), with `tipsFor` returning `[Tip.readerSettings,
  Tip.scrollChant]`. After each frame, after a `ScrollEndNotification`
  bubbling through it, and whenever one of `reevaluateOn` fires, the host
  asks, in order, for the first tip of its list that is due and whose
  anchors are all laid out **and fully inside the host's own visible
  bounds** (a control scrolled out of view waits until it is on screen),
  provided `tipsAllowedProvider` is true, `ModalRoute.of(context)?.isCurrent`
  is true (no sheet or other route on top), and `canShow(tip)` returns true.
  The reader's `canShow` is: for both tips, nothing is playing and auto-scroll
  is stopped; for `scrollChant` also the recording is downloaded (the store's
  status for the reading is `downloaded`, or the store knows nothing), and
  the reader passes `store.snapshot`, `_chant` and `_autoScroll` in
  `reevaluateOn`. When the controller makes the tip active, the host draws,
  above its child:
  - a scrim of `pictureScrim` at 55% over the whole page with a rounded
    cut-out (`NamoRadius.md`, 6 px padding) around the union of the anchor
    rects, painted with a `CustomPainter`;
  - a bubble (`FloatingBar` look, max width 360, `NamoSpace.lg` padding):
    title in `NamoType.label(p.text)`, body in `NamoType.body(p.text)`,
    a `PrimaryButton('Got it')` aligned end; placed below the cut-out when
    there is room for it, otherwise above; horizontally centred on the
    cut-out and clamped inside the page with `NamoSpace.lg` margins; a small
    notch toward the control is left to the builder.
  - Any tap on the scrim, the cut-out or the button calls `dismiss()`; the
    control under the cut-out is not activated by that tap. While a tip is
    up the host also catches Back (`PopScope`/`BackButtonListener`) and the
    Escape key and calls `dismiss()` without leaving the screen.
  - The scrim and bubble fade in over `NamoMotion.of(context,
    NamoMotion.open)` (instant under reduced motion); nothing animates
    afterwards.
  - Semantics: the bubble is a `Semantics(container, liveRegion, label:
    '<title>. <body>')` with the button inside; the scrim is
    `Semantics(button, label: 'Dismiss tip')`; the rest of the page is
    wrapped in `ExcludeSemantics` while a tip is up, so screen readers land
    on the tip first.
- Once dismissed, the host asks again on the next frame for the next due tip
  of its list (so a first pirith shows Languages and layout, then Scroll and
  Chant).

### Placement of anchors and hosts

- `app_shell.dart`: `TipHost` around the whole shell (the `Scaffold` with
  the bar, or the `Row` with the rail), `tipsFor` by `shell.currentIndex`;
  the Settings `_Destination` (bar and rail) is wrapped in
  `TipAnchor(tip: Tip.recordings)`.
- `my_flows_part.dart`: the empty-state card, or the `new-flow` button when
  flows exist, is wrapped in `TipAnchor(tip: Tip.myFlows)`. Home and Library
  themselves need no host.
- `reader_screen.dart`: `TipHost` around the Scaffold (body and bar) with
  the `canShow` and `reevaluateOn` above; `_TopBar`'s `reader-settings`
  button in `TipAnchor(tip: Tip.readerSettings)`; `reader_bottom_bar.dart`:
  both `_LabelledRound`s (Scroll, Chant) each in `TipAnchor(tip:
  Tip.scrollChant)` (the host unions them). Flow readings have the settings
  button too, so tip 3 may land there; tip 4 only where the chanting layout
  is shown and the recording has arrived.
- `settings_screen.dart`, About Namo group: `ListRow(key: ValueKey('tips-reset'),
  title: 'Show the tips again', onTap: resetAll)` after Sources, followed
  by a `SnackBar('The tips will show again.')`.

### Tests and test support

- `pumpApp` (and so `openReal`) always overrides `tipsAllowedProvider` with
  `false` unless called with `tips: true` (new parameter on both), so no
  existing test sees a tip. The four tests that build
  `ProviderScope(child: NamoApp())` directly (`library_screen_test` ×2,
  `home_header_test`, `gatha_card_test`) get the same override added.
- Unit: `TipsController` seen/dismiss/withdraw/reset/persist/round-trip,
  `recordings` not due on the web (the controller takes `web` like
  `RecordingsGroup`), `request` refused while another tip is active.
- Widget (`TipHost` with a fake page): below/above placement, clamping at
  320 px, union of two anchors, an anchor scrolled out of view waits and the
  tip appears after scrolling it in, tap on scrim and on Got it both
  dismiss and mark seen, Back and Escape dismiss without popping, disposing
  the host withdraws (not seen), one tip at a time across two hosts, nothing
  when a modal route is on top, instant under reduced motion with no running
  animations.
- Screens (`openReal(..., tips: true)`): Home shows Recordings once over the
  bar (the bar is under the scrim; not on the second open; not when `web`);
  Library shows My flows pointing at the card (empty) and at New flow (with
  flows); a gatha reader shows Languages and layout; a pirith with its
  recording downloaded shows it then Scroll and Chant, and with the
  recording still waiting shows only the first until the fake store marks
  it downloaded; `openChanting` with tips on works after dismissing;
  Settings' "Show the tips again" brings Home's tip back.
- Overflow at the three sizes × 2.0× with each tip up; accessibility
  guidelines with a tip up; design rules; glyph check.

## Left to the builder

- The notch/arrow on the bubble (or none).
- The exact fade (opacity only) and the scrim alpha within 50–60%.
- How `TipAnchor` reads its rect after layout (post-frame callback and
  `RenderBox.localToGlobal` against the host's render box).

## Open with the owner (defaults taken)

- The copy above is the designer's; change any sentence.
- "Got it" rather than Next/Skip: each tip is on its own screen, so there is
  no sequence to skip.
