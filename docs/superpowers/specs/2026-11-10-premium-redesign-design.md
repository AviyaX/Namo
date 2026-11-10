# Namo premium redesign — design

Date: 2026-11-10
Owner's brief (word for word): `docs/superpowers/specs/2026-11-10-owner-redesign-brief.md`
Starting point: branch `first-release` at `3284870` (first release finished, 489 tests passing).

## 1. In short

The app works, but the owner finds that it "looks like a basic, outdated mobile application". This project gives every screen a new, calm, premium look, in **two versions: dark premium and light premium**. The owner asked for both ("the dark premium redesign has to be with there light premoum vertion also"). Dark is what a new user sees first; the switch is in Settings.

Everything the app does today keeps working exactly as it does now. Only how it looks, and a few places where it helps people find things (search, a daily verse), change.

Wherever this page says **(my call)**, the owner did not decide it; I chose it and the owner can change it. All of these are collected in section 16.

## 2. Why, and what success looks like

The owner's words: "A production-quality premium application that could comfortably compete with internationally released meditation, reading and wellness applications." And: "Do not stop after creating a basic dark theme."

Success, as the owner would judge it:

- Opening the app feels like opening a well-made book of devotion, not a default Flutter app.
- Both the dark and the light version look designed, not one made by inverting the other.
- Sinhala and Pali text is comfortable to read for a long time.
- Nothing that worked before is broken or missing.

## 3. Goals, non-goals, anti-goals

**Goals**

1. One shared look (colours, type, spacing, shapes, motion, components) that every screen uses.
2. Dark premium and light premium themes, each meeting the contrast rules in section 6.
3. New navigation bar, Home, Library, Reader, Saved, Settings, Sources, not-found and loading/error states.
4. Gentle motion that switches off when the device asks for reduced motion.
5. Works on Android, iOS and web from the same code, at phone, tablet and desktop widths.

**Non-goals**

- No new religious content. No change to the content file, its structure, or the content build tool.
- No "Popular Collections" and no "Recently Added" for now: with one topic there is nothing to rank or date, and inventing them would be showing fake things. Home is built so further topics appear by themselves when their content is added (section 9).
- No new packages and no new font files.
- No change to routes and addresses, saved-data keys, or what is stored.
- No accounts, no network use, no payments, no ads.
- No change to how auto-scroll, audio, bookmarks, favourites, reading position or language choice behave.

**Anti-goals** (it would be a failure even if it "works")

- A dark theme painted over the old layout.
- Any text of a verse changed, shortened, or re-typed for display.
- Decoration that makes the text harder to read: bright greens, strong gradients, heavy shadows, many borders, bouncing motion.
- A light theme that is only the old ivory look.
- A feature quietly lost because its screen was redrawn.

## 4. Constraints

- "This is a UI/UX redesign, NOT a request to rebuild the application's functionality. Preserve all existing functionality." (brief)
- Offline: nothing is fetched at run time. Fonts and pictures are bundled. The web build keeps `--no-web-resources-cdn`.
- Totally free: no price, ads or donation prompts.
- Android, iOS and web stay in step on every change.
- Verse text is shown exactly as stored. Only verses marked "checked against source" may be picked out and featured (section 9, Daily Gatha).
- Existing widget keys (`screen-*`, `reader-*`, `setting-*`, `settings-column`, `saved-column`, `open-<category id>`), tooltips and accessibility labels stay, so behaviour tests keep their meaning.
- Touch targets stay at least 48 × 48.
- The third-party `ui-ux-pro-max` skill is guidance only. Its checklist (`.claude/skills/ui-ux-pro-max/references/pro-rules.md`) is used for the final pass; it never overrides the owner's brief.

## 5. Approaches

Three ways of doing this were considered.

1. **Shared look first, then each screen** (chosen). Build the design system (palette, type, spacing, components) once, then rebuild each screen from those parts in the brief's order: navigation, Home and Library, Reader, Saved and Settings, motion, final inspection. Costs an early stage where little changes on screen; buys consistency, both themes for free on every screen, and small reviewable steps.
2. **Restyle screen by screen.** Faster to show a first screen, but each screen invents its own values, the two themes drift apart, and the result is the "inconsistent components" the brief wants gone. Rejected.
3. **Rebuild the app from scratch around a new design.** Rejected: the brief forbids it, and 489 tests of working behaviour would be thrown away.

The owner was told approach 1 and answered with the added requirement of a light premium version, which approach 1 handles directly: every colour comes from a named role that has a dark and a light value.

