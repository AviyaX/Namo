# Namo — Samantha Pattana Dharma Wandanawa (text, chanting and read-along) — Design

Date: 2026-11-11. Status: approved by the owner on 2026-11-11 ("built that", after being shown where the document is), including the calls in section 8. Section 8 was then tightened after a builder's read-through (calls 2, 3, 7, 8, 11 and the new 20-22); those changes are reported to the owner.

## 1. What the owner asked for

In the owner's words (2026-11-11):

> "afte rthat we create a another one like budda wandanawa and pirith called සමන්ත පට්ඨාන ධර්ම වන්දනාව (Samantha Pattana Dharma Wandanawa) here's teh pdf. in this one we need 2 section 1. Introduction [typed Sinhala text] then the second part pattana hdarma wandanwada in this pdf it contain firt the pali part and then later section sinhala meaning one"

> "https://www.youtube.com/watch?v=hYXyO3o7Iac you can download the audio from this youtube video"

> "/tipitaka.lk is the publisher"

> "show as in pirith" (asked whether each part shows its Pali with its meaning together, or all Pali then all meaning)

> "c if we can implement c that is the best way" (C = the recording plays and the text follows the voice)

So: the Library gets a third topic, **සමන්ත පට්ඨාන ධර්ම වන්දනාව**, beside Buddha Wandanawa and Pirith. It holds two readings: the **Introduction**, and the **Vandanā** itself. The Vandanā reads like a pirith: Pali, with the Sinhala meaning shown only when the Sinhala meaning is switched on, and a recording that highlights what is being chanted while the page follows.

## 2. Why

The owner chants this with the Thero's recording and wants it in the same quiet, offline reader as the rest of Namo, with the same help Pirith gives: not losing one's place in a long chant (47 minutes, much of it near-identical sentences where the eye slips easily).

## 3. Goals, non-goals, anti-goals

