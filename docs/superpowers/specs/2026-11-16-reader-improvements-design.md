# Reader improvements — design

Date: 2026-11-16. Status: the owner asked for the three changes after using
the app for a few days and said to go ahead ("yes work on them"); the
decisions below are the designer's, taken without a further round of
questions.

## Intent

Three things the owner found while using the app:

1. In a pirith it looked as if there was one play button for both the
   recording and auto-scroll, so scrolling the text without the sound
   seemed impossible. The control exists (the small two-arrow icon left of
   the big play) but the owner never recognised it. Make it obvious.
2. The recording has no speed control. Add one.
3. With Pali and Sinhala chosen, the meaning always sits under the Pali.
   Add a side-by-side layout, Pali left and Sinhala right, that a person
   can choose instead. Only for Pali with Sinhala. The Tripitaka reader
   (its own screens, its own switch) is not touched.

## Goals

- A person who has never used the app sees at once that a pirith can be
  scrolled by itself or chanted, and which button does which.
- Chanting can be slowed or sped up in a tap, the words keep highlighting
  in step, and the chosen speed is kept for next time.
- "Side by side" joins the layout choices wherever they are offered, works
  for gatha readings and for pirith, and is refused with a plain message
  when the two chosen languages are not Pali and Sinhala.
- Nothing else about reading, chanting, following, bookmarks, saved places
  or the Tripitaka changes.
- Android, iOS and web stay in step; the existing overflow and
  accessibility checks keep passing at 320 px and 2.0× text.

## Non-goals

- Changing the bar of a reading without a recording (one round play for
  auto-scroll, unambiguous already).
- Speeds outside 0.75×–1.5×, or pitch controls.
- A side-by-side view for Pali with English or Sinhala with English.
- Any change under `lib/tipitaka/`.
- Changing the content files.

## Constraints

- One code base for Android, iOS and web; iOS not build-tested here.
- Keys the tests already use stay: `reader-autoscroll`, `chant-play`,
  `chant-restart`, `chant-slider`, `reader-prev`, `reader-next`.
- No raw colours, Material defaults or type sizes outside the design
  tokens (design-rules tests). Every new UI string passes
  `tools/check_ui_glyphs.py`.
- Speed must come from the player, not from the app's clock: `just_audio`
  `setSpeed` is supported on Android, iOS and web, and the highlight
  follows the player's reported position, so nothing in `ChantFollow`
  changes.

## Approaches considered

1. **Pirith bar.** (a) Labels under all five icons: too wide at 320 px with
   2.0× text. (b) A second bar row: eats reading space. (c) *Chosen:* two
   round buttons in the middle of the control row, "Scroll" (outlined) and
   "Chant" (filled), each with a one-word caption; restart moves beside the
   slider, where it belongs with the recording.
2. **Speed.** (a) A sheet with a selector: a tap plus a choice for a
   one-dimensional setting. (b) *Chosen:* one button showing the current
   speed that cycles through four values, as podcast players do.
3. **Side by side.** (a) A separate on/off switch "meaning beside the
   Pali": two settings that fight each other. (b) *Chosen:* a third value
   of the existing layout setting, so one chooser carries all of it.

## How it works

### 1. The pirith bar

For a reading with a timed recording the floating bar has two rows.

**Recording row** (where the slider is today): a restart icon button
(`replay_rounded`, key `chant-restart`, tooltip "Restart chanting") on the
left, the position slider with its two times under it in the middle, and
the speed button (below) on the right. Restart is disabled until the
recording is loaded, as now. The failure message replaces the slider, as
now; the two buttons stay.

**Control row**: previous · **Scroll** · **Chant** · next, centred.