## 6. Colour

### 6.1 Roles

Every colour on screen comes from one of these roles. No screen uses a raw colour value.

| Role | Dark (owner's values) | Light (my call) | Used for |
|---|---|---|---|
| `background` | `#151714` | `#F7F4EC` | page background |
| `backgroundAlt` | `#1C1F1B` | `#EFEBE1` | grouped areas, selector tracks, input fields |
| `surface` | `#232720` | `#FDFBF6` | cards, floating bars, sheets |
| `border` | `#34382F` | `#D5CFC0` | hairlines and card edges (decoration only) |
| `text` | `#EAE6DC` | `#22251F` | main text |
| `textSecondary` | `#A9A698` | `#4F5248` | supporting text, second reading language |
| `textMuted` | `#77776D` | `#72736A` | see rule below |
| `sage` | `#A8B99F` | `#4F6447` | the accent: active tab, primary button, progress, selected state |
| `gold` | `#C6A879` | `#7F6130` | second accent: section numbers, "saved" state, small ornaments |

Derived, not separate values: pressed tint = `text` at 8 % over whatever is beneath; keyboard focus ring = `sage`, 2 px; text on a sage button = `background` (dark) / `surface` (light).

### 6.2 Measured contrast

Contrast ratio against `background` / `backgroundAlt` / `surface`:

| | Dark | Light |
|---|---|---|
| `text` | 14.5 / 13.4 / 12.2 | 14.1 / 13.0 / 15.0 |
| `textSecondary` | 7.4 / 6.8 / 6.2 | 7.3 / 6.7 / 7.7 |
| `textMuted` | 4.0 / 3.7 / 3.4 | 4.4 / 4.0 / 4.6 |
| `sage` | 8.7 / 8.0 / 7.3 | 5.9 / 5.4 / 6.3 |
| `gold` | 8.0 / 7.4 / 6.7 | 5.2 / 4.8 / 5.6 |
| `border` | 1.5 / 1.4 / 1.3 | 1.4 / 1.3 / 1.5 |
| text on sage button | 8.7 | 6.3 |

### 6.3 Rules that follow

- Text people need to read uses `text`, `textSecondary`, `sage` or `gold` (all at least 4.5 : 1 everywhere).
- **`textMuted` is below 4.5 : 1** in the owner's dark palette, so it is never used for text people need. It is used for: disabled controls, purely decorative marks, and the outlines of controls (it is at least 3 : 1 everywhere, which is the rule for non-text marks). **(my call — the owner's value is kept as given; only its use is limited.)**
- Placeholders (the search field) and hints that explain something (such as "Needs two languages") are needed text: they use `textSecondary`. Only the label of the disabled control itself may be `textMuted`.
- `border` is decoration. Nothing depends on seeing it: cards are also separated by their surface colour and spacing.
- Accents are used sparingly: on one screen, sage marks what is active or primary, gold marks numbers and saved things. Never large filled areas of either, except the one primary button.
- State is never shown by colour alone: active tabs also get a filled icon and a pill; selected segments also get a tick or a raised thumb; saved things use a filled icon instead of an outline.
- Text on a picture is always the light `#EAE6DC` over a dark fade, in both themes (section 9).

## 7. Type

No new fonts. **(my call — the brief allows "better alternatives already available in the project".)**

| Use | Family (already bundled) |
|---|---|
| Titles and English reading text | Lora (serif) |
| Sinhala, and Pali in Sinhala script | Noto Sans Sinhala |
| Navigation, labels, buttons, small text | the Latin letters inside Noto Sans Sinhala (they are Noto Sans) |
| Roman Pali, when it is added | Noto Serif (the only bundled font with all Pali diacritics) |

The builder checks with fontTools that every character in every English interface string exists in Noto Sans Sinhala; any that does not is drawn in Lora by fallback, and a test lists them.

Scale (logical pixels at normal system text size; all text follows the system text size):

| Style | Family | Size / line height | Weight |
|---|---|---|---|
| wordmark ("Namo") | Lora | 28 / 1.2 | 500 |
| screen title | Lora | 26 / 1.25 | 500 |
| section title | Lora (Sinhala: Noto Sans Sinhala) | 20 / 1.3 | 500 (Sinhala 600) |
| card title | Lora | 18 / 1.3 | 500 |
| body (interface) | sans | 15 / 1.5 | 400 |
| label, button | sans | 14 / 1.3 | 500 |
| caption | sans | 13 / 1.4 | 400 |
| overline | sans | 12 / 1.3, letter spacing 0.8 | 600 |