**Goals**
- A third topic in Library and on Home, with two readings: Introduction, and the Vandanā.
- The Vandanā shows the opening, the 24 numbered parts and the closing in the PDF's order. Each part shows its Pali; its Sinhala meaning appears under it only when the Sinhala meaning is on (the same rule as Pirith today).
- With the chanting playing: the line being chanted is highlighted, the word inside it is marked as in Pirith, and the page follows by itself. The same controls as a pirith (play/pause, restart, position slider, "Follow the chanting", tap to move the chanting).
- Without sound: plain auto-scroll and reading by hand, as everywhere else.
- Offline, free, no network request at run time; Android, iOS and web in step.
- Favourite, remembered place, Continue Reading, search, text size, line spacing and My flows work for it as they do for a pirith.
- Sources are credited: tipitaka.lk (publisher, on the owner's word), the chanter and the channel.

**Non-goals**
- An English meaning or Roman-letter Pali (the source has neither; none is made).
- Pairing the meaning sentence by sentence with the Pali (the source pairs them only by the 24 numbers).
- A recording of the Sinhala meaning or of the Introduction (the recording is the Pali only).
- Background/lock-screen playing, playing speed, repeat, downloading on demand.

**Anti-goals**
- Any Pali or Sinhala line retyped, corrected or "fixed" from memory. The text is the converter's output from the PDF and the owner's typed Introduction, nothing else.
- The automatic captions used for timing ever being shown as text.
- A highlight that pretends to be more exact than it is, or jumps backwards.
- Sound without the person pressing play; sound during checks on the owner's computer.
- Buddha Wandanawa, Pirith or My flows behaving differently because of this work.
- The app looking as if it were tipitaka.lk's or the channel's own.

## 4. What the material holds (measured)

All in `source_material/samantha_patthana/` (untracked today).

- **PDF** (56 pages, FM Bindumathi legacy font; publisher tipitaka.lk on the owner's word, the PDF names none). Pages 1–3 Introduction; pages 4–34 Pali; pages 35–56 Sinhala meaning.
- **Converted text**: `converted/pages/page-NN.txt` (one file per page, the PDF's own lines), `converted/structure.json` (where the opening, each of the 24 parts, each part's worship verse and the closing start, for both halves), `converted/conversion-report.md`. Made by `tools/fm_to_unicode.py`; nothing typed. `REVIEW_converted_text.md` is the same text laid out for the owner to check. **The owner has not checked it yet.**
- **Pali half**: opening (homage, three verses, the list of the 24 paccaya), 24 numbered parts each ending in a two-line worship verse, 5 closing lines. 507 text lines. Parts differ greatly in length (part 4 runs over three pages).
- **Sinhala half**: an opening, the same 24 numbers, a closing line.
- **Introduction**: the owner's typed Unicode text in `introduction_owner_supplied.md`. It differs from the PDF's pages 1–3 in 7 places.
- **Recording**: `audio/hYXyO3o7Iac.m4a`, 46.2 MB, 47 min 36 s, Ven. Kiriwaththuduwe Ariyadassana Thero, channel "Samata Dharmaya". It chants the Pali half only, start to end (the homage three times). No licence is stated on the video.
- **Timing**: the video has no chapters, but it has automatic Sinhala captions with a time on every word (saved at `audio/captions/si-orig.json3`, 2,171 words). A first rough match of those words to the PDF's Pali lines (letters only, in order) matched 79% of the letters; 437 of 507 lines got a time, in order with no step backwards. The 70 that did not are in long runs of near-identical sentences (e.g. pages 9–10), where a rough match slips; a more careful match should recover many, and the rest can be placed between their timed neighbours.

## 5. Constraints

- **No invented text.** Suspected errors are reported to the owner, not changed.
- **Text not yet checked.** The topic is built from the converted text as it stands and carries the app's existing "needs checking" status until the owner says it is checked. Corrections from the owner's check are applied in the source files and rebuilt, never typed into the app asset.
- **Permission.** The recording and the text are not put in front of the public until the owner says permission is in hand (a release-checklist line, as for Pirith). The recording is used byte for byte.
- **Offline, free, three platforms, no new package** (the audio and read-along machinery from Pirith is reused).
- **Existing behaviour and stored data preserved.**
- **Tests never play sound.**
- Design system tokens only; both themes; 320 wide up to desktop.

## 6. Approaches considered

**How the Vandanā is laid out** (put to the owner; chose "as in pirith"):
1. *Each part with its Pali and its meaning together — chosen.* Meaning shown only with the Sinhala meaning on.
2. *All Pali, then all meaning, as the PDF has it.* Faithful to the book's order but the meaning is 30 pages from its Pali.

**The recording** (put to the owner; chose C):
- A. Text only.
- B. Recording as one track, no following.
- C. *Recording with the text following — chosen.*

**Where the times come from** (my call):
1. *From the video's automatic captions, matched by tool to the PDF's lines — chosen.* No listening needed to produce them; a time per line, which is finer than Pirith's per-block times. Cost: the captions are machine-made, so some lines get an estimated time; the result must be checked by ear.
2. The owner notes 26 start times by ear. Exact where noted, but only one time per part — part 4 is over five minutes long, so the highlight inside it would be a guess.
3. Per-word times taken straight from the captions. Finer still, but the captions mishear words, so word-level marks would jump. Not now.

**Where the recording lives**: inside the app (+46 MB), same reasoning as Pirith (offline rule).

## 7. What the owner decided

- The topic, its name, its two readings, and that the Introduction is the owner's typed text.
- The text of the Vandanā comes from the PDF; the publisher to credit is tipitaka.lk.
- The recording is the YouTube one.
- Layout as in Pirith; the recording follows the text (C).

## 8. My calls (each can be overturned)

Content
1. **The Introduction uses the owner's typed text** as it is; the 7 differences from the PDF are listed for the owner but not applied.
2. **Line breaks: the PDF's own lines are kept**, in the Vandanā's Pali and in its Sinhala meaning, exactly as the owner sees them in the review file. A line too long for a narrow screen wraps like any long line. Nothing is joined into paragraphs, because the PDF has no paragraph marks and guessing them would rearrange the text. The Introduction is the owner's typed paragraphs and wraps normally.
3. **The Introduction is always shown** when that reading is open, whatever the language setting (it is Sinhala prose with no Pali; hiding it would leave an empty page).
4. **Language setting:** the Vandanā follows exactly what a pirith does today for each choice (Pali shown when Pali is chosen, the Sinhala meaning only when the Sinhala meaning is on). With English chosen there is no English to show, so the Pali shows alone; Sources says no English is included. If a choice hides the Pali there is nothing to highlight; the chanting still plays.
5. **Names:** topic title "Samantha Pattana Dharma Wandanawa" (the owner's spelling) with "සමන්ත පට්ඨාන ධර්ම වන්දනාව"; readings "Introduction" and "සමන්ත පට්ඨාන ධර්ම වන්දනාව" (Roman: "Samantha Pattana Dharma Wandanawa"). Library chip "Samantha Pattana".
6. **Each reading is one section** (like a pirith), so each can be favourited, has its place remembered, and can be added to a flow as text.
7. **Units and their meaning:** the units are, in order: the homage, the three opening verses, the list of the 24, each of the 24 parts, the closing. A unit's meaning is the piece of the Sinhala half that `structure.json` gives for the same slot (homage, list, each numbered part, closing), shown under the whole unit. A unit with no piece in the Sinhala half (the three opening verses) shows no meaning. Nothing is moved between slots.

Chanting
8. **Highlight:** each PDF line is one row, as a pirith's phrase is. The unit being chanted gets Pirith's quiet background, the line being chanted gets Pirith's phrase mark, from the line's own time.
9. **Lines whose time is estimated** (no confident caption match) are placed evenly between their timed neighbours and flagged in the data and in a report; the reader treats them like any other line. Times never go backwards.
10. **The homage chanted three times** keeps the homage highlighted until the verses begin.
11. **Everything else about the chanting is Pirith's**, unchanged: the bar's buttons, the slider, following and "Follow the chanting", tapping a line moves the chanting to the start of that line once the chanting has been started, loading on first play, stopping on leaving, the screen kept awake.
12. **The reader shows** "Chanted by Ven. Kiriwaththuduwe Ariyadassana Thero" under the title of the Vandanā, as Pirith shows its chanter. The Introduction has no recording, so its bar is the plain one.
13. **In a flow** the Vandanā is text only (flows have no recording button — already decided).

Elsewhere
14. **Picture:** the Home card and Library row use the owner's own unused picture `design/card_images/stupa_dusk.jpg`. (The other unused one is `bodhi_tree.jpg`.)
15. **Order:** third, after Pirith, in Library and on Home.
16. **Daily Gatha** keeps drawing from Buddha Wandanawa only.
17. **Search** covers the topic's names, the Introduction and the Vandanā's Pali and Sinhala, one hit per reading.
18. **Sources page:** an entry — "Text: සමන්ත පට්ඨාන ධර්ම වන්දනාව, published by tipitaka.lk; converted to Unicode by tool; the Introduction as supplied by the app's owner. Chanting: Ven. Kiriwaththuduwe Ariyadassana Thero, from the channel Samata Dharmaya. Namo is not connected with tipitaka.lk or the channel." "Used with permission" is added only when the owner confirms it.
19. **Git:** the built text and the recording are committed as app assets (the repository is local only); the downloaded originals, captions and PDF stay untracked source material, as with Pirith.
20. **Build inputs are tracked**, as with Pirith: a tool turns the converted pages and `structure.json` into `content/extracted/samantha_patthana.json`, and the times into `content/extracted/samantha_patthana_times.json`; both are committed and the app asset is built from them, so the stage check works without the untracked source material. The owner's corrections go into a corrections list in the build tool (from, to, reason — the way `tools/build_content.py` does it), never into the converted pages or the asset by hand.
21. **If the owner's listening check finds the line highlight drifting** in the long runs, the fallback is a data change, not a rebuild: those lines lose their own times and the unit is highlighted as a whole from its start time (the part starts are the most reliable times). The model must therefore allow a line with no time.
22. **Library row for the Vandanā** shows the recording's length, as a pirith's does.

## 9. How it fits the code that exists

Today (branch `first-release`):
- `lib/content/model.dart`: `Library → Category → Reading → Section → Verse`; a pirith's `Verse` carries `phrases` (Pali, Sinhala, English each); `Reading.audio` is a `RecordingInfo` with `blockTimes` (one start/end per verse) and `duration`. The reader estimates the word inside the timed block by length.
- `assets/content/pirith.json` built and checked by `tools/build_pirith.py <root> [--check]`; recordings under `assets/audio/pirith/`.
- The reader hides a phrased reading's meaning unless the Sinhala meaning is on; My flows resolves sections by `{readingId, sectionId}`.

Suggested shape (the plan may refine names, not behaviour):
- **Build tool** `tools/build_samantha_patthana.py <root> [--check] [--import-audio <dir>]`: reads the converted pages and `structure.json`, the owner's Introduction file, and a times file; writes `assets/content/samantha_patthana.json` and copies the recording to `assets/audio/samantha_patthana/`. `--check` proves the asset equals what the sources give and the recording matches its recorded size and checksum. It joins the other stage checks.
- **Timing tool** (separate, run once and when the text changes): matches the caption words to the PDF's Pali lines and writes `content/extracted/samantha_patthana_times.json` (per line: start, end, and whether matched or estimated) plus a report listing estimated lines. The captions file is read as data only.
- **Model:** a verse is one unit (section 8 call 7); its Pali lines are its phrases (Pali only), and it carries one meaning for the whole unit, shown under the lines. The recording information gains an optional time per line. Pirith's data and behaviour are untouched; where a recording has line times the reader uses them, otherwise the existing block rule.
- **Category id** `cat-samantha-patthana`; reading ids `sp-introduction`, `sp-vandana` (stable: saved items, places and flows are keyed on them).

## 10. Left to the builder

- Exact names and the asset's format; how the model carries lines and per-line times with the least disturbance to Pirith's code paths.
- The matching method in the timing tool, provided times are in order, every line has one, and the report says which are estimated.
- Screen-reader names, failure message, loading state: as Pirith.
- Checking the 46 MB `.m4a` plays and seeks in the browser at hand.

## 11. How we will know it is right

- Counts in the app equal the sources: 24 parts in both halves, 507 Pali lines, the opening and closing present; proven by `--check` and a test. The Introduction equals the owner's file character for character.
- Phone and wide sizes, both themes, meaning on and off, English chosen: no overflow, nothing empty.
- With a stand-in player moved through the real times: the right line is marked, marks move forward only, the page follows, hand-scrolling pauses following.
- Pirith, Buddha Wandanawa and My flows: every existing test passes unchanged in meaning.
- The web build makes no outside request, and none for the recording until play is pressed.
- The owner listens in the browser to the opening, a short part and the long part 4, and says whether the highlight keeps pace; the owner checks the converted text.
