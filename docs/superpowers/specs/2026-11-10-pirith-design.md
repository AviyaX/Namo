# Namo — Pirith (text, chanting and read-along) — Design

Date: 2026-11-10. Status: approved by the owner on 2026-11-10 ("yes this is good"), including the calls in section 8. Built after the premium redesign is finished and before My flows. Its plan is written once this is approved, against the redesign's real components.

## 1. What the owner asked for

In the owner's words (2026-11-10):

> "and next add pirith to the libray - in pirith there is a another deopdoen that contain all the pirith 1. Maha mangala sutta 2. rathana suthra 3. karaniya metta suthraya etc.."

> "https://pitaka.lk/pirith go through this one it have audieos and text in pali and sinhala whan we play the audio that is very usefull if we extract all the with timestam we can use that to our appp to scrool thig also"

> "when pirith is playing can we do auto scrall while hiiglighiing that word becueae in the web i gae you it has that feature we can get it to this rigfht ?"

> "yes user can ither play the audio and read while app itself highliting the words and also user can read the pirith by withouyt playing tha audios but auto scral is active you got what am saying ?"

On permission to use the site's material: "you cn get it wthout any issue ill get the permission and tht is not a n issue this site also given by developers".

So: the Library gets a second topic, **Pirith**. It opens in place to the list of pirith; each one opens in the reader. A pirith can be used in two ways: **with the chanting** (the recording plays, the app highlights what is being chanted and the page follows it), or **without sound** (plain auto-scroll at the chosen speed, as in Buddha Wandanawa). Reading by hand always works.

## 2. Why

People chant pirith along with a monk's voice, and they lose their place: the eyes fall behind the chanting or run ahead of it. pitaka.lk solves that on the web by lighting up the phrase being chanted. The owner wants that in Namo, on the phone, without internet, in the same quiet reader as the rest of the app. Pirith is also the second "topic" the owner planned from the start (Buddha Wandanawa, then Pirith, then Meditation).

## 3. Goals, non-goals, anti-goals

**Goals**
- A Pirith topic in Library and on Home, listing every pirith that has text (39), in the source's order.
- Each pirith opens in the existing reader, shown phrase by phrase: the Pali phrase with its meaning.
- With the chanting playing: the verse being chanted is marked, the phrase being chanted inside it is highlighted, and the page follows by itself.
- Without sound: plain auto-scroll (Slow / Normal / Fast) and reading by hand, exactly as today.
- Everything works with no internet, on Android, iOS and web; free; nothing asked of the network while the app runs.
- The existing reader functions keep working for a pirith: languages, text size, line spacing, favourite, remembered place, Continue Reading, search.
- The source is credited; the text is shown as the source has it.

**Non-goals (not in this piece of work)**
- The five recordings that have no text on the site (section 4).
- Playing with the screen locked or the app in the background, lock-screen controls.
- Playing one pirith after another by itself, repeat, a sleep timer, a playing-speed control.
- Exact per-word timing (the source has none; making it by hand is a separate job).
- Roman-letter Pali text (the source has only Sinhala-letter Pali).
- Recordings for Buddha Wandanawa; other chanters.
- Downloading recordings on demand.

**Anti-goals (would make this a failure even if it "works")**
- Any phrase retyped, corrected, joined, split or reordered: the text must be the source's, phrase for phrase.
- A highlight that jumps about or pretends to be more exact than it is.
- Sound starting when the person did not press play, or sound during automated checks on the owner's computer.
- The app needing internet, or opening noticeably slower because of Pirith.
- Buddha Wandanawa looking or behaving differently because of this work.
- The app looking as if it were pitaka.lk's own app.

## 4. What the source holds (measured, not assumed)

