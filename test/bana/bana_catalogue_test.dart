import 'dart:io';

import 'package:buddhist_gatha/bana/bana_catalogue.dart';
import 'package:flutter_test/flutter_test.dart';

BanaCatalogue _real() =>
    BanaCatalogue.parse(File('assets/bana/bana.json').readAsStringSync())!;

void main() {
  test('parses the bundled file', () {
    final c = _real();
    expect(c.version, 1);
    expect(c.bana, hasLength(180));
    expect([for (final s in c.series) s.parts.length], [23, 72]);
    expect(c.topics, hasLength(11));
    expect(c.speakers, hasLength(2));
  });

  test('parse returns null on malformed or missing version', () {
    expect(BanaCatalogue.parse('not json'), isNull);
    expect(BanaCatalogue.parse('[]'), isNull);
    expect(BanaCatalogue.parse('{"topics":[]}'), isNull);
    expect(BanaCatalogue.parse('{"version":"1"}'), isNull);
    expect(BanaCatalogue.parse('{"version":1,"topics":5}'), isNull);
  });

  test('filter by speaker then topic', () {
    final c = _real();
    const kiri = 'kiriwaththuduwe-ariyadassana';
    expect(c.topicsFor(kiri), {'PT'});
    expect(c.topicsFor(null), hasLength(11));
    final items = c.filter(speakerId: kiri, topicId: 'PT');
    expect(items, hasLength(1));
    expect((items.single as SeriesItem).series.id, 'patthana-deshana');
  });

  test('a series shows whole under its topic', () {
    final c = _real();
    final items = c.filter(topicId: 'PT');
    expect(items.first, isA<SeriesItem>());
    expect((items.first as SeriesItem).series.id, 'patthana-deshana');
    final singles = items.whereType<SingleItem>().toList();
    expect(singles, isNotEmpty);
    expect(items.indexWhere((i) => i is SingleItem), 1);
    expect(singles.every((s) => s.bana.topics.contains('PT')), isTrue);
    expect(singles.every((s) => s.bana.series == null), isTrue);
  });

  test('query finds a series part', () {
    final c = _real();
    final items = c.filter(query: 'ආනාපානසති');
    final parts = [
      for (final i in items.whereType<SingleItem>())
        if (i.bana.series == 'samatha-bhavana') i.bana.part,
    ];
    expect(parts, [17, 18]);
    expect(items.whereType<SeriesItem>(), isEmpty);
  });

  test('partsOf is in part order 1..72', () {
    final c = _real();
    expect([for (final b in c.partsOf('patthana-deshana')) b.part],
        [for (var i = 1; i <= 72; i++) i]);
    expect(c.partsOf('nope'), isEmpty);
  });

  test('links, thumbnail and length label', () {
    final c = _real();
    final b = c.byId('2PZGfjRIOJk')!;
    expect(b.watchUri.toString(), 'https://www.youtube.com/watch?v=2PZGfjRIOJk');
    expect(b.thumbnailUri.toString(),
        'https://i.ytimg.com/vi/2PZGfjRIOJk/mqdefault.jpg');
    expect(b.lengthLabel, '42:22');
    expect(c.byId('missing'), isNull);
    expect(c.seriesById('samatha-bhavana'), isNotNull);
  });

  test('length label with hours', () {
    final c = BanaCatalogue.parse('{"version":1,"bana":[{"id":"abcdefghijk",'
        '"title":"t","speaker":"s","channel":"c","topics":[],"seconds":3725,'
        '"embeddable":true}]}')!;
    expect(c.bana.single.lengthLabel, '1:02:05');
  });
}
