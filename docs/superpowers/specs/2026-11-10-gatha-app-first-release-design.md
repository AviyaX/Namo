# Buddhist Gatha app, first release: design

Date: 2026-11-10. Status: waiting for the owner's approval.

Lines marked **(my call)** are choices Claude made that the owner has not yet confirmed. Everything else comes from the owner's written spec or from what the owner said in conversation.

## 1. What this is and why

A free, offline Buddhist prayer-book app for Android, iOS and web. It should feel like a well-made printed prayer book: calm, plain, comfortable to read for a long time. It should not look like a colourful generic mobile app.

The owner's model is namo.lk ("almost our idea as a web"). namo.lk already has a reader with font size, auto-scroll and a dark mode. What it lacks, and what this app adds: it works offline, it is an installable app, it remembers where you stopped, it has bookmarks and favourites, line spacing, and room for chanting audio later.

The first release holds one category, **Namaskaraya to Deviyanta Pin Dima** (the daily worship and offering sequence). The reader, the type, the language choice and the auto-scroll are the priorities.

## 2. Goals, non-goals, anti-goals

**Goals**

- One category with real, sourced text: 19 sections (listed in section 5).
- A reader with font size, line spacing, bookmark, favourite, progress, previous/next, and a remembered position.
- Language choice: Sinhala, English, Pali. One or two at a time, never three. Two layouts when two are chosen.
- Smooth auto-scroll with play, pause, resume, reset, slow/normal/fast and a custom speed.
- Audio that is fully optional: the app is complete without any recording, and recordings can be added later without reworking the reader.
- Four tabs: Home, Library, Saved, Settings. Light and dark themes.
- Settings, saved items and reading position survive restarts.
- Runs on Android, iOS and web from one codebase. All three are updated together on every change.

**Non-goals for this release**

- More categories (the other 31 namo.lk articles are stored and can follow).
- English for the shrine and offering sections (7–17) and for the three එත්තාවතා verses of section 18. Roman-letter Pali for any section. The slots exist; the text does not yet.
- Offline use and "install to home screen" for the **web** version. Android and iOS are offline by nature. Web offline depends on where the site is hosted, which is not decided **(my call)**.
- Publishing to the Play Store, the App Store or a public website. This release ends at a working, tested app. Publishing is a separate step with its own decisions (store accounts, icon, permanent app IDs).
- Real chanting recordings, lock-screen audio controls, audio timed to the verses.
- Accounts, sync between devices, search, notifications, sharing.

**Anti-goals: these would make it a failure even if it works**

- Any prayer text or translation that was typed from memory, generated, or "improved". Every line must trace to a named source.
- Text-to-speech or generated chanting standing in for real chanting.
- Ads, payments, donation prompts. The owner said the app "will be totally free".
- Jerky or jumping auto-scroll.
- Bright gradients, colourful cards, oversized headings, heavy shadows, decorative animation.

## 3. Constraints

- Flutter 3.47.9 / Dart 3.13.7, already installed. The project exists at `C:\Users\Dell\develop\buddhist_gatha` as the default scaffold for Android, iOS and web, with one commit.
- This Windows machine can run the web build in Chrome today. It has no Android toolchain yet (Android Studio or the SDK must be installed before an Android build). iOS cannot be built on Windows at all; it needs a Mac.
- Palette from the spec: warm ivory `#F5F1E8`, soft sand `#E8E0D2`, antique gold `#A88B5B`, forest green `#354638`, charcoal `#292A26`.
- Fonts are bundled in the app, not fetched: Noto Sans Sinhala for Sinhala and for Pali in Sinhala letters; Noto Serif for Roman Pali; Lora for English. All three are under the SIL Open Font Licence.
- Sources are credited inside the app.
- The app has no name yet. The working title is "Buddhist Gatha", from the heading of the owner's spec. The scaffold's placeholder IDs (`com.example.…`) stay until the owner names the app; they must change before anything is published **(my call)**.
- The owner's original spec is kept beside this document as `2026-11-09-owner-spec.md`. Where the two differ, this document is the later decision.

## 4. Approaches considered

**How the content is stored**

