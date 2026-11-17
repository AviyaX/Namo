# Chant for My flows — design

Date: 2026-11-17. Status: the owner reported that a flow offers only Scroll
("in my flows we only can scroll, there is no play audio, need to fix it")
and, of three approaches, chose 1: Chant plays the recorded sections in the
flow's order and skips the rest. The rest is the designer's. Builder check
done the same day; its four questions (what sets the timeline's length, the
wait between recordings, a seek into a recording that is not on the device,
which flow tests change) are answered below as the designer's calls. This
supersedes the "no recording on a flow" lines of
`2026-11-10-chanting-flows-design.md` (its non-goal "Recordings for flows",
6.4 "No recording controls on a flow", "No recordings … on flows").

## Intent

A person opens one of their flows — say three Buddha Wandanawa sections, then
the Mangala Sutta, then the Ratana Sutta — and taps Chant. The Mangala Sutta's
recording plays and the words are followed as in the pirith reader; when it
ends the Ratana Sutta's recording follows without another tap; the Buddha
Wandanawa sections, which have no recording, are passed over. The bar tells
them beforehand that Chant plays 2 of 5 sections. Everything a pirith's
chant has — the slider, Restart, speed, Follow the chanting, tapping a line,
downloads on demand — works on the flow as one chant.

## Goals

- Chant on any flow with at least one recorded section; the recordings play
  one after another in the flow's order with no gap the person has to fill.
- The words are followed across all the recorded sections; a tap on a
  recorded line seeks there, even into another recording.
- A recording that is not on the device yet is fetched when the chant needs
  it (and the others are queued as soon as the chant starts), with the same
  row and messages as the pirith reader.
- The person can see how much of a flow chants: in the reader before the
  chant starts, in the My flows list and in the flow editor.
- The pirith and Samantha Pattana readers behave exactly as today.
- Android, iOS and web from one code base; the existing 2,500+ tests keep
  their assertions except the three in `flow_reader_test.dart` that pin "no
  chant on a flow" (a pirith in a flow; two pirith; the two Samantha Pattana
  readings — the Vandana is a one-section timed recording, so it chants in a
  flow too, with its line-timed following).

## Non-goals

- Recordings for sections of a reading that has none (Buddha Wandanawa);
  chanting an unrecorded section with synthetic speech; auto-scrolling
  through unrecorded sections while the chant waits.
- Joining recordings into one file, re-encoding, or crossfades.
- Partial recordings (a flow section that is only part of a recorded
  reading); every recorded reading today has one section, and the design
  leaves the hook (`sectionCues`) untouched.
- Changing the flow editor's structure beyond a caption and a mark.

## Anti-goals

- Any change to how a single pirith chants, looks or is tested.
- A chant that silently stops at the end of the first recording, or a page
  that jumps while the person is reading an unrecorded section before the
  chant has reached a recorded one.
- Playing a recording that has not been verified on the device.

## Constraints

- `ChantPlayer.load(Recording)` plays one file; `ChantStatus.completed` marks
  its end; `setSpeed` is kept across loads. Nothing in `just_audio` use
  changes.
- `ChantFollow` works on one `times` list and one Pali-lengths list indexed
  by the reading's block number; `PhraseBlockItem.index` in a flow is
  already a flow-wide running number over the phrased sections in flow
  order (plain sections take no numbers).
- The recording store is keyed by `Recording.readingId`; `locationFor`
  returns a location only for a verified, downloaded file; `download(r)`
  fetches one at a time.
- Every recording's content entry carries `duration_ms` (all 40 do), and
  `block_times.length` equals the reading's verse count (all 40 do).
- Design rules; keys the tests rely on stay: `chant-play`, `chant-restart`,
  `chant-slider`, `chant-speed`, `reader-autoscroll`, `reader-prev`,
  `reader-next`, `follow-chanting`, `block-active`, `recording-row`,
  `recording-download`.
- No sound in tests; `FakeChantPlayer` stays the test double.

## Approaches considered