Nothing is smaller than 12. Reading text keeps today's sizes and the reader's own size and spacing controls (Sinhala and Pali 18, English 17, times the chosen scale).

## 8. Shape, spacing, depth, icons, motion

- **Spacing:** 4, 8, 12, 16, 24, 32, 48 only. Page side margin 20 on phones (16 under 360 wide), 32 from 840 wide.
- **Corner radii:** three only — 12 (fields, thumbnails, selectors, small cards), 16 (cards, groups), 24 (picture cards, floating bars, the top of sheets).
- **Depth:** flat. The only shadows are one soft shadow under the floating navigation bar, the reader's floating control bar, and sheets (dark: black 30 %, blur 24, offset 8 down; light: `#22251F` 12 %, same shape).
- **Icons:** Material Symbols Rounded, weight 300 (already used). Outline by default; filled only for the active tab and for "saved" states. Two sizes: 20 and 24.
- **Motion:** press feedback 120 ms; expand/collapse, selector thumb and tab fade 200 ms; page and sheet transitions 300 ms; ease-out curves; no bounce, no overshoot. With the device's "reduce motion" on, all of these are instant. Press feedback is a tint, never a change of size or position.
- **Content widths:** lists and reading column 680 (as today); Home 1040 on wide screens.

## 9. Screens

### 9.1 Navigation

**Phones (under 840 wide):** a floating bar. 16 from each side, 12 above the bottom safe area, about 64 high, radius 24, `surface` with a 1 px `border` edge and the soft shadow. Four destinations in today's order with today's labels: Home, Library, Saved, Settings. Each is at least 48 × 48.

- Inactive: outline icon and 12 px label in `textSecondary`.
- Active: filled icon and label in `sage`, on a faint sage pill (sage at 14 %).
- Pressing the tab you are on returns it to its first page (today's behaviour).

Content scrolls behind the bar, and every scrolling page has enough bottom space that its last item can be brought fully above the bar.

**Wide screens (840 and up):** the side rail stays, restyled the same way (same icons, labels, sage pill, `backgroundAlt` rail with a hairline). **(my call — a floating bottom bar looks lost on a desktop window.)**

Switching tabs cross-fades in 200 ms; each tab keeps its place and scroll position (as today). The reader stays a full-screen page outside the bar (as today).

### 9.2 Home

Order on a phone, top to bottom, with 24–32 between blocks:

1. **Header.** "Namo" wordmark; under it a small greeting in `textSecondary` — "Good morning" (05:00–11:59), "Good afternoon" (12:00–16:59), "Good evening" (otherwise), from the device clock. No settings button here: Settings is one tap away in the bar. **(my call on both.)**
2. **Continue reading.** Shown only when a reading place is remembered (today's rule). A `surface` card: small picture thumbnail, overline "Continue reading", reading title, the Sinhala heading of the section you were in, a 2 px sage progress line and the percent. Opens the reader where you left off (today's behaviour and accessibility label).
3. **Featured: the first topic** (Buddha Wandanawa). A large picture card, radius 24, the owner's statue picture cropped square on phones (the whole figure stays in view), at most 420 high. A dark fade rises from the bottom only as far as the text needs. On it: overline "Buddha Vandana", title "Buddha Wandanawa", Sinhala subtitle "බුද්ධ වන්දනාව", "19 sections" (counted from the content), and one sage button: "Begin", or "Continue" when a place is remembered. The card and the button open the reader.
4. **Today's gatha** (the brief's "Daily Gatha"). A `surface` card with a thin gold line on its leading edge: overline "Today's gatha", one whole verse in the reader's chosen language or languages (first in `text`, second in `textSecondary`, exactly as the reader draws them), the section's heading as a caption, and "Read in context", which opens the reader at that section. Rules **(my call)**:
   - Only verses marked "checked against source" are eligible; the four marked "needs checking" never appear.
   - Only short verses are eligible: Pali of at most 4 lines and no language over 320 characters. This is measured on the stored text of every language the verse has (a missing language counts as nothing), whatever languages the reader has chosen, so the eligible set is the same for everyone. Lines are counted by line breaks, length by characters. Today that is 19 of the 28 verses. The verse is shown whole, never cut.
   - The choice depends only on the local date: the number of days from 1 January 1970 to today's date on the device's calendar, modulo the count of eligible verses, taken in content order. So it is the same all day, the same on every device in the same date, and needs no storage or network. The clock is read through one provider that tests can replace; the greeting uses the same one.
   - If a chosen language has no text for that verse, that language is left out, as the reader does. If nothing would be left, the Pali is shown.