Source: https://pitaka.lk/pirith/ (project: github.com/pnfo/pirith, by pathnirvana). Everything below is already in the project, untracked: page files in `source_material/pitaka_lk_pirith/site/`, recordings in `source_material/pitaka_lk_pirith/audio/`, extracted text and times in `content/extracted/pitaka_lk_pirith.json`, made by `tools/extract_pitaka_pirith.py` (reads the page's files as text; nothing typed by hand).

- 44 recordings, all chanted by Ven. Nauyane Ariyadhamma Thero (නාඋයනේ අරියධම්ම ථෙරෝ), `.m4a`, 87.3 MB in all.
- 39 of them have text: 5,692 phrase rows in 1,157 blocks. Every row has all three: Pali in Sinhala letters, a Sinhala meaning of that phrase, an English meaning of that phrase. Their recordings total 53.7 MB (0.2–7.1 MB each; 53 seconds to 40 minutes 48 seconds).
- 5 have a recording only, no text: `28-aggika-bharadvaja-suttam`, `29-saccavibhanga-suttam`, `30-atanatiya-suttam-1`, `32-atanatiya-suttam-2`, `35-tesattati-nyana-parittam` (33.6 MB).
- Names are given in Sinhala only (e.g. මහා මඞ්ගල සුත්තං); the site has no English or Roman names.
- Timing: **one start and end time per block** (a block is a verse or a short passage: median 4 phrases, at most 23; median 13.9 s, at most 70 s). There is **no time per phrase**. The site finds the block as "the last block whose start is before the current time", takes progress = (time − start) ÷ (end − start), capped at 1, and picks the phrase by Pali text length: target = total Pali length of the block × progress; the first phrase whose running length reaches the target is the highlighted one.
- Oddities found: neighbouring blocks' times sometimes overlap by a fraction of a second (e.g. `12-mettanisamsa` block 4 starts at 47.66 s while block 3 ends at 47.80 s); a few blocks have small gaps between them; the last block of `25-alavaka-suttam` (block 30, 12 phrases) has no usable time on the site (`[0]`) and lies beyond the end of the recording — it is text only. A third number on some time entries is not used by the site's timing and is ignored.
- Credits on the site: "May this effort be a tribute to the venerable Nauyane Ariyadhamma Thero. The Pali text and Sinhala translations are excerpted from the Piruwana Poth Wahanse." Errors go to pathnirvana@gmail.com. Where the English comes from is not stated.
- Reuse terms in the source project: "Creative Commons Attribution-NoDerivatives 4.0 International Public License" and "copyright 2021 pathnirvana - please request permission if you would like to distribute any content here".

## 5. Constraints

- **Permission:** the owner is getting it from the site's makers. That is settled between them and is not a step in this work. The extracted file carries the note that the material is not released publicly until that permission is in hand; the credit and licence lines stay with the data and the source is credited in the app.
- **No derivatives:** the text is shown phrase for phrase as the source has it, and the recordings are used byte for byte (no re-encoding, trimming or joining).
- **No invented text:** nothing religious is typed or "fixed" from memory. If something looks wrong it is reported to the owner, not changed.
- **Offline and free:** no network request at run time; no new paid or online service.
- **Three platforms in step:** Android, iOS, web. iOS still cannot be built on this machine; the code must not rely on anything untested there beyond what the app already uses.
- **No unnecessary dependencies:** `just_audio` is already in the app and already hidden behind `ChantPlayer`; this work should need no new package.
- **Existing behaviour is preserved** for Buddha Wandanawa and for stored data (saved items, remembered places, settings).
- **The redesign's design system** (tokens, typography, components, both themes) is the only source of colours, sizes and motion.
- **Tests never play sound**; they use a stand-in player.

## 6. Approaches considered

**Layout of a pirith** (put to the owner; the owner chose 1):

