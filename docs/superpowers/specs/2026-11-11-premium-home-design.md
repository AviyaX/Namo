# Premium Home and shared look — design

Date: 2026-11-11. Status: approved by the owner on 2026-11-12; built on branch premium-home.

## Intent

The owner wants Namo to look premium, like the dark Home mockup they made
with ChatGPT (kept at `design/mockups/home_dark.png`, with the light one at
`design/mockups/home_light.png`; copy them there from the session's
`images/25.png` and `images/14.png` as the first step of the work). Home is
rebuilt in that mockup's arrangement. The rest of the app keeps its screens
and layouts but takes the same colours, card style, lettering and bottom
bar, so it feels like one app.

## Goals

- Home, on a phone, reads top to bottom as the dark mockup does: header,
  featured card, today's gatha, Quick Access, Collections, pill bottom bar.
- Light and dark themes both exist, with the same arrangement; each uses
  its own pictures and palette.
- Library, Saved, Settings, Sources, the flow editor and the reader match
  in feel through the shared tokens and shared widgets alone.
- Every existing feature keeps working and stays reachable.
- Android, iOS and web stay in step (one Flutter code base; nothing
  platform-specific is added).

## Non-goals

- New layouts for Library, Saved, Settings or the reader.
- New content, new topics, notifications, accounts, meditation features.
- New fonts or new packages.

## Anti-goals (these would make it a failure)

- Any control that does nothing (the mockup's bell is left out for this
  reason).
- Any religious text that does not come from the app's content files. The
  mockup's gatha wording and English line are illustration only and are not
  copied.
- Any network request at run time; any ad, payment or donation prompt.
- The reader becoming harder to read, or losing a setting.
- Text over a picture that fails contrast (4.5:1 for body text).

## Constraints

- Flutter, existing packages only. Fonts stay Lora (titles), NotoSerif
  (Roman Pali), NotoSansSinhala (Sinhala and interface text).
- Pictures: only the owner's own, listed in `docs/pictures.md` and credited
  on the Sources page as today ("made by its owner with an AI image tool").
- The owner's icon file `design/branding/namo_icon_owner_supplied.png` is
  not altered.
- The app's existing tests are updated, not deleted; analyze stays clean;
  the content and glyph checks stay green.
- Wide screens (840 px and up) keep the side rail.

## Approaches considered

1. **Home only.** Fastest, but the other screens would look like a
   different, plainer app.
2. **Home plus the shared look.** Rebuild Home; restyle everything else
   through shared tokens and widgets, layouts untouched. *Chosen by the
   owner*: premium feel everywhere without risk to the reader.
3. **Redesign every screen.** No mockups exist for the other screens, so it
   would be guesswork; can follow later, screen by screen.

## The shared look

All of this lives in `lib/design/` so every screen picks it up.

**Palette** (`NamoPalette`; starting values, the builder may tune a value
to meet contrast but keeps the character):

| Role | Dark | Light |
|---|---|---|
| background | `#0E1410` deep green-black | `#F8F4EA` warm cream |
| backgroundAlt | `#141C16` | `#F0EBDD` |
| surface (cards) | `#1A241C` | `#FFFCF5` |
| border | `#3B4233` | `#D9D0BB` |
| text | `#EFE9DA` | `#1F2A20` |
| textSecondary | `#B5B3A0` | `#4C5646` |
| textMuted | `#7F8273` | `#72786A` |
| sage (actions) | `#8FB07F` | `#4E6B45` |
| gold (accents, frames) | `#D2B26C` | `#8A6A2C` |

A new role, `frame`, is added: the thin gold line round a featured or
gatha card (gold at about 55% in dark, 45% in light). Error colours stay.

**Cards.** `SurfaceCard` gains a soft top-to-bottom gradient (surface to
backgroundAlt), a 1 px border and radius 20. Framed cards use `frame`.
Still one shadow style in the app.