5. **In Buddha Wandanawa.** A row that scrolls sideways: one small card per section (gold number, Sinhala heading), each opening the reader at that section. "See all" opens the Library with the topic open.
6. **Collections.** Appears only when there are two or more topics: a sideways row of picture cards for the other topics. With one topic today it is absent. This is where Pirith and Meditation will appear when the owner supplies them.

**Wide screens:** the featured card becomes a full-width banner using the owner's wide picture (`design/card_images/home_banner.jpg`, statue on the right, text on the left), which gets bundled and credited on Sources **(my call)**. Its origin is already recorded in `docs/pictures.md` (supplied by the owner on 2026-11-10, made with an AI image tool); its Sources credit says the same as the existing picture's, and `docs/pictures.md` moves it to "Bundled". Under it, "Continue reading" and "Today's gatha" sit side by side; then the section row.

**Pictures.** The other pictures in `design/card_images/` (`pirith.jpg`, `bodhi_tree.jpg`, `stupa_dusk.jpg`) stay unbundled; they are for later topics. A topic with no picture of its own gets the drawn lotus panel that `lib/home/card_art.dart` already has, restyled in the new colours, wherever a picture or thumbnail would be: Home, Library, Saved, and the Collections row. Thumbnails are the same picture decoded small.

While content loads or if it fails, the existing loading and error states show, restyled.

### 9.3 Library