1. **Phrase by phrase, like pitaka.lk — chosen ("1").** Each row is one Pali phrase with its meaning. It is exactly how the text and times come from the site, so nothing is rearranged; the Sinhala there is a phrase-by-phrase meaning that only reads right next to its phrase. Cost: a pirith looks different from Buddha Wandanawa (whole verse, then whole meaning).
2. **Whole verses, like Buddha Wandanawa.** Phrases joined into a paragraph with a joined meaning under it. Looks like the rest of Namo, but the joined meaning reads awkwardly and it rearranges someone else's text. Rejected for that reason.

**Where the recordings live** (my call, section 8): inside the app (+54 MB) versus fetched on first use (small app, but needs internet and somewhere to host files — against Namo's offline rule and its "no outside requests" rule). Inside the app.

**How the highlight is driven:** from the source's own block times plus the source's own length-based estimate inside a block (chosen: same behaviour the owner liked, no new data to make) versus making per-phrase times by hand for 5,692 phrases (exact, but weeks of listening and a derivative data set of its own). Not now.

## 7. What the owner decided

- The source is pitaka.lk/pirith: its text, its recordings, its times.
- Library gets a topic **Pirith** that opens in place to the list of pirith; each opens in the reader.
- Layout: phrase by phrase. On a phone the meaning sits directly under its phrase in a softer colour; on a wide screen phrase and meaning sit side by side. The language setting still works (Pali only, Pali with Sinhala, Pali with English).
- With the chanting: what is being chanted is highlighted and the page follows.
- Without sound: plain auto-scroll at the chosen speed, as in Buddha Wandanawa. Reading by hand works too.
- Only one runs at a time: starting the chanting stops plain auto-scroll; starting auto-scroll pauses the chanting. ("1. yes")
- Highlighting happens only with the chanting; silent auto-scroll shows no highlight. ("2. yes")
- The owner gets the permission.

## 8. My calls (not decided by the owner — each can be overturned)

Content
1. **Recordings go inside the app**, about 54 MB more, so pirith plays with no internet. I asked twice; it was not answered, so this is my call under Namo's offline rule.
2. **The 39 pirith with text are included; the 5 recording-only ones are left out** for now. Namo is a reading app and they have nothing to read; they would add 34 MB.
3. **Names:** each pirith shows the site's Sinhala name, and under it a Roman-letter name made letter for letter from that Sinhala name by a fixed rule in the build tool (standard Pali romanisation, e.g. Mahā Maṅgala Suttaṃ) — not typed by hand. Search finds it without the marks ("mangala").
4. **Numbering:** 1–39 in the site's order (the site's own numbers have gaps where the left-out recordings sit).
5. **English** is shown as the site gives it; Sources says its origin is not stated there.

Reading
6. **Blocks are kept visible:** the phrases of one block sit together with a wider gap before the next block, because the block is the unit the times belong to.
7. **A pirith is one section.** It can be favourited and its place is remembered; there is no separate bookmark inside a pirith in this release.
8. **"When two languages show"** (section by section / verse by verse) has no effect in a pirith, which is always phrase by phrase; the reading-settings sheet does not show that choice while a pirith is open.
9. **Previous / next** in the reader's bar go to the previous / next pirith (in Buddha Wandanawa they go to the previous / next section, as today).