1. **A programme player over the single player (chosen).** A `ChantProgramme`
   lists the flow's recorded sections as legs on one timeline; a
   `ProgrammePlayer` wraps the existing `ChantPlayer`, loads legs in turn
   and reports one `ChantState` on that timeline. The reader binds to the
   programme for every reading (a pirith is a programme of one leg), so the
   follow, slider, restart, speed and download logic stays in one shape.
2. **Re-bind in the reader on completion.** The reader keeps its
   single-recording code and, when a leg completes, swaps `_timed` and the
   follower to the next recording. Less new code, but the state that today
   assumes one recording (`_timed`, `_follow`, `_chant`, the awaits-file
   flags, the bar's `recording:`) would gain a "current leg" dimension in
   five places, and the slider could only show one leg at a time.
3. **One joined audio file per flow.** Rejected: recordings are never
   re-encoded, flows change at any time, and the files live on R2.

## How it works

### The programme (`lib/audio/chant_programme.dart`)

```dart
/// One recording's place in a chant: which blocks of the reading it covers
/// and where it starts on the chant's timeline.
class ChantLeg {
  const ChantLeg({required this.recording, required this.sectionId, required this.firstBlock, required this.start});
  final Recording recording;   // recording.duration is required
  final String sectionId;      // the flow section (or the reading's own) this leg plays
  final int firstBlock;        // flow-wide index of the leg's first block
  final Duration start;        // sum of the earlier legs' durations
  int get blockCount => recording.blockTimes.length;
  Duration get end => start + recording.duration;
}

class ChantProgramme {
  const ChantProgramme({required this.legs, required this.sectionCount, required this.times, required this.lineTimes, required this.paliLengths});
  final List<ChantLeg> legs;                    // in flow order; never empty
  final int sectionCount;                       // sections in the reading (flow or not)
  int get recordedCount => legs.length;
  bool get partial => recordedCount < sectionCount;
  final List<BlockTime?> times;                 // flow index space: each leg's blockTimes shifted by leg.start; null for blocks outside any leg
  final List<List<Duration?>> lineTimes;        // same, shifted; [] where a leg has none
  final List<List<int>> paliLengths;            // per phrased block across the whole reading (same counting as buildReaderItems)
  Duration get total => legs.last.end;
  int legAt(Duration position);                 // the leg whose [start, end) holds position; clamped to the ends
  ChantLeg? legOfBlock(int block);

  /// Null when no section of [reading] has a recording.
  static ChantProgramme? of(Reading reading, AudioCatalogue catalogue);
}
```

`of` walks the reading's sections in order, counting phrased blocks the way
`buildReaderItems` does; for each section it finds the source reading id
(`refOfFlowSection(section.id)?.readingId ?? reading.id`) and asks the
catalogue; a recording is used only when it is timed and its source reading
has exactly one section (a whole reading in the flow); otherwise the section
counts as unrecorded. `paliLengthsOf(reading)` is replaced by this
per-block list and the old function removed. `Recording` gains
`final Duration duration` (from `RecordingInfo.duration`; the catalogue fails
loudly on a timed recording without one). A single reading with a recording
gives a programme of one leg with `start` zero — today's behaviour.

Leg starts come from the content's `duration_ms` (every recording has one).
When a leg's file turns out a little longer than listed, the inner position
is clamped to the leg's length before it is mapped, so the highlight and the
slider never spill into the next section; a file a little shorter leaves a
gap of under a second before the next leg's times begin. There is no
correction of the timeline from the player's reported length: the listed
durations come from the files themselves.

### The player (`lib/audio/programme_player.dart`)

```dart
/// Plays a ChantProgramme's legs in turn on one ChantPlayer and reports one
/// state on the programme's timeline.
class ProgrammePlayer {
  ProgrammePlayer(this._inner, {required bool Function(Recording) isAvailable});
  /// One leg: the inner state as it is (today's slider, times and tests).
  /// Several legs: position = leg.start + min(inner position, leg length); duration = programme.total.
  ValueListenable<ChantState> get state;
  Stream<ChantState> get states;
  int? get leg;                                 // the leg loaded now
  /// A leg whose file is not on the device yet, and where in it the chant goes on when it arrives.
  ({int leg, Duration at})? get awaiting;
  /// Called when the chant needs a leg whose file is not available; the reader starts the download and shows the row.
  void Function(int leg)? onAwait;
  Future<void> load(ChantProgramme p);          // leg 0 when available (state ready); else awaits it
  Future<void> playLeg(int leg, {Duration at = Duration.zero, bool play = true});
      // available → load if needed, seek to `at`, play (or stay paused); not available → awaiting = (leg, at),
      // state paused at legs[leg].start + at, onAwait(leg)
  Future<void> arrived();                       // the awaited file is on the device: load it and go on (plays when the chant is still wanted, else stays paused there)
  Future<void> play();                          // while awaiting: arms the wait again (onAwait); otherwise inner play
  Future<void> pause();                         // while awaiting: the wait is no longer armed (awaiting stays, so Play can arm it again); otherwise inner pause
  Future<void> restart();                       // playLeg(0)
  Future<void> seek(Duration to);               // same leg → inner seek; another leg → playLeg(legAt(to), at: to - start, play: <was playing>)
  Future<void> setSpeed(double speed);
  Future<void> dispose();
}
```

On the inner player's `completed` for leg k < last: `playLeg(k + 1)` — the
next recording plays at once when its file is there; otherwise the chant
**waits** for it. The wait is not `loading`: the state reads `paused` at the
awaited leg's start (plus `at`), with the programme's total as duration, so
Restart and the slider stay usable and the Chant button reads Play. Play
while waiting arms the wait again (and the reader restarts the download if
it stopped); Scroll, going to the background and leaving the reader disarm
it exactly as they pause a chant today. A failed download leaves the row's
reason and Try again; Play starts the download again. On `completed` of the
last leg the state is `completed` at `total`. Speed is the inner player's
(kept across loads). A `failed` inner state is reported as `failed` (the
bar shows "The recording could not be played." as today; Play tries the same
leg again). A seek or a tapped line into a leg whose file is missing waits
the same way, from the chosen point.

### The reader

- `recording` for a flow is no longer forced to null: the reader builds
  `ChantProgramme.of(reading, catalogue)` for every reading; `_timed`
  becomes the programme (`ChantProgramme? _programme`), `_player` a
  `ProgrammePlayer` over `chantPlayerProvider`'s player, `_follow` is built
  from `programme.times/lineTimes/paliLengths`.
- The player's `isAvailable(r)` is
  `(store.snapshot.value.of(r.readingId)?.availability ?? Availability.downloaded) == Availability.downloaded`
  (a missing entry counts as downloaded, as today). Play
  (`_chantPlayOrPause`) becomes: playing → pause; otherwise `_chantWanted =
  true`, pause auto-scroll, and `player.play()` (which loads the first leg
  or arms the wait). When the chant starts on a flow, every leg whose
  recording is not downloaded is queued with `store.download(r)` so later
  legs arrive in time.
- `onAwait(k)`: the reader starts `store.download(legs[k].recording)` unless
  it is already downloading, and remembers that a file is awaited.
  `_onRecordings` (the store listener): when the awaited leg's recording is
  downloaded → `player.arrived()`; it plays only if `_chantWanted` is still
  true. The bar's `recording:` is the status of the awaited leg's recording
  while waiting (so the row shows "Downloading recording… 42%", "Waiting to
  download", or the failure with Try again), else the current leg's. The
  Chant button is busy while that recording is downloading, as today.
- Tapping a line: `follow.lineStart(block, line)` is already on the
  programme timeline; `_tapLine` calls `player.seek(...)`, which changes leg
  when needed.
- Restart → `playLeg(0)`. Previous/Next in a flow keep scrolling between
  headings. Screen awake unchanged (the lock is released while a leg's file
  is awaited and taken again when it plays).
- Nothing else about flows changes: no favourite, bookmarks mapped to the
  originals, saved place under the flow id.

### What the person sees

- **Reader bar on a flow with recorded sections:** the two-row chant bar.
  Before the first Play, and only when `programme.partial`, the slider's
  slot shows a caption "Chant plays 2 of 5 sections" (key `chant-coverage`,
  `NamoType.caption(p.textSecondary)`, a live region); from the first load
  the slider takes the slot (the timeline is the whole programme: "m:ss of
  m:ss" over all legs). A flow with no recorded section keeps today's bar
  (Previous / Scroll / Next).
- **My flows row** caption: `sectionCount(n)` plus " · 2 with recordings"
  when at least one section is recorded (`recordedCount(k)` → "1 with a
  recording" / "k with recordings"); nothing extra when none.
- **Flow editor:** the same caption under the flow name; each section row
  with a recording shows a small mark after its title (`Symbols.graphic_eq_rounded`
  at `NamoSizes.iconSmall`, `p.sage`, semantics "has a recording"); the
  "Add sections" sheet shows the same mark on recorded readings.
- Pirith and Samantha Pattana readers: unchanged.

### Tests

- Unit: `ChantProgramme.of` (one leg for a pirith with `start` zero and
  today's times; a flow of Buddha ×3 + two pirith gives two legs, the second
  shifted by the first's duration, `times` null for the Buddha blocks is
  not needed because plain sections take no block numbers — assert the
  index space matches `buildReaderItems`' `PhraseBlockItem.index`; a flow
  with no recorded section gives null; `legAt` at boundaries;
  `paliLengths` across sections equals the originals'); `ProgrammePlayer`
  with `FakeChantPlayer` (a one-leg programme reports the inner state
  unchanged — position and the fake's 20 s duration; advancing through leg
  1 of two loads and plays leg 2 when available; with leg 2 unavailable the
  state is `paused` at leg 2's start, `onAwait(1)` is called once, Restart
  still works, `arrived()` loads and plays; `pause` while waiting then
  `play` calls `onAwait` again; a position past a leg's listed length is
  clamped; `seek` into another leg loads it and keeps the paused/playing
  state, and into an unavailable leg waits at the chosen point; speed passed
  through; `completed` at the end of the last leg; a failed load reported as
  failed).
- Reader (real library, `FakeRecordingStore`, `FakeChantPlayer`): a flow
  with two pirith chants both in order (the second recording is loaded when
  the first completes; the active block moves into the second section); a
  flow mixing Buddha and pirith shows "Chant plays 2 of 5 sections" until
  Play, then the slider; a tap on a line of the second pirith seeks into
  it; Restart goes to the first; the second recording not downloaded →
  queued at Play, and when the first ends the state reads paused at the
  second's start with the row showing the download, Restart works meanwhile,
  Scroll disarms the wait and Play arms it again, and on arrival the chant
  goes on; a drag into an undownloaded leg waits the same way; a failed
  download shows Try again and Play downloads again; speed survives the leg
  change; the Samantha Pattana Vandana chants inside a flow; Previous/Next
  still move between headings; a flow with no recorded section is unchanged
  (no `chant-play`); the pirith reader's suites unchanged
  (`pirith_chanting_test`, `pirith_follow_test`,
  `samantha_patthana_chanting_test`, `recording_download_test`,
  `reader_awake_test` all green without edits).
- `flow_reader_test.dart`: the three "no chant on a flow" assertions are
  rewritten (no favourite button stays; chant controls present with a
  pirith, with two pirith, and with the Vandana); My flows and editor
  captions and marks tested; overflow matrix
  rows for a flow reader with the chant bar at 320 px / 2.0×; accessibility.

## Left to the builder

- Whether `ProgrammePlayer` exposes a `ValueListenable` and a `Stream` or
  only one of them (the reader uses `_chant` as a `ValueNotifier` today).
- The exact copy of the editor mark's semantics and the caption joiner.
- How the one-leg programme is given to the untimed development tone (the
  placeholder catalogue): it is untimed, so it stays on `AudioControls` as
  today and never becomes a programme.

## Open with the owner (defaults taken)

- "Chant plays 2 of 5 sections" wording and placement (the slider's slot
  before Play).
- The Buddha Wandanawa sections are passed over silently; the page moves to
  the next recorded section when its first block starts.