| Option | Trade-off |
|---|---|
| **A. One structured JSON file bundled with the app (chosen, my call)** | Small, readable, easy to check by eye and to compare between versions. Loads the same way on Android, iOS and web. No search index, which this release does not need. |
| B. SQLite database | Good for thousands of entries and search. On web it needs an extra WebAssembly layer, and the content becomes a binary file nobody can read or review. Too heavy for 19 sections. |
| C. Fetch from a server | Breaks the offline requirement and needs hosting. Rejected. |

The spec allows A or B. A fits because the content is small and must be reviewable. The code reads content through one repository interface, so moving to B later does not touch the screens.

**How the category is read**

| Option | Trade-off |
|---|---|
| **A. One continuous page for the whole sequence, with a contents list to jump to any section (chosen, my call)** | Matches how the sequence is chanted, from start to end. Matches namo.lk. Auto-scroll has something to scroll. |
| B. One screen per section | Many sections are two lines long (for example පහන් පූජාව). Auto-scroll would be pointless and the user would tap "next" 18 times in one sitting. |

**How auto-scroll moves**

| Option | Trade-off |
|---|---|
| **A. Move the page a little on every screen frame, by speed × time since the last frame (chosen, my call)** | Even motion at any speed. Speed can change mid-scroll with no jump. Unaffected when font size changes the page length. |
| B. One long "animate to the bottom" call | Simple, but it must be cancelled and recalculated whenever speed, font size or layout changes, and each restart risks a visible hitch. |
| C. A repeating timer | The spec rules this out; timers do not line up with screen frames and look jerky. |

## 5. Content

### 5.1 The 19 sections

