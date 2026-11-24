import '../content/model.dart';
import '../flows/flow_reading.dart';
import 'audio_catalogue.dart';
import 'chant_timing.dart';

/// True when [recording] chants [section]: the section is numbered as blocks
/// ([sectionHasBlocks]) and the recording times exactly its blocks.
///
/// A pirith's recording is its reading's, and every recorded reading has one
/// section, so the verse count stands in for that. A section with its own
/// recording (a Buddha Wandanawa section) is chanted only by that.
bool sectionIsRecorded(Section section, Recording? recording) =>
    sectionHasBlocks(section) &&
    recording != null &&
    recording.timed &&
    recording.blockTimes.length == section.verses.length;

/// The recording that would chant [section] of reading [readingId]: its own
/// (a Buddha Wandanawa section), else its reading's. In a flow, the section's
/// original reading and section. Null when there is none.
Recording? recordingOfSection(
  AudioCatalogue catalogue,
  String readingId,
  Section section,
) {
  final ref = refOfFlowSection(section.id);
  final from = ref?.readingId ?? readingId;
  if (section.audio != null) {
    return catalogue.recordingFor(
      sectionRecordingId(from, ref?.sectionId ?? section.id),
    );
  }
  return catalogue.recordingFor(from);
}

/// One recorded section, played at [start] on the programme's timeline.
class ChantLeg {
  const ChantLeg({
    required this.recording,
    required this.sectionId,
    required this.firstBlock,
    required this.start,
  });

  final Recording recording;
  final String sectionId;

  /// The reader's index of the section's first block.
  final int firstBlock;
  final Duration start;

  int get blockCount => recording.blockTimes.length;
  Duration get end => start + recording.duration;
}

/// The recorded sections of a reading, one after another on one timeline.
class ChantProgramme {
  const ChantProgramme({
    required this.legs,
    required this.sectionCount,
    required this.times,
    required this.lineTimes,
    required this.paliLengths,
  });

  final List<ChantLeg> legs;

  /// Every section of the reading, recorded or not.
  final int sectionCount;

  /// One entry per phrased block on the programme's timeline; null for a
  /// block without a time or outside every leg.
  final List<BlockTime?> times;

  /// One list per phrased block when any leg has line times, else empty.
  final List<List<Duration?>> lineTimes;
  final List<List<int>> paliLengths;

  bool get single => legs.length == 1;
  int get recordedCount => legs.length;
  bool get partial => recordedCount < sectionCount;
  Duration get total => legs.last.end;

  /// The leg playing at [position]: 0 before the first, the last at or after
  /// [total].
  int legAt(Duration position) {
    var at = 0;
    for (var i = 1; i < legs.length; i++) {
      if (legs[i].start <= position) at = i;
    }
    return at;
  }

  /// The leg that chants [block]; null for a block outside every leg.
  ChantLeg? legOfBlock(int block) {
    for (final leg in legs) {
      if (block >= leg.firstBlock && block < leg.firstBlock + leg.blockCount) {
        return leg;
      }
    }
    return null;
  }

  /// Null when no section of [reading] is recorded.
  static ChantProgramme? of(Reading reading, AudioCatalogue catalogue) {
    final legs = <ChantLeg>[];
    var block = 0;
    var start = Duration.zero;
    for (final s in reading.sections) {
      if (!sectionHasBlocks(s)) continue;
      final recording = recordingOfSection(catalogue, reading.id, s);
      if (sectionIsRecorded(s, recording)) {
        final leg = ChantLeg(
          recording: recording!,
          sectionId: s.id,
          firstBlock: block,
          start: start,
        );
        legs.add(leg);
        start = leg.end;
      }
      block += s.verses.length;
    }
    if (legs.isEmpty) return null;

    final paliLengths = paliLengthsOf(reading);
    final first = legs.first;
    if (legs.length == 1 && first.blockCount == block) {
      // A pirith: its own times, untouched.
      return ChantProgramme(
        legs: List.unmodifiable(legs),
        sectionCount: reading.sections.length,
        times: first.recording.blockTimes,
        lineTimes: first.recording.lineTimes,
        paliLengths: paliLengths,
      );
    }

    final times = List<BlockTime?>.filled(block, null);
    final lined = legs.any((l) => l.recording.lineTimes.isNotEmpty);
    final lineTimes = lined
        ? List<List<Duration?>>.filled(block, const [])
        : const <List<Duration?>>[];
    for (final leg in legs) {
      final r = leg.recording;
      for (var i = 0; i < leg.blockCount; i++) {
        final t = r.blockTimes[i];
        times[leg.firstBlock + i] = t == null
            ? null
            : BlockTime(t.start + leg.start, t.end + leg.start);
        if (lined && i < r.lineTimes.length) {
          lineTimes[leg.firstBlock + i] = [
            for (final at in r.lineTimes[i]) at == null ? null : at + leg.start,
          ];
        }
      }
    }
    return ChantProgramme(
      legs: List.unmodifiable(legs),
      sectionCount: reading.sections.length,
      times: List.unmodifiable(times),
      lineTimes: lined ? List.unmodifiable(lineTimes) : lineTimes,
      paliLengths: paliLengths,
    );
  }
}

/// How many sections of [reading] a recording chants.
int recordedSectionCount(Reading reading, AudioCatalogue catalogue) =>
    ChantProgramme.of(reading, catalogue)?.recordedCount ?? 0;