- Screen title "Library" in the page (no app bar), with a caption counted from content, e.g. "1 collection · 19 sections".
- **Search field** (new). `backgroundAlt`, radius 12, search icon, a clear button when there is text, accessibility label "Search the library". It does not take focus by itself.
- **Topic chips**: "All" plus one per topic, shown only when there are two or more topics. **(my call — one chip alone is noise.)**
- **Topic rows**, editorial style: square picture thumbnail (radius 12), title in Lora, Sinhala subtitle, "19 sections", and a chevron that turns when open. Tapping opens the numbered sections underneath on the same page — today's behaviour, animation, and remembered open/closed state. Section rows: gold number, Sinhala heading, a small forward chevron; tapping opens the reader at that section.
- Opening the Library from an address that names a topic or reading opens that topic once (today's behaviour) and clears any search text so it can be seen.

**Search behaviour (my call):**

- Works offline over what is bundled: topic titles and subtitles, section headings, and verse text in all three languages, whatever reading languages are chosen.
- Starts at 2 characters. While there is a query, the topic list is replaced by results: one row per matching section, in content order, showing the section number and heading, plus — when the match was in a verse — the matching line of that verse (at most two lines on screen). Tapping opens the reader at that section.
- When several texts of a section match, the line shown comes from the reader's chosen languages first (in their chosen order), then from the others in the order Pali, Sinhala, English. A line in a language that is not currently chosen carries a small label with that language's name.
- Matching is plain "contains": letter case ignored; Latin diacritics ignored (so "sangha" finds "Saṅgha"); spaces collapsed; invisible joiner characters in Sinhala ignored. No stemming, no fuzzy matching.
- Nothing found: an empty state saying so, with the query, and the line "Try a word from a section title or a verse."
- The query is not saved between app starts.

### 9.4 Reader

Looks change; behaviour does not. Position saving, back handling, keeping the screen awake, auto-scroll and its pause-on-touch, audio, bookmarks and favourites all stay as they are.

- **Top bar:** `background`, no shadow. Back; the reading's title, small, in `textSecondary`; favourite (outline heart, filled gold when on); reading settings (today's `tune` icon and tooltips).
- **Progress:** the 2 px sage line moves to directly under the top bar, full width, same accessibility label.
- **Section heading:** gold number, the heading in Noto Sans Sinhala 20/600, the bookmark button at the trailing edge (outline; filled gold when bookmarked; today's tooltips), a hairline beneath. Notes about missing or explanatory text keep their wording, in caption style.
- **Verse text:** first language in `text`, second in `textSecondary` (as today) — the two are told apart by tone, script and spacing, not by extra colours. 24 between verses, 12 between the two languages of one verse.
- **Floating control bar:** same shape language as the navigation bar. Previous section, a round sage play/pause button for auto-scroll (56 across, dark icon), next section; same keys and tooltips. When the reading has a recording, an audio row (play/pause, position slider, time) appears above the three buttons inside the same bar; with no recording it is absent, as today. The text can be scrolled fully above the bar.
- **Reading settings sheet:** radius 24 at the top, a grab handle, title "Reading settings". In order: languages (segmented selector, below), "When two languages show" (two-way segmented selector, disabled with "Needs two languages" as today), text size, line spacing, scroll speed, and the quiet button "Back to the beginning". Same keys.

**Segmented selector** (new shared component, replacing rows of radio-like choices):

- A `backgroundAlt` track, radius 12, equal segments at least 48 high.
- One-of-many (theme, layout): a `surface` thumb slides to the chosen segment in 200 ms; its label turns `text`, others `textSecondary`.
- Languages (Pali, Sinhala, English): any one or two. A chosen segment has a faint sage fill, a sage label and a small tick. Choosing a third, or switching off the last, is refused with today's messages ("Two languages at most. Switch one off first." / "One language always stays on."). This gives the brief's three pairs — Pali + Sinhala, Pali + English, Sinhala + English — and keeps today's single-language reading.
- Screen readers hear each segment as a button with its checked state, as today.
- Fits without overflow at 360 wide up to 1.5× system text size; above that the segments may stack.

### 9.5 Saved

- Screen title "Saved" in the page.
- Two groups with overline labels and counts: **Bookmarks** (rows: gold section number, Sinhala section heading, reading title beneath) and **Favourites** (rows: thumbnail, title, Sinhala subtitle). Every row opens the reader as today and keeps its remove button and tooltip.
- If one group is empty, it shows today's line ("No bookmarks yet." / "No favourites yet.").
- If both are empty: one centred empty state — an outline bookmark icon in a quiet circle (no illustration), "Nothing saved yet", "Bookmark a section or favourite a reading and it will wait for you here.", and the button "Open the Library". **(my call on the wording.)**

### 9.6 Settings

Screen title "Settings" in the page. Groups as `surface` cards (radius 16), each with a small outline icon and a label, rows separated by hairlines:

| Group | Contents |
|---|---|
| Appearance | Theme: segmented — Dark, Light, Same as device |
| Reading | Text size; line spacing; "When two languages show" |
| Languages | The language selector; caption "Choose one or two." |
| Audio | The switch "Start auto-scroll when a recording starts"; caption "No recordings are included yet." (shown while the content has none) |
| Auto-scroll | Scroll speed |
| About Namo | "Free. No ads. Works offline."; Sources (opens the Sources page) |

Every control keeps its key, label and behaviour. Nothing is removed.

### 9.7 Sources, not-found, loading and error

Restyled with the same parts; wording unchanged. Sources gains a credit line for the wide Home picture.

## 10. Themes and the switch

- A new install starts in **dark**. Settings → Appearance offers Dark, Light, Same as device. **(my call — the brief says dark is "the primary experience"; the owner asked for light as well.)**
- A choice already stored on a device is kept as it is. Note: the app has stored "Same as device" until now, so a browser that has already used the app keeps following the device until Dark or Light is picked once.
- In the code this is only a change of the default: stored settings with no theme, or none at all, give dark; a stored "system" stays system. No key, version or flag is added.
- The status bar and system navigation bar (Android, iOS) and the browser theme colour follow the theme in use, not the device's theme, set per theme from the app.
- Tabs are already kept alive side by side by the router (`StatefulShellRoute.indexedStack`); the cross-fade must keep that, so each tab's place and scroll position survive as today.
- The splash screen and web page background change from `#2B3837` to `#151714` on all three platforms. One dark splash for everyone, because the splash shows before the app can read the saved theme. **(my call.)** After re-running the splash tool, the iOS project's asset-catalog setting is checked (it has broken before).

## 11. Shared components

In `lib/design/` and `lib/design/widgets/`. Names are the builder's to choose; the set is:

palette (the roles of 6.1, dark and light), type styles (7), size/spacing/radius/motion values (8); page header; overline label; surface card; picture card with fade; thumbnail; editorial list row; segmented selector (one-of-many and one-or-two); search field; chip; primary button and quiet button; progress line; empty state; floating navigation bar and side rail; floating reader bar; sheet frame; slider and switch styling; pressable (tint feedback, focus ring, 48 minimum).

Material's default cards, dropdowns, elevated buttons and navigation bar are not used on any screen.

## 12. What does not change

Routes and addresses; the content file, model and build tool; saved-data keys and formats (`namo.settings.v1` and the others); what "bookmark", "favourite", "continue reading", language choice, layout choice, text size, line spacing, scroll speed, auto-scroll and audio do; widget keys, tooltips and accessibility labels; the 48 px minimum target; no network at run time; packages and fonts.

One stored default changes: the theme for new installs (section 10).

## 13. Platforms

All three share the Flutter code, so each stage lands on all three at once. Web is checked in the browser at every stage. Android and iOS cannot be built on this computer today (no Android SDK; iOS needs a Mac); their platform files (splash, system bar colours) are updated in the same commits, and the first Android and iOS builds remain owner tasks as before.

## 14. Order of work

The brief's phases, each ending with all checks green and a look in the browser in both themes:

1. Design system: palette, type, values, shared components; theme switch default. (Screens still old in layout, already in the new colours.)
2. Navigation bar and app structure.
3. Home, then Library with search.
4. Reader and its settings sheet.
5. Saved, Settings, Sources, not-found, loading/error.
6. Transitions and motion; splash and system bars.
7. Inspect every screen in both themes at 360, 390, 840 and 1280 wide and in phone landscape; fix what is uneven; run the `pro-rules.md` checklist.

## 15. Tests and checks

Behaviour tests stay and must keep passing. Tests that pin the old look (colours, Material widgets, layout details) are rewritten for the new look; none is deleted without a replacement that guards the same behaviour.

New tests:

- Both palettes: every text role against every surface role meets 4.5 : 1 except `textMuted`; `textMuted` and control outlines meet 3 : 1; a test fails if `textMuted` is used by a text style people need.
- Theme: new install is dark; a stored choice is honoured; the three-way switch works and is stored.
- Navigation bar: four destinations with labels, each at least 48 × 48, active one announced as selected; last item of each tab can be scrolled above the bar; side rail from 840.
- Segmented selector: one-of-many and one-or-two rules, refusal messages, screen-reader states, no overflow at 360 wide and 1.5× text.
- Today's gatha: same verse all day, changes with the date, only eligible verses over a full cycle, never a "needs checking" verse, text identical to the stored text.
- Search: finds by Sinhala, by Pali in Sinhala script, by English, with and without diacritics and capitals; one row per section; nothing-found state; opens the reader at the right section; cleared when a topic is opened from an address.
- Home: no "Continue reading" before anything was read; "Begin" becomes "Continue"; no Collections row with one topic, one with two (using test content).
- Saved: combined empty state and its button; single-group lines; rows still open and remove.
- Settings: every existing control still present with its key, under its group.
- Reduced motion: every animation is instant.
- No overflow on any screen at 360, 390, 840 and 1280 wide, at 1.0× and 1.5× text, in both themes.
- No raw colour values in screen code (a source scan).

Every stage: `flutter analyze` clean, all tests pass, content check passes, web build succeeds, and screenshots of the changed screens in both themes show no console errors and no outside requests.

## 16. Calls I made (for the owner to check)

1. Dark for new installs; Light and Same as device in Settings.
2. The light premium colours in 6.1.
3. The muted text colour (`#77776D`) is kept but used only where reading it is not needed, because it is too faint for small text.
4. No new fonts: Lora for titles, Noto Sans Sinhala for Sinhala, Pali and (its Latin letters) labels.
5. Home's content and order; a greeting by time of day; no settings button on Home.
6. Today's gatha: one whole, short, checked verse chosen by the date.
7. No "Popular Collections" or "Recently Added" until there is more than one topic; a "Collections" row appears by itself then.
8. Library search: plain "contains" search over titles, headings and verses in all three languages.
9. Topic chips only when there are two or more topics.
10. Wide screens keep a side rail instead of a floating bottom bar.
11. The owner's wide banner picture is used for Home on wide screens.
12. One dark splash screen on all platforms.
13. Wording of the new lines: "Today's gatha", "Read in context", "Begin" / "Continue", "See all", "Nothing saved yet…", "Open the Library", "Choose one or two.", "No recordings are included yet.", "Free. No ads. Works offline."

## 17. Left to the builder

Widget and file names; exact paddings within the spacing scale; how the tab cross-fade and page transitions are wired in go_router; how bottom space behind the floating bars is provided; the exact height of the picture fade (verified by measuring text contrast on the picture); picture alignment per crop; the fold table for Latin diacritics in search.