**Lettering.** Titles in Lora as now. Overlines (FEATURED COLLECTION,
TODAY'S GATHA) are small capitals with wide letter spacing in gold.

**Bottom bar.** A full pill (radius = half its height), surface colour with
border; the active tab is a filled sage pill with light icon and label, as
in the mockup. Sizes, text scaling behaviour, keys and semantics stay.
The wide-screen rail takes the same active style.

**Drawn marks** (code, `CustomPainter`, no image files; new file
`lib/design/marks.dart`): the lotus mark (header, gatha overline), the
bodhi-leaf watermark (gatha card, very faint), and four Quick Access line
icons: joined palms, dhamma wheel, lotus, seated figure. Gold line work,
1.5 px stroke, and each has a semantic label or is excluded from semantics
where decorative.

## Home

Phone order: header · featured carousel · (continue card, only for a flow)
· today's gatha · Quick Access · Your flows (only if any) · Collections.

**Header.** Lotus mark and "Namo"; under it the tagline
"Buddhist Prayers · Chanting"; then the greeting. Behind it, bleeding to
the top of the screen and fading into the background colour, the header
picture for the theme. One icon at the right: search, which opens the
Library tab with its search field focused. No bell, no profile.

**Featured carousel.** One page per topic, in library order (Buddha
Wandanawa, Pirith, Samantha Pattana); dots under it show the page; swipe or
(for keyboard and screen reader) previous/next actions move it. It does not
move by itself. Each page: picture with the statue to the right and words
on the left over a scrim; overline "FEATURED COLLECTION"; title; Sinhala
title; count label (existing `topicCountLabel`); a sage button; and, when
there is something to resume, a progress line with "NN% complete" at the
lower right.

- Buddha Wandanawa uses `hero_dark` / `hero_light` by theme. The other two
  topics use their collection picture (existing scrim behaviour).
- Button and progress follow what is remembered, with no invented numbers:
  - topic with one reading and a remembered place: "Continue", progress =
    that reading's stored progress; opens the reader at the place.
  - topic with several readings where the last-read reading is in it:
    "Continue", the reading's name in a caption line, its progress; opens
    that reading.
  - otherwise: "Begin" (one reading) or "Open" (several; opens the topic
    in the Library); no progress line.
- The carousel starts on the topic that holds the last-read reading, else
  the first.
- On wide screens the page keeps today's wide proportions (width / 3).

**Continue card.** The existing slim card is kept only for the case the
carousel cannot cover: the last-read thing is one of the person's flows.
Restyled by the shared look, otherwise unchanged.

**Today's gatha.** Same pick rule and same texts as today (`gathaForDay`,
`gathaTexts`: the person's chosen languages, Pali when none has text;
English only when the source has it and the person has English on). New
dress: framed card, lotus + "TODAY'S GATHA" overline, leaf watermark at
the right, a caption "topic · section heading", and a "Read in context"
button (book icon, arrow). A bookmark button at the top right toggles the
existing section bookmark (`toggleBookmark(readingId, sectionId)`), filled
when set, so it shows up in Saved; its label says "Bookmark this section".

**Quick Access.** Four cards in one row (two rows of two below 360 px
wide), each: line icon, an English label, the section's own Sinhala
heading from the content, opening the reader at that section:

| Label | Section | Icon |
|---|---|---|
| Namaskara | `s01` | joined palms |
| Tisarana | `s02` | wheel |
| Pancha Sila | `s03` | lotus |
| Buddha Guna | `s04` | seated figure |

The English labels are interface labels, like the topic titles. The
Sinhala line is the heading exactly as stored (it may wrap to two lines;
it is not shortened to match the mockup). "See all" opens Buddha
Wandanawa in the Library. A card whose section is missing from the content
is not shown. This replaces the numbered "In Buddha Wandanawa" strip;
all 19 sections stay reachable through "See all" and the Library.

**Collections.** All three topics (today the first is left out) as
picture cards in a sideways row: title, Sinhala title, count with a book
icon, and for a one-reading topic with a remembered place, a progress line
and percent. Tap opens the topic in the Library, as now. "See all" opens
the Library tab.

**Your flows** row: kept as it is, restyled by the shared look.

## Pictures

Supplied by the owner on 2026-11-11, generated with ChatGPT from their own
mockup; originals in `source_material/ui_pictures/` (untracked). Converted
to JPEG (quality about 85, longest side at most 1600) into
`assets/pictures/`:

| Asset | From | Used for |
|---|---|---|
| `hero_dark.jpg` | `hero_dark.png` | featured page, dark |
| `hero_light.jpg` | `hero_light.png` | featured page, light |
| `header_dark.jpg` | `header_dark.png` | Home header, dark |
| `header_light.jpg` | `header_light.png` | Home header, light |
| `buddha_wandanawa.jpg` | `buddha_wandanawa.png` | replaces the current card picture |
| `pirith.jpg` | `pirith.png` | replaces the current card picture |

`samantha_patthana.jpg` stays as it is until the owner supplies the new
one. `home_banner.jpg` is no longer used and is dropped from the bundle.
`continue_thumb.png` and the two tall statues are kept in source material,
unused. `docs/pictures.md` and the Sources page credit are updated to
match. If a picture fails to load, the existing drawn fallback panel shows.

## Edge cases the builder must cover

- Text size at 200%: nothing clipped on Home; cards grow.
- 320 px wide phone and 1280 px wide window.
- No remembered place anywhere (first launch): no progress lines, "Begin".
- "Reduce motion": carousel and bar change without animation.
- Light theme over light pictures: words stay readable (scrim or dark
  text, the builder's choice per picture).
- Screen reader order follows the visual order; the carousel announces
  "page n of 3".

## Answers to a builder's questions

- **Mockups** are in the repo at `design/mockups/home_dark.png` and
  `home_light.png`. The dark one is the reference for arrangement and
  proportions. Where this text and the mockup disagree, this text wins.
- **The pictures are plain scenes**: no text, marks, scrim or interface in
  any of them. The two hero pictures (1600 x 800) have the statue on the
  right and an empty, darker left for the words; a scrim is still added in
  code. The two header pictures (1600 x 533) already fade to the theme's
  background colour at the bottom and left; code adds a short fade at the
  bottom edge so the join cannot show, and crops from the top right.
- **Bottom bar tabs** keep icon over label, all four labels always shown,
  as now. Only the bar's shape and the active tab's fill change.
- **Search from Home** goes to the Library with a query parameter
  (`/library?focus=search`) that the Library screen reads once to focus its
  search field. Pressing the Library tab again still resets it as now.
- **Wide screens**: one centred column at the existing `homeColumn` width:
  header (picture spans the column), featured page, then today's gatha,
  Quick Access (four in a row), flows, Collections (three cards filling the
  row, no sideways scroll). The continue card for a flow sits beside the
  gatha card as now.
- **Topics today**: Buddha Wandanawa has 1 reading (19 sections), Pirith
  39, Samantha Pattana 2. Rules are written by reading count, not by topic
  name. "Open" always leads to that topic in the Library. "Continue" on a
  several-reading topic appears only when the last-read reading is in it.
- **Contrast**: all text, overlines included, meets 4.5:1 (3:1 for large
  titles) on whatever it sits on; tune gold or the scrim to get there.
  Frames, the watermark and dots are decoration and need not.

## Left to the builder

Exact spacing, the drawing of the marks, the scrim strengths, how the
carousel is built (a `PageView` is expected), the conversion tool for the
pictures, and how tests are organised.

## Calls made by the designer, for the owner to check

- No bell; search icon opens the Library search.
- Tagline without "Meditation".
- Progress is how far through a reading the person has scrolled, not a
  count of sections.
- Pirith and Samantha Pattana show progress only on the featured page for
  the reading last read, not a figure for the whole topic.
- The numbered section strip is replaced by Quick Access.
- The carousel does not move by itself.
- Quick Access Sinhala lines use the full stored headings.
- Built departure: the overline on the featured card is cream, not gold (contrast).
- Built departure: Quick Access is four across from 390 px, 2 x 2 below (words would break).
- Built departure: the "NN% complete" figure sits on a small dark backdrop so it stays readable over the light hero picture.
- Built departure: on phones the featured card's words take about 65% of its width (half on wide screens), so a long title word is not broken.
- Built departure: the header picture is at most 136 px tall (plus the top inset) so it has faded out before the featured card; on wide screens it also fades at both sides of the column.
