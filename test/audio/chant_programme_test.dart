import 'package:buddhist_gatha/audio/audio_catalogue.dart';
import 'package:buddhist_gatha/audio/chant_programme.dart';
import 'package:buddhist_gatha/content/model.dart';
import 'package:buddhist_gatha/reader/reader_items.dart';
import 'package:buddhist_gatha/settings/reading_language.dart';
import 'package:flutter_test/flutter_test.dart';

Duration s(num x) => Duration(microseconds: (x * 1000000).round());
BlockTime bt(num a, num b) => BlockTime(s(a), s(b));

class _Catalogue implements AudioCatalogue {
  _Catalogue(this.recordings);

  final Map<String, Recording> recordings;

  @override
  Recording? recordingFor(String readingId) => recordings[readingId];
}

/// A phrased verse of [n] made-up phrases.
Verse phrased(String id, [int n = 2]) => Verse(
  id: id,
  phrases: [
    for (var i = 0; i < n; i++)
      Phrase(pali: 'pali $id $i', sinhala: 'si $id $i', english: 'en $id $i'),
  ],
);

Verse plain(String id) => Verse(id: id, paliSi: 'plain $id', sinhala: 'si');

/// A section of a flow taken from reading [readingId].
Section section(String readingId, String sectionId, List<Verse> verses) =>
    Section(
      id: '$readingId~$sectionId',
      number: 1,
      heading: 'Heading $readingId',
      verses: [for (final v in verses) v.withId('$readingId~${v.id}')],
    );

Recording recording(
  String readingId,
  List<BlockTime?> blockTimes,
  Duration duration, {
  List<List<Duration?>> lineTimes = const [],
}) => Recording(
  readingId: readingId,
  path: 'audio/$readingId.m4a',
  label: 'Recording $readingId',
  placeholder: false,
  blockTimes: blockTimes,
  lineTimes: lineTimes,
  duration: duration,
);

/// Three plain sections, pirith A (2 blocks, 10 s) and pirith B (3 blocks,
/// 20 s), in the order plain, A, plain, B, plain.
Reading flow() => Reading(
  id: 'flow-1',
  title: 'My flow',
  sections: [
    section('one', 's1', [plain('v1'), plain('v2')]),
    section('pa', 'p', [phrased('a1'), phrased('a2', 3)]),
    section('two', 's1', [plain('v1')]),
    section('pb', 'p', [phrased('b1'), phrased('b2'), phrased('b3', 1)]),
    section('three', 's2', [plain('v1')]),
  ],
);

final aTimes = [bt(1, 4), bt(4, 9)];
final bTimes = [bt(0.5, 6), null, bt(12, 19)];

AudioCatalogue flowCatalogue() => _Catalogue({
  'pa': recording('pa', aTimes, s(10)),
  'pb': recording('pb', bTimes, s(20)),
});