Sections 1–17 are the namo.lk page "බුද්ධ පූජාව හා බෝධි පූජාව" (https://namo.lk/buddha-puja/, downloaded 2026-11-09, page last changed 2024-06-27). The owner chose this page: "all of this content". Sections 18–19 come from the paritha.org booklet, pages 37–38, because namo.lk has no merit-sharing or forgiveness verses anywhere; the owner said to use the other source.

| No. | Section | Source |
|---|---|---|
| 1 | නමස්කාරය | namo.lk |
| 2 | තිසරණ සරණයාම | namo.lk |
| 3 | පංචශීලය සමාදන්වීම | namo.lk |
| 4 | බුදු ගුණ සිහි කිරීම | namo.lk |
| 5 | දහම් වැඳීම | namo.lk |
| 6 | සඟුන් වැඳීම | namo.lk |
| 7 | චෛත්‍ය වන්දනාව | namo.lk |
| 8 | බෝධි වන්දනාව | namo.lk |
| 9 | බුද්ධ පූජා ආරාධනාව | namo.lk |
| 10 | පහන් පූජාව | namo.lk |
| 11 | සුවඳ දුම් පූජාව | namo.lk |
| 12 | මල් පූජාව | namo.lk |
| 13 | පැන් පූජාව | namo.lk |
| 14 | ආහාර පූජාව | namo.lk |
| 15 | ගිලන්පස පූජාව | namo.lk |
| 16 | දැහැත් පූජාව | namo.lk (the site numbers it "15" a second time; the app numbers it 16) |
| 17 | සියල්ල එකවිට පූජා කිරීම | namo.lk |
| 18 | දෙවියන්ට පින් දීම | paritha.org booklet, p. 37 |
| 19 | තෙරුවන් සමාකර ගැනීම | paritha.org booklet, pp. 37–38 |

The booklet prints the heading of section 18 as `දෙවියන්ට පින්දීම`; the app uses the owner's spelling, `දෙවියන්ට පින් දීම`.

The booklet follows section 19 with an untitled closing verse (ඉමිනා පුඤ්ඤකම්මේන …). It is left out of this release **(my call)** because it has no printed heading and lies past "Deviyanta Pin Dima". It is one line of configuration to add.

### 5.2 What each language slot holds

| Slot | In this release |
|---|---|
| Pali, in Sinhala letters | Present for all 19 sections |
| Sinhala (the meaning) | Present for all 19 sections |
| English | Present for sections 1–6 and 19 and for half of section 18. Empty for sections 7–17 |
| Pali, in Roman letters | Empty |

**English.** The owner supplied the Mahamevnawa "Vandana" PDF as "the English one", so its English is used wherever it has the same verse **(my call: the owner has not said this in so many words)**. What it has:

| Sections | What the PDF gives |
|---|---|
| 1–3 (homage, refuges, precepts) | A line-for-line translation |
| 4–6 (qualities of the Buddha, Dhamma and Sangha) | An explanation of each quality, word by word, not a line-for-line translation. It is shown as the English for these sections and the record marks it as an explanation **(my call)** |
| 18 | The three ආකාසට්ඨා verses. It does not have the three එත්තාවතා verses |
| 19 | All three forgiveness verses |
| 7–17 (shrine and offerings) | Nothing. Its "Buddha Puja" is a different text |

Each English verse is paired with its Pali verse by an explicit list in the build script (5.5). Each pairing is checked by reading the Roman-letter Pali that the PDF prints beside the English against the app's Pali. Where the two differ, the difference is recorded on the verse and the verse is marked "needs checking". One is known already: in the first ආකාසට්ඨා verse the booklet reads `ලෝක සාසනං` and the PDF reads "sasanam".

The PDF's Roman-letter Pali is **not** used **(my call)**. It is printed without the marks Roman Pali needs ("sammasambuddhassa", not "sammāsambuddhassa"), and the spec asks for correct Pali marks.

**Rules.** The four slots are stored as separate fields and never derived from each other. An empty field stays empty. Where a chosen language is missing from a section, the section shows one short, quiet line under its heading ("English is not yet available for this section", or "for part of this section") and nothing on each verse **(my call)**.

"Pali" in the language chooser shows the Sinhala-letter Pali. When Roman-letter Pali is added, a "Pali script" setting appears; until then it is hidden **(my call)**.

### 5.3 Spelling corrections

The owner said to use the spellings found in the other sources ("use anywhere else ones"). A spelling is corrected only when the stored sources themselves show the other form; the counts below are that evidence. Each correction is recorded in the content file beside the verse: the original, the replacement and the reason. Nothing else in the text is changed.

**namo.lk page (sections 1–17)**

| As printed | Corrected to | Evidence |
|---|---|---|
| ගච්චාමි (9 places) | ගච්ඡාමි | 20 uses elsewhere on namo.lk, 9 in the booklet |
| විඡ්ඡාචරණ (1) | විජ්ජාචරණ | 18 elsewhere on namo.lk, 4 in the booklet |
| සමාදියාමී (4) | සමාදියාමි | 10 elsewhere on namo.lk, 5 in the booklet; the page itself uses it twice |

**paritha.org booklet, pages 37–38 (sections 18–19)**

| As printed | Corrected to | Evidence |
|---|---|---|
| රුස්කර (3) | රැස්කර | රැස් 6 times elsewhere in the booklet and 8 on namo.lk |
| පුණ්ය (3) | පුණ්‍ය | the booklet's own other use; namo.lk |
| භූතයා් | භූතයෝ | 3 times elsewhere in the booklet, 2 on namo.lk |
| ම විසින් (3) | මා විසින් | 5 elsewhere in the booklet, 42 on namo.lk |
| සාසණ (1) | සාසන | 8 elsewhere in the booklet, 5 on namo.lk |
| පුංඤ්ඤකෙත්තං (1) | පුඤ්ඤක්ඛෙත්තං | 2 elsewhere in the booklet, 6 on namo.lk |
| අනුත්ථරං (1) | අනුත්තරං | 3 elsewhere in the booklet, 10 on namo.lk |
| දේවානාගා (3) | දේවා නාගා | spacing only; both sources print two words elsewhere |

`පුණ්ය` and `භූතයා්` have been checked against the image of the printed page: the booklet itself is typed that way. The rest are checked the same way at the start of Stage 2. If the page image shows the right spelling, the fault is in the conversion and is fixed there instead, not listed as a correction.

**Left as printed and marked "needs checking"** **(my call)**: `සබ්බ ධානේසු` in section 7. It is probably a slip for `ඨානේසු`, but no stored source has that verse to confirm it.

### 5.4 Per-section record

Each section carries: its heading; its verses in order; for each verse the four language fields above; source name, source address or page, and date collected; translator (none of the three sources names one, so this reads "not named by the source"); a check status (`unchecked`, `checked against source`, or `needs checking`); and its list of corrections. English carries its own source, since it comes from a different place than the Pali and Sinhala.

Audio is recorded on the reading, not on each section: see section 8.

### 5.5 How the content file is made

A script in `tools/` builds `assets/content/namaskaraya_to_pin_dima.json` from the three already-extracted files in `content/extracted/` (`namo_lk.json`, `paritha_booklet.json`, `mahamevnawa_vandana.json`). It applies only the corrections listed in 5.3 and the English pairing list described in 5.2. It stops with an error if a correction does not match the number of places expected. Nobody types verse text by hand. The script can be re-run at any time and must produce the same file.

Booklet page 37 has been compared line by line with the image of the printed page and matches. Page 38 is compared the same way at the start of Stage 2, before its text is used.

### 5.6 Credits

Settings has a "Sources" page that names, with links:

- namo.lk, for sections 1–17;
- the paritha.org booklet (compiled by Devapriya and Shyamali from the Piruwana Poth Wahanse, "for free distribution"), for sections 18–19;
- the "Vandana" booklet of Mahamevnawa Bhavana Asapuwa, Markham, Ontario, for the English.

What each source says about reuse: namo.lk states no terms. The booklet says free distribution only, which a free app meets. The Mahamevnawa PDF prints no terms and names no translator; its parent organisation's website asks that its material be kept to private use. The owner's position is that this material is free to share. A short note to each (hi@namo.lk; medism@gmail.com; info@mahamevnawa.ca) before any public release is still recommended, and matters most for the English. It is the owner's to send and does not block building.

## 6. Structure of the app

### 6.1 Shape of the content

Category → Reading → Section → Verse.

- A **reading** is a text read in one sitting. This release has one category holding one reading (the 19 sections). Later, a "Pirith" category would hold many readings.
- **Previous / next** in the reader moves between sections inside the reading (it scrolls to the heading). When a category has several readings, the first and last sections lead on to the neighbouring reading.

### 6.2 Screens

- **Home.** The app's name, a "Continue reading" entry showing where the user stopped, and the category.
- **Library.** Categories; inside a category, its readings; inside a reading, the contents list of sections. Tapping a section opens the reader at that section.
- **Reader.** Described in section 7.
- **Saved.** Two lists: bookmarks (places) and favourites (whole readings).
- **Settings.** Languages, layout, font size, line spacing, default scroll speed, audio preference, theme (light / dark / follow the device), Sources.

On wide screens (web, tablets) the text column is capped at a comfortable reading width and centred; the four tabs move from the bottom to the side **(my call)**.

### 6.3 Bookmarks and favourites

- A **bookmark** marks a section, so the user can come back to that place. A reading can have several.
- A **favourite** marks a whole reading.

### 6.4 Building blocks (my call)

| Need | Choice | Why |
|---|---|---|
| App state | Riverpod | Each piece can be replaced by a fake in tests, which the staged, tested build depends on |
| Routes | go_router | The web version gets real addresses (a link opens the reader directly) and the back button works as expected. Addresses use the form that works on any plain file host, since hosting is not decided |
| Saved settings and progress | shared_preferences | One small key-value store that works on Android, iOS and web |
| Audio playback | just_audio, behind the app's own interface | Works on all three platforms; the interface means the reader never depends on it directly |

Code is grouped by feature: `content` (model, repository, loader), `reader` (screen, scroll engine, layouts), `settings`, `saved`, `audio`, `library`, `home`, plus `design` (colours, type, shared widgets). Each stores and loads through an interface, so tests run without a device.

## 7. The reader

- **Top bar:** back, the reading's title with the category name beneath it, favourite, and a button for reader settings.
- **Body:** the sections in order. Each has its heading, a bookmark control, and its verses.
- **Bottom bar:** previous section, auto-scroll play/pause, next section, and a thin progress line. Audio controls appear here only when the reading has a recording.
- **Reader settings sheet** (opens over the reader, without leaving it): languages, layout, font size, line spacing, scroll speed, reset to the beginning.

**Languages.** The user picks one or two of Sinhala, English, Pali. Choosing a third is refused with a short message asking to switch one off first; the last remaining language cannot be switched off. The choice is saved.

**Layouts for two languages.**

- *Section layout:* within each section, all verses in the first language, then all in the second.
- *Verse layout:* each verse in the first language, directly followed by the same verse in the second.

Changing language or layout while reading keeps the user at the same verse.

**Progress and position.** Progress is how far through the reading the user has scrolled. The remembered position is stored as "which verse is at the top, and how far into it", not as a pixel count, so it stays correct after a font-size, spacing, language or screen-size change. It is saved as the user reads and restored on reopening.

**Auto-scroll.** Play starts from the current position. Slow, normal and fast are presets; a slider gives a custom speed; all can be changed while scrolling. Touching or dragging the text pauses it at once. Resume continues from wherever the page now is. It stops by itself at the end. Reset returns to the top and stops.

**Accessibility.** Every control has a screen-reader label and a touch area of at least 48 points. Text scales with the reader's font-size setting. Nothing overflows sideways at any setting.

## 8. Audio

No recordings exist, so the release ships with none and the reader shows no audio controls.

A recording belongs to a **reading**: one recording of the whole sequence, the way it is chanted **(my call)**. The catalogue can also hold a start time for each section, so that previous/next can jump within the recording once real audio exists; this release stores no times. Recordings are files bundled with the app. The catalogue answers through an interface, so downloaded recordings can be added later without changing the reader.

What is built: an audio catalogue (answers "does this reading have a recording, and where?") and a player interface (play, pause, resume, restart, position, duration), with a just_audio implementation behind it. Audio and auto-scroll are separate and can run alone or together; a setting "start auto-scroll when audio starts" links them if the user wants.

For development and tests only, one short neutral tone file, named and labelled as a placeholder, exercises the controls. It is never shown in a release build **(my call)**.

Lock-screen and background controls are left until real recordings exist, since they need per-platform setup that cannot be judged without real audio **(my call)**. The interface leaves room for them.

## 9. Themes

Light: ivory background, charcoal text, sand for dividers and quiet surfaces, forest green for headings and active controls, gold for small accents (the progress line, the bookmark mark). Dark: a charcoal-based version of the same roles, with text and accents lightened until they meet standard contrast levels **(my call; exact dark values are settled in Stage 1 and shown to the owner)**. Thin-line icons, hairline borders, almost no shadow, small corner radii.

## 10. Checking the work

- Automated tests for: the one-or-two-languages rule; loading the content file and its empty fields; both layouts; the scroll engine (speeds, pause on touch, stop at end, reset); saved settings, bookmarks, favourites and position surviving a restart; the reader with and without a recording; switching language mid-reading.
- A test that the content file matches what the build script produces, and that every correction in it is on the list in 5.3.
- Each stage ends with its tests passing and the app run in Chrome and looked at by Claude. Claude then reports to the owner what was built and what was seen, and carries on to the next stage unless the owner objects **(my call)**. Stage 1 (the look) and Stage 4 (the reader) come with screenshots for the owner.
- Android and iOS are confirmed to compile and run when a toolchain is available (see Constraints). Until then they are kept in step by code that has no platform-specific branches, and this limit is stated in each stage report.

## 11. Stages

The eight stages are the owner's. What each contains:

| Stage | Contains |
|---|---|
| 1. Design system and navigation | Colours, type, bundled fonts, light and dark themes, shared widgets. The four tabs with empty screens. Routes |
| 2. Home screen and the category | The content build script and the content file (5.5). Just enough of the content model to load it. Home, Library and the contents list showing the 19 sections |
| 3. Content model and language selection | The full model with all four language slots and the source record. The one-or-two-languages rule. Language and layout choice in Settings |
| 4. Reader screen | The reader, both layouts, font size, line spacing, previous/next, the settings sheet, the bookmark and favourite controls |
| 5. Auto-scroll | The scroll engine and its controls |
| 6. Audio architecture | Catalogue, player interface, controls that appear only when a recording exists, the development placeholder |
| 7. Persistence and reading progress | Everything saved across restarts: settings, bookmarks, favourites, position, progress. The Saved tab. "Continue reading" on Home. The rest of Settings, including Sources |
| 8. Tests, refinement, platform validation | Gaps in tests, accessibility pass, wide-screen layout, an Android build if the toolchain is installed by then |

Stages 3–6 keep their state in memory behind the same interfaces that Stage 7 then backs with saved storage, so nothing built earlier is reworked.

## 12. Left to the builder

File names inside each feature folder; exact type sizes and spacing; the preset scroll speeds and slider range (tuned by eye for a chanting pace); how often position is saved; wording of short interface messages; the interface language (English labels with Sinhala content in this release).
