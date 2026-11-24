# Buddha Wandanawa chanting — design (short)

Date: 2026-11-24. Branch `bana`. Owner approved the plan in conversation ("ok").

## Why

The owner wants the 33 sections of Buddha Wandanawa to play like the pirith: press
Play and the chanting goes section after section while the reader follows.

## Decided (owner)

- Only Ven. Nauyane Ariyadhamma Thero's voice: his real chanting where it exists
  (morning Buddha Vandana, YouTube NkxAu76U6z4; his Saranagamana pirith; his Pansil,
  YouTube K7If2Z1B3ME), and for the rest the owner's own chanting changed into the
  Thero's voice by an AI voice tool (Seed-VC), slowed to 90%. The owner says the
  monastery gave permission; the name for Sources is still to come.
- Computer-made chanting is labelled on its sections and credited in Sources.
- Sections 31 and 32: no audio. Section 12 uses the Thero's wording.
- Highlight verse by verse (these verses have no phrase marks); Play goes through
  the whole Wandanawa; Play also works in My flows.

## Approaches

1. **One recording per section, times per verse (chosen).** Each section carries
   its own `audio` in the content (path, label, one start/end per verse). The
   existing multi-leg chant programme (already used by flows) plays the recorded
   sections one after another. Smallest change to the player; a section can be
   redone alone; flows reuse it as is.
2. One recording for the whole reading with section cues. Needs new cue logic in
   the player and makes any one-section fix re-upload everything.
3. Give the verses phrase marks so they become pirith-style blocks. Changes how
   the Wandanawa looks and touches the text; rejected.

## Shape (designer's calls)

- Content: `Section.audio` (same fields as a reading's recording). Built by
  `tools/build_content.py` from `content/wandana_audio.json` (written by
  `tools/assemble_wandana_audio.py`) and the files in `hosted/audio/wandana/`
  (size, SHA-256, length measured from the file).
- A section with its own recording counts as a section of blocks (one block per
  verse) for the chant programme, the reader's block numbering and the place
  finder (one "phrase" per verse). Verses without a time are skipped.
- Recording ids for sections are `<readingId>#<sectionId>` (download status keys).
- Reader: the verse being chanted gets the sage tint box (as a pirith block), the
  page follows it, and a tap on a verse while chanting jumps there. The heading
  shows the section's recording label.
- Gaps the owner should know: the Thero's vandana has no s08 verse 3; his Metta
  (s33) matches our text only in verses 1 and 7; those verses stay silent and the
  label says so. The owner may record them later.
- Downloads, background play, speed and the web build work as for pirith.

## Non-goals

No word-by-word follow for the Wandanawa; no new recordings beyond what the owner
supplied; no change to the text.