void main() {
  test('a pirith is a one-leg programme with its own times', () {
    final times = [bt(0, 3), bt(3, 7), null];
    final lines = <List<Duration?>>[
      [s(0), s(1)],
      [s(3), null],
      [],
    ];
    final rec = recording('pirith-x', times, s(8), lineTimes: lines);
    final catalogue = _Catalogue({'pirith-x': rec});
    final reading = Reading(
      id: 'pirith-x',
      title: 'A pirith',
      sections: [
        Section(
          id: 'p',
          number: 1,
          heading: 'Pirith',
          verses: [phrased('v1'), phrased('v2'), phrased('v3')],
        ),
      ],
    );
    final p = ChantProgramme.of(reading, catalogue)!;
    expect(p.legs, hasLength(1));
    expect(p.legs.single.start, Duration.zero);
    expect(p.legs.single.firstBlock, 0);
    expect(p.legs.single.sectionId, 'p');
    expect(p.legs.single.recording, same(rec));
    expect(p.times, hasLength(times.length));
    for (var i = 0; i < times.length; i++) {
      expect(identical(p.times[i], times[i]), isTrue, reason: '$i');
    }
    expect(p.lineTimes, hasLength(lines.length));
    for (var i = 0; i < lines.length; i++) {
      expect(identical(p.lineTimes[i], lines[i]), isTrue, reason: '$i');
    }
    expect(p.single, isTrue);
    expect(p.partial, isFalse);
    expect(p.sectionCount, 1);
    expect(p.total, s(8));
    expect(recordedSectionCount(reading, catalogue), 1);
  });

  test('a flow of plain and pirith sections gives legs in order on one '
      'timeline', () {
    final p = ChantProgramme.of(flow(), flowCatalogue())!;
    expect(p.legs.map((l) => l.firstBlock), [0, 2]);
    expect(p.legs.map((l) => l.start), [Duration.zero, s(10)]);
    expect(p.legs.map((l) => l.sectionId), ['pa~p', 'pb~p']);
    expect(p.legs.map((l) => l.blockCount), [2, 3]);
    expect(p.legs.map((l) => l.end), [s(10), s(30)]);
    expect(p.times, [bt(1, 4), bt(4, 9), bt(10.5, 16), null, bt(22, 29)]);
    expect(p.lineTimes, isEmpty);
    expect(p.sectionCount, 5);
    expect(p.recordedCount, 2);
    expect(p.single, isFalse);
    expect(p.partial, isTrue);
    expect(p.total, s(30));
    expect(recordedSectionCount(flow(), flowCatalogue()), 2);
  });

  test('the block index space matches the reader items', () {
    final reading = flow();
    final p = ChantProgramme.of(reading, flowCatalogue())!;
    final blocks = buildReaderItems(
      reading,
      LanguageSelection.initial,
      TwoLanguageLayout.verse,
    ).whereType<PhraseBlockItem>().toList();
    expect(blocks, hasLength(5));
    expect(p.times, hasLength(blocks.length));
    expect(p.paliLengths, hasLength(blocks.length));
    for (final b in blocks) {
      expect(p.legOfBlock(b.index)?.sectionId, b.sectionId, reason: b.verseId);
      expect(p.paliLengths[b.index], [
        for (final ph in b.phrases) ph.pali.length,
      ]);
    }
    expect(p.legOfBlock(-1), isNull);
    expect(p.legOfBlock(blocks.length), isNull);
  });

  test('a section whose recording does not cover it is not a leg', () {
    final p = ChantProgramme.of(
      flow(),
      _Catalogue({
        // Three times for a section of two verses.
        'pa': recording('pa', [bt(0, 1), bt(1, 2), bt(2, 3)], s(10)),
        'pb': recording('pb', bTimes, s(20)),
      }),
    )!;
    expect(p.legs.map((l) => l.sectionId), ['pb~p']);
    expect(p.legs.single.firstBlock, 2);
    expect(p.legs.single.start, Duration.zero);
    expect(p.times, [null, null, ...bTimes]);
    expect(p.recordedCount, 1);
    expect(p.total, s(20));
  });

  test('no recorded section gives null', () {
    expect(ChantProgramme.of(flow(), _Catalogue({})), isNull);
    expect(recordedSectionCount(flow(), _Catalogue({})), 0);
    // An untimed recording (the placeholder tone) records nothing.
    const tone = Recording(
      readingId: 'pa',
      path: placeholderToneAsset,
      label: placeholderToneLabel,
      placeholder: true,
      duration: Duration.zero,
    );
    expect(ChantProgramme.of(flow(), _Catalogue({'pa': tone})), isNull);
    expect(
      ChantProgramme.of(
        const Reading(id: 'empty', title: 'Empty', sections: []),
        flowCatalogue(),
      ),
      isNull,
    );
  });

  test('legAt at the boundaries', () {
    final p = ChantProgramme.of(flow(), flowCatalogue())!;
    expect(p.legAt(const Duration(milliseconds: -1)), 0);
    expect(p.legAt(Duration.zero), 0);
    expect(p.legAt(s(9.999)), 0);
    expect(p.legAt(s(10)), 1);
    expect(p.legAt(s(30)), 1);
    expect(p.legAt(s(99)), 1);
  });

  test('line times are shifted and kept per block', () {
    final p = ChantProgramme.of(
      flow(),
      _Catalogue({
        'pa': recording('pa', aTimes, s(10)),
        'pb': recording(
          'pb',
          bTimes,
          s(20),
          lineTimes: [
            [s(0.5), s(3)],
            [],
            [null],
          ],
        ),
      }),
    )!;
    expect(p.lineTimes, [
      <Duration?>[],
      <Duration?>[],
      [s(10.5), s(13)],
      <Duration?>[],
      [null],
    ]);
  });

  group('sections with their own recordings (the Buddha Wandanawa)', () {
    const info = RecordingInfo(path: 'audio/w.m4a', label: 'Chanted');
    Section own(String id, List<Verse> verses, {bool audio = true}) => Section(
      id: id,
      number: 1,
      heading: 'Heading $id',
      audio: audio ? info : null,
      verses: verses,
    );
    // s1 (two verses, recorded), s2 (no recording), s3 (three verses, the
    // middle one silent).
    Reading wandana() => Reading(
      id: 'wandana',
      title: 'Wandana',
      sections: [
        own('s1', [plain('a1'), plain('a2')]),
        own('s2', [plain('b1')], audio: false),
        own('s3', [plain('c1'), plain('c2'), plain('c3')]),
      ],
    );
    AudioCatalogue catalogue() => _Catalogue({
      sectionRecordingId('wandana', 's1'): recording('wandana#s1', [
        bt(0.3, 4),
        bt(4.7, 9),
      ], s(10)),
      sectionRecordingId('wandana', 's3'): recording('wandana#s3', [
        bt(0.3, 2),
        null,
        bt(3, 5),
      ], s(6)),
    });

    test('play one after another, a block per verse', () {
      expect(sectionRecordingId('wandana', 's3'), 'wandana#s3');
      final p = ChantProgramme.of(wandana(), catalogue())!;
      expect(p.legs.map((l) => l.sectionId), ['s1', 's3']);
      expect(p.legs.map((l) => l.firstBlock), [0, 2]);
      expect(p.legs.map((l) => l.start), [Duration.zero, s(10)]);
      expect(p.times, [bt(0.3, 4), bt(4.7, 9), bt(10.3, 12), null, bt(13, 15)]);
      expect(p.paliLengths, [
        for (final id in ['a1', 'a2', 'c1', 'c2', 'c3']) ['plain $id'.length],
      ]);
      expect(p.sectionCount, 3);
      expect(p.partial, isTrue);
      expect(p.total, s(16));
    });

    test('a section is recorded only with a time per verse', () {
      final r = wandana();
      expect(
        sectionIsRecorded(
          r.sections[0],
          catalogue().recordingFor('wandana#s1'),
        ),
        isTrue,
      );
      // A recording timing three verses does not chant a section of two.
      expect(
        sectionIsRecorded(
          r.sections[0],
          catalogue().recordingFor('wandana#s3'),
        ),
        isFalse,
      );
      // A section without its own recording is not chanted by one.
      expect(
        sectionIsRecorded(
          r.sections[1],
          catalogue().recordingFor('wandana#s1'),
        ),
        isFalse,
      );
      expect(
        recordingOfSection(catalogue(), 'wandana', r.sections[2])?.readingId,
        'wandana#s3',
      );
      expect(recordingOfSection(catalogue(), 'wandana', r.sections[1]), isNull);
    });

    test('in a flow, a section keeps its recording', () {
      final w = wandana();
      final f = Reading(
        id: 'flow-1',
        title: 'My flow',
        sections: [
          for (final sec in [w.sections[2], w.sections[0]])
            Section(
              id: 'wandana~${sec.id}',
              number: 1,
              heading: sec.heading,
              audio: sec.audio,
              verses: [for (final v in sec.verses) v.withId('wandana~${v.id}')],
            ),
        ],
      );
      final p = ChantProgramme.of(f, catalogue())!;
      expect(p.legs.map((l) => l.sectionId), ['wandana~s3', 'wandana~s1']);
      expect(p.times, [bt(0.3, 2), null, bt(3, 5), bt(6.3, 10), bt(10.7, 15)]);
      expect(
        recordingOfSection(catalogue(), 'flow-1', f.sections[0])?.readingId,
        'wandana#s3',
      );
    });

    test('the block index space matches the reader items', () {
      final p = ChantProgramme.of(wandana(), catalogue())!;
      final items = buildReaderItems(
        wandana(),
        LanguageSelection.initial,
        TwoLanguageLayout.verse,
      );
      final blocks = <String, int>{
        for (final i in items)
          if (blockOfItem(i) != null) i.verseId!: blockOfItem(i)!,
      };
      expect(blocks, {'a1': 0, 'a2': 1, 'c1': 2, 'c2': 3, 'c3': 4});
      expect(p.times, hasLength(blocks.length));
      expect(p.legOfBlock(blocks['c3']!)?.sectionId, 's3');
      expect(
        items
            .whereType<VerseTextItem>()
            .where((i) => i.verseId == 'b1')
            .every((i) => i.block == null),
        isTrue,
      );
    });
  });
}