Chanting
10. **How exact the highlight is, shown honestly:** the block being chanted gets a quiet background (exact — from the source's times); the phrase inside it gets the stronger mark (estimated by text length, as the site does, so it can be a moment early or late). The mark is a shape as well as a colour (a sage bar at the phrase's leading edge), so it does not rely on colour alone.
11. **The bar's buttons when a reading has a recording:** the round sage button plays and pauses the chanting; plain auto-scroll gets its own smaller button beside it with a different icon; a restart button; above them a thin position slider with elapsed and total time (the slider the redesign deferred to this work, ledger ruling R10). When a reading has no recording the bar is exactly today's (round button = auto-scroll). Reason: two identical play triangles in one bar would be confusing, and the chanting is the main thing in a pirith.
12. **Following:** the page moves when the highlighted phrase changes, keeping it about a third of the way down the visible text, with the design system's gentle motion (no motion when the device asks for reduced motion). If the person scrolls by hand while the chanting plays, following pauses, the chanting carries on, and a small "Follow the chanting" button appears above the bar; tapping it resumes following. Following does not resume by itself.
13. **Tapping a phrase** once the chanting has been started in this visit (playing or paused) moves the chanting to the start of that phrase's block. Before the chanting has been started, tapping does nothing — sound never starts from a tap on the text.
14. **Play starts from the beginning** the first time; after a pause it continues from where it was. The chanting position is not remembered after leaving the pirith; the reading place is.
15. **The recording is loaded when play is first pressed**, not when the pirith is opened (on the web this avoids fetching megabytes for someone who only reads). While it loads the round button shows a loading state.
16. **The existing setting "Start auto-scroll when a recording starts"** does not apply to recordings that have times (following replaces it); it stays for recordings without times.
17. **Leaving the screen:** the chanting stops when the person leaves the pirith, and pauses when the app goes to the background on a phone. The screen is kept awake while the chanting plays, as it is during auto-scroll. Sound follows the media volume like a music app.
18. **A block with no time** (Alavaka's last) is shown as text and never highlighted. In a gap between blocks the last phrase of the earlier block stays highlighted; before the first block starts nothing is highlighted; when the recording ends the highlight clears.

Elsewhere in the app
19. **Home** gets a second picture card for Pirith using the owner's own `design/card_images/pirith.jpg`; the Library card uses the same picture. Title "Pirith", Sinhala "පිරිත්".
20. **Daily Gatha** keeps drawing from Buddha Wandanawa only; a single pirith phrase out of its sutta is not a "gatha of the day".
21. **Each Library row** shows number, Sinhala name, Roman name and the recording's length; the reader shows "Chanted by Ven. Nauyane Ariyadhamma Thero" quietly under the title.
22. **Sources page:** a Pirith entry — chanter; "Pali text and Sinhala meaning from the Piruwana Poth Wahanse, as published at pitaka.lk/pirith by pathnirvana; English meaning as given there"; the licence name; "Namo is not connected with pitaka.lk". The words "used with permission" are added only when the owner confirms the permission has been given.
23. **My flows (later):** a pirith can be added to a flow as text like any section and is shown phrase by phrase there; flows have no recording button (already decided in the flows design), so no chanting inside a flow.
24. **Git and release:** the repository is local only (no remote; nothing is pushed unless the owner asks), so committing the material is not distributing it. There is no build switch for Pirith: it is built and visible in the owner's local copy. Putting the app in front of the public (a store, a public website, or pushing the repository to a public place) waits for the owner to say the permission has been given — a line in the release checklist, not code. The 39 recordings are committed once as app assets (they are needed to build the app); the folder of downloaded originals stays on this computer, out of git, so 87 MB is not stored twice; the small page files are committed as the record of the source.

## 9. How it fits the code that exists

The plan is written only after the redesign's 14 tasks are finished, so the reader, bar and settings sheet it names are final by then. The position slider does not exist yet: the redesign left it out on purpose and this work adds it (section 8 item 11).

What is there today (branch `premium-redesign`):
- `lib/content/model.dart`: `Library → Category → Reading → Section → Verse`; `Reading.audio` (`RecordingInfo{asset, label, sectionCues}`) exists but is never filled. `lib/content/content_repository.dart` loads one asset (`assets/content/namaskaraya_to_pin_dima.json`, `schema == 1`) through `libraryProvider`.
- `lib/audio/`: `ChantPlayer` (`load`, `play`, `pause`, `restart`, `seek`, a stream of `ChantState{status, position, duration}`), with `JustAudioChantPlayer` the only file that imports `just_audio`; `AudioCatalogue.recordingFor(readingId)`; `AudioControls` (play/pause, restart, time text).
- `lib/reader/`: `reader_items.dart` (`HeadingItem`, `VerseTextItem`), `reader_body.dart`, `reader_bottom_bar.dart` (previous, round auto-scroll button, next, optional audio strip), `auto_scroll.dart` (`AutoScrollEngine`), `reading_position.dart` (place kept as reading, section, verse, fraction), `screen_awake.dart`.
- `lib/library/library_screen.dart` already shows several categories and a category with several readings; `lib/library/search.dart` gives one hit per matching section and folds text on every keystroke with no cache.
- `lib/home/card_art.dart` maps a category id to its picture; `lib/saved/saved.dart` keeps bookmarks (reading + section) and favourite readings.
- `tools/build_content.py <project_root> [--check]` builds the Buddha Wandanawa asset; `--check` is part of every stage check.

The shape I suggest (the plan may refine names, not behaviour):
- **Content:** a build tool (`tools/build_pirith.py <project_root> [--check]`) turns `content/extracted/pitaka_lk_pirith.json` into a bundled text asset and puts the 39 recordings under `assets/audio/pirith/<site id>.m4a`. `--check` proves the bundled text equals the extracted text and each recording matches its recorded size and checksum. Category id `cat-pirith`; reading ids made from the site's ids (stable, because saved items and remembered places are keyed on them).
- **Model:** a pirith is a `Reading` with one `Section`; each block is a `Verse` that additionally carries its ordered phrases (Pali, Sinhala, English). The recording's information gains a start and end time per block. Buddha Wandanawa's data and file are untouched.
- **Timing logic:** one small pure function — given the block times, the Pali lengths and a position, return the block and phrase (or none) — following section 4's rule and section 8 item 18, tested against the real data's awkward cases (overlap, gap, untimed block, before the start, after the end).
- **Reader:** a new item kind for a phrase row; the body draws it stacked on narrow screens and side by side at the existing wide breakpoint; a follow controller listens to the player's position, owns "following / paused by hand", and never runs at the same time as `AutoScrollEngine`.
- **Search:** covers pirith names (Sinhala and Roman) and phrase text in the chosen languages, one hit per pirith showing the matching phrase; folded text is prepared once, not per keystroke.

## 10. What is left to the builder

- Exact file names, class names and the bundled file's format (one file or one per pirith), provided the app does not open noticeably slower and search stays responsive with 5,692 more rows.
- The exact look of the highlight, the slider and the "Follow the chanting" button, within the design tokens, in both themes, at every size the redesign supports (320 wide up to desktop, phone landscape, large text).
- Which fonts carry the Roman names' marked letters (check the bundled fonts' coverage; fall back within the bundled fonts).
- How often the highlight is recomputed and how the scroll is kept smooth.
- Screen-reader behaviour: phrase changes are not announced while the chanting plays; the controls are named ("Play chanting", "Pause chanting", "Start auto-scroll", "Follow the chanting", the slider's value as time).
- Behaviour on a failed recording: today's message ("The recording could not be played.") and the text stays fully usable.
- Checking `.m4a` playback in the browsers at hand; reporting, not hiding, any that cannot play it.

## 11. How we will know it is right

- Counts: 39 pirith, 1,157 blocks, 5,692 phrases, 39 recordings — in the app equal to the extracted file, proven by `--check` and by a test.
- A pirith opened at phone and wide sizes, both themes, each language choice: rows as described, no overflow.
- With a stand-in player moved through a real pirith's times: the right block is marked at each moment; the phrase mark moves in order and never leaves the block; the page follows; hand-scrolling pauses following and the button brings it back.
- Starting the chanting stops auto-scroll; starting auto-scroll pauses the chanting; no highlight during auto-scroll.
- Buddha Wandanawa: every existing test still passes unchanged in meaning.
- The web build makes no outside request and no request for a recording until play is pressed.
- The owner listens to at least Maha Mangala, Ratana and Karaniya Metta in the browser and says whether the highlight feels right.
