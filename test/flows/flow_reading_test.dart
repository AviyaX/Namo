import 'package:buddhist_gatha/content/model.dart';
import 'package:buddhist_gatha/flows/flow_reading.dart';
import 'package:buddhist_gatha/flows/flows.dart';
import 'package:flutter_test/flutter_test.dart';

Phrase _p(String s) => Phrase(pali: 'p$s', sinhala: 's$s', english: 'e$s');

const _src = SourceRecord(
  name: 'src name',
  locator: 'src locator',
  collected: 'src collected',
  translator: 'src translator',
);

const _fix = Correction(
  field: 'f1',
  from: 'x1',
  to: 'y1',
  reason: 'r1',
  count: 1,
);

/// Latin placeholder text only.
Library _library() => Library(
  categories: [
    Category(
      id: 'c1',
      title: 'Category one',
      subtitle: 'Sub one',
      readings: [
        Reading(
          id: 'r1',
          title: 'Reading one',
          audio: const RecordingInfo(asset: 'r1.m4a', label: 'credit r1'),
          sections: [
            Section(
              id: 'a',
              number: 1,
              heading: 'Heading a',
              verses: [
                Verse(
                  id: 'a-1',
                  paliSi: 'p a1',
                  sinhala: 's a1',
                  english: 'e a1',
                ),
              ],
            ),
            Section(
              id: 'b',
              number: 2,
              heading: 'Heading b',
              source: _src,
              check: CheckStatus.checkedAgainstSource,
              corrections: const [_fix],
              verses: [
                Verse(
                  id: 'b-1',
                  paliSi: 'p b1',
                  paliRoman: 'pr b1',
                  sinhala: 's b1',
                  english: 'e b1',
                  englishKind: EnglishKind.explanation,
                  englishSource: _src,
                  check: CheckStatus.needsChecking,
                  notes: const ['n1'],
                  corrections: const [_fix],
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    Category(
      id: 'c2',
      title: 'Category two',
      subtitle: 'Sub two',
      readings: [
        Reading(
          id: 'r2',
          title: 'Reading two',
          titleRoman: 'Roman two',
          audio: const RecordingInfo(asset: 'r2.m4a', label: 'credit r2'),
          sections: [
            Section(
              id: 'p',
              number: 1,
              heading: 'Heading r2',
              verses: [
                Verse(id: 'b1', phrases: [_p('1'), _p('2')]),
                Verse(id: 'b2', phrases: [_p('3')]),
              ],
            ),
          ],
        ),
        Reading(
          id: 'r3',
          title: 'Reading three',
          titleRoman: 'Roman three',
          sections: [
            Section(
              id: 'p',
              number: 1,
              heading: 'Heading r3',
              verses: [
                Verse(id: 'b1', phrases: [_p('4')]),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

const _r2p = FlowRef(readingId: 'r2', sectionId: 'p');
const _r1b = FlowRef(readingId: 'r1', sectionId: 'b');
const _r3p = FlowRef(readingId: 'r3', sectionId: 'p');

List<List<String>> _verseIds(Reading r) => [
  for (final s in r.sections) [for (final v in s.verses) v.id],
];

void main() {
  test('Verse.withId changes only the id', () {
    final v = _library().reading('r1')!.sections[1].verses.single;
    final w = v.withId('new');
    expect(w.id, 'new');
    expect(identical(w.paliSi, v.paliSi), isTrue);
    expect(identical(w.paliRoman, v.paliRoman), isTrue);
    expect(identical(w.sinhala, v.sinhala), isTrue);
    expect(identical(w.english, v.english), isTrue);
    expect(identical(w.englishSource, v.englishSource), isTrue);
    expect(w.englishKind, v.englishKind);
    expect(w.check, v.check);
    expect(identical(w.notes, v.notes), isTrue);
    expect(identical(w.corrections, v.corrections), isTrue);
    expect(identical(w.phrases, v.phrases), isTrue);
  });

  test('a flow becomes a reading of its sections, in flow order', () {
    final lib = _library();
    const flow = Flow(
      id: 'flow-1',
      name: 'Flow one',
      sections: [_r2p, _r1b, _r3p],
    );
    final r = flowReading(flow, lib);
    expect(r.id, 'flow-1');
    expect(r.title, 'Flow one');
    expect(r.audio, isNull);
    expect(r.titleRoman, isNull);
    expect(r.sections.map((s) => s.id), ['r2~p', 'r1~b', 'r3~p']);
    expect(r.sections.map((s) => s.number), [1, 2, 3]);
    expect(r.sections.map((s) => s.heading), [
      'Heading r2',
      'Heading b',
      'Heading r3',
    ]);
    expect(_verseIds(r), [
      ['r2~b1', 'r2~b2'],
      ['r1~b-1'],
      ['r3~b1'],
    ]);

    final originalB = lib.reading('r1')!.sections[1];
    final flowB = r.sections[1];
    expect(identical(flowB.heading, originalB.heading), isTrue);
    expect(identical(flowB.source, originalB.source), isTrue);
    expect(flowB.check, originalB.check);
    expect(identical(flowB.corrections, originalB.corrections), isTrue);
  });

  test('the text of a flow verse is the identical object', () {
    final lib = _library();
    const flow = Flow(id: 'flow-1', name: 'F', sections: [_r2p, _r1b]);
    final r = flowReading(flow, lib);
    final pairs = [
      (r.sections[0].verses[0], lib.reading('r2')!.sections[0].verses[0]),
      (r.sections[0].verses[1], lib.reading('r2')!.sections[0].verses[1]),
      (r.sections[1].verses[0], lib.reading('r1')!.sections[1].verses[0]),
    ];
    for (final (f, o) in pairs) {
      expect(identical(f.paliSi, o.paliSi), isTrue);
      expect(identical(f.sinhala, o.sinhala), isTrue);
      expect(identical(f.english, o.english), isTrue);
      expect(identical(f.phrases, o.phrases), isTrue);
      expect(identical(f.notes, o.notes), isTrue);
      expect(identical(f.corrections, o.corrections), isTrue);
    }
  });

  test('a ref to a missing reading or section is skipped', () {
    final lib = _library();
    const flow = Flow(
      id: 'flow-2',
      name: 'F',
      sections: [
        FlowRef(readingId: 'gone', sectionId: 'a'),
        _r3p,
        FlowRef(readingId: 'r1', sectionId: 'gone'),
        _r1b,
      ],
    );
    final r = flowReading(flow, lib);
    expect(r.sections.map((s) => s.id), ['r3~p', 'r1~b']);
    expect(r.sections.map((s) => s.number), [1, 2]);
    expect(liveRefs(flow, lib), [_r3p, _r1b]);
  });

  test('the library is untouched', () {
    final lib = _library();
    List<Object> snapshot() => [
      for (final c in lib.categories)
        for (final r in c.readings) ...[
          r,
          r.sections,
          for (final s in r.sections) ...[
            s,
            s.id,
            s.number,
            s.heading,
            s.verses,
            for (final v in s.verses) ...[v, v.id],
          ],
        ],
    ];
    final before = snapshot();
    flowReading(
      const Flow(id: 'flow-1', name: 'F', sections: [_r2p, _r1b, _r3p]),
      lib,
    );
    final after = snapshot();
    expect(after, before);
    for (var i = 0; i < before.length; i++) {
      expect(identical(after[i], before[i]), isTrue, reason: '$i');
    }
    expect(lib.reading('r1')!.sections.map((s) => s.id), ['a', 'b']);
    expect(_verseIds(lib.reading('r2')!), [
      ['b1', 'b2'],
    ]);
  });

  group('resolveReading', () {
    final lib = _library();
    const flows = FlowsState(
      flows: [
        Flow(id: 'flow-1', name: 'Flow one', sections: [_r1b, _r2p]),
        Flow(id: 'flow-2', name: 'Empty'),
      ],
      nextNumber: 3,
    );

    test('a content id gives the identical reading', () {
      expect(
        identical(resolveReading(lib, flows, 'r1'), lib.reading('r1')),
        isTrue,
      );
    });

    test('a flow id gives the flow as a reading', () {
      final r = resolveReading(lib, flows, 'flow-1')!;
      expect(r.id, 'flow-1');
      expect(r.title, 'Flow one');
      expect(r.sections.map((s) => s.id), ['r1~b', 'r2~p']);
    });

    test('an empty flow gives a reading with no sections', () {
      final r = resolveReading(lib, flows, 'flow-2')!;
      expect(r.id, 'flow-2');
      expect(r.title, 'Empty');
      expect(r.sections, isEmpty);
    });

    test('a flow whose sections are all gone gives a reading with no '
        'sections', () {
      const gone = FlowsState(
        flows: [
          Flow(
            id: 'flow-1',
            name: 'F',
            sections: [FlowRef(readingId: 'gone', sectionId: 'p')],
          ),
        ],
        nextNumber: 2,
      );
      expect(resolveReading(lib, gone, 'flow-1')!.sections, isEmpty);
    });

    test('unknown ids give null', () {
      expect(resolveReading(lib, flows, 'flow-9'), isNull);
      expect(resolveReading(lib, flows, 'nothing'), isNull);
    });
  });

  test('section ids round-trip', () {
    for (final ref in [_r2p, _r1b, _r3p]) {
      expect(refOfFlowSection(flowSectionId(ref)), ref);
    }
    expect(flowSectionId(_r1b), 'r1~b');
    expect(refOfFlowSection('plain'), isNull);
  });
}
