# Chant for My flows Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A flow's Chant plays the recordings of its recorded sections one after another in the flow's order, follows the words across them, fetches missing files as it reaches them, and skips sections that have no recording.

**Architecture:** `ChantProgramme` turns any reading into legs (one recording each) on one timeline whose block index space is the reader's existing flow-wide `PhraseBlockItem.index`; `ProgrammePlayer` wraps the single `ChantPlayer`, loads legs in turn and reports one `ChantState` on that timeline (a one-leg programme passes the inner state through untouched, so the pirith reader is unchanged). The reader binds every reading to a programme; waiting for a missing file is a `paused` state at the awaited leg's start, armed and disarmed like a chant. Captions and a mark in My flows and the editor say which sections chant.

**Tech Stack:** Flutter 3.47 / Dart 3.13, Riverpod 3, `just_audio` (unchanged), the existing `FakeChantPlayer` and `FakeRecordingStore` test doubles.

**Spec:** `docs/superpowers/specs/2026-11-17-flow-chant-design.md`

## Global Constraints

- The pirith and Samantha Pattana readers behave exactly as today: `test/reader/pirith_chanting_test.dart`, `pirith_follow_test.dart`, `samantha_patthana_chanting_test.dart`, `recording_download_test.dart`, `reader_awake_test.dart`, `chant_bar_test.dart` and `test/audio/*` pass without edits (except `chant_timing_test.dart`, which gains cases). A one-leg programme reports the inner player's state unchanged (position and duration as the player gives them).
- Leg starts come from `Recording.duration` (the content's `duration_ms`; all 40 recordings have one); the inner position is clamped to the leg's length before mapping. No timeline correction from the player's reported length.
- A leg is used only when its section is phrased (non-empty, every verse phrased) and the source reading's timed recording has exactly as many `blockTimes` as the section has verses. Source reading id: `refOfFlowSection(section.id)?.readingId ?? reading.id`.
- Waiting for a file reads `paused` at the awaited leg's start (plus the remembered offset) with the programme's total as duration; Restart and the slider stay usable; Play arms the wait, Pause/Scroll/background/leaving disarm it. A failed download shows the row's reason and Try again; Play downloads again. A seek, Restart or tapped line into a missing file waits the same way from the chosen point.
- Keys stay: `chant-play`, `chant-restart`, `chant-slider`, `chant-speed`, `reader-autoscroll`, `reader-prev`, `reader-next`, `follow-chanting`, `block-active`, `recording-row`, `recording-download`. New keys: `chant-coverage`, `flow-recorded-<readingId~sectionId>` (the mark).
- Copy, verbatim: "Chant plays 2 of 5 sections" (`'Chant plays $recorded of $total sections'`, only when `recorded < total`); `recordedCount(n)` → "1 with a recording" / "n with recordings"; a flow row's caption → `sectionCount(n)` + " · " + `recordedCount(k)` when k > 0; the mark's semantics label "Has a recording". All pass `tools/check_ui_glyphs.py`.
- Design rules (`test/quality/design_rules_test.dart`): no raw colours outside `lib/design/tokens.dart`; `textMuted` only under `lib/design/`; no Material default widgets; sizes via `NamoType`; no new `Duration(milliseconds:` outside tokens.
- No sound in tests; `FakeChantPlayer` stays the double (its `length` is every recording's inner length; leg starts still come from the content durations).
- Flutter at `/c/Users/Dell/develop/flutter/bin/flutter` (not on PATH); `flutter analyze` clean and the task's suites green before each commit; the full suite in Tasks 3 and 4. One flutter/git command at a time; never `git add -A`; commits by name with trailer `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- Android, iOS and web from one code base; nothing per platform changes.

## Review Focus

1. A flow whose recorded section comes after several unrecorded ones: Play must not move the page before that section's first block starts — Task 3 (`'the page stays until the first recorded block starts'`).
2. Leaving the reader while a leg's file is awaited: nothing plays after dispose, and the next reader is not silenced — Task 3 (`'leaving while waiting plays nothing'`).
3. The second leg's file fails to load (damaged or missing on disk): the bar shows the failure and Play tries that leg again — Task 2 (`'a failed load of a later leg is reported as failed and play retries it'`).
4. A speed change while waiting applies to the next leg — Task 2 (`'speed set while waiting reaches the next leg'`).
5. A second tap on Play while a leg loads must not load twice — Task 2 (`'play while loading is ignored'`).

---

### Task 1: Durations, the programme and per-block Pali lengths

**Files:**
- Create: `lib/audio/chant_programme.dart`, `test/audio/chant_programme_test.dart`
- Modify: `lib/audio/audio_catalogue.dart` (`Recording.duration`), `lib/audio/chant_timing.dart` (`paliLengthsOf`), `test/audio/chant_timing_test.dart`, `test/audio/audio_catalogue_test.dart`

**Interfaces:**
- Consumes: `Recording`, `AudioCatalogue`, `BlockTime`, `RecordingInfo.duration` (`lib/content/model.dart`), `refOfFlowSection` (`lib/flows/flow_reading.dart`), the phrased-section rule of `buildReaderItems` (`lib/reader/reader_items.dart`).
- Produces:
  ```dart
  // lib/audio/audio_catalogue.dart
  class Recording { ... required this.duration, ... final Duration duration; }   // ContentAudioCatalogue: RecordingInfo.duration; a timed recording without one throws StateError('recording for <readingId> has no duration'); the placeholder tone: Duration.zero

  // lib/audio/chant_timing.dart
  /// [block][phrase] Pali lengths over every section whose verses are all phrased, in order — the reader's block numbering.
  List<List<int>> paliLengthsOf(Reading reading);   // unchanged result for one-section readings

  // lib/audio/chant_programme.dart
  bool sectionIsRecorded(Section section, Recording? recording);   // non-empty, every verse phrased, recording != null && timed && blockTimes.length == verses.length
  class ChantLeg {
    const ChantLeg({required this.recording, required this.sectionId, required this.firstBlock, required this.start});
    final Recording recording; final String sectionId; final int firstBlock; final Duration start;
    int get blockCount => recording.blockTimes.length;
    Duration get end => start + recording.duration;
  }
  class ChantProgramme {
    const ChantProgramme({required this.legs, required this.sectionCount, required this.times, required this.lineTimes, required this.paliLengths});
    final List<ChantLeg> legs; final int sectionCount;
    final List<BlockTime?> times; final List<List<Duration?>> lineTimes; final List<List<int>> paliLengths;
    bool get single => legs.length == 1;
    int get recordedCount => legs.length;
    bool get partial => recordedCount < sectionCount;
    Duration get total => legs.last.end;
    int legAt(Duration position);          // 0 before the first leg; the last at/after total
    ChantLeg? legOfBlock(int block);
    /// Null when no section of [reading] is recorded.
    static ChantProgramme? of(Reading reading, AudioCatalogue catalogue);
  }
  int recordedSectionCount(Reading reading, AudioCatalogue catalogue);   // of(...)?.recordedCount ?? 0
  ```
  `of`: walk `reading.sections`; `block` counts phrased blocks as `buildReaderItems` does; for a recorded section make a leg with `firstBlock = block` and `start = previous end` (zero for the first); `times` has one entry per phrased block — a leg's `blockTimes` shifted by `start` (null stays null), null for blocks outside any leg; `lineTimes` has one entry per phrased block when any leg has line times (shifted lists; `const []` elsewhere), else `const []`; `paliLengths = paliLengthsOf(reading)`. For a one-leg programme `times` equals the recording's `blockTimes` and `lineTimes` equals its `lineTimes`.

- [ ] **Step 1: Write the failing tests**

- `test/audio/chant_programme_test.dart` (a fake `AudioCatalogue` over hand-made readings; made-up ASCII text): `'a pirith is a one-leg programme with its own times'` (start zero, `times` identical to `blockTimes`, `lineTimes` identical, `single`, `partial == false`); `'a flow of plain and pirith sections gives legs in order on one timeline'` (three plain sections, pirith A with 2 blocks and duration 10 s, pirith B with 3 blocks and 20 s → legs `firstBlock` 0 and 2, `start` 0 and 10 s, `times` length 5 with B's times shifted by 10 s, `sectionCount` 5, `recordedCount` 2, `partial`, `total` 30 s); `'the block index space matches the reader items'` (compare `legOfBlock`/`times.length` with `PhraseBlockItem.index` values from `buildReaderItems` on the same flow reading); `'a section whose recording does not cover it is not a leg'` (blockTimes.length != verses.length); `'no recorded section gives null'`; `'legAt at the boundaries'` (−1 ms → 0; exactly 10 s → 1; at total → last); `'line times are shifted and kept per block'` (one line-timed leg).
- `test/audio/chant_timing_test.dart`: `'paliLengthsOf counts every phrased section in order'` (a flow reading with a plain section between two phrased ones; lengths equal the originals'); the existing cases unchanged.
- `test/audio/audio_catalogue_test.dart`: `'a recording carries its duration'`; `'a timed recording without a duration is refused'`.

- [ ] **Step 2: Run them to see them fail**

Run: `/c/Users/Dell/develop/flutter/bin/flutter test test/audio/chant_programme_test.dart test/audio/chant_timing_test.dart test/audio/audio_catalogue_test.dart`
Expected: compile errors.

- [ ] **Step 3: Implement**

`Recording.duration` (update every constructor call in lib and test — grep `Recording(`); `paliLengthsOf` over all phrased sections; `chant_programme.dart` as in Interfaces.

- [ ] **Step 4: Run the audio and reader suites and the analyzer**

Run: `/c/Users/Dell/develop/flutter/bin/flutter test test/audio test/reader` → PASS (the pirith suites unchanged); `flutter analyze` → clean.

- [ ] **Step 5: Commit**

```bash
git add lib/audio/audio_catalogue.dart lib/audio/chant_timing.dart lib/audio/chant_programme.dart test/audio/chant_programme_test.dart test/audio/chant_timing_test.dart test/audio/audio_catalogue_test.dart
git commit -m "Chant: a programme of legs on one timeline"
```

---

### Task 2: The programme player

**Files:**
- Create: `lib/audio/programme_player.dart`, `test/audio/programme_player_test.dart`
- Modify: `test/support/fake_chant_player.dart` only if a hook is missing (say so in the report)

**Interfaces:**
- Consumes: Task 1; `ChantPlayer`, `ChantState`, `ChantStatus` (`lib/audio/chant_player.dart`); `FakeChantPlayer`.
- Produces:
  ```dart
  // lib/audio/programme_player.dart
  typedef Awaiting = ({int leg, Duration at});
  /// Plays a ChantProgramme's legs in turn on one ChantPlayer and reports one state on the programme's timeline.
  class ProgrammePlayer {
    ProgrammePlayer(ChantPlayer inner, {required bool Function(Recording) isAvailable});
    ChantState get state;                       // idle until the first load; one leg: the inner state as it is; several: position = leg.start + min(inner.position, leg length), duration = programme.total; waiting: paused at legs[leg].start + at
    Stream<ChantState> get states;              // broadcast, de-duplicated by ==
    ChantProgramme? get programme;
    int? get leg;                               // the leg loaded in the inner player
    Awaiting? get awaiting;
    bool get armed;                             // the chant should go on when the awaited file arrives
    void Function(int leg)? onAwait;            // the reader starts the download
    void bind(ChantProgramme p);                // stores it; loads nothing (the first Play loads, as today); leg = null, awaiting = null, state idle
    Future<void> playLeg(int leg, {Duration at = Duration.zero, bool play = true});
    Future<void> arrived();                     // loads the awaited leg, seeks to at, plays when armed; no-op when nothing is awaited or the file is still unavailable
    Future<void> play();                        // awaiting → armed = true, onAwait(leg); leg == null → playLeg(0); loading → ignored; otherwise inner.play()
    Future<void> pause();                       // awaiting → armed = false; otherwise inner.pause()
    Future<void> restart();                     // single → inner.restart(); else playLeg(0)
    Future<void> seek(Duration to);             // single → inner.seek(to); same leg → inner.seek(to - start); other leg → playLeg(legAt(to), at: to - start, play: inner was playing)
    Future<void> setSpeed(double speed);        // inner
    Future<void> dispose();                     // cancels the inner subscription; the inner player belongs to its provider
  }
  ```
  Inner states are published only once this player has loaded a leg or is waiting (a state left over from another reader's use of the same inner player is ignored, as `_chantLoaded` does today). On inner `completed` for leg k < last → `playLeg(k + 1)`; for the last → `completed` at `total`. A `failed` inner state is reported as `failed` with the leg's position; a later `play()` on `failed` reloads the same leg. `playLeg` on an unavailable leg: `awaiting = (leg, at)`, `armed = play`, state `paused` at `start + at`, `onAwait(leg)`.

- [ ] **Step 1: Write the failing tests**

`test/audio/programme_player_test.dart` with `FakeChantPlayer` (and a `_SpyPlayer` recording `seeks`/`loaded` as `pirith_follow_test` does), programmes built by hand with made-up recordings (durations 10 s and 20 s, `FakeChantPlayer.length` 10 s so inner completion lands at the leg end):
- `'a one-leg programme reports the inner state unchanged'` (bind; play → `loaded` has one recording; the state's duration is the fake's length; seek passes through; `restart` passes through).
- `'nothing is loaded on bind; the first play loads leg 0'`.
- `'play while loading is ignored'` (gate the fake; two plays → one load).
- `'leg 1 completing loads and plays leg 2 when available'` (advance 10 s → `loaded` has both, state playing at 10 s + inner 0; the position is `start + inner`).
- `'a position past the listed length is clamped'` (a leg listed at 8 s with the fake's 10 s length: inner 9 s → reported 8 s).
- `'with leg 2 unavailable the chant waits paused at its start and asks once'` (`isAvailable` false for B; after leg 1 completes: state paused at 10 s, duration 30 s, `awaiting == (1, 0)`, `onAwait` called once with 1; `armed`).
- `'pause while waiting disarms, play arms again'` (`onAwait` called a second time; `armed` toggles; the state stays paused).
- `'arrived loads the awaited leg and plays when armed'` (make B available; `arrived()` → loaded B, playing at 10 s; when disarmed → paused at 10 s, loaded).
- `'restart while waiting goes back to leg 0'`.
- `'seek into another leg loads it and keeps playing or paused'` (two cases).
- `'seek into an unavailable leg waits at the chosen point'` (`awaiting.at` = offset; state position = start + at).
- `'speed set while waiting reaches the next leg'` (`setSpeed(1.25)` during the wait; after `arrived()` the fake's `speeds` ends with 1.25 and `loaded` grew — the fake re-applies speed after load as the real player does; if it does not, add that to the fake and say so).
- `'a failed load of a later leg is reported as failed and play retries it'` (`failOnLoad` on the second load; state failed; `play()` → a third load).
- `'completed at the end of the last leg'` (position == total).
- `'states from before this player loaded anything are ignored'` (the fake emits a playing state before bind/play → `state` stays idle).

- [ ] **Step 2: Run them to see them fail**

Run: `/c/Users/Dell/develop/flutter/bin/flutter test test/audio/programme_player_test.dart`
Expected: compile errors.

- [ ] **Step 3: Implement `lib/audio/programme_player.dart`**

A broadcast `StreamController<ChantState>` fed from `inner.states` through the mapping above; a load generation counter so an overtaken `playLeg` does not play.

- [ ] **Step 4: Run the audio suite and the analyzer**

Run: `/c/Users/Dell/develop/flutter/bin/flutter test test/audio` → PASS; `flutter analyze` → clean.

- [ ] **Step 5: Commit**

```bash
git add lib/audio/programme_player.dart test/audio/programme_player_test.dart test/support/fake_chant_player.dart
git commit -m "Chant: a player that walks a programme's legs"
```

---

### Task 3: The reader chants a flow

**Files:**
- Create: `test/reader/flow_chant_test.dart`
- Modify: `lib/reader/reader_screen.dart` (the audio fields, `_bindAudio`, `_chantPlayOrPause`, `_chantRestart`, `_onRecordings`, `_onAudio`, `_tapLine`, the bar wiring in `build`, `dispose`), `lib/reader/reader_bottom_bar.dart` (`coverage`), `test/reader/flow_reader_test.dart`, `test/reader/chant_bar_test.dart` (or `reader_bottom_bar` tests, wherever the bar's rows are tested)

**Interfaces:**
- Consumes: Tasks 1–2; `recordingStoreProvider`, `RecordingsSnapshot.of`, `Availability`; `chantPlayerProvider`; `ChantFollow`; `realFlowsStore`, `openReal`, `FakeRecordingStore`, `FakeChantPlayer`, `mangalaReadingId`, `spVandanaId`.
- Produces:
  ```dart
  // lib/reader/reader_screen.dart (private state)
  ChantProgramme? _programme;          // replaces Recording? _timed
  ProgrammePlayer? _player;            // created in _bindAudio over the provider's ChantPlayer: ProgrammePlayer(inner, isAvailable: _available)..onAwait = _onAwait
  bool _available(Recording r) => (ref.read(recordingStoreProvider).snapshot.value.of(r.readingId)?.availability ?? Availability.downloaded) == Availability.downloaded;
  void _onAwait(int leg);              // store.download(legs[leg].recording) unless its status is downloading
  Recording? get _rowRecording;        // the awaited leg's recording while waiting, else the loaded leg's, else legs.first's
  // _chantPlayOrPause: playing → _chantWanted = false, pause; loading → return; otherwise _chantWanted = true, _autoScroll.pause(), queue store.download for every leg not downloaded and not downloading, player.play()
  // _onRecordings: if player.awaiting != null && _available(that leg's recording) → player.arrived()
  // _tapLine / onChantSeek → player.seek(...); _chantRestart → player.restart(); _onAudio unchanged except it reads the programme player's states
  // build: final programme = ChantProgramme.of(reading, catalogue) for every reading; the untimed dev tone keeps its path (recording != null && !recording.timed → AudioControls); the store is watched when programme != null || recording != null;
  //   bar: chantState: programme == null ? null : _chant.value; recording: store.snapshot.value.of(_rowRecording.readingId); onDownload → store.download(_rowRecording);
  //   coverage: programme != null && programme.partial ? 'Chant plays ${programme.recordedCount} of ${programme.sectionCount} sections' : null

  // lib/reader/reader_bottom_bar.dart
  ReaderBottomBar({..., String? coverage});    // when coverage != null and chantState.status == ChantStatus.idle, the slider's slot shows Text(coverage, key: ValueKey('chant-coverage'), style: NamoType.caption(p.textSecondary)) inside Semantics(liveRegion: true); once loading/ready/... the slider (or RecordingRow/ChantFailed) takes the slot as today
  ```
  `_follow` is built from `programme.times`, `programme.paliLengths`, `programme.lineTimes`. `_chantLoaded`/`_chantAwaitsFile` go away (the programme player carries that state); `_startedChant` stays (dispose pauses only a chant this reader started). The `flow` flag no longer forces `recording = null`; favourite, neighbours and bookmarks stay as they are for flows.

- [ ] **Step 1: Write the failing tests**

- `test/reader/flow_chant_test.dart` (real library; flows through `storeExtras`; `FakeRecordingStore`; `FakeChantPlayer`/`_SpyPlayer`): `'a flow of two pirith chants both in order'` (Play loads the first; advance past its listed duration → the second is loaded and playing; `block-active` moves into the second section); `'a mixed flow shows the coverage line until Play, then the slider'` ("Chant plays 2 of 5 sections" with flow-1 "Evening" plus a second pirith; key `chant-coverage`; after Play `chant-slider`); `'the page stays until the first recorded block starts'` (scroll offset unchanged after Play until the first block's time); `'a tap on a line of the second pirith seeks into it'` (the spy's last seek equals the line start minus the leg start); `'Restart goes to the first recording'`; `'the second recording not downloaded is queued at Play and awaited when the first ends'` (`store.downloads` holds the second's path right after Play; after the first completes the state is paused at the second's start, the row shows "Waiting to download" / "Downloading recording… 0%", `chant-restart` enabled; `store.set(id2, downloaded)` → the second plays); `'Scroll disarms the wait and Play arms it again'`; `'a failed download shows Try again and Play downloads again'`; `'a drag into an undownloaded leg waits at that point'`; `'leaving while waiting plays nothing'` (navigate away; `store.set(...)` → the fake player never plays); `'speed survives the leg change'`; `'the Vandana chants inside a flow'` (`spVandanaId` section with line-timed following); `'Previous and Next still move between headings'`; `'a flow with no recorded section is unchanged'` (no `chant-play`, no coverage line).
- `test/reader/flow_reader_test.dart`: the three "no chant on a flow" assertions become: no favourite button (kept) and `chant-play` present for the pirith-in-flow, two-pirith and Samantha Pattana flows.
- Bar tests: `'the coverage line sits where the slider goes until the chant starts'`.

- [ ] **Step 2: Run them to see them fail**

Run: `/c/Users/Dell/develop/flutter/bin/flutter test test/reader/flow_chant_test.dart test/reader/flow_reader_test.dart`
Expected: the flow tests find no `chant-play`.

- [ ] **Step 3: Implement**

As in Interfaces; keep the diff in `reader_screen.dart` to the audio paths named above.

- [ ] **Step 4: Run the full suite, the analyzer and the glyph check**

Run: `/c/Users/Dell/develop/flutter/bin/flutter test` → all pass (the pirith suites without edits); `flutter analyze` → clean; `python -I -X utf8 tools/check_ui_glyphs.py .` → exit 0.

- [ ] **Step 5: Commit**

```bash
git add lib/reader/reader_screen.dart lib/reader/reader_bottom_bar.dart test/reader/flow_chant_test.dart test/reader/flow_reader_test.dart test/reader/chant_bar_test.dart
git commit -m "Chant: flows play their recorded sections in order"
```

---

### Task 4: Captions, the mark, matrices and docs

**Files:**
- Create: `lib/flows/recording_mark.dart`
- Modify: `lib/flows/flows.dart` (`recordedCount`, `flowCaption`), `lib/flows/my_flows_part.dart`, `lib/flows/flow_editor_screen.dart`, `lib/flows/add_sections_sheet.dart`, `test/flows/*` (the existing flows tests), `test/quality/overflow_test.dart`, `test/quality/accessibility_test.dart`, `README.md` (My flows), `docs/release-checklist.md`, `docs/superpowers/specs/2026-11-10-chanting-flows-design.md` (one superseded note at the top)

**Interfaces:**
- Consumes: Tasks 1–3; `sectionIsRecorded`, `recordedSectionCount`, `audioCatalogueProvider`, `flowReading`, `liveRefs`.
- Produces:
  ```dart
  // lib/flows/flows.dart
  String recordedCount(int n);                       // '1 with a recording' | '$n with recordings'
  String flowCaption({required int sections, required int recorded});   // sectionCount(sections) + (recorded > 0 ? ' · ${recordedCount(recorded)}' : '')

  // lib/flows/recording_mark.dart
  class RecordingMark extends StatelessWidget { const RecordingMark({super.key}); }   // Semantics(label: 'Has a recording', child: Icon(Symbols.graphic_eq_rounded, size: NamoSizes.iconSmall, weight: 300, color: p.sage))
  ```
  My flows rows and the editor's header use `flowCaption(sections: live.length, recorded: recordedSectionCount(flowReading(flow, library), catalogue))`. Editor rows and the Add-sections sheet show `RecordingMark(key: ValueKey('flow-recorded-<readingId~sectionId>'))` after the title (in the row's `detail` or `trailing` slot, keeping the existing action buttons) when `sectionIsRecorded(section, catalogue.recordingFor(readingId))`.

- [ ] **Step 1: Write the failing tests**

- Flows tests (`test/flows/`): `'a flow row says how many sections have recordings'` (flow-1 "Evening": "4 sections · 1 with a recording"; flow-2 "Morning": "1 section · 1 with a recording"; a Buddha-only flow: "3 sections"); `'the editor shows the mark on recorded sections'` (key `flow-recorded-pirith-08-mahamangala~p` present; none on a Buddha section); `'the Add sections sheet marks recorded readings'`; `recordedCount`/`flowCaption` unit cases.
- `test/quality/overflow_test.dart`: rows for the flow reader with the chant bar idle (`Routes.reader('flow-1')` with `realFlowsStore`) and the editor with marks, at 320×568 and 1280×800, text 1.0 and 2.0, light and dark; `test/quality/accessibility_test.dart`: the same two screens (light and dark).

- [ ] **Step 2: Run them to see them fail**

Run: `/c/Users/Dell/develop/flutter/bin/flutter test test/flows` → FAIL (captions and marks missing).

- [ ] **Step 3: Implement and write the docs**

README "My flows": one paragraph — a flow chants its recorded sections in order and passes over the rest; the row says how many chant. `docs/release-checklist.md`: under My flows, owner checks: chant a flow of two pirith on the phone; with one of them not downloaded, the chant waits and goes on when it arrives; a Buddha-plus-pirith flow shows "Chant plays 1 of 4 sections". The 2026-11-10 design gets a first line "Superseded in part by `2026-11-17-flow-chant-design.md`: flows now chant their recorded sections."

- [ ] **Step 4: Run the full suite, the analyzer and the glyph check**

Run: `/c/Users/Dell/develop/flutter/bin/flutter test` → all pass; `flutter analyze` → clean; `python -I -X utf8 tools/check_ui_glyphs.py .` → exit 0.

- [ ] **Step 5: Commit**

```bash
git add lib/flows/flows.dart lib/flows/recording_mark.dart lib/flows/my_flows_part.dart lib/flows/flow_editor_screen.dart lib/flows/add_sections_sheet.dart test/flows test/quality/overflow_test.dart test/quality/accessibility_test.dart README.md docs/release-checklist.md docs/superpowers/specs/2026-11-10-chanting-flows-design.md
git commit -m "Flows: say which sections chant"
```
