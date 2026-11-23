import '../content/model.dart';

/// A block and a phrase of a pirith, both zero-based.
class ChantPlace {
  const ChantPlace(this.block, this.phrase);

  final int block, phrase;

  @override
  bool operator ==(Object other) =>
      other is ChantPlace && other.block == block && other.phrase == phrase;

  @override
  int get hashCode => Object.hash(block, phrase);

  @override
  String toString() => 'ChantPlace($block, $phrase)';
}

/// Which block and phrase is being chanted at [position].
///
/// The block is the last timed one that has started. Within it, the phrase is
/// found by how far through the block's time we are, spread over the phrases
/// by the length of their Pali text. [paliLengths] `[b][p]` is the UTF-16 length
/// of phrase `p` of block `b`. Null before the first timed block starts.
///
/// When [lineTimes] has a non-empty entry for the block, the phrase is the last
/// line whose time is set and not after [position], or `-1` when none is (the
/// block is active but no line is marked yet).
ChantPlace? placeAt(
  Duration position,
  List<BlockTime?> times,
  List<List<int>> paliLengths, {
  List<List<Duration?>> lineTimes = const [],
}) {
  int? block;
  for (var i = 0; i < times.length; i++) {
    final t = times[i];
    if (t != null && t.start <= position) block = i;
  }
  if (block == null) return null;

  if (block < lineTimes.length && lineTimes[block].isNotEmpty) {
    var phrase = -1;
    final lines = lineTimes[block];
    for (var p = 0; p < lines.length; p++) {
      final at = lines[p];
      if (at != null && at <= position) phrase = p;
    }
    return ChantPlace(block, phrase);
  }

  final t = times[block]!;
  final span = (t.end - t.start).inMicroseconds;
  final progress = span <= 0
      ? 1.0
      : ((position - t.start).inMicroseconds / span).clamp(0.0, 1.0);

  final lengths = block < paliLengths.length
      ? paliLengths[block]
      : const <int>[];
  if (lengths.isEmpty) return ChantPlace(block, 0);
  final total = lengths.fold<int>(0, (a, b) => a + b);
  final target = total * progress;
  var running = 0;
  for (var p = 0; p < lengths.length; p++) {
    running += lengths[p];
    if (running >= target) return ChantPlace(block, p);
  }
  return ChantPlace(block, lengths.length - 1);
}

/// The Pali length of every phrase, `[block][phrase]`, over every section of
/// blocks ([sectionHasBlocks]), in order: the reader's block numbering. A
/// verse that is not phrased is one phrase: its whole Pali.
List<List<int>> paliLengthsOf(Reading reading) => [
  for (final s in reading.sections)
    if (sectionIsPhrased(s))
      for (final v in s.verses) [for (final p in v.phrases) p.pali.length]
    else if (sectionHasBlocks(s))
      for (final v in s.verses) [(v.paliSi ?? '').length],
];

/// True for a section the reader shows as blocks of phrases: it has verses
/// and every one is phrased (as `buildReaderItems` numbers them).
bool sectionIsPhrased(Section s) =>
    s.verses.isNotEmpty && s.verses.every((v) => v.isPhrased);

/// True for a section whose verses are numbered as blocks for chanting: a
/// phrased section (a pirith), or one with its own recording, where each
/// verse is a block (a Buddha Wandanawa section).
bool sectionHasBlocks(Section s) =>
    sectionIsPhrased(s) || (s.audio != null && s.verses.isNotEmpty);

/// When [block] starts; null for an untimed (or missing) block.
Duration? blockStart(List<BlockTime?> times, int block) =>
    block >= 0 && block < times.length ? times[block]?.start : null;