- **Scroll**: a 56 px round button, sage hairline border on the surface
  colour, sage `swipe_vertical_rounded` icon; while auto-scroll runs it is
  filled sage with the icon in the on-sage colour. Key `reader-autoscroll`.
  Tooltip and semantic label as today ("Start auto-scroll" / "Pause
  auto-scroll" / "Resume auto-scroll"). Caption under it: "Scroll".
- **Chant**: the existing 56 px filled sage button with its spinner while
  loading. Key `chant-play`. Caption: "Chant".
- Captions are `NamoType.caption` in the secondary text colour, centred
  under the button, one line, excluded from semantics (the button's label
  already says it). Button and caption are one column with 4 px between.
- Behaviour unchanged: starting one pauses the other.

The bar of a reading without a recording is unchanged.

### 2. Speed

- Values: 0.75×, 1×, 1.25×, 1.5×. A tap moves 1 → 1.25 → 1.5 → 0.75 → 1.
- The button shows the current value ("1×", "1.25×", "1.5×", "0.75×") in
  label type, 48 px touch target, key `chant-speed`. Semantic label
  "Chanting speed 1×", hint "Tap for 1.25×" (the next value). If
  `check_ui_glyphs.py` refuses "×", a plain "x" is used instead.
- Saved in `AppSettings` as `chantSpeed` (JSON key `chantSpeed`, default
  1.0). A missing, wrongly typed or unknown value falls back to 1.0; a
  number is snapped to the nearest allowed value.
- `ChantPlayer` gains `Future<void> setSpeed(double speed)`. The
  `just_audio` player applies the current speed after every successful
  load and at once when it changes; the fake player records it.
- The reader passes the setting to the bar and, on tap, saves the next
  value and calls `setSpeed`. `ChantState` is unchanged; the slider shows
  the recording's real position.

### 3. Side by side

- `TwoLanguageLayout` gains `sideBySide('Side by side')` after the two
  existing values.
- **Rule**: side by side applies only when the two chosen languages are
  exactly Pali and Sinhala, in either order. `setLayout(sideBySide)` with
  any other pair is refused and the chooser shows "Side by side needs Pali
  and Sinhala." the way the language chooser shows its refusals. When the
  saved layout is side by side but the languages are no longer that pair,
  the reader and the choosers behave as if it were "Verse by verse"; the
  saved value is kept, so choosing Pali and Sinhala again brings side by
  side back. One function, `effectiveLayout(AppSettings)`, decides this
  for everyone.
- **Gatha readings**: a new reader item, a verse pair (section id, verse
  id, Pali text, Sinhala text), for every verse that has both. A verse with
  only one of the two shows as a single full-width verse, as today. Drawn
  as a row: Pali on the left in the text colour, Sinhala on the right in
  the secondary colour, both top-aligned, `NamoSpace.lg` between, each
  taking half the width. Pali is on the left whichever language was chosen
  first. Headings, notes and introductions are unchanged. Saved places and
  bookmarks keep working: a pair item carries its verse id and counts as
  either of its two languages when a saved place is looked up.
- **Pirith**: the block already draws its two passages side by side on
  wide screens; under this layout it does so at any width, including a
  unit kept line by line (its lines on the left, its meaning on the
  right). Highlighting and tapping work as they do on wide screens today.
  On wide screens nothing changes.
- **Choosers**: Settings and the reader's sheet show three segments
  (Section by section · Verse by verse · Side by side). In a pirith the
  sheet, which hides the chooser today, shows it with two segments:
  "Meaning below" (sets "Verse by verse" when the saved value is side by
  side, otherwise leaves the saved value alone) and "Side by side". The
  "Needs two languages" rule stays.

## Tests

- Bar: the two rows and their keys for a timed recording; captions
  present; nothing overflows at 320×568 with 2.0× device text (the
  existing overflow suite, extended to a pirith); the Scroll button's
  tooltip states; starting Scroll pauses the chant and the other way round
  (existing tests keep passing).
- Speed: cycling order and labels; the setting saved and restored; an
  unknown saved value → 1×; the player receives `setSpeed` after load and
  on change (fake player).
- Layout: `buildReaderItems` with side by side gives pairs for verses with
  both texts and singles otherwise; `effectiveLayout` with each pair of
  languages; the refusal message; the pirith sheet's two-segment chooser
  and what each segment sets; a pirith block on a 320 px screen is a row
  under side by side and a column otherwise; a saved place resolves to a
  pair item.
- The whole check list: `flutter test`, `flutter analyze`, the content
  `--check`s, `check_ui_glyphs.py`, the web build.

## Left to the builder

- How the outlined Scroll button is drawn (a `DecoratedBox` with a sage
  border is the expectation), and exact spacing in the control row.
- The verse-pair widget's name and where the row logic lives.
- Whether the pirith sheet's two-segment chooser is a mode of
  `LayoutChooser` or its own small widget.

## Owner checks (release checklist)

- On a phone: open a pirith, press Scroll with no sound, then Chant; the
  two captions read right; change the speed while chanting and watch the
  highlight stay in step; set Side by side and read a gatha and a pirith
  at your usual text size.
